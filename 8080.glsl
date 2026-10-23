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


#define TST(flag)       ((flag)!=0)
#define RD_WORD(addr)  ((mem[addr+1]<<8) | mem[addr]);

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


void main() {


    loadstate();
    current.calladdr = PC;
    int op = RD_BYTE(PC++);

    switch(op){

        case 0x00: //NOP
            break;

        case 0x31:            /* lxi sp, data16 */
            //cpu_cycles = 10;
            SP = RD_WORD(PC);
            PC += 2;
            break;

        case 0x3E:            /* mvi a, data8 */
            //Scpu_cycles = 7;
            A = RD_BYTE(PC++);
            break;

        case 0xFE:            /* cpi data8 */
            //cpu_cycles = 7;

            work8 = RD_BYTE(PC++);
            CMP(work8);
            break;


        case 0xF1:            /* pop psw */
            //cpu_cycles = 10;

            POP2(A, work8);
            i8080_retrieve_flags(work8);
            break;


         case 0x7C:            /* mov a, h */
            //cpu_cycles = 5;
            A = H;
            break;


         case 0x7D:            /* mov a, l */
            //cpu_cycles = 5;
            A = L;
            break;


        case 0xCA:            /* jz addr */
            //cpu_cycles = 10;
            if (TST(Z_FLAG)) {
                PC = RD_WORD(PC);
            } else {
                PC += 2;
            }
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



        case 0xD1:            /* pop d */
            //cpu_cycles = 11;
            POP2(D,E);
            break;


        case 0xD5:            /* push d */
            //cpu_cycles = 11;
            PUSH2(D,E);
            break;

        case 0xC1:            /* pop b */
            //cpu_cycles = 11;
            POP2(B,C);
            break;


        case 0xE1:            /* pop h */
            //cpu_cycles = 11;
            //POP(HL);
            POP2(H,L);
            break;

        case 0xC3:            /* jmp addr */
        case 0xCB:            /* jmp addr, undocumented */
            //cpu_cycles = 10;
            PC = RD_WORD(PC);
            break;


        case 0xCD:            /* call addr */
        case 0xDD:            /* call, undocumented */
        case 0xED:
        case 0xFD:
            //cpu_cycles = 17;
            CALL;
            break;


        case 0xE5:            /* push h */
            //cpu_cycles = 11;
            PUSH2(H,L);
            break;

        default:
            current.fault = 0x1000 | op;

    }


    savestate();
}

