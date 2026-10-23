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


#define POP2(h,l)        { (l) = RD_BYTE(SP++); (h) = RD_BYTE(SP++); }
#define PUSH2(h,l)       { WR_BYTE(--SP, h); WR_BYTE(--SP, l);  }

#define POP16(w)        { w = RD_BYTE(SP++); w |=RD_BYTE(SP++)<<8 ; }

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
    S_FLAG = BOOL((((reg) & 0x80) != 0));             \
    Z_FLAG = BOOL((reg) == 0);                      \
    H_FLAG = BOOL(((reg) & 0x0f) == 0);             \
    P_FLAG = PARITY(reg);                       \
    reg = reg&0xff;\
}

#define DCR(reg) \
{                                               \
    --(reg);                                    \
    S_FLAG = BOOL(((reg) & 0x80) != 0);             \
    Z_FLAG = BOOL((reg) == 0);                      \
    H_FLAG = BOOL(!(((reg) & 0x0f) == 0x0f));         \
    P_FLAG = PARITY(reg);                       \
    reg = reg&0xff;\
}


#define TST(flag)       ((flag)!=0)
#define RD_WORD(addr)  ((mem[addr+1]<<8) | mem[addr])

#define CALL \
{             	\
    PUSH2(  (PC+2)>>8  , (PC + 2)&0xff    );  \
    PC = RD_WORD(PC);                           \
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

        h=v>>8;
        l=v&0xff;
}


void main() {


    loadstate();
    current.calladdr = PC;
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

        case 0x05:            /* dcr b */
            //cpu_cycles = 5;
            DCR(B);
            break;

        case 0x06:            /* mvi b, data8 */
            //cpu_cycles = 7;
            B = RD_BYTE(PC++);
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

        case 0x21:             /* lxi h, data16 */
            //cpu_cycles = 10;

            //HL = RD_WORD(PC);
            SET16(H, L, RD_WORD(PC));
            PC += 2;
            break;

        case 0x23:            /* inx h */
            //cpu_cycles = 5;
            //HL++;
            SET16(H,L, WORD(H,L)+1);
            break;

        case 0x31:            /* lxi sp, data16 */
            //cpu_cycles = 10;
            SP = RD_WORD(PC);
            PC += 2;
            break;


        case 0x3A:            /* lda addr */
            //cpu_cycles = 13;
            work16 = RD_WORD(PC);
            A = RD_BYTE(work16);
            PC += 2;
            break;

        case 0x3C:            /* inr a */
            //cpu_cycles = 5;
            INR(A);
            break;

        case 0x3E:            /* mvi a, data8 */
            //Scpu_cycles = 7;
            A = RD_BYTE(PC++);
            break;


        case 0x78:            /* mov a, b */
            //cpu_cycles = 5;
            A = B;
            break;

        case 0x79:            /* mov a, c */
            //cpu_cycles = 5;
            A = C;
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

        case 0xDA:            /* jc addr */
            //cpu_cycles = 10;
            if (TST(C_FLAG)) {
                PC = RD_WORD(PC);
            } else {
                PC += 2;
            }
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

        case 0xE0:            /* rpo */
            //cpu_cycles = 5;
            if (!TST(P_FLAG)) {
                //cpu_cycles = 11;
                POP16(PC);
            }
            break;


        case 0xE1:            /* pop h */
            //cpu_cycles = 11;
            //POP(HL);
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

          case 0xEC:            /* cpe addr */
            if (TST(P_FLAG)) {
                //cpu_cycles = 17;
                CALL;
            } else {
                //cpu_cycles = 11;
                PC += 2;
            }
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

        case 0xF5:            /* push psw */
            //cpu_cycles = 11;
            //i8080_store_flags();
            PUSH2(A, i8080_pack_flags());
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


    savestate();
}

