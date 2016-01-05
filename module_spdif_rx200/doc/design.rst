SPDIF receiver for XCORE200
===========================

The SPDIF receiver for XCORE200 uses a different approach than the XS1
version, as it resynchronises to every edge between two bits.

Operation
---------

The principle of operation is as follows:

* Gather two words of data that are oversampled by 8x, say::

    High word                           Low word
    00000011 11111100 00000011 11111110 00000001 11111110 00000000 11111111

  These are shifted in from a 1-bit port, so they should be read from right
  to left, where the least significant bit of the low word is the oldest
  bit and the most significant bit of the high word is the highest bit

* Maintain a bit position of the last known edge between two SPDIF-bits.
  Lets assume that this is initialised to zero.

* Extract 8 bits up from the bit position; this gives us one of the
  following sequences:

    ======== =================== ===============
    Sequence SPDIF encoding      Shift required
    ======== =================== ===============
    00000000 An SPDIF zero bit   8
    11111111 An SPDIF zero bit   8
    00001111 An SPDIF one bit    8
    11110000 An SPDIF one bit    8
    00000001 An SPDIF zero bit   9
    11111110 An SPDIF zero bit   9
    00011110 An SPDIF one bit    9
    11100001 An SPDIF one bit    9
    ======== =================== ===============

  We use two lookup tables, one table that gives us the SPDIF encoding (0
  or 1), and one that gives us the shift required (8 or 9).

  We add the shift required to the bit position, and we append the SPDIF
  bit to the data.

* If the resulting bit position is 32 or higher, we dithc the low word (it
  has been fully processed), we use the high word as the low word, and we
  input another word of data for the high word.
  
* Repeat the previous step 28 times; this gets us 28 data bits.

* THe next data bit should be a zero (this is a violation)

* The next data bit should be a one (this is the second part of the
  violation, and the first part of the data word)

* Now reduce the bit position by 4, and extract a bit, this is the first
  marker of the XYZ preamble.

* Now increase the bit position by 4, and extra the bit, this is the second
  marker of the XYZ preamble. If the first marker are set it is a Z, if the
  second marker is set it is an X, if none are set it is a Y.

* Repeat until the preamble fails.

Extracting one SPDIF bit requires five XCORE200 issue slots::

 bit0:
    { lextract r11, r9, r8, r5, 8                   };
    { ld8u     r10, r2[r11]       ; shl r6, r6, 1   };
    { ld8u     r10, r1[r11]       ; add r5, r5, r10 };
    { shr      r10, r5, 5         ; or  r6, r6, r10 };
    { bf       r10, bit1          ; and r5, r5, r4  };
    { in       r9, res[r0]        ; add r8, r9, 0   };
 bit1:

In this sequence we use 5 dual issue instructions; in 3 of those we
overwrite the register used in the other lane:

#. lextract extracts the word from the high (r9) and the low
   (r8) word into r11. The bit position is stored in r5.

#. ld8u establishes how much to shift (r10) the bit position by by indexing
   the byte (r11) into table r2; and simultaneoulsy shl shifts the data word
   (r6) up by one bit.

#. The next ld8u establishes whether to set the bit in the data word (r10)
   by indexing the byte (r11) into table r1; and simultaneoulsy add adds
   the shift (odl value of r10) to the bit position (r5).

#. The shr instruction works out whether the bit position (r5) has strayed
   outside the lowest word; if bit 5 is set it leaves 1 in r10.
   Simultaneoulsy, the or operation adds the SPDIF-bit (old value of r10)
   to the data word.

#. The bf instruction tests whether we need to read a new bit of data. If
   not, we jump over the in instruction. Simultaneously, the and instruction
   flattens all but the bottom five bits in r5 (r4 is constant 31)

#. Finally, the in instruction inputs the next data word, and the add
   instruction moves the high word into the low word.

Similar sequences deal with the violation and the preamble.

The crux is to get the shift and lookup table correct.



Analysis of MIPS requirements
-----------------------------

The code above can be optimised; at the cost of making it unreadable. THe
trick is to observe that if the IN instruction is executed, then the
following bit (bit1) is guaranteed to not need to do an IN
instruction, so they can be folded in between the IN and bit2 leading to
this sequence of code::

 bit0:
    { lextract r11, r9, r8, r5, 8                   };
    { ld8u     r10, r2[r11]       ; shl r6, r6, 1   };
    { ld8u     r10, r1[r11]       ; add r5, r5, r10 };
    { shr      r10, r5, 5         ; or  r6, r6, r10 };
    { bf       r10, bit1          ; and r5, r5, r4  };
    { in       r9, res[r0]        ; add r8, r9, 0   };
    { lextract r11, r9, r8, r5, 8                   };
    { ld8u     r10, r2[r11]       ; shl r6, r6, 1   };
    { ld8u     r10, r1[r11]       ; add r5, r5, r10 };
    { bu bit2                     ; or  r6, r6, r10 };
    
 bit1:

First we analyse the unoptimised code above. Assume the processor runs at
exactly 500 MHz with a 100 MHz reference clock and eight threads running.
Also assume that the signal is at a 192 KHz sample rate (12.288 MHz
effective bit rate). At a 12.288 MHz effective bit rate, each bit will take
81.3802 ns. A sequence of, say, 1024 bits will take 83333 ns; inputting
this sequence will take 1024 * 5 issues plus 260.4 * 1 issues = 5380.4
issues. This requires 65.564 MIPS; just over 62.5 MIPS.

The optimised code will take exactly 5 issues per SPDIF bit (since for each
IN we compensate with a sequence of four). This gets us to 1024 * 5 issues
= 5120 requiring 61.4 MIPS; just below 62.5


Locking on
----------

Locking on is the tricky bit.

Suppose that have the right divider, we then input a word of data and look
for one of the following patterns (and their inverses):

* xxx1 1100 0000 0000 0011 1111 1111 1100
  
* xxx1 1000 0000 0000 0011 1111 1111 1100

* xxx1 1000 0000 0000 0111 1111 1111 1100

* xxx1 1000 0000 0000 0011 1111 1111 1110
  
* xxx1 0000 0000 0000 0011 1111 1111 1110
  
* xxx1 0000 0000 0000 0111 1111 1111 1110

The first three are a sequence of two violations (X preamble) at 48 KHz, the
second three are a sequence of two violations (X preamble) at 44.1 KHz. If
these are found, then the startbit is set in the appropriate place and the
final bit of the preamble is consumed.

This is achieved by means of a hash table with a CRC; it should easily fit
in 20 instructions available.
