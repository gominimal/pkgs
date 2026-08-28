/* non-leaf recursion: prolog/epilog/stack-frame + defined-fn self-call. */
#include <stdio.h>
long fib(int n){ return n < 2 ? n : fib(n-1) + fib(n-2); }
long fact(int n){ return n <= 1 ? 1 : n * fact(n-1); }
int ack(int m,int n){ /* Ackermann: deep mutual-ish recursion */
    if (m == 0) return n + 1;
    if (n == 0) return ack(m-1, 1);
    return ack(m-1, ack(m, n-1));
}
int main(void){
    printf("fib %ld\n", fib(20));   /* 6765 */
    printf("fact %ld\n", fact(12)); /* 479001600 */
    printf("ack %d\n", ack(2,3));   /* 9 */
    return 0;
}
