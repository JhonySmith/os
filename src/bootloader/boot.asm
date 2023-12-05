org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

;
; FAT12 заголовок
;
jmp short start 
nop

bpb_oem_ident:           		db 'MSWIN4.1'			; 8 bytes
bpb_bytes_per_sector:    		dw 512
bpb_sectors_per_cluster: 		db 1
bpb_reserved_sectors:   		dw 1
bpb_fat_count: 							db 2
bpb_dir_entries_count:			dw 0E0h
bpb_total_sectors:					dw 2880						; 2880 * 512 = 1.44MB
bpb_media_descriptor_type:	db 0F0h						; F0 = 3.5" floppy disk
bpb_sectors_per_fat:				dw 9							; 9 sectors/fat
bpb_sectors_per_track:			dw 18
bpb_heads:									dw 2
bpb_hidden_sectors:					dd 0
bpb_large_sector_count:			dd 0

; Расширенная загрузочная запись
ebr_drive_number: 					db 0
														db 0
ebr_signature:							db 29h
ebr_volume_id:							db 12h, 34h, 56h, 78h
ebr_volume_label: 					db '           '
ebr_system_id:							db 'FAT12   '


;
;	Дальше код
;

start:
	jmp main

;
; Вывод строки на экран 
; Параметры:
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
	; установка сегментов данных
	mov ax, 0
	mov dx, ax
	mov es, ax

	; установка стека
	mov ss, ax
	mov sp, 0x7C00

	; read something from floppy disk
	; BIOS should set DL to drive number

	mov [ebr_drive_number], dl

	mov ax, 1
	mov cl, 1
	mov bx, 0x07E00										; data should be after the bootloader
	call disk_read

	; вывод сообщения
	mov si, msg_hello
	call puts
	
	cli
	hlt

floppy_error:
	mov si, msg_read_failed
	call puts
	jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah, 0
	int 16h														; wait for keypress
	jmp 0FFFFh:0											; jump to beginning of BIOS, should reboot

.halt:
	cli
	hlt

;
;	Преобразование LBA адреса в CHS адрес
;	Параметры:
;		- ax: LBA адрес
;	return:
;		- cx [bits 0-5]: sector number
;		- cx [bits 6-15]: cylinder
;		- dh: head
;

lba_to_chs:

	push ax
	push dx

	xor dx, dx													; dx = 0
	div word [bpb_sectors_per_track]		;	ax = LBA / SectorsPerTrack
																			; dx = LBA % SectorsPerTrack
	
	inc dx															; dx = (LBA % SectorsPerTrack + 1) = sector
	mov cx, dx 													; cx = sector

	xor dx, dx													; dx = 0
	div word [bpb_heads]								; ax = (LBA / SectorsPerTrack) / Heads = cylinder
																			; dx = (LBA / SectorsPerTrack) % Heads = head
	mov dh, dl													; dx = head
	mov ch, al													; ch = cylinder (lower 8 bits)
	shl ah, 6
	or cl, ah														; put upper 2 bits of cylinder in CL

	pop ax
	mov dl, al
	pop ax
	ret

;
;	Reads sectors from a disk
;	Parameters:
;		- ax: LBA address
;		- cl: number of sectors tp read (up to 128)
;		- ex:bx: memory address where to store read data
;

disk_read:
	push ax
	push bx
	push cx
	push dx
	push di

	push cx															; save CL (number of sectors to read)
	call lba_to_chs											; compute CHS
	pop ax															; AL = number of sectors

	mov ah, 02h
	mov di, 3														; retry count

.retry:
	pusha																; save all registers
	stc																	; set carry flag, some BIOS'es don't set it
	int 13h															; carry flag cleared = success
	jnc	.done
	
	; failed
	popa
	call disk_reset

	dec di
	test di, di
	jnz .retry

.fail:
	jmp floppy_error

.done:
	popa

	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret

;
;	Reset disk controller
;	Parameters:
;		dl: drive number
;
disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret

msg_hello: 						db 'Hello world!', ENDL, 0
msg_read_failed: 			db 'Read from disk failed!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h