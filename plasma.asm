; *************************************************************************** 
;   Boot sector plasma effect - x86 real mode, VGA mode 13h (320x200x256)
;
;            Copyright (C) 2026 By Ulrik Hørlyk Hjort
;
; Permission is hereby granted, free of charge, to any person obtaining
; a copy of this software and associated documentation files (the
; "Software"), to deal in the Software without restriction, including
; without limitation the rights to use, copy, modify, merge, publish,
; distribute, sublicense, and/or sell copies of the Software, and to
; permit persons to whom the Software is furnished to do so, subject to
; the following conditions:
;
; The above copyright notice and this permission notice shall be
; included in all copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
; NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
; LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
; OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
; WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
; ***************************************************************************   
	
; Compile:  nasm -f bin -o plasma.bin plasma.asm
; Run:      qemu-system-i386 -L /usr/local/share/qemu plasma.bin

BITS 16
ORG 0x7C00

    xor  ax, ax
    mov  ds, ax
    mov  ss, ax
    mov  sp, 0x7C00

    ; Switch to VGA mode 13h: 320x200, 256 colors
    mov  ax, 0x0013
    int  0x10

    ; Set DAC palette: 3-phase sine rainbow (R/G/B each 120° apart)
    xor  al, al
    mov  dx, 0x3C8
    out  dx, al         ; start writing from color index 0
    inc  dx             ; dx = 0x3C9  (data port)
    xor  cl, cl         ; cl = color index 0..255
.pal:
    movzx bx, cl
    mov  al, [bx + sine_table]
    shr  al, 2          ; scale 0-255 → 0-63
    out  dx, al         ; R
    add  bl, 85         ; bl = (cl + 85)  & 0xFF
    mov  al, [bx + sine_table]
    shr  al, 2
    out  dx, al         ; G
    add  bl, 85         ; bl = (cl + 170) & 0xFF
    mov  al, [bx + sine_table]
    shr  al, 2
    out  dx, al         ; B
    inc  cl
    jnz  .pal           ; repeat 256 times (wraps 255 → 0)

    ; Point ES to VGA framebuffer at A000:0000
    mov  ax, 0xA000
    mov  es, ax
    xor  dh, dh         ; DH = time / animation counter

; ── Main animation loop ──────────────────────────────────────────────────────
.frame:
    xor  di, di         ; DI = pixel offset into framebuffer
    xor  si, si         ; SI = y (0..199)

.yloop:
    xor  cx, cx         ; CX = x (0..319),  CL = x & 0xFF

.xloop:
    ; color = sine[(x + t)] + sine[(2y + t)] + sine[(x + y + 2t)]
    ; All indices auto-wrap mod 256 via 8-bit arithmetic.

    ; v1 = sine[(x + t) & 0xFF]
    mov  al, cl
    add  al, dh
    movzx bx, al
    mov  dl, [bx + sine_table]

    ; v2 = sine[(2*y + t) & 0xFF]
    mov  bx, si         ; BX = y  (y < 200 → BH=0, BL=y)
    mov  al, bl
    shl  al, 1          ; al = 2*y
    add  al, dh
    movzx bx, al
    add  dl, [bx + sine_table]

    ; v3 = sine[(x + y + 2*t) & 0xFF]
    mov  al, cl         ; al = x
    add  al, dh
    add  al, dh         ; al = x + 2*t
    mov  bx, si
    add  al, bl         ; al = x + y + 2*t
    movzx bx, al
    add  dl, [bx + sine_table]

    ; Write 8-bit color (sum mod 256) to framebuffer
    mov  [es:di], dl
    inc  di

    inc  cx
    cmp  cx, 320
    jb   .xloop

    inc  si
    cmp  si, 200
    jb   .yloop

    inc  dh             ; advance time
    jmp  .frame

; ── 256-byte sine lookup table ───────────────────────────────────────────────
; sine_table[i] = round(127.5 + 127.5 * sin(i * 2π / 256))  →  range 0..255
sine_table:
    db 128, 131, 134, 137, 140, 143, 146, 149, 152, 155, 158, 162, 165, 167, 170, 173
    db 176, 179, 182, 185, 188, 190, 193, 196, 198, 201, 203, 206, 208, 211, 213, 215
    db 218, 220, 222, 224, 226, 228, 230, 232, 234, 235, 237, 238, 240, 241, 243, 244
    db 245, 246, 248, 249, 250, 250, 251, 252, 253, 253, 254, 254, 254, 255, 255, 255
    db 255, 255, 255, 255, 254, 254, 254, 253, 253, 252, 251, 250, 250, 249, 248, 246
    db 245, 244, 243, 241, 240, 238, 237, 235, 234, 232, 230, 228, 226, 224, 222, 220
    db 218, 215, 213, 211, 208, 206, 203, 201, 198, 196, 193, 190, 188, 185, 182, 179
    db 176, 173, 170, 167, 165, 162, 158, 155, 152, 149, 146, 143, 140, 137, 134, 131
    db 128, 124, 121, 118, 115, 112, 109, 106, 103, 100,  97,  93,  90,  88,  85,  82
    db  79,  76,  73,  70,  67,  65,  62,  59,  57,  54,  52,  49,  47,  44,  42,  40
    db  37,  35,  33,  31,  29,  27,  25,  23,  21,  20,  18,  17,  15,  14,  12,  11
    db  10,   9,   7,   6,   5,   5,   4,   3,   2,   2,   1,   1,   1,   0,   0,   0
    db   0,   0,   0,   0,   1,   1,   1,   2,   2,   3,   4,   5,   5,   6,   7,   9
    db  10,  11,  12,  14,  15,  17,  18,  20,  21,  23,  25,  27,  29,  31,  33,  35
    db  37,  40,  42,  44,  47,  49,  52,  54,  57,  59,  62,  65,  67,  70,  73,  76
    db  79,  82,  85,  88,  90,  93,  97, 100, 103, 106, 109, 112, 115, 118, 121, 124

    times 510-($-$$) db 0   ; pad to 510 bytes
    dw 0xAA55               ; boot signature
