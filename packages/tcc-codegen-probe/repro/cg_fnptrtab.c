//shape:fnptr-table  (static array of fn pointers + indirect call) — exercises .data R_X86_64_64 relocs + indirect-call codegen; binutils/gas dispatch
#include <stdio.h>
static int add(int a,int b){ return a+b; }
static int sub(int a,int b){ return a-b; }
static int mul(int a,int b){ return a*b; }
static int (*tab[3])(int,int) = { add, sub, mul };
int main(void){
  int s = 0;
  for (int i = 0; i < 3; i++) s += tab[i](6,2);   /* 8 + 4 + 12 = 24 */
  printf("%d\n", s);
  return 0;
}
