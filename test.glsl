#version 430
layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout (std430, binding=1) buffer idata{ int di[]; };

//copy some stuff from 8080core to see how well it can compile





int PARITY(int reg){

 int par;

 par  = (reg>>4) ^ (reg); //fold 8 to 4

 //ABCDEFGH
 //    ABCD


 par = (par>>2) ^ par;   //fold 4 to 2

 //ABCDEFGH
 //    ABCD
 //  ABCDEF
 //      AB



 par = (par>>1) ^ par;  //fold 2 to 1

 //ABCDEFGH
 //    ABCD
 //  ABCDEF
 //      AB
 // ABCDEFG
 //     ABC
 //   ABCDE
 //       A


 //select rightmost bit and flip

 return (par ^ 1) & 1;

}
int S_FLAG;
int Z_FLAG;
int H_FLAG;
int P_FLAG;

#define INR(reg) \
{                                               \
    ++(reg);\
    reg&=0xff; \
    S_FLAG = (((reg) & 0x80) != 0)?1:0;             \
    Z_FLAG = ((reg) == 0)?1:0;                      \
    H_FLAG = (((reg) & 0x0f) == 0)?1:0;             \
    P_FLAG = PARITY(reg);                       \
}

void main() {


    int i;
    for (i=0;i<4;i++){

        INR(di[i]);

        di[i] |=di[i]  |  (S_FLAG<<24) | (Z_FLAG<<20) | (H_FLAG << 16) | (P_FLAG << 12) | (0xf<<8);

    }

}

