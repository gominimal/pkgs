//shape:computed-goto  (GCC labels-as-values, goto *ptr) — gcc's own genattrtab/insn-recog use this; tcc supports it
#include <stdio.h>
int main(void){
  static void *tab[] = { &&L0, &&L1, &&L2, &&Lend };
  int i = 0, acc = 0;
  goto *tab[i];
L0:  acc += 1;   i = 1; goto *tab[i];
L1:  acc += 10;  i = 2; goto *tab[i];
L2:  acc += 100; i = 3; goto *tab[i];
Lend: printf("%d\n", acc);   /* 111 */
  return 0;
}
