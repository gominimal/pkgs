let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let patch = import "../patch/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "3.02" in
{
  name = "nasm",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://www.nasm.us/pub/nasm/releasebuilds/%{version}/nasm-%{version}.tar.xz",
      sha256 = "87336eba53b4acfe917424ab5d500d2b0054d9f5148d35c2273ccf2cfb712f0d",
      extract = true,
      strip_prefix = "nasm-%{version}",
    } | Source,
    # Security backport: CVE-2026-6067, heap overflow in the obj output
    # format. obj_directive() appends each GROUP member to the fixed
    # segs[GROUP_MAX] (256) array of a heap-allocated struct Group without a
    # bound, so a .asm naming more than 256 segments in a GROUP writes past
    # the allocation when assembled with -f obj (nasm issue #203). Upstream
    # fixed it in netwide-assembler/nasm commit 8890d723d0aa (2026-06-29),
    # one day after the nasm-3.02 tag; no release contains it yet. Verbatim
    # `git format-patch` of that commit, applied fail-closed in build.sh.
    # Drop it at the first release that contains 8890d723.
    { file = "CVE-2026-6067.patch" } | Local,
    base,
    make,
    patch,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    zlib,
  ],

  cmd = "./build.sh",
  outputs = {
    ndisasm = { glob = "usr/bin/ndisasm" } | OutputBin,
    nasm = { glob = "usr/bin/nasm" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-2-Clause",
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/nasm -v",

    # Assemble real code and disassemble it again with ndisasm.
    assemble_disassemble =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%"
              set -eu
              printf 'bits 64\nmov eax, 0x2a\nxor rdi, rdi\nsyscall\n' > t.asm
              /usr/bin/nasm -f bin -o t.bin t.asm
              out=$(/usr/bin/ndisasm -b 64 t.bin)
              echo "$out"
              [[ $out == *"mov eax,0x2a"* && $out == *"xor rdi,rdi"* && $out == *"syscall"* ]]
              /usr/bin/nasm -f elf64 -o t.o t.asm
              [ -s t.o ]
            "%,
          ],
        ],
      } | Test,

    # CVE-2026-6067 regression. A GROUP of 256 defined segments (GROUP_MAX)
    # still assembles with -f obj; a 257th member, and the hostile shape from
    # nasm issue #203 (thousands of members), must be refused with the
    # patch's "too many segments in a group" error and exit 1, not overflow
    # the heap. Unpatched nasm either crashes or exits 0 on both.
    cve_2026_6067_group_overflow =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%"
              set -u
              gen() { # gen <n-defined-segments> <n-group-members> <file>
                {
                  for ((i = 0; i < $1; i++)); do printf 'segment s%d\nnop\n' "$i"; done
                  printf 'group G'
                  for ((i = 0; i < $2; i++)); do printf ' s%d' "$i"; done
                  printf '\n'
                } > "$3"
              }
              gen 256 256 ok.asm
              /usr/bin/nasm -f obj -o ok.obj ok.asm || { echo "256-member group rejected"; exit 1; }
              [ -s ok.obj ] || { echo "no object for 256-member group"; exit 1; }
              for t in "257 257 over" "0 4000 hostile"; do
                set -- $t
                gen "$1" "$2" "$3.asm"
                /usr/bin/nasm -f obj -o "$3.obj" "$3.asm" 2> "$3.err"
                rc=$?
                err=$(< "$3.err")
                echo "$3: rc=$rc: $err"
                [ "$rc" -eq 1 ] || { echo "$3: want exit 1, got $rc"; exit 1; }
                [[ $err == *"too many segments in a group"* ]] || { echo "$3: missing error"; exit 1; }
              done
            "%,
          ],
        ],
      } | Test,
  },
} | BuildSpec
