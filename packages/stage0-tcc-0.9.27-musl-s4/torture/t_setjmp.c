/* setjmp/longjmp: libtcc.c:638 wraps every compile in setjmp; the boot0
   saga briefly suspected setjmp codegen. Exercises musl setjmp + tcc. */
#include <stdio.h>
#include <setjmp.h>
static jmp_buf jb;
static void boom(int v){ longjmp(jb, v); }
int main(void){
    int r = setjmp(jb);
    if (r == 0){ printf("set\n"); boom(7); printf("UNREACHABLE\n"); }
    printf("jmp %d\n", r); /* 7 */
    return 0;
}
