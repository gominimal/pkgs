/* large stack frame -> disp32 (>127-byte) rbp offsets. The "disp32 /
   large-stack-offset" hypothesis surfaced repeatedly in the boot0 saga. */
#include <stdio.h>
int main(void){
    int a[512];                 /* 2KB frame, forces disp32 offsets */
    for (int i = 0; i < 512; i++) a[i] = i * 3 - 7;
    long sum = 0;
    for (int i = 0; i < 512; i++) sum += a[i];
    printf("sum %ld\n", sum);   /* 3*(511*512/2) - 7*512 = 392448 - 3584 = 388864 */
    printf("first %d last %d\n", a[0], a[511]); /* -7 1526 */
    int j = 300;                /* variable index into the big frame */
    printf("mid %d\n", a[j]);   /* 300*3-7 = 893 */
    return 0;
}
