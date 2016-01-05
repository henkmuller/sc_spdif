#include <stdio.h>
#include <xs1.h>
#include <xclib.h>

unsigned encodings[32];
unsigned nEncodings;
unsigned actions[32];

void addVector(char string[39], unsigned value) {
    unsigned encoding = 0;
    for(unsigned i = 0; i < 39; i++) {
        if (string[i] == '0') {
            encoding = encoding << 1;
        } else if (string[i] == '1') {
            encoding = (encoding << 1) | 1;
        }
    }
    printf("%08x\n", encoding);
    actions[nEncodings] = value;
    encodings[nEncodings++] = encoding;
    actions[nEncodings] = value;
    encodings[nEncodings++] = 0x1FFFFFFF ^ encoding;
}

unsigned hashClash(unsigned poly) {
    unsigned hit[128];
    unsigned value[128];
    unsigned action[128];
    
    unsigned clash = 0;
    int allOnes = (1 << (32-clz(poly)))-1;
    for(unsigned i = 0; i < 64; i++) {
        hit[i] = 0;
        value[i] = 0xAAAAAAAA;
        action[i] = 0;
    }
    printf("Poly %02x allOnes %02x  ", poly, allOnes);
    for(unsigned i = 0; i  < nEncodings; i++) {
        unsigned int crc = encodings[i];
        crc32(crc, 0, poly);
        if (hit[crc]) {
            printf(" clash at %2d out of %d\n", i, nEncodings);
            clash = 1;
            break;
        }
        hit[crc] = 1;
        value[crc] = encodings[i];
        action[crc] = actions[i];
    }
    if (!clash) {
        for(int i = 0; i <= allOnes; i++) {
            printf(" %d", hit[i]);
        }
        printf("\n\nhashtable:");
        for(int i = 0; i <= allOnes; i++) {
            if ((i & 3) == 0) printf("\n    .word ");
            printf(" 0x%08x,", value[i]);
        }
        printf("\n\nhashactions:");
        for(int i = 0; i <= allOnes; i++) {
            if ((i & 15) == 0) printf("\n    .byte ");
            printf(" %2d,", action[i]);
        }
        printf("\n");
    }
    return clash;
}

void buildHash() {
    for(int i = 16; i <= 63; i++) {
        if (!hashClash(i)) {
            printf("Using poly 0x%02x\n", i);
            break;
        }
    }
}


int main(void) {
// 6 vectors indicating that we are sampling too fast
    addVector("0000 0000 0000 0000 0000 0000 0000 0xxx", 0);
    addVector("1000 0000 0000 0000 0000 0000 0000 0xxx", 0);
    addVector("1000 0000 0000 0000 0000 0000 0000 1xxx", 0);
    addVector("1000 0000 0000 0000 0000 0000 0001 1xxx", 0);
    addVector("1000 0000 0000 0000 0000 0000 0011 1xxx", 0);
//    addVector("1000 0000 0000 0000 0000 0000 0111 1xxx", 0);
// 4800 double violations
    addVector("1100 0000 0000 1111 1111 1111 1100 0xxx", 26);
    addVector("1100 0000 0000 0111 1111 1111 1100 0xxx", 26);
    addVector("1100 0000 0000 0011 1111 1111 1100 0xxx", 26);
    addVector("1100 0000 0000 0001 1111 1111 1100 0xxx", 26);
    addVector("1100 0000 0000 0000 1111 1111 1100 0xxx", 26);
// 44100 family of speeds
    addVector("1000 0000 0000 0111 1111 1111 1110 0xxx", 27);
    addVector("1000 0000 0000 0011 1111 1111 1110 0xxx", 27);
    addVector("1000 0000 0000 0001 1111 1111 1110 0xxx", 27);
    addVector("1000 0000 0000 0011 1111 1111 1111 0xxx", 28);
    addVector("1000 0000 0000 0001 1111 1111 1111 0xxx", 28);

    buildHash();
    return 0;
}
