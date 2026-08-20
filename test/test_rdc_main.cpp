#include <stdio.h>

extern int run_rdc_test();

int main()
{
    printf("=== RDC (Separable Compilation) Test ===\n");
    return run_rdc_test();
}
