/* BUG1 static-PLT regression: a call to a DEFINED GLOBAL function in a
   SEPARATE object. tcc wrongly routed it through an unfilled lazy PLT/GOT
   stub in a -static link => SIGSEGV. Must compile xobj_main.c + xobj_lib.c
   as TWO objects and link. (fix-plt: PLT32->PC32 for defined syms.) */
#include <stdio.h>
extern int lib_add(int, int);
extern int lib_mul(int, int);
extern int lib_val;
int main(void){
    printf("add %d\n", lib_add(20, 22));  /* 42 */
    printf("mul %d\n", lib_mul(6, 7));    /* 42 */
    printf("gval %d\n", lib_val);         /* 99 (cross-object data reloc) */
    return 0;
}
