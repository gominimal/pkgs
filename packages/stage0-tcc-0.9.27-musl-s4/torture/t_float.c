/* float gate (gate 4): exercises tcc RUNTIME float codegen (SSE) AND musl
   strtod/printf-float. Inputs are `volatile` so tcc cannot constant-fold them
   away -> genuine load + arithmetic + call instructions are emitted.
   ALL printed values are EXACT binary fractions => %f output is libc-invariant
   (identical on musl/glibc/any conforming libc), so the .expected is trustworthy. */
#include <stdio.h>
#include <stdlib.h>
int main(void){
    volatile double a = 1.5, b = 2.25, c = 0.5, d = 7.0, e = 2.0;
    printf("add %.2f\n", a + b);            /* 3.75   (exact) */
    printf("mul %.4f\n", c * c);            /* 0.2500 (exact) */
    printf("div %.3f\n", d / e);            /* 3.500  (exact) */
    printf("f7 %.6f\n", d * 1.0);           /* 7.000000 (exact) */
    /* strtod -> runtime double, exact value */
    double s = strtod("3.5", (char**)0);
    printf("strtod %.1f\n", s);             /* 3.5 */
    /* float->int conversion (runtime) */
    volatile double q = 3.75;
    printf("toint %d\n", (int)(q * 4.0));   /* 15 */
    /* classic 0.1+0.2 != 0.3, runtime operands defeat folding */
    volatile double p1 = 0.1, p2 = 0.2, p3 = 0.3;
    printf("cmp %d\n", (p1 + p2 > p3) ? 1 : 0); /* 1 */
    /* int<->double round trip */
    volatile int n = 42; double h = n; h = h / 2.0;
    printf("half %.1f\n", h);               /* 21.0 */
    /* float (32-bit) path, exact */
    volatile float fa = 1.25f, fb = 2.75f;
    printf("flt %.2f\n", (double)(fa + fb));/* 4.00 */
    return 0;
}
