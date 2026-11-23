"""Tries the destinations the build hosts' egress policy closes to a build, and two it leaves
open. Exits 1 if a closed one answers or an open one does not. Prints classes, not addresses."""
import socket
import sys

TIMEOUT = 5


def tcp(addr, port):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(TIMEOUT)
    try:
        s.connect((addr, port))
        return "connected"
    except socket.timeout:
        return "timeout"
    except OSError as e:
        return "error:" + (e.strerror or str(e))
    finally:
        s.close()


def own_listener():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.bind(("127.0.0.1", 0))
    srv.listen(1)
    try:
        return tcp("127.0.0.1", srv.getsockname()[1])
    finally:
        srv.close()


# class, what the policy should make of it, result
rows = [
    ("metadata tcp/80", "closed", tcp("169.254.169.254", 80)),
    ("host loopback tcp/22", "closed", tcp("127.0.0.1", 22)),
    ("host loopback tcp/50051", "closed", tcp("127.0.0.1", 50051)),
    ("vpc tcp/9", "closed", tcp("10.255.255.1", 9)),
    ("own loopback listener", "open", own_listener()),
    ("internet tcp/443", "open", tcp("1.1.1.1", 443)),
]
bad = 0
for name, want, got in rows:
    # A dropped packet shows as a timeout. "connected" on a closed class is the failure this
    # looks for; a refusal there would mean the packet got through to a closed port.
    ok = (got == "timeout") if want == "closed" else (got == "connected")
    bad += not ok
    print(f"{'ok  ' if ok else 'FAIL'} {name}: expected {want}, got {got}")
sys.exit(1 if bad else 0)
