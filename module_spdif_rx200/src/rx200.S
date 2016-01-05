/*
r0:   input port
r1:   channel
r2:   alignment table (8 or 9)
r3:   value table (0 or 1)
r4:   31
r5:   bitpos
r6:   data
r7:   *************
r8:   low
r9:   high
r10:  action/shaction
r11:  byte
*/

    .globl spdif_rx200_asm    
    .globl spdif_rx200_asm.nstackwords
    .linkset spdif_rx200_asm.nstackwords, 10
    .globl spdif_rx200_asm_ce    
    .globl spdif_rx200_asm_ce.nstackwords
    .linkset spdif_rx200_asm_ce.nstackwords, 10
    
#define BITN(n,np1,np2) \
n:   \
    { lextract r11, r9, r8, r5, 8                   };\
    { ld8u     r10, r2[r11]       ; shl r6, r6, 1   };\
    { ld8u     r10, r3[r11]       ; add r5, r5, r10 };\
    { shr      r10, r5, 5         ; or  r6, r6, r10 };\
    { bf       r10, np1           ; and r5, r5, r4  };\
    { in       r9, res[r0]        ; add r8, r9, 0   };\
    { lextract r11, r9, r8, r5, 8                   };\
    { ld8u     r10, r2[r11]       ; shl r6, r6, 1   };\
    { ld8u     r10, r3[r11]       ; add r5, r5, r10 };\
    { bu np2                      ; add r6, r6, r10 };\

    .issue_mode dual
    .align 4
spdif_rx200_asm:
spdif_rx200_asm_ce:
    { dualentsp 10                 ; nop                     }
    { std   r4, r5, sp[2]                                    }
    { std   r6, r7, sp[4]                                    }
    { std   r8, r9, sp[6]                                    }
    { stw   r10, sp[8]             ; ldap  r11, table_values }
    { add   r3, r11, 0             ; ldap  r11, table_align  }
    { add   r2, r11, 0             ; ldc   r7, 0             }
    { ldc      r5, 0               ; ldc   r4, 29            }
    { ldc      r4, 0x23            ; mkmsk r9, r4            }
syncloop:   
    { in       r8, res[r0]         ; nop                  }
    { and      r10, r8, r9         ; ldap r11, hashtable  }
    { crc32    r10, r5, r4                                }
    { ldw      r11, r11[r10]       ; and r8, r8, r9       }
    { eq       r11, r11, r8        ; nop                  }
    { bf       r11, syncloop       ; ldap r11, hashactions}
    { ld8u     r5, r11[r10]        ; ldc  r4, 31          }
    { bf       r5, slower          ; nop                  }
    { in       r9, res[r0]         ; ldc  r6, 1           }
    { bl preamble2                                        }
slower:
    
    { bl return                    ; ldc r0, 1}
    
    BITN(bit15, bit16, bit17)
    BITN(bit14, bit15, bit16)
    BITN(bit16, bit17, bit18)
    BITN(bit13, bit14, bit15)
    BITN(bit17, bit18, bit19)
    BITN(bit12, bit13, bit14)
    BITN(bit18, bit19, bit20)
    BITN(bit11, bit12, bit13)
    BITN(bit19, bit20, bit21)
    BITN(bit10, bit11, bit12)
    BITN(bit20, bit21, bit22)
    BITN(bit9, bit10, bit11)
    BITN(bit21, bit22, bit23)
    BITN(bit8, bit9, bit10)
    BITN(bit22, bit23, bit24)
    BITN(bit7, bit8, bit9)
    BITN(bit23, bit24, bit25)
    BITN(bit6, bit7, bit8)
    BITN(bit24, bit25, bit26)
    BITN(bit5, bit6, bit7)
    BITN(bit25, bit26, bit27)
    BITN(bit4, bit5, bit6)
    BITN(bit3, bit4, bit5)
    BITN(bit26, bit27, violationstart)
    BITN(bit2, bit3, bit4)
bit27: 
    { lextract r11, r9, r8, r5, 8                   };
    { ld8u     r10, r2[r11]       ; shl r6, r6, 1   };
    { ld8u     r10, r3[r11]       ; add r5, r5, r10 };
    { shr      r10, r5, 5         ; add r6, r6, r10 };
    { bf       r10, violationstart; and r5, r5, r4  };
    { in       r9, res[r0]        ; add r8, r9, 0   };
    { lextract r11, r9, r8, r5, 8                   }
    { ld8u     r10, r2[r11]       ; bitrev r6, r6   }
    { ld8u     r10, r3[r11]       ; add r5, r5, r10 }
    { bf       r10, violationcont ; nop             }
    { bu fail                     ; nop             }
    BITN(bit1, bit2, bit3)
violationstart:
    { lextract r11, r9, r8, r5, 8                   }
    { ld8u     r10, r2[r11]       ; bitrev r6, r6   }
    { ld8u     r10, r3[r11]       ; add r5, r5, r10 }
    { shr      r10, r5, 5         ; bt r10, fail    }
    { bf       r10, violationcont ; and r5, r5, r4  }
    { in       r9, res[r0]        ; add r8, r9, 0   }
    { lextract r11, r9, r8, r5, 8                   }
    { ld8u     r10, r2[r11]       ; sub r5, r5, 4   }
    { ld8u     r10, r3[r11]       ; add r5, r5, r10 }
    { bt r10, preamble            ; nop             }
    { bu fail                     ; nop             }
    BITN(bit0, bit1, bit2)
violationcont:
    { lextract r11, r9, r8, r5, 8                   }
    { ld8u     r10, r2[r11]       ; sub r5, r5, 4   }
    { ld8u     r10, r3[r11]       ; add r5, r5, r10 }
    { shr      r10, r5, 5         ; bf r10, fail    }
    { bf       r10, preamble      ; and r5, r5, r4  }
    { in       r9, res[r0]        ; add r8, r9, 0   }
    { lextract r11, r9, r8, r5, 8                   }
    { ld8u     r10, r2[r11]       ; add r5, r5, 4   }
    { ld8u     r7, r3[r11]        ; add r5, r5, r10 }
    { bu preamble2                ; shl r7, r7, 1   }
preamble:  
    { lextract r11, r9, r8, r5, 8                   }
    { ld8u     r10, r2[r11]       ; add r5, r5, 4   }
    { ld8u     r7, r3[r11]        ; add r5, r5, r10 }
    { shr      r10, r5, 5         ; shl r7, r7, 1   }
    { bf       r10, preamble2     ; and r5, r5, r4   }
    { in       r9, res[r0]        ; add r8, r9, 0   }
    { lextract r11, r9, r8, r5, 8                   }
    { ld8u     r10, r2[r11]       ; out res[r1], r6  }
    { ld8u     r10, r3[r11]       ; add r5, r5, r10 }
    { bu bit0                     ; or  r6, r10, r7 }
preamble2:  
    { lextract r11, r9, r8, r5, 8                   }
    { ld8u     r10, r2[r11]       ; out res[r1], r6  }
    { ld8u     r10, r3[r11]       ; add r5, r5, r10 }
    { shr      r6, r5, 5          ; and r5, r5, r4 }
    { bf       r6, bit0           ; or  r6, r10, r7 }
    { in       r9, res[r0]        ; add r8, r9, 0   }
    { lextract r11, r9, r8, r5, 8                   }
    { ld8u     r10, r2[r11]       ; shl r6, r6, 1   }
    { ld8u     r10, r3[r11]       ; add r5, r5, r10 }
    { bu bit1                     ; add r6, r6, r10 }
fail:
    { ldc   r0, 0                 ; nop}
return: 
    { ldd   r4, r5, sp[2]              }
    { ldd   r6, r7, sp[4]              }
    { ldd   r8, r9, sp[6]              }
    { ldw   r10, sp[8]            ; nop}
    { retsp 10                    ; nop}

/*
    This is a table with SPDIF bit values associated with patterns
    found in the input stream. Patterns should be read from right to left
    (the LSB is the oldest bit). The base encoding oversampled by 8x
    results in 4 patterns:
    
    00000000 (0x00) which is a SPDIF-0
    11111111 (0xFF) which is a SPDIF-0
    00001111 (0x0F) which is a SPDIF-1
    11110000 (0xF0) which is a SPDIF-1

    In addition, there are patterns that are shifted by one bit either way,
	or patterns with a slow rising and or falling edge. For each
    pattern X, ~X should have the same value.

    Patterns that should not occur should have one of the B0D and B1D patterns
    (BAD). There is very little in terms of error recovery, the only exception
    is the violation. This must result in a no-transition and transition. By
    filling BAD entries with both 0 and 1 we will catch anything bad eventually.
*/
#define B0D 0
#define B1D 1

table_values:   
    .byte    0,   0, B0D, B1D, B0D, B1D, B0D, B1D  // 00..07
    .byte  B0D, B1D, B0D, B1D, B0D, B1D,   1,   1  // 08..0F
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // 10..17
    .byte  B0D, B1D, B0D, B1D, B0D, B1D,   1,   1  // 18..1F
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // 20..27
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // 28..2F
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // 30..37
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // 38..3F
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // 40..47
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // 48..4F
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // 50..57
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // 58..5F
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // 60..67
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // 68..6F
    .byte    1, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // 70..77
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D,   0  // 78..7F
    .byte    0, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // 80..87
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D,   1  // 88..8F
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // 90..97
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // 98..9F
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // A0..A7
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // A8..AF
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // B0..B7
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // B8..BF
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // C0..C7
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // C8..CF
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // D0..D7
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // D8..DF
    .byte    1,   1, B0D, B1D, B0D, B1D, B0D, B1D  // E0..E7
    .byte  B0D, B1D, B0D, B1D, B0D, B1D, B0D, B1D  // E8..EF
    .byte    1,   1, B0D, B1D, B0D, B1D, B0D, B1D  // F0..F7
    .byte  B0D, B1D, B0D, B1D, B0D, B1D,   0,   0  // F8..FF

/*
    This is a table with alignments associated with patterns
    found in the input stream. Patterns should be read from right to left
    (the LSB is the oldest bit). The default alignment value is 8,
	indicating that the next SPDIF bit is found 8 positions upstream.
    Exceptions to this are patterns that need to shift the stream up, for
    example:
    
    00000001 (0x01) 
    11111110 (0xFE) 
    00011110 (0x1E) 
    11100001 (0xE1) 

    These need to be shifted up and hence the next SPDIF bit is likely to
	be nine bits up. For each pattern X, ~X should have the same value.

*/
table_align:   
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // 00..07
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // 08..0F
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // 10..17
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // 18..1F
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // 20..27
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // 28..2F
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // 30..37
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // 38..3F
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // 40..47
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // 48..4F
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // 50..57
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // 58..5F
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // 60..67
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // 68..6F
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // 70..77
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // 78..7F
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // 80..87
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // 88..8F
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // 90..97
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // 98..9F
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // A0..A7
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // A8..AF
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // B0..B7
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // B8..BF
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // C0..C7
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // C8..CF
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // D0..D7
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // D8..DF
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // E0..E7
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // E8..EF
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // F0..F7
    .byte    8,   9,   8,   9,   9,   8,   9,   8  // F8..FF

/*
    
    This is a hash table that stores all possible double violations that we
	need to catch on to. It is used when syncing to a stream. All patterns
	are looked up in the hashtable and compared to the value found to check
	if this is a double violation. If so, the next table is used to figure
	out where in the pattern the last bit of the pre-amble appears.
    
*/
hashtable:
    .word  0x00000000, 0x18003ff8, 0x07ffe007, 0xaaaaaaaa
    .word  0xaaaaaaaa, 0xaaaaaaaa, 0xaaaaaaaa, 0xaaaaaaaa
    .word  0x07fe0007, 0xaaaaaaaa, 0x0fff8001, 0x0fff8003
    .word  0x10000001, 0x10000003, 0x1000fffc, 0x10000007
    .word  0xaaaaaaaa, 0xaaaaaaaa, 0xaaaaaaaa, 0xaaaaaaaa
    .word  0x18001ff8, 0xaaaaaaaa, 0x1fffffff, 0x07ffc007
    .word  0x0fff0003, 0x0ffffff8, 0x0ffffffe, 0x0ffffffc
    .word  0x10007ffe, 0x10007ffc, 0x1801fff8, 0xaaaaaaaa
    .word  0x0fffc001, 0x0fffc003, 0xaaaaaaaa, 0xaaaaaaaa
    .word  0xaaaaaaaa, 0xaaaaaaaa, 0xaaaaaaaa, 0xaaaaaaaa
    .word  0xaaaaaaaa, 0xaaaaaaaa, 0xaaaaaaaa, 0x18007ff8
    .word  0xaaaaaaaa, 0xaaaaaaaa, 0x07ff0007, 0x10000000
    .word  0xaaaaaaaa, 0xaaaaaaaa, 0xaaaaaaaa, 0xaaaaaaaa
    .word  0xaaaaaaaa, 0xaaaaaaaa, 0x10003ffe, 0x10003ffc
    .word  0x1800fff8, 0x0fffffff, 0xaaaaaaaa, 0xaaaaaaaa
    .word  0xaaaaaaaa, 0x07ff8007, 0xaaaaaaaa, 0xaaaaaaaa

hashactions:
    .byte   0, 26, 26,  0,  0,  0,  0,  0, 26,  0, 28, 27,  0,  0, 27,  0
    .byte   0,  0,  0,  0, 26,  0,  0, 26, 27,  0,  0,  0, 28, 27, 26,  0
    .byte  28, 27,  0,  0,  0,  0,  0,  0,  0,  0,  0, 26,  0,  0, 26,  0
    .byte   0,  0,  0,  0,  0,  0, 28, 27, 26,  0,  0,  0,  0, 26,  0,  0
