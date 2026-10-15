/* detbuild: a deterministic build-time environment, preloaded into package
 * builds with LD_PRELOAD. It pins the host facts that the world-rebuild study
 * (build-servers early-cutoff, 2026-10) found embedded in otherwise identical
 * artifacts:
 *
 *  - the kernel release/version uname(2) reports: perl's Config, cadical,
 *    opencv, or-tools, foundationdb and emacs bake it into what they ship;
 *  - process entropy: LuaJIT seeds its string hash (so its table order) from
 *    the raw getrandom syscall, rustc/proc-macro HashMaps from getrandom,
 *    and a build that runs them twice orders its output differently.
 *
 * Only processes that run under the preload see this; the binaries a build
 * produces are not linked against it. Hostname is already pinned by the
 * sandbox's UTS namespace and is left alone, as are sysname and machine.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdarg.h>
#include <stddef.h>
#include <string.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/utsname.h>

#define DETBUILD_RELEASE "7.0.0-minimal"
#define DETBUILD_VERSION "#1 SMP PREEMPT_DYNAMIC minimal"

ssize_t getrandom(void *buf, size_t n, unsigned int flags)
{
    unsigned char *p = buf;
    (void)flags;
    for (size_t i = 0; i < n; i++)
        p[i] = (unsigned char)(0xA5 ^ (i * 157));
    return (ssize_t)n;
}

int getentropy(void *buf, size_t n)
{
    getrandom(buf, n, 0);
    return 0;
}

/* LuaJIT (lj_prng.c) and others bypass the libc wrapper. */
long syscall(long nr, ...)
{
    static long (*real)(long, ...);
    long a[6];
    va_list ap;
    va_start(ap, nr);
    for (int i = 0; i < 6; i++)
        a[i] = va_arg(ap, long);
    va_end(ap);
    if (nr == SYS_getrandom)
        return getrandom((void *)a[0], (size_t)a[1], (unsigned int)a[2]);
    if (!real)
        real = (long (*)(long, ...))dlsym(RTLD_NEXT, "syscall");
    return real(nr, a[0], a[1], a[2], a[3], a[4], a[5]);
}

static void pin(char *dst, size_t cap, const char *src)
{
    strncpy(dst, src, cap - 1);
    dst[cap - 1] = '\0';
}

int uname(struct utsname *u)
{
    static int (*real)(struct utsname *);
    if (!real)
        real = (int (*)(struct utsname *))dlsym(RTLD_NEXT, "uname");
    int rc = real(u);
    if (rc == 0) {
        pin(u->release, sizeof u->release, DETBUILD_RELEASE);
        pin(u->version, sizeof u->version, DETBUILD_VERSION);
    }
    return rc;
}
