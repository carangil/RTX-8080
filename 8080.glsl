#version 430
layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

struct state8080{
	int memlen;
	int xA;
	int xB;
	int xC;
	int xD;
	int xE;
    int xH;
    int xL;
	int xPC;
	int xSP;
	int calladdr;
	int xS_FLAG;
	int xZ_FLAG;
	int xH_FLAG;
	int xC_FLAG;
	int xP_FLAG;
    int xIFF;
    int fault;
};

#define A current.xA
#define B current.xB
#define C current.xC
#define D current.xD
#define E current.xE
#define H current.xH
#define L current.xL
#define SP current.xSP
#define PC current.xPC
#define S_FLAG current.xS_FLAG
#define Z_FLAG current.xZ_FLAG
#define H_FLAG current.xH_FLAG
#define C_FLAG current.xC_FLAG
#define P_FLAG current.xP_FLAG
#define IFF current.xIFF



layout (std430, binding=0) buffer statedata{
     state8080 saved;
};

layout (std430, binding=1) buffer idata{ int mem[]; };

//cpu state

state8080 current;

void loadstate(){
    current = saved;
}

void savestate(){
    saved = current;
}

int half_carry_table[] = { 0, 0, 1, 0, 1, 0, 1, 1 };
int sub_half_carry_table[] = { 0, 1, 1, 1, 0, 0, 0, 1 };


#define RD_BYTE(addr) mem[addr]
#define WR_BYTE(addr, value)  mem[addr]=value;


#define WR_WORD(addr, value)  mem[addr] = (value)&0xff; mem[addr+1] = (value)>>8;


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
int work16;
int work8;
int varindex;

#define BOOL(X)  ((X)?1:0)

#define FIXSP  (SP &=0xFFFF)

#define POP2(h,l)        { (l) = RD_BYTE(SP++);FIXSP ;(h) = RD_BYTE(SP++);FIXSP; }
#define PUSH2(h,l)       { SP--;FIXSP; WR_BYTE(SP, h); SP--;FIXSP;WR_BYTE(SP, l);  }

#define POP16(w)        { w = RD_BYTE(SP++);FIXSP; w |=RD_BYTE(SP++)<<8 ;FIXSP; }

#define WORD(h,l)  ( (h<<8) | (l)   )



void CMP(int val)
{
    work16 = A - (val);



    varindex = ((A & 0x88) >> 1) |
            (((val) & 0x88) >> 2) |
            ((work16 & 0x88) >> 3);
    S_FLAG = BOOL( ((work16 & 0x80) != 0));
    Z_FLAG = BOOL(((work16 & 0xff) == 0));
    H_FLAG = (1-sub_half_carry_table[varindex & 0x7]);

    C_FLAG = BOOL(((work16 & 0x0100) != 0));
    P_FLAG = PARITY(work16 & 0xff);
}

#define CLR(flag)       (flag = 0)
#define SET(flag)       (flag = 1)

#define CPL(flag)       (flag = 1-(flag))

void ANA(int val)
{
    H_FLAG =BOOL( ((A | val) & 0x08) != 0);
    A &= (val);
    S_FLAG = BOOL(((A & 0x80) != 0));
    Z_FLAG = BOOL(A == 0);
    P_FLAG = PARITY(A);
    CLR(C_FLAG);
}


#define INR(reg) \
{                                               \
    ++(reg);                                    \
    reg = reg&0xff;\
    S_FLAG = BOOL((((reg) & 0x80) != 0));             \
    Z_FLAG = BOOL((reg) == 0);                      \
    H_FLAG = BOOL(((reg) & 0x0f) == 0);             \
    P_FLAG = PARITY(reg);                       \
}

#define DCR(reg) \
{                                               \
    --(reg);\
    reg = reg&0xff;\
    S_FLAG = BOOL(((reg) & 0x80) != 0);             \
    Z_FLAG = BOOL((reg) == 0);                      \
    H_FLAG = BOOL(!(((reg) & 0x0f) == 0x0f));         \
    P_FLAG = PARITY(reg);                       \
}


void ADD(int val) {
    work16 = A + (val);
    varindex = ((A & 0x88) >> 1) |
            (((val) & 0x88) >> 2) |
            ((work16 & 0x88) >> 3);
    A = work16 & 0xff;
    S_FLAG = BOOL((A & 0x80) != 0);
    Z_FLAG = BOOL(A == 0);
    H_FLAG = half_carry_table[varindex & 0x7];
    P_FLAG = PARITY(A);
    C_FLAG = BOOL((work16 & 0x0100) != 0);
}


void ADC(int val)
{
    work16 = A + (val) + C_FLAG;
    varindex = ((A & 0x88) >> 1) |
            (((val) & 0x88) >> 2) |
            ((work16 & 0x88) >> 3);
    A = work16 & 0xff;
    S_FLAG = BOOL((A & 0x80) != 0);
    Z_FLAG = BOOL(A == 0);
    H_FLAG = half_carry_table[varindex & 0x7];
    P_FLAG = PARITY(A);
    C_FLAG = BOOL((work16 & 0x0100) != 0);
}

void SUB(int val)
{
    work16 = A - (val);
    varindex = ((A & 0x88) >> 1) |
            (((val) & 0x88) >> 2) |
            ((work16 & 0x88) >> 3);
    A = work16 & 0xff;
    S_FLAG = BOOL((A & 0x80) != 0);
    Z_FLAG = BOOL(A == 0);
    H_FLAG = 1-sub_half_carry_table[varindex & 0x7];
    P_FLAG = PARITY(A);
    C_FLAG = BOOL((work16 & 0x0100) != 0);
}

void SBB(int val)
{
    work16 = A - (val) - C_FLAG;

    varindex = ((A & 0x88) >> 1) |
            (((val) & 0x88) >> 2) |
            ((work16 & 0x88) >> 3);
    A = work16 & 0xff;
    S_FLAG = BOOL((A & 0x80) != 0);
    Z_FLAG = BOOL(A == 0);
    H_FLAG = 1-sub_half_carry_table[varindex & 0x7];
    P_FLAG = PARITY(A);
    C_FLAG = BOOL((work16 & 0x0100) != 0);

}

void ORA(int val)
{
    A |= (val);
    S_FLAG = BOOL((A & 0x80) != 0);
    Z_FLAG = BOOL(A == 0);
    CLR(H_FLAG);
    P_FLAG = PARITY(A);
    CLR(C_FLAG);
}


void XRA(int val)
{
    A ^= (val);
    S_FLAG = BOOL((A & 0x80) != 0);
    Z_FLAG = BOOL(A == 0);
    CLR(H_FLAG);
    P_FLAG = PARITY(A);
    CLR(C_FLAG);
}


void DAD( int reg)
{

    //do bottom 8 bit add
    work16 = L + (reg & 0xFF);

    work8 = work16 & 0xff;  //take bottom 8 bits
    work16 = work16 >>8;  //shift right any carry left over

    work16 += H;  //add in H
    work16 += (reg>>8); //add in top part of reg


    //set carry if top byte exceeded 8 bits
    if (work16 > 0xff)
        C_FLAG = 1;
    else
        C_FLAG = 0;

    //bottom of work16 has H byte
    H = work16 & 0xff;

    //work8 has the saved L byte
    L = work8;



}


#define SWAP(a,b)  work8=b; b=a; a=work8;

#define TST(flag)       ((flag)!=0)
#define RD_WORD(addr)  ((mem[addr+1]<<8) | mem[addr])

#define CALL \
{             	\
    PUSH2(  (PC+2)>>8  , (PC + 2)&0xff    );  \
    PC = RD_WORD(PC);                           \
}


void RST(int addr)
{
    PUSH2(  (PC)>>8  , (PC)&0xff    );
    PC = (addr);
}


#define F_CARRY         0x01
#define F_UN1           0x02
#define F_PARITY        0x04
#define F_UN3           0x08
#define F_HCARRY        0x10
#define F_UN5           0x20
#define F_ZERO          0x40
#define F_NEG           0x80

void i8080_retrieve_flags(int F) {
    S_FLAG = (F & F_NEG)   ==0   ? 0 : 1;
    Z_FLAG = (F & F_ZERO)  ==0   ? 0 : 1;
    H_FLAG = (F & F_HCARRY)==0   ? 0 : 1;
    P_FLAG = (F & F_PARITY)==0   ? 0 : 1;
    C_FLAG = (F & F_CARRY) ==0  ? 0 : 1;
}


int i8080_pack_flags() {



    return  S_FLAG*F_NEG
            +Z_FLAG*F_ZERO
            +H_FLAG*F_HCARRY
            +P_FLAG*F_PARITY
            +C_FLAG*F_CARRY
            +F_UN1;

}



void SET16(inout int h, inout int l, int v){

        h=(v>>8)&0xff;
        l=v&0xff;
}

#define INC16(h,l, inc)   SET16(h,l, (WORD(h,l)+inc)&0xffff)


//temps
int carry;
int add;


#define ITER 100000

void main() {


    loadstate();
    current.calladdr = PC;
    for (int i=0;i<ITER;i++){

        if(current.fault!=0)
            break;
        PC = PC&0xFFFF;

        int op = RD_BYTE(PC++);

        switch(op){

            case 0x00:            /* nop */
            // Undocumented NOP.
            case 0x08:            /* nop */
            case 0x10:            /* nop */
            case 0x18:            /* nop */
            case 0x20:            /* nop */
            case 0x28:            /* nop */
            case 0x30:            /* nop */
            case 0x38:            /* nop */
                //cpu_cycles = 4;
                break;


            case 0x01:            /* lxi b, data16 */
                //cpu_cycles = 10;
                SET16(B,C, RD_WORD(PC));
                PC += 2;
                break;


            case 0x02:            /* stax b */
                //cpu_cycles = 7;
                WR_BYTE(WORD(B,C), A);
                break;


            case 0x03:            /* inx b */
                //cpu_cycles = 5;
                INC16(B, C, 1);
                break;

            case 0x04:            /* inr b */
                //cpu_cycles = 5;
                INR(B);
                break;

            case 0x05:            /* dcr b */
                //cpu_cycles = 5;
                DCR(B);
                break;

            case 0x06:            /* mvi b, data8 */
                //cpu_cycles = 7;
                B = RD_BYTE(PC++);
                break;


            case 0x07:            /* rlc */
                //cpu_cycles = 4;
                C_FLAG = BOOL((A & 0x80) != 0);
                A = (A << 1) | C_FLAG;
                A=A&0xFF;
                break;

            case 0x09:            /* dad b */
                //cpu_cycles = 10;
                DAD(WORD(B,C));
                break;


            case 0x0A:            /* ldax b */
                //cpu_cycles = 7;
                A = RD_BYTE(WORD(B,C));
                break;

            case 0x0B:            /* dcx b */
                //cpu_cycles = 5;
                INC16(B, C, -1);
                break;

            case 0x0C:            /* inr c */
                //cpu_cycles = 5;
                INR(C);
                break;

            case 0x0D:            /* dcr c */
                //cpu_cycles = 5;
                DCR(C);
                break;


            case 0x0E:            /* mvi c, data8 */
                //cpu_cycles = 7;
                C = RD_BYTE(PC++);
                break;


            case 0x0F:            /* rrc */
                //cpu_cycles = 4;
                C_FLAG = A & 0x01;
                A = (A >> 1) | (C_FLAG << 7);
                break;


            case 0x11:            /* lxi d, data16 */
                //cpu_cycles = 10;
                SET16(D,E,RD_WORD(PC));
                PC += 2;
                break;

            case 0x12:            /* stax d */
                //cpu_cycles = 7;
                WR_BYTE(WORD(D,E), A);
                break;

            case 0x13:            /* inx d */
                //cpu_cycles = 5;
                INC16(D,E,1);

                break;

            case 0x14:            /* inr d */
                //cpu_cycles = 5;
                INR(D);
                break;

            case 0x15:            /* dcr d */
                //cpu_cycles = 5;
                DCR(D);
                break;

            case 0x16:            /* mvi d, data8 */
                //cpu_cycles = 7;
                D = RD_BYTE(PC++);
                break;

            case 0x17:            /* ral */
                //cpu_cycles = 4;
                work8 = C_FLAG;
                C_FLAG =BOOL((A & 0x80) != 0);
                A = (A << 1) | work8;
                A = A &0xff;
                break;



        case 0x19:            /* dad d */
                //cpu_cycles = 10;
                DAD(WORD(D,E));
                break;


            case 0x1A:            /* ldax d */
                //cpu_cycles = 7;
                A = RD_BYTE(WORD(D,E));
                break;


            case 0x1B:            /* dcx d */
                //cpu_cycles = 5;
                INC16(D,E,-1);
                break;

            case 0x1C:            /* inr e */
                //cpu_cycles = 5;
                INR(E);
                break;

            case 0x1D:            /* dcr e */
                //cpu_cycles = 5;
                DCR(E);
                break;

            case 0x1E:            /* mvi e, data8 */
                //cpu_cycles = 7;
                E = RD_BYTE(PC++);
                break;


            case 0x1F:             /* rar */
                //cpu_cycles = 4;
                work8 = C_FLAG;
                C_FLAG = A & 0x01;
                A = (A >> 1) | (work8 << 7);
                break;


            case 0x21:             /* lxi h, data16 */
                //cpu_cycles = 10;

                //HL = RD_WORD(PC);
                SET16(H, L, RD_WORD(PC));
                PC += 2;
                break;


            case 0x22:            /* shld addr */
                //cpu_cycles = 16;
                WR_WORD(RD_WORD(PC), WORD(H,L));
                PC += 2;
                break;


            case 0x23:            /* inx h */
                //cpu_cycles = 5;
                INC16(H,L, 1);


                break;

            case 0x24:            /* inr h */
                //cpu_cycles = 5;
                INR(H);
                break;

            case 0x25:            /* dcr h */
                //cpu_cycles = 5;
                DCR(H);
                break;

            case 0x26:            /* mvi h, data8 */
                //cpu_cycles = 7;
                H = RD_BYTE(PC++);
                break;

                case 0x2C:            /* inr l */
                //cpu_cycles = 5;
                INR(L);
                break;

                        case 0x2A:            /* ldhl addr */
                //cpu_cycles = 16;
        //       HL = RD_WORD(RD_WORD(PC));
                SET16(H,L,RD_WORD(RD_WORD(PC)));
                PC += 2;
                break;


                case 0x27:            /* daa */
                //cpu_cycles = 4;
                carry = C_FLAG;
                add = 0;
                if ( (H_FLAG!=0) || (A & 0x0f) > 9) {
                    add = 0x06;
                }
                if ( (C_FLAG!=0) || (A >> 4) > 9 || ((A >> 4) >= 9 && (A & 0x0f) > 9)) {
                    add |= 0x60;
                    carry = 1;
                }
                ADD(add);
                P_FLAG = PARITY(A);
                C_FLAG = carry;
                break;


            case 0x29:            /* dad hl */
                //cpu_cycles = 10;
                DAD(WORD(H,L));
                break;


            case 0x2B:            /* dcx h */
                //cpu_cycles = 5;
                INC16(H,L,-1);
                break;

            case 0x2D:            /* dcr l */
                //cpu_cycles = 5;
                DCR(L);
                break;

                    case 0x2E:            /* mvi l, data8 */
                //cpu_cycles = 7;
                L = RD_BYTE(PC++);
                break;


                case 0x2F:            /* cma */
                //cpu_cycles = 4;
                A ^= 0xff;
                break;


            case 0x31:            /* lxi sp, data16 */
                //cpu_cycles = 10;
                SP = RD_WORD(PC);
                PC += 2;
                break;

            case 0x32:            /* sta addr */
                //cpu_cycles = 13;
                WR_BYTE(RD_WORD(PC), A);
                PC += 2;
                break;

            case 0x33:            /* inx sp */
                //cpu_cycles = 5;
                SP++;
                break;

            case 0x34:            /* inr m */
                //cpu_cycles = 10;
                work8 = RD_BYTE(WORD(H,L));
                INR(work8);
                WR_BYTE(WORD(H,L), work8);
                break;

            case 0x35:            /* dcr m */
                //cpu_cycles = 10;
                work8 = RD_BYTE(WORD(H,L));
                DCR(work8);
                WR_BYTE(WORD(H,L), work8);
                break;

            case 0x36:            /* mvi m, data8 */
                //cpu_cycles = 10;
                WR_BYTE(WORD(H,L), RD_BYTE(PC++));
                break;

            case 0x37:            /* stc */
                //cpu_cycles = 4;
                SET(C_FLAG);
                break;


            case 0x39:            /* dad sp */
                //cpu_cycles = 10;
                DAD(SP);
                break;


            case 0x3A:            /* lda addr */
                //cpu_cycles = 13;
                work16 = RD_WORD(PC);
                A = RD_BYTE(work16);
                PC += 2;
                break;


            case 0x3B:            /* dcx sp */
                //cpu_cycles = 5;
                SP--;
                SP=SP&0xFFFF;
                break;

            case 0x3C:            /* inr a */
                //cpu_cycles = 5;
                INR(A);
                break;

            case 0x3D:            /* dcr a */
                //cpu_cycles = 5;
                DCR(A);
                break;


            case 0x3E:            /* mvi a, data8 */
                //Scpu_cycles = 7;
                A = RD_BYTE(PC++);
                break;

            case 0x3F:            /* cmc */
                //cpu_cycles = 4;
                CPL(C_FLAG);
                break;

            case 0x40:            /* mov b, b */
                //cpu_cycles = 4;
                break;

            case 0x41:            /* mov b, c */
                //cpu_cycles = 5;
                B = C;
                break;

            case 0x42:            /* mov b, d */
                //cpu_cycles = 5;
                B = D;
                break;

            case 0x43:            /* mov b, e */
                //cpu_cycles = 5;
                B = E;
                break;

            case 0x44:            /* mov b, h */
                //cpu_cycles = 5;
                B = H;
                break;

            case 0x45:            /* mov b, l */
                //cpu_cycles = 5;
                B = L;
                break;

            case 0x46:            /* mov b, m */
                //cpu_cycles = 7;
                B = RD_BYTE(WORD(H,L));
                break;

            case 0x47:            /* mov b, a */
                //cpu_cycles = 5;
                B = A;
                break;

                case 0x48:            /* mov c, b */
                //cpu_cycles = 5;
                C = B;
                break;

            case 0x49:            /* mov c, c */
                //cpu_cycles = 5;
                break;

            case 0x4A:            /* mov c, d */
                //cpu_cycles = 5;
                C = D;
                break;

            case 0x4B:            /* mov c, e */
                //cpu_cycles = 5;
                C = E;
                break;

            case 0x4C:            /* mov c, h */
                //cpu_cycles = 5;
                C = H;
                break;

            case 0x4D:            /* mov c, l */
                //cpu_cycles = 5;
                C = L;
                break;

            case 0x4E:            /* mov c, m */
                //cpu_cycles = 7;
                C = RD_BYTE(WORD(H,L));
                break;


            case 0x4F:            /* mov c, a */
                //cpu_cycles = 5;
                C = A;
                break;


            case 0x50:            /* mov d, b */
                //cpu_cycles = 5;
                D = B;
                break;

            case 0x51:            /* mov d, c */
                //cpu_cycles = 5;
                D = C;
                break;

            case 0x52:            /* mov d, d */
                //cpu_cycles = 5;
                break;

            case 0x53:            /* mov d, e */
                //cpu_cycles = 5;
                D = E;
                break;

            case 0x54:            /* mov d, h */
                //cpu_cycles = 5;
                D = H;
                break;

            case 0x55:            /* mov d, l */
                //cpu_cycles = 5;
                D = L;
                break;

            case 0x56:            /* mov d, m */
                //cpu_cycles = 7;
                D = RD_BYTE(WORD(H,L));
                break;
            case 0x57:            /* mov d, a */
                //cpu_cycles = 5;
                D = A;
                break;


            case 0x58:            /* mov e, b */
                //cpu_cycles = 5;
                E = B;
                break;

            case 0x59:            /* mov e, c */
                //cpu_cycles = 5;
                E = C;
                break;

            case 0x5A:            /* mov e, d */
                //cpu_cycles = 5;
                E = D;
                break;

            case 0x5B:            /* mov e, e */
                //cpu_cycles = 5;
                break;

            case 0x5C:            /* mov c, h */
                //cpu_cycles = 5;
                E = H;
                break;

            case 0x5D:            /* mov c, l */
                //cpu_cycles = 5;
                E = L;
                break;

            case 0x5E:            /* mov c, m */
                //cpu_cycles = 7;
                E = RD_BYTE(WORD(H,L));
                break;

            case 0x5F:            /* mov c, a */
                //cpu_cycles = 5;
                E = A;
                break;

            case 0x60:            /* mov h, b */
                //cpu_cycles = 5;
                H = B;
                break;

            case 0x61:            /* mov h, c */
                //cpu_cycles = 5;
                H = C;
                break;

            case 0x62:            /* mov h, d */
                //cpu_cycles = 5;
                H = D;
                break;

            case 0x63:            /* mov h, e */
                //cpu_cycles = 5;
                H = E;
                break;
            case 0x64:            /* mov h, h */
                //cpu_cycles = 5;
                break;

            case 0x65:            /* mov h, l */
                //cpu_cycles = 5;
                H = L;
                break;
            case 0x66:            /* mov h, m */
                //cpu_cycles = 7;
                H = RD_BYTE(WORD(H,L));
                break;

            case 0x67:            /* mov h, a */
                //cpu_cycles = 5;
                H = A;
                break;

            case 0x68:            /* mov l, b */
                //cpu_cycles = 5;
                L = B;
                break;

            case 0x69:            /* mov l, c */
                //cpu_cycles = 5;
                L = C;
                break;


            case 0x6A:            /* mov l, d */
                //cpu_cycles = 5;
                L = D;
                break;

        case 0x6B:            /* mov l, e */
                //cpu_cycles = 5;
                L = E;
                break;
        case 0x6C:            /* mov l, h */
                //cpu_cycles = 5;
                L = H;
                break;

                case 0x6D:            /* mov l, l */
                //cpu_cycles = 5;
                break;

            case 0x6E:            /* mov l, m */
                //cpu_cycles = 7;
                L = RD_BYTE(WORD(H,L));
                break;

            case 0x6F:            /* mov l, a */
                //cpu_cycles = 5;
                L = A;
                break;


            case 0x70:            /* mov m, b */
                //cpu_cycles = 7;
                WR_BYTE(WORD(H,L), B);
                break;

            case 0x71:            /* mov m, c */
                //cpu_cycles = 7;
                WR_BYTE(WORD(H,L), C);
                break;

            case 0x72:            /* mov m, d */
                //cpu_cycles = 7;
                WR_BYTE(WORD(H,L), D);
                break;

            case 0x73:            /* mov m, e */
                //cpu_cycles = 7;
                WR_BYTE(WORD(H,L), E);
                break;

            case 0x74:            /* mov m, h */
                //cpu_cycles = 7;
                WR_BYTE(WORD(H,L), H);
                break;

            case 0x75:            /* mov m, l */
                //cpu_cycles = 7;
                WR_BYTE(WORD(H,L), L);
                break;

            case 0x76:            /* hlt */
    //             //cpu_cycles = 4
                PC--;
                current.fault = 0x80000000;
                break;

            case 0x77:            /* mov m, a */
                //cpu_cycles = 7;
                WR_BYTE(WORD(H,L), A)WORD(H,L);
                break;


            case 0x78:            /* mov a, b */
                //cpu_cycles = 5;
                A = B;
                break;

            case 0x79:            /* mov a, c */
                //cpu_cycles = 5;
                A = C;
                break;
            case 0x7A:            /* mov a, d */
                //cpu_cycles = 5;
                A = D;
                break;

            case 0x7B:            /* mov a, e */
                //cpu_cycles = 5;
                A = E;
                break;

            case 0x7C:            /* mov a, h */
                //cpu_cycles = 5;
                A = H;
                break;

            case 0x7D:            /* mov a, l */
                //cpu_cycles = 5;
                A = L;
                break;

            case 0x7E:            /* mov a, m */
                //cpu_cycles = 7;
                A = RD_BYTE(WORD(H,L));
                break;

            case 0x7F:            /* mov a, a */
                //cpu_cycles = 5;
                break;

            case 0x80:            /* add b */
                //cpu_cycles = 4;
                ADD(B);
                break;

            case 0x81:            /* add c */
                //cpu_cycles = 4;
                ADD(C);
                break;

            case 0x82:            /* add d */
                //cpu_cycles = 4;
                ADD(D);
                break;

            case 0x83:            /* add e */
                //cpu_cycles = 4;
                ADD(E);
                break;

            case 0x84:            /* add h */
                //cpu_cycles = 4;
                ADD(H);
                break;

            case 0x85:            /* add l */
                //cpu_cycles = 4;
                ADD(L);
                break;

            case 0x86:            /* add m */
                //cpu_cycles = 7;
                work8 = RD_BYTE(WORD(H,L));
                ADD(work8);
                break;

            case 0x87:            /* add a */
                //cpu_cycles = 4;
                ADD(A);
                break;

            case 0x88:            /* adc b */
                //cpu_cycles = 4;
                ADC(B);
                break;

            case 0x89:            /* adc c */
                //cpu_cycles = 4;
                ADC(C);
                break;

            case 0x8A:            /* adc d */
                //cpu_cycles = 4;
                ADC(D);
                break;

            case 0x8B:            /* adc e */
                //cpu_cycles = 4;
                ADC(E);
                break;

            case 0x8C:            /* adc h */
                //cpu_cycles = 4;
                ADC(H);
                break;

            case 0x8D:            /* adc l */
                //cpu_cycles = 4;
                ADC(L);
                break;

            case 0x8E:            /* adc m */
                //cpu_cycles = 7;
                work8 = RD_BYTE(WORD(H,L));
                ADC(work8);
                break;

            case 0x8F:            /* adc a */
                //cpu_cycles = 4;
                ADC(A);
                break;

            case 0x90:            /* sub b */
                //cpu_cycles = 4;
                SUB(B);
                break;

            case 0x91:            /* sub c */
                //cpu_cycles = 4;
                SUB(C);
                break;

            case 0x92:            /* sub d */
                //cpu_cycles = 4;
                SUB(D);
                break;

            case 0x93:            /* sub e */
                //cpu_cycles = 4;
                SUB(E);
                break;

            case 0x94:            /* sub h */
                //cpu_cycles = 4;
                SUB(H);
                break;

            case 0x95:            /* sub l */
                //cpu_cycles = 4;
                SUB(L);
                break;

            case 0x96:            /* sub m */
                //cpu_cycles = 7;
                work8 = RD_BYTE(WORD(H,L));
                SUB(work8);
                break;

            case 0x97:            /* sub a */
                //cpu_cycles = 4;
                SUB(A);
                break;

            case 0x98:            /* sbb b */
                //cpu_cycles = 4;
                SBB(B);
                break;

            case 0x99:            /* sbb c */
                //cpu_cycles = 4;
                SBB(C);
                break;

            case 0x9A:            /* sbb d */
                //cpu_cycles = 4;
                SBB(D);
                break;

            case 0x9B:            /* sbb e */
                //cpu_cycles = 4;
                SBB(E);
                break;

            case 0x9C:            /* sbb h */
                //cpu_cycles = 4;
                SBB(H);
                break;

            case 0x9D:            /* sbb l */
                //cpu_cycles = 4;
                SBB(L);
                break;

            case 0x9E:            /* sbb m */
                //cpu_cycles = 7;
                work8 = RD_BYTE(WORD(H,L));
                SBB(work8);
                break;

            case 0x9F:            /* sbb a */
                //cpu_cycles = 4;
                SBB(A);
                break;

            case 0xA0:            /* ana b */
                //cpu_cycles = 4;
                ANA(B);
                break;

            case 0xA1:            /* ana c */
                //cpu_cycles = 4;
                ANA(C);
                break;

            case 0xA2:            /* ana d */
                //cpu_cycles = 4;
                ANA(D);
                break;

            case 0xA3:            /* ana e */
                //cpu_cycles = 4;
                ANA(E);
                break;

            case 0xA4:            /* ana h */
                //cpu_cycles = 4;
                ANA(H);
                break;

            case 0xA5:            /* ana l */
                //cpu_cycles = 4;
                ANA(L);
                break;

            case 0xA6:            /* ana m */
                //cpu_cycles = 7;
                work8 = RD_BYTE(WORD(H,L));
                ANA(work8);
                break;

            case 0xA7:            /* ana a */
                //cpu_cycles = 4;
                ANA(A);
                break;

            case 0xA8:            /* xra b */
                //cpu_cycles = 4;
                XRA(B);
                break;

            case 0xA9:            /* xra c */
                //cpu_cycles = 4;
                XRA(C);
                break;

            case 0xAA:            /* xra d */
                //cpu_cycles = 4;
                XRA(D);
                break;

            case 0xAB:            /* xra e */
                //cpu_cycles = 4;
                XRA(E);
                break;

            case 0xAC:            /* xra h */
                //cpu_cycles = 4;
                XRA(H);
                break;

            case 0xAD:            /* xra l */
                //cpu_cycles = 4;
                XRA(L);
                break;

            case 0xAE:            /* xra m */
                //cpu_cycles = 7;
                work8 = RD_BYTE(WORD(H,L));
                XRA(work8);
                break;

            case 0xAF:            /* xra a */
                //cpu_cycles = 4;
                XRA(A);
                break;

            case 0xB0:            /* ora b */
                //cpu_cycles = 4;
                ORA(B);
                break;

            case 0xB1:            /* ora c */
                //cpu_cycles = 4;
                ORA(C);
                break;

            case 0xB2:            /* ora d */
                //cpu_cycles = 4;
                ORA(D);
                break;

            case 0xB3:            /* ora e */
                //cpu_cycles = 4;
                ORA(E);
                break;

            case 0xB4:            /* ora h */
                //cpu_cycles = 4;
                ORA(H);
                break;

            case 0xB5:            /* ora l */
                //cpu_cycles = 4;
                ORA(L);
                break;

            case 0xB6:            /* ora m */
                //cpu_cycles = 7;
                work8 = RD_BYTE(WORD(H,L));
                ORA(work8);
                break;

            case 0xB7:            /* ora a */
                //cpu_cycles = 4;
                ORA(A);
                break;

            case 0xB8:            /* cmp b */
                //cpu_cycles = 4;
                CMP(B);
                break;

            case 0xB9:            /* cmp c */
                //cpu_cycles = 4;
                CMP(C);
                break;

            case 0xBA:            /* cmp d */
                //cpu_cycles = 4;
                CMP(D);
                break;

            case 0xBB:            /* cmp e */
                //cpu_cycles = 4;
                CMP(E);
                break;

            case 0xBC:            /* cmp h */
                //cpu_cycles = 4;
                CMP(H);
                break;

            case 0xBD:            /* cmp l */
                //cpu_cycles = 4;
                CMP(L);
                break;

            case 0xBE:            /* cmp m */
                //cpu_cycles = 7;
                work8 = RD_BYTE(WORD(H,L));
                CMP(work8);
                break;

            case 0xBF:            /* cmp a */
                //cpu_cycles = 4;
                CMP(A);
                break;

            case 0xC0:            /* rnz */
                //cpu_cycles = 5;
                if (!TST(Z_FLAG)) {
                    //cpu_cycles = 11;
                    POP16(PC);
                }
                break;

            case 0xC1:            /* pop b */
                //cpu_cycles = 11;
                POP2(B,C);
                break;

            case 0xC2:            /* jnz addr */
                //cpu_cycles = 10;
                if (!TST(Z_FLAG)) {
                    PC = RD_WORD(PC);
                }
                else {
                    PC += 2;
                }
                break;

            case 0xC3:            /* jmp addr */
            case 0xCB:            /* jmp addr, undocumented */
                //cpu_cycles = 10;
                PC = RD_WORD(PC);
                break;

                case 0xC9:            /* ret */
                case 0xD9:            /* ret, undocumented */
                //cpu_cycles = 10;
                POP16(PC);

                break;

            case 0xC4:            /* cnz addr */
                if (!TST(Z_FLAG)) {
                    //cpu_cycles = 17;
                    CALL;
                } else {
                    //cpu_cycles = 11;
                    PC += 2;
                }
                break;

            case 0xC5:            /* push b */
                //cpu_cycles = 11;
                PUSH2(B,C);
                break;


            case 0xC6:            /* adi data8 */
                //cpu_cycles = 7;
                work8 = RD_BYTE(PC++);
                ADD(work8);
                break;


            case 0xC8:            /* rz */
                //cpu_cycles = 5;
                if (TST(Z_FLAG)) {
                    //cpu_cycles = 11;
                    POP16(PC);
                }
                break;

            case 0xCA:            /* jz addr */
                //cpu_cycles = 10;
                if (TST(Z_FLAG)) {
                    PC = RD_WORD(PC);
                } else {
                    PC += 2;
                }
                break;

            case 0xCC:            /* cz addr */
                if (TST(Z_FLAG)) {
                    //cpu_cycles = 17;
                    CALL;
                } else {
                    //cpu_cycles = 11;
                    PC += 2;
                }
                break;

            case 0xCD:            /* call addr */
            case 0xDD:            /* call, undocumented */
            case 0xED:
            case 0xFD:
                //cpu_cycles = 17;
                CALL;
                break;


            case 0xCE:            /* aci data8 */
                //cpu_cycles = 7;
                work8 = RD_BYTE(PC++);
                ADC(work8);
                break;

                    case 0xCF:            /* rst 1 */
                //cpu_cycles = 11;
                RST(0x0008);
                break;



            case 0xD0:            /* rnc */
                //cpu_cycles = 5;
                if (!TST(C_FLAG)) {
                    //cpu_cycles = 11;
                    POP16(PC);
                }
                break;



            case 0xD1:            /* pop d */
                //cpu_cycles = 11;
                POP2(D,E);
                break;

            case 0xD2:            /* jnc addr */
                //cpu_cycles = 10;
                if (!TST(C_FLAG)) {
                    PC = RD_WORD(PC);
                } else {
                    PC += 2;
                }
                break;


            case 0xD3:            /* out port8 */

                current.fault = 0x40000000 | (RD_BYTE(PC++) | (A<<8)   );

                break;



            case 0xD4:            /* cnc addr */
                if (!TST(C_FLAG)) {
                    //cpu_cycles = 17;
                    CALL;
                } else {
                    //cpu_cycles = 11;
                    PC += 2;
                }
                break;

            case 0xD5:            /* push d */
                //cpu_cycles = 11;
                PUSH2(D,E);
                break;

                case 0xD8:            /* rc */
                //cpu_cycles = 5;
                if (TST(C_FLAG)) {


                    //cpu_cycles = 11;
                    POP16(PC);
                }
                break;


            case 0xD6:            /* sui data8 */
                //cpu_cycles = 7;
                work8 = RD_BYTE(PC++);
                SUB(work8);
                break;

            case 0xD7:            /* rst 2 */
                //cpu_cycles = 11;
                RST(0x0010);
                break;

            case 0xDA:            /* jc addr */
                //cpu_cycles = 10;
                if (TST(C_FLAG)) {
                    PC = RD_WORD(PC);
                } else {
                    PC += 2;
                }
                break;




            case 0xDB:            /* in port8 */

                current.fault = 0x20000000 | (RD_BYTE(PC++));

                break;


            case 0xDC:            /* cc addr */
                if (TST(C_FLAG)) {
                    //cpu_cycles = 17;
                    CALL;
                } else {
                    //cpu_cycles = 11;
                    PC += 2;
                }
                break;

            case 0xDE:            /* sbi data8 */
                //cpu_cycles = 7;
                work8 = RD_BYTE(PC++);
                SBB(work8);
                break;


            case 0xDF:            /* rst 3 */
                //cpu_cycles = 11;
                RST(0x0018);
                break;



            case 0xE0:            /* rpo */
                //cpu_cycles = 5;
                if (!TST(P_FLAG)) {
                    //cpu_cycles = 11;
                    POP16(PC);
                }
                break;


            case 0xE1:            /* pop h */
                //cpu_cycles = 11;

                POP2(H,L);
                break;


            case 0xE2:            /* jpo addr */
                //cpu_cycles = 10;
                if (!TST(P_FLAG)) {
                    PC = RD_WORD(PC);
                }
                else {
                    PC += 2;
                }
                break;

            case 0xE3:            /* xthl */
                //cpu_cycles = 18;

                work16 = RD_WORD(SP);
                WR_WORD(SP, WORD(H,L));
                SET16(H,L, work16);

                break;

            case 0xE4:            /* cpo addr */
                if (!TST(P_FLAG)) {
                    //cpu_cycles = 17;
                    CALL;
                } else {
                    //cpu_cycles = 11;
                    PC += 2;
                }
                break;

            case 0xE5:            /* push h */
                //cpu_cycles = 11;
                PUSH2(H,L);
                break;


            case 0xE6:            /* ani data8 */
                //cpu_cycles = 7;
                work8 = RD_BYTE(PC++);
                ANA(work8);
                break;

            case 0xE7:            /* rst 4 */
                //cpu_cycles = 11;
                RST(0x0020);
                break;


            case 0xE8:            /* rpe */
                //cpu_cycles = 5;
                if (TST(P_FLAG)) {
                    //cpu_cycles = 11;
                    POP16(PC);
                }
                break;

                case 0xE9:            /* pchl */
                //cpu_cycles = 5;
                PC = WORD(H,L);
                break;

            case 0xEA:            /* jpe addr */
                //cpu_cycles = 10;
                if (TST(P_FLAG)) {
                    PC = RD_WORD(PC);
                } else {
                    PC += 2;
                }
                break;


            case 0xEB:            /* xchg */
                //cpu_cycles = 4;

                SWAP(H,D);
                SWAP(L,E);

                break;


            case 0xEC:            /* cpe addr */
                if (TST(P_FLAG)) {
                    //cpu_cycles = 17;
                    CALL;
                } else {
                    //cpu_cycles = 11;
                    PC += 2;
                }
                break;


            case 0xEE:            /* xri data8 */
                //cpu_cycles = 7;
                work8 = RD_BYTE(PC++);
                XRA(work8);
                break;


            case 0xEF:            /* rst 5 */
                //cpu_cycles = 11;
                RST(0x0028);
                break;

            case 0xF0:            /* rp */
                //cpu_cycles = 5;
                if (!TST(S_FLAG)) {
                    //cpu_cycles = 11;
                    POP16(PC);
                }
                break;


            case 0xF1:            /* pop psw */
                //cpu_cycles = 10;

                POP2(A, work8);
                i8080_retrieve_flags(work8);
                break;

            case 0xF2:            /* jp addr */
                //cpu_cycles = 10;
                if (!TST(S_FLAG)) {
                    PC = RD_WORD(PC);
                } else {
                    PC += 2;
                }
                break;

                case 0xF4:            /* cp addr */
                if (!TST(S_FLAG)) {
                    //cpu_cycles = 17;
                    CALL;
                } else {
                    //cpu_cycles = 11;
                    PC += 2;
                }
                break;

            case 0xF3:            /* di */
                //cpu_cycles = 4;
                IFF = 0;


                break;

            case 0xF5:            /* push psw */
                //cpu_cycles = 11;
                //i8080_store_flags();
                PUSH2(A, i8080_pack_flags());
                break;


            case 0xF6:            /* ori data8 */
                //cpu_cycles = 7;
                work8 = RD_BYTE(PC++);
                ORA(work8);
                break;

            case 0xF7:            /* rst 6 */
                //cpu_cycles = 11;
                RST(0x0030);
                break;

            case 0xF8:            /* rm */
                //cpu_cycles = 5;
                if (TST(S_FLAG)) {
                    //cpu_cycles = 11;
                    POP16(PC);
                }
                break;

                case 0xFA:            /* jm addr */
                //cpu_cycles = 10;
                if (TST(S_FLAG)) {
                    PC = RD_WORD(PC);
                } else {
                    PC += 2;
                }
                break;


            case 0xF9:            /* sphl */
                //cpu_cycles = 5;
                SP = WORD(H,L);
                break;

        case 0xFB:            /* ei */
            //cpu_cycles = 4;
            IFF = 1;
            //i8080_hal_iff(IFF);
            break;

            case 0xFC:            /* cm addr */
                if (TST(S_FLAG)) {
                    //cpu_cycles = 17;
                    CALL;
                } else {
                    //cpu_cycles = 11;
                    PC += 2;
                }
                break;


            case 0xFE:            /* cpi data8 */
                //cpu_cycles = 7;

                work8 = RD_BYTE(PC++);
                CMP(work8);
                break;



            default:
                current.fault = 0x10000000 | op;

        }
    }

    savestate();
}

