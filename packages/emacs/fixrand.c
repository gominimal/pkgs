/*
 * fixrand.c — LD_PRELOAD shim for deterministic builds.
 *
 * Intercepts getrandom() and /dev/urandom reads to return deterministic
 * output from a fixed-seed LCG. This makes Emacs's internal hash table
 * seeding reproducible, fixing .elc and .pdmp non-determinism.
 *
 * Also freezes clock_gettime(CLOCK_REALTIME) to SOURCE_DATE_EPOCH: the dumped
 * .pdmp otherwise embeds two wall-clock reads that getrandom interception does
 * not cover — the *scratch* buffer's buffer-display-time (Fcurrent_time during
 * make_initial_frame) and Vgc_elapsed GC timing (src/alloc.c).
 *
 * Inspired by libfate (Nicolas Graves / Guix).
 *
 * Build:  gcc -shared -fPIC -O2 -ldl -o fixrand.so fixrand.c
 * Usage:  LD_PRELOAD=./fixrand.so emacs --batch ...
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/random.h>
#include <time.h>
#include <unistd.h>

static uint32_t seed = 0x12345678;

/* Resolve real symbols once at library load time via a constructor.  Doing this
 * inside the interposed function itself is unsafe for clock_gettime: on some
 * glibc versions dlsym(RTLD_NEXT, ...) takes dl_load_lock and may internally
 * call clock_gettime (e.g. for CLOCK_MONOTONIC profiling / adaptive locking),
 * causing deadlock or infinite recursion on the very first call. */
static ssize_t (*real_read)(int, void *, size_t) = NULL;
static int (*real_clock_gettime)(clockid_t, struct timespec *) = NULL;

__attribute__((constructor))
static void fixrand_init(void) {
    real_read = dlsym(RTLD_NEXT, "read");
    real_clock_gettime = dlsym(RTLD_NEXT, "clock_gettime");
}

static uint32_t next_rand(void) {
    seed = seed * 1103515245 + 12345;
    return seed;
}

static void fill_deterministic(unsigned char *buf, size_t len) {
    for (size_t i = 0; i < len; i++)
        buf[i] = next_rand() & 0xFF;
}

ssize_t getrandom(void *buf, size_t buflen, unsigned int flags) {
    (void)flags;
    if (!buf) { errno = EFAULT; return -1; }
    fill_deterministic(buf, buflen);
    return (ssize_t)buflen;
}

ssize_t read(int fd, void *buf, size_t count) {
    char proc_path[64];
    char target[256];
    snprintf(proc_path, sizeof(proc_path), "/proc/self/fd/%d", fd);
    ssize_t len = readlink(proc_path, target, sizeof(target) - 1);
    if (len > 0) {
        target[len] = '\0';
        if (strcmp(target, "/dev/urandom") == 0 ||
            strcmp(target, "/dev/random") == 0) {
            if (!buf) { errno = EFAULT; return -1; }
            fill_deterministic(buf, count);
            return (ssize_t)count;
        }
    }
    if (!real_read) {
        errno = EIO;
        return -1;
    }
    return real_read(fd, buf, count);
}

/* Freeze wall-clock reads so Emacs's current-time (e.g. the *scratch* buffer's
   buffer-display-time, set in make_initial_frame) and GC timing (Vgc_elapsed)
   are deterministic in the dumped .pdmp. Only CLOCK_REALTIME is pinned (to the
   sandbox-exported SOURCE_DATE_EPOCH); CLOCK_MONOTONIC and others pass through
   so timeouts / progress loops are unaffected. */
int clock_gettime(clockid_t clk_id, struct timespec *tp) {
    if (clk_id == CLOCK_REALTIME && tp) {
        const char *e = getenv("SOURCE_DATE_EPOCH");
        tp->tv_sec = e ? (time_t)strtoll(e, NULL, 10) : 0;
        tp->tv_nsec = 0;
        return 0;
    }
    if (!real_clock_gettime) {
        errno = ENOSYS;
        return -1;
    }
    return real_clock_gettime(clk_id, tp);
}
