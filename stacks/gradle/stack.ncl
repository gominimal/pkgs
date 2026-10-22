let { stack, .. } = import "minimal.ncl" in
stack {
  name = "gradle",
  # Pinned to the current LTS line (jdk-25), not the `jdk` meta, so a project's
  # Java does not move when the meta next rolls to a new LTS.
  build_packages = ["gradle", "jdk-25", "base", "curl"],
  runtime_packages = ["jdk-25"],
  build_env_vars = {
    JAVA_HOME = "/usr/lib/jvm",
  },
  build_cmd = "gradle build -x test --no-daemon -q",

  matches_project_if_any = [
    {
      file_regexes."build.gradle" = "*",
    },
    {
      file_regexes."settings.gradle" = "*",
    },
    # Kotlin DSL: `gradle init`'s default since Gradle 8.2.
    {
      file_regexes."build.gradle.kts" = "*",
    },
    {
      file_regexes."settings.gradle.kts" = "*",
    },
  ],
}
