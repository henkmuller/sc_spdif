// Copyright (c) 2011, XMOS Ltd, All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

//::declaration
#include <xs1.h>
#include <xclib.h>
#include <stdio.h>
#include <stdlib.h>
#include "spdif_rx200.h"

buffered in port:4 oneBitPort = XS1_PORT_1F;
clock clockblock = XS1_CLKBLK_1;
//::

//::data handling
void handleSamples(streaming chanend c) {
    unsigned int v, left, right;
    unsigned int nextSample = 0;
    c :> v;
    printf("Got initial %08x\n", v);
    int  zIn = 385;
    int nextLeft = 0;
    int isLeft = 0;
    int errors = 0;
    int not_seen_first_sample = 1;
    int not_seen_first_Z = 1;
    int printme = 0;
    while(1) {
        c :> v;
        unsigned value = (v & 0x0ffffff0) >> 4;
        if((v & 0xF) == FRAME_Y) {
            right = (v & ~0xf) << 4;
            // operate on left and right
            isLeft = 0;
        } else if ((v & 0xF) == FRAME_X || (v & 0xf) == FRAME_Z) {
            left = (v & ~0xf) << 4;
            isLeft = 1;
        } else {
            printf("Neither left nor right %08x\n", v);
            errors++;
        }
        if ((v & 0xF) == FRAME_Z) {
            if (zIn != 0 && !not_seen_first_Z) {
                printf("Wrong number of steps to Z %d\n", zIn);
                errors++;
            }
            not_seen_first_Z = 0;
            zIn = 383;
        } else {
            if (zIn == 0) {
                printf("Zero steps, expected Z not %d\n", v & 0xF);
                errors++;
            }
            zIn--;
        }
        if (value != nextSample && isLeft == nextLeft) {
            if (not_seen_first_sample) {
                not_seen_first_sample = 0;
            } else {
                printf("Error, got %08x expected %08x (%08x)\n", value, nextSample, v);
                errors++;
            }
        } else {
            if (printme == 0) {
                printme = 10;
                printf("Good,  got %08x expected %08x (%08x, %d) %d\n", value, nextSample, v, zIn, errors);
            } else {
                printme--;
            }
        }
        nextSample = (value + 1) * 47 & 0x00ffffff;
        nextLeft = !isLeft;
    }
}
//::

void generateSamples(chanend values) {
    int pseudoRandom = 0;
    outuint(values, 48000);
    outuint(values, 48000*2*32*2*4);
    for(int i = 0; i < 4000; i++) {
//        printf("\nValue: %08x\n", pseudoRandom<<8);
        outuint(values, pseudoRandom<<8);
        pseudoRandom = (pseudoRandom + 1) * 47 & 0x00ffffff;
    }
    exit(0);
}



/*
 Spotting preamble:

 0000 0000 0000 0000 0000 0000 0000 0xxx slower
 1000 0000 0000 0000 0000 0000 0000 0xxx slower
 1000 0000 0000 0000 0000 0000 0000 1xxx slower
 1000 0000 0000 0000 0000 0000 0001 1xxx slower
 1000 0000 0000 0000 0000 0000 0011 1xxx slower
 1000 0000 0000 0000 0000 0000 0111 1xxx slower
 1000 0000 0001 1111 1111 1111 10xx xxxx
 1000 0000 0000 1111 1111 1111 10xx xxxx
 1000 0000 0000 0111 1111 1111 10xx xxxx
 1000 0000 0000 0011 1111 1111 10xx xxxx
 1000 0000 0000 0001 1111 1111 10xx xxxx
 1000 0000 0000 0111 1111 1111 1110 0xxx   44100
 1000 0000 0000 0011 1111 1111 1110 0xxx   44100
 1000 0000 0000 0001 1111 1111 1110 0xxx   44100
 1000 0000 0000 0011 1111 1111 1111 0xxx   44100
 1000 0000 0000 0001 1111 1111 1111 0xxx   44100
 */
void SpdifReceive200(streaming chanend samples, streaming chanend values, int x) {
    int data = 0xA;
    int expectingViolation1 = 1;
    int expectingViolation2 = 0;
    int expectingPreamble1 = 0;
    int expectingPreamble2 = 0;
    unsigned long long samples64;

    unsigned y;
    samples :> y;
//    printf("Got %08x\n", y);
    samples64 = y;
    samples :> y;
//    printf("Got %08x\n", y);
    samples64 |= ((unsigned long long)y) << 32;
    int bitpos = 0;
    while(1) {
        if (bitpos >= 32) {
            samples64 = samples64 >> 32;
            unsigned y;
            samples :> y;
//            printf("Got %08x\n", y);
            samples64 |= ((unsigned long long)y) << 32;
            bitpos -= 32;
        }

        unsigned int byte = (samples64 >> bitpos) & 0xff;
//        printf("Byte %02x\n", byte);
        bitpos += 8;
        if (expectingViolation1) {
            switch(byte) {
            case 0x00:
            case 0xff:
                break;
            case 0x01:
            case 0xfe:
            case 0x03:
            case 0xfc:
                bitpos++;
                break;
            default:
                printf("Error violation %02x\n", byte);
                break;
            }
            expectingViolation1 = 0;
            expectingViolation2 = 1;
        } else if (expectingViolation2) {
            switch(byte) {
            case 0x0f:
            case 0x1f:
            case 0xf0:
            case 0xf8:
                break;
            case 0x1e:
            case 0xe1:
                bitpos++;
                break;
            default:
                printf("Error violation2 %02x\n", byte);
                break;
            }
            expectingViolation2 = 0;
            expectingPreamble1 = 1;
        } else if (expectingPreamble1) {
            switch(byte) {
            case 0x00:
            case 0xff:
                break;
            case 0x0f:
            case 0x1f:
            case 0xf0:
            case 0xe0:
            case 0xf8:
                break;
            case 0x1e:
            case 0xe1:
                bitpos++;
                break;
            case 0x01:
            case 0xfe:
                bitpos++;
                break;
            default:
                printf("Error preamble1 %02x\n", byte);
                break;
            }
            expectingPreamble1 = 0;
            expectingPreamble2 = 1;
        } else if (expectingPreamble2) {
            switch(byte) {
            case 0x00:
            case 0xff:
                break;
            case 0x0f:
            case 0xf0:
            case 0xe0:
                break;
            case 0x1f:
            case 0x1e:
            case 0xe1:
                bitpos++;
                break;
            case 0x01:
            case 0xfe:
                bitpos++;
                break;
            default:
                printf("Error preamble2 %02x\n", byte);
                break;
            }
            expectingPreamble2 = 0;
        } else {
            switch(byte) {
            case 0x00:
            case 0xff:
                data = data << 1;
                break;
            case 0x01:
            case 0x03:
            case 0xfe:
            case 0xfc:
                data = data << 1;
                bitpos++;
                break;
            case 0x80:
            case 0x7f:
                data = data << 1;
                bitpos--;
                break;
            case 0x0f:
            case 0xf0:
            case 0xe0:
                data = (data << 1) | 1;
                break;
            case 0x1f:
            case 0xe1:
            case 0x1e:
            case 0xf1:
                data = (data << 1) | 1;
                bitpos++;
                break;
            case 0x8f:
            case 0xf8:
            case 0x87:
            case 0x78:
                data = (data << 1) | 1;
                bitpos--;
                break;
            default:
                printf("Error byte %02x\n", byte);
                break;
            }
            if (data & 0x80000000) {
                values <: bitrev(data);
                data = 0xA;
                expectingViolation1 = 1;
            }
        }
        
//        printf("%08x ", bitrev(y));
    }
}

extern void SpdifTest(streaming chanend p, chanend c_in);

//::main program
int main(void) {
    streaming chan c, samples;
    chan values;
    par {
        generateSamples(values);
        SpdifTest(samples, values);
        {spdif_rx200_asm_ce(samples, c); exit(0);}
        handleSamples(c);
    }
    return 0;
}
//::
