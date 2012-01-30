.model small

;==================================================;
; Merubah integer di AX menjadi string 1 digit dan ;
; menyimpannya di [di]                             ;
;==================================================;
IntToStr1 macro
	xor	dx, dx
	div	ten
	add	dl, '0'
	mov	[di], dl
	sub	di, 1
endm

;===================================;
; Push All (8086 belum punya pusha) ;
;===================================;
apush	macro
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
endm

;=================================;
; Pop All (8086 belum punya popa) ;
;=================================;
apop	macro
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
endm

;==============================================================;
; Clear Screen dengan cara menscroll keseluruhan layar ke atas ;
;==============================================================;
Cls	macro
	mov	ax, 0600h
	xor	cx, cx
	mov	dx, 184fh
	mov	bh, 07
	int	10h
endm

;=========================================;
; Pindahkan posisi kursor ke lokasi (x,y) ;
;=========================================;
GotoXY	macro	x,y
	mov	ah, 02
	xor	bx, bx
	mov	dx, ((y)*256)+(x)
	int	10h
endm





;====================;
; Definisi Konstanta ;
;====================;

Key_Escape	equ	01h
Key_Up		equ	48h
Key_Down	equ	50h
Key_Enter	equ	1ch
Key_Tab		equ	0fh
Key_F2		equ	3ch
Key_F3		equ	3dh
Key_F4		equ	3eh
Key_F5		equ	3fh
Key_F6		equ	40h
Key_F7		equ	41h
Key_F8		equ	42h
Key_F9		equ	43h
Key_F10		equ	44h
Key_Home	equ	47h
Key_End		equ	4fh
Key_PageUp	equ	49h
Key_PageDown	equ	51h

buffer_size	equ	62*1024

max_path		equ	64
max_file		equ	13

view_attr		equ	07h
def_attr		equ	17h
dir_attr		equ	1fh
sel_attr		equ	30h
path_attr		equ	70h
title_attr		equ	1eh





;===============;
; Struktur Data ;
;===============;

PANELINFO	struc
	dir	dw	max_path dup (?)
	filter	db	"*.*"
		db	max_file-3 dup (?)
	files	dw	?
	nfiles	dw	?
	col	dw	?	; kolom awal tempat panel berada
	top	dw	0       ; indeks pertama file yang ditampilkan
	sel	dw	0       ; indeks file yang dipilih
PANELINFO	ends

FILEENTRY	struc
	fattr	db	?
	ftime	dw	?
	fdate	dw	?
	fsize	dd	?
	fname	db	13 dup (?)
FILEENTRY	ends



;===================;
; Definisi Variabel ;
;===================;

.data
head1	db	"ÚÄ ÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄ¿"
head2	db	"³    Name    ³  Size  ³   Date   ³Time ³"
;head3	db	"ÆÍÍÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍµ"
tempfmt db	"³            ³        ³          ³     ³"
foot1	db	"ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÙ"
foot2	db	"        2Chdir  3View   4Append 5Copy   6Rename 7Mkdir  8Delete 9Filter 10Quit  "
dirfmt	db	"<DIR>"

chdirmsg	db	"Change to directory: $"
filtermsg	db	"Change filter to: $"
deletemsg	db	"Really want to delete [y/n] ? $"
mkdirmsg	db	"Directory to create: $"
renamemsg	db	"Rename to: $"
appendmsg	db	"Append with: $"

ten	dw	10

panel1	PANELINFO	<?>
panel2	PANELINFO	<?>
active		dw	offset panel1	; panel yang sedang dipilih
inactive	dw	offset panel2   ; panel yang tidak dipilih
filefmt		db	81 dup (?)

nlines		dw	?
topline		dw	?

handle1		dw	?
handle2		dw	?

readbuf		db	257 dup (?)
input		db	max_path dup (?)
buffer		db	buffer_size dup (?)





;===============;
; Program Utama ;
;===============;
.code
.stack	100h
start:	mov	ax, @data
	mov	ds, ax
	mov	es, ax

        Cls
        GotoXY	79 24

        xor	ax, ax
        mov	[panel1.col], ax
        mov	ax, 40
        mov	[panel2.col], ax

	; Ambil current directory
	mov	ax, offset [panel1.dir]
	call	getDir
	mov	ax, offset [panel2.dir]
	call	getDir

	call	refreshDir
	call	drawScreen

ulang:	xor	ax, ax
	int	16h		; baca satu ketikan, keluaran di AH
	cmp	ah, Key_Up
	jz	go_up
	cmp	ah, Key_Down
	jz	go_down
	cmp	ah, Key_Home
	jz	go_home
	cmp	ah, Key_End
	jz	go_end
	cmp	ah, Key_PageUp
	jz	go_pageup
	cmp	ah, Key_PageDown
	jz	go_pagedown
	cmp	ah, Key_Enter
	jz	chdir
	cmp	ah, Key_Tab
	jz	switch
	cmp	ah, Key_F2
	jz	chdir2
	cmp	ah, Key_F3
	jz	view
	cmp	ah, Key_F4
	jz	append
	cmp	ah, Key_F5
	jz	copy
	cmp	ah, Key_F6
	jz	rename
	cmp	ah, Key_F7
	jz	mkdir
	cmp	ah, Key_F8
	jz	delete
	cmp	ah, Key_F9
	jz	go_filter
	cmp	ah, Key_F10
	jnz	ulang
	jmp	short selesai

go_up:	mov	ax, -1
	jmp	short scroll
go_down:mov	ax, 1
	jmp	short scroll
go_home:mov	ax,-16386
	jmp	short scroll
go_end:	mov	ax, 16387
	jmp	short scroll
go_pageup:
	mov	ax, -18
	jmp	short scroll
go_pagedown:
	mov	ax, 18
scroll:
	call	doScroll
	jmp	short refresh

chdir:	call	doChdir
	jmp	short refresh
switch:	mov	ax, active
	mov	bx, offset panel1
	cmp	ax, offset panel1
	jnz	sw2
	mov	bx, offset panel2
sw2:	mov	active, bx
	mov	inactive, ax
	lea	ax, [(PANELINFO ptr bx).dir]
	call	setDir
	jmp	short refresh
chdir2:	call	doChdir2
	jmp	short refresh
view:	call	doView
	jmp	short refresh
append:	call	doAppend
	jmp	short refresh
copy:	call	doCopy
	jmp	short refresh
rename:	call	doRename
	jmp	short refresh
mkdir:	call	doMkdir
	jmp	short refresh
delete:	call	doDelete
	jmp	short refresh
go_filter:
	call	doFilter
	jmp	short refresh
refresh:
	call	drawScreen
	jmp	ulang

selesai:
	mov	ax, 4c00h
	int	21h



;================================;
; Change working direvtory       ;
; Inp:	AX = nama direktori baru ;
; Out:	Carry -> Error           ;
;================================;
setDir proc near
	apush
	mov	si, ax

	mov	dx, [si]	; periksa apakah direktori
	cmp	dh, ':'		; disertai dengan nama drive
	jnz	setdir_next

	sub	dl, 'A'
	mov	ah, 0eh
	int	21h		; ganti drive

setdir_next:
	mov	dx, si
	mov	ah, 3bh
	int	21h		; ganti direktori

	apop
	ret
setDir endp



;================================================;
; Get working directory in active drive          ;
; I/O:	AX = tempat untuk menyimpan working dir  ;
;================================================;
getDir proc near
	apush
	cld
	mov	di, ax
	mov	ah, 19h
	int	21h		; ambil drive aktif
	add	al, 'A'
	stosb
	mov	ax, '\:'	; tambahkan ':\'
	stosw
	mov	si, di
	xor	dx, dx
	mov	ah, 47h
	int	21h		; ambil direktori aktif
	apop
	ret
getDir endp



;===============================================================;
; Mengembalikan daftar file yang ada di derektori & drive aktif ;
; Inp:	AX = array untuk menyimpan daftar file                  ;
;	BX = filter (wild char)                                 ;
; Out:	AX = jumlah file                                        ;
;===============================================================;
getDirList proc near
	push	bp
	mov	bp, sp
	sub	sp, 8
	apush

        ; [bp-2] = counter
        ; [bp-4] = filter
        ; [bp-6] = segment DTA
        ; [bp-8] = offset DTA

	mov	di, ax
	xor	ax, ax
	mov	[bp-2], ax
	mov	[bp-4], bx

	; Ambil Disk Transfer Area (DTA)
	mov	dx, es
	mov	ah, 2fh
	int	21h
	mov	ax, es
	add	bx, 15h
	mov	[bp-8], bx
	mov	[bp-6], ax
	mov	es, dx

	; Find dirs
	mov	ah, 4eh
	mov	cx, 00110111b	; Atribut = ADHRS
	mov	dx, [bp-4]
	int	21h		; find first
	push	ds
	lds	si, [bp-8]
	jc	find_end1
find_next1:
	mov	al, [(FILEENTRY ptr si).fattr]
	and	al, 10h         ; periksa apakah merupakan direktori
	jz	find_skip1
	mov	ax, word ptr [(FILEENTRY ptr si).fname]
	cmp	ax, '.'		; skip bila nama direktori = '.'
	jz	find_skip1
	add	word ptr [bp-2], 1	; increment counter
	mov	cx, (size FILEENTRY) / 2
	repz	movsw			; copy info file ke array
	sub	si, size FILEENTRY
find_skip1:
	mov	ah, 4fh
	int	21h		; find next
	jnc	find_next1
find_end1:
	pop	ds

	; Find files
	mov	ah, 4eh
	mov	cx, 00100111b
	mov	dx, [bp-4]
	int	21h		; find first
	push	ds
	lds	si, [bp-8]
	jc	find_end2
find_next2:
	add	word ptr [bp-2], 1	; increment counter
	mov	cx, (size FILEENTRY) / 2
	repz	movsw			; copy info file ke array
	sub	si, size FILEENTRY
	mov	ah, 4fh		; find next
	int	21h
	jnc	find_next2
find_end2:
	pop	ds

	apop
	mov	ax,[bp-2]	; keluaran di AX = jumlah file yang ada
	mov	sp, bp
	pop	bp
	ret
getDirList endp



;================================================;
; Memformat FILEENTRY untuk ditampilkan di layar ;
; Inp:	AX = file yang akan diformat tampilannya ;
; Out:	filefmt = hasil pemformatan file         ;
;================================================;
formatFile proc near
	apush
	mov	bx, ax

	; copy dari template
	mov	si, offset tempfmt
	mov	di, offset filefmt
	mov	cx, 20
	repz	movsw

	; Isikan pembatas tanggal
	mov	al, '-'
	mov	di, offset filefmt+27
	stosb
	mov	di, offset filefmt+30
	stosb

	; Isikan pembatas jam
	mov	al, ':'
	mov	di, offset filefmt+36
	stosb

	; copy nama file
	lea	si, [(FILEENTRY ptr bx).fname]
	mov	di, offset filefmt+1
file_next:
	lodsb
	test	al, al
	jz	file_done
	stosb
	jmp	file_next
file_done:

	; Bitfields for file time:
	; Bit(s)  Description
	;  15-11  hours (0-23)
	;  10-5   minutes
 	;  4-0    seconds/2

	; Tulis tahun
	mov	ax, [(FILEENTRY ptr bx).fdate]
	mov	cl, 9
	shr	ax, cl
	add	ax, 1980
	mov	di, offset filefmt+26
	IntToStr1
	IntToStr1
	IntToStr1
	IntToStr1

	; Tulis bulan
	mov	ax, [(FILEENTRY ptr bx).fdate]
	mov	cl, 5
	shr	ax, cl
	and	ax, 15
	mov	di, offset filefmt+29
	IntToStr1
	IntToStr1

	; Tulis hari
	mov	ax, [(FILEENTRY ptr bx).fdate]
	and	ax, 1fh
	mov	di, offset filefmt+32
	IntToStr1
	IntToStr1

	; Bitfields for file date:
	; Bit(s)  Description
	;  15-9   year - 1980
	;  8-5    month
	;  4-0    day

	; Tulis jam
	mov	ax, [(FILEENTRY ptr bx).ftime]
	mov	cl, 11
	shr	ax, cl
	mov	di, offset filefmt+35
	IntToStr1
	IntToStr1

	; Tulis menit
	mov	ax, [(FILEENTRY ptr bx).ftime]
	mov	cl, 5
	shr	ax, cl
	and	ax, 63
	mov	di, offset filefmt+38
	IntToStr1
	IntToStr1

	mov	al, [(FILEENTRY ptr bx).fattr]
	test	al,10h		; apakah file merupakan direktori ?
	jz	not_dir

	mov	si, offset dirfmt
	mov	di, offset filefmt+17
	mov	cx, 5
	repz	movsb		; tuliskan '<DIR>' pada kolom besar file
	jmp	short size_done
not_dir:
	; Tulis besar file
	mov	ax, word ptr [(FILEENTRY ptr bx).fsize]
	mov	dx, word ptr [(FILEENTRY ptr bx).fsize+2]
	mov	cx, 10000
	div	cx
	mov	cx, ax
	mov	ax, dx
	mov	di, offset filefmt+21
	test	cx, cx
	jz	size_small
	IntToStr1
	IntToStr1
	IntToStr1
	IntToStr1
	mov	ax, cx

size_small:
	IntToStr1
	test	ax, ax
	jz	size_done
	jmp	size_small

size_done:
	apop
	ret
formatFile endp



;=======================================;
; Inp:	AX : string yang akan ditulis   ;
;	BX : panjang string             ;
;	CH : baris                      ;
;	CL : kolom                      ;
; Note: melakukan akses memori langsung ;
;       sehingga kursor tidak berpindah ;
;=======================================;
writeStr proc near
	apush
	push	es
	mov	si, ax
	mov	ax, 0b800h
	mov	es, ax

	mov	ax, 80
	mul	ch
	xor	ch, ch
	add	ax, cx
	shl	ax, 1
	mov	di, ax

writes_next:
	test	bx, bx
	jz	writes_done
	movsb
	add	di, 1
	sub	bx, 1
	jmp	writes_next

writes_done:
	pop	es
	apop
	ret
writeStr endp



;========================================================;
; Mengganti attribut sekelompok sel, dimulai dari posisi ;
;   tertentu sebanyak N buah sel ke kanan.               ;
; Inp:	AH : 0 -> karakter 1 -> atribut                  ;
;	AL : karakter / atribut                          ;
;	BX : banyak sel yang akan ditulis                ;
;	CH : baris                                       ;
;	CL : kolom                                       ;
;========================================================;
lineAttr	proc near
	apush
	push	es
	mov	dx, ax
	mov	ax, 0b800h
	mov	es, ax

	mov	ax, 80
	mul	ch
	xor	ch, ch
	add	ax, cx
	shl	ax, 1
	add	al, dh
	mov	di, ax
	mov	ax, dx

writea_next:
	test	bx, bx
	jz	writea_done
	stosb
	add	di, 1
	sub	bx, 1
	jmp	writea_next

writea_done:
	pop	es
	apop
	ret
lineAttr endp



;=======================================================;
; Membaca isi direktori dan memasukkannya ke dalam list ;
;=======================================================;
refreshDir proc near
	mov	ax, offset [panel1.dir]
	call	setDir
	mov	ax, offset buffer
	mov	[panel1.files], ax
	mov	bx, offset [panel1.filter]
	call	getDirList
	mov	[panel1.nfiles], ax

	mov	ax, offset [panel2.dir]
	call	setDir
	mov	ax, [panel1.nfiles]
	mov	dx, size FILEENTRY
	mul	dx
	add	ax, offset buffer
	mov	[panel2.files], ax
	mov	bx, offset [panel2.filter]
	call	getDirList
	mov	[panel2.nfiles], ax

	mov	bx, active
	lea	ax, [(PANELINFO ptr bx).dir]
	call	setDir

	xor	ax, ax
	call	doScroll
	ret
refreshDir endp



;=======================================;
; Membaca satu baris dari stdin         ;
; Inp :	ax = pointer buffer hasil input ;
;	bx = besar buffer               ;
;	cx = string$ pesan              ;
;=======================================;
read proc near
	apush
	push	ax		; simpan paramter di stack
	push	bx

	; tampilkan pesan
	GotoXY  0 23
	mov	ah, 9
	mov	dx, cx
	int	21h

	mov	di, offset readbuf
	pop	ax
	push	ax
	mov	[di], ax
	mov	dx, di
	mov	ah, 0ah
	int	21h		; int 21h - 0ah, membaca string

	pop	dx		; dx = besar buffer
	pop	di		; di = pointer buffer hasil input
	lea	si, [readbuf+2]
	xor	cx, cx
	mov	cl, [readbuf+1]	; cx = Min(besar_yang_dibaca, besar_buffer)
	dec	dx
	cmp	cx, dx
	jb	read_next
	mov	cx, dx
read_next:
	repz	movsb
	xor	ax, ax		; akhiri string dengan 0
	stosb

	mov	ax, ' '
	mov	bx, 80
	mov	cx, 1700h
	call	lineAttr

        GotoXY	79 24

	apop
	ret
read endp



;==============================================;
; Membandingkan dua buah string                ;
; Inp : AX, BX = string yang akan dibandingkan ;
; Out : AX = 0       -> string sama            ;
;            negatif -> string1 < string2      ;
;            positif -> string1 > string2      ;
;==============================================;
strcmp proc
	mov	si, ax
	mov	di, bx
	xor	ax, ax
	xor	bx, bx
cmp_next:
	mov	al, [si]
	mov	bl, [di]
	test	al, al
	jz	cmp_done
	test	bl, bl
	jz	cmp_done
	cmp	al, bl
	jnz	cmp_done
	add	si, 1
	add	di, 1
	jmp	cmp_next
cmp_done:
	sub	ax, bx
	ret
strcmp endp



;=================================;
; Mengganti string ke huruf besar ;
; Inp : AX = string masukkkan     ;
;=================================;
upCase	proc near
	apush
	mov	si, ax
upcase_next:
	mov	al, [si]
	test	al, al
	jz	upcase_done
	cmp	al, 'a'
	jb	upcase_skip
	cmp	al, 'z'
	ja	upcase_skip
	sub	al, 'a'-'A'
	mov	[si], al
upcase_skip:
	add	si, 1
	jmp	upcase_next
upcase_done:
	apop
	ret
upCase endp



;===============================================;
; Menggambar panel                              ;
; Inp:	AX: alamat panel yang akan di tampilkan ;
;===============================================;
drawPanel proc near
	mov	si, ax

	; Beri warna title
	mov	ax, 100h+title_attr
	mov	bx, 4
	mov	cx, [(PANELINFO ptr si).col]
	add	cx, 100h+5
	call	lineAttr
	add	cx, 11
	call	lineAttr
	add	cx, 10
	call	lineAttr
	add	cx, 8
	call	lineAttr
	sub	cx, 100h+34

	; Cetak header
	mov	ax, offset head1
	mov	bx, 40
	mov	cx, [(PANELINFO ptr si).col]
	call	writeStr
	mov	ax, offset head2
	add	cx, 100h
	call	writeStr
	mov	ax, offset tempfmt
	add	cx, 100h
	call	writeStr

	; Cetak nama direktori
	xor	ax, ax
	mov	cx, -1
	lea	di, [(PANELINFO ptr si).dir]
	repnz	scasb
	not	cx
	lea	ax, [(PANELINFO ptr si).dir]
	mov	bx, cx
	mov	cx, [(PANELINFO ptr si).col]
	add	cx, 3
	call	writeStr
	mov	ax, 100h+path_attr
	add	bx, 1
	sub	cx, 1
	call	lineAttr

	; Cetak daftar file
	mov	ax, [(PANELINFO ptr si).top]
	mov	dx, size FILEENTRY
	mul	dx
	add	ax, [(PANELINFO ptr si).files]
	mov	di, ax
	mov	bx, 40
	mov	cx, [(PANELINFO ptr si).col]
	add	cx, 300h
	mov	dx, [(PANELINFO ptr si).top]
list_next:
	mov	ax, [(PANELINFO ptr si).nfiles]
	cmp	dx, ax
	jge	list_done
	cmp	cx, 1600h
	jge	list_done
	mov	ax, di
	call	formatFile
	mov	ax, offset filefmt
	call	writeStr

	; Beri warna lain untuk nama direktori
	mov	al, [(FILEENTRY ptr di).fattr]
	test	al, 10h
	jz	list_not_dir
	mov	ax, 100h+dir_attr
	mov	bx, 38
	add	cx, 1
	call	lineAttr
	mov	ax, 100h+def_attr
	mov	bx, 1
	add	cx, 12
	call	lineAttr
	add	cx, 9
	call	lineAttr
	add	cx, 11
	call	lineAttr
	mov	bx, 40
	sub	cx, 33

list_not_dir:
	cmp	si, active
	jnz	list_not_active
	cmp	dx, [(PANELINFO ptr si).sel]
	jnz	list_not_active

        ; Beri warna lain untuk file yang dipilih
	mov	ax, 100h+sel_attr
	mov	bx, 38
	add	cx, 1
	call	lineAttr
	mov	bx, 40
	sub	cx, 1
list_not_active:
	add	cx, 100h
	add	di, size FILEENTRY
	add	dx, 1
	jmp	list_next
list_done:

	; Cetak ruang kosong yang tersisa
	mov	ax, offset tempfmt
list_pad_next:
	cmp	cx, 1600h
	jge	list_pad_done
	call	writeStr
	add	cx, 100h
	jmp	list_pad_next
list_pad_done:

	; Cetak footer
	mov	ax, offset foot1
	call	writeStr

	ret
drawPanel endp



;==============================;
; Menggambar keseluruhan layar ;
;==============================;
drawScreen proc near
	; Set default attribute
	mov	ax, 100h+def_attr
	mov	bx, 23*80
	xor	cx, cx
	call	lineAttr

	mov	ax, offset panel1
	call	drawPanel
	mov	ax, offset panel2
	call	drawPanel

	mov	ax, offset foot2
	mov	bx, 80
	mov	cx, 1800h
	call	writeStr

	mov	ax, 107h
	call	lineAttr
	mov	ax, 100h+sel_attr
	mov	bx, 5
	add	cx, 9
	call	lineAttr
	mov	bx, 4
	add	cx, 8
	call	lineAttr
	mov	bx, 6
	add	cx, 8
	call	lineAttr
	mov	bx, 4
	add	cx, 8
	call	lineAttr
	mov	bx, 6
	add	cx, 8
	call	lineAttr
	mov	bx, 5
	add	cx, 8
	call	lineAttr
	mov	bx, 6
	add	cx, 8
	call	lineAttr
	mov	bx, 6
	add	cx, 8
	call	lineAttr
	mov	bx, 4
	add	cx, 9
	call	lineAttr

	ret
drawScreen endp



;============================================;
; Menggulung layar panel aktif sebesar delta ;
; Inp : AX = delta                           ;
;============================================;
doScroll proc near
	mov	bx, active
	mov	cx, [(PANELINFO ptr bx).sel]
	add	cx, ax

	cmp	cx, [(PANELINFO ptr bx).nfiles]
	jl	scroll_next1
	mov	cx, [(PANELINFO ptr bx).nfiles]
	sub	cx, 1
scroll_next1:
	cmp	cx, 0
	jnl	scroll_next2
	xor	cx, cx
scroll_next2:
	mov	[(PANELINFO ptr bx).sel], cx
	mov	ax, [(PANELINFO ptr bx).top]
	cmp	ax, cx
	jle	scroll_no_up
	mov	[(PANELINFO ptr bx).top], cx
	jmp	short scroll_skip
scroll_no_up:
	sub	cx, ax
	sub	cx, 18
	jle	scroll_skip
	add	ax, cx
	mov	[(PANELINFO ptr bx).top], ax
scroll_skip:
	ret
doScroll endp



;====================================================================;
; Mengganti direktori pada panel aktif dengan direktori yang dipilih ;
;====================================================================;
doChdir	proc near
	mov	bx, active
	mov	ax, [(PANELINFO ptr bx).sel]
	mov	dx, size FILEENTRY
	mul	dx
	add	ax, [(PANELINFO ptr bx).files]
	add	ax, FILEENTRY.fname
	call	setDir
	jc	chdir_error
	lea	ax, [(PANELINFO ptr bx).dir]
	call	getDir
	xor	ax, ax
	mov	[(PANELINFO ptr bx).top], ax
	mov	[(PANELINFO ptr bx).sel], ax
	call	refreshDir
chdir_error:
	ret
doChdir endp



;======================================;
; Mengganti direktori panel yang aktif ;
;======================================;
doChdir2 proc near
	mov	si, active
	lea	ax, [(PANELINFO ptr si).dir]
	mov	bx, max_path
	mov	cx, offset chdirmsg
	call	read
	call	upCase
	call	setDir
	jc	chdir2_error
	xor	ax, ax
	mov	[(PANELINFO ptr si).top], ax
	mov	[(PANELINFO ptr si).sel], ax
chdir2_error:
	lea	ax, [(PANELINFO ptr si).dir]
	call	getDir
	call	refreshDir
	ret
doChdir2 endp



;================================================;
; Mengkonkat file yang dipilih dengan suatu file ;
;================================================;
doAppend proc near
	xor	ax, ax
	not	ax
	mov	handle1, ax
	mov	handle2, ax

	mov	ax, offset input
	mov	bx, max_path
	mov	cx, offset appendmsg
	call	read

	; Buka file pertama dengan mode readonly
	mov	ax, 3d10h
	mov	dx, offset input
	int	21h
	jc	append_done
	mov	handle1, ax

	; Buka file kedua dengan mode writeonly
	mov	bx, active
	mov	ax, [(PANELINFO ptr bx).sel]
	mov	dx, size FILEENTRY
	mul	dx
	add	ax, [(PANELINFO ptr bx).files]
	add	ax, FILEENTRY.fname
	mov	dx, ax
	mov	ax, 3d11h
	int	21h
	jc	append_done
	mov	handle2, ax

	; Seek to end of file
	mov	bx, ax
	mov	ax, 4202h
	xor	cx, cx
	xor	dx, dx
	int	21h

append_next:
	mov	ah, 3fh
	mov	bx, handle1
	mov	cx, buffer_size
	lea	dx, buffer
	int	21h
	jc	append_done
	cmp	ax, 0
	je	append_done
	mov	cx, ax
	mov	ah, 40h
	mov	bx, handle2
	lea	dx, buffer
	int	21h
	jc	append_done
	cmp	cx, ax
	je	append_next
append_done:
	; fclose(handle1)
	mov	ah, 3eh
	mov	bx, handle1
	int	21h

	; fclose(handle2)
	mov	ah, 3eh
	mov	bx, handle2
	int	21h

	call	refreshDir
	ret
doAppend endp



;===================================================;
; Mengkopi file yang dipilih dari ke direktori lain ;
;===================================================;
doCopy proc near
	mov	ax, offset [panel1.dir]
	mov	bx, offset [panel2.dir]
	call	strcmp
	test	ax, ax
	jnz	copy_ok
	ret

copy_ok:
	push	bp
	mov	bp, sp
	sub	sp, 5
	xor	ax, ax
	not	ax
	mov	handle1, ax
	mov	handle2, ax

	mov	bx, active
	mov	ax, [(PANELINFO ptr bx).sel]
	mov	dx, size FILEENTRY
	mul	dx
	add	ax, [(PANELINFO ptr bx).files]
	mov	bx, ax
	mov	al, [(FILEENTRY ptr bx).fattr]
	mov	cx, [(FILEENTRY ptr bx).ftime]
	mov	dx, [(FILEENTRY ptr bx).fdate]
	mov	[bp-5], al
	mov	[bp-4], cx
	mov	[bp-2], dx

	mov	ax, 3d10h
	lea	dx, [(FILEENTRY ptr bx).fname]
	int	21h
	jc	copy_done
	mov	handle1, ax

	mov	bx, inactive
	lea	ax, [(PANELINFO ptr bx).dir]
	call	setDir
	mov	ah, 3ch
	xor	cx, cx
	mov	cl, [bp-5]
	int	21h
	jc	copy_done
	mov	handle2, ax

copy_next:
	mov	ah, 3fh
	mov	bx, handle1
	mov	cx, buffer_size
	lea	dx, buffer
	int	21h
	jc	copy_done
	cmp	ax, 0
	je	copy_done
	mov	cx, ax
	mov	ah, 40h
	mov	bx, handle2
	lea	dx, buffer
	int	21h
	jc	copy_done
	cmp	cx, ax
	je	copy_next
copy_done:
        ; fclose(handle1)
	mov	ah, 3eh
	mov	bx, handle1
	int	21h

	; Set file last change
	mov	ax, 5701h
	mov	bx, handle2
	mov	cx, [bp-4]
	mov	dx, [bp-2]
	int	21h

        ; fclose(handle2)
	mov	ah, 3eh
	mov	bx, handle2
	int	21h

	call	refreshDir
	mov	sp, bp
	pop	bp
	ret
doCopy endp



;============================;
; Merename file yang dipilih ;
;============================;
doRename proc near
	mov	ax, offset input
	mov	bx, max_file
	mov	cx, offset renamemsg
	call	read

	mov	bx, active
	mov	ax, [(PANELINFO ptr bx).sel]
	mov	dx, size FILEENTRY
	mul	dx
	add	ax, [(PANELINFO ptr bx).files]
	add	ax, FILEENTRY.fname
	mov	dx, ax
	mov	di, offset input
	mov	ah, 56h
	int	21h
	call	refreshDir
	ret
doRename endp



;=================================================;
; Membuat direktori baru di dalam direktori aktif ;
;=================================================;
doMkdir proc near
	mov	ax, offset input
	mov	bx, max_file
	mov	cx, offset mkdirmsg
	call	read

	mov	ah, 39h
	mov	dx, offset input
	int	21h
	call	refreshDir
	ret
doMkdir endp



;=======================================;
; Menghapus file/direktori yang dipilih ;
;=======================================;
doDelete proc near
	mov	ax, offset input
	mov	bx, 2
	mov	cx, offset deletemsg
	call	read
	mov	al, [input]
	or	al, 20h
	cmp	al, 'y'
	jnz	delete_done

	mov	bx, active
	mov	ax, [(PANELINFO ptr bx).sel]
	mov	dx, size FILEENTRY
	mul	dx
	add	ax, [(PANELINFO ptr bx).files]
	mov	bx, ax
	lea	dx, [(FILEENTRY ptr bx).fname]
	mov	ah, 3ah
	test	byte ptr [(FILEENTRY ptr bx).fattr], 10h
	jnz	del_dir
	mov	ah, 41h
del_dir:
	int	21h
	call	refreshDir

delete_done:
	ret
doDelete endp



;==============================;
; Mengganti filter panel aktif ;
;==============================;
doFilter proc near
	mov	si, active
	lea	ax, [(PANELINFO ptr si).filter]
	mov	bx, max_file
	mov	cx, offset filtermsg
	call	read
	xor	ax, ax
	mov	[(PANELINFO ptr si).top], ax
	mov	[(PANELINFO ptr si).sel], ax
	call	refreshDir
	ret
doFilter endp



;===================================;
; Menampilkan isi file yang dipilih ;
;===================================;
doView proc near
	xor	ax, ax
	mov	topline, ax
	not	ax
	mov	handle1, ax

	mov	bx, active
	mov	ax, [(PANELINFO ptr bx).sel]
	mov	dx, size FILEENTRY
	mul	dx
	add	ax, [(PANELINFO ptr bx).files]
	add	ax, FILEENTRY.fname
	mov	dx, ax
	mov	ax, 3d00h
	int	21h
	jnc	view_ok
	jmp	view_done

view_ok:
	mov	handle1, ax

	; Ganti warna latar
	mov	ax, 100h+view_attr
	mov	bx, 24*80
	xor	cx, cx
	call	lineAttr
	mov	ax, 107h
	mov	bx, 80
	mov	cx, 1800h
	call	lineAttr
	mov	ax, ' '
	call	lineAttr

	call	scanFile
        call	drawView

view_loop:
	xor	ax, ax
	int	16h
	cmp	ah, Key_Up
	jz	view_up
	cmp	ah, Key_Down
	jz	view_down
	cmp	ah, Key_PageUp
	jz	view_pageup
	cmp	ah, Key_PageDown
	jz	view_pagedown
	cmp	ah, Key_Home
	jz	view_home
	cmp	ah, Key_End
	jz	view_end
	cmp	ah, Key_Escape
	jnz	view_loop
	Cls
	jmp	short view_done
view_up:
	mov	ax, -1
	jmp	short view_scroll
view_down:
	mov	ax, 1
	jmp	short view_scroll
view_pageup:
	mov	ax, -23
	jmp	short view_scroll
view_pagedown:
	mov	ax, 23
	jmp	short view_scroll
view_home:
	mov	ax, -16768
	jmp	short view_scroll
view_end:
	mov	ax, 16767
	jmp	short view_scroll
view_scroll:
	call	scrollView
	call	drawView
	jmp	view_loop

view_done:
        ; fclose(handle1)
	mov	ah, 3eh
	mov	bx, handle1
	int	21h

	call	refreshDir
	ret
doView endp



;==========================================;
; Menggulung layar sebanyak delta tertentu ;
; Inp: AX = delta                          ;
;==========================================;
scrollView proc near
	mov	cx, topline
	add	cx, ax

	mov	dx, nlines
	cmp	cx, dx
	jl	scrollv_next1
	mov	cx, dx
	sub	cx, 1
scrollv_next1:
	cmp	cx, 0
	jnl	scrollv_next2
	xor	cx, cx
scrollv_next2:
	mov	topline, cx
	ret
scrollView endp



;=================================================;
; Membaca file untuk menentukan posisi awal baris ;
; Inp: handle1 : handle file yang akan discan     ;
; Out: nlines : jumlah baris                      ;
;      buffer : array of offset awal baris        ;
;=================================================;
scanFile proc
	push	bp
	mov	bp, sp
	sub	sp, 4
	apush

	xor	ax, ax
	mov	[bp-4], ax
	mov	[bp-2], ax
	mov	di, offset buffer
	stosw
	stosw
	mov	ax, 1
	mov	[nlines], ax

scan_next:
	mov	ah, 3fh
	mov	bx, handle1
	mov	cx, 256
	mov	dx, offset readbuf
	int	21h
	jc	scan_end
	test	ax, ax
	jz	scan_end

        mov	cx, ax
        mov	si, offset readbuf
scan_next2:
	add	word ptr [bp-4], 1
	adc	word ptr [bp-2], 0
	lodsb
	cmp	al, 10
	jnz	scan_skip
	add	[nlines], 1
	mov	ax, [bp-4]
	stosw
	mov	ax, [bp-2]
	stosw
scan_skip:
	loop	scan_next2
        jmp	scan_next

scan_end:
	apop
	mov	sp, bp
	pop	bp
	ret
scanFile endp



;==================================;
; Membaca satu baris               ;
; Inp: CX:DX = offset              ;
; Out: filefmt = baris yang dibaca ;
;==================================;
getLine proc
	apush
	mov	ax, 4200h
	mov	bx, handle1
	int	21h		; Pindahkan pointer file ke CX:DX

	mov	ah, 3fh
	mov	bx, handle1
	mov	cx, 80
	mov	dx, offset filefmt
	int	21h		; Baca file sebanyak 80 byte (lebar laytar)

	mov	di, offset filefmt
	add	di, ax
	mov	al, 13
	stosb			; Tambahkan karakter enter di akhir string

	mov	cx, 80
	mov	si, offset filefmt
line_next:
	mov	al, [si]
	cmp	al, 13   	; Periksa apakah sudah ganti baris
	jz	line_done
	cmp	al, 10
	jz	line_done
	cmp	al, 255
	jz	line_beep
	cmp	al, 7
	jz	line_beep	; periksa apakah karakter yang berbunyi
	cmp	al, 8		; jika ya overwrite dengan spasi
	jnz	line_not_beep
line_beep:
	mov	al, ' '		; kita overwrite disini
	mov	[si], al
line_not_beep:
	add	si, 1
	loop	line_next
line_done:

	mov	di, si		; isi sisa baris dengan spasi
	mov	al, ' '
	repz	stosb

	apop
	ret
getLine endp



;==============================================;
; Menulis isi file ke layar mulai dari topline ;
;==============================================;
drawView proc
	cld

	mov	ax, topline
	mov	dx, ax
	shl	ax, 1
	shl	ax, 1
	add	ax, offset buffer
	mov	si, ax
	mov	bx, 80
	xor	cx, cx
dview_next:
	cmp	cx, 1800h
	jge	dview_done
	cmp	dx, nlines
	jge	dview_done
	push	dx
	push	cx
	lodsw			; Ambil offset baris sekarang
	mov	dx, ax
	lodsw
	mov	cx, ax
	call	getLine		; Baca baris dari file
	pop	cx

	; Goto start of line
	mov	ah, 02
	xor	bx, bx
	mov	dx, cx
	int	10h

	push	si
	mov	si, offset filefmt
dview_line:
	lodsb
	mov	dx, ax
	mov	ah, 2
	int	21h		; tulis satu karakter

	push	cx
	mov	ah, 3
	xor	bx, bx
	int	10h		; ambil posisi kursor
	pop	cx
	and	dx, 0ff00h
	cmp	cx, dx		; periksa apakah kursor sudah ganti baris
	je	dview_line

	pop	si
	pop	dx
	add	cx, 100h
	add	dx, 1
	jmp	dview_next
dview_done:

        ; Tulis sisa baris yang masih kosong dengan '.'
        mov	ax, 176
        mov	bx, 80
dview_next2:
	cmp	cx, 1800h
	jge	dview_done2
	call	lineAttr
	add	cx, 100h
	jmp	dview_next2
dview_done2:

	; Kembalikan posisi kursor ke kanan bawah
	GotoXY	79 24
	ret
drawView endp

end	start
