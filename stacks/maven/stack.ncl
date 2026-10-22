let { stack, .. } = import "minimal.ncl" in
stack {
  name = "maven",
  # Pinned to the current LTS line (jdk-25), not the `jdk` meta, so a project's
  # Java does not move when the meta next rolls to a new LTS.
  build_packages = ["maven", "jdk-25", "base", "curl"],
  runtime_packages = ["jdk-25"],
  build_env_vars = {
    JAVA_HOME = "/usr/lib/jvm",
    MAVEN_OPTS = "-Dmaven.repo.local=/state/m2/repository",
  },
  build_cmd = "mvn package -DskipTests -q",

  matches_project_if_any = [
    {
      file_regexes."pom.xml" = "*",
    },
  ],
}
