xc.exe: xc.asm
	tasm /w2 xc.asm
	tlink xc.obj
	del xc.obj
	del xc.map
	upx --best xc.exe

clean:
	del xc.exe
