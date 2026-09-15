/* 64-bit arithmetic -> libtcc1.a runtime helpers (__udivdi3/__umoddi3/
   __divdi3/__ashldi3) "built once by the flaky compiler, threaded forward
   untested" (retrospective Finding 5). */
#include <stdio.h>
int main(void){
    unsigned long long u = 12345678901234567890ULL;
    printf("udiv %llu\n", u / 1000000007ULL);   /* 12345678814 */
    printf("umod %llu\n", u % 1000000007ULL);    /* 814816192 */
    long long s = -1234567890123456789LL;
    printf("sdiv %lld\n", s / 1000000LL);        /* -1234567890123 */
    printf("smod %lld\n", s % 1000000LL);        /* -456789 */
    unsigned long long m = 4000000000ULL * 3ULL; /* exceeds 32 bits */
    printf("mul %llu\n", m);                     /* 12000000000 */
    printf("shl %llu\n", 1ULL << 40);            /* 1099511627776 */
    printf("shr %llu\n", 0xFF00000000ULL >> 32); /* 255 */
    return 0;
}
