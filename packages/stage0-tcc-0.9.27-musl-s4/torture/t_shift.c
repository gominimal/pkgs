/* fix-shift regression (BUG: mescc collapsed constant shift-count to 0).
   The o() pattern `while(c){emit(c&0xff); c=c>>8;}` was the original
   infinite-loop. Tests constant + variable shift counts, both directions. */
#include <stdio.h>
int main(void){
    unsigned x = 0x12345678u;
    printf("shl1 %u\n", 1u << 1);          /* 2 */
    printf("shl31 %u\n", 1u << 31);        /* 2147483648 */
    printf("shr8 %u\n", x >> 8);           /* 0x123456 = 1193046 */
    printf("shr16 %u\n", x >> 16);         /* 0x1234 = 4660 */
    printf("shl4 %u\n", x << 4);           /* 0x23456780 = 591751040 */
    /* the runaway o() loop: decompose a word into bytes LSB-first */
    unsigned c = 0x11223344u; int n = 0;
    while (c) { printf("byte %u\n", c & 0xffu); c = c >> 8; n++; }
    printf("nbytes %d\n", n);              /* must terminate at 4 */
    int s = 24;                            /* variable shift count */
    printf("varshl %u\n", 1u << s);        /* 16777216 */
    return 0;
}
