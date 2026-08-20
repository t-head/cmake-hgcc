#include <stdio.h>
#include <hggc_runtime.h>

__global__ void add_kernel(int *c, const int *a, const int *b, int n)
{
    int i = blockDim.x * blockIdx.x + threadIdx.x;
    if (i < n)
        c[i] = a[i] + b[i];
}

int main()
{
    const int N = 1024;
    size_t size = N * sizeof(int);

    int *h_a = (int *)malloc(size);
    int *h_b = (int *)malloc(size);
    int *h_c = (int *)malloc(size);

    for (int i = 0; i < N; i++) {
        h_a[i] = i;
        h_b[i] = i * 2;
    }

    int *d_a, *d_b, *d_c;
    hggcMalloc((void **)&d_a, size);
    hggcMalloc((void **)&d_b, size);
    hggcMalloc((void **)&d_c, size);

    hggcMemcpy(d_a, h_a, size, hggcMemcpyHostToDevice);
    hggcMemcpy(d_b, h_b, size, hggcMemcpyHostToDevice);

    add_kernel<<<(N + 255) / 256, 256>>>(d_c, d_a, d_b, N);
    hggcDeviceSynchronize();

    hggcMemcpy(h_c, d_c, size, hggcMemcpyDeviceToHost);

    int errors = 0;
    for (int i = 0; i < N; i++) {
        if (h_c[i] != h_a[i] + h_b[i])
            errors++;
    }

    printf("cmake-hgcc test: %s (%d errors)\n",
           errors == 0 ? "PASSED" : "FAILED", errors);

    hggcFree(d_a);
    hggcFree(d_b);
    hggcFree(d_c);
    free(h_a);
    free(h_b);
    free(h_c);
    return errors;
}
