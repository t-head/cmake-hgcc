#include <stdio.h>

extern "C" int shared_lib_scale(float *host_data, int n);

int main()
{
    const int N = 4;
    float data[4] = {1.0f, 2.0f, 3.0f, 4.0f};
    shared_lib_scale(data, N);

    int ok = (data[0] == 2.0f && data[1] == 4.0f && data[2] == 6.0f && data[3] == 8.0f);
    printf("Shared lib test: [%.0f, %.0f, %.0f, %.0f] — %s\n",
           data[0], data[1], data[2], data[3], ok ? "PASSED" : "FAILED");
    return ok ? 0 : 1;
}
