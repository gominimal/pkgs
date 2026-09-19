/* lb#470 register+stack argument passing. SysV amd64 passes args 1-6 in
   rdi,rsi,rdx,rcx,r8,r9 and 7+ on the stack. The >=4-arg miscompile class. */
#include <stdio.h>
int a4(int a,int b,int c,int d){ return a+b*10+c*100+d*1000; }
int a5(int a,int b,int c,int d,int e){ return a+b*10+c*100+d*1000+e*10000; }
int a6(int a,int b,int c,int d,int e,int f){ return a+b*2+c*3+d*4+e*5+f*6; }
int a7(int a,int b,int c,int d,int e,int f,int g){ return a+b*2+c*3+d*4+e*5+f*6+g*7; }
int main(void){
    printf("a4 %d\n", a4(1,2,3,4));          /* 4321 */
    printf("a5 %d\n", a5(1,2,3,4,5));        /* 54321 */
    printf("a6 %d\n", a6(1,1,1,1,1,1));      /* 1+2+3+4+5+6 = 21 */
    printf("a7 %d\n", a7(1,1,1,1,1,1,1));    /* 21+7 = 28 */
    /* computed args (not constants) exercise the register-load path */
    int v = 2;
    printf("c7 %d\n", a7(v,v,v,v,v,v,v));    /* 2*(1+2+3+4+5+6+7)=56 */
    return 0;
}
