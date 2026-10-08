ZHOME?=..

include $(ZHOME)/includes/zmake.inc


SRCglslrun=*.c
ZLIBS=       -lzgl -lzmem -lzstructures -lzthread -lglfw -lGL

#: -lzmem -lzstructures -lzgl  -lglfw -lGL
#-lzstructures   -lzgl -lglfw -lGL -lzmem
LIBS=

glslrun: $(SRCglslrun) *.h $(INCDIR)/*.h
	$(CC) $(CFLAGS) -o $@ $(SRCglslrun) -L$(OBJDIR) $(ZLIBS) $(LIBS)

clean: 
	-rm glslrun


run: 
	./glslrun
	#gdb -ex run ./glslrun



debugger: glslrun
	DEBUGINFOD_URLS=""  gdb -q -x cmds.gdb ./glslrun
