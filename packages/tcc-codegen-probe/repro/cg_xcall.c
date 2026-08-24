//shape:static-PLT  (cross-object call to a DEFINED GLOBAL NON-LEAF fn under -static) — fix C regression guard
#include <stdio.h>
extern int libfn(int);                 /* defined in cg_xcall.lib.c (separate object) */
int main(void){
  printf("%d\n", libfn(20) + 1);       /* (20*2 + 2) + 1 = 43 */
  return 0;
}
