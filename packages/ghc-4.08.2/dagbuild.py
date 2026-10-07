#!/usr/bin/env python3
"""dagbuild.py DIR JOBS CMD...: compile the modules DIR/<m>.hs in import order, JOBS at a time.

CMD is run in DIR with the module name appended and prints one line: "OK m ...", "WAIT m" or "FAIL m: ...".
A module starts once every module it imports (non-SOURCE imports within the set) has compiled; the ready module
with the most work behind it (its size plus its largest chain of importers) goes first. WAIT and FAIL are retried
after the next success, as the overlay's round scripts do, so an import the graph misses still resolves.
The module set is $MODS when given, else every *.hs in DIR except *.unlit.hs.
Prints one line per attempt (elapsed, duration, CMD's line); exits 1 if any module never compiled.
"""
import heapq
import os
import re
import subprocess
import sys
import time
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait

d, jobs, cmd = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
mods = sorted(os.environ["MODS"].split()) if os.environ.get("MODS") else sorted(
    f[:-3] for f in os.listdir(d) if f.endswith(".hs") and not f.endswith(".unlit.hs"))
ms = set(mods)
IMP = re.compile(r"^import\s+(\{-#\s*SOURCE\s*#-\}\s*)?(?:qualified\s+)?([A-Z][\w.]*)", re.M)
deps, users = {}, {m: set() for m in mods}
for m in mods:
    src = open(os.path.join(d, m + ".hs"), errors="replace").read()
    deps[m] = {x.group(2) for x in IMP.finditer(src) if not x.group(1) and x.group(2) in ms and x.group(2) != m}
    for x in deps[m]:
        users[x].add(m)
size = {m: os.path.getsize(os.path.join(d, m + ".hs")) for m in mods}
prio = {}


def weight(m, seen=frozenset()):
    if m in prio:
        return prio[m]
    if m in seen:
        return size[m]
    w = size[m] + max((weight(u, seen | {m}) for u in users[m]), default=0)
    prio[m] = w
    return w


for m in mods:
    weight(m)

done, retry, last = set(), set(), {}
pending = set(mods)
ready = []


def push(m):
    pending.discard(m)
    heapq.heappush(ready, (-prio[m], m))


for m in mods:
    if not deps[m]:
        push(m)


def run(m):
    s = time.time()
    r = subprocess.run(cmd + [m], cwd=d, capture_output=True, text=True)
    lines = r.stdout.strip().splitlines()
    return m, (lines[-1] if lines else "FAIL %s: no output (rc=%d)" % (m, r.returncode)), time.time() - s


t0 = time.time()
running = {}
with ThreadPoolExecutor(jobs) as ex:
    while True:
        while ready and len(running) < jobs:
            m = heapq.heappop(ready)[1]
            running[ex.submit(run, m)] = m
        if not running:
            # nothing runnable: retry what waited, then anything whose imports never all compiled (a graph miss)
            stalled = sorted(retry) or sorted(pending)
            if not stalled or last.get("_stall") == len(done):
                break
            last["_stall"] = len(done)
            for m in stalled:
                retry.discard(m)
                push(m)
            continue
        fin, _ = wait(running, return_when=FIRST_COMPLETED)
        for f in fin:
            del running[f]
            m, line, dt = f.result()
            print("%6.0fs %6.0fs %s" % (time.time() - t0, dt, line), flush=True)
            if line.startswith("OK"):
                done.add(m)
                last[m] = "ok"
                for u in sorted(users[m]):
                    if u in pending and deps[u] <= done:
                        push(u)
                for w in sorted(retry):
                    retry.discard(w)
                    last[w] = "retried"
                    push(w)
            else:
                last[m] = line
                retry.add(m)

left = sorted(set(mods) - done)
print("DAGBUILD_DONE: %d/%d compiled in %.0fs%s" % (len(done), len(mods), time.time() - t0,
                                                   "; never compiled: " + " ".join(left) if left else ""), flush=True)
sys.exit(1 if left else 0)
