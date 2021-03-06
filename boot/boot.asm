org 07c00h
    jmp short LABEL_START
    nop
%include "fat12.inc"
%include "loader.inc"
BaseOfStack equ 07c00h


LABEL_START:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, BaseOfStack

    call Clear
    mov dh, 0
    call DisplayString

    ; reset floppy
    xor ah, ah
    xor dl, dl
    int 13h

    ; Find loader.bin
LoopNum dw RootDirSectors
SectorNo dw RootDirNo
LABEL_LOOP_EACH_SECTOR:
    cmp word[LoopNum], 0
    jz LABEL_NO_LOADER
    dec word[LoopNum]

    mov ax, BaseOfLoader
    mov es, ax
    mov bx, OffsetOfLoader
    mov cl, 1
    mov ax, [SectorNo]
    call ReadSector

    ; Deal with a sector
    FileName db 'LOADER  BIN'
    mov si, FileName
    mov di, OffsetOfLoader
    mov dx, 10h
    ; Deal with each item in root sector
LABEL_DEAL_EACH_ITEM:
    cmp dx, 0
    jz LABEL_LOOP_NEXT
    dec dx
    mov cx, 11
LABEL_CMP_FILENAME:  ; Begin to compare filename
    cmp cx, 0
    jz LABEL_FILENAME_FOUND
    dec cx
    cld
    lodsb; al<-ds:si
    cmp al, byte[es:di]
    jz LABEL_GO_ON
    jmp LABEL_DIFF
LABEL_GO_ON:
    inc di
    jmp LABEL_CMP_FILENAME  ; Continue to compare next byte
LABEL_DIFF: ; Filename wrong, Continue to read next dir entry(32 bytes)
    and di, 0ffe0h
    add di, 20h ; 32 bytes
    mov si, FileName
    jmp LABEL_DEAL_EACH_ITEM

LABEL_LOOP_NEXT:
    inc word[SectorNo]
    jmp LABEL_LOOP_EACH_SECTOR

LABEL_NO_LOADER:
    mov dh, 2
    call DisplayString
    jmp $

; Find loader.bin already
LABEL_FILENAME_FOUND:
    mov dh, 3
    call DisplayString

    and di, 0ffe0h
    add di, 01ah
    mov cx, word[es:di]
    push cx; 

    mov ax, BaseOfLoader
    mov es, ax
    mov bx, OffsetOfLoader

    mov ax, DeltaSectorNo
    add ax, RootDirSectors
    add ax, cx

LABEL_LOADING:
    mov cl, 1
    call ReadSector
    pop ax
    call GetFATEntry
    cmp ax, 0ff8h;end
    jnb LABEL_LOADED;ax>=0xff8
    push ax
    mov dx, RootDirSectors
    add ax, dx
    add ax, DeltaSectorNo
    add bx, [BPB_BytsPerSec]
    jmp LABEL_LOADING

LABEL_LOADED:
    jmp BaseOfLoader:OffsetOfLoader

;---------------------------
; Function DispalyString
; ES:BP Address of string
; CX Length of string
; DH Line
MessageLength equ 9
BootMessage: db "Booting  "
Message1 db "Ready B  "
Message2 db "No Loader"
Message3 db "Find  L  "

DisplayString:
    push es
    mov ax, MessageLength
    mul dh
    add ax, BootMessage
    mov bp, ax
    mov ax, ds
    mov es, ax
    mov cx, MessageLength
    mov ax, 01301h
    mov bx, 0007h
	mov dl, 0
    int 10h
    pop es
    ret

;------------------------------
; Function Clear
; Just clear context in screen
Clear:
    mov ax, 0600h
    mov bx, 0700h
    mov cx, 0
    mov dx, 0184fh
    int 10h
    ret
;--------------------------
; Function ReadSector
; From ax, read cl sectors to es:bx
ReadSector:
    push bp
    mov bp, sp
    sub esp, 2;2 bytes to store cl
    mov byte[bp-2], cl

    mov dl, [BPB_SecPerTrk]
    div dl; Reminder is in ah
    inc ah
    mov cl, ah; Sector
    mov dh, al
    and dh, 1; Head
    shr al, 1
    mov ch, al; Cylinder
    mov dl, [BS_DrvNum]; Driver

GO_ON_READING:
    mov ah, 2
    mov al, byte[bp-2]
    int 13h
    jc GO_ON_READING

    add esp, 2
    pop bp
    ret

;----------------------
; Function GetFATEntry
; ax is pre-FAT number
Odd db 0
GetFATEntry:
    push es
    push bx
    push ax

    mov ax, BaseOfLoader
    sub ax, 0100h
    mov es, ax
    pop ax
    mov byte[Odd], 0 
    mov bx, 3
    mul bx; dx:ax = ax*3
    mov bx, 2
    div bx; reminder is in dx, quotient is in ax
    cmp dx, 0
    jz LABEL_EVEN
    mov byte[Odd], 1

LABEL_EVEN:
    xor dx, dx
    mov bx, [BPB_BytsPerSec]
    div bx;dx:ax/BPB_BytsPerSec
          ;ax sector offset
          ;dx FATEnt offset in that sector
    push dx;3 values in stack now
    mov bx, 0
    add ax, FAT1SectorNo
    mov cl, 2
    call ReadSector

    pop dx
    add bx, dx
    mov ax, [es:bx];2 bytes
    cmp byte[Odd], 1
    jnz LABEL_EVEN2
    shr ax, 4
LABEL_EVEN2:
    and ax, 0fffh
LABEL_FAT_OK:
    pop bx
    pop es
    ret



times 510 - ($-$$) db 0
dw 0xaa55
