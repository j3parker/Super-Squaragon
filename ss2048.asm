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

.define Stage                      $10
.define MenuFlag                   #$00
.define PlaidStageFlag             #$01
.define CPUFlag                    #$02

.define PlaidStage_State           $11
.define PlaidStage_UpdateUpperFlag #$00
.define PlaidStage_UpdateLowerFlag #$01
.define PlaidStage_IdleFlag        #$02


.define Grid        $A0
.define GridBg      $B0
.define GridPalette $C0

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

  jsr LoadSprites

  lda #%10010000
  sta $2000

  lda #%00011010
  sta $2001

  lda PlaidStageFlag
  sta Stage
  lda PlaidStage_UpdateUpperFlag
  sta PlaidStage_State

@Forever:
  clc
  jmp @Forever

LoadSprites:
  ; $00 - X value (pixels)
  ; X - array index (always)

  clc
  ldy #$47

  ldx #$00 ; byte index into sprite data
@Column:
  lda #$47 ; X: 64 + 8 pixels from left
  sta $00
@Row:
  ; Top left
  tya
  sta $0200, x ; Store Y value
  inx
  lda #$2C
  sta $0200, x ; Store transparent tile
  inx
  sta $0200, x ; Store arbitrary palette etc.
  inx
  lda $00
  sta $0200, x ; Store X value
  inx

  ; Top right
  tya
  sta $0200, x ; Store Y value
  inx
  lda #$2C
  sta $0200, x ; Store transparent tile
  inx
  lda #$00
  sta $0200, x ; Store arbitrary palette etc.
  inx
  lda $00
  adc #$08 ; 8 pixels
  sta $0200, x ; Store X value
  inx

  ; Bottom left
  tya
  adc #$08 ; 8 pixels
  sta $0200, x ; Store Y value
  inx
  lda #$2C
  sta $0200, x ; Store transparent tile
  inx
  lda #$00
  sta $0200, x ; Store arbitrary palette etc.
  inx
  lda $00
  sta $0200, x ; Store X value
  inx

  ; Bottom right
  tya
  adc #$08 ; 8 pixels
  sta $0200, x ; Store Y value
  inx
  lda #$2C
  sta $0200, x ; Store transparent tile
  inx
  lda #$00
  sta $0200, x ; Store arbitrary palette etc.
  inx
  lda $00
  adc #$08 ; 8 pixels
  sta $0200, x ; Store X value
  inx

  lda $00
  adc #$20 ; 32 pixels
  sta $00
  cmp #$C7 ; Past last column
  bne @Row

  tya
  clc
  adc #$20 ; 32 pixels
  tay
  cmp #$C7 ; Past last row
  bne @Column

  rts


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
  rts

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

Vsync:
  clc
  jsr StageDispatch

  ; urg, figure out scrolling...
  lda #$00
  sta $2005
  lda #$00
  sta $2005
  lda #%10010000
  sta $2000

  ; TODO first the bits on the left control color intensities - i.e. disco mode
  lda #%00011010
  sta $2001



  lda $2002
  lda #$00
  sta $2003
  lda #$02
  sta $4014
  rti

StageDispatch:
  lda Stage
  jsr JumpEngine

  .word Menu
  .word PlaidStage

Menu:
  rts ; Not implemented

PlaidStage:
  lda PlaidStage_State
  jsr JumpEngine

  .word PlaidStage_UpdateUpper
  .word PlaidStage_UpdateLower
  .word PlaidStage_Idle

PlaidStage_UpdateUpper:
  ldx #$21
  jsr UpdateTiles
  lda PlaidStage_UpdateLowerFlag
  sta PlaidStage_State
  rts

PlaidStage_UpdateLower:
  ldx #$22
  jsr UpdateTiles
  lda PlaidStage_IdleFlag
  sta PlaidStage_State
  rts

PlaidStage_Idle:
  ; read gamepads etc.
  rts

_TilePattern:
.byte $00, $01, $01, $02
.byte $07, $20, $20, $03
.byte $07, $20, $20, $03
.byte $06, $05, $05, $04

UpdateTiles:
  ; Input: X: high byte PPU start
  ; $00 - high byte PPU addr
  ; $01 - low byte PPU addr
  ; $02 - gridcell we are on
  ; $03 - high byte PPU target
  stx $00
  lda #$08
  sta $01
  lda #$00
  sta $02
  inx
  stx $03
  ldx #$00

@Row:
  ; Position the PPU r/w register and pre-increment it for the next loop
  lda $00
  sta $2006
  tay
  lda $01
  sta $2006
  ; Add 8 tiles to get to the right edge of screen, 8 tiles padding on left on next row
  adc #$20 ; 8 tile padding on both ends = 16 ($10) plus $10 for the board width
  sta $01
  tya
  adc #$00
  sta $00

  ; x: _TilePattern row
  ; y: ($02) gridcell index
  ldy $02
  jsr UpdateTiles_SingleRow

  ; Cycle through _TilePattern rows
  txa
  adc #$04
  tax
  cpx #$10
  bne @CheckIfDone
  ldx #$00
  tya
  adc #$04
  tay
  sty $02

@CheckIfDone:
  lda $00
  cmp $03
  bne @Row

  ; Update attribute tables
  lda #$23
  sta $2006
  lda #$D2 ; C0 + $12 (i.e. top + left initial pad)
  ldy #$00 ; grid index
  ldx $00
  cpx #$22 ; if we were doing the lower half the high byte now points to start of lower half
  beq @SaveAttrLow
  clc
  adc #$10 ; we are in the lower half of the grid, add 16 metatiles
  ldy #$08 ; grid index
@SaveAttrLow:
  sta $00
  sta $2006

  ; Send a row of attributes
  ldx Grid, y
  lda _PaletteChoice, x
  sta $2007
  ldx Grid+$01, y
  lda _PaletteChoice, x
  sta $2007
  ldx Grid+$02, y
  lda _PaletteChoice, x
  sta $2007
  ldx Grid+$03, y
  lda _PaletteChoice, x
  sta $2007

  ; Reposition to next row
  lda #$23
  sta $2006
  lda $00
  clc
  adc #$08
  sta $2006

  ; Send a row of attributes
  ldx Grid+$04, y
  lda _PaletteChoice, x
  sta $2007
  ldx Grid+$05, y
  lda _PaletteChoice, x
  sta $2007
  ldx Grid+$06, y
  lda _PaletteChoice, x
  sta $2007
  ldx Grid+$07, y
  lda _PaletteChoice, x
  sta $2007

  rts

UpdateTiles_SingleRow:
  ; Send a row
  ; x holds tilepattern index
  ; y holds bg selection index
@Loop:
  lda _TilePattern, x
  adc GridBg, y
  sta $2007
  lda _TilePattern+$01, x
  adc GridBg, y
  sta $2007
  lda _TilePattern+$02, x
  adc GridBg, y
  sta $2007
  lda _TilePattern+$03, x
  adc GridBg, y
  sta $2007

  lda _TilePattern, x
  adc GridBg+$01, y
  sta $2007
  lda _TilePattern+$01, x
  adc GridBg+$01, y
  sta $2007
  lda _TilePattern+$02, x
  adc GridBg+$01, y
  sta $2007
  lda _TilePattern+$03, x
  adc GridBg+$01, y
  sta $2007

  lda _TilePattern, x
  adc GridBg+$02, y
  sta $2007
  lda _TilePattern+$01, x
  adc GridBg+$02, y
  sta $2007
  lda _TilePattern+$02, x
  adc GridBg+$02, y
  sta $2007
  lda _TilePattern+$03, x
  adc GridBg+$02, y
  sta $2007

  lda _TilePattern, x
  adc GridBg+$03, y
  sta $2007
  lda _TilePattern+$01, x
  adc GridBg+$03, y
  sta $2007
  lda _TilePattern+$02, x
  adc GridBg+$03, y
  sta $2007
  lda _TilePattern+$03, x
  adc GridBg+$03, y
  sta $2007

  rts

JumpEngine:
  ; This code was stolen from Super Mario Bros/the smbdis.asm disassembly.

  ; Put jump table index into Y
  asl
  tay

  ; Pull the callers return PC from the top of the stack. The jump table is just after it
  pla
  sta $04
  pla
  sta $05

  ; Store it somewhere we can indirectly jump with
  iny
  lda ($04), y
  sta $06
  iny
  lda ($04), y
  sta $07

  jmp ($06)

.segment "VECTORS"
  .word Vsync
  .word Boot
  .word 0
