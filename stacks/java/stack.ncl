let { stack, .. } = import "minimal.ncl" in
# The Java development loadout: one session with everything to write, build,
# navigate and debug a JVM project, whichever build tool it uses —
#
#   javac Hello.java && java Hello      # compile + run (jdk)
#   jshell                              # REPL (jdk)
#   mvn -q package                      # Maven projects
#   gradle build                        # Gradle projects (Groovy or Kotlin DSL)
#   jdtls                               # LSP for editors / agents (stdio)
#   jdb -attach 5005                    # debug; jcmd / jfr profile (jdk)
#   asprof -d 30 -f out.html <pid>      # flamegraph (async-profiler)
#   google-java-format -i Foo.java      # format; checkstyle / pmd / spotbugs lint
#   jbang Script.java                   # single-file scripts with //DEPS
#
# It is the union of the `maven` and `gradle` stacks' setup plus the language
# server, pinned to Java 25 (`jdk-25`, the current LTS) like the `maven` and
# `gradle` stacks, so a project's Java doesn't move when the `jdk` meta rolls
# to the next LTS; use `jdk-21` / `jdk-27` in the project for another line. The JDK itself is most of the
# toolbox: javac, jshell, jdb, jcmd, jfr, jdeps, jlink, jpackage, javadoc,
# javap all ship in it, and jdk-25 links every one into /usr/bin. The tools
# below the JDK (formatter, linters, profiler, mvnd, kotlinc, jbang) all
# depend on the `jdk` meta, which is jdk-25 today, so the closure holds one
# JDK.
#
# Opt-in (no `matches_project_if_any`), like `aeneas` and `reveng`: a pom.xml
# or build.gradle already selects the plain `maven` / `gradle` build stack,
# and this one must not compete with them. You ask for it explicitly.
stack {
  name = "java",

  build_packages = [
    # Shared base, as in the `maven` / `gradle` stacks. curl because build
    # tools and wrapper scripts reach for it.
    "base",
    "curl",

    # THE ANCHOR: the current LTS JDK (compiler, runtime, jshell, jdb, jfr,
    # jcmd, jlink, ...). Ships no `JAVA_HOME` of its own — see below.
    "jdk-25",

    # Both mainstream build tools. Each also works as a launcher for the
    # project's own plugins (Error Prone, SpotBugs, Spotless, OpenRewrite,
    # JaCoCo...), which are build-classpath dependencies resolved from Maven
    # Central rather than packages.
    "maven",
    "gradle",

    # Eclipse JDT Language Server: completion, diagnostics, refactoring,
    # organize-imports and Eclipse-profile formatting over LSP. Its wrapper
    # already redirects -data / -configuration to a writable cache dir.
    "jdtls",

    # Everyday tools around the build, each a package on main:
    "google-java-format", # formatter
    "checkstyle", # style linter
    "pmd", # static analysis + CPD
    "spotbugs", # bytecode bug finder
    "async-profiler", # CPU/alloc/lock profiler (asprof, jfrconv)
    "mvnd", # Maven daemon
    "kotlin", # kotlinc, for Gradle Kotlin DSL / mixed projects
    "jbang", # run .java scripts with //DEPS
  ],

  runtime_packages = ["jdk-25"],

  build_env_vars = {
    # Gradle's and Maven's launchers both want JAVA_HOME and the jdk package
    # does not set it. Same value the `maven`, `gradle` and `reveng` stacks use.
    JAVA_HOME = "/usr/lib/jvm",

    # Keep the Maven local repository on the state disk so dependencies
    # survive between builds (same as the `maven` stack). Gradle needs no
    # equivalent: the gradle package's env_state_wiring already points
    # GRADLE_USER_HOME at a state dir.
    MAVEN_OPTS = "-Dmaven.repo.local=/state/m2/repository",
  },

  # A dev bench has no single canonical build command (Maven or Gradle?), so
  # exercise every anchor instead: a session that cannot compile, cannot run
  # either build tool, cannot start the language server, or has lost the
  # debugger fails AT START rather than an hour in. jdb is on PATH: jdk-25
  # links every usr/lib/jvm/bin/* into /usr/bin.
  build_cmd = "java -version && javac -version && mvn -v && gradle --version && jdtls --help > /dev/null && jdb -version",
}
#
# BUILD PLUGINS, NOT PACKAGES — they ride the project's own pom/build.gradle
# and resolve from Maven Central, so a package would be dead weight:
#   Error Prone, Lombok (an annotation processor — a dependency, not a tool),
#   Spotless, JaCoCo, the OpenRewrite Maven/Gradle plugins.
#
# DELIBERATELY ABSENT:
#   the `mod` OpenRewrite CLI   Moderne's proprietary distribution; and some
#                               recipe modules moved to a source-available
#                               (non-OSI) licence. Use the build plugins.
#   ./mvnw, ./gradlew           wrappers DOWNLOAD a distribution at run time;
#                               the packaged mvn / gradle are the hermetic path.
