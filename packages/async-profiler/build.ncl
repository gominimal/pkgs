let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
# async-profiler: a low-overhead sampling CPU / allocation / lock profiler for
# the JVM that writes flame graphs, collapsed stacks and JFR. Built from source
# (see build.sh): the native agent libasyncProfiler.so, the asprof attach
# launcher, the jfrconv converter and the Java API jar.
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let jdk = import "../jdk/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "4.5" in
{
  name = "async-profiler",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "DeterministicJar.java" } | Local,
    {
      url = "https://github.com/async-profiler/async-profiler/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "807b83aefc86fcb067395d526684f3ea127919d611fe3bde1647938af7522869",
      extract = true,
      strip_prefix = "async-profiler-%{version}",
    } | Source,
    base,
    toolchain,
    make,
  ],

  runtime_deps = [
    # libasyncProfiler.so and asprof link only libc / libdl / libpthread /
    # librt; upstream links libstdc++ and libgcc statically into the .so.
    glibc,
    # jfrconv is a /bin/sh launcher that runs `java -jar` on itself; the agent
    # is useless without a JVM to load it into, and the build needs javac.
    bash,
    jdk,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    asprof = { glob = "usr/bin/asprof" } | OutputBin,
    jfrconv = { glob = "usr/bin/jfrconv" } | OutputBin,
    agent = { glob = "usr/lib/libasyncProfiler.so" } | OutputLib,
    header = { glob = "usr/include/asprof.h" } | OutputData,
    jars = { glob = "usr/share/async-profiler/*.jar" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "async-profiler",
        repo = "async-profiler",
      },
    } | Attrs,

  # Every profiling test uses event=itimer (setitimer + SIGPROF), which needs
  # no privileges. The default event=cpu uses perf_events, which a container
  # or sandbox usually forbids (perf_event_paranoid / seccomp).
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "asprof --version | grep -q 'Async-profiler %{version} '"],
          ["/bin/bash", "-c", "jfrconv --version | grep -q 'JFR converter %{version} '"],
        ],
      } | Test,

    # Load the agent at JVM start-up, profile a busy loop, and require the
    # loop's own method in the dumped stacks; then do the same through JFR
    # output and jfrconv (which exercises the converter jar).
    agent =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              cd "$(mktemp -d)"
              cat > Busy.java <<'EOF'
              public class Busy {
                  static long burnCpu(long n) {
                      long x = 0;
                      for (long i = 0; i < n; i++) {
                          x += (i * i) ^ (x >>> 3);
                      }
                      return x;
                  }
                  public static void main(String[] args) {
                      long end = System.nanoTime() + Long.parseLong(args[0]) * 1000000000L;
                      long s = 0;
                      while (System.nanoTime() < end) {
                          s += burnCpu(1000000);
                      }
                      System.out.println(s != 42 ? "done" : "");
                  }
              }
              EOF
              javac Busy.java
              agent=/usr/lib/libasyncProfiler.so
              noinline=-XX:CompileCommand=quiet,dontinline,Busy::burnCpu

              java $noinline -agentpath:$agent=start,event=itimer,file=out.collapsed -cp . Busy 3 > run1.out 2>&1 \
                || { cat run1.out; exit 1; }
              grep -q 'Busy.burnCpu' out.collapsed || { head -c 4000 out.collapsed; exit 1; }

              java $noinline -agentpath:$agent=start,event=itimer,file=out.jfr -cp . Busy 3 > run2.out 2>&1 \
                || { cat run2.out; exit 1; }
              test -s out.jfr
              jfrconv out.jfr conv.collapsed
              grep -q 'Busy.burnCpu' conv.collapsed
              jfrconv out.jfr conv.html
              grep -qi '<!doctype html>' conv.html
            "%,
          ],
        ],
      } | Test,

    # asprof attaches to an already-running JVM (HotSpot dynamic attach, no
    # ptrace), profiles it for two seconds and writes collapsed stacks.
    attach =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              cd "$(mktemp -d)"
              cat > Spin.java <<'EOF'
              public class Spin {
                  static long spinLoop(long n) {
                      long x = 0;
                      for (long i = 0; i < n; i++) {
                          x += (i * 31) ^ (x >>> 5);
                      }
                      return x;
                  }
                  public static void main(String[] args) {
                      long end = System.nanoTime() + 20L * 1000000000L;
                      long s = 0;
                      while (System.nanoTime() < end) {
                          s += spinLoop(1000000);
                      }
                      System.out.println(s != 42 ? "done" : "");
                  }
              }
              EOF
              javac Spin.java
              java -XX:CompileCommand=quiet,dontinline,Spin::spinLoop -cp . Spin > spin.out 2>&1 &
              pid=$!
              trap 'kill $pid 2>/dev/null || true' EXIT
              sleep 3
              asprof -e itimer -d 2 -o collapsed -f "$PWD/attach.collapsed" $pid
              grep -q 'Spin.spinLoop' attach.collapsed || { head -c 4000 attach.collapsed; exit 1; }
            "%,
          ],
        ],
      } | Test,
  },
} | BuildSpec
