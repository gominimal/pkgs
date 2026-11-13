let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let python = import "../python/build.ncl" in

let libx11 = import "../libx11/build.ncl" in
let libxext = import "../libxext/build.ncl" in
let xorgproto = import "../xorgproto/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "1.7.0" in
{
  name = "libglvnd",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/NVIDIA/libglvnd/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "073e7292788d4d3eeb45ea6c7bdcce9bfdb3b3eef8d7dbd47f2f30dce046ef98",
      extract = true,
      strip_prefix = "libglvnd-%{version}",
    } | Source,
    base,
    meson,
    ninja,
    pkgconf,
    python,
    toolchain,
    xorgproto,
  ],
  runtime_deps = [
    libx11,
    libxext,
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/lib{EGL,GL,GLX,OpenGL,GLdispatch,GLESv}*.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test -f /usr/lib/libGLdispatch.so.0"],
          ["/bin/bash", "-c", "test -f /usr/lib/libOpenGL.so.0"],
          ["/bin/bash", "-c", "test -f /usr/lib/libEGL.so.1"],
        ],
      } | Test,
    # Load libEGL + libOpenGL (and through them libGLdispatch) and call them with no
    # display, no context and no vendor ICD installed (no mesa in test_deps):
    #   - eglQueryString(EGL_NO_DISPLAY, EGL_VERSION) is answered by libglvnd itself:
    #     "1.5 libglvnd" (src/EGL/libegl.c:89, :939-940). Mesa's libEGL says "1.5", so
    #     this also proves the loaded libEGL.so.1 is glvnd's.
    #   - EGL_VENDOR without a display is an error: NULL + EGL_BAD_DISPLAY
    #     (libegl.c:941-944, error recorded by __eglSetError :844-853, read by
    #     eglGetError :822-841).
    #   - EGL_EXTENSIONS without a display is never NULL ("" with no vendor, :924-938).
    #   - glGetString with no current context hits GLdispatch's no-op table, which
    #     returns 0 (src/GLdispatch/vnd-glapi/table.c:41-45).
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
              gcc -x c - -o t -lEGL -lOpenGL <<'EOF'
              #include <stdio.h>
              #include <string.h>
              #include <EGL/egl.h>
              #include <GL/gl.h>
              int main(void) {
                const char *ver = eglQueryString(EGL_NO_DISPLAY, EGL_VERSION);
                printf("eglQueryString(EGL_NO_DISPLAY, EGL_VERSION) = %s\n", ver ? ver : "(null)");
                if (ver == NULL || strcmp(ver, "1.5 libglvnd") != 0) return 1;

                const char *vendor = eglQueryString(EGL_NO_DISPLAY, EGL_VENDOR);
                EGLint err = eglGetError();
                printf("eglQueryString(EGL_NO_DISPLAY, EGL_VENDOR) = %s, eglGetError() = 0x%04x\n",
                       vendor ? vendor : "(null)", (unsigned)err);
                if (vendor != NULL || err != EGL_BAD_DISPLAY) return 1;

                const char *ext = eglQueryString(EGL_NO_DISPLAY, EGL_EXTENSIONS);
                printf("client extensions = \"%s\"\n", ext ? ext : "(null)");
                if (ext == NULL) return 1;

                const GLubyte *glver = glGetString(GL_VERSION);
                printf("glGetString(GL_VERSION) with no context = %s\n",
                       glver ? (const char *)glver : "(null)");
                if (glver != NULL) return 1;

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
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "NVIDIA",
        repo = "libglvnd",
      },
    } | Attrs,
} | BuildSpec
