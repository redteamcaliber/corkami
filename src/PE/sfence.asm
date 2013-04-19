; a driver to test sfence effect

; thanks to Carsten Willems

; Ange Albertini, BSD LICENCE 2013

%include 'consts.inc'

IMAGEBASE EQU 10000H
org IMAGEBASE
bits 32

SECTIONALIGN equ 200h
FILEALIGN equ 200h

istruc IMAGE_DOS_HEADER
    at IMAGE_DOS_HEADER.e_magic, db 'MZ'
    at IMAGE_DOS_HEADER.e_lfanew, dd NT_Signature - IMAGEBASE
iend

NT_Signature:
istruc IMAGE_NT_HEADERS
    at IMAGE_NT_HEADERS.Signature, db 'PE', 0, 0
iend
istruc IMAGE_FILE_HEADER
    at IMAGE_FILE_HEADER.Machine,               dw IMAGE_FILE_MACHINE_I386
    at IMAGE_FILE_HEADER.NumberOfSections,      dw NUMBEROFSECTIONS
    at IMAGE_FILE_HEADER.SizeOfOptionalHeader,  dw SIZEOFOPTIONALHEADER
    at IMAGE_FILE_HEADER.Characteristics,       dw IMAGE_FILE_EXECUTABLE_IMAGE | IMAGE_FILE_32BIT_MACHINE
iend

OptionalHeader:
istruc IMAGE_OPTIONAL_HEADER32
    at IMAGE_OPTIONAL_HEADER32.Magic,                     dw IMAGE_NT_OPTIONAL_HDR32_MAGIC
    at IMAGE_OPTIONAL_HEADER32.AddressOfEntryPoint,       dd EntryPoint - IMAGEBASE
    at IMAGE_OPTIONAL_HEADER32.ImageBase,                 dd IMAGEBASE
    at IMAGE_OPTIONAL_HEADER32.SectionAlignment,          dd SECTIONALIGN
    at IMAGE_OPTIONAL_HEADER32.FileAlignment,             dd FILEALIGN
    at IMAGE_OPTIONAL_HEADER32.MajorSubsystemVersion,     dw 4
    at IMAGE_OPTIONAL_HEADER32.SizeOfImage,               dd 2 * SECTIONALIGN
    at IMAGE_OPTIONAL_HEADER32.SizeOfHeaders,             dd SIZEOFHEADERS
    at IMAGE_OPTIONAL_HEADER32.CheckSum,                  dd 0 ; to be fixed externally
    at IMAGE_OPTIONAL_HEADER32.Subsystem,                 dw 1 ; IMAGE_SUBSYSTEM_NATIVE
    at IMAGE_OPTIONAL_HEADER32.NumberOfRvaAndSizes,       dd 16
iend

istruc IMAGE_DATA_DIRECTORY_16
    at IMAGE_DATA_DIRECTORY_16.ImportsVA,  dd Import_Descriptor - IMAGEBASE
    at IMAGE_DATA_DIRECTORY_16.FixupsVA,   dd Directory_Entry_Basereloc - IMAGEBASE
    at IMAGE_DATA_DIRECTORY_16.FixupsSize, dd DIRECTORY_ENTRY_BASERELOC_SIZE
iend

SIZEOFOPTIONALHEADER equ $ - OptionalHeader
SectionHeader:
istruc IMAGE_SECTION_HEADER
    at IMAGE_SECTION_HEADER.VirtualSize,      dd 1 * SECTIONALIGN
    at IMAGE_SECTION_HEADER.VirtualAddress,   dd 1 * SECTIONALIGN
    at IMAGE_SECTION_HEADER.SizeOfRawData,    dd 1 * FILEALIGN
    at IMAGE_SECTION_HEADER.PointerToRawData, dd 1 * FILEALIGN
    at IMAGE_SECTION_HEADER.Characteristics,  dd IMAGE_SCN_MEM_EXECUTE | IMAGE_SCN_MEM_WRITE
iend
NUMBEROFSECTIONS equ ($ - SectionHeader) / IMAGE_SECTION_HEADER_size
SIZEOFHEADERS equ $ - IMAGEBASE

section progbits vstart=IMAGEBASE + SECTIONALIGN align=FILEALIGN

EntryPoint:
    pusha
reloc01:
    mov esi, _esi
reloc11:
    mov edi, _edi


; the idea:
; 1. invalidate the cache (privileged instruction)
; 2. make a memory write
; 3. if you enforce a Save Fence, the CPU will wait for the write

    inv
    mov dword [esi], 1
    sfence
    mov dword [edi], 2

    rdtsc

    mov ebx, eax
    sfence
    mov dword [esi], 3
    rdtsc
    sub eax, ebx
    push eax

; test without the sfence
    invd
    mov dword [esi], 1
    ;sfence
    mov dword [edi], 2
    rdtsc

    mov ecx, eax
    ;sfence
    mov dword [esi], 3
    rdtsc
    sub eax, ecx
    push eax


reloc21:
    push Msg
reloc32:
    call [__imp__DbgPrint]
    add esp, 3 * 4
_
    popa
    mov eax, 0xC0000182; STATUS_DEVICE_CONFIGURATION_ERROR
    retn 8
_c

_esi dd 0
_edi dd 0

ntoskrnl.exe_iat:
__imp__DbgPrint:
    dd hnDbgPrint - IMAGEBASE
    dd 0

Import_Descriptor:
;ntoskrnl.exe_DESCRIPTOR
    dd ntoskrnl.exe_hintnames - IMAGEBASE
    dd 0, 0
    dd ntoskrnl.exe - IMAGEBASE
    dd ntoskrnl.exe_iat - IMAGEBASE
times 5 dd 0

ntoskrnl.exe_hintnames:
    dd hnDbgPrint - IMAGEBASE
    dd 0

hnDbgPrint:
    dw 0
    db 'DbgPrint', 0

ntoskrnl.exe db 'ntoskrnl.exe',0
_d

Directory_Entry_Basereloc:
block_start0:
; relocation block start
    .VirtualAddress dd reloc01 - IMAGEBASE
    .SizeOfBlock dd base_reloc_size_of_block0
    dw (IMAGE_REL_BASED_HIGHLOW << 12) | (reloc01 + 1 - reloc01)
    dw (IMAGE_REL_BASED_HIGHLOW << 12) | (reloc11 + 1 - reloc01)
    dw (IMAGE_REL_BASED_HIGHLOW << 12) | (reloc21 + 1 - reloc01)
    dw (IMAGE_REL_BASED_HIGHLOW << 12) | (reloc32 + 2 - reloc01)
    base_reloc_size_of_block0 equ $ - block_start0
;relocation block end

;relocations end

DIRECTORY_ENTRY_BASERELOC_SIZE  equ $ - Directory_Entry_Basereloc
_d

Msg db " SFence test: without %i with %i", 0
_d

align FILEALIGN, db 0
