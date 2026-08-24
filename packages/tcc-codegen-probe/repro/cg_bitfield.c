//shape:bitfield  (struct bitfield pack/extract; signed truncation) — binutils ELF/opcode tables, gcc tree flags
#include <stdio.h>
struct S { unsigned a:3; unsigned b:5; unsigned c:1; int d:7; };
int main(void){
  struct S s;
  s.a = 5; s.b = 20; s.c = 1; s.d = -3;
  printf("%u %u %u %d\n", s.a, s.b, s.c, s.d);   /* 5 20 1 -3 */
  return 0;
}
