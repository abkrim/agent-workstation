"""nan-gate: this machine's single door to NaN (nan.builders).

A NaN plan allows a fixed number of simultaneous requests per key. Every NaN
client on the machine points its base URL at this gate instead of
https://api.nan.builders/v1:

    http://127.0.0.1:4880/<pool>/v1/...     pool = hermes | dev

At most MAX_CONCURRENT requests go upstream at once; the rest wait in line, the
higher-priority pool first (hermes, then dev), and in arrival order within a
pool. A requests-per-minute ceiling keeps the machine under the per-key limit.
The client's own Authorization header is forwarded as is: the gate holds no key.
Responses, streamed ones included, are passed through as they arrive.
Standard library only. Installed by workstation-kit (modules/85-nan.sh).
"""
import heapq
import http.client
import itertools
import os
import ssl
import sys
import threading
import time
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

UPSTREAM = os.environ.get("NAN_GATE_UPSTREAM", "api.nan.builders")
LISTEN = os.environ.get("NAN_GATE_LISTEN", "127.0.0.1")
PORT = int(os.environ.get("NAN_GATE_PORT", "4880"))
MAX_CONCURRENT = int(os.environ.get("NAN_GATE_MAX_CONCURRENT", "4"))
MAX_RPM = int(os.environ.get("NAN_GATE_MAX_RPM", "40"))
WAIT_TIMEOUT = float(os.environ.get("NAN_GATE_WAIT_TIMEOUT", "900"))
UPSTREAM_TIMEOUT = float(os.environ.get("NAN_GATE_UPSTREAM_TIMEOUT", "900"))
POOLS = {"hermes": 0, "dev": 1}
HOP = {"connection", "keep-alive", "proxy-authenticate", "proxy-authorization", "te",
       "trailers", "transfer-encoding", "upgrade", "host", "content-length"}


class Gate:
    """Priority semaphore with a sliding one-minute request window."""

    def __init__(self, slots: int, rpm: int):
        self.slots = slots
        self.rpm = rpm
        self.busy = 0
        self.waiting: list[tuple[int, int, threading.Event]] = []
        self.order = itertools.count()
        self.started: deque[float] = deque()
        self.lock = threading.Lock()

    def _grant(self) -> None:
        now = time.monotonic()
        while self.started and now - self.started[0] > 60:
            self.started.popleft()
        while self.waiting and self.busy < self.slots and len(self.started) < self.rpm:
            _, _, event = heapq.heappop(self.waiting)
            self.busy += 1
            self.started.append(now)
            event.set()

    def acquire(self, priority: int) -> bool:
        event = threading.Event()
        with self.lock:
            heapq.heappush(self.waiting, (priority, next(self.order), event))
            self._grant()
        deadline = time.monotonic() + WAIT_TIMEOUT
        while not event.wait(1.0):
            with self.lock:
                self._grant()  # the rpm window may have opened
            if time.monotonic() > deadline:
                with self.lock:
                    if event.is_set():
                        return True
                    self.waiting = [w for w in self.waiting if w[2] is not event]
                    heapq.heapify(self.waiting)
                return False
        return True

    def release(self) -> None:
        with self.lock:
            self.busy -= 1
            self._grant()

    def status(self) -> str:
        with self.lock:
            return f"busy={self.busy}/{self.slots} waiting={len(self.waiting)} last_minute={len(self.started)}/{self.rpm}"


GATE = Gate(MAX_CONCURRENT, MAX_RPM)
CONTEXT = ssl.create_default_context()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "nan-gate"

    def log_message(self, fmt, *args):  # one line per request, no bodies or keys
        sys.stderr.write("%s %s\n" % (self.log_date_time_string(), fmt % args))

    def _reply(self, code: int, body: str) -> None:
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _proxy(self) -> None:
        if self.path == "/status":
            return self._reply(200, '{"status": "%s"}' % GATE.status())
        parts = self.path.split("/", 2)
        if len(parts) < 3 or parts[1] not in POOLS:
            return self._reply(404, '{"error": "use /hermes/ or /dev/ before /v1"}')
        pool, rest = parts[1], "/" + parts[2]
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else None
        if not GATE.acquire(POOLS[pool]):
            return self._reply(429, '{"error": {"message": "nan-gate: waited too long for a free slot", "code": "gate_timeout"}}')
        try:
            upstream = http.client.HTTPSConnection(UPSTREAM, timeout=UPSTREAM_TIMEOUT, context=CONTEXT)
            headers = {k: v for k, v in self.headers.items() if k.lower() not in HOP}
            headers["Host"] = UPSTREAM
            upstream.request(self.command, rest, body=body, headers=headers)
            response = upstream.getresponse()
            self.send_response(response.status, response.reason)
            for k, v in response.getheaders():
                if k.lower() not in HOP:
                    self.send_header(k, v)
            self.send_header("Transfer-Encoding", "chunked")
            self.send_header("Connection", "close")
            self.end_headers()
            while True:
                chunk = response.read1(65536) if hasattr(response, "read1") else response.read(65536)
                if not chunk:
                    break
                self.wfile.write(b"%x\r\n%s\r\n" % (len(chunk), chunk))
                self.wfile.flush()
            self.wfile.write(b"0\r\n\r\n")
            self.close_connection = True
            upstream.close()
        except (BrokenPipeError, ConnectionResetError):
            self.close_connection = True
        except Exception as error:  # upstream unreachable or timed out
            try:
                self._reply(502, '{"error": {"message": "nan-gate: %s", "code": "gate_upstream"}}' % type(error).__name__)
            except Exception:
                pass
        finally:
            GATE.release()

    do_GET = do_POST = do_PUT = do_DELETE = do_PATCH = _proxy


if __name__ == "__main__":
    server = ThreadingHTTPServer((LISTEN, PORT), Handler)
    server.daemon_threads = True
    sys.stderr.write(f"nan-gate on {LISTEN}:{PORT}, {MAX_CONCURRENT} slots, {MAX_RPM} rpm\n")
    server.serve_forever()
