let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let glib = import "../glib/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.38.0" in
{
  name = "atk",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/atk-%{version}.tar.xz",
      sha256 = "ac4de2a4ef4bd5665052952fe169657e65e895c5057dffb3c2a810f6191a0c36",
      extract = true,
      strip_prefix = "atk-%{version}",
    } | Source,
    base,
    meson,
    ninja,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    glib,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libatk-1.0.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  tests = {
    # Link against libatk and call into it: the version getters return the compiled-in
    # ATK_{MAJOR,MINOR,MICRO}_VERSION (atk/atkversion.c:51-97, set from meson.build:2), and
    # the role-name round trip goes through the GObject enum type (atk/atkobject.c:283-309,
    # 1581-1677), so the test fails if libatk or its glib/gobject runtime deps cannot load.
    # Prototypes are declared by hand: atk.h needs the glib include tree, which no
    # runtime dep promises to ship.
    link_and_run =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, toolchain],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%%"
              set -e
              gcc -x c - -o t -latk-1.0 <<'EOF'
              #include <stdio.h>
              #include <string.h>
              extern unsigned int atk_get_major_version(void);
              extern unsigned int atk_get_minor_version(void);
              extern unsigned int atk_get_micro_version(void);
              extern int atk_role_for_name(const char *name);
              extern const char *atk_role_get_name(int role);
              int main(void) {
                char got[32];
                snprintf(got, sizeof got, "%u.%u.%u", atk_get_major_version(),
                         atk_get_minor_version(), atk_get_micro_version());
                printf("libatk runtime version %s, pinned %%{version}\n", got);
                if (strcmp(got, "%%{version}") != 0) return 1;
                int role = atk_role_for_name("push button");
                const char *name = atk_role_get_name(role);
                printf("atk_role_for_name(\"push button\") = %d, atk_role_get_name -> %s\n",
                       role, name ? name : "(null)");
                /* ATK_ROLE_INVALID is 0 (atk/atkobject.h:248). */
                if (role <= 0 || name == NULL || strcmp(name, "push button") != 0) return 1;
                puts("OK");
                return 0;
              }
              EOF
              ./t
            "%%
          ],
        ],
      } | Test,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "LGPL-2.0-only",
    } | Attrs,
} | BuildSpec
