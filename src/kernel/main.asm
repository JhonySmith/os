org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

#
# FAT12 header
#
jmp short start 
nop

bdb_oem:                 	db 'MSWIN4.1' ; 8 bytes
bdb_bytes_per_sector:    	dw 512
bdb_sectors_per_cluster: 	db 1
bdb_reserverd_sectors:   	dw 1
bdb_fat_count: 						db 2


start:
	jmp main

;
; Prints a string to the screen 
; Params:
; - ds:si points to string
;

puts:
	push si
	push ax

.loop:
	lodsb
	or al, al
	jz .done

	mov ah, 0x0e
	mov bh, 0
	
	int 0x10
	
	jmp .loop

.done:
	pop ax
	pop si
	ret

main:
	; setup data segments
	mov ax, 0
	mov dx, ax
	mov es, ax

	; setup stack
	mov ss, ax
	mov sp, 0x7C00

	; print message
	mov si, msg_hello
	call puts
	
	hlt

.halt:
	jmp .halt

msg_hello: db 'Hello world!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h