let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "4.33" in
{
  name = "libev",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # Mirror of http://dist.schmorp.de/libev/Attic/libev-%{version}.tar.gz (libev is
      # developed in CVS, no GitHub repo). The bytes are Debian's
      # libev_%{version}.orig.tar.gz; the sha256 matches Homebrew's libev formula, which
      # fetches the upstream URL.
      url = "gs://minimal-staging-archives/libev-%{version}.tar.gz",
      sha256 = "507eb7b8d1015fbec5b935f34ebed15bf346bed04a11ab82b8eee848c4205aea",
      extract = true,
      strip_prefix = "libev-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [glibc],
  cmd = "./build.sh",
  build_args = { include version },
  outputs = {
    libs = { glob = "usr/lib/libev.so*" } | OutputLib,
    includes = { glob = "usr/include/ev*.h" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      # LICENSE: BSD 2-clause, or "alternatively" GPL-2.0-or-later, at the recipient's
      # choice. Both are offered; we redistribute under the BSD-2-Clause terms.
      license_spdx = "BSD-2-Clause OR GPL-2.0-or-later",
      repology_project = "libev",
    } | Attrs,

  tests = {
    # Link against libev and run its loop: a pipe watcher fires on a write and a timer
    # fires after it, both through the default (epoll) backend.
    event_loop =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              cat > t.c <<'EOF'
              #include <ev.h>
              #include <stdio.h>
              #include <unistd.h>
              static int got_io, got_timer;
              static void io_cb(EV_P_ ev_io *w, int revents) {
                char c; if (read(w->fd, &c, 1) == 1 && c == 'x') got_io = 1;
                ev_io_stop(EV_A_ w);
              }
              static void timer_cb(EV_P_ ev_timer *w, int revents) { got_timer = 1; ev_break(EV_A_ EVBREAK_ALL); }
              int main(void) {
                if (ev_version_major() != EV_VERSION_MAJOR || ev_version_minor() != EV_VERSION_MINOR) return 1;
                struct ev_loop *loop = EV_DEFAULT;
                if (!(ev_backend(loop) & EVBACKEND_EPOLL)) { fprintf(stderr, "backend %u\n", ev_backend(loop)); return 1; }
                int p[2]; if (pipe(p) != 0) return 1;
                ev_io io; ev_io_init(&io, io_cb, p[0], EV_READ); ev_io_start(loop, &io);
                ev_timer t; ev_timer_init(&t, timer_cb, 0.05, 0.); ev_timer_start(loop, &t);
                if (write(p[1], "x", 1) != 1) return 1;
                ev_run(loop, 0);
                printf("io=%d timer=%d\n", got_io, got_timer);
                return !(got_io && got_timer);
              }
              EOF
              gcc t.c -o t -lev
              ./t
              [ "$(./t)" = 'io=1 timer=1' ]
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
