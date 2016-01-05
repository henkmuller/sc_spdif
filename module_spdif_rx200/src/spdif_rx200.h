// Copyright (c) 2011, XMOS Ltd, All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

/*! \file */

#ifndef _spdif_rx200_h_
#define _spdif_rx200_h_
#include <xs1.h>

/** This constant defines the four least-significant bits of the first
 * sample of a frame (typically a sample from the left channel)
 */
#define FRAME_X 8

/** This constant defines the four least-significant bits of the second or
 * later sample of a frame (typically a sample from the right channel,
 * unless there are more than two channels)
 */
#define FRAME_Y 0

/** This constant defines the four least-significant bits of the first
 * sample of the first frame of a block (typically a sample from the left
 * channel)
 */
#define FRAME_Z 4


/** \brief S/PDIF receive assembly code
 *
 * This function needs 1 thread and no memory other than ~2300 bytes of
 * program code. It can do 11025, 12000, 22050, 24000, 44100, 48000, 88200,
 * 96000, 176200, and 192000 Hz. The clock needs to be set up to be 8x the
 * base frequency, 100 MHz for 192/176.2, 25 MHz for 48/44.1, etc
 *
 * Output: the received 24-bit sample values are output as a word on the
 * streaming channel end. Each value is shifted up by 4-bits with the
 * bottom four bits being one of FRAME_X, FRAME_Y, or FRAME_Z. The bottom
 * four bits should be removed whereupon the sample value should be sign
 * extended.
 *
 * \param p               S/PDIF input port. This port must be 32-bit buffered,
 *                        declared as ``in buffered port:32``
 *
 * \param c               channel to output samples to
 *
 * \returns               0 to indicate lock has been lost, or 1 to indicate
 *                        that the clock divider needs to be doubled.
 **/
int spdif_rx200_asm(in buffered port:32 p,
                    streaming chanend c);

/* Wrapper that uses a channel rather than a port; for testing */

int spdif_rx200_asm_ce(streaming chanend p,
                       streaming chanend c);

/** \brief S/PDIF receive function.
 *
 * This function calls the asm function above and sets the appropriate
 * clock. It will always wait for a few transitions, then try the fastest
 * clock and lower it until it locks.
 *
 * Output: the received 24-bit sample values are output as a word on the
 * streaming channel end. Each value is shifted up by 4-bits with the
 * bottom four bits being one of FRAME_X, FRAME_Y, or FRAME_Z. The bottom
 * four bits should be removed whereupon the sample value should be sign
 * extended.
 *
 * The function does not return.
 *
 * \param p    S/PDIF input port. This port must be 32-bit buffered,
 *             declared as ``in buffered port:32``
 *
 * \param c    channel to output samples to
 *
 * \param clk  clock block sourced from the 100 MHz reference clock which
 *             from whih p is clocked
 *
 **/
void spdif_rx200(in buffered port:32 p, streaming chanend c, clock clk);

#endif // spdif_rx200_h
