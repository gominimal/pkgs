/* fix-mul / BUG2 regression: power-of-2 strength reduction (a*2 -> shl)
   miscompiled as shl $0 (==a*1). Tests *2/*4/*8 vs non-power *3/*5/*7. */
#include <stdio.h>
int f(int a,int b,int c,int d,int e){ return a + b*2 + c*3 + d*4 + e*5; }
int main(void){
    printf("m2 %d\n", 7*2);     /* 14 */
    printf("m4 %d\n", 7*4);     /* 28 */
    printf("m8 %d\n", 7*8);     /* 56 */
    printf("m3 %d\n", 7*3);     /* 21 */
    printf("m5 %d\n", 7*5);     /* 35 */
    printf("m16 %d\n", 3*16);   /* 48 */
    printf("f55 %d\n", f(1,2,3,4,5)); /* 1+4+9+16+25 = 55 */
    int x = 6;
    printf("vx2 %d\n", x*2);    /* 12 (variable operand) */
    return 0;
}
