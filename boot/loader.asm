org 0100h

jmp LABEL_START
%include "fat12.inc"
%include "loader.inc"

; Something related to protect mode
%include "pm.inc"
; GDT
LABEL_GDT:  Descriptor 0, 0, 0
LABEL_DESC_FLAT_C:  Descriptor 0, 0fffffh, DA_CR|DA_32|DA_LIMIT_4K; 0-4G
LABEL_DESC_FLAT_RW: Descriptor 0, 0fffffh, DA_DRW|DA_32|DA_LIMIT_4K; 0-4G
LABEL_DESC_VIDEO:   Descriptor 0b8000h, 0ffffh, DA_DRW|DA_DPL3;

GdtLen equ $ - LABEL_GDT
GdtPtr dw GdtLen - 1; boundary
    dd BaseOfLoader*10h + LABEL_GDT
; Selector
SelectorFlatC equ LABEL_DESC_FLAT_C - LABEL_GDT
SelectorFlatRW equ LABEL_DESC_FLAT_RW - LABEL_GDT
SelectorVideo equ LABEL_DESC_VIDEO - LABEL_GDT + SA_RPL3

BaseOfStack equ 0100h

PageDirBase equ 100000h ;
PageTblBase equ 101000h ;

LABEL_START:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, BaseOfStack

    ;call Clear
    mov dh, 0
    call DisplayString

    ; Get information of memory
    mov ebx, 0          ; ebx = 
    mov di, _MemChkBuf      ; es:di (ARDS)
.MemChkLoop:
    mov eax, 0E820h     ; eax = 0000E820h
    mov ecx, 20         ; ecx = size of ARDS
    mov edx, 0534D4150h     ; edx = 'SMAP'
    int 15h         ; int 15h, this call returns a memory map of all installed RAM
    jc  .MemChkFail
    add di, 20
    inc dword [_dwMCRNumber]    ; dwMCRNumber = ARDS number
    cmp ebx, 0
    jne .MemChkLoop
    jmp .MemChkOK
.MemChkFail:
    mov dword [_dwMCRNumber], 0
.MemChkOK:


    ; reset floppy
    xor ah, ah
    xor dl, dl
    int 13h

    ; Find kernel.bin
LoopNum dw RootDirSectors
SectorNo dw RootDirNo
LABEL_LOOP_EACH_SECTOR:
    cmp word[LoopNum], 0
    jz LABEL_NO_KERNEL
    dec word[LoopNum]

    mov ax, BaseOfKernel
    mov es, ax
    mov bx, OffsetOfKernel
    mov cl, 1
    mov ax, [SectorNo]
    call ReadSector

    ; Deal with a sector
    FileName db 'KERNEL  BIN'
    mov si, FileName
    mov di, OffsetOfKernel
    mov dx, 10h
    ; Deal with each item in root sector
LABEL_DEAL_EACH_ITEM:
    cmp dx, 0
    jz LABEL_LOOP_NEXT
    dec dx
    mov cx, 11
LABEL_CMP_FILENAME:
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
    jmp LABEL_CMP_FILENAME
LABEL_DIFF:
    and di, 0ffe0h
    add di, 20h
    mov si, FileName
    jmp LABEL_DEAL_EACH_ITEM

LABEL_LOOP_NEXT:
    inc word[SectorNo]
    jmp LABEL_LOOP_EACH_SECTOR

LABEL_NO_KERNEL:
    mov dh, 2
    call DisplayString
    jmp $

; Find kernel.bin already
LABEL_FILENAME_FOUND:
    mov dh, 3
    call DisplayString

    and di, 0ffe0h
    add di, 01ah
    mov cx, word[es:di]
    push cx; 

    mov ax, BaseOfKernel
    mov es, ax
    mov bx, OffsetOfKernel

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
    call KillMotor
    mov dh, 1
    call DisplayString

    lgdt [GdtPtr]
    cli

    in al, 92h
    or al, 00000010b
    out 92h, al

    mov eax, cr0
    or eax, 1
    mov cr0, eax ; PE flag of cr0 set, enabe segment protection

    jmp dword SelectorFlatC:(BaseOfLoaderPhyAddr+LABEL_PM_START)

;---------------------------
; Function DispalyString
; ES:BP Address of string
; CX Length of string
; DH Line
MessageLength equ 9
LoadMessage: db "Loading K"
Message1 db "Ready K  "
Message2 db "No Kernel"
Message3 db "Find K   "

DisplayString:
    push es
    mov ax, MessageLength
    mul dh
    add ax, LoadMessage
    mov bp, ax
    mov ax, ds
    mov es, ax
    mov cx, MessageLength
    mov ax, 01301h
    mov bx, 0007h
	mov dl, 12
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

    mov ax, BaseOfKernel
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
;--------------------
; Function KillMotor
KillMotor:
    push    dx
    mov dx, 03F2h
    mov al, 0
    out dx, al
    pop dx
    ret


[SECTION .s32]
ALIGN 32
[BITS 32]
LABEL_PM_START:
    mov ax, SelectorVideo
    mov gs, ax

    mov ax, SelectorFlatRW
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov ss, ax
    mov esp, TopOfStack

    push    szMemChkTitle
    call    DisplayStringPM
    add esp, 4

    call DisplayMemInfo
    call SetupPaging

    mov ah, 0Fh             ; 0000: black bg    1111: white word
    mov al, 'P'
    mov [gs:((80 * 0 + 39) * 2)], ax    ; line 0 column 39

    call InitKernel
    ;jmp    $
    jmp SelectorFlatC:KernelEntryPointPhyAddr ; Enter kernel

%include "lib.inc"

;-----------------------
; Function DisplayMemInfo
DisplayMemInfo:
    push esi
    push edi
    push ecx
    
    mov esi, MemChkBuf
    mov ecx, [dwMCRNumber]
.loop:
    mov edx, 5
    mov edi, ARDStruct
.1:
    push dword[esi]
    call DisplayInt
    pop eax
    stosd
    add esi, 4
    dec edx
    cmp edx, 0
    jnz .1
    call DisplayReturn
    cmp dword[dwType], 1
    jne .2
    mov eax, [dwBaseAddrLow];
    add eax, [dwLengthLow];
    cmp eax, [dwMemSize]  ;    if(BaseAddrLow + LengthLow > MemSize)
    jb  .2        ;
    mov [dwMemSize], eax  ;    MemSize = BaseAddrLow + LengthLow;
.2:               ;  }
    loop    .loop         ;}
                  ;
    call    DisplayReturn     ;printf("\n");
    push    szRAMSize     ;
    call    DisplayStringPM       ;printf("RAM size:");
    add esp, 4        ;
                  ;
    push    dword [dwMemSize] ;
    call    DisplayInt        ;DispInt(MemSize);
    add esp, 4        ;

    pop ecx
    pop edi
    pop esi
    ret

;-------------------------
; Function SetupPaging
SetupPaging:
    xor edx, edx
    mov eax, [dwMemSize]
    mov ebx, 400000h    
    div ebx
    mov ecx, eax    
    test    edx, edx
    jz  .no_remainder
    inc ecx     
.no_remainder:
    push    ecx     

    

    ; init page dir table
    mov ax, SelectorFlatRW
    mov es, ax
    mov edi, PageDirBase    
    xor eax, eax
    mov eax, PageTblBase | PG_P  | PG_USU | PG_RWW
.1:
    stosd
    add eax, 4096       
    loop    .1

	;init page table
    pop eax         
    mov ebx, 1024       
    mul ebx
    mov ecx, eax        
    mov edi, PageTblBase    
    xor eax, eax
    mov eax, PG_P  | PG_USU | PG_RWW
.2:
    stosd
    add eax, 4096       ; page manage 4K space
    loop    .2

    mov eax, PageDirBase
    mov cr3, eax
    mov eax, cr0
    or  eax, 80000000h
    mov cr0, eax
    jmp short .3
.3:
    nop

    ret

;------------------------
; Function InitKernel
InitKernel:
        xor   esi, esi
        mov   cx, word [BaseOfKernelFilePhyAddr+2Ch]; Number of program header
        movzx ecx, cx                               ;/
        mov   esi, [BaseOfKernelFilePhyAddr + 1Ch]  ; Offset of Program header in elf file
        add   esi, BaseOfKernelFilePhyAddr; Address of program header in memory
.Begin:
        mov   eax, [esi + 0]
        cmp   eax, 0                      ; type
        jz    .NoAction
        push  dword [esi + 010h]    ;size
        mov   eax, [esi + 04h]            ; 
        add   eax, BaseOfKernelFilePhyAddr; 
        push  eax           ;src  
        push  dword [esi + 08h]     ;dst 
        call  Memcpy                     
        add   esp, 12                     
.NoAction:
        add   esi, 020h                   ; esi += size of program header
        dec   ecx
        jnz   .Begin

        ret

[SECTION .data1]
ALIGN 32

LABEL_DATA:
; Symbols in real mode
; Const string
_szMemChkTitle: db "BaseAddrL BaseAddrH LengthLow LengthHigh   Type", 0Ah, 0
_szRAMSize: db "RAM size:", 0
_szReturn:  db 0Ah, 0
; variable
_dwMCRNumber:   dd 0    ; Memory Check Result
_dwDispPos: dd (80 * 6 + 0) * 2 
_dwMemSize: dd 0
_ARDStruct: ; Address Range Descriptor Structure
  _dwBaseAddrLow:       dd  0
  _dwBaseAddrHigh:      dd  0
  _dwLengthLow:         dd  0
  _dwLengthHigh:        dd  0
  _dwType:          dd  0
_MemChkBuf: times   256 db  0
; Symbol in protect mode
szMemChkTitle       equ BaseOfLoaderPhyAddr + _szMemChkTitle
szRAMSize       equ BaseOfLoaderPhyAddr + _szRAMSize
szReturn        equ BaseOfLoaderPhyAddr + _szReturn
dwDispPos       equ BaseOfLoaderPhyAddr + _dwDispPos
dwMemSize       equ BaseOfLoaderPhyAddr + _dwMemSize
dwMCRNumber     equ BaseOfLoaderPhyAddr + _dwMCRNumber
ARDStruct       equ BaseOfLoaderPhyAddr + _ARDStruct
    dwBaseAddrLow   equ BaseOfLoaderPhyAddr + _dwBaseAddrLow
    dwBaseAddrHigh  equ BaseOfLoaderPhyAddr + _dwBaseAddrHigh
    dwLengthLow equ BaseOfLoaderPhyAddr + _dwLengthLow
    dwLengthHigh    equ BaseOfLoaderPhyAddr + _dwLengthHigh
    dwType      equ BaseOfLoaderPhyAddr + _dwType
MemChkBuf       equ BaseOfLoaderPhyAddr + _MemChkBuf


StackSpace: times 1024 db 0
TopOfStack equ BaseOfLoaderPhyAddr + $
