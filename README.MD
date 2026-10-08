
# Retrochallenge 2026/10   RTX-8080

I will be posting 

## GLSL Runner

This is a simple project that runs a glsl compute shader and returns the result.

The shader contains some bit manipulation macros taken from https://github.com/carangil/i8080-core , as my plans are to port the 8080 emulator to GLSL


## Target platform

Linux, for now.

## Dependencies:  

*This program uses some utility functions from another project currently named Geranium.  Geranium is an interpreted programming language in development that is unrelated to this project, but has a lot of things to make C programming and OpenGL a bit easier, so I'm importing it here as a dependency.  I plan to split Geranium into two seperate projects: the interpreter and the helpers, but that's not the focus currently.
*


Geranium: https://github.com/carangil/Geranium

GLFW3: dev packages included in most Linux distros.  One of my first search results gave this page, and it looks mostly correct after a quick glance. ( https://www.developnsolve.com/linux/how-to-install-glfw-on-linux )


### Building
```

#Make a directory for all this stuff:

mkdir foo
cd foo

#clone Geranium:

git clone https://github.com/carangil/Geranium

cd Geranium
make

# If successful, it should say 'done.' If you got errors, I guess you have work to do

cd ..

#clone this repo

git clone https://github.com/carangil/RC2026-10

cd RC2026-10

#set the ZHOME variable to point to Geranium

export ZHOME=../Geranium
make

# run it

./glslrun test.glsl


```

Running it should output a bunch of debugging stuff, but eventually print this out:


```
f02 111f00 1010f80 1f03 
```

That's the output of the glsl compute shader.


