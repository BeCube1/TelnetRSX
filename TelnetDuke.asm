			; Telnet client v1.0.1 beta example for M4 Board
			; Written by Duke 2018
			; Requires firmware v1.1.0 upwards
			; Assembles with RASM (www.roudoudou.com/rasm)
			; Formatted for Notepad++, see :  
			; http://www.cpcwiki.eu/forum/amstrad-cpc-hardware/amstrad-cpc-wifi/msg150664/#msg150664
			; to easily cross compile and test quick on real CPC

			
puffermem equ $bf00
KL_FIND_COMMAND	equ $bcd4
org $0170
db $0a,$00,$0a,$00,$83,$20,$1c,$80,$01,$00		; Call $180

org $180
;	ld c,6
;	call $B90F ;KL_ROM_SELECT
			
;			org	$1000
;			nolist
			
DATAPORT		equ $FE00
ACKPORT			equ $FC00			

; m4 commands used
C_NETSOCKET		equ $4331
C_NETCONNECT	equ $4332
C_NETCLOSE		equ $4333
C_NETSEND		equ $4334
C_NETRECV		equ $4335
C_NETHOSTIP		equ $4336

; firmware functions used
km_read_char	equ	$BB09
km_wait_key		equ	$BB18
txt_output		equ $BB5A
txt_set_column	equ $BB6F
txt_set_row		equ $BB72
txt_set_cursor	equ	$BB75
txt_get_cursor	equ	$BB78
txt_cur_on		equ	$BB81
scr_reset		equ	$BC0E
scr_set_ink		equ	$BC32
scr_set_border	equ	$BC38
mc_wait_flyback	equ	$BD19
kl_rom_select	equ $b90f

; telnet negotiation codes
DO 				equ $fd
WONT 			equ $fc
WILL 			equ $fb
DONT 			equ $fe
CMD 			equ $ff
CMD_ECHO 		equ 1
CMD_WINDOW_SIZE equ 31
			
start:		ld		a,2			
			call	scr_reset		; set mode 2
			xor		a
			ld		b,a
			call	scr_set_border
			xor		a
			ld		b,0
			ld		c,0
			call	scr_set_ink
			ld		a,1
			ld		b,26
			ld		c,26
			call	scr_set_ink
			ld		h,20
			ld		l,1
			call	txt_set_cursor
			ld		hl,msgtitle
			call	disptextz
			ld		h,20
			ld		l,2
			call	txt_set_cursor

			ld		hl,msgtitle2
			call	disptextz
			call	crlf
			
			; find rom M4 rom number
			
			ld		a,(m4_rom_num)
			cp		$FF
			call	z,find_m4_rom	
			cp		$FF
			jr		nz, found_m4
			
			ld		hl,msgnom4
			call	disptextz
			jp		exit
			
found_m4:	ld		hl,msgfoundm4
			call	disptextz
			ld		hl,($FF00)	; get version
			ld		a,h
			call	print_lownib
			ld		a,$2E
			call	txt_output
			ld		a,l
			rr		a
			rr		a
			rr		a
			rr		a
			call	print_lownib
			ld		a,$2E
			call	txt_output
			ld		a,l
			call	print_lownib
			
			; compare version
			
			ld		de,$110		; v1.1.0 lowest version required
			ld 		a,h
			xor		d
			jp		m,cmpgte2
			sbc		hl,de
			jr		nc,cmpgte3
cmpgte1: 	ld		hl,msgverfail
			call	disptextz
			jp		exit
cmpgte2:	bit		7,d
			jr		z,cmpgte1
cmpgte3:	ld		hl,msgok	
			call	disptextz

			; ask for server / ip
loop_ip:
			ld		hl,msgserverip
			call	disptextz
			call	get_server
			cp		0
			jr		nz, loop_ip
;ld ix,ip_addr
;ld (ix+0),162
;ld (ix+1),73
;ld (ix+2),168
;ld (ix+3),192
			
			ld		hl,msgconnecting
			call	disptextz
			
			ld		hl,ip_addr
			call	disp_ip
			
			ld		hl,msgport
			call	disptextz
			
			ld		hl,(port)
			call	disp_port
			call	crlf
			call	telnet_session
			jr		loop_ip
			
exit:
			jp		km_wait_key

print_lownib:			
			and		$F			; keep lower nibble
			add		a,48			; 0 + x = neric ascii
			jp		txt_output
			
get_server:	
			ld		hl,buf
			call	get_textinput
			
			;cp		$FC			; ESC?
			;ret		z
			xor		a
			cp		c
			jr		z, get_server
		
			; check if any none neric chars
			
			ld		b,c
			ld		hl,buf
check_neric:
			ld		a,(hl)
			cp		59				; bigger than ':' ?
			jr		nc,dolookup
			inc		hl
			djnz	check_neric
			jp		convert_ip
			
			; make dns lookup
dolookup:	
			; copy name to packet
			
			ld		hl,buf
			ld		de,lookup_name
			ld		b,0
copydns:	ld		a,(hl)
			cp		58
			jr		z,copydns_done
			cp		0
			jr		z,copydns_done
			ld		a,b
			ldi
			inc		a
			ld		b,a
			jr		copydns
copydns_done:
			push	hl
			xor		a
			ld		(de),a		; terminate with zero
			
			ld		hl,cmdlookup
			inc		b			
			inc		b
			inc		b
			ld		(hl),b		; set  size
			
			; disp servername
			
			ld		hl,msgresolve
			call	disptextz
			ld		hl,lookup_name
			call	disptextz
			
			; do the lookup
			call	dnslookup			; OUT   A=0 => All OK
			pop		hl
			cp		0
			jr		z, lookup_ok
			
			ld		hl,msgfail
			call	disptextz
			ld		a,1
				

		
			ret
			
lookup_ok:	push	hl			; contains port "offset"
			ld		hl,msgok
			call	disptextz
			
			; copy IP from socket 0 info
			ld		hl,($FF06)
			ld		de,4
			add		hl,de
			ld		de,ip_addr
			ldi
			ldi
			ldi
			ldi
			pop		hl
			jr		check_port
			; convert ascii IP to binary, no checking for non decimal chars format must be x.x.x.x
convert_ip:			
			ld		hl,buf	
			call	ascii2dec
			ld		(ip_addr+3),a
			call	ascii2dec
			ld		(ip_addr+2),a
			call	ascii2dec
			ld		(ip_addr+1),a
			call	ascii2dec
			ld		(ip_addr),a
			dec		hl
check_port:	ld		a,(hl)
			cp		$3A		; any ':' for port number ?
			jr		nz, no_port
			
			push	hl
			pop		ix
			call	port2dec
			
			jr		got_port
			
no_port:	ld		hl,23
got_port:	
			ld		(port),hl
			xor		a
			ret

; ------------------------------------------------------------------------------

dnslookup:	; OUT   A=0 => All OK
			ld		hl,($FF02)	; get response buffer address
			push	hl
			pop		iy
			
			ld		hl,($FF06)	; get sock info
			push	hl
			pop		ix		; ix ptr to current socket status			
			


			ld ix,buf			; Name of the Side to resolve
			ld bc,ip_addr
			
; IN IX=Adress of IP-Adress, BC=Adress of the Host-String			OUT=Filled (BC) with IP-Adress
			call RSX_CMD_NET_LOOKUP_IP     ; OUT   A=0 => All OK

			ret
			
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
			
; ------------------------------------------------------------------------------
			
			; actual telnet session
			; M4 rom should be mapped as upper rom.
			
telnet_session:	
			ld		hl,($FF02)	; get response buffer address
			push	hl
			pop		iy
			
			; get a socket
			
;			ld		hl,cmdsocket
;			call	sendcmd
;			ld		a,(iy+3)
;			cp		255
;			ret		z
			
			call RSX_CMD_SOCKET		; OUT: A=Socket	; ix ptr to current socket status  Z=ERROR
			ret z
			
			; store socket in predefined packets
			
			ld		(csocket),a
			ld		(clsocket),a
			ld		(rsocket),a
			ld		(sendsock),a
			
			
			; multiply by 16 and add to socket status buffer
			
			sla		a
			sla		a
			sla		a
			sla		a
			
			ld		hl,($FF06)	; get sock info
			ld		e,a
			ld		d,0
			add		hl,de	; sockinfo + (socket*4)
			push	hl
			pop		ix		; ix ptr to current socket status
			
			; connect to server
			
;			ld		hl,cmdconnect
;			call	sendcmd
;			ld		a,(iy+3)
;			cp		255
;			jp		z,exit_close
			ld a,(rsocket)
			ld de,ip_addr
			call RSX_CMD_CONNECT			;  IN   A=Socket, DE=Pointer to IP-Addr      Z-Flag indicates Error
			jp		z,exit_close			

wait_connect:
;			ld		a,(ix)			; get socket status  (0 ==IDLE (OK), 1 == connect in progress, 2 == send in progress)
			ld		a,(rsocket)
			call RSX_CMD_GET_SOCKET_STATE	; IN A= Socket,   OUT   (0 ==IDLE (OK), 1 == connect in progress, 2 == send in progress) , 3==closed
			
			cp		1				; connect in progress?
			jr		z,wait_connect
			cp		0
			jr		z,connect_ok
			call	disp_error	
			jp		exit_close

			; ------------------------------------------------------
connect_ok:	ld		hl,msgconnect
			call	disptextz
			
		
mainloop:	ld		bc,1
			call	recv_noblock
			
			call	km_read_char
			jr		nc,mainloop
			cp		$FC			; ESC?
			jp		z, exit_close	
			cp		$9				; TAB?
			jr		nz, no_pause
wait_no_tab:
			call	km_read_char
			cp		$9
			jr		z, wait_no_tab
			
pause_loop:			
			call	km_read_char
			cp		$FC			; ESC?
			jp		z, exit_close	
			cp		$9				; TAB again to leave
			jr		nz, pause_loop
			jr		mainloop
no_pause:
			
			ld		hl,sendtext
			ld		(hl),a
			
			
			push hl
wait_send:	
			;ld		a,(ix)
			ld		a,(rsocket)
			call RSX_CMD_GET_SOCKET_STATE	; IN A= Socket,   OUT   (0 ==IDLE (OK), 1 == connect in progress, 2 == send in progress) , 3==closed
			
			cp		2			; send in progress?
			jr		z,wait_send	
			pop hl
			cp		0
			call	nz,disp_error	
			
			;xor		a
			;ld		(isEscapeCode),a
			
			ld		a,(hl)
			;call	txt_output
			cp		$D
			jr		nz, plain_text
			inc		hl
			ld		a,$A
			;call	txt_output
			ld		(hl),a
			
;			ld		a,7
;			ld		(cmdsend),a
;			ld		a,2
;			ld		(sendsize),a
;			ld		hl,cmdsend			
;			call	sendcmd
			ld a,(rsocket)
			ld ix,cmdsend
			ld ix,$4000
			ld (ix+0),5		; Size								
			ld (ix+1),a
			ld (ix+2),$01	; Sendsize
			ld (ix+3),$00	; Sendsize			
			ld a,(sendtext)
			ld (ix+4),a
			ld a,(sendtext+1)
			ld (ix+5),a			
			call 	RSX_CMD_NET_SEND_CUSTOM_DATA	; IN IX=Pointer to Data ($00:Length, $01:Socketnumber, $02-$9999:Data)   OUT   nothing

			jp		mainloop
			
plain_text:
;			ld		a,6
;			ld		(cmdsend),a
;			ld		a,1
;			ld		(sendsize),a
;			ld		hl,cmdsend
;			call	sendcmd

			; negotiate window size
			ld a,(rsocket)
			ld ix,cmdsend
			ld ix,$4000
			ld (ix+0),4		; Size								
			ld (ix+1),a
			ld (ix+2),$01	; Sendsize
			ld (ix+3),$00	; Sendsize			
			ld a,(sendtext)
			ld (ix+4),a
			call 	RSX_CMD_NET_SEND_CUSTOM_DATA	; IN IX=Pointer to Data ($00:Length, $01:Socketnumber, $02-$9999:Data)   OUT   nothing
			
			
			
			jp		mainloop


			; call when CMD ($FF) detected, read next two bytes of command
			; IY = socket structure ptr
negotiate:
		
			ld		bc,2
			call	recv
			cp		$FF
			jp		z, exit_close	
			cp		3
			jp		z, exit_close
			xor		a
			cp		c
			jr		nz, check_negotiate
			cp		b
			jr		z,negotiate	; keep looping, want a reply. Could do other stuff here!
			

check_negotiate:	
		ld iy,NetReadDataBuf-6			;#######
;		ld iy,NetReadDataBuf-3			;#######			
			
			ld		a,(iy+6)
			cp		$FD	; DO
			jp		nz, will_not
			ld		a,(iy+7)
			cp		CMD_WINDOW_SIZE	
			jp		nz, will_not
			
		
goon0			
 			push ix
			push iy
			push hl		
		 	
			; negotiate window size
			ld a,(rsocket)
			ld ix,cmdsend
			ld ix,$4000
			ld (ix+0),6		; Size								
			ld (ix+1),a
			ld (ix+2),$03	; Sendsize
			ld (ix+3),$00	; Sendsize			
			ld (ix+4),$FF		; CMD
			ld (ix+5),$FB		; WILL
			ld (ix+6),CMD_WINDOW_SIZE
			call 	RSX_CMD_NET_SEND_CUSTOM_DATA	; IN IX=Pointer to Data ($00:Length, $01:Socketnumber, $02-$9999:Data)   OUT   nothing

			pop hl
			pop iy
			pop ix
			
			; -----------------------------------------------------
_wait_sendxxx		
			ld a,(rsocket)
			call RSX_CMD_GET_SOCKET_STATE	; IN A= Socket,   OUT   (0 ==IDLE (OK), 1 == connect in progress, 2 == send in progress) , 3==closed)       DE=Data   (from IX+2 / IX+3)		ld a,(ix)
			cp		2			; send in progress?
			jr		z,_wait_sendxxx
			cp		0
			call	nz,disp_error
		
			ld a,(rsocket)
			ld ix,cmdsend
			ld ix,$4000
			ld (ix+0),12		; Size
			ld (ix+1),a
			ld (ix+2),9	; Sendsize
			ld (ix+3),0	; Sendsize			
			ld (ix+4),$FF		; CMD
			ld (ix+5),$FA		; SB sub negotiation
			ld (ix+6),CMD_WINDOW_SIZE			
			ld (ix+7),0
			ld (ix+8),80			
			ld (ix+9),0
			ld (ix+10),24
			ld (ix+11),255			
			ld (ix+12),240		; End of subnegotiation parameters.

			
			call 	RSX_CMD_NET_SEND_CUSTOM_DATA	; IN IX=Pointer to Data ($00:Length, $01:Socketnumber, $02-$9999:Data)   OUT   nothing
			ret
			

			
will_not:
			
			ld		a,(iy+6)
			cp		$FD			; DO
			jr		nz, not_do
			ld		a,$FC			; WONT
			jr		next_telcmd
not_do:		cp		$FC			; WILL
			jr		nz, next_telcmd
			ld		a,$FD			; DO

next_telcmd:
			push af
			ld a,(rsocket)
			ld ix,cmdsend
			ld ix,$4000
			ld (ix+0),6		; Size
			ld (ix+1),a
			ld (ix+2),3	; Sendsize
			ld (ix+3),0	; Sendsize			
			ld (ix+4),$FF		; CMD
			pop af
			ld (ix+5),a
			ld	a,(iy+7)
			ld (ix+6),a
			
			call 	RSX_CMD_NET_SEND_CUSTOM_DATA	; IN IX=Pointer to Data ($00:Length, $01:Socketnumber, $02-$9999:Data)   OUT   nothing
			ret



; ---------------------------------------------------------------------------------		

recv_noblock:
			push 	af
			push 	bc
			push 	de
			push 	hl
			
			;ld	bc,2048		- to do empty entire receive buffer and use index
			
			ld		bc,1
			
			call 	recv
			cp		$FF
			jp		z, exit_close	
			cp		3
			jp		z, exit_close
			xor		a
			cp		c
			jr		nz, got_msg2
			cp		b
			jr		nz, got_msg2
			pop 	hl
			pop 	de
			pop 	bc
			pop 	af
			ret
got_msg2:	
			; disp received msg
			push	iy
			pop		hl
			ld		de,$6
			add		hl,de		; received text pointer
		ld hl,NetReadDataBuf			;#######	
			ld		a,(hl)
			
			cp		CMD
			jr		nz,not_tel_cmd
			call	negotiate
			
			jp		recvdone
			
not_tel_cmd:
			ld		b,a
			cp		$1B		; escape code sequence?
			jr		nz, notescapeCode
			ld		(isEscapeCode),a
			xor		a
			ld		(EscapeCount),a
			jp		recvdone
notescapeCode:
			ld		a,(isEscapeCode)
			cp		0
			jp		z, not_in_escmode
			ld		hl, EscapeBuf
			ld		a, (EscapeCount)
			inc		a
			ld		e,a
			ld		d,0
			add		hl,de
			ld		(EscapeCount),a
			cp		1
			jp		z, skip_check_esc_code	; we only want $1B,'[' ... for now
			ld		a,(hl)
			
			cp		'A'					; cursor up
			jr		nz,	not_A
			ld		b,11				; VT
			ld		a, (EscapeCount)
			cp		2
			jp		z,do_control_code
			call	escape_val
			ld		b,a
			call	txt_get_cursor		; H = col, L = line
			ld		a,l
			sub		b					; new line (should do <0 etc checks, gah)
			call	txt_set_row
			jp		isok2
not_A:
			cp		'B'					; cursor down
			jr		nz,	not_B
			ld		a, (EscapeCount)
			ld		b,10				; LF
			cp		2
			jp		z,do_control_code
			call	escape_val
			ld		b,a
			call	txt_get_cursor		; H = col, L = line
			ld		a,l
			add		a,b					; new line 
			call	txt_set_row
			jp		isok2
			jp		do_control_code
not_B:
			cp		'C'					; cursor forward
			jr		nz,	not_C
			ld		a, (EscapeCount)
			ld		b,9					; TAB
			cp		2
			jp		z,do_control_code
			call	escape_val
			ld		b,a
			call	txt_get_cursor		; H = col, L = line
			ld		a,h
			add		a,b					; new column, should check
			call	txt_set_column
			jp		isok2
not_C:			
			cp		'D'					; cursor backwards
			jr		nz,	not_D
			ld		a, (EscapeCount)
			ld		b,8					; BS
			cp		2
			jp		z,do_control_code
			call	escape_val
			ld		b,a
			call	txt_get_cursor		; H = col, L = line
			ld		a,h
			sub		b					; new column, should check
			call	txt_set_column
			jp		isok2
not_D:		cp		'E'				; cursor next line
			jr		nz, not_E
			ld		a, (EscapeCount)
			call		escape_val
			ld		b,1
			cp		0
			jr		z, default_1line
			ld		b,a
default_1line:			
			call	txt_get_cursor		; H = col, L = line
			add		a,l
			ld		l,a
			ld		h,0
			call	txt_set_cursor
			jp		isok2
not_E:		cp		'F'
			jr		nz, not_F
			call	escape_val
			ld		b,1
			cp		0
			jr		z, default_1line2
			ld		b,a
default_1line2:			
			call	txt_get_cursor		; H = col, L = line
			ld		a,l
			sub		b
			ld		l,a					
			ld		h,0
			call	txt_set_cursor
			jp		isok2
not_F:		cp		'G'
			jr		nz, not_G
			call	escape_val
			ld		b,1
			cp		0
			jr		z, default_1col
			ld		b,a
default_1col:			
			call	txt_get_cursor		; H = col, L = line
			ld		a,h
			sub		b
			ld		h,a					
			call	txt_set_cursor
			jp		isok2
not_G:
			cp		's'
			jr		nz, not_s
			call	txt_get_cursor
			ld		(curPos),hl
			jp		isok2
not_s:
			cp		'u'
			jr		nz, not_u
			ld		hl,(curPos)
			call	txt_set_cursor
			jp		isok2
not_u:			
		
skip_check_esc_code:	
			
			; filter out unsused sequences
			
			; upper case
			cp		$41
			jr		c, recvdone			; less than
			cp		$5A
			jr		c, isok2
			; check lower case
			cp		$61
			jr		c, recvdone			; less than
			cp		$7A
			jr		nc, recvdone
		
isok2:
			xor		a
			ld		(isEscapeCode),a
			jr		recvdone
do_control_code:
			xor		a
			ld		(isEscapeCode),a

not_in_escmode:
;MAXAM
			ld		a,b
			call	txt_output
recvdone:	
			
			pop		hl
			pop		de
			pop		bc
			pop 	af
			ret
			

exit_close:
			
			call	disp_error
			

			
			;ld		hl,cmdclose
			;call	sendcmd
			ld a,(rsocket)
			call RSX_CMD_CLOSE_CONNECTION; IN A= Socket	
			
			jp		loop_ip
			ret
; ------------------------------------------------------------------------------			
			; recv tcp data
			; in
			; bc = receive size
			; out
			; a = receive status
			; bc = received size 

			
recv:		; connection still active

			ld		a,(rsocket)
			push bc
			call RSX_CMD_GET_SOCKET_STATE	; IN A= Socket,   OUT   (0 ==IDLE (OK), 1 == connect in progress, 2 == send in progress) , 3==closed
			pop bc
;			ld		a,(ix)			;
			cp		3				; socket status  (3 == remote closed connection)
			ret		z
			; check if anything in buffer ?
			; DE <> 0 ?
			ld  	a, d
			or  	e
			jr		nz,recv_cont
			;ld		a,(ix+2)
			;cp		0
			;jr		nz,recv_cont
			;ld		a,(ix+3)
			;cp		0
			;jr		nz,recv_cont

;			ld		a,(rsocket)
;			call RSX_CMD_GET_SOCKET_STATE	; IN A= Socket,   OUT   (0 ==IDLE (OK), 1 == connect in progress, 2 == send in progress) , 3==closed
;			
;			cp		3				; socket status  (3 == remote closed connection)
;			ret		z
;			; check if anything in buffer ?
;			; DE <> 0 ?
;			ld  	a, d
;			or  	e
;			jr		nz,recv_cont
			ld		bc,0
			ld		a,1	
			ret

recv_cont:
			; set receive size
;			push de
;			pop bc
			
			ld		a,c
			ld		(rsize),a
			ld		a,b
			ld		(rsize+1),a
			
;			ld		hl,cmdrecv
;			call	sendcmd
			ld		a,(rsocket)
			ld ix,NetReadDataBuf
			push bc
			pop de
			
			call 	RSX_CMD_NET_RECEIVE_DATA	; IN A= Socket, DE=Size IX=Pointer to Data   OUT   BC=Size, Filled (DE)-Memory			
;			ld		a,(iy+3)
			cp		0				; all good ?
			jr		z,recv_ok
			push	af
			call	disp_error
			pop		af
			ld		bc,0
			ret

recv_ok:			
;			ld		c,(iy+4)
;			ld		b,(iy+5)
;			ret
			
; ------------------------------------------------------------------------------
			
			;
			; Find M4 ROM location
			;
				
find_m4_rom:
			ld		iy,m4_rom_name	; rom identification line
			ld		d,127		; start looking for from (counting downwards)
			
romloop:	push	de
			ld		c,d
			call	kl_rom_select		; system/interrupt friendly
			ld		a,($C000)
			cp		1
			jr		nz, not_this_rom
			ld		hl,($C004)	; get rsxcommand_table
			push	iy
			pop		de
cmp_loop:
			ld		a,(de)
			xor		(hl)			; hl points at rom name
			jr		z, match_char
not_this_rom:
			pop		de
			dec		d
			jr		nz, romloop
			ld		a,255		; not found!
			ret
			
match_char:
			ld		a,(de)
			inc		hl
			inc		de
			and		$80
			jr		z,cmp_loop
			
			; rom found, store the rom number
			
			pop		de			;  rom number
			ld 		a,d
			ld		(m4_rom_num),a
			ret

; ------------------------------------------------------------------------------								
;			;
;			; Send command to M4
;			; HL = packet to send
;			;
;sendcmd:
;			ld		bc,$FE00
;			ld		d,(hl)
;			inc		d
;sendloop:	inc		b
;			outi
;			dec		d
;			jr		nz,sendloop
;			ld		bc,$FC00
;			out		(c),c
;			ret
; ------------------------------------------------------------------------------					
			; display text
			; HL = text
			; BC = length

disptext:	xor		a
			cp		c
			jr		nz, not_dispend
			cp		b
			ret		z
not_dispend:
			ld 		a,(hl)
			push	bc
			call	txt_output
			pop		bc
			inc		hl
			dec		bc
			jr		disptext

			; display text zero terminated
			; HL = text
disptextz:	ld 		a,(hl)
			or		a
			ret		z
			call	txt_output
			inc		hl
			jr		disptextz

			;
			; Display error code in ascii (hex)
			;
	
			; a = error code
disp_error:
			cp		3
			jr		nz, not_rc3
			ld		hl,msgconnclosed
			jp		disptextz
not_rc3:	cp		$FC
			jr		nz,notuser
			ld		hl,msguserabort
			jp		disptextz
notuser:
			push	af
			ld		hl,msgsenderror
			ld		bc,9
			call	disptext
			pop		bc
			ld		a,b
			srl		a
			srl		a
			srl		a
			srl		a
			add		a,$90
			daa
			adc		a,$40
			daa
			call	txt_output
			ld		a,b
			and		$0f
			add		a,$90
			daa
			adc		a,$40
			daa
			call	txt_output
			ld		a,10
			call	txt_output
			ld		a,13
			call	txt_output
			ret
disphex:	ld		b,a
			srl		a
			srl		a
			srl		a
			srl		a
			add		a,$90
			daa
			adc		a,$40
			daa
			call	txt_output
			ld		a,b
			and		$0f
			add		a,$90
			daa
			adc		a,$40
			daa
			call	txt_output
			ld		a,32
			call	txt_output
			ret

			;
			; Get input text line.
			;
			; in
			; hl = dest buf
			; return
			; bc = out size
get_textinput:		
			ld	bc,0
			call	txt_cur_on	
inputloop:
			
re:			call	mc_wait_flyback
			call	km_read_char
			jr		nc,re

			cp		$7F
			jr		nz, not_delkey
			ld		a,c
			cp		0
			jr		z, inputloop
			push	hl
			push	bc
			call	txt_get_cursor
			dec		h
			push	hl
			call	txt_set_cursor
			ld		a,32
			call	txt_output
			pop		hl
			call	txt_set_cursor
			pop		bc
			pop		hl
			dec		hl
			dec		bc
			jr		inputloop
not_delkey:	
			cp		13
			jr		z, terminate
			cp		$FC
			ret		z
			cp		32
			jr		c, inputloop
			cp		$7e
			jr		nc, inputloop
			ld		(hl),a
			inc		hl
			inc		bc
			push	hl
			push	bc
			call	txt_output
			call	txt_get_cursor
			;push	hl
			;ld		a,32
			;call	txt_output
			;pop	hl
			call	txt_set_cursor
			pop		bc
			pop		hl
			jp		inputloop
terminate:	ld		(hl),0
			ret

; ------------------------------------------------------------------------------
			
			;
			; Get input text line, accept only neric and .
			;
			; in
			; hl = dest buf
			; return
			; bc = out size
get_textinput_ip:		
			ld	bc,0
			call	txt_cur_on	
inputloop2:
			
re2:		call	mc_wait_flyback
			call	km_read_char
			jr		nc,re2

			cp		$7F
			jr		nz, not_delkey2
			ld		a,c
			cp		0
			jr		z, inputloop2
			push	hl
			push	bc
			call	txt_get_cursor
			dec	h
			push	hl
			call	txt_set_cursor
			ld		a,32
			call	txt_output
			pop	hl
			call	txt_set_cursor
			pop		bc
			pop		hl
			dec		hl
			dec		bc
			jr		inputloop2
not_delkey2:	
			cp		13
			jr		z, enterkey2
			cp		$FC
			ret		z
			cp		46				; less than '.'
			jr		c, inputloop2
			cp		59				; bigger than ':' ?
			jr		nc, inputloop2
			
			
			ld		(hl),a
			inc		hl
			inc		bc
			push	hl
			push	bc
			call	txt_output
			call	txt_get_cursor
			;push	hl
			;ld		a,32
			;call	txt_output
			;pop	hl
			call	txt_set_cursor
			pop		bc
			pop		hl
			jp		inputloop2
enterkey2:	ld		(hl),0
			ret
			
			
crlf:		ld		a,10
			call	txt_output
			ld		a,13
			jp		txt_output

			
			; HL = point to IP addr
			
disp_ip:	ld		bc,3
			add		hl,bc
			ld		b,3
disp_ip_loop:
			push	hl
			push	bc
			call	dispdec
			pop		bc
			pop		hl
			dec		hl
			ld		a,$2e
			call	txt_output
			djnz	disp_ip_loop
			
			jp		dispdec	; last digit
			
			
dispdec:	ld		e,0
			ld		a,(hl)
			ld		l,a
			ld		h,0
			ld		bc,-100
			call	n1
			cp		'0'
			jr		nz,notlead0
			ld		e,1
notlead0:	call	nz,txt_output
			ld		c,-10
			call	n1
			cp		'0'
			jr		z, lead0_2
			call	txt_output
lead0_2_cont:	
			ld		c,b
			call	n1
			jp		txt_output
			
n1:			ld		a,'0'-1
n2:			inc		a
			add		hl,bc
			jr		c,n2
			sbc		hl,bc
			ret
lead0_2:
			ld		d,a
			xor		a
			cp		e
			ld		a,d
			call	z,txt_output
			jr		lead0_2_cont
						
			; ix = points to :portnumber
			; hl = return 16 bit number
			
port2dec:
count_digits:
			inc		ix
			ld		a,(ix)
			cp		0
			jr		nz,count_digits
			dec		ix
			ld		a,(ix)
			cp		$3A
			ret		z
			sub		48
			ld		l,a			; *1
			ld		h,0
			
			
			dec		ix
			ld		a,(ix)
			cp		$3A
			ret		z
			sub		48

			push	hl
			ld  	e,a
			ld		d,0
			ld 		bc,10
			call	mul16		; *10
			pop		de
			add		hl,de		
			dec		ix
			ld		a,(ix)
			cp		$3A
			ret		z
			sub		48
			
			push	hl
			ld  	e,a
			ld		d,0
			ld 		bc,100
			call	mul16		; *100
			pop		de
			add		hl,de		
			dec		ix
			ld		a,(ix)
			cp		$3A
			ret		z
			sub		48
			
			push	hl
			ld  	e,a
			ld		d,0
			ld 		bc,1000
			call	mul16		; *1000
			pop		de
			add		hl,de		
			dec		ix
			ld		a,(ix)
			cp		$3A
			ret		z
			sub		48
			
			push	hl
			ld  	e,a
			ld		d,0
			ld 		bc,10000
			call	mul16		; *10000
			pop		de
			add		hl,de		
			ret
						
ascii2dec:	ld		d,0
loop2e:		ld		a,(hl)
			cp		0
			jr		z,found2e
			cp		$3A		; ':' port seperator ?
 			jr		z,found2e
			
			cp		$2e
			jr		z,found2e
			; convert to decimal
			cp		$41	; a ?
			jr		nc,less_than_a
			sub		$30	; - '0'
			jr		next_dec
less_than_a:	
			sub		$37	; - ('A'-10)
next_dec:		
			ld		(hl),a
			inc		hl
			inc		d
			dec		bc
			xor		a
			cp		c
			ret		z
			jr		loop2e
found2e:
			push	hl
			call	dec2bin
			pop		hl
			inc		hl
			ret
dec2bin:	dec		hl
			ld		a,(hl)
			dec		hl
			dec		d
			ret		z
			ld		b,(hl)
			inc		b
			dec		b
			jr		z,skipmul10
mul10:		add		a,10
			djnz	mul10
skipmul10:	dec		d
			ret		z
			dec		hl
			ld		b,(hl)
			inc		b
			dec		b
			ret		z
mul100:		add		a,100
			djnz	mul100
			ret
			
			; BC*DE

mul16:		ld	hl,0
			ld	a,16
mul16Loop:	add	hl,hl
			rl	e
			rl	d
			jp	nc,nomul16
			add	hl,bc
			jp	nc,nomul16
			inc	de
nomul16:
			dec	a
			jp	nz,mul16Loop
			ret
escape_val:	cp		2
			jr		nz, has_value
			xor		a
			ret
has_value:	ld		d,0
			sub		2
			ld		e,a
dec_loop2:
			ld		a,(hl)
			cp		$41	; a ?
			jr		nc,less_than_a2
			sub		$30	; - '0'
			jr		next_dec2
less_than_a2:	
			sub		$37	; - ('A'-10)
next_dec2:	inc	hl
			cp	0
			jr	nz, do_mul
			dec	e
			jr	nz, dec_loop2
			ld	a,d
			ret
do_mul:		ld	b,a
			ld	a,e
			cp	3
			jr	nz, not_3digits
			xor	a
a_mul100:		add	a,100
			djnz	a_mul100
			ld	d,a
			dec	e
			jr	nz, dec_loop2
			ret
not_3digits:		cp	2
			jr	nz, not_2digits
			xor	a
a_mul10:		add	a,10
			djnz	a_mul10
			add	a,d			
			ld	d,a
			dec	e
			jr	nz, dec_loop2
			ret
			ld	a,d
not_2digits:	ld	a,b
			add	a,d
			ret			
			
disp_port:
			ld		bc,-10000
			call	n16_1
			cp		48
			jr		nz,not16_lead0
			ld		bc,-1000
			call	n16_1
			cp		48
			jr		nz,not16_lead1
			ld		bc,-100
			call	n16_1
			cp		48
			jr		nz,not16_lead2
			ld		bc,-10
			call	n16_1
			cp		48
			jr		nz, not16_lead3
			jr		not16_lead4
	
not16_lead0:
			call	txt_output
			ld		bc,-1000
			call	n16_1
not16_lead1:
			call	txt_output
			ld		bc,-100
			call	n16_1
not16_lead2:
			call	txt_output
			ld		c,-10
			call	n16_1
not16_lead3:
			call	txt_output
not16_lead4:
			ld		c,b
			call	n16_1
			call	txt_output
			ret
n16_1:
			ld		a,'0'-1
n16_2:
			inc		a
			add		hl,bc
			jr		c,n16_2
			sbc		hl,bc

			;ld		(de),a
			;inc	de
			
			ret			
			
msgconnclosed:	db	10,13,"Remote closed connection....",10,13,0
msgsenderror:	db	10,13,"ERROR: ",0
msgconnect:		db	10,13,"Connected.",10,13,0
msgserverip:	db	10,13,"Input server name or IP (:PORT or default to 23):",10,13,0
msgnom4:		db	"No M4 board found, bad luck :/",10,13,0
msgfoundm4:		db	"Found M4 Board v",0
msgverfail:		db	", you need v1.1.0 or higher.",10,13,0
msgok:			db  ", OK.",10,13,0
msgconnecting:	db	10,13, "Connecting to IP ",0
msgport:		db  " port ",0
msgresolve:		db	10,13, "Resolving: ",0
msgfail:		db 	", failed!", 10, 13, 0
msgtitle:		db	"CPC telnet client v1.0.1 beta / Duke 2018!5555",0
msgtitle2:		db  "=========================================",0
msguserabort:	db	10,13,"User aborted (ESC)", 10, 13,0
cmdsocket:		db	5
				dw	C_NETSOCKET
				db	$0,$0,$6		; domain, type, protocol (TCP/IP)

cmdconnect:		db	9	
				dw	C_NETCONNECT
csocket:		db	0
ip_addr:		db	0,0,0,0		; ip addr
port:			dw	23		; port

cmdsend:		db	0			; we can ignore value of this byte (part of early design)	
				dw	C_NETSEND
sendsock:		db	0
sendsize:		dw	0			; size
sendtext:		ds	255
			
cmdclose:		db	$03
				dw	C_NETCLOSE
clsocket:		db	$0

cmdlookup:		db	16
				dw	C_NETHOSTIP
lookup_name:	ds	128

cmdrecv:		db	5
				dw	C_NETRECV	; recv
rsocket:		db	$0			; socket
rsize:			dw	2048		; size
			
m4_rom_name:	db "M4 BOAR",$C4		; D | $80
m4_rom_num:	db	$FF
curPos:			dw	0
isEscapeCode:	db	0
EscapeCount:	db	0
EscapeBuf:		ds	255
buf:			ds	255	



NetReadDataBuf: ds  2048


; ---------------------------------------------------------------------------    
RSX_CMD_NET_LOOKUP_IP
	push hl
	push bc
;ld hl,M4_CMD_NET_LOOKUP_IP
;jp 	RSX_JUMPTORAM_AND_EXIT	; call $1b: pop bc : pop hl : ret	

	ld hl,puffermem
	ld (hl),$95
	push de
	call KL_FIND_COMMAND		; OUT: HL=Adress, C=ROM-Number
	pop de
	jr 	RSX_JUMPTOROM_AND_EXIT	; call $1b: pop bc : pop hl : ret

; ---------------------------
RSX_CMD_SOCKET
	push hl
	push bc
;ld hl,M4_CMD_SOCKET
;jr 	RSX_JUMPTORAM_AND_EXIT	; call $1b: pop bc : pop hl : ret	

	ld hl,puffermem
	ld (hl),$91
	call KL_FIND_COMMAND		; OUT: HL=Adress, C=ROM-Number
	jr 	RSX_JUMPTOROM_AND_EXIT	; call $1b: pop bc : pop hl : ret
; ---------------------------

RSX_CMD_CONNECT
	push hl
	push bc
;ld hl,M4_CMD_CONNECT
;jr 	RSX_JUMPTORAM_AND_EXIT	; call $1b: pop bc : pop hl : ret	
	
	push af
	push de
	ld hl,puffermem
	ld (hl),$92
	call KL_FIND_COMMAND		; OUT: HL=Adress, C=ROM-Number
	pop de
	pop af
	jr 	RSX_JUMPTOROM_AND_EXIT	; call $1b: pop bc : pop hl : ret
; ---------------------------
	
RSX_CMD_GET_SOCKET_STATE
	push hl
	push bc
;ld hl,M4_GET_SOCKET_STATE
;jr 	RSX_JUMPTORAM_AND_EXIT	; call $1b: pop bc : pop hl : ret	
	push af
	ld hl,puffermem
	ld (hl),$93
	call KL_FIND_COMMAND		; OUT: HL=Adress, C=ROM-Number
	pop af
	
	jr 	RSX_JUMPTOROM_AND_EXIT	; call $1b: pop bc : pop hl : ret

; ---------------------------
RSX_CMD_NET_SEND_CUSTOM_DATA	; IN IX=Pointer to Data ($00:Length, $01:Socketnumber, $02-$9999:Data)   OUT   nothing
	push hl
	push bc
;ld hl,M4_CMD_NET_SEND_CUSTOM_DATA
;jr 	RSX_JUMPTORAM_AND_EXIT	; call $1b: pop bc : pop hl : ret		
	push ix
	ld hl,puffermem
	ld (hl),$96
	call KL_FIND_COMMAND		; OUT: HL=Adress, C=ROM-Number
	pop ix
	jr 	RSX_JUMPTOROM_AND_EXIT	; call $1b: pop bc : pop hl : ret
	
; ---------------------------

RSX_CMD_CLOSE_CONNECTION; IN A= Socket	


	push hl
	push bc
;ld hl,M4_CMD_CLOSE_CONNECTION
;jr 	RSX_JUMPTORAM_AND_EXIT	; call $1b: pop bc : pop hl : ret		
	push ix
	ld hl,puffermem
	ld (hl),$97
	call KL_FIND_COMMAND		; OUT: HL=Adress, C=ROM-Number
	pop ix
	jr 	RSX_JUMPTOROM_AND_EXIT	; call $1b: pop bc : pop hl : ret
	
	
; ---------------------------
	
RSX_CMD_NET_RECEIVE_DATA
	push hl
	push bc
;ld hl,M4_CMD_NET_RECEIVE_DATA
;jr 	RSX_JUMPTORAM_AND_EXIT	; call $1b: pop bc : pop hl : ret		
	
	push af
	push de
	push ix
	ld hl,puffermem
	ld (hl),$94
	call KL_FIND_COMMAND		; OUT: HL=Adress, C=ROM-Number
	pop ix
	pop de
	pop af




RSX_JUMPTOROM_AND_EXIT:	
	call $1b
	
	pop bc
	pop hl
	ret


;RSX_JUMPTORAM_AND_EXIT
;	call $1e	; jp HL
;	pop bc
;	pop hl
;	ret
	


; ---------------------------------------------------------------------------    


