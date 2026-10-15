#include <stdio.h>
#include <hgrtc.h>

// Minimal link-level check for the HGGC::hgrtc imported target: hgrtc.h has to
// come from the propagated include directory, libhgrtc has to link, and the
// loader has to find it at run time. hgrtcVersion() queries the library only and
// needs no PPU device.

int main()
{
    int major = -1;
    int minor = -1;

    hgrtcResult res = hgrtcVersion(&major, &minor);
    if (res != HGRTC_SUCCESS) {
        printf("hgrtcVersion failed: %s\n", hgrtcGetErrorString(res));
        return 1;
    }

    printf("hgrtc version: %d.%d\n", major, minor);
    if (major < 0 || minor < 0) {
        printf("implausible version numbers\n");
        return 1;
    }

    printf("HGGC::hgrtc link test PASSED\n");
    return 0;
}
