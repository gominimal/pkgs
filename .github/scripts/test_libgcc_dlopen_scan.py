#!/usr/bin/env python3
"""Unit tests for libgcc_dlopen_scan.py (no network). Run: python3 -m unittest test_libgcc_dlopen_scan"""

import io
import os
import struct
import sys
import tarfile
import tempfile
import tomllib
import unittest
from contextlib import redirect_stderr, redirect_stdout
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import libgcc_dlopen_scan as s  # noqa: E402


def elf(undefined=(), defined=(), cls=2, data=1) -> bytes:
    """A minimal ELF with a .dynsym/.dynstr pair: `undefined` names get
    st_shndx 0 (imports), `defined` names st_shndx 1 (exports)."""
    names = list(undefined) + list(defined)
    strtab = b"\0"
    offs = []
    for n in names:
        offs.append(len(strtab))
        strtab += n.encode() + b"\0"
    syms = b"\0" * 24  # STN_UNDEF
    for i, off in enumerate(offs):
        shndx = 0 if i < len(undefined) else 1
        syms += struct.pack("<IBBHQQ", off, 0x12, 0, shndx, 0, 0)
    str_off = 64
    sym_off = str_off + len(strtab)
    sh_off = sym_off + len(syms)
    shdrs = b"\0" * 64  # SHN_UNDEF
    shdrs += struct.pack("<IIQQQQIIQQ", 0, 3, 0, 0, str_off, len(strtab), 0, 0, 1, 0)  # [1] .dynstr
    shdrs += struct.pack("<IIQQQQIIQQ", 0, 11, 0, 0, sym_off, len(syms), 1, 1, 8, 24)  # [2] .dynsym
    ident = b"\x7fELF" + bytes([cls, data, 1]) + b"\0" * 9
    hdr = ident + struct.pack("<HHIQQQIHHHHHH", 3, 62, 1, 0, 0, sh_off, 0, 64, 56, 0, 64, 3, 0)
    assert len(hdr) == 64
    return hdr + strtab + syms + shdrs


def tar(files: dict[str, bytes]) -> io.BytesIO:
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w") as t:
        for name, data in files.items():
            ti = tarfile.TarInfo(name)
            ti.size = len(data)
            t.addfile(ti, io.BytesIO(data))
    buf.seek(0)
    return buf


class Elf(unittest.TestCase):
    def test_imports_found(self):
        self.assertEqual(s.elf_imports(elf(["pthread_exit", "malloc", "backtrace"])), {"pthread_exit", "backtrace"})

    def test_thrd_exit_and_cancel(self):
        self.assertEqual(s.elf_imports(elf(["thrd_exit", "pthread_cancel"])), {"thrd_exit", "pthread_cancel"})

    def test_negative_control_defined_symbol_is_not_an_import(self):
        # libc itself DEFINES pthread_exit; only an undefined reference counts.
        self.assertEqual(s.elf_imports(elf(["malloc"], defined=["pthread_exit", "backtrace"])), set())

    def test_negative_control_similar_names(self):
        self.assertEqual(s.elf_imports(elf(["pthread_exit_np", "__backtrace", "pthread_cancelx"])), set())

    def test_not_elf64le_is_skipped(self):
        self.assertIsNone(s.elf_imports(elf(["pthread_exit"], cls=1)))
        self.assertIsNone(s.elf_imports(elf(["pthread_exit"], data=2)))
        self.assertIsNone(s.elf_imports(b"#!/bin/sh\n"))

    def test_truncated_elf_raises(self):
        with self.assertRaises(Exception):
            s.elf_imports(elf(["pthread_exit"])[:100])


class Tar(unittest.TestCase):
    def test_scan_tar(self):
        hits, elfs, bad = s.scan_tar(
            tar(
                {
                    "./usr/lib/libx.so.1": elf(["pthread_exit"]),
                    "./usr/bin/y": elf(["printf"]),
                    "./usr/share/doc": b"text",
                    "./usr/lib/broken.so": elf(["pthread_exit"])[:100],
                }
            )
        )
        self.assertEqual(hits, {"usr/lib/libx.so.1": {"pthread_exit"}})
        self.assertEqual((elfs, bad), (2, 1))


FOUND = {
    "python": {
        "amd64": {"usr/lib/libpython3.so": {"pthread_exit", "backtrace"}},
        "arm64": {"usr/lib/libpython3.so": {"pthread_exit", "backtrace"}},
    },
    "redis": {"amd64": {"usr/bin/redis-server": {"pthread_cancel"}}},
}
ARCHES = ["amd64", "arm64"]


class Compare(unittest.TestCase):
    def listed(self):
        return tomllib.loads(s.render(FOUND))["importers"]

    def test_render_round_trips(self):
        listed = self.listed()
        self.assertEqual(listed["python"]["symbols"], ["backtrace", "pthread_exit"])
        self.assertEqual(listed["redis"]["arches"], ["amd64"])
        self.assertEqual(s.compare(FOUND, listed, {}, ARCHES), ([], []))

    def test_render_header_names_the_fix(self):
        self.assertIn('subsetOf gcc-runtime ["libgcc"]', s.render(FOUND))

    def test_negative_control_missing_importer(self):
        listed = self.listed()
        del listed["redis"]
        problems, _ = s.compare(FOUND, listed, {}, ARCHES)
        self.assertEqual(len(problems), 1)
        self.assertIn("missing: `redis`", problems[0])

    def test_negative_control_stale_entry(self):
        listed = self.listed()
        listed["bash"] = {"symbols": ["backtrace"], "arches": ARCHES}
        problems, _ = s.compare(FOUND, listed, {}, ARCHES)
        self.assertEqual(len(problems), 1)
        self.assertIn("stale: `bash`", problems[0])

    def test_unscanned_entry_is_not_stale(self):
        listed = self.listed()
        listed["bash"] = {"symbols": ["backtrace"], "arches": ARCHES}
        problems, notes = s.compare(FOUND, listed, {"bash": set(ARCHES)}, ARCHES)
        self.assertEqual(problems, [])
        self.assertIn("unverified", notes[0])

    def test_negative_control_changed_symbols(self):
        listed = self.listed()
        listed["python"]["symbols"] = ["pthread_exit"]
        problems, _ = s.compare(FOUND, listed, {}, ARCHES)
        self.assertIn("changed: `python` symbols", problems[0])

    def test_negative_control_changed_arches(self):
        listed = self.listed()
        listed["redis"]["arches"] = ARCHES
        problems, _ = s.compare(FOUND, listed, {}, ARCHES)
        self.assertIn("changed: `redis` arches", problems[0])

    def test_arch_without_artifact_does_not_contradict(self):
        listed = self.listed()
        listed["redis"]["arches"] = ARCHES
        problems, _ = s.compare(FOUND, listed, {"redis": {"arm64"}}, ARCHES)
        self.assertEqual(problems, [])

    def test_evidence_paths_are_not_compared(self):
        listed = self.listed()
        listed["python"]["elfs"] = ["usr/lib/libpython3.15.so"]
        self.assertEqual(s.compare(FOUND, listed, {}, ARCHES)[0], [])


class Write(unittest.TestCase):
    """main() end to end with the index and the artifact fetch faked: --write
    and the regenerated block in check mode must keep what the scan could not
    read, as check mode's compare() does (pkgs#1545 review)."""

    def run_main(self, listed: dict, unscanned_pkgs: set[str], write: bool, scanned=FOUND):
        d = tempfile.mkdtemp()
        data = os.path.join(d, "importers.toml")
        with open(data, "w", encoding="utf-8") as f:
            f.write(s.render({}) + "".join(
                f'\n[importers."{k}"]\nsymbols = {v["symbols"]!r}\narches = {v["arches"]!r}\n'
                f'elfs = {v.get("elfs", [])!r}\nelf_count = {v.get("elf_count", 0)}\n'.replace("'", '"')
                for k, v in sorted(listed.items())
            ))
        pkgs = sorted(set(scanned) | set(listed) | {"zlib", "curl"})
        entries = {a: [{"name": p, "spec_hash": f"{a}-{p}"} for p in pkgs] for a in ARCHES}
        dumps = []
        for a, es in entries.items():
            dp = os.path.join(d, f"{a}.json")
            with open(dp, "w", encoding="utf-8") as f:
                f.write(__import__("json").dumps(es))
            dumps += ["--dump", f"{a}={dp}"]
        index = {f"{a}-{p}": f"{a}-{p}" for a in ARCHES for p in pkgs
                 if not (p in unscanned_pkgs or (p == "redis-arm" and a == "arm64"))}

        def scan(_base, sha):
            a, p = sha.split("-", 1)
            return scanned.get(p, {}).get(a, {}), 1, 0

        argv = dumps + ["--data", data, "--max-miss-fraction", "0.9"] + (["--write"] if write else [])
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.object(s, "load_index", return_value=index), mock.patch.object(
            s, "scan_artifact", side_effect=scan
        ), redirect_stdout(out), redirect_stderr(err):
            code = s.main(argv)
        return code, open(data, encoding="utf-8").read(), out.getvalue() + err.getvalue()

    BASH = {"symbols": ["backtrace"], "arches": ARCHES, "elfs": ["usr/bin/bash"], "elf_count": 1}

    def test_write_keeps_unscanned_listed_entry(self):
        listed = tomllib.loads(s.render(FOUND))["importers"]
        listed["bash"] = self.BASH
        code, text, out = self.run_main(listed, {"bash"}, write=True)
        got = tomllib.loads(text)["importers"]
        self.assertIn("bash", got, out)
        self.assertEqual(got["bash"]["arches"], ARCHES)
        self.assertEqual(got["bash"]["elfs"], ["usr/bin/bash"])
        # and check mode on the written file agrees: nothing stale, nothing missing
        code, _, out = self.run_main(got, {"bash"}, write=False)
        self.assertEqual(code, 0, out)

    def test_negative_control_write_drops_scanned_stale_entry(self):
        listed = tomllib.loads(s.render(FOUND))["importers"]
        listed["bash"] = self.BASH
        code, text, out = self.run_main(listed, set(), write=True)
        self.assertEqual(code, 1, out)
        self.assertNotIn("bash", tomllib.loads(text)["importers"])

    def test_regenerated_block_keeps_unscanned_listed_entry(self):
        listed = tomllib.loads(s.render(FOUND))["importers"]
        listed["bash"] = self.BASH
        del listed["redis"]  # a real problem, so the regenerated block prints
        code, _, out = self.run_main(listed, {"bash"}, write=False)
        self.assertEqual(code, 1, out)
        block = out.split("```toml\n", 1)[1].split("```", 1)[0]
        got = tomllib.loads(block)["importers"]
        self.assertIn("bash", got)
        self.assertIn("redis", got)

    def test_carried_keeps_listed_arch_without_artifact(self):
        listed = tomllib.loads(s.render(FOUND))["importers"]
        listed["redis"]["arches"] = ARCHES
        keep, extra = s.carried(FOUND, listed, {"redis": {"arm64"}}, ARCHES)
        self.assertEqual(keep, {})
        self.assertEqual(extra, {"redis": {"arm64"}})
        got = tomllib.loads(s.render(FOUND, keep, extra))["importers"]
        self.assertEqual(got["redis"]["arches"], ARCHES)
        self.assertEqual(s.compare(FOUND, got, {"redis": {"arm64"}}, ARCHES)[0], [])


if __name__ == "__main__":
    unittest.main()
