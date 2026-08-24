//shape:7-arg-call  (>=7 args: 6 in regs + 1 on stack) — lb#470 register+stack passing; pervasive in binutils/gcc
#include <stdio.h>
int f7(int a,int b,int c,int d,int e,int f,int g){
  return a + b*2 + c*3 + d*4 + e*5 + f*6 + g*7;
}
int main(void){
  printf("%d\n", f7(1,2,3,4,5,6,7));   /* 1+4+9+16+25+36+49 = 140 */
  return 0;
}
