let { harness, .. } = import "minimal.ncl" in
harness {
  name = "maven",
  build_packages = ["maven", "jdk", "base", "curl"],
  runtime_packages = ["jdk"],
  build_env_vars = {
    JAVA_HOME = "/usr/lib/jvm",
    MAVEN_OPTS = "-Dmaven.repo.local=/state/m2/repository",
  },
  build_cmd = "mvn package -DskipTests -q",
}
