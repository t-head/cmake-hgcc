#include <stdio.h>

extern int device_add(int a, int b);

void host_greet()
{
    printf("Hello from host C++ code\n");
}

int main()
{
    host_greet();
    int result = device_add(3, 4);
    printf("device_add(3, 4) = %d — %s\n",
           result, result == 7 ? "PASSED" : "FAILED");
    return result == 7 ? 0 : 1;
}
