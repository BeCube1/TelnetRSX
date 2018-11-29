include "Version.h"

KL_FIND_COMMAND                 EQU &BCD4
TXT_OUTPUT                      EQU &BB5A

	org #C000
; ---------------------------------------------------------------------------
; ROM Header
rom_type
    DEFB 1                          ; Background ROM

rom_version
    DEFB 0,1,2
; ---------------------------------------------------------------------------
rsx_names
    DEFW rsx_name_table

; ---------------------------------------------------------------------------
    JP   init_rom

; ---------------------------------------------------------------------------
extra_rsxs
	jp 	M4_CMD_SOCKET		; IN  ---     OUT: Return data[0] = socket number or 0xFF (error). Only TCP protocol for now.
	jp	M4_CMD_CONNECT		; IN   A=Socket, DE=Pointer to IP-Addr      Z-Flag indicates Error		
	jp	M4_GET_SOCKET_STATE	; IN A= Socket,   OUT   (0 ==IDLE (OK), 1 == connect in progress, 2 == send in progress)			       DE=Data   (from IX+2 / IX+3)	
	jp  M4_CMD_NET_RECEIVE_DATA; IN A= Socket, DE=Size IX=Pointer to Data   OUT   A=Buffer State, BC=Size, Filled (DE)-Memory
	jp	M4_CMD_NET_LOOKUP_IP ; IN DE=Adress of IP-Adress, IX=Adress of the Host-String			OUT=Filled (BC) with IP-Adress
	jp	M4_CMD_NET_SEND_CUSTOM_DATA	; IN IX=Pointer to Data (#00:Length, #01:Socketnumber, #02-#9999:Data)   OUT   nothing
	jp	M4_CMD_CLOSE_CONNECTION; IN A= Socket
	
rsx_name_table
    DEFB 'NET RSX',' ' + $80
    defb #91	;	SOCK
    defb #92	;	CONNECT
    defb #93	;	GET_SOCK_STATE
	defb #94	;	NET_RECEIVE_DATA
	defb #95	;	NET_LOOKUP_IP
	defb #96	;	NET_SEND_CUSTOM_DATA
	defb #97	;	CMD_CLOSE_CONNECTION
    DEFB 0                          ; End RSX name table

; ---------------------------------------------------------------------------    
init_rom	
	push ix
	push iy
	push de
	push hl
	
	ld hl,versionstring
	call PrintString
	
	pop hl
	pop de
	pop iy
	pop ix
	SCF ; Set_C_Flag
	ret

PrintString:
	ld a,(hl)
	cp 0
	ret z
	call TXT_OUTPUT
	inc hl
	jr PrintString


; ---------------------------------------------------------------------------    
	include "M4Driver.asm"
; ---------------------------------------------------------------------------    
	
versionstring: defm " Net RSX "
				Version
				
			   defb "b",#0d,#0a,#0a,0

EndROM
; ---------------------------------------------------------------------------
 ;Padding the rom with 0s until the checksum byte
 ds #FFFF-EndROM,#00   

;;;	ORG  #FFFF
;;;    DEFB 0
