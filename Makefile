ZHOME?=..

include $(ZHOME)/includes/zmake.inc


SRCglslrun=*.c
ZLIBS=       -lzgl -lzmem -lzstructures -lzthread -lglfw -lGL -lcurses

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



4kbas32:
	wget -O 4kbas32 https://github.com/companje/Altair8800/raw/master/data/4kbas32.bin



debugger: glslrun
	DEBUGINFOD_URLS=""  gdb -q -x cmds.gdb ./glslrun
