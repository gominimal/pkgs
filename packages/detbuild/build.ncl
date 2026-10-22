let { BuildSpec, Local, OutputLib, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
{
  name = "detbuild",
  # A deterministic build-time environment for one build command:
  #   LD_PRELOAD=/usr/lib/minimal/libdetbuild.so <build command>
  # pins uname(2)'s kernel release/version and process entropy (a fixed-seed
  # stream behind getrandom/getentropy, the raw getrandom syscall, arc4random*
  # and reads of /dev/urandom). detbuild.c lists what leaked, from where, and
  # what it does NOT cover (AT_RANDOM, static and Go binaries, glibc-internal
  # entropy).
  #
  # The entropy it hands out is predictable, so: never a sandbox default, never
  # `export`ed, never on a command that uses the network (AGENTS.md,
  # "Preloading detbuild"; enforced by .github/scripts/detbuild_preload_guard.py).
  #
  # Deliberately depends on the toolchain's members rather than `toolchain`, so
  # it could become one of toolchain's runtime deps without a cycle.
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "detbuild.c" } | Local,
    base,
    binutils,
    gcc,
    glibc,
    linux_headers,
  ],
  runtime_deps = [
    glibc,
  ],
  cmd = "./build.sh",
  outputs = {
    lib = { glob = "usr/lib/minimal/libdetbuild.so" } | OutputLib,
  },
  tests = {
    uname =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test \"$(LD_PRELOAD=/usr/lib/minimal/libdetbuild.so uname -r)\" = 6.1.0-minimal"],
          ["/bin/bash", "-c", "test \"$(uname -r)\" != 6.1.0-minimal"],
        ],
      } | Test,
    # Every intercepted entropy entry point, called directly: two getrandom()
    # calls, the raw syscall, a read of /dev/urandom, arc4random_buf and
    # getentropy. Under the preload two runs must print the same six draws,
    # and no draw may repeat inside a run (a constant pattern, which the first
    # version of this shim returned on every call, fails here). Without the
    # preload two runs must differ, which shows the comparison can fail. Also:
    # 8 threads x 1000 draws never repeat, coreutils `head` reading
    # /dev/urandom repeats run to run, and a real file reads back unchanged.
    entropy_stream =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
          set -euo pipefail
          cd "$(mktemp -d)"
          cat > t.c << 'EOF'
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/random.h>
#include <sys/syscall.h>
#include <sys/utsname.h>
#include <unistd.h>

static void draw(const char *tag, const unsigned char *b, size_t n) {
    printf("draw %s ", tag);
    static const char hex[] = "0123456789abcdef";
    for (size_t i = 0; i < n; i++) { putchar(hex[b[i] >> 4]); putchar(hex[b[i] & 15]); }
    putchar('\n');
}

int main(void) {
    unsigned char a[16], b[16], c[16], d[16], e[16], f[16], big[300];
    if (getrandom(a, sizeof a, 0) != (ssize_t)sizeof a) return 2;
    if (getrandom(b, sizeof b, 0) != (ssize_t)sizeof b) return 3;
    if (syscall(SYS_getrandom, c, sizeof c, 0) != (long)sizeof c) return 4;
    int fd = open("/dev/urandom", O_RDONLY);
    if (fd < 0 || read(fd, d, sizeof d) != (ssize_t)sizeof d) return 5;
    close(fd);
    arc4random_buf(e, sizeof e);
    if (getentropy(f, sizeof f) != 0) return 6;
    errno = 0;
    if (getentropy(big, sizeof big) != -1 || errno != EIO) return 7;
    draw("getrandom1", a, sizeof a);
    draw("getrandom2", b, sizeof b);
    draw("syscall", c, sizeof c);
    draw("urandom", d, sizeof d);
    draw("arc4random", e, sizeof e);
    draw("getentropy", f, sizeof f);
    struct utsname u;
    if (uname(&u) != 0) return 8;
    printf("release %s\n", u.release);
    return 0;
}
EOF
          gcc -O1 -Wall -Werror t.c -o t
          L=/usr/lib/minimal/libdetbuild.so
          r1=$(LD_PRELOAD=$L ./t)
          r2=$(LD_PRELOAD=$L ./t)
          printf '%s\n' "$r1"
          [ "$r1" = "$r2" ] || { echo "FAIL: two preloaded runs differ:"; printf '%s\n' "$r2"; exit 1; }
          [ "$(printf '%s\n' "$r1" | grep -c '^draw ')" = 6 ] || { echo "FAIL: expected 6 draws"; exit 1; }
          rep=$(printf '%s\n' "$r1" | awk '/^draw /{print $3}' | sort | uniq -d)
          [ -z "$rep" ] || { echo "FAIL: a draw repeats inside one run: $rep"; exit 1; }
          printf '%s\n' "$r1" | grep -qx 'release 6.1.0-minimal' || { echo "FAIL: uname not pinned"; exit 1; }
          cat > th.c << 'EOF'
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/random.h>
static uint64_t v[8][1000];
static void *run(void *p) {
    uint64_t *o = p;
    for (int i = 0; i < 1000; i++) getrandom(&o[i], sizeof o[i], 0);
    return 0;
}
int main(void) {
    pthread_t t[8];
    for (int i = 0; i < 8; i++) pthread_create(&t[i], 0, run, v[i]);
    for (int i = 0; i < 8; i++) pthread_join(t[i], 0);
    for (int i = 0; i < 8; i++)
        for (int j = 0; j < 1000; j++) printf("v %llu\n", (unsigned long long)v[i][j]);
    return 0;
}
EOF
          gcc -O1 -Wall -Werror -pthread th.c -o th
          dup=$(LD_PRELOAD=$L ./th | sort | uniq -d | wc -l)
          [ "$dup" -eq 0 ] || { echo "FAIL: $dup repeated draws across 8 threads"; exit 1; }
          h1=$(LD_PRELOAD=$L head -c 16 /dev/urandom | od -An -tx1)
          h2=$(LD_PRELOAD=$L head -c 16 /dev/urandom | od -An -tx1)
          [ "$h1" = "$h2" ] || { echo "FAIL: /dev/urandom through head differs"; exit 1; }
          printf 'a real file\n' > real.txt
          [ "$(LD_PRELOAD=$L cat real.txt)" = "a real file" ] || { echo "FAIL: a real file read changed"; exit 1; }
          u1=$(./t | grep '^draw ')
          u2=$(./t | grep '^draw ')
          [ "$u1" != "$u2" ] || { echo "FAIL: control: unpreloaded runs are identical"; exit 1; }
          echo OK
"%,
          ],
        ],
      } | Test,
  },
} | BuildSpec
