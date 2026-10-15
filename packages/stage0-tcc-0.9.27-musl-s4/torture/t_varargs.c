/* varargs / va_list regression (BUG6). snprintf %s crashed (garbage ptr),
   %d gave garbage, %*d wrong. Exercises __va_start/__va_arg in libtcc1.a. */
#include <stdio.h>
#include <stdarg.h>
static int vsum(int n, ...){
    va_list ap; va_start(ap, n); int s = 0;
    for (int i = 0; i < n; i++) s += va_arg(ap, int);
    va_end(ap); return s;
}
int main(void){
    char b[64];
    printf("vsum %d\n", vsum(5,10,20,30,40,50)); /* 150 */
    snprintf(b, sizeof b, "%s%d", "x", 5);  printf("snp1 %s\n", b);  /* x5 */
    snprintf(b, sizeof b, "%*d", 4, 7);     printf("snp2 [%s]\n", b);/* [   7] */
    snprintf(b, sizeof b, "%s-%s-%d", "a", "bb", 42); printf("snp3 %s\n", b); /* a-bb-42 */
    snprintf(b, sizeof b, "%05d", 42);      printf("snp4 %s\n", b);  /* 00042 */
    return 0;
}
