M4_C_NETSOCKET	equ	$4331
M4_C_NETCONNECT	equ	$4332
M4_C_NETCLOSE	equ	$4333
M4_C_NETSEND	equ	$4334
M4_C_NETRECV	equ	$4335
M4_C_NETHOSTIP	equ	$4336

M4_CMD_SOCKET	ld	hl,ROM_cmdsocket
		call	M4_sendcmd

		call    GetM4ROMNumber

		call    FF02_IY__Get_M4_Buffer_Response_Address

		inc	hl
		inc	hl
		inc	hl
		call	Read8BitFromROM
		cp	255

		ret

FF02_IY__Get_M4_Buffer_Response_Address
		push	af
		ld	hl,$ff02
		push	bc
		call	Read16BitFromROM
		pop	bc
		pop	af
		ret

FF06_IX__Get_M4_Socket_Response_Address
		push	af
		ld	hl,$ff06
		push	bc
		call	Read16BitFromROM
		pop	bc
		pop	af
		ret

Clear_Z_Flag	ret

ROM_cmdsocket	defb	5
		defw	M4_C_NETSOCKET
		defb	$0,$0,$6


M4_CMD_CONNECT	ex	de,hl

		call	send_cmd_connect

		call    GetM4ROMNumber

		call    FF02_IY__Get_M4_Buffer_Response_Address

		inc	hl
		inc	hl
		inc	hl
		call	Read8BitFromROM
		cp	255
		ret

M4_GET_SOCKET_STATE
		push	ix
		push	hl
		call    GetM4ROMNumber
		call	GetSocketPtr

		push	ix
		inc	ix
		inc	ix
		push	ix
		pop	hl
		call	Read16BitFromROM

		ex	de,hl
		pop	hl
		call	Read8BitFromROM

		pop	hl
		pop	ix

		ret

GetSocketPtr	push	hl
		push	de

		sla	a
		sla	a
		sla	a
		sla	a

		call 	FF06_IX__Get_M4_Socket_Response_Address

		ld	e,a
		ld	d,0
		add	hl,de
		push	hl
		pop	ix
		pop	de
		pop	hl

		ret

puffermem4rsx	equ	$bf00

GetM4ROMNumber	push	de
		push	hl

		push	af

		ld	hl,puffermem4rsx
		ld	(hl),'S'
		inc	hl
		ld	(hl),'D'+$80
		dec	hl
		call	KL_FIND_COMMAND
		pop	af
		pop	hl
		pop	de
		ret

Read16BitFromROM
		push	ix
		push	de
		push	bc
		call	Read16BitFromROM_Main
		pop	bc
		pop	de
		pop	ix
		ret
Read16BitFromROM_Main
		ld	ix,$b918
		push	ix
		ld	ix,puffermem4rsx

		ld	(ix+00),$7e
		ld	(ix+01),$23
		ld	(ix+02),$66
		ld	(ix+03),$6f
		ld	(ix+04),$c9
		push	ix
		jp	$b90f

Read32BitFromROM
		push	ix
		push	bc
		call	Read32BitFromROM_Main
		pop	bc
		pop	ix
		ret
Read32BitFromROM_Main
		ld	ix,$b918
		push	ix
		ld	ix,puffermem4rsx

		ld	(ix+00),$5e
		ld	(ix+01),$23
		ld	(ix+02),$56
		ld	(ix+03),$23
		ld	(ix+04),$7e
		ld	(ix+05),$23
		ld	(ix+06),$66
		ld	(ix+07),$6f
		ld	(ix+08),$c9
		push	ix
		jp	$b90f

Read8BitFromROM	push	ix
		push	de
		push	bc
		call	Read8BitFromROM_Main

		pop	bc
		pop	de
		pop	ix
		ret

Read8BitFromROM_Main
		ld	ix,$b918
		push	ix
		ld	ix,puffermem4rsx
		ld	(ix+0),$7e
		ld	(ix+1),$c9
		push	ix
		jp	$b90f

M4_sendcmd	ld	bc,$fe00
		ld	d,(hl)
		inc	d
M4_sendcmd_sendloop
		inc	b
		outi
		dec	d
		jr	nz,M4_sendcmd_sendloop
		ld	bc,$fc00
		out	(c),c
		ret

send_cmd_connect
		push	af
		ld	bc,$fe00
		ld	a,$9
		out	(c),a

		ld	a,M4_C_NETCONNECT

		out	(c),a
		ld	a,M4_C_NETCONNECT>>8
		out	(c),a

		pop	af
		out	(c),a

		inc	b
		outi
		inc	b
		outi
		inc	b
		outi
		inc	b
		outi
		inc	b

		ld	bc,$fe00

		ld	a,23
		out	(c),a
		ld	a,0
		out	(c),a

		ld	bc,$fc00
		out	(c),c
		ret

M4_CMD_NET_LOOKUP_IP
		push	de

		push	ix
		pop	hl

		call	M4_CMD_NET_LOOKUP_IP_send

		call	GetM4ROMNumber

		call	FF02_IY__Get_M4_Buffer_Response_Address

		inc	hl
		inc	hl
		inc	hl
		call	Read8BitFromROM
		cp	1
		jr	z,M4_CMD_NET_LOOKUP_IP_wait
		pop	de
		ld	a,1
		ret

M4_CMD_NET_LOOKUP_IP_wait
		call 	FF06_IX__Get_M4_Socket_Response_Address


M4_CMD_NET_LOOKUP_IP_wait_lookup
		call	Read8BitFromROM
		cp	5
		jr	z,M4_CMD_NET_LOOKUP_IP_wait_lookup
		push	af

		inc	hl
		inc	hl
		inc	hl
		inc	hl

		call	Read32BitFromROM
		pop	af
		pop	ix

		ld	(ix+0),e
		ld	(ix+1),d
		ld	(ix+2),l
		ld	(ix+3),h
		ret

M4_CMD_NET_LOOKUP_IP_send
		ld	bc,$fe00
		ld	a,16
		out	(c),a

		ld	a,M4_C_NETHOSTIP
		out	(c),a
		ld	a,M4_C_NETHOSTIP>>8
		out	(c),a

		ld	d,14
M4_CMD_NET_LOOKUP_IP_sendloop_NEU
		ld	a,(hl)
		inc	hl
		out	(c),a

		dec	d
		jr	nz,M4_CMD_NET_LOOKUP_IP_sendloop_NEU

		ld	bc,$fc00
		out	(c),c
		ret

		ld	d,16
		inc	d
M4_CMD_NET_LOOKUP_IP_sendloop
		inc	b
		outi
		dec	d
		jr	nz,M4_CMD_NET_LOOKUP_IP_sendloop
		ld	bc,$fc00
		out	(c),c
		ret

M4_CMD_NET_RECEIVE_DATA
		push	de
		push	af
		ld	bc,$fe00
		ld	a,5
		out	(c),a

		ld	a,M4_C_NETRECV
		out	(c),a
		ld	a,M4_C_NETRECV>>8
		out	(c),a
		pop	af
		out	(c),a

		pop	de
		out	(c),e
		out	(c),d

		ld	bc,$fc00
		out	(c),c

		call    GetM4ROMNumber

		call	FF02_IY__Get_M4_Buffer_Response_Address
		inc	hl
		inc	hl
		inc	hl
		inc	hl

		push	hl

		call	Read16BitFromROM
		push	hl
		pop	de

		pop	hl

		inc	hl
		inc	hl
		push	de

M4_CMD_NET_RECEIVE_DATA___TRANSFER_DATA_LOOP
		call	Read8BitFromROM

		ld	(ix),a
		inc	ix
		inc	hl
		dec	de
		ld	a,d
		or	e
		jr	nz,M4_CMD_NET_RECEIVE_DATA___TRANSFER_DATA_LOOP

		call	FF02_IY__Get_M4_Buffer_Response_Address
		inc	hl
		inc	hl
		inc	hl

		call	Read8BitFromROM

		pop	bc

		ret

M4_CMD_NET_SEND_CUSTOM_DATA
		ld	bc,$fe00
		ld	a,(ix+0)

		push	af
		inc	a
		inc	a
		out	(c),a

		ld	a,M4_C_NETSEND
		out	(c),a
		ld	a,M4_C_NETSEND>>8
		out	(c),a

		inc	ix

		pop	de
M4_CMD_NET_SEND_CUSTOM_DATA_LOOP
		ld	a,(ix)
		inc	ix
		out	(c),a

		dec	d

		jr	nz,M4_CMD_NET_SEND_CUSTOM_DATA_LOOP

		ld	bc,$fc00
		out	(c),c
		ret
M4_CMD_CLOSE_CONNECTION
		ld	bc,$fe00
		ld	e,3

		out	(c),e

		ld	e,M4_C_NETCLOSE
		out	(c),e
		ld	e,M4_C_NETCLOSE>>8
		out	(c),e

		out	(c),a

		ld	bc,$fc00
		out	(c),c

		ret
