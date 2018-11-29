;			call    GetM4ROMNumber	; OUT  C=M4ROM-Number
;
; IX-Register
; call 	FF06_IX__Get_M4_Socket_Response_Address	; IN: C=ROM-Number OUT:  HL=Socket response adress    (ld		hl,(0xFF06)	; get Socket response address)
;
; IY-Register
; call  FF02_IY__Get_M4_Buffer_Response_Address; IN: C=ROM-Number OUT HL=Adresse			ld		hl,(0xFF02)	; get response buffer address
			
			
			
; http://www.spinpoint.org/cpc/m4info.txt

; m4 commands used
M4_C_NETSOCKET		equ 0x4331		; data[0] = domain, data[1] = type, data[2] = protocol. Return data[0] = socket number or 0xFF (error). 							Only TCP protocol for now.
M4_C_NETCONNECT		equ 0x4332		; data[0] = socket, data[1..4] = ip, data[5-6] = port. Return data[0] = 0 (OK) or ERROR 0xFF.
M4_C_NETCLOSE		equ 0x4333
M4_C_NETSEND		equ 0x4334
M4_C_NETRECV		equ 0x4335		;data[0] = socket, data[1..2] = receive size (don't flood buffer, max. 0x800).
									; Return data[0] = 0. data[1..2] = actual received size. data[3...] = received data. Look at sockinfo for status.

M4_C_NETHOSTIP		equ 0x4336	; data[0..] = hostname string\0. Return data[0] = 1 Lookup in progress. Any other = error. Look in M4rom sockinfo for IP and status
;Responses are read from rom by mapping M4 rom.
;At offset 0xFF00, there is a link table for things that may move as firmware gets updates:
;0xFF00		.dw	#0x109			; rom version
;0xFF02		.dw	rom_response		; 0x800+some byte buffer for responses from commands
;0xFF04		.dw	rom_config		; Internal config, that is only reset by power cycle. This buffer can be written with <1 byte size> .dw C_CONFIG <offset> <data>
;0xFF06		.dw	sock_info			; socket structure for NETAPI, works like read only hardware registers
;0xFF08		.dw	helper_functions	; useful functions, to have executed in rom.

;Socket info structure (ptr read from 0xFF06), there is a total of 4 sockets for use and "socket 0" reserved C_NETHOSTIP. User sockets are 1-4. offset:
;(socket*16)+0	status  : current status 0=idle, 1=connect in progress, 2=send in progress, 3=remote closed connectoion, 
;					4=wait incoming (accept), 5=dnslookup in progress, 240-255 = error code
;(socket*16)+1	lastcmd : last command updating sock status 0=none, 1=send, 2=dnslookup, 3=connect, 4=accept, 5=recv, 6=error handler
;(socket*16)+2	received: (2 bytes)	- data received in internal buffer (ready to get with C_NETRECV)
;(socket*16)+4	ip_addr :	(4 bytes)	- ip addr of connected client in passive mode
;(socket*16)+8	port    :	(2 bytes)	- port of the same..
;(socket*16)+10	reserved: (6 bytes)	- not used yet (alignment!).


; ------------------------------------------------------------------------------
; http://www.spinpoint.org/cpc/m4info.txt
M4_CMD_SOCKET		; 0x4331
; Implemented v1.0.9. data[0] = domain, data[1] = type, data[2] = protocol. 
; Return data[0] = socket number or 0xFF (error). Only TCP protocol for now.
			
			; get a socket
			
			;cmdsocket:		db	5
			;	dw	C_NETSOCKET
			;	db	0x0,0x0,0x6		; domain, type, protocol (TCP/IP)
			ld		hl,ROM_cmdsocket
			call	M4_sendcmd
			
			call    GetM4ROMNumber	; OUT  C=M4ROM-Number

			call    FF02_IY__Get_M4_Buffer_Response_Address	; OUT HL=Adresse			ld		hl,(0xFF02)	; get response buffer address

			inc hl
			inc hl
			inc hl			
			call Read8BitFromROM	; IN: C=ROM-Number, HL=Adress   OUT: A=Value	;			ld		a,(hl)
;MAXAM	; A=1
			cp		255
			;ret		z
			ret


FF02_IY__Get_M4_Buffer_Response_Address
			push af
			ld hl,#FF02
			push bc
			call Read16BitFromROM	; IN: C=ROM-Number, HL=Adress   OUT: HL=Value	;			ld		hl,(0xFF02)	; get response buffer address
			pop bc
			pop af
			ret

FF06_IX__Get_M4_Socket_Response_Address	; OUT:  HL=Socket response adress    (ld		hl,(0xFF06)	; get Socket response address)
			push af
			ld hl,#FF06
			push bc
			call Read16BitFromROM	; IN: C=ROM-Number, HL=Adress   OUT: HL=Value	;			ld		hl,(0xFF06)	; get Socket response address
			pop bc
			pop af
			ret

						
			
			; store socket in predefined packets
;			push af			
;			ld		(csocket),a
;			ld		(clsocket),a
;			ld		(rsocket),a
;			ld		(sendsock),a
			
			
;			pop af
			Clear_Z_Flag
			ret

ROM_cmdsocket:		db	5
				dw	M4_C_NETSOCKET
				db	0x0,0x0,0x6		; domain, type, protocol (TCP/IP)

			
; ------------------------------------------------------------------------------
M4_CMD_CONNECT		; IN   A=Socket, DE=Pointer to IP-Addr      Z-Flag indicates Error

			ex de,hl
			
			call	send_cmd_connect  ; IN   A=Socket, HL=Pointer to IP-Addr
			
			call    GetM4ROMNumber	; OUT  C=M4ROM-Number
			
			call    FF02_IY__Get_M4_Buffer_Response_Address	; OUT HL=Adresse			ld		hl,(0xFF02)	; get response buffer address
			
			inc hl
			inc hl
			inc hl
			call Read8BitFromROM	; IN: C=ROM-Number, HL=Adress   OUT: A=Value	;			ld		a,(hl)
			cp		255
;			ret z
;			Clear_Z_Flag
			ret
			
			
; ------------------------------------------------------------------------------						;
M4_GET_SOCKET_STATE	; IN A= Socket,   OUT   (0 ==IDLE (OK), 1 == connect in progress, 2 == send in progress)		       DE=Data   (from IX+2 / IX+3)	
; Socket
; 0: #FE00
; 1: #FE10

			push ix
			push hl
			call    GetM4ROMNumber	; OUT  C=M4ROM-Number			
;MAXAM		; A=1 (ok)
			call	GetSocketPtr	; IN A=Socket,C=ROM-Number OUT IX=Ptr
			
			push ix
			inc ix
			inc ix
;MAXAM	  ; IX=#FE02
			push ix
			pop hl
;fe12		
			call Read16BitFromROM	; IN: C=ROM-Number, HL=Adress   OUT: HL=Value	;			ld		hl,(0xFF02)	; get response buffer address

			ex de,hl
			pop hl
;MAXAM		; C=6 (ok)
			call Read8BitFromROM	; IN: C=ROM-Number, HL=Adress   OUT: A=Value		,;ld a,(ix)
		
			pop hl
			pop ix
;MAXAM			

			ret

; ------------------------------------------------------------------------------						;
GetSocketPtr		; GetSocketPtr	; IN A=Socket,C=ROM-Number OUT IX=Ptr
			; multiply by 16 and add to socket status buffer
			push hl
			push de
			
			sla		a
			sla		a
			sla		a
			sla		a
			
;			ld		hl,(0xFF06)	; get sock info
			call 	FF06_IX__Get_M4_Socket_Response_Address	; IN: C=ROM-Number OUT:  HL=Socket response adress    (ld		hl,(0xFF06)	; get Socket response address)
		

;Socket info structure (ptr read from 0xFF06), there is a total of 4 sockets for use and "socket 0" reserved C_NETHOSTIP. User sockets are 1-4. offset:
;(socket*16)+0	status  : current status 0=idle, 1=connect in progress, 2=send in progress, 3=remote closed connectoion, 
;					4=wait incoming (accept), 5=dnslookup in progress, 240-255 = error code
;(socket*16)+1	lastcmd : last command updating sock status 0=none, 1=send, 2=dnslookup, 3=connect, 4=accept, 5=recv, 6=error handler
;(socket*16)+2	received: (2 bytes)	- data received in internal buffer (ready to get with C_NETRECV)
;(socket*16)+4	ip_addr :	(4 bytes)	- ip addr of connected client in passive mode
;(socket*16)+8	port    :	(2 bytes)	- port of the same..
;(socket*16)+10	reserved: (6 bytes)	- not used yet (alignment!).
			
			ld		e,a
			ld		d,0
			add		hl,de	; sockinfo + (socket*4)
			push	hl
			pop		ix		; ix ptr to current socket status
			pop de
			pop hl

			ret
; ------------------------------------------------------------------------------						;

puffermem4rsx equ #bf00

GetM4ROMNumber				; OUT  C=M4ROM-Number
	push de
	push hl
	
	push af

	ld hl,puffermem4rsx
	ld (hl),'S'
	inc hl
	ld (hl),'D'+#80
	dec hl
	call KL_FIND_COMMAND		; OUT: HL=Adress, C=ROM-Number
	pop af
	pop hl
	pop de
	ret
	;ld c,6
	;ret


Read16BitFromROM	; IN: C=ROM-Number, HL=Adress   OUT: HL=Value	;			ld		hl,(0xFF02)	; get response buffer address
			push ix
			push de
			push bc
			call Read16BitFromROM_Main
			pop bc
			pop de
			pop ix
			ret
Read16BitFromROM_Main	
; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!			
;ld a,(hl)	; #7e
;inc hl		; #23
;ld h,(hl)	; #66
;ld l,a		; #6F
;ret		; #c9
; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		
			ld ix,#B918
			push ix
			ld ix,puffermem4rsx
			
			ld (ix+00),#7e	;ld a,(hl)	; #7e
			ld (ix+01),#23	;inc hl		; #23
			ld (ix+02),#66	;ld h,(hl)	; #66
			ld (ix+03),#6f	;ld l,a		; #6F
			ld (ix+04),#c9	;ret		; #c9
			push ix
			jp #B90F	; HI KL ROM SELECT		IN:    C = ROM-Select-Byte		OUT    C = alte ROM-Selection		B = alter ROM-Status		Unverändert: DE,HL,IX,IY
			
;			call #B90F	; HI KL ROM SELECT		IN:    C = ROM-Select-Byte		OUT    C = alte ROM-Selection		B = alter ROM-Status		Unverändert: DE,HL,IX,IY
;			ld a,(hl)
;			inc hl
;			ld h,(hl)
;			ld l,a
;			jp #B918	; HI KL ROM DESELECTION	IN:   C = alte ROM-Selection	       B = alter ROM-Status			OUT:    C = zuletzt angewähltes ROM				Unverändert: AF,DE,HL,IX,IY


Read32BitFromROM; IN: C=ROM-Number, HL=Adress   OUT: HLDE=Value			IX Destroyed
			push ix
			push bc
			call Read32BitFromROM_Main
			pop bc
			pop ix
			ret
Read32BitFromROM_Main			
; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!			
;ld e,(hl)	; #5e
;inc hl		; #23
;ld d,(hl)	; #56
;inc hl		; #23
;ld a,(hl)	; #7e
;inc hl		; #23
;ld h,(hl)	; #66
;ld l,a		; #6F
;ret		; #c9
; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


			ld ix,#B918
			push ix
			ld ix,puffermem4rsx
			
			ld (ix+00),#5e	;ld e,(hl)	; #5e
			ld (ix+01),#23	;inc hl		; #23
			ld (ix+02),#56	;ld d,(hl)	; #56
			ld (ix+03),#23	;inc hl		; #23
			ld (ix+04),#7e	;ld a,(hl)	; #7e
			ld (ix+05),#23	;inc hl		; #23
			ld (ix+06),#66	;ld h,(hl)	; #66
			ld (ix+07),#6f	;ld l,a		; #6F
;	ld (ix+08),#F7			; MAXAM
			ld (ix+08),#c9	;ret		; #c9
			push ix
			jp #B90F	; HI KL ROM SELECT		IN:    C = ROM-Select-Byte		OUT    C = alte ROM-Selection		B = alter ROM-Status		Unverändert: DE,HL,IX,IY




Read8BitFromROM	; IN: C=ROM-Number, HL=Adress   OUT: A=Value	;			ld		a,(hl)
			push ix
			push de
			push bc
			call Read8BitFromROM_Main

			pop bc
			pop de
			pop ix
			ret

Read8BitFromROM_Main
; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!			
;ld a,(hl)	; #7e
;ret		; #c9
; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

			ld ix,#B918
			push ix
			ld ix,puffermem4rsx
			ld (ix+0),#7e		;ld a,(hl)	; #7E
			ld (ix+1),#c9		;ret		; #c9
			push ix
			jp #B90F	; HI KL ROM SELECT		IN:    C = ROM-Select-Byte		OUT    C = alte ROM-Selection		B = alter ROM-Status		Unverändert: DE,HL,IX,IY
			
;			ld a,(hl)	; #7e
;			ret			; #c9
			
;			call #B90F	; HI KL ROM SELECT		IN:    C = ROM-Select-Byte		OUT    C = alte ROM-Selection		B = alter ROM-Status		Unverändert: DE,HL,IX,IY
;			ld a,(hl)
;			jp #B918	; HI KL ROM DESELECTION	IN:   C = alte ROM-Selection	       B = alter ROM-Status			OUT:    C = zuletzt angewähltes ROM				Unverändert: AF,DE,HL,IX,IY
; ------------------------------------------------------------------------------						;
			; Send command to M4
			; HL = packet to send
			;
M4_sendcmd:
			ld		bc,0xFE00
			ld		d,(hl)
			inc		d
M4_sendcmd_sendloop:
			inc		b
			outi
			dec		d
			jr		nz,M4_sendcmd_sendloop
			ld		bc,0xFC00
			out		(c),c
			ret



send_cmd_connect:		; IN   A=Socket, HL=Pointer to IP-Addr
			push af
			ld		bc,0xFE00
;			ld		bc,0xFF00
			ld a,#9	; Länge von C_NETCONNECT
			out (C),a
			
			ld a,M4_C_NETCONNECT			; Bit 0-8

			out (C),a
			ld a,M4_C_NETCONNECT>>8		; Bit 9-16
			out (C),a
	
			pop af	; Socket			(0-4)
;MAXAM
			out (C),a
			

			; send_ip_backwards			
			; IP 4 Bytes
;ld a,(hl)
;MAXAM
inc		b
			outi		;Reads from (HL) and writes to the (C) port. HL is then incremented, and B is decremented.
			inc		b
;ld a,(hl)
;MAXAM
			outi		;Reads from (HL) and writes to the (C) port. HL is then incremented, and B is decremented.		
			inc		b
			outi		;Reads from (HL) and writes to the (C) port. HL is then incremented, and B is decremented.		
			inc		b
			outi		;Reads from (HL) and writes to the (C) port. HL is then incremented, and B is decremented.		
			inc		b
			
			ld		bc,0xFE00
			;port:			dw	23		; port

			ld a,23		; Port 23
			out (C),a
			ld a,0		; Port 23
			out (C),a

			ld		bc,0xFC00
			out		(c),c
			ret
; ------------------------------------------------------------------------------
; DE-Reg: data[0..] = hostname string\0. Return data[0] = 1 Lookup in progress. Any other = error. Look in M4rom sockinfo for IP and status
; DE = Stringadress
; IN IX=Adress of IP-Adress, BC=Adress of the Host-String			OUT=Filled (BC) with IP-Adress
; OUT   A=0 => All OK
M4_CMD_NET_LOOKUP_IP:

			push de
			
			push ix
			pop hl			
		
			call M4_CMD_NET_LOOKUP_IP_send		; IN   HL=Adress of Name to lookup
			
			; Analyse
			call    GetM4ROMNumber	; OUT  C=M4ROM-Number

			
			call    FF02_IY__Get_M4_Buffer_Response_Address	; OUT HL=Adresse			ld		hl,(0xFF02)	; get response buffer address
			
			inc hl
			inc hl
			inc hl
			call Read8BitFromROM	; IN: C=ROM-Number, HL=Adress   OUT: A=Value	;			ld		a,(hl)
			cp 	1
			jr		z,M4_CMD_NET_LOOKUP_IP_wait
			pop 	de
			ld		a,1
			ret

M4_CMD_NET_LOOKUP_IP_wait
			call 	FF06_IX__Get_M4_Socket_Response_Address	; OUT:  HL=Socket response adress    (ld		hl,(0xFF06)	; get Socket response address)
			
	
M4_CMD_NET_LOOKUP_IP_wait_lookup
			call Read8BitFromROM	; IN: C=ROM-Number, HL=Adress   OUT: A=Value	;			ld	a,(ix+0)
			cp	5			; ip lookup in progress
			jr	z,M4_CMD_NET_LOOKUP_IP_wait_lookup
			push af
			
;			call Read8BitFromROM	; IN: C=ROM-Number, HL=Adress   OUT: A=Value	;			ld	a,(ix+0)
			inc hl
			inc hl
			inc hl
			inc hl   ; HL points now to the IP-Adress
			
;MAXAM
			call Read32BitFromROM; IN: C=ROM-Number, HL=Adress   OUT: HLDE=Value    IX Destroyed
			pop af
			pop ix	; Destination of IP-Adress-Memory
			
;MAXAM
			ld (ix+0),e
			ld (ix+1),d
			ld (ix+2),l
			ld (ix+3),h
			ret
			
			
M4_CMD_NET_LOOKUP_IP_send:			; IN   HL=Adress of Name to lookup
			; Send Data to M4
			ld		bc,0xFE00
			ld a,16	; Länge von String
			out (C),a
			
			ld a,M4_C_NETHOSTIP			; Bit 0-8
			out (C),a
			ld a,M4_C_NETHOSTIP>>8		; Bit 9-16
			out (C),a



			ld d,14
M4_CMD_NET_LOOKUP_IP_sendloop_NEU:
			ld a,(hl)
			inc hl
			out (c),a

			dec d			
			jr nz,M4_CMD_NET_LOOKUP_IP_sendloop_NEU
			
			
			ld		bc,0xFC00
			out		(c),c			
			ret
			
			
			
			



			ld d,16
			inc		d
M4_CMD_NET_LOOKUP_IP_sendloop
			inc		b
			outi
			dec		d
			jr		nz,M4_CMD_NET_LOOKUP_IP_sendloop
			ld		bc,0xFC00
			out		(c),c
			ret

; Original Code:
;			ld		hl,(0xFF02)	; get response buffer address
;			push	hl
;			pop		iy
;			
;			ld		hl,(0xFF06)	; get sock info
;			push	hl
;			pop		ix		; ix ptr to current socket status
;			
;
;			ld		hl,cmdlookup
;			call	sendcmd
;			ld		a,(iy+3)
;			cp		1
;			jr		z,wait_lookup
;			ld		a,1
;			ret
;			
;wait_lookup:
;			ld	a,(ix+0)
;			cp	5			; ip lookup in progress
;			jr	z, wait_lookup
;			ret
			
;cmdlookup:		db	16
;				dw	C_NETHOSTIP
;lookup_name:	ds	128

; ------------------------------------------------------------------------------
;C_NETRECV        	0x4335		Implemented v1.0.9.	data[0] = socket, data[1..2] = receive size (don't flood buffer, max. 0x800).
;							Return data[0] = 0. data[1..2] = actual received size. data[3...] = received data. Look at sockinfo for status.
; IN A= Socket, DE=Size IX=Pointer to Data   OUT   A=Buffer State,  BC=Size, Filled (DE)-Memory
M4_CMD_NET_RECEIVE_DATA:
			; Send Data to M4
			
			push de
			push af
;MAXAM						
			ld		bc,0xFE00
			ld a,5
			out (C),a
			
			
			ld a,M4_C_NETRECV			; Bit 0-8
			out (C),a
			ld a,M4_C_NETRECV>>8		; Bit 9-16
			out (C),a
			pop af
			out (C),a					; Socket
			
			pop de						; Size
			out (c),e
			out (c),d			
			
			ld		bc,0xFC00
			out		(c),c
			
			; Auswertungsphase		
			call    GetM4ROMNumber	; OUT  C=M4ROM-Number
			; IY-Register					
			call  FF02_IY__Get_M4_Buffer_Response_Address; IN: C=ROM-Number OUT HL=Adresse			ld		hl,(0xFF02)	; get response buffer address
			inc hl
			inc hl
			inc hl
			inc hl
			
			push hl
			
;MAXAM		; HL ist richtig?	
			; Lese die empfangene Laenge   (#E801)
			; ld bc,(iy+4)     ; +4  +5
			call Read16BitFromROM	; IN: C=ROM-Number, HL=Adress   OUT: HL=Value	;			ld	a,(ix+0)
;MAXAM		; HL ist falsch					
			push hl
			pop de		; Länge in DE
			
			pop hl
			
			
			inc hl
			inc hl		; #E806			
			push de


M4_CMD_NET_RECEIVE_DATA___TRANSFER_DATA_LOOP
			;ld a,(iy+6)  Datenstart

;ld a,hl    ich komme hier mit ix und iy durcheinander
;MAXAM
;nop
			call Read8BitFromROM	; IN: C=ROM-Number, HL=Adress   OUT: A=Value	;			ld		a,(hl)

;			push af
;			call SUB_Print_8BitHex
;			pop af

;ld a,a			
			ld (ix),a
			inc ix
			inc hl
			dec de
			ld  a, d
			or  e
			jr  nz,M4_CMD_NET_RECEIVE_DATA___TRANSFER_DATA_LOOP
			
			; ld		a,(iy+3)			
			; C ist hier richtig (=ROM-Nr. M4)
			call  FF02_IY__Get_M4_Buffer_Response_Address; IN: C=ROM-Number OUT HL=Adresse			ld		hl,(0xFF02)	; get response buffer address
			inc hl
			inc hl
			inc hl
		
			call Read8BitFromROM	; IN: C=ROM-Number, HL=Adress   OUT: A=Value	;			ld		a,(hl)
			
			pop bc
;MAXAM			

			ret


;cmdrecv:		db	5
;				dw	M4_C_NETRECV	; recv
;rsocket:		db	0x0			; socket
;rsize:			dw	2048		; size





; ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
M4_CMD_NET_SEND_CUSTOM_DATA:
			ld	bc,&FE00
			ld a,(ix+0)

			push af
			inc a
			inc a
			out (C),a
			
			
			ld a,M4_C_NETSEND			; Bit 0-8
			out (C),a
			ld a,M4_C_NETSEND>>8		; Bit 9-16
			out (C),a
			
			inc ix
			
			pop de
M4_CMD_NET_SEND_CUSTOM_DATA_LOOP:			
			ld a,(ix)
			inc ix
			out (c),a

			dec d
			
			jr nz,M4_CMD_NET_SEND_CUSTOM_DATA_LOOP			
			
			
			ld		bc,0xFC00
			out		(c),c			
			ret			
; ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
M4_CMD_CLOSE_CONNECTION		; IN A= Socket
			
			ld	bc,&FE00
			ld  e,3; Size

			out (c),e
			
			
			
			ld e,M4_C_NETCLOSE			; Bit 0-8
			out (C),e
			ld e,M4_C_NETCLOSE>>8		; Bit 9-16
			out (C),e
			
			out (c),a	; Socket

			
			ld		bc,0xFC00
			out		(c),c
			
			ret
			
; ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
