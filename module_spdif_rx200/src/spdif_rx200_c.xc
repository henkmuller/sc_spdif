#include "spdif_rx200.h"
#include <xs1.h>

void spdif_rx200(in buffered port:32 p, streaming chanend c, clock clk) {
    while(1) {
        p when pinseq(1) :> void;
        p when pinseq(0) :> void;
        p when pinseq(1) :> void;
        p when pinseq(0) :> void;
        set_clock_div(clk, 0);
        if (spdif_rx200_asm(p, c) == 0) {
            set_clock_div(clk, 1);
            if (spdif_rx200_asm(p, c) == 0) {
                set_clock_div(clk, 2);
                spdif_rx200_asm(p, c);
            }
        }
    }
}
