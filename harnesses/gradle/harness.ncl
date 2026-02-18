let { harness, .. } = import "minimal.ncl" in
harness {
  name = "gradle",
  build_packages = ["gradle", "jdk", "base", "curl"],
  runtime_packages = ["jdk"],
  build_env_vars = {
    JAVA_HOME = "/usr/lib/jvm",
  },
  build_cmd = "gradle build -x test --no-daemon -q",
}
