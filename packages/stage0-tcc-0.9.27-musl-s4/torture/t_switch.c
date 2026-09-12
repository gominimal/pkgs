/* switch / jump-table codegen. */
#include <stdio.h>
const char *name(int k){
    switch (k){
        case 0:  return "zero";
        case 1:  return "one";
        case 2:  return "two";
        case 7:  return "seven";
        case 100:return "hundred";
        default: return "other";
    }
}
int main(void){
    int keys[6] = {0,1,2,7,100,55};
    for (int i = 0; i < 6; i++) printf("k%d %s\n", keys[i], name(keys[i]));
    /* fallthrough accumulation */
    int acc = 0, x = 3;
    switch (x){ case 3: acc += 3; case 2: acc += 2; case 1: acc += 1; break; default: acc = -1; }
    printf("fall %d\n", acc); /* 6 */
    return 0;
}
