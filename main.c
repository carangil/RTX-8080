#include <stdio.h>


#include "ztypes.h"
#include "zmem.h"
#include "zarray.h"
#include "zstring.h"
#include "zgl.h"
#include "GLFW/glfw3.h"

typedef struct state8080{
	int memlen;
	int A;
	int B;
	int C;
	int D;
	int E;
	int H;
	int L;
	int PC;
	int SP;
	int calladdr;
	int S_FLAG;
	int Z_FLAG;
	int H_FLAG;
	int C_FLAG;
	int P_FLAG;
	int fault;
} state8080;



void errorHandler(int error, const char* message) {
	printf(" glfw e");
	printf("GLFW ERROR:%d (0x%x) %s\n", error, error, message ? message : "null");

}


void printbuffer(int* intdata, int datalen){

	for (int i=0;i<datalen;i++){
		if (0==(i&15))
			printf("\n%04x:",i);

		printf("%02x ", intdata[i]);
	}
	printf("\n");
}
/*
void printstate(state8080* state){
	printf("%x memlen ", state->memlen);
	printf("A:%02x B:%02x C:%02x D:%02x E:%02x  PC:%02x  SP:%02x  calladdr:%04x",
		   state->A, state->B, state->C, state->D, state->E, state->PC, state->SP, state->calladdr);

	printf(" S%d Z%d H%d C%d P%d ",
		state->S_FLAG,
		state->Z_FLAG,
		state->H_FLAG,
		state->C_FLAG,
		state->P_FLAG);

	printf("\n");

}
*/


(*syscalls[256])(state8080* state, int* mem) = {NULL};

void C_WRITESTR(state8080* state, int* mem){
	int ptr = (state->D <<8 | state->E) & 0xffff;

	while (mem[ptr]!='$'){
		fputc(mem[ptr++], stdout);
		ptr &= 0xffff;
	}

}


int main(int argc, char** args){


	if (!glfwInit()) {
		printf(" Can't init glfw\n");
		return 1;
	}


	char* datafile = NULL;

	if (argc < 2){
		printf("Need filename\n");
		return 1;
	}


	int start =0;

	for (int i=2;i<argc;i++){

		if (!strcmp(args[i], "-data") && ((i+1) < argc)){
			datafile = args[i+1];
			i++;
			continue;
		}


		if (!strcmp(args[i], "-start") && ((i+1) < argc)){
			start = atoi(args[i+1]);
			i++;
			continue;
		}


	}


	char* source = ram_loadstr(args[1]);
	if (!source){
		printf("Can't read %s\n", args[1]);
		return 1;
	}
	printf("%s\n", source);


	char* data = NULL;
	int datalen = 0;
	if (datafile){
		printf(" Loading from %s\n", datafile);
		data = 	ram_loadbin(datafile, &datalen, 0);  //note:loadstr will add a null terminator, but that is harmless

		printf("%p %d bytes start at %x\n", data, datalen, start);
	}

	int* intdata = NULL;

	if (data) {
		intdata = zarray_alloc(int, 0x10000);


		for (int i=0;i<datalen;i++){
			intdata[start+i] = data[i] & 0xff;
		}


		for (int i=0;i<datalen+start;i++){
			if (0==(i&15))
				printf("\n%04x:",i);

			printf("%02x ", intdata[i]);
		}
		printf("\n");


	}
	datalen = 0x10000; //full memory




	glfwSetErrorCallback(errorHandler);
	//4.3 is minimum glsl version with compute shader
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
	glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE); // do not show the window

	GLFWwindow* win = glfwCreateWindow(320, 200, "Test", NULL, NULL); //something needs to be retro... might as well be the window size
	glfwMakeContextCurrent(win);
	zgl_init(glfwGetProcAddress);
	zglCheckError(__LINE__);

	/*
	while(1){
		int w,h;

		glfwPollEvents();
ram_free(source)
		glfwGetWindowSize(win, &w, &h);
		glViewport(0, 0, w, h);
		glClearColor(.5,100 0, 0, 1); //something that isn't white or black (red)
	pop	h
);

		glClear(GL_COLOR_BUFFER_BIT);
		glfwSwapBuffers(win);

	}
	*/


	zglShaderGroupT* sg = zglCreateComputeShader(NULL, source, NULL);

	printf(" Created shader group %p\n", sg);

	ram_free(source);
	source = NULL;

	char* log = NULL;
	int shader = zglFindVariant(sg, 0, &log);



	zglCheckError(__LINE__);

	if (log) {
		printf("glsl Compile log:%s\n", log);
		ram_free(log);
		log= NULL;
	}

	//setup data

	if (!shader)
		exit(1);

	int issbo = 0;
	zglCheckError(__LINE__);




	glGenBuffers(1, &issbo);


	state8080 state = {0};
	state.memlen = datalen;
	state.PC=start;
	state.SP = 0x800;

	intdata[5] = 0x8000; //trap instruction for CP/M calls
	syscalls[9] = C_WRITESTR;

	//printstate(&state);

	int statessbo = 0;

	glGenBuffers(1, &statessbo);



	zglCheckError(__LINE__);

	glUseProgram(shader);

	zglCheckError(__LINE__);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, issbo);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, statessbo);


	printbuffer(intdata, datalen);
	//send data
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, issbo);
	glBufferData(GL_SHADER_STORAGE_BUFFER,  datalen*sizeof(intdata[0]), intdata, GL_DYNAMIC_COPY);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);


	int use_instruction[256]={0};


	for (int iterations = 0; iterations <1059;iterations++){

		//fprintf(stderr, "%04x\n", state.PC);


		if (state.PC == 0){
			fprintf(stderr, "Jump to 0x0000: Terminate\n");
			break;
		}

		fprintf(stderr, "%04x\t", state.PC);


        fprintf(stderr, "a:%02x b:%02x c:%02x d:%02x e:%02x h:%02x l:%02x sp:%02x flags:%d%d%d%d%d",
        state.A,state.B,state.C,state.D,state.E,state.H,state.L,state.SP,
        state.C_FLAG,state.P_FLAG,state.H_FLAG,state.Z_FLAG,state.S_FLAG);
		fprintf(stderr, "\n");

		if (intdata[state.PC] < 256)
			use_instruction[  intdata[state.PC] ] ++;

		//send state
		glBindBuffer(GL_SHADER_STORAGE_BUFFER, statessbo);
		glBufferData(GL_SHADER_STORAGE_BUFFER,  sizeof(state), &state, GL_DYNAMIC_COPY);
		glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

		//run it
		zglCheckError(__LINE__);
		glDispatchCompute(1, 1, 1);

		zglCheckError(__LINE__);
		glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

		zglCheckError(__LINE__);


		//get state
		glBindBuffer(GL_SHADER_STORAGE_BUFFER, statessbo);
		glGetBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, sizeof(state), &state);

		//printstate(&state);
		if (state.fault){
			fprintf(stderr, "%04x  fault %x\n", state.PC, state.fault);


			if (state.fault & 0x10000000){
				int op = state.fault&0xffff;

				if (op <256)
					use_instruction[op] = 0; //didn't 'use' an unimplemented instruction

				if (op == 0x8000){

					int call = state.C;

					fprintf(stderr, "syscall %x\n", call);

					if (syscalls[call])
						syscalls[call](&state, intdata);

					state.PC = intdata[state.SP];
					state.SP+=2;
				}

				state.fault=0;
			}
		}
	}

	//get data back
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, issbo);
	glGetBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, datalen*sizeof(intdata[0]), intdata);


	//printbuffer(intdata, datalen);



	fprintf(stderr, "Instructions used:\n");
	for (int i=0;i<256;i++){
		if (use_instruction[i])
			fprintf(stderr, "%02x\n", i, use_instruction[i]);
	}



	ram_free(data);
	ram_free(intdata);
	ram_free(sg);
	ram_allocs();

	return 0;
}
