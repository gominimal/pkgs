# The build script shared by jdk-21, jdk-25 and jdk-27 (OpenJDK from source). Each recipe lists
# `script` in its build_deps and its own build.sh runs it with that version's build_args
# (version, build_num, feature, boot, version_opt).
let { Local, .. } = import "minimal.ncl" in
{
  script = { file = "build-from-source.sh" } | Local,
}
