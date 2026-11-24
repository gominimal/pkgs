#!/usr/bin/env python3
"""Unit tests for libgcc_dlopen_scan.py (no network). Run: python3 -m unittest test_libgcc_dlopen_scan"""

import io
import os
import struct
import sys
import tarfile
import tomllib
import unittest

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


if __name__ == "__main__":
    unittest.main()
