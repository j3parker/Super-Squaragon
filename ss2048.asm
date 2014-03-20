_Palettes:
  ; Background
  .byte $2D, $3D, $31, $32
  .byte $2D, $21, $22, $11
  .byte $2D, $12, $13, $03
  .byte $2D, $01, $04, $10

  ; Sprite
  .byte $0F, $2D, $36, $37
  .byte $0F, $20, $27, $26
  .byte $0F, $20, $16, $05
  .byte $0F, $20, $06, $06

_Sprites:
  .byte $48, $04, $00, $68
  .byte $48, $05, $00, $70
  .byte $50, $06, $00, $68
  .byte $50, $07, $00, $70

  .byte $48, $00, $00, $48
  .byte $48, $01, $00, $50
  .byte $50, $02, $00, $48
  .byte $50, $03, $00, $50

  .byte $88, $10, $01, $A8
  .byte $88, $11, $01, $B0
  .byte $90, $12, $01, $A8
  .byte $90, $13, $01, $B0

  ; This is the power of two for the tile modulo 3, multiplied by 8.
  ; It gives us the offset into the bg pattern table to get our bg tiles
  ; for a cell. There are 8 tiles to build up one cell.
  ; E.g. tile 128 = 2^7, 7%3 == 1 so we use want to use color 1 of the palette
  ; determined by _PaletteChoice. The bg tiles are stored at an offset of 0x08
  ; from the first cell bg tile.
_PaletteIndex:
  .byte $00, $08, $10, $00, $08, $10, $00, $08, $10, $00, $08

  ; This is the power of two for the tile divided by 3, and then those
  ; two bits are replicated 4 times. Each two bits sets the palette of a
  ; 16x16 region but we use 32x32 meta-tiles so we want the same palette for
  ; all 4 tiles. E.g. 7/3 = 2 = 0b10 --> 0b10101010 = 0xAA, so tile 128=2^7
  ; uses palette 2 (the third palette) and therefore we write 0xAA to the
  ; attribute table.
_PaletteChoice:
  .byte $00, $00, $00, $55, $55, $55, $AA, $AA, $AA, $FF, $FF

.define RNG_SEED $20

Boot:
  sei
  cld
  ldx #$40
  stx $4017    ; disable APU frame IRQ
  ldx #$FF
  txs
  inx          ; now X = 0
  stx $2000    ; disable NMI
  stx $2001    ; disable rendering
  stx $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT $2002
  BPL vblankwait1

@ClearMemory:
  lda #$00
  sta $0000, x
  sta $0100, x
  sta $0200, x
  sta $0400, x
  sta $0500, x
  sta $0600, x
  sta $0700, x
  lda #$FE
  sta $0300, x
  inx
  bne @ClearMemory

vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2

  ; We will want to change this based on the level later
LoadPalettes:
  lda #$3F
  sta $2006
  lda #$00
  sta $2006
  tax
@Loop:
  lda _Palettes, x
  sta $2007
  inx
  cpx #$20
  bne @Loop

  ; Sets each bg tile to the 4th solid color of the palette
  ; (Has to deal with 16 bit arithmetic because there are 960 tiles)
ClearBackground:
  lda #$20
  sta $2006
  lda #$00
  sta $2006
  tax
  ldy #$30 ; This tile is dithered between color 1 and 3
@Loop:
  sty $2007
  inx
  bne @NoCarry
  adc #$01
@NoCarry:
  cmp #$0C
  bne @Loop
  cpx #$30
  bne @Loop

  jsr DrawOuterBorder

  ; Loads a checkerboard pattern into the attribute table (palette choices)
InitAttrTable:
  lda #$23
  sta $2006
  lda #$C0
  sta $2006
  ldx #$00
  lda #%11001001 ; Make this $FF to choose only the last palette
@Loop:
  sta $2007
  inx
  cpx #$40
  bne @Loop

  ; Update all tiles to be empty
  lda #$00
  ldy #$00
@Row:
  ldx #$00
@Column:
  jsr UpdateTile
  inx
  cpx #$04
  bne @Column
  iny
  cpy #$04
  bne @Row


  ; This is some hardcoded setting of coloured tiles
  lda #$02
  ldx #$01
  ldy #$00
  jsr UpdateTile
  lda #$01
  ldx #$00
  ldy #$00
  jsr UpdateTile
  lda #$05
  ldx #$03
  ldy #$02
  jsr UpdateTile

LoadSprites:
  ldx #$00
@Loop:
  lda _Sprites, x
  sta $0200, x
  inx
  cpx #$30
  bne @Loop

  ; urg, figure out scrolling...
  lda #$00
  sta $2005
  lda #$FF
  sta $2005
  lda #$00
  sta $2000

  lda #%10010000
  sta $2000

  lda #%00011010
  sta $2001


@Forever:
  jmp @Forever

; Draws a 1 pixel border around the grid cells.
; Each cell is surrounded by 1px of black, so two adjacent cells get a 2 pixel
; border. We draw a seperate border around the outside to get uniformity.
DrawOuterBorder:

TopRow:
  lda #$20
  sta $2006
  lda #$E7
  sta $2006
  lda #$E0
  sta $2007
  ldx #$00
  lda #$C0
@Loop:
  sta $2007
  inx
  cpx #$10
  bne @Loop
  lda #$E1
  sta $2007

BottomRow:
  lda #$23
  sta $2006
  lda #$07
  sta $2006
  lda #$E3
  sta $2007
  ldx #$00
  lda #$C2
@Loop:
  sta $2007
  inx
  cpx #$10
  bne @Loop
  lda #$E2
  sta $2007

  lda #$C3
  ldx #$21
  ldy #$07
  jsr InitVertBorder

  lda #$C1
  ldx #$21
  ldy #$18
  jsr InitVertBorder

; Helper function for DrawOuterBorder
InitVertBorder:
  pha
  clc
@Loop:
  pla
  stx $2006
  sty $2006
  sta $2007
  pha
  tya
  adc #$20
  tay
  txa
  adc #$00
  tax
  cpx #$23
  bne @Loop
  pla
  rts




; Inputs:
;   A - color ($00, $01, $02)
;   X - X index
;   Y - Y index
UpdateTile:
  sta $00
  stx $01
  sty $02

  tax
  lda _PaletteIndex, x
  sta $03
  lda _PaletteChoice, x
  sta $04

  ; Get high bit for bg
  lda #$21
  cpy #$00
  beq @Skip
  cpy #$01
  beq @Skip
  clc
  adc #$01
@Skip:
  sta $2006
  sta $05

  ; Offset for X pos
  lda #$08
  ldx $01
@Loop:
  cpx #$00
  beq @Done
  dex
  adc #$03
  jmp @Loop
@Done:
  ; Offset for odd rows
  ldy $02
  beq @EvenRow
  cpy #$02
  beq @EvenRow
  clc
  adc #$80
@EvenRow:
  sta $2006
  sta $06

  lda $03
  jsr Top

  tax
  lda $05
  sta $2006
  lda $06
  clc
  adc #$20
  sta $2006
  sta $06
  txa
  jsr Middle

  tax
  lda $05
  sta $2006
  lda $06
  clc
  adc #$20
  sta $2006
  sta $06
  txa
  jsr Middle

  tax
  lda $05
  sta $2006
  lda $06
  clc
  adc #$20
  sta $2006
  txa
  jsr Bottom

  ; Update attr table with colour
  lda #$23
  sta $2006
  clc
  lda $01
  adc #$D2
  sta $05
  lda $02
  asl
  asl
  asl
  adc $05
  sta $2006
  lda $04

  sta $2007

@Exit:
  lda $00
  ldx $01
  ldy $02
  rts

Top:
  sta $2007
  clc
  adc #$01
  sta $2007
  sta $2007
  adc #$01
  sta $2007
  sbc #$01
  rts

Middle:
  clc
  adc #$07
  sta $2007
  tay
  lda $03
  ror
  ror
  ror
  adc #$20
  sta $2007
  sta $2007
  tya
  sbc #$03
  sta $2007
  sbc #$03
  rts

Bottom:
  clc
  adc #$06
  sta $2007
  sbc #$00
  sta $2007
  sta $2007
  sbc #$01
  sta $2007
  sbc #$05
  rts

Vsync:
  lda $2002
  lda #$00
  sta $2003
  lda #$02
  sta $4014
  rti

.segment "VECTORS"
  .word Vsync
  .word Boot
  .word 0
