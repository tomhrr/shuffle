  .inesprg 1
  .ineschr 1
  .inesmap 0
  .inesmir 1

  .bank 0
  .org $C000

  .rsset $0000

time        .rs 1
frames      .rs 1
controller  .rs 1
prngSeed    .rs 2

needPPUReg  .rs 1
needScore   .rs 1
soft2000    .rs 1
soft2001    .rs 1
xscroll     .rs 1
yscroll     .rs 1
sleeping    .rs 1

needToPPU   .rs 1
toPPUHi     .rs 1
toPPULo     .rs 1
toPPULength .rs 1
toPPULocLo  .rs 1
toPPULocHi  .rs 1

pointerLo   .rs 1
pointerHi   .rs 1
var         .rs 1

gameState   .rs 1
balls       .rs 1
score       .rs 5
playermoved .rs 1
pballs      .rs 16
xsballs     .rs 16
ysballs     .rs 16
xsiballs    .rs 16
ysiballs    .rs 16

SCORE_BG_INDEX_HI = $24
SCORE_BG_INDEX_LO = $41
SPEED_MIN = $02
SPEED_MAX = $03
SPEED_MASK = $03
BALLS_MAX = $0A
SPEED_PLAYER = $03

CopyToPPUInit .macro
  lda $2002
  lda \1
  sta $2006
  lda \2
  sta $2006
  .endm

Increment .macro
  lda \1
  clc
  adc #SPEED_PLAYER
  sta \1
  .endm

Decrement .macro
  lda \1
  sec
  sbc #SPEED_PLAYER
  sta \1
  .endm

LoadBackground:
  sta $2006
  lda #$00
  sta $2006
  lda #$00
  sta pointerLo
  ldx #$00
  ldy #$00
  LBOutsideLoop:
    LBInsideLoop:
    lda [pointerLo], Y
    sta $2007
    iny
    cpy #$00
    bne LBInsideLoop
  inc pointerHi
  inx
  cpx #$04
  bne LBOutsideLoop
  rts

Reset:
  sei
  cld
  ldx #$40
  stx $4017
  ldx #$FF
  txs
  inx
  stx $2000
  stx $2001
  stx $4010

VBlankWait1:
  bit $2002
  bpl VBlankWait1

ClearMemory:
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
  bne ClearMemory

PBalls:
  ldx #$00
  lda #$10
  PBLoop:
    sta pballs, X
    inx
    clc
    adc #$04
    cpx #$0F
    bne PBLoop

VBlankWait2:
  bit $2002
  bpl VBlankWait2

LoadPalettes:
  CopyToPPUInit #$3F, #$00
  ldx #$00
  LPLoop:
    lda palette, X
    sta $2007
    inx
    cpx #$20
    bne LPLoop

LoadSprites:
  ldx #$00
  LSLoop:
    lda sprites, X
    sta $0200, X
    inx
    cpx #$10
    bne LSLoop

LoadInitBackground:
  lda #high(background)
  sta pointerHi
  lda #$20
  jsr LoadBackground
  lda #high(gameplaybackground)
  sta pointerHi
  lda #$24
  jsr LoadBackground

InitGlobals:
  ldx #$00
  lda #$00
  IGLoop:
    sta controller, X
    inx
    cpx #$0F
    bne IGLoop

  lda #%10011000
  sta soft2000
  sta $2000
  lda #%00001000
  sta soft2001
  sta $2001
  lda #$01
  sta needPPUReg
  jsr WaitFrame
  jmp DoFrame

WaitFrame:
  inc sleeping
  WFLoop:
    lda sleeping
    bne WFLoop
  rts

PRNG:
  ldx #$08
  lda prngSeed
  POutsideLoop:
  asl A
  rol prngSeed+1
  bcc PInsideLoop
  eor #$2D
  PInsideLoop:
  dex
  bne POutsideLoop
  sta prngSeed+0
  cmp #$00
  rts

GetSpeed:
  jsr PRNG
  and #SPEED_MASK
  cmp #SPEED_MIN
  bcc MinChecked
  lda #SPEED_MIN
  rts
  MinChecked:
    cmp #SPEED_MAX
    bcs MaxChecked
    lda #SPEED_MAX
  MaxChecked:
    rts

ReadController:
  lda #$01
  sta $FF
  sta $4016
  lda #$00
  sta $4016
  lda $4016
  and $FF
  asl A
  sta controller
  ldx #$00
  ReadController1Loop:
    lda $4016
    and $FF
    ora controller
    asl A
    sta controller
    inx
    cpx #$06
    bne ReadController1Loop
  lda $4016
  and $FF
  ora controller
  sta controller
  rts

HandleControllerInput:
  lda #$00
  sta playermoved
  lda controller
  and #%00001000
  beq UpDone
  Decrement $0200
  Decrement $0204
  Decrement $0208
  Decrement $020C
  lda #$01
  sta playermoved
  UpDone:
    lda controller
    and #%00000100
    beq DownDone
    Increment $0200
    Increment $0204
    Increment $0208
    Increment $020C
    lda #$01
    sta playermoved
  DownDone:
    lda controller
    and #%00000010
    beq LeftDone
    Decrement $0203
    Decrement $0207
    Decrement $020B
    Decrement $020F
    lda #$01
    sta playermoved
  LeftDone:
    lda controller
    and #%00000001
    beq RightDone
    Increment $0203
    Increment $0207
    Increment $020B
    Increment $020F
    lda #$01
    sta playermoved
  RightDone:
    rts

InitPlay:
  lda #$00
  sta balls
  sta $0210
  sta $0211
  sta $0212
  sta $0213
  sta time
  sta frames
  ldx #$00
  sta score, X
  inx
  sta score, X
  inx
  sta score, X
  inx
  sta score, X
  lda #%10010001
  sta soft2000
  lda #%00011000
  sta soft2001
  lda #$01
  sta needPPUReg
  jsr WaitFrame
  rts

IncrementScore:
  ldx #$00
  lda playermoved
  cmp #$01
  beq ISFinished
  ISLoop:
    lda score, X
    clc
    adc #$01
    sta score, X
    cmp #$0A
    bne ISIncFinished
    lda #$00
    sta score, X
    inx
    cpx #$04
    bne ISLoop
  ISIncFinished:
    lda #$01
    sta needScore
  ISFinished:
    rts

DrawScore:
  ldx #$04
  CopyToPPUInit #SCORE_BG_INDEX_HI, #SCORE_BG_INDEX_LO
  DSLoop:
    lda score, X
    sta $2007
    dex
    cpx #$00
    bne DSLoop
  lda #$00
  sta $2007
  sta $2005
  sta $2005
  rts

SpawnBall:
  lda frames
  and #$0F
  bne SBFinished
  lda balls
  clc
  cmp #BALLS_MAX
  bcs SBFinished
  tax
  lda pballs, X
  tay
  lda #$10
  sta $0200, Y
  iny
  lda #$00
  sta $0200, Y
  iny
  lda #$00
  sta $0200, Y
  iny
  jsr PRNG
  sta $0200, Y

  jsr GetSpeed
  ldx balls
  sta xsballs, X
  jsr GetSpeed
  ldx balls
  sta ysballs, X
  jsr PRNG
  and #$01
  ldx balls
  sta xsiballs, X
  jsr PRNG
  and #$01
  ldx balls
  sta ysiballs, X

  lda xsballs, X
  cmp ysballs, X
  bne SBSpeedOK
  cmp #SPEED_MAX
  bne SBIncrement
  dec xsballs, X
  jmp SBSpeedOK
  SBIncrement:
    inc xsballs, X
  SBSpeedOK:
    inc balls
  SBFinished:
    rts

MoveBalls:
  lda balls
  cmp #$00
  beq MBFinished
  ldx #$00
  MBLoop:
    lda ysiballs, X
    cmp #$01
    beq YPositive
    lda pballs, X
    tay
    lda $0200, Y
    sec
    sbc ysballs, X
    sta $0200, Y
    jmp YFinished
  YPositive:
    lda pballs, X
    tay
    lda $0200, Y
    clc
    adc ysballs, X
    sta $0200, Y
  YFinished:
    lda xsiballs, X
    cmp #$01
    beq XPositive
    lda pballs, X
    tay
    lda $0203, Y
    sec
    sbc xsballs, X
    sta $0203, Y
    jmp XFinished
  XPositive:
    lda pballs, X
    tay
    lda $0203, Y
    clc
    adc xsballs, X
    sta $0203, Y
  XFinished:
    inx
    cpx balls
    bne MBLoop
  MBFinished:
    rts

GameOver:
  lda #$00
  sta soft2001
  lda #$01
  sta needPPUReg
  jsr WaitFrame

  lda #high(gameoverbackground)
  sta pointerHi
  lda #$20
  jsr LoadBackground

  lda #$02
  sta gameState
  lda #$00
  sta balls

  ldx #$00
  GOClearMemory:
    sta $0210, x
    inx
    bne GOClearMemory

  lda #$70
  sta $0200
  sta $0203
  sta $0204
  sta $020B
  lda #$78
  sta $0207
  sta $0208
  sta $020C
  sta $020F

  lda #%10011000
  sta soft2000
  lda #%00001000   
  sta soft2001
  lda #$01
  sta needPPUReg
  jsr WaitFrame

  ldx #$00
  lda score, X
  sta var
  ldx #$04
  lda score, X
  ldx #$00
  sta score, X
  lda var
  ldx #$04
  sta score, X
  lda #$00
  sta score, X
  
  ldx #$01
  lda score, X
  sta var
  ldx #$03
  lda score, X
  ldx #$01
  sta score, X
  lda var
  ldx #$03
  sta score, X

  lda #$22
  sta toPPUHi
  lda #$4D
  sta toPPULo
  lda #$05
  sta toPPULength
  lda #$00
  sta toPPULocHi
  lda #score
  sta toPPULocLo
  lda #$01
  sta needToPPU
  lda #$00
  sta time
  sta frames
  jsr WaitFrame

  GOLoopWait:
    jsr WaitFrame
    lda time
    cmp #$03
    bne GOLoopWait
  GOFinished:
    rts

InitMenuScreen:
  lda #$00         
  sta soft2001
  lda #$01
  sta needPPUReg
  jsr WaitFrame

  lda #high(background)
  sta pointerHi
  lda #$20
  jsr LoadBackground

  lda #$00
  sta gameState

  lda #%10011000   
  sta soft2000
  lda #%00001000   
  sta soft2001
  lda #$01
  sta needPPUReg
  jsr WaitFrame

  rts

CheckPlayerCollision:
  lda balls
  cmp #$00
  beq CPCFinished
  ldx #$00
  CheckBallR1:
    lda pballs, X
    tay
    lda $0200, Y
    clc
    adc #$08
    cmp $0200
    bcc NextBall
    sta var
    lda $0200
    clc
    adc #$10
    cmp var
    bcc NextBall
    iny
    iny
    iny
    lda $0200, Y
    clc
    adc #$08
    cmp $0203
    bcc NextBall
    sta var
    lda $0203
    clc
    adc #$10
    cmp var
    bcc NextBall
    jsr GameOver
    rts
  NextBall:
    inx
    cpx balls
    bne CheckBallR1
  CPCFinished:
    rts

FlashStart:
  lda #$22
  sta toPPUHi
  lda #$8A
  sta toPPULo
  lda #$0B
  sta toPPULength
  ldx #$00
  FSLoop:
    lda #$00
    sta time
    sta frames
    txa
    and #$01
    bne ShowNothing
    ShowStart:
      lda #$E0
      sta toPPULocHi
      lda #$00
      sta toPPULocLo
      jmp SetNeedToPPU
    ShowNothing:
      lda #$E2
      sta toPPULocHi
      lda #$8A
      sta toPPULocLo
    SetNeedToPPU:
      lda #$01
      sta needToPPU
    FSLoopWait:
      jsr WaitFrame
      lda frames
      cmp #$08
      bne FSLoopWait
      inx
      cpx #$06
      beq FSFinished
      jmp FSLoop
  FSFinished:
    rts

DoFrame:
  jsr ReadController
  lda gameState
  cmp #$01
  beq InGame
  cmp #$02
  beq GameOverScreen
  MenuScreen:
    inc prngSeed
    lda controller
    and #%00010000
    beq Finished
    jsr FlashStart
    lda #$01
    sta gameState
    jsr InitPlay
  InGame:
    jsr ReadController
    jsr HandleControllerInput
    jsr SpawnBall
    jsr MoveBalls
    jsr CheckPlayerCollision
    jsr IncrementScore
    jmp Finished
  GameOverScreen:
    lda #$00
    sta gameState
    jsr InitMenuScreen
  Finished:
    jsr WaitFrame
    jmp DoFrame

NMI:
  pha
  txa
  pha
  tya
  pha
  lda #$00
  sta $2003
  lda #$02
  sta $4014
  ppuUpdate:
    lda needToPPU
    beq ppuRegUpdate
    CopyToPPUInit toPPUHi, toPPULo
    ldy #$00
    LoadPPULoop:
      lda [toPPULocLo], Y
      sta $2007
      iny
      cpy toPPULength
      bne LoadPPULoop
    lda #$00
    sta needToPPU
  ppuRegUpdate:
    lda needPPUReg
    beq ScoreUpdate
    lda soft2001
    sta $2001
    lda soft2000
    sta $2000
    lda #$00
    sta needPPUReg
  ScoreUpdate:
    lda needScore
    beq ScrollUpdate
    lda gameState
    cmp #$01
    bne ScrollUpdate
    jsr DrawScore
    lda #$00
    sta needScore
  ScrollUpdate:
    bit $2002
    lda xscroll
    sta $2005
    lda yscroll
    sta $2005
  nmiFinished:
    inc frames
    lda frames
    cmp #$3C
    bne FramesFinished
    lda #$00
    sta frames
    inc time
  FramesFinished:
    lda #$00
    sta sleeping
    pla
    tay
    pla
    tax
    pla
    rti

;;;;;;;;;;;;;;

  .bank 1
  .org $E000

  .include "backgrounds.asm"

palette:
  .db $0f,$17,$28,$39,$0f,$17,$28,$39,$0f,$17,$28,$39,$0f,$17,$28,$39
  .db $0f,$17,$28,$39,$0f,$17,$28,$39,$0f,$17,$28,$39,$0f,$17,$28,$39

sprites:
  .db $70, $02, $00, $70
  .db $70, $03, $00, $78 
  .db $78, $12, $00, $70 
  .db $78, $13, $00, $78 

  .org $FFFA
  .dw NMI
  .dw Reset
  .dw 0

;;;;;;;;;;;;;;

  .bank 2
  .org $0000
  .incbin "shuffle.chr"
