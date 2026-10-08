#include <stdio.h>


#include "ztypes.h"
#include "zmem.h"
#include "zarray.h"
#include "zstring.h"
#include "zgl.h"
#include "GLFW/glfw3.h"




void errorHandler(int error, const char* message) {
	printf(" glfw e");
	printf("GLFW ERROR:%d (0x%x) %s\n", error, error, message ? message : "null");

}

int main(int argc, char** args){


	if (!glfwInit()) {
		printf(" Can't init glfw\n");
		return 1;
	}

	if (argc < 2){
		printf("Need filename\n");
		return 1;
	}

	char* source = ram_loadstr(args[1]);
	if (!source){
		printf("Can't read %s\n", args[1]);
		return 1;
	}

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


	int issbo = 0;
	zglCheckError(__LINE__);


	int idata[4] = { 1, 0xff , 0x7f , 2};


	glGenBuffers(1, &issbo);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, issbo);
	glBufferData(GL_SHADER_STORAGE_BUFFER,  sizeof(idata), idata, GL_DYNAMIC_COPY);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

	zglCheckError(__LINE__);

	glUseProgram(shader);

	zglCheckError(__LINE__);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, issbo);


	//run it
	zglCheckError(__LINE__);
	glDispatchCompute(1, 1, 1);

	zglCheckError(__LINE__);
	glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

	zglCheckError(__LINE__);


	glBindBuffer(GL_SHADER_STORAGE_BUFFER, issbo);
	glGetBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, sizeof(idata), idata);


	for (int i=0;i<sizeof(idata)/sizeof(idata[0]);i++)
		printf("%x ", idata[i]);
	printf("\n");


	ram_free(sg);
	ram_allocs();

	return 0;
}
