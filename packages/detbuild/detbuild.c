/* detbuild: a deterministic build-time environment, preloaded into ONE build
 * command with LD_PRELOAD. It pins the host facts that the world-rebuild study
 * (build-servers early-cutoff, 2026-10) found embedded in otherwise identical
 * artifacts:
 *
 *  - the kernel release/version uname(2) reports: perl's Config, cadical,
 *    opencv, or-tools, foundationdb and emacs bake it into what they ship;
 *  - process entropy: LuaJIT seeds its string hash (so its table order) from
 *    the raw getrandom syscall, rustc/proc-macro HashMaps from getrandom,
 *    and a build that runs them twice orders its output differently.
 *
 * NOT FOR CRYPTO. Every byte this hands out is predictable. OpenSSL, GnuTLS,
 * libsodium and Python's secrets/ssl draw from the same calls, so a TLS
 * connection made under the preload uses guessable ephemeral keys, and any key
 * generated under it (a test cert, a host key) is public. Hence the rules
 * (AGENTS.md, "Preloading detbuild"): never a sandbox default, never
 * `export`ed, and never on a command that uses the network. A package with
 * `needs.internet` fetches first without the preload and preloads only the
 * offline step (`cargo build --frozen`).
 *
 * What is pinned, per process:
 *  - getrandom(), getentropy(), syscall(SYS_getrandom, ...) and
 *    arc4random(), arc4random_buf(), arc4random_uniform() all draw from one
 *    splitmix64 stream with a fixed seed. Successive calls return different
 *    bytes; the same sequence of calls returns the same bytes on every run.
 *    The stream is per process and every process starts at the seed, so two
 *    processes (and the two sides of a fork) see the same bytes. Tools that
 *    make names in a shared directory must retry on a collision; tempfile,
 *    mkstemp and the Rust tempfile crate do.
 *  - read() (and the fortified __read_chk) on a descriptor opened through
 *    open()/open64()/openat()/openat64() or their fortified __open*_2 forms
 *    on the path "/dev/urandom" or "/dev/random" (the JDK's
 *    SecureRandom seed, older getrandom fallbacks). The descriptor is checked
 *    with fstat() before any read is replaced, so a stale entry can only miss,
 *    never corrupt a real file's data.
 *  - uname() and syscall(SYS_uname): release and version are replaced.
 *    6.1.0 sits below every kernel the build fleet runs, so a feature check
 *    keyed on the version can only turn a feature off, never claim one the
 *    host lacks. Hostname is pinned by the sandbox's UTS namespace; sysname
 *    and machine are left alone.
 *
 * What is NOT pinned:
 *  - AT_RANDOM (the auxv bytes the kernel hands every process; it seeds the Go
 *    runtime and glibc's stack protector), getauxval() included;
 *  - glibc-internal entropy (__getrandom_nocancel in mkstemp, malloc), which
 *    never goes through the exported symbols;
 *  - statically linked and Go binaries, which make raw syscalls;
 *  - /dev/urandom read through stdio (fopen/fread use glibc-internal open and
 *    read), through a dup()ed descriptor, or one inherited across exec;
 *  - /proc/sys/kernel/random/uuid, /proc/sys/kernel/osrelease, /proc/version.
 *
 * Only processes that run under the preload see this; the binaries a build
 * produces are not linked against it.
 */
#undef _FORTIFY_SOURCE
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/random.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/sysmacros.h>
#include <sys/types.h>
#include <sys/utsname.h>
#include <unistd.h>

#define DETBUILD_RELEASE "6.1.0-minimal"
#define DETBUILD_VERSION "#1 SMP PREEMPT_DYNAMIC minimal"
#define DETBUILD_SEED 0x6d696e696d616c00ULL /* "minimal\0" */

/* ---- the stream --------------------------------------------------------- */

static uint64_t stream = DETBUILD_SEED;

/* splitmix64. The atomic add makes each 8-byte draw unique even when threads
 * race; which thread gets which draw then follows the scheduler, which is as
 * deterministic as the build's own threading. */
static uint64_t next64(void)
{
    uint64_t z = __atomic_add_fetch(&stream, 0x9e3779b97f4a7c15ULL, __ATOMIC_RELAXED);
    z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9ULL;
    z = (z ^ (z >> 27)) * 0x94d049bb133111ebULL;
    return z ^ (z >> 31);
}

static void fill(void *buf, size_t n)
{
    unsigned char *p = buf;
    while (n) {
        uint64_t v = next64();
        size_t k = n < sizeof v ? n : sizeof v;
        memcpy(p, &v, k);
        p += k;
        n -= k;
    }
}

/* ---- raw syscalls -------------------------------------------------------- */

/* The syscall() and uname() interposers pass through with the instruction
 * itself rather than a dlsym'd libc pointer: nothing to resolve lazily, so
 * no data race on a static, and no dlsym (which can allocate) re-entering
 * from an allocator that calls syscall(), as jemalloc and mimalloc do. */
static long raw6(long nr, long a, long b, long c, long d, long e, long f)
{
#if defined(__x86_64__)
    long ret;
    register long r10 __asm__("r10") = d;
    register long r8 __asm__("r8") = e;
    register long r9 __asm__("r9") = f;
    __asm__ volatile("syscall"
                     : "=a"(ret)
                     : "a"(nr), "D"(a), "S"(b), "d"(c), "r"(r10), "r"(r8), "r"(r9)
                     : "rcx", "r11", "memory");
    return ret;
#elif defined(__aarch64__)
    register long x8 __asm__("x8") = nr;
    register long x0 __asm__("x0") = a;
    register long x1 __asm__("x1") = b;
    register long x2 __asm__("x2") = c;
    register long x3 __asm__("x3") = d;
    register long x4 __asm__("x4") = e;
    register long x5 __asm__("x5") = f;
    __asm__ volatile("svc 0"
                     : "+r"(x0)
                     : "r"(x8), "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x5)
                     : "memory");
    return x0;
#else
#error "detbuild: no raw syscall for this architecture"
#endif
}

static long sysret(long r)
{
    if ((unsigned long)r > -4096UL) {
        errno = (int)-r;
        return -1;
    }
    return r;
}

/* ---- libc functions we forward to -------------------------------------- */

/* Resolved once, before main, while the process is single-threaded. A call
 * that arrives before this runs (another library's constructor) falls back
 * to the raw syscall. */
static ssize_t (*real_read)(int, void *, size_t);
static int (*real_close)(int);
static int (*real_open)(const char *, int, ...);
static int (*real_open64)(const char *, int, ...);
static int (*real_openat)(int, const char *, int, ...);
static int (*real_openat64)(int, const char *, int, ...);
static int (*real___open_2)(const char *, int);
static int (*real___open64_2)(const char *, int);
static int (*real___openat_2)(int, const char *, int);
static int (*real___openat64_2)(int, const char *, int);

#define RESOLVE(f) \
    __atomic_store_n(&real_##f, (__typeof__(real_##f))dlsym(RTLD_NEXT, #f), __ATOMIC_RELEASE)

__attribute__((constructor)) static void detbuild_init(void)
{
    RESOLVE(read);
    RESOLVE(close);
    RESOLVE(open);
    RESOLVE(open64);
    RESOLVE(openat);
    RESOLVE(openat64);
    RESOLVE(__open_2);
    RESOLVE(__open64_2);
    RESOLVE(__openat_2);
    RESOLVE(__openat64_2);
}

#define REAL(f) __atomic_load_n(&real_##f, __ATOMIC_ACQUIRE)

/* ---- entropy ------------------------------------------------------------ */

ssize_t getrandom(void *buf, size_t n, unsigned int flags)
{
    (void)flags;
    if (!buf && n) {
        errno = EFAULT;
        return -1;
    }
    fill(buf, n);
    return (ssize_t)n;
}

int getentropy(void *buf, size_t n)
{
    if (n > 256) {
        errno = EIO;
        return -1;
    }
    return getrandom(buf, n, 0) < 0 ? -1 : 0;
}

uint32_t arc4random(void)
{
    uint32_t v;
    fill(&v, sizeof v);
    return v;
}

void arc4random_buf(void *buf, size_t n)
{
    fill(buf, n);
}

uint32_t arc4random_uniform(uint32_t upper)
{
    if (upper < 2)
        return 0;
    uint32_t min = -upper % upper; /* reject the short top bucket */
    for (;;) {
        uint32_t r = arc4random();
        if (r >= min)
            return r % upper;
    }
}

/* ---- /dev/urandom and /dev/random descriptors -------------------------- */

#define TRACK_MAX 4096
#define WORD_BITS (8 * sizeof(unsigned long))
static unsigned long tracked_fds[TRACK_MAX / WORD_BITS];
static int ntracked;

static int is_random_path(const char *p)
{
    return p && (strcmp(p, "/dev/urandom") == 0 || strcmp(p, "/dev/random") == 0);
}

static void track(int fd)
{
    if (fd < 0 || fd >= TRACK_MAX)
        return;
    unsigned long bit = 1UL << (fd % WORD_BITS);
    if (!(__atomic_fetch_or(&tracked_fds[fd / WORD_BITS], bit, __ATOMIC_RELAXED) & bit))
        __atomic_add_fetch(&ntracked, 1, __ATOMIC_RELAXED);
}

static void untrack(int fd)
{
    if (fd < 0 || fd >= TRACK_MAX)
        return;
    unsigned long bit = 1UL << (fd % WORD_BITS);
    if (__atomic_fetch_and(&tracked_fds[fd / WORD_BITS], ~bit, __ATOMIC_RELAXED) & bit)
        __atomic_sub_fetch(&ntracked, 1, __ATOMIC_RELAXED);
}

/* True only if fd is tracked AND still is /dev/random (1,8) or /dev/urandom
 * (1,9). A descriptor closed behind our back (fclose of an fdopen, close_range,
 * a raw close) and reused for a real file fails the fstat and is dropped. */
static int is_random_fd(int fd)
{
    if (!__atomic_load_n(&ntracked, __ATOMIC_RELAXED) || fd < 0 || fd >= TRACK_MAX)
        return 0;
    unsigned long bit = 1UL << (fd % WORD_BITS);
    if (!(__atomic_load_n(&tracked_fds[fd / WORD_BITS], __ATOMIC_RELAXED) & bit))
        return 0;
    struct stat st;
    if (fstat(fd, &st) == 0 && S_ISCHR(st.st_mode) && major(st.st_rdev) == 1 &&
        (minor(st.st_rdev) == 8 || minor(st.st_rdev) == 9))
        return 1;
    untrack(fd);
    return 0;
}

static mode_t mode_arg(int flags, va_list ap)
{
    if ((flags & O_CREAT) || (flags & O_TMPFILE) == O_TMPFILE)
        return (mode_t)va_arg(ap, int);
    return 0;
}

static int opened(const char *path, int fd)
{
    if (fd >= 0 && is_random_path(path))
        track(fd);
    else if (fd >= 0)
        untrack(fd); /* reused number, now a different file */
    return fd;
}

static int raw_openat(int dirfd, const char *path, int flags, mode_t mode)
{
    return (int)sysret(raw6(SYS_openat, dirfd, (long)path, flags, mode, 0, 0));
}

int open(const char *path, int flags, ...)
{
    va_list ap;
    va_start(ap, flags);
    mode_t mode = mode_arg(flags, ap);
    va_end(ap);
    int (*f)(const char *, int, ...) = REAL(open);
    return opened(path, f ? f(path, flags, mode) : raw_openat(AT_FDCWD, path, flags, mode));
}

int open64(const char *path, int flags, ...)
{
    va_list ap;
    va_start(ap, flags);
    mode_t mode = mode_arg(flags, ap);
    va_end(ap);
    int (*f)(const char *, int, ...) = REAL(open64);
    return opened(path, f ? f(path, flags, mode)
                          : raw_openat(AT_FDCWD, path, flags, mode));
}

int openat(int dirfd, const char *path, int flags, ...)
{
    va_list ap;
    va_start(ap, flags);
    mode_t mode = mode_arg(flags, ap);
    va_end(ap);
    int (*f)(int, const char *, int, ...) = REAL(openat);
    return opened(path, f ? f(dirfd, path, flags, mode) : raw_openat(dirfd, path, flags, mode));
}

int openat64(int dirfd, const char *path, int flags, ...)
{
    va_list ap;
    va_start(ap, flags);
    mode_t mode = mode_arg(flags, ap);
    va_end(ap);
    int (*f)(int, const char *, int, ...) = REAL(openat64);
    return opened(path, f ? f(dirfd, path, flags, mode)
                          : raw_openat(dirfd, path, flags, mode));
}

/* _FORTIFY_SOURCE builds call these when open's flags aren't a constant. */
int __open_2(const char *path, int flags)
{
    int (*f)(const char *, int) = REAL(__open_2);
    return opened(path, f ? f(path, flags) : raw_openat(AT_FDCWD, path, flags, 0));
}

int __open64_2(const char *path, int flags)
{
    int (*f)(const char *, int) = REAL(__open64_2);
    return opened(path, f ? f(path, flags) : raw_openat(AT_FDCWD, path, flags, 0));
}

int __openat_2(int dirfd, const char *path, int flags)
{
    int (*f)(int, const char *, int) = REAL(__openat_2);
    return opened(path, f ? f(dirfd, path, flags) : raw_openat(dirfd, path, flags, 0));
}

int __openat64_2(int dirfd, const char *path, int flags)
{
    int (*f)(int, const char *, int) = REAL(__openat64_2);
    return opened(path, f ? f(dirfd, path, flags) : raw_openat(dirfd, path, flags, 0));
}

int close(int fd)
{
    untrack(fd);
    int (*f)(int) = REAL(close);
    return f ? f(fd) : (int)sysret(raw6(SYS_close, fd, 0, 0, 0, 0, 0));
}

ssize_t read(int fd, void *buf, size_t n)
{
    if (is_random_fd(fd)) {
        fill(buf, n);
        return (ssize_t)n;
    }
    ssize_t (*f)(int, void *, size_t) = REAL(read);
    return f ? f(fd, buf, n) : (ssize_t)sysret(raw6(SYS_read, fd, (long)buf, (long)n, 0, 0, 0));
}

/* _FORTIFY_SOURCE builds call this for a read into a buffer of known size. */
extern void __chk_fail(void) __attribute__((noreturn));

ssize_t __read_chk(int fd, void *buf, size_t n, size_t buflen)
{
    if (n > buflen)
        __chk_fail();
    return read(fd, buf, n);
}

/* ---- uname -------------------------------------------------------------- */

static void pin(char *dst, size_t cap, const char *src)
{
    strncpy(dst, src, cap - 1);
    dst[cap - 1] = '\0';
}

static void pin_uname(struct utsname *u)
{
    pin(u->release, sizeof u->release, DETBUILD_RELEASE);
    pin(u->version, sizeof u->version, DETBUILD_VERSION);
}

int uname(struct utsname *u)
{
    int rc = (int)sysret(raw6(SYS_uname, (long)u, 0, 0, 0, 0, 0));
    if (rc == 0)
        pin_uname(u);
    return rc;
}

/* LuaJIT (lj_prng.c) and others bypass the libc wrappers. */
long syscall(long nr, ...)
{
    long a[6];
    va_list ap;
    va_start(ap, nr);
    for (int i = 0; i < 6; i++)
        a[i] = va_arg(ap, long);
    va_end(ap);
    if (nr == SYS_getrandom)
        return getrandom((void *)a[0], (size_t)a[1], (unsigned int)a[2]);
    if (nr == SYS_uname)
        return uname((struct utsname *)a[0]);
    return sysret(raw6(nr, a[0], a[1], a[2], a[3], a[4], a[5]));
}
