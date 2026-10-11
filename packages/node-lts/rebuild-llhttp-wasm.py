#!/usr/bin/env python3
"""Regenerate undici's llhttp wasm from in-tree C and replace the shipped blobs.

  check-tree  node tree tripwires: pinned undici / npm-undici versions, no cjs lexer wasm
  build       pin build/wasm.js flags, compile llhttp{,_simd}.wasm twice, require identical bytes
  splice      decode the pinned shipped blob in a carrier, gate tables+features, replace it once
  census      every wasm carrier under the roots is an allowed sha or on an allowed path
  smoke       instantiate blobs under a built node and parse a POST; optional loopback fetch
  selftest    synthetic tree, proves every gate both passes and fails

stdlib only. Exit 1 on any mismatch.
"""
import argparse
import base64
import binascii
import collections
import fnmatch
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

MAGIC = b"\0asm\x01\0\0\0"

# deps/undici/src/build/wasm.js, identical in undici v6.26.0, v6.28.0, v7.29.0, v8.10.2.
WASM_JS_PINNED = (
    "let WASM_CFLAGS = process.env.WASM_CFLAGS || '--sysroot=/usr/share/wasi-sysroot -target wasm32-unknown-wasi'",
    "WASM_CFLAGS += ' -Ofast -fno-exceptions -fvisibility=hidden -mexec-model=reactor'",
    "WASM_LDFLAGS += ' -Wl,-error-limit=0 -Wl,-O3 -Wl,--lto-O3 -Wl,--strip-all'",
    "WASM_LDFLAGS += ' -Wl,--allow-undefined -Wl,--export-dynamic -Wl,--export-table'",
    "WASM_LDFLAGS += ' -Wl,--export=malloc -Wl,--export=free -Wl,--no-entry'",
    "const WASM_OPT_FLAGS = '-O4 --converge --strip-debug --strip-dwarf --strip-producers'",
)
CFLAGS = "-Ofast -fno-exceptions -fvisibility=hidden -mexec-model=reactor".split()
LDFLAGS = ("-Wl,-error-limit=0 -Wl,-O3 -Wl,--lto-O3 -Wl,--strip-all "
           "-Wl,--allow-undefined -Wl,--export-dynamic -Wl,--export-table "
           "-Wl,--export=malloc -Wl,--export=free -Wl,--no-entry").split()
# clang 17's "generic" cpu; clang 21's generic adds bulk-memory, multivalue, reference-types,
# nontrapping-fptoint and call-indirect-overlong, none of which the shipped blobs use.
CPU = ["-mcpu=mvp", "-mmutable-globals"]
LLHTTP_SRCS = ("api.c", "http.c", "llhttp.c")
GATE_ALLOWED = {"mutable-globals"}

B64_ALIGNED = re.compile(rb"AGFzbQ[A-Za-z0-9+/]*={0,2}")


class Fail(Exception):
    pass


def sha(b):
    return hashlib.sha256(b).hexdigest()


def log(msg):
    print(msg, flush=True)


# ---------------------------------------------------------------- wasm reader

def uleb(b, i, maxbytes=5):
    r = s = n = 0
    while True:
        if i >= len(b):
            raise Fail("truncated leb128")
        x = b[i]
        i += 1
        n += 1
        r |= (x & 0x7F) << s
        s += 7
        if x < 0x80:
            return r, i
        if n >= maxbytes:
            raise Fail("leb128 too long")


def uleb_len(b, i):
    v, j = uleb(b, i)
    return v, j, j - i


def sleb(b, i, maxbytes=10):
    r = s = n = 0
    while True:
        if i >= len(b):
            raise Fail("truncated sleb128")
        x = b[i]
        i += 1
        n += 1
        r |= (x & 0x7F) << s
        s += 7
        if x < 0x80:
            if x & 0x40:
                r -= 1 << s
            return r, i
        if n >= maxbytes:
            raise Fail("sleb128 too long")


def name(b, i):
    n, i = uleb(b, i)
    return b[i:i + n].decode("utf-8", "replace"), i + n


VALTYPES = {0x7F: "i32", 0x7E: "i64", 0x7D: "f32", 0x7C: "f64", 0x7B: "v128", 0x70: "funcref", 0x6F: "externref"}


def valtype(b, i, feats):
    t = b[i]
    if t not in VALTYPES:
        raise Fail("unknown valtype 0x%02x" % t)
    if t == 0x7B:
        feats["simd128"] += 1
    elif t in (0x70, 0x6F):
        feats["reference-types"] += 1
    return VALTYPES[t], i + 1


def limits(b, i, feats):
    flag = b[i]
    i += 1
    if flag & ~1:
        feats["limits-flag-%d" % flag] += 1
    _, i = uleb(b, i, 10)
    if flag & 1:
        _, i = uleb(b, i, 10)
    return i


def walk_ops(b, i, end, feats, const_expr=False):
    """Walk instructions in b[i:end]; count non-MVP features; unknown opcodes fail closed."""
    while i < end:
        op = b[i]
        i += 1
        if op == 0x0B and const_expr:
            return i
        if op in (0x00, 0x01, 0x05, 0x0B, 0x0F, 0x1A, 0x1B, 0xD1) or 0x45 <= op <= 0xBF:
            if op == 0xD1:
                feats["reference-types"] += 1
        elif op in (0x02, 0x03, 0x04):
            bt = b[i]
            if bt == 0x40 or bt in VALTYPES:
                if bt == 0x7B:
                    feats["simd128"] += 1
                i += 1
            else:
                _, i = sleb(b, i, 5)
                feats["multivalue"] += 1
        elif op in (0x0C, 0x0D, 0x10, 0x20, 0x21, 0x22, 0x23, 0x24):
            _, i = uleb(b, i)
        elif op in (0x25, 0x26, 0xD2):
            _, i = uleb(b, i)
            feats["reference-types"] += 1
        elif op == 0x0E:
            n, i = uleb(b, i)
            for _ in range(n + 1):
                _, i = uleb(b, i)
        elif op == 0x11:
            _, i = uleb(b, i)
            tbl, i, ln = uleb_len(b, i)
            if ln > 1:
                feats["call-indirect-overlong"] += 1
            if tbl != 0:
                feats["reference-types"] += 1
        elif op == 0x1C:
            n, i = uleb(b, i)
            for _ in range(n):
                _, i = valtype(b, i, feats)
            feats["reference-types"] += 1
        elif 0x28 <= op <= 0x3E:
            _, i = uleb(b, i)
            _, i = uleb(b, i, 10)
        elif op in (0x3F, 0x40):
            if b[i] != 0:
                feats["multi-memory"] += 1
            _, i = uleb(b, i)
        elif op == 0x41:
            _, i = sleb(b, i, 5)
        elif op == 0x42:
            _, i = sleb(b, i, 10)
        elif op == 0x43:
            i += 4
        elif op == 0x44:
            i += 8
        elif 0xC0 <= op <= 0xC4:
            feats["sign-ext"] += 1
        elif op == 0xD0:
            i += 1
            feats["reference-types"] += 1
        elif op == 0xFC:
            sub, i = uleb(b, i)
            if sub <= 7:
                feats["nontrapping-fptoint"] += 1
            elif sub <= 14:
                feats["bulk-memory"] += 1
                nimm = {8: 2, 9: 1, 10: 2, 11: 1, 12: 2, 13: 1, 14: 2}[sub]
                for _ in range(nimm):
                    _, i = uleb(b, i)
            elif sub <= 17:
                feats["reference-types"] += 1
                _, i = uleb(b, i)
            else:
                raise Fail("unknown opcode 0xfc %d" % sub)
        elif op == 0xFD:
            sub, i = uleb(b, i)
            feats["simd128"] += 1
            if sub <= 11 or sub in (92, 93):
                _, i = uleb(b, i)
                _, i = uleb(b, i, 10)
            elif sub in (12, 13):
                i += 16
            elif 21 <= sub <= 34:
                i += 1
            elif 84 <= sub <= 91:
                _, i = uleb(b, i)
                _, i = uleb(b, i, 10)
                i += 1
            elif sub >= 0x100:
                raise Fail("relaxed-simd opcode 0xfd %d" % sub)
        else:
            raise Fail("unknown opcode 0x%02x" % op)
    if const_expr:
        raise Fail("const expr without end")
    return i


def wasm_info(b):
    if b[:8] != MAGIC:
        raise Fail("not a wasm v1 module")
    feats = collections.Counter()
    types, funcs, imports, exports, ids = [], [], set(), set(), []
    import_funcs = []
    i = 8
    while i < len(b):
        sid = b[i]
        sz, i = uleb(b, i + 1)
        end = i + sz
        if end > len(b):
            raise Fail("section %d overruns module" % sid)
        s, j = b, i
        ids.append(sid)
        if sid == 0:
            nm, _ = name(s, j)
            feats["custom-section:" + nm] += 1
        elif sid == 1:
            n, j = uleb(s, j)
            for _ in range(n):
                if s[j] != 0x60:
                    raise Fail("unknown type form 0x%02x" % s[j])
                j += 1
                sig = []
                for _part in range(2):
                    k, j = uleb(s, j)
                    vs = []
                    for _ in range(k):
                        v, j = valtype(s, j, feats)
                        vs.append(v)
                    sig.append(vs)
                if len(sig[1]) > 1:
                    feats["multivalue"] += 1
                types.append("(%s)->(%s)" % (",".join(sig[0]), ",".join(sig[1])))
        elif sid == 2:
            n, j = uleb(s, j)
            for _ in range(n):
                mod, j = name(s, j)
                fld, j = name(s, j)
                kind = s[j]
                j += 1
                if kind == 0:
                    t, j = uleb(s, j)
                    import_funcs.append(t)
                    imports.add((mod, fld, "func", types[t]))
                elif kind == 1:
                    _, j = valtype(s, j, feats)
                    j = limits(s, j, feats)
                    imports.add((mod, fld, "table", ""))
                elif kind == 2:
                    j = limits(s, j, feats)
                    imports.add((mod, fld, "memory", ""))
                elif kind == 3:
                    v, j = valtype(s, j, feats)
                    if s[j]:
                        feats["mutable-globals"] += 1
                    j += 1
                    imports.add((mod, fld, "global", v))
                else:
                    raise Fail("unknown import kind %d" % kind)
        elif sid == 3:
            n, j = uleb(s, j)
            for _ in range(n):
                t, j = uleb(s, j)
                funcs.append(t)
        elif sid == 6:
            n, j = uleb(s, j)
            for _ in range(n):
                _, j = valtype(s, j, feats)
                j += 1
                j = walk_ops(s, j, end, feats, const_expr=True)
        elif sid == 7:
            n, j = uleb(s, j)
            for _ in range(n):
                nm, j = name(s, j)
                kind = s[j]
                idx, j = uleb(s, j + 1)
                kname = {0: "func", 1: "table", 2: "memory", 3: "global"}.get(kind)
                if kname is None:
                    raise Fail("unknown export kind %d" % kind)
                desc = ""
                if kind == 0:
                    ni = len(import_funcs)
                    desc = types[import_funcs[idx] if idx < ni else funcs[idx - ni]]
                exports.add((nm, kname, desc))
        elif sid == 9:
            n, j = uleb(s, j)
            for _ in range(n):
                flag, j = uleb(s, j)
                if flag != 0:
                    feats["elem-flags-%d" % flag] += 1
                    break
                j = walk_ops(s, j, end, feats, const_expr=True)
                k, j = uleb(s, j)
                for _ in range(k):
                    _, j = uleb(s, j)
        elif sid == 10:
            n, j = uleb(s, j)
            for _ in range(n):
                bsz, j = uleb(s, j)
                bend = j + bsz
                ng, j = uleb(s, j)
                for _ in range(ng):
                    _, j = uleb(s, j)
                    _, j = valtype(s, j, feats)
                j = walk_ops(s, j, bend, feats)
                if j != bend or s[bend - 1] != 0x0B:
                    raise Fail("function body did not parse to its end")
        elif sid == 11:
            n, j = uleb(s, j)
            for _ in range(n):
                flag, j = uleb(s, j)
                if flag != 0:
                    feats["data-flags-%d" % flag] += 1
                    break
                j = walk_ops(s, j, end, feats, const_expr=True)
                k, j = uleb(s, j)
                j += k
        elif sid == 12:
            feats["bulk-memory"] += 1
        elif sid in (4, 5, 8):
            pass
        else:
            feats["section-%d" % sid] += 1
        i = end
    return {"imports": imports, "exports": exports, "feats": feats, "ids": set(ids)}


def gate(shipped, rebuilt, label):
    """Rebuilt blob must present the shipped blob's tables and no extra wasm features."""
    a, r = wasm_info(shipped), wasm_info(rebuilt)
    errs = []
    for k in ("imports", "exports"):
        if a[k] != r[k]:
            errs.append("%s differ: missing %s, extra %s" % (k, sorted(a[k] - r[k]), sorted(r[k] - a[k])))
    simd = "simd128" in a["feats"]
    if simd != ("simd128" in r["feats"]):
        errs.append("simd128 use differs: shipped %s, rebuilt %s" % (simd, not simd))
    allowed = GATE_ALLOWED | ({"simd128"} if simd else set())
    extra = sorted(set(r["feats"]) - allowed)
    if extra:
        errs.append("features not allowed: %s" % ", ".join("%s x%d" % (f, r["feats"][f]) for f in extra))
    if r["ids"] - a["ids"]:
        errs.append("sections not in shipped blob: %s" % sorted(r["ids"] - a["ids"]))
    if errs:
        raise Fail("%s: gate failed\n  " % label + "\n  ".join(errs))
    log("@@GATE ok %s imports=%d exports=%d feats=%s" % (
        label, len(r["imports"]), len(r["exports"]), dict(r["feats"]) or "{}"))


# ---------------------------------------------------------------- carriers

def b64_decode(run):
    try:
        return base64.b64decode(run, validate=True)
    except (binascii.Error, ValueError):
        return None


def _misaligned_patterns():
    out = []
    for k in (1, 2):
        enc = base64.b64encode(b"\0" * k + MAGIC)
        lo, hi = 8 * k, 8 * k + 8 * len(MAGIC)
        first, last = -(-lo // 6), hi // 6 - 1
        out.append(enc[first:last + 1])
    return out


MISALIGNED = _misaligned_patterns()
OTHER_FORMS = (
    ("js-bytes", re.compile(rb"(?<![\w.])0\s*,\s*97\s*,\s*115\s*,\s*109\s*,\s*1\s*,\s*0\s*,\s*0\s*,\s*0(?![\w.])")),
    ("js-hexbytes", re.compile(rb"0x0?0\s*,\s*0x61\s*,\s*0x73\s*,\s*0x6d", re.I)),
    ("escaped", re.compile(rb"\\(?:x00|0|u0000)asm")),
)


def carriers(data):
    """Yield (kind, offset, decoded-or-None) for every wasm carrier form found in data."""
    for m in B64_ALIGNED.finditer(data):
        blob = b64_decode(m.group(0))
        if blob is not None and not blob.startswith(MAGIC):
            blob = None
        yield ("base64", m.start(), blob)
    for pat in MISALIGNED:
        start = 0
        while True:
            k = data.find(pat, start)
            if k < 0:
                break
            yield ("base64-misaligned", k, None)
            start = k + 1
    start = 0
    while True:
        k = data.find(MAGIC, start)
        if k < 0:
            break
        yield ("raw", k, data if k == 0 else None)
        start = k + 1
    for kind, rx in OTHER_FORMS:
        for m in rx.finditer(data):
            yield (kind, m.start(), None)


def splice(path, pin, rebuilt_path):
    data = open(path, "rb").read()
    new = open(rebuilt_path, "rb").read()
    hits = []
    for m in B64_ALIGNED.finditer(data):
        blob = b64_decode(m.group(0))
        if blob is not None and sha(blob) == pin:
            hits.append((m, blob))
    if len(hits) != 1:
        raise Fail("%s: shipped blob %s found %d times, want exactly 1" % (path, pin[:16], len(hits)))
    m, shipped = hits[0]
    gate(shipped, new, "%s <- %s" % (path, os.path.basename(rebuilt_path)))
    out = data[:m.start()] + base64.b64encode(new) + data[m.end():]
    got = collections.Counter(sha(b) for b in (b64_decode(x.group(0)) for x in B64_ALIGNED.finditer(out)) if b)
    if pin != sha(new) and got[pin]:
        raise Fail("%s: shipped blob still present after splice" % path)
    if got[sha(new)] < 1:
        raise Fail("%s: rebuilt blob not present after splice" % path)
    tmp = path + ".splice"
    with open(tmp, "wb") as f:
        f.write(out)
    shutil.copymode(path, tmp)
    os.replace(tmp, path)
    log("@@SPLICE ok %s shipped=%s rebuilt=%s%s" % (
        path, pin[:16], sha(new)[:16], " (identical to upstream)" if pin == sha(new) else ""))


def census(roots, allowed_shas, allow_paths, expect, allow_raw=None):
    allowed_shas = set(allowed_shas)
    allow_raw = allow_raw or {}
    fails, found, raws = [], collections.Counter(), collections.Counter()
    nfiles = 0
    for root in roots:
        if not os.path.exists(root):
            raise Fail("census root %s does not exist" % root)
        walk = [(os.path.dirname(root) or ".", [], [os.path.basename(root)])] if os.path.isfile(root) else os.walk(root)
        for d, dirs, files in walk:
            dirs.sort()
            for fn in sorted(files):
                p = os.path.normpath(os.path.join(d, fn))
                if os.path.islink(p) or not os.path.isfile(p):
                    continue
                nfiles += 1
                with open(p, "rb") as f:
                    data = f.read()
                path_ok = any(fnmatch.fnmatch(p, g) for g in allow_paths)
                for kind, off, blob in carriers(data):
                    h = sha(blob) if blob is not None else None
                    if h in allowed_shas:
                        if kind == "base64":
                            found[p] += 1
                        log("@@CENSUS ok %s %s:%d %s" % (kind, p, off, h[:16]))
                    elif kind == "raw" and blob is None and p in allow_raw:
                        # a bare header inside a binary (V8 byte constants), not an extractable module
                        raws[p] += 1
                        log("@@CENSUS raw-allowed %s:%d %s" % (p, off, data[max(0, off - 8):off + 24].hex()))
                    elif path_ok:
                        log("@@CENSUS allowed-path %s %s:%d %s" % (kind, p, off, (h or "-")[:16]))
                    else:
                        fails.append("%s %s:%d %s" % (kind, p, off, h or "undecodable/embedded"))
    for p, (n, at_least) in sorted(expect.items()):
        if found[p] < n if at_least else found[p] != n:
            fails.append("expected %d%s allowed blob(s) in %s, found %d" % (n, "+" if at_least else "", p, found[p]))
    for p, n in sorted(allow_raw.items()):
        if raws[p] != n:
            fails.append("expected %d raw header(s) in %s, found %d" % (n, p, raws[p]))
    if expect:
        for p in sorted(set(found) - set(expect)):
            if not any(fnmatch.fnmatch(p, g) for g in allow_paths):
                fails.append("allowed blob in unexpected file %s (x%d)" % (p, found[p]))
    if fails:
        raise Fail("census failed:\n  " + "\n  ".join(fails))
    log("@@CENSUS PASS files=%d blobs=%d" % (nfiles, sum(found.values())))


# ---------------------------------------------------------------- source pins and build

def json_version(path):
    with open(path) as f:
        return json.load(f)["version"]


def llhttp_version(path):
    txt = open(path).read()
    parts = []
    for k in ("MAJOR", "MINOR", "PATCH"):
        m = re.search(r"#define LLHTTP_VERSION_%s (\d+)" % k, txt)
        if not m:
            raise Fail("%s: no LLHTTP_VERSION_%s" % (path, k))
        parts.append(m.group(1))
    return ".".join(parts)


def pin_eq(what, got, want):
    if got != want:
        raise Fail("%s is %s, recipe pins %s" % (what, got, want))
    log("@@PIN ok %s = %s" % (what, got))


def check_tree(undici, npm_undici):
    pin_eq("deps/undici/src version", json_version("deps/undici/src/package.json"), undici)
    pin_eq("npm undici version", json_version("deps/npm/node_modules/undici/package.json"), npm_undici)
    lex = []
    for d, _, files in os.walk("deps"):
        for fn in files:
            if fn.endswith(".wasm") and ("lexer" in fn or "cjs-module-lexer" in d):
                lex.append(os.path.join(d, fn))
    if lex:
        raise Fail("cjs lexer wasm present: %s" % lex)
    log("@@PIN ok no cjs-module-lexer wasm")


def check_undici_src(src, version, llhttp):
    pin_eq("%s version" % src, json_version(os.path.join(src, "package.json")), version)
    pin_eq("%s llhttp" % src, llhttp_version(os.path.join(src, "deps/llhttp/include/llhttp.h")), llhttp)
    srcs = sorted(f for f in os.listdir(os.path.join(src, "deps/llhttp/src")) if f.endswith(".c"))
    if tuple(srcs) != LLHTTP_SRCS:
        raise Fail("%s/deps/llhttp/src/*.c is %s, want %s" % (src, srcs, list(LLHTTP_SRCS)))
    lines = {l.strip() for l in open(os.path.join(src, "build/wasm.js"))}
    missing = [l for l in WASM_JS_PINNED if l not in lines]
    if missing:
        raise Fail("%s/build/wasm.js flags drifted; missing:\n  %s" % (src, "\n  ".join(missing)))
    log("@@PIN ok %s/build/wasm.js flags" % src)


def compile_cmd(cc, sysroot, rt, out, simd):
    cmd = [cc, "--sysroot=" + sysroot, "-target", "wasm32-unknown-wasi"] + CPU + CFLAGS
    if simd:
        cmd.append("-msimd128")
    # clang's wasm driver runs wasm-opt after an -Ofast link whenever wasm-opt is on PATH.
    cmd += LDFLAGS + ["-nodefaultlibs", "--no-wasm-opt"]
    cmd += ["deps/llhttp/src/" + s for s in LLHTTP_SRCS] + ["-Ideps/llhttp/include", "-o", out, "-lc"]
    if rt:
        cmd.append(rt)
    return cmd


def build(src, outdir, version, llhttp, cc, sysroot, rt, dry_run):
    check_undici_src(src, version, llhttp)
    src = os.path.abspath(src)
    outdir = os.path.abspath(outdir)
    os.makedirs(outdir, exist_ok=True)
    for stem, simd in (("llhttp", False), ("llhttp_simd", True)):
        outs = []
        for n in (1, 2):
            out = os.path.join(outdir, "%s.%d.wasm" % (stem, n))
            cmd = compile_cmd(cc, sysroot, rt, out, simd) + ["-ffile-prefix-map=%s=." % src]
            log("@@BUILD " + " ".join(cmd))
            if dry_run:
                continue
            subprocess.run(cmd, cwd=src, check=True)
            outs.append(open(out, "rb").read())
            os.unlink(out)
        if dry_run:
            continue
        if outs[0] != outs[1]:
            raise Fail("%s.wasm differs between two identical compiles" % stem)
        with open(os.path.join(outdir, stem + ".wasm"), "wb") as f:
            f.write(outs[0])
        log("@@BUILD ok %s.wasm %d bytes sha256=%s" % (stem, len(outs[0]), sha(outs[0])))


SMOKE_JS = r"""
const fs = require('node:fs');
const req = Buffer.from('POST /x?y=1 HTTP/1.1\r\nHost: a\r\nContent-Length: 5\r\n\r\nhello');
for (const f of process.argv.slice(1)) {
  const seen = {};
  const span = (k) => (p, at, len) => { seen[k] = (seen[k] || '') + Buffer.from(mem.buffer, at, len).toString(); return 0; };
  let mem;
  const env = {
    wasm_on_message_begin: () => 0, wasm_on_status: span('status'),
    wasm_on_url: span('url'), wasm_on_header_field: span('hf'), wasm_on_header_value: span('hv'),
    wasm_on_headers_complete: () => 0, wasm_on_body: span('body'),
    wasm_on_message_complete: () => { seen.done = true; return 0; },
  };
  const { exports: e } = new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(f)), { env });
  mem = e.memory;
  e._initialize();
  const p = e.llhttp_alloc(1);
  const buf = e.malloc(req.length);
  new Uint8Array(mem.buffer, buf, req.length).set(req);
  const rc = e.llhttp_execute(p, buf, req.length);
  if (rc !== 0 || seen.url !== '/x?y=1' || seen.body !== 'hello' || !seen.done) {
    console.error('@@SMOKE FAIL', f, rc, JSON.stringify(seen)); process.exit(1);
  }
  e.free(buf); e.llhttp_free(p);
  console.log('@@SMOKE ok llhttp_execute', f);
}
"""

FETCH_JS = r"""
const http = require('node:http');
const s = http.createServer((q, r) => { let b = ''; q.on('data', (d) => b += d); q.on('end', () => r.end('echo:' + b)); });
s.on('error', (e) => {
  if (['EPERM', 'EACCES', 'EADDRNOTAVAIL'].includes(e.code)) { console.log('@@SMOKE fetch SKIP no loopback', e.code); process.exit(0); }
  console.error('@@SMOKE FAIL listen', e); process.exit(1);
});
s.listen(0, '127.0.0.1', async () => {
  try {
    const r = await fetch(`http://127.0.0.1:${s.address().port}/x`, { method: 'POST', body: 'hello' });
    const t = await r.text();
    if (t !== 'echo:hello') throw new Error('body ' + t);
    console.log('@@SMOKE ok fetch'); s.close();
  } catch (e) { console.error('@@SMOKE FAIL fetch', e); process.exit(1); }
});
"""


def smoke(node, wasms, fetch, requires):
    subprocess.run([node, "-e", SMOKE_JS] + list(wasms), check=True)
    for r in requires:
        subprocess.run([node, "-e", "require(%s); console.log('@@SMOKE ok require', %s)" % (
            json.dumps(os.path.abspath(r)), json.dumps(r))], check=True)
    if fetch:
        subprocess.run([node, "-e", FETCH_JS], check=True)


# ---------------------------------------------------------------- selftest

def _sec(sid, body):
    return bytes([sid]) + _leb(len(body)) + body


def _leb(n):
    out = bytearray()
    while True:
        x = n & 0x7F
        n >>= 7
        if n:
            out.append(x | 0x80)
        else:
            out.append(x)
            return bytes(out)


def _str(s):
    return _leb(len(s)) + s.encode()


def _vec(items):
    return _leb(len(items)) + b"".join(items)


def mkwasm(imports=("wasm_on_url",), exports=("malloc", "llhttp_execute"), body=b"\x41\x00\x0b", simd=False):
    """Tiny module: imports env.<name> (i32,i32,i32)->i32, exports memory + funcs sharing one body."""
    t3 = b"\x60\x03\x7f\x7f\x7f\x01\x7f"
    types = _sec(1, _vec([t3]))
    imp = _sec(2, _vec([_str("env") + _str(n) + b"\x00\x00" for n in imports]))
    nf = len(exports)
    fn = _sec(3, _vec([b"\x00"] * nf))
    mem = _sec(5, _vec([b"\x00\x01"]))
    exp = _sec(7, _vec([_str("memory") + b"\x02\x00"] +
                       [_str(n) + b"\x00" + _leb(len(imports) + k) for k, n in enumerate(exports)]))
    if simd:
        body = b"\xfd\x0c" + b"\x00" * 16 + b"\x1a" + body
    code1 = _leb(0) + body
    code = _sec(10, _vec([_leb(len(code1)) + code1] * nf))
    return MAGIC + types + imp + fn + mem + exp + code


def _expect_fail(fn, *a, contains=""):
    try:
        fn(*a)
    except Fail as e:
        if contains and contains not in str(e):
            raise AssertionError("failed for the wrong reason: %s" % e)
        log("  (expected failure: %s)" % str(e).splitlines()[0])
        return
    raise AssertionError("%s%r should have failed" % (fn.__name__, a))


def selftest():
    shipped = mkwasm()
    shipped_simd = mkwasm(simd=True)
    good = mkwasm(body=b"\x41\x01\x0b")
    good_simd = mkwasm(body=b"\x41\x01\x0b", simd=True)
    bad_import = mkwasm(imports=("wasm_on_url", "__multi3"), body=b"\x41\x02\x0b")
    bad_export = mkwasm(exports=("malloc",), body=b"\x41\x03\x0b")
    bad_bulk = mkwasm(body=b"\x41\x00\x41\x00\x41\x00\xfc\x0b\x00\x41\x00\x0b")
    bad_overlong = mkwasm(body=b"\x41\x00\x41\x00\x41\x00\x41\x00\x11\x00\x80\x80\x80\x80\x00\x0b")
    bad_unknown = mkwasm(body=b"\x06\x40\x0b\x41\x00\x0b")
    bad_signext = mkwasm(body=b"\x41\x00\xc0\x0b")
    pins = {k: sha(v) for k, v in (("plain", shipped), ("simd", shipped_simd))}

    log("selftest: gate")
    gate(shipped, good, "good")
    _expect_fail(gate, shipped, bad_signext, "sign-ext", contains="sign-ext")
    gate(shipped_simd, good_simd, "good simd")
    _expect_fail(gate, shipped, bad_import, "bad import", contains="imports differ")
    _expect_fail(gate, shipped, bad_export, "bad export", contains="exports differ")
    _expect_fail(gate, shipped, bad_bulk, "bulk-memory", contains="bulk-memory")
    _expect_fail(gate, shipped, bad_overlong, "overlong", contains="call-indirect-overlong")
    _expect_fail(gate, shipped, good_simd, "simd in plain", contains="simd128")
    _expect_fail(gate, shipped_simd, good, "no simd in simd", contains="simd128")
    _expect_fail(wasm_info, bad_unknown, contains="unknown opcode")
    _expect_fail(wasm_info, b"\0asm\x02\0\0\0", contains="not a wasm v1")

    cwd = os.getcwd()
    with tempfile.TemporaryDirectory() as td:
        def tree():
            root = os.path.join(td, "t%d" % len(os.listdir(td)))
            u = os.path.join(root, "deps/undici")
            n = os.path.join(root, "deps/npm/node_modules/undici/lib/llhttp")
            os.makedirs(n)
            os.makedirs(u, exist_ok=True)
            os.makedirs(os.path.join(root, "deps/v8/third_party/wasm-api/example"))
            with open(os.path.join(u, "undici.js"), "w") as f:
                f.write('var wasmBase64 = "%s";\n// next\nvar wasmBase64 = "%s";\n' % (
                    base64.b64encode(shipped).decode(), base64.b64encode(shipped_simd).decode()))
            with open(os.path.join(n, "llhttp-wasm.js"), "w") as f:
                f.write("module.exports = Buffer.from('%s', 'base64')\n" % base64.b64encode(shipped).decode())
            with open(os.path.join(root, "deps/v8/third_party/wasm-api/example/hello.wasm"), "wb") as f:
                f.write(mkwasm(exports=("run",)))
            for name, b in (("good.wasm", good), ("good_simd.wasm", good_simd), ("bad_bulk.wasm", bad_bulk)):
                with open(os.path.join(root, name), "wb") as f:
                    f.write(b)
            return root

        def full_pass(root):
            os.chdir(root)
            splice("deps/undici/undici.js", pins["plain"], "good.wasm")
            splice("deps/undici/undici.js", pins["simd"], "good_simd.wasm")
            splice("deps/npm/node_modules/undici/lib/llhttp/llhttp-wasm.js", pins["plain"], "good.wasm")
            census(["deps"], [sha(good), sha(good_simd)], ["deps/v8/third_party/wasm-api/example/*"],
                   {"deps/undici/undici.js": (2, False), "deps/npm/node_modules/undici/lib/llhttp/llhttp-wasm.js": (1, False)})

        try:
            log("selftest: splice + census pass")
            full_pass(tree())

            log("selftest: N+ expectations")
            census(["deps"], [sha(good), sha(good_simd)], ["deps/v8/third_party/wasm-api/example/*"],
                   {"deps/undici/undici.js": (1, True), "deps/npm/node_modules/undici/lib/llhttp/llhttp-wasm.js": (1, True)})
            _expect_fail(census, ["deps"], [sha(good), sha(good_simd)], ["deps/v8/third_party/wasm-api/example/*"],
                         {"deps/undici/undici.js": (3, True), "deps/npm/node_modules/undici/lib/llhttp/llhttp-wasm.js": (1, True)},
                         contains="expected 3+")

            log("selftest: splice rejects")
            root = tree()
            os.chdir(root)
            _expect_fail(splice, "deps/undici/undici.js", "0" * 64, "good.wasm", contains="found 0 times")
            _expect_fail(splice, "deps/undici/undici.js", pins["plain"], "bad_bulk.wasm", contains="bulk-memory")
            before = open("deps/undici/undici.js", "rb").read()
            _expect_fail(splice, "deps/undici/undici.js", pins["plain"], "good_simd.wasm", contains="simd128")
            assert open("deps/undici/undici.js", "rb").read() == before, "failed splice modified the carrier"
            with open("deps/undici/undici.js", "a") as f:
                f.write('var again = "%s";\n' % base64.b64encode(shipped).decode())
            _expect_fail(splice, "deps/undici/undici.js", pins["plain"], "good.wasm", contains="found 2 times")

            log("selftest: census rejects")
            for label, mutate, why in (
                ("unspliced shipped blob", lambda: None, "base64 deps/undici/undici.js"),
                ("rogue base64", lambda: open("deps/rogue.js", "w").write(
                    "x='%s'" % base64.b64encode(mkwasm(exports=("evil",))).decode()), "deps/rogue.js"),
                ("raw wasm", lambda: open("deps/x.wasm", "wb").write(mkwasm(exports=("evil",))), "raw deps/x.wasm"),
                ("embedded raw", lambda: open("deps/x.bin", "wb").write(b"ELF..." + MAGIC + b"..."), "raw deps/x.bin"),
                ("misaligned base64", lambda: open("deps/m.js", "w").write(
                    "y='%s'" % base64.b64encode(b"Q" + mkwasm()).decode()), "base64-misaligned deps/m.js"),
                ("js byte array", lambda: open("deps/a.js", "w").write("[0, 97, 115, 109, 1, 0, 0, 0]"), "js-bytes"),
                ("truncated base64", lambda: open("deps/t.js", "w").write("z='AGFzbQEAAAABJw'"), "undecodable"),
                ("expect count", lambda: open("deps/undici/undici.js", "a").write(
                    "var dup = '%s';\n" % base64.b64encode(good).decode()), "expected 2 allowed blob(s)"),
                ("unexpected carrier", lambda: open("deps/copy.js", "w").write(
                    "c='%s'" % base64.b64encode(good).decode()), "unexpected file deps/copy.js"),
            ):
                log("  case: " + label)
                root = tree()
                os.chdir(root)
                if label != "unspliced shipped blob":
                    full_pass(root)
                mutate()
                _expect_fail(census, ["deps"], [sha(good), sha(good_simd)],
                             ["deps/v8/third_party/wasm-api/example/*"],
                             {"deps/undici/undici.js": (2, False),
                              "deps/npm/node_modules/undici/lib/llhttp/llhttp-wasm.js": (1, False)},
                             contains=why)

            log("selftest: census allow-raw is an exact count")
            root = tree()
            os.chdir(root)
            full_pass(root)
            open("deps/x.bin", "wb").write(b"ELF..." + MAGIC + b"........" + MAGIC + b"...")
            exp = {"deps/undici/undici.js": (2, False), "deps/npm/node_modules/undici/lib/llhttp/llhttp-wasm.js": (1, False)}
            census(["deps"], [sha(good), sha(good_simd)], ["deps/v8/third_party/wasm-api/example/*"], exp, {"deps/x.bin": 2})
            _expect_fail(census, ["deps"], [sha(good), sha(good_simd)], ["deps/v8/third_party/wasm-api/example/*"], exp,
                         {"deps/x.bin": 1}, contains="expected 1 raw header(s)")
            open("deps/x.wasm", "wb").write(mkwasm(exports=("evil",)))
            _expect_fail(census, ["deps"], [sha(good), sha(good_simd)], ["deps/v8/third_party/wasm-api/example/*"], exp,
                         {"deps/x.wasm": 1}, contains="raw deps/x.wasm")

            log("selftest: source pins")
            src = os.path.join(td, "undici-src")
            os.makedirs(os.path.join(src, "deps/llhttp/src"))
            os.makedirs(os.path.join(src, "deps/llhttp/include"))
            os.makedirs(os.path.join(src, "build"))
            json.dump({"version": "8.10.2"}, open(os.path.join(src, "package.json"), "w"))
            open(os.path.join(src, "deps/llhttp/include/llhttp.h"), "w").write(
                "#define LLHTTP_VERSION_MAJOR 9\n#define LLHTTP_VERSION_MINOR 3\n#define LLHTTP_VERSION_PATCH 1\n")
            for s in LLHTTP_SRCS:
                open(os.path.join(src, "deps/llhttp/src", s), "w").write("")
            open(os.path.join(src, "build/wasm.js"), "w").write("\n".join(WASM_JS_PINNED) + "\n")
            build(src, os.path.join(td, "out"), "8.10.2", "9.3.1", "clang", "/usr/share/wasi-sysroot", None, True)
            _expect_fail(check_undici_src, src, "8.10.3", "9.3.1", contains="recipe pins 8.10.3")
            _expect_fail(check_undici_src, src, "8.10.2", "9.3.0", contains="recipe pins 9.3.0")
            open(os.path.join(src, "deps/llhttp/src/extra.c"), "w").write("")
            _expect_fail(check_undici_src, src, "8.10.2", "9.3.1", contains="src/*.c")
            os.unlink(os.path.join(src, "deps/llhttp/src/extra.c"))
            open(os.path.join(src, "build/wasm.js"), "w").write(
                "\n".join(WASM_JS_PINNED).replace("-Ofast", "-O3") + "\n")
            _expect_fail(check_undici_src, src, "8.10.2", "9.3.1", contains="flags drifted")
        finally:
            os.chdir(cwd)

    cmd = compile_cmd("clang", "/s", None, "o.wasm", True)
    for f in CFLAGS + LDFLAGS + CPU + ["-msimd128", "-mexec-model=reactor", "-lc", "--no-wasm-opt"]:
        assert f in cmd, f
    log("@@SELFTEST PASS")


# ---------------------------------------------------------------- cli

def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sp = ap.add_subparsers(dest="cmd", required=True)
    p = sp.add_parser("check-tree")
    p.add_argument("--undici", required=True)
    p.add_argument("--npm-undici", required=True)
    p = sp.add_parser("build")
    p.add_argument("src")
    p.add_argument("outdir")
    p.add_argument("--version", required=True)
    p.add_argument("--llhttp", required=True)
    p.add_argument("--cc", default="clang")
    p.add_argument("--sysroot", default="/usr/lib/wasi", help="packages/wasi-libc install root")
    p.add_argument("--rt", help="explicit wasm32 builtins archive, if llhttp needs one")
    p.add_argument("--dry-run", action="store_true")
    p = sp.add_parser("splice")
    p.add_argument("carrier")
    p.add_argument("shipped_sha")
    p.add_argument("rebuilt")
    p = sp.add_parser("census")
    p.add_argument("roots", nargs="+")
    p.add_argument("-C", dest="chdir")
    p.add_argument("--wasm", action="append", default=[], help="rebuilt blob whose sha is allowed")
    p.add_argument("--allow-path", action="append", default=[], help="fnmatch glob, relative to -C")
    p.add_argument("--expect", action="append", default=[], help="PATH=N (exact) or PATH=N+ allowed blobs in PATH")
    p.add_argument("--allow-raw", action="append", default=[], help="PATH=N: exactly N undecodable raw wasm headers in PATH")
    p = sp.add_parser("smoke")
    p.add_argument("node")
    p.add_argument("wasm", nargs="+")
    p.add_argument("--fetch", action="store_true")
    p.add_argument("--require", action="append", default=[])
    sp.add_parser("selftest")
    a = ap.parse_args(argv)
    try:
        if a.cmd == "check-tree":
            check_tree(a.undici, a.npm_undici)
        elif a.cmd == "build":
            build(a.src, a.outdir, a.version, a.llhttp, a.cc, a.sysroot, a.rt, a.dry_run)
        elif a.cmd == "splice":
            splice(a.carrier, a.shipped_sha, a.rebuilt)
        elif a.cmd == "census":
            shas = [sha(open(w, "rb").read()) for w in a.wasm]
            if a.chdir:
                os.chdir(a.chdir)
            expect = {}
            for e in a.expect:
                k, _, v = e.rpartition("=")
                expect[os.path.normpath(k)] = (int(v.rstrip("+")), v.endswith("+"))
            raw = {}
            for e in a.allow_raw:
                k, _, v = e.rpartition("=")
                raw[os.path.normpath(k)] = int(v)
            census(a.roots, shas, a.allow_path, expect, raw)
        elif a.cmd == "smoke":
            smoke(a.node, a.wasm, a.fetch, a.require)
        elif a.cmd == "selftest":
            selftest()
    except Fail as e:
        print("ERROR: %s" % e, file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as e:
        print("ERROR: %s" % e, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
