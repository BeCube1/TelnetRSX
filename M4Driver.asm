M4_C_NETSOCKET	equ	$4331
M4_C_NETCONNECT	equ	$4332
M4_C_NETCLOSE	equ	$4333
M4_C_NETSEND	equ	$4334
M4_C_NETRECV	equ	$4335
M4_C_NETHOSTIP	equ	$4336

M4_CMD_SOCKET	ld	hl,ROM_cmdsocket
		call	M4_sendcmd

		call    GetM4ROMNumber			; OUT: C=ROM number

		;; O: HL=Address

		call    FF02_IY__Get_M4_Buffer_Response_Address

		inc	hl
		inc	hl
		inc	hl

		call	Read8BitFromROM			; IN: C=ROM number, HL=Address; OUT: A=Value
		cp	255

		ret

FF02_IY__Get_M4_Buffer_Response_Address
		push	af
		push	bc

		ld	hl,$ff02
		call	Read16BitFromROM		; IN: C=ROM number, HL=Address; OUT: HL=Value

		pop	bc
		pop	af

		ret

;;;
;;; OUT:  HL=Socket response address
;;;

FF06_IX__Get_M4_Socket_Response_Address
		push	af
		push	bc

		ld	hl,$ff06
		call	Read16BitFromROM		; IN: C=ROM number, HL=Address; OUT: HL=Value

		pop	bc
		pop	af

		ret

Clear_Z_Flag	ret

ROM_cmdsocket	defb	5
		defw	M4_C_NETSOCKET
		defb	$0,$0,$6

;;;
;;; IN: A=Socket, DE=Pointer to IP, ZF=Error
;;;

M4_CMD_CONNECT	ex	de,hl

		call	send_cmd_connect		; IN: A=Socket, HL=Pointer to IP

		call    GetM4ROMNumber			; OUT: C=ROM number

		;; OUT: HL=Address

		call    FF02_IY__Get_M4_Buffer_Response_Address

		inc	hl
		inc	hl
		inc	hl

		call	Read8BitFromROM			; IN: C=ROM number, HL=Address; OUT: A=Value
		cp	255

		ret

;;;
;;; IN: A=Socket; OUT: A=State (0=Idle, 1=Connect in progress, 2=Send in progress)
;;;

M4_GET_SOCKET_STATE
		push	ix
		push	hl

		call    GetM4ROMNumber			; OUT: C=ROM number
		call	GetSocketPtr			; IN: A=Socket, C=ROM number; OUT: ix=Socket prt.

		push	ix

		inc	ix
		inc	ix

		push	ix
		pop	hl

		call	Read16BitFromROM		; IN: C=ROM number, HL=Address; OUT: HL=Value

		ex	de,hl
		pop	hl
		call	Read8BitFromROM			; IN: C=ROM number, HL=Address; OUT: A=Value

		pop	hl
		pop	ix

		ret

;;;
;;; IN: A=Socket, C=ROM number; OUT: ix=Socket ptr.
;;;

GetSocketPtr	push	hl
		push	de

		sla	a
		sla	a
		sla	a
		sla	a

		;; IN: C=ROM number; OUT: HL=Socket response address

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

;;;
;;; OUT: C=ROM number
;;;

GetM4ROMNumber	push	de
		push	hl
		push	af

		ld	hl,puffermem4rsx
		ld	(hl),'S'
		inc	hl
		ld	(hl),'D'+$80
		dec	hl
		call	KL_FIND_COMMAND			; OUT: HL=Address, C=ROM number

		pop	af
		pop	hl
		pop	de

		ret

;;;
;;; IN: C=ROM number, HL=Address; OUT: HL=Value
;;;

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

		ld	(ix+00),$7e			; ld a,(hl)
		ld	(ix+01),$23			; inc hl
		ld	(ix+02),$66			; ld h,(hl)
		ld	(ix+03),$6f			; ld l,a
		ld	(ix+04),$c9			; ret
		push	ix
		jp	$b90f

;;;
;;; IN: C=ROM number, HL=Address; OUT: HL/DE=Value
;;;

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

		ld	(ix+00),$5e			; ld e,(hl)
		ld	(ix+01),$23			; inc hl
		ld	(ix+02),$56			; ld d,(hl)
		ld	(ix+03),$23			; inc hl
		ld	(ix+04),$7e			; ld a,(hl)
		ld	(ix+05),$23			; inc hl
		ld	(ix+06),$66			; ld h,(hl)
		ld	(ix+07),$6f			; ld l,a
		ld	(ix+08),$c9			; ret
		push	ix
		jp	$b90f

;;;
;;; IN: C=ROM number, HL=Address; OUT: A=Value
;;;

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

		ld	(ix+0),$7e			; ld a,(hl)
		ld	(ix+1),$c9			; ret
		push	ix
		jp	$b90f

;;;
;;; IN: H =Packet to send
;;;

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

;;;
;;; IN: A=Socket, HL=Pointer to IP
;;;

send_cmd_connect
		push	af
		ld	bc,$fe00

		ld	a,$9
		out	(c),a

		ld	a,M4_C_NETCONNECT&$ff
		out	(c),a

		ld	a,M4_C_NETCONNECT>>8
		out	(c),a

		pop	af				; Socket
		out	(c),a

		inc	b				; IP
		outi
		inc	b
		outi
		inc	b
		outi
		inc	b
		outi
		inc	b

		ld	bc,$fe00

		ld	a,23				; Port 23
		out	(c),a

		ld	a,0
		out	(c),a

		ld	bc,$fc00
		out	(c),c
		ret

;;;
;;; IN: DE=Hostname, BC=size(Hostname), IX=IP address; OUT: A=0 => Ok
;;;

M4_CMD_NET_LOOKUP_IP
		push	de

		push	ix
		pop	hl

		call	M4_CMD_NET_LOOKUP_IP_send	; IN: HL=Hostname address

		call	GetM4ROMNumber			; OUT: C=ROM number

		;; OUT: HL=Address

		call	FF02_IY__Get_M4_Buffer_Response_Address

		inc	hl
		inc	hl
		inc	hl
		call	Read8BitFromROM			; IN: C=ROM number, HL=Address; OUT: A=Value
		cp	1
		jr	z,M4_CMD_NET_LOOKUP_IP_wait

		pop	de
		ld	a,1
		ret
M4_CMD_NET_LOOKUP_IP_wait

		;; OUT: HL=Socket response adress

		call 	FF06_IX__Get_M4_Socket_Response_Address
M4_CMD_NET_LOOKUP_IP_wait_lookup
		call	Read8BitFromROM			; IN: C=ROM number, HL=Address; OUT: A=Value
		cp	5				; IP lookup in progress.
		jr	z,M4_CMD_NET_LOOKUP_IP_wait_lookup
		push	af

		inc	hl
		inc	hl
		inc	hl
		inc	hl

		call	Read32BitFromROM		; IN: C=ROM number, HL=Address; OUT: HL/DE=Value, IX=destroyed
		pop	af
		pop	ix

		ld	(ix+0),e
		ld	(ix+1),d
		ld	(ix+2),l
		ld	(ix+3),h
		ret

;;;
;;; IN: HL=Hostname address
;;;

M4_CMD_NET_LOOKUP_IP_send
		ld	bc,$fe00

		ld	a,16				; String length
		out	(c),a

		ld	a,M4_C_NETHOSTIP&$ff
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

;;;
;;; IN: A=Socket, DE=Size, IX=Pointer to Data; OUT: A=Buffer state, BC=Recv bytes count
;;;

M4_CMD_NET_RECEIVE_DATA
		push	de
		push	af
		ld	bc,$fe00
		ld	a,5
		out	(c),a

		ld	a,M4_C_NETRECV&$ff
		out	(c),a
		ld	a,M4_C_NETRECV>>8
		out	(c),a

		pop	af				; Socket
		out	(c),a

		pop	de				; Size
		out	(c),e
		out	(c),d

		ld	bc,$fc00
		out	(c),c

		call    GetM4ROMNumber			; OUT: C=ROM number

		;; IN: C=ROM number; OUT: HL=Address

		call	FF02_IY__Get_M4_Buffer_Response_Address

		inc	hl
		inc	hl
		inc	hl
		inc	hl
		push	hl

		call	Read16BitFromROM		; IN: C=ROM number, HL=Address; OUT: HL=Value
		push	hl
		pop	de

		pop	hl

		inc	hl
		inc	hl
		push	de

M4_CMD_NET_RECEIVE_DATA___TRANSFER_DATA_LOOP
		call	Read8BitFromROM			; IN: C=ROM number, HL=Address; OUT: A=Value

		ld	(ix),a
		inc	ix
		inc	hl
		dec	de
		ld	a,d
		or	e
		jr	nz,M4_CMD_NET_RECEIVE_DATA___TRANSFER_DATA_LOOP

		;; IN: C=ROM number; OUT: HL=Address

		call	FF02_IY__Get_M4_Buffer_Response_Address

		inc	hl
		inc	hl
		inc	hl

		call	Read8BitFromROM			; IN: C=ROM number, HL=Address; OUT: A=Value

		pop	bc

		ret

M4_CMD_NET_SEND_CUSTOM_DATA
		ld	bc,$fe00
		ld	a,(ix+0)

		push	af
		inc	a
		inc	a
		out	(c),a

		ld	a,M4_C_NETSEND&$ff
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

;;;
;;; IN A=Socket
;;;

M4_CMD_CLOSE_CONNECTION
		ld	bc,$fe00
		ld	e,3

		out	(c),e

		ld	e,M4_C_NETCLOSE&$ff
		out	(c),e
		ld	e,M4_C_NETCLOSE>>8
		out	(c),e

		out	(c),a				; Socket

		ld	bc,$fc00
		out	(c),c

		ret
