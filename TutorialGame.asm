;;==== BASIC ANATOMY OF A NES FILE ====
;;=====================================

;;  1. The iNES Header
    .db "NES", $1a   ; iNes identifier
    .db $01          ; number of PRG-Rom blocks the game will have
    .db $01          ; number of CHR-Rom blocks the game will have
    .db $00, $01     ; control bytes
    .db $00, $00, $00, $00, $00, $00, $00, $00  ;; filler

;; 2. Constants and Variables
    .enum $0000  ; This is the Zero Page

    ; variables will eventually go here
    playerY .dsb 1     ; playerX (sprite's x pos) is 1 byte in length
    playerX .dsb 1     ; playerY (sprite's y pos)

    frameTimer .dsb 1  ; declare frameTimer variablw
    .ende

;; 3. Set the starting point fot the code
    .org $C000  ; This starts the code at address $C000


;; 4. The RESET routine
RESET:
    SEI        ; SEI tells the code to ignore interupts for the routine
    LDA #$00   ; Load 0 into the accumulator
    STA $2000  ; Disables the NMI
    STA $2001  ; Disables the rendering
    STA $4010
    STA $4015
    LDA #$40   ; Loads HEX: 40_16 (= 64_10) into accumulator
    STA $4017
    CLD        ; Disables decimal mode
    LDX #$FF   ; Loads 255_10 into X register
    TXS        ; Initializes the stack

;; Waits for vBlank to be reached (i.e. waits for a new frame)
    bit $2002
vBlankWait1:
    bit $2002
    BPL vBlankWait1

    ;; CLEAR OUT MEMORY & STUFF HERE
    LDA #$00  ; Loads 0 into the accumulator
    LDX #$00  ; Loads 0 into the X register (X will INCrement through [0, 255])
ClearMemoryLoop:
    STA $0000, x  ; Stores the accumulator into addr $0000 + x
    STA $0100, x  ; Stores the accumulator into addr $0100 + x
    STA $0200, x  ; Stores the accumulator into addr $0200 + x
    STA $0300, x  ; Stores the accumulator into addr $0300 + x
    STA $0400, x  ; Stores the accumulator into addr $0400 + x
    STA $0500, x  ; Stores the accumulator into addr $0500 + x
    STA $0600, x  ; Stores the accumulator into addr $0600 + x
    STA $0700, x  ; Stores the accumulator into addr $0700 + x
    INX           ; X++
    BNE ClearMemoryLoop  ; Will continue to loop unitl X overflows back to 0

;; same as vBlankWait1. We specifically want this to run after Clearing memory
vBlankWait2:
    bit $2002
    BPL vBlankWait2

    ;; Re-Enable things after clearing memory & setting up
    LDA #%10010000  ; Loads this binary number into accumulator
    STA $2000       ; Re-Enables NMI

    LDA #%00011110  ; Loads this binary number into accumulator
    STA $2001       ; Re-Enables rendering

    ;; Set Default value variable values
    LDA #$80
    STA playerX
    STA playerY

    ;; At the end of RESET, jump to the Main Game Code
    JMP MainGameLoop


;; 5. The NMI (Non-Maskable Interrupt): Happens at the end of every frame
;;                                      When the game does its PPU updates
;;                                      & prepares to draw the next frame.
NMI:
    ;; Push A, X, & Y registers to the stack to preserve them
    PHA  ; push accumulator to the stack
    TXA  ; A <= X
    PHA
    TYA  ; A <= Y
    PHA  ; Stack in Descending Order: Y, X, A

    ;;===================
    ;; DO NMI STUFF HERE

    INC frameTimer  ; frameTimer++ every time NMI is hit

    ;; Transfer sprites to PPU
    LDA $00
    STA $2003  ; sets the low byte of the sprite RAM address
    LDA #$02
    STA $4014  ; sets high byte of the sprite RAM addr
               ; sprite RAM addr: $0200 (16-bit addr)

    ;; load palattes (Palette tables are defined in Section 8)
    LDA $2002
    LDA #$3F
    STA $2006
    LDA #$00
    STA $2006
    LDX #$00
LoadPalettesLoop:
    LDA MyPalettes, x    ; Load whatever value from the table that x equals
    STA $2007            ; Store it to the addr that handles palettes.
    INX                  ; X++
    CPX #$20             ; Compare X to 32 (8 banks * 4 colors)
    BNE LoadPalettesLoop  ; Loop while X != 32

    ;; Re-Enable Things
    LDA #%10010000  ; Re-Enable NMI
    STA $2000
    LDA #%00011110  ; RE-Enables rendering

    STA $2001
    ;;===================

    ;; Pull Y, X, & A registers from the stack
    PLA  ; Pull Y from stack and into the accumulator
    TAY  ; Y <= A = Y_old
    PLA
    TAX  ; X <= A = X_old
    PLA  ; A <= A_old

    ;; At the end of NMI, we want to "Return from Interrupt"
    RTI  ; returns back to the point in the code we were when the frame ended

;; 6. The Main Game Loop
MainGameLoop:
    ;; Regulate Frames
    LDA frameTimer
CheckFrameTimer:
    CMP frameTimer       ; if frameTimer is the same...
    BEQ CheckFrameTimer  ; loop; Else frame has INCreased & we can move forward

    ;; Game Logic Goes Here
    LDA playerY
    STA $0200    ; store the sprite's y value
    LDA playerX
    STA $0203    ; store the sprite's x value


    INC playerX  ; | Every Frame,
    INC playerX  ; | playerX+=2

    JMP MainGameLoop

;; 7. Sub Routines


;; 8. INCludes and data tables

MyPalettes:
    .db $0E,$05,$25,$0F,$0E,$05,$25,$0F,$0E,$05,$25,$0F,$0E,$05,$25,$0F  ; background
    .db $0E,$05,$25,$0F,$0E,$05,$25,$0F,$0E,$05,$25,$0F,$0E,$05,$25,$0F  ; sprites


;; 9. The Vectors (last few bytes of the ROM file)
;;                Determine the location of: Reset, NMI, (& other interupts)

    .org $fffa  ; sets us up at the very end of the code.
    .dw NMI     ; NMI points to label NMI
    .dw RESET   ; Reset points to label RESET
    .dw 00

    ;; load the sprite(s)
    .INCbin "Player.chr"
