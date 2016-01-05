// Copyright (c) 2011, XMOS Ltd, All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

/**
 * @file    SpditTransmit.xc
 * @brief   S/PDIF line transmitter
 * @author  XMOS Semiconductor
 *
 * Uses a master clock to output S/PDIF encoded samples.
 * This implementation uses a lookup table to generate S/PDIF encoded data stream from raw audio samples.
 */

#include <xs1.h>
#include <xclib.h>
#include <print.h>
#include <stdio.h>
#include <stdlib.h>

#define	VALIDITY 		0x00000000		/* Validity bit (x<<28) */

void SpdifTransmitPortConfig(out buffered port:32 p, clock clk, in port p_mclk)
{
    /* Clock clock block from master-clock */
    configure_clock_src(clk, p_mclk);

    /* Clock S/PDIF tx port from MClk */
    configure_out_port_no_ready(p, clk, 0);

    /* Set delay to align SPDIF output to the clock at the external flop */
    set_clock_fall_delay(clk, 7);

    /* Start the clockblock ticking */
    start_clock(clk);
}



/* Returns parity for a given word */
static int inline parity32(unsigned x)
{
    crc32(x, 0, 1);
    return (x & 1);
}


unsigned dataWords_2[16] = {
  0x0F0F,
  0xF0F3,
  0xF0CF,
  0x0F33,
  0xF30F,
  0x0CF3,
  0x0CCF,
  0xF333,
  0xCF0F,
  0x30F3,
  0x30CF,
  0xCF33,
  0x330F,
  0xCCF3,
  0xCCCF,
  0x3333
};

unsigned preableWords_2[3] = {
    0x303F, 0x0C3F, 0x033F
};


unsigned dataWords_4[32] = {
    0x00FF, 0x00FF,
    0xFF00, 0xFF0F,
    0xFF00, 0xF0FF,
    0x00FF, 0x0F0F,
    0xFF0F, 0x00FF,
    0x00F0, 0xFF0F,
    0x00F0, 0xF0FF,
    0xFF0F, 0x0F0F,
    0xF0FF, 0x00FF,
    0x0F00, 0xFF0F,
    0x0F00, 0xF0FF,
    0xF0FF, 0x0F0F,
    0x0F0F, 0x00FF,
    0xF0F0, 0xFF0F,
    0xF0F0, 0xF0FF,
    0x0F0F, 0x0F0F
};

unsigned preambleWords_4[6] = {
    0x0F00, 0x0FFF,
    0x00F0, 0x0FFF,
    0x000F, 0x0FFF
};

static unsigned int current_bits;
static unsigned int num_current_bits;
static int last = 1;

void addbits(streaming chanend p, unsigned int num_bits, unsigned int bits) {
    if (!last && (rand() & 1)) {
        last = 1;
        int pos = rand() % num_bits;
        int maskr = (1<<(pos+1))-1;
        int maskl = ((1<<(num_bits-pos))-1) << pos;
        int new_bits = ((bits&maskl)<<1) | (bits & maskr);
//        printf("Transformed %04x into %05x\n", bits, new_bits);
        bits = new_bits;
        num_bits++;
    } else {
        last = 0;
    }
    bits &= (1 << num_bits)-1;
//    printf("Adding %2d bits %04x\n", num_bits, bits);
    int new_num_bits = num_bits + num_current_bits;
    current_bits = current_bits | bits << num_current_bits;
    if (new_num_bits < 32) {
        num_current_bits = new_num_bits;
    } else {
        p <: current_bits;
        num_current_bits = new_num_bits - 32;
        current_bits = bits >> (num_bits - num_current_bits);
    }
}

/* Divide by 2, e.g 24 -> 96khz */
static void SpdifTransmit_2(streaming chanend p, chanend c_tx0, const int ctrl_left[2], const int ctrl_right[2])
{
    unsigned word;
    unsigned xor = 0;
    unsigned encoded_preamble, encoded_byte;

    unsigned sample, sample2, control, preamble, parity;

#pragma unsafe arrays
    while (1)
    {
        int controlLeft  = ctrl_left[0];
        int controlRight = ctrl_right[0];
        int newblock = 2;

        for (int i = 0; i < 192; i++)
        {
            /* Check for new frequency */
            if (testct(c_tx0))
            {
                chkct(c_tx0, XS1_CT_END);
                return;
            }

            /* Input samples */
            sample = inuint(c_tx0) >> 4 & 0x0FFFFFF0 ;
            sample2 = inuint(c_tx0);

            control = (controlLeft & 1)<<30;
            preamble = newblock ;
            parity = parity32(sample | control | VALIDITY) << 31;
            word = preamble | sample | control | parity | VALIDITY;

            /* Output left sample */

            /* Preamble */
            encoded_preamble = preableWords_2[word & 0xF];
            encoded_preamble ^= xor;
            addbits(p, 16, encoded_preamble);
            xor = __builtin_sext(encoded_preamble, 16) >> 16;
            word = word >> 4;

            newblock = 0;
            controlLeft >>=1;

            /* Lookup remaining 28 bits, 4 bits at a time */
#pragma unsafe arrays
#pragma loop unroll(7)
            for (int i = 0; i < 7; i++)
            {
                encoded_byte = dataWords_2[word & 0xF];
                encoded_byte ^= xor;  /* Xor to invert data if lsab of last data was a 1 */
                addbits(p, 16, encoded_byte);
                xor = __builtin_sext(encoded_byte, 16) >> 16;
                word = word >> 4;
            }

            sample = sample2 >> 4 & 0x0FFFFFF0 ;

            control = (controlRight & 1)<<30;
            preamble = (1);
            parity = parity32(sample | control | VALIDITY) << 31;
            word = preamble | sample | control | parity | VALIDITY;

            /* Output right sample */

            /* Preamble */
            encoded_preamble = preableWords_2[word & 0xF];
            encoded_preamble ^= xor;
            addbits(p, 16, encoded_preamble);
            xor = __builtin_sext(encoded_preamble, 16) >> 16;
            word = word >> 4;

            controlRight >>=1;

            /* Lookup remaining 28 bits, 4 bits at a time */
#pragma unsafe arrays
#pragma loop unroll(7)
            for (int i = 0; i < 7; i++)
            {
                encoded_byte = dataWords_2[word & 0xF];
                encoded_byte ^= xor;  // Xor to invert data if lsab of last data was a 1
                addbits(p, 16, encoded_byte);
                xor = __builtin_sext(encoded_byte, 16) >> 16;
                word = word >> 4;
            }

            if (i == 31) {
                controlLeft = ctrl_left[1];
                controlRight = ctrl_right[1];
            }
        }
    }
}



/* Divide by 4, e.g 24 -> 48khz */
void SpdifTransmit_4(streaming chanend p, chanend c_tx0, const int ctrl_left[2], const int ctrl_right[2])
{
    unsigned word;
    unsigned xor = 0;
    unsigned encoded_preamble, encoded_byte;

    unsigned sample, control, preamble, parity, sample2;

#pragma unsafe arrays
    while (1)
    {
        int controlLeft  = ctrl_left[0];
        int controlRight = ctrl_right[0];
        int newblock = 2;

        for (int i = 0 ; i<192; i++)
        {
            /* Check for new sample frequency */
            if (testct(c_tx0))
            {
                /* Swallow control token and return */
                chkct(c_tx0, XS1_CT_END);
                return;
            }

            /* Input left and right samples */
            sample = inuint(c_tx0) >> 4 & 0x0FFFFFF0 ;
            sample2 = inuint(c_tx0);

            /* Create status bit */
            control = (controlLeft & 1) << 30;
            preamble = newblock ;

            /* Generate parity bit */
            parity = parity32(sample | control | VALIDITY) << 31;

            /* Generate complete 32bit word */
            word = preamble | sample | control | parity | VALIDITY;

            /* Output left sample */

            /* Look up preamble and output */
            encoded_preamble = preambleWords_4[(word & 0xF)*2+1];
            encoded_preamble ^= xor;
            addbits(p, 16, encoded_preamble);

            encoded_preamble = preambleWords_4[(word & 0xF)*2];
            encoded_preamble ^= xor;
            addbits(p, 16, encoded_preamble);
            xor = __builtin_sext(encoded_preamble, 16) >> 16;
            word = word >> 4;

            newblock = 0;
            controlLeft >>=1;

            /* Lookup remaining 28 bits, 4 bits at a time */
#pragma unsafe arrays
#pragma loop unroll(7)
            for (int i = 0; i < 7; i++)
            {
                encoded_byte = dataWords_4[(word & 0xF)*2+1];
                encoded_byte ^= xor;  /* Xor to invert data if lsab of last data was a 1 */
                addbits(p, 16, encoded_byte);
                encoded_byte = dataWords_4[(word & 0xF) * 2];
                encoded_byte ^= xor;  /* Xor to invert data if lsab of last data was a 1 */
                addbits(p, 16, encoded_byte);
                xor = __builtin_sext(encoded_byte, 16) >> 16;
                word = word >> 4;
            }

            sample = sample2 >> 4 & 0x0FFFFFF0 ;

            /*  Output right sample */

            control = (controlRight & 1)<<30;
            preamble = (1);
            parity = parity32(sample | control | VALIDITY) << 31;
            word = preamble | sample | control | parity | VALIDITY;

            /* Look up and output pre-amble, 2 bytes at a time */
            encoded_preamble = preambleWords_4[(word & 0xF)*2+1];
            encoded_preamble ^= xor;
            addbits(p, 16, encoded_preamble);

            encoded_preamble = preambleWords_4[(word & 0xF)*2];
            encoded_preamble ^= xor;
            addbits(p, 16, encoded_preamble);
            xor = __builtin_sext(encoded_preamble, 16) >> 16;
            word = word >> 4;

            controlRight >>=1;


            /* Lookup remaining 28 bits, 4 bits at a time */
#pragma unsafe arrays
#pragma loop unroll(7)
            for (int i = 0; i < 7; i++)
            {
                encoded_byte = dataWords_4[(word & 0xF)*2+1];
                encoded_byte ^= xor;  /* Xor to invert data if lsab of last data was a 1 */
                addbits(p, 16, encoded_byte);
                encoded_byte = dataWords_4[(word & 0xF) * 2];
                encoded_byte ^= xor;  /* Xor to invert data if lsab of last data was a 1 */
                xor = __builtin_sext(encoded_byte, 16) >> 16;
                word = word >> 4;
                addbits(p, 16, encoded_byte);
            }

            if (i == 31) {
                controlLeft = ctrl_left[1];
                controlRight = ctrl_right[1];
            }
        }
    }
}


/* Defines for building channel status words */
#define CHAN_STAT_L        0x00107A04
#define CHAN_STAT_R        0x00207A04

#define CHAN_STAT_44100    0x00000000
#define CHAN_STAT_48000    0x02000000
#define CHAN_STAT_88200    0x08000000
#define CHAN_STAT_96000    0x0A000000
#define CHAN_STAT_176400   0x0C000000
#define CHAN_STAT_192000   0x0E000000

#define CHAN_STAT_WORD_2   0x0000000B


/* S/PDIF transmit thread */
void SpdifTest(streaming chanend p, chanend c_in)
{
    int chanStat_L[2], chanStat_R[2];
    unsigned divide;

    /* Receive sample frequency over channel (in Hz) */
    unsigned  samFreq = inuint(c_in);

    /* Receive master clock frequency over channel (in Hz) */
    unsigned  mclkFreq = inuint(c_in);

    /* Create channel status words based on sample freq */
    switch(samFreq)
    {
        case 44100:
            chanStat_L[0] = CHAN_STAT_L | CHAN_STAT_44100;
            chanStat_R[0] = CHAN_STAT_R | CHAN_STAT_44100;
            break;

        case 48000:
            chanStat_L[0] = CHAN_STAT_L | CHAN_STAT_48000;
            chanStat_R[0] = CHAN_STAT_R | CHAN_STAT_48000;
            break;

        case 88200:
            chanStat_L[0] = CHAN_STAT_L | CHAN_STAT_88200;
            chanStat_R[0] = CHAN_STAT_R | CHAN_STAT_88200;
            break;

        case 96000:
            chanStat_L[0] = CHAN_STAT_L | CHAN_STAT_96000;
            chanStat_R[0] = CHAN_STAT_R | CHAN_STAT_96000;
            break;

        case 176400:
            chanStat_L[0] = CHAN_STAT_L | CHAN_STAT_176400;
            chanStat_R[0] = CHAN_STAT_R | CHAN_STAT_176400;
            break;

        case 192000:
            chanStat_L[0] = CHAN_STAT_L | CHAN_STAT_192000;
            chanStat_R[0] = CHAN_STAT_R | CHAN_STAT_192000;
            break;

        default:
            /* Sample frequency not recognised.. carry on for now... */
            chanStat_L[0] = CHAN_STAT_L;
            chanStat_R[0] = CHAN_STAT_R;
            break;

    }
    chanStat_L[1] = CHAN_STAT_WORD_2;
    chanStat_R[1] = CHAN_STAT_WORD_2;

    /* Calculate required divide */
    divide = mclkFreq / (samFreq * 2 * 32 * 2);

    switch(divide)
    {

        case 2:
            /* E.g. 24 -> 96 */
           SpdifTransmit_2(p, c_in, chanStat_L, chanStat_R);
           break;

        case 4:
            /* E.g. 24MHz -> 48kHz */
            SpdifTransmit_4(p, c_in, chanStat_L, chanStat_R);
            break;

        default:
            /* Mclk does not support required sample freq */
            printf("Not supported %d %d\n", samFreq, mclkFreq);
            break;
    }
}


