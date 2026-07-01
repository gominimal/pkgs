/* struct by-value arg + struct return + nested. SysV classifies small
   structs into registers; a multi-word struct copy miscompile (vrotb/vrott)
   was a deferred suspect. */
#include <stdio.h>
struct P { int x, y; };
struct Q { long a; long b; long c; };
struct P mk(int x,int y){ struct P p; p.x=x; p.y=y; return p; }
int sump(struct P p){ return p.x + p.y; }
long sumq(struct Q q){ return q.a + q.b + q.c; }
int main(void){
    struct P p = mk(3,4);
    printf("byval %d\n", sump(p));          /* 7 */
    printf("ret %d %d\n", p.x, p.y);        /* 3 4 */
    struct Q q = {100,200,300};
    printf("q %ld\n", sumq(q));             /* 600 */
    struct P arr[3] = {{1,2},{3,4},{5,6}};
    int t = 0; for (int i=0;i<3;i++) t += sump(arr[i]);
    printf("arr %d\n", t);                  /* 21 */
    return 0;
}
