# The build inputs shared by jdk-21, jdk-25 and jdk-27 (OpenJDK from source), as ONE import:
# pkgs' imports check wants an import's identifier to match its folder, so a recipe can bind
# only one `jdk` from ../jdk. Each recipe lists `script` in its build_deps and its own build.sh
# runs it with that version's build_args (version, build_num, feature, boot, version_opt);
# `cve` carries the CVE-2026-111943 step's inputs (../jdk/cve-2026-111943.ncl).
let { Local, .. } = import "minimal.ncl" in
let jdk = import "../jdk/cve-2026-111943.ncl" in
{
  script = { file = "build-from-source.sh" } | Local,
  cve = jdk,
}
