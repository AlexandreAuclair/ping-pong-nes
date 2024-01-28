.INCLUDE "header.asm"

.SEGMENT "ZEROPAGE"

.INCLUDE "registers.inc"

; game constant
STATETITLE     = $00  ; displaying title screen
STATEPLAYING   = $01  ; move paddles/ball, check for collisions
STATEGAMEOVER  = $02  ; displaying game over screen

RIGHTWALL      = $F6 ; when ball reaches one of these, do something
TOPWALL        = $20
BOTTOMWALL     = $D8
LEFTWALL       = $02

PADDLE1X       = $08  ; horizontal position for paddles, doesnt move
PADDLE2X       = $F0

; game variable
gamestate: .res 1
ballx: .res 1
bally: .res 1
ballup: .res 1
balldown: .res 1
ballleft: .res 1
ballright: .res 1
ballspeedx: .res 1
ballspeedy: .res 1
paddle1ytop: .res 1
paddle1ymid: .res 1
paddle1ybot: .res 1
score1: .res 1
score2: .res 1
buttons1: .res 1
buttons2: .res 1
paddle2ytop: .res 1
paddle2ymid: .res 1
paddle2ybot: .res 1
pointerLo: .res 1
pointerHi: .res 1


.SEGMENT "STARTUP"

RESET:
  .INCLUDE "init.asm"

  JSR vblankwait
  JSR LoadPalettes

.SEGMENT "CODE"

; initial values for variable
  LDA #$01
  STA balldown
  STA ballleft
  LDA #$00
  STA ballup
  STA ballright
  STA score1
  STA score2

  LDA #$50
  STA bally

  LDA #$80
  STA ballx

  LDA #$01
  STA ballspeedx
  STA ballspeedy

  LDA #$78
  STA paddle1ytop
  STA paddle2ytop

  LDA #$80
  STA paddle1ymid
  STA paddle2ymid

  LDA #$88
  STA paddle1ybot
  STA paddle2ybot

;;:Set starting game state

  JSR UnloadBackground1    

  LDA #$0F
  STA APU_STATUS



  
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA PPU_CTRL
  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA PPU_MASK

Forever:
  JMP Forever     ;jump back to Forever, infinite loop, waiting for NMI

;----------------------------------NMI---------------------------------

NMI:
  LDA #$00
  STA PPU_OAM_ADDR
  LDA #$02
  STA OAM_DMA

  JSR DrawScore

  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA PPU_CTRL
  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA PPU_MASK
  LDA #$00
  STA PPU_SCROLL
  STA PPU_SCROLL


  ;;;all graphics updates done by PPU here, run game engine

  JSR ReadController1  ;;get the current button data for player 1
  JSR ReadController2  ;;get the current button data for player 2

GameEngine:  
  LDA gamestate
  CMP #STATETITLE
  BEQ EngineTitle    ;;game is displaying title screen
    
  LDA gamestate
  CMP #STATEGAMEOVER
  BEQ EngineGameOver  ;;game is displaying ending screen
  
  LDA gamestate
  CMP #STATEPLAYING
  BEQ EnginePlaying   ;;game is playing
GameEngineDone:  
  
  JSR UpdateSprites  ;;set ball/paddle sprites from positions
  
  RTI             ; return from interrupt

;----------------------Engine-----------------------------------------
;;;;;;;;
 
EngineTitle:
  ;;if start button pressed
  ;;  turn screen off
  ;;  load game screen
  ;;  set starting paddle/ball position
  ;;  go to Playing State
  ;;  turn screen on
  JSR LoadBackground1
  LDA #$01
  STA balldown
  STA ballleft
  LDA #$00
  STA ballup
  STA ballright
  STA score1
  STA score2

  LDA #$50
  STA bally

  LDA #$80
  STA ballx

  LDA #$02
  STA ballspeedx
  STA ballspeedy
titleloop:  
  LDX buttons1
  CPX #$10
  BNE GameEngineDone
jeuState:
  LDA #STATEPLAYING
  STA gamestate
  JSR UnloadBackground1
  JSR LoadBackgroundJeu 
  JMP GameEngineDone

;;;;;;;;; 
 
EngineGameOver:
  ;;if start button pressed
  ;;  turn screen off
  ;;  load title screen
  ;;  go to Title State
  ;;  turn screen on 
  JSR LoadBackground2
  JSR LoadNoSprite
EndingLoop:
  LDX buttons1
  CPX #$80
  BNE GameEngineDone
titleState:
  LDA #STATETITLE
  STA gamestate
  JMP GameEngineDone
 
;;;;;;;;;;;
 
EnginePlaying:
  JSR LoadSprite

MoveBallRight:
  LDA ballright
  BEQ MoveBallRightDone   ;;if ballright=0, skip this section

  LDA ballx
  CLC
  ADC ballspeedx        ;;ballx position = ballx + ballspeedx
  STA ballx

  LDA ballx
  CMP #RIGHTWALL
  BCC MoveBallRightDone      ;;if ball x < right wall, still on screen, skip next section
  LDA #$80
  STA ballx
  STA bally
  ;;in real game, give point to player 1, reset ball
  INC score1
  JSR play_noteGs2
  LDA score1
  CMP #$0A
  BNE MoveBallRightDone
  LDA #STATEGAMEOVER
  STA gamestate
  JMP GameEngineDone
MoveBallRightDone:


MoveBallLeft:
  LDA ballleft
  BEQ MoveBallLeftDone   ;;if ballleft=0, skip this section

  LDA ballx
  SEC
  SBC ballspeedx        ;;ballx position = ballx - ballspeedx
  STA ballx

  LDA ballx
  CMP #LEFTWALL
  BCS MoveBallLeftDone      ;;if ball x > left wall, still on screen, skip next section
  LDA #$80
  STA ballx
  STA bally
  ;;in real game, give point to player 2, reset ball
  INC score2
  JSR play_noteGs2
  LDA score2
  CMP #$0A
  BNE MoveBallLeftDone
  LDA #STATEGAMEOVER
  STA gamestate
  JMP GameEngineDone
MoveBallLeftDone:


MoveBallUp:
  LDA ballup
  BEQ MoveBallUpDone   ;;if ballup=0, skip this section

  LDA bally
  SEC
  SBC ballspeedy        ;;bally position = bally - ballspeedy
  STA bally

  LDA bally
  CMP #TOPWALL
  BCS MoveBallUpDone      ;;if ball y > top wall, still on screen, skip next section
  JSR play_noteC4
  LDA #$01
  STA balldown
  LDA #$00
  STA ballup         ;;bounce, ball now moving down
MoveBallUpDone:


MoveBallDown:
  LDA balldown
  BEQ MoveBallDownDone   ;;if ballup=0, skip this section

  LDA bally
  CLC
  ADC ballspeedy        ;;bally position = bally + ballspeedy
  STA bally

  LDA bally
  CMP #BOTTOMWALL
  BCC MoveBallDownDone      ;;if ball y < bottom wall, still on screen, skip next section
  JSR play_noteC4
  LDA #$00
  STA balldown
  LDA #$01
  STA ballup         ;;bounce, ball now moving down
MoveBallDownDone:

MovePaddleUp:
  ;;if up button pressed
  ;;  if paddle top > top wall
  ;;    move paddle top and bottom up
  LDX buttons1
  CPX #$08
  BNE checkPaddle2Up
PaddleSprite1Up:
  LDX #$00
PaddleSprite1UpLoop:
  LDA paddle1ytop, x
  SEC
  SBC #$03
  STA paddle1ytop, x
  INX
  CPX #$03
  BNE PaddleSprite1UpLoop
checkPaddle2Up:
  LDX buttons2
  CPX #$08
  BNE MovePaddleUpDone
PaddleSprite2Up:
  LDX #$00
PaddleSprite2UpLoop:
  LDA paddle2ytop, x
  SEC
  SBC #$03
  STA paddle2ytop, x
  INX
  CPX #$03
  BNE PaddleSprite2UpLoop
MovePaddleUpDone:

MovePaddleDown:
  ;;if down button pressed
  ;;  if paddle bottom < bottom wall
  ;;    move paddle top and bottom down
  LDX buttons1
  CPX #$04
  BNE checkPaddle2Down
PaddleSprite1Do:
  LDX #$00
PaddleSprite1DoLoop:
  LDA paddle1ytop, x
  CLC
  ADC #$03
  STA paddle1ytop, x
  INX
  CPX #$03
  BNE PaddleSprite1DoLoop
checkPaddle2Down:
  LDX buttons2
  CPX #$04
  BNE MovePaddleDownDone
PaddleSprite2Do:
  LDX #$00
PaddleSprite2DoLoop:
  LDA paddle2ytop, x
  CLC
  ADC #$03
  STA paddle2ytop, x
  INX
  CPX #$03
  BNE PaddleSprite2DoLoop
MovePaddleDownDone:
  
CheckPaddleCollision:
  ;;if ball x < paddle1x
  ;;  if ball y > paddle y top
  ;;    if ball y < paddle y bottom
  ;;      bounce, ball now moving left
  LDA ballx
  CMP #PADDLE1X +6
  BCS CheckPaddle2
  LDA bally
  CMP paddle1ytop
  BCC CheckPaddle2
  CMP paddle1ybot
  BCS CheckPaddle2
  LDA #$01
  STA ballright
  LDA #$00
  STA ballleft         ;;bounce, ball now moving left
  JSR play_noteCs4
CheckPaddle2:
  LDA ballx
  CMP #PADDLE2X
  BCC CheckPaddleCollisionDone
  LDA bally
  CMP paddle2ytop
  BCC CheckPaddleCollisionDone
  CMP paddle2ybot
  BCS CheckPaddleCollisionDone
  LDA #$00
  STA ballright
  LDA #$01
  STA ballleft         ;;bounce, ball now moving right
  JSR play_noteCs4
CheckPaddleCollisionDone:

  JMP GameEngineDone

;----------subroutines---------------

vblankwait:       ; First wait for vblank to make sure PPU is ready
  BIT PPU_STATUS
  BPL vblankwait
  RTS

LoadPalettes:
  LDA #$3F
  STA PPU_ADDRESS
  LDA #$00
  STA PPU_ADDRESS
  LDX #$00                ; start out at 0
LoadPalettesLoop:
  LDA PaletteData, x      ; load data from address (PaletteData + the value in x)
                          ; 1st time through loop it will load PaletteData+0
                          ; 2nd time through loop it will load PaletteData+1
                          ; 3rd time through loop it will load PaletteData+2
                          ; etc
  STA PPU_DATA             ; write to PPU
  INX                     
  CPX #$20                ; Compare X to hex $20, decimal 32
  BNE LoadPalettesLoop    ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                          ; if compare was equal to 32, keep going down
  RTS


LoadSprite:
  LDA paddle1ytop
  STA $0204
  LDA #PADDLE1X
  STA $0207

  LDA paddle1ymid
  STA $0208
  LDA #PADDLE1X
  STA $020B

  LDA paddle1ybot
  STA $020C
  LDA #PADDLE1X
  STA $020F

  LDA paddle2ytop
  STA $0210
  LDA #PADDLE2X
  STA $0213

  LDA paddle2ymid
  STA $0214
  LDA #PADDLE2X
  STA $0217

  LDA paddle2ybot
  STA $0218
  LDA #PADDLE2X
  STA $021B
  RTS

LoadNoSprite:
  LDA #$00
  LDX #$00
NoSpriteLoop:
  STA SPRITE_ADDR,x
  INX
  CPX #$1C
  BNE NoSpriteLoop
  RTS

ReadController1:
  LDA #$01
  STA JoyP1
  LDA #$00
  STA JoyP1
  LDX #$08
ReadController1Loop:
  LDA JoyP1
  LSR A
  ROL buttons1
  DEX
  BNE ReadController1Loop
  RTS

ReadController2:
  LDA #$01
  STA JoyP2
  LDA #$00
  STA JoyP2
  LDX #$08
ReadController2Loop:
  LDA JoyP2
  LSR A
  ROL buttons2
  DEX
  BNE ReadController2Loop
  RTS

DrawScore:
  LDA #$18
  STA $02F8

  LDA score1
  ADC #$01
  STA $02F9
  
  LDA #$00
  STA $02FA
  
  LDA #$78
  STA $02FB
    
  LDA #$18
  STA $02FC

  LDA score2
  ADC #$02
  STA $02FD
  
  LDA #$00
  STA $02FE
  
  LDA #$88
  STA $02FF
  RTS

UpdateSprites:
  LDA bally  ;;update all ball sprite info
  STA $0200
  
  LDA #$01
  STA $0201
  
  LDA #$00
  STA $0202
  
  LDA ballx
  STA $0203
  
  ;;update paddle sprites
  RTS

play_noteCs4:
    LDA #$8F    ;Duty 02, Volume F
    STA SQ1_ENV
    LDA #$08    ;Set Negate flag so low notes aren't silenced
    STA SQ1_SWEEP
    
    ;LDA current_note
    ;ASL A               ;multiply by 2 because we are indexing into a table of words
    ;TAY
    LDA #$C9             ;read the low byte of the period
    STA SQ1_LO           ;write to SQ1_LO
    LDA #$00             ;read the high byte of the period
    STA SQ1_HI           ;write to SQ1_HI
    RTS

play_noteC4:
    LDA #$8F    ;Duty 02, Volume F
    STA SQ1_ENV
    LDA #$08    ;Set Negate flag so low notes aren't silenced
    STA SQ1_SWEEP
    
    ;LDA current_note
    ;ASL A               ;multiply by 2 because we are indexing into a table of words
    ;TAY
    LDA #$FD             ;read the low byte of the period
    STA SQ1_LO           ;write to SQ1_LO
    LDA #$00             ;read the high byte of the period
    STA SQ1_HI           ;write to SQ1_HI
    RTS

play_noteGs2:
    LDA #$8F    ;Duty 02, Volume F
    STA SQ1_ENV
    LDA #$08    ;Set Negate flag so low notes aren't silenced
    STA SQ1_SWEEP
    
    ;LDA current_note
    ;ASL A               ;multiply by 2 because we are indexing into a table of words
    ;TAY
    LDA #$1A             ;read the low byte of the period
    STA SQ1_LO           ;write to SQ1_LO
    LDA #$02             ;read the high byte of the period
    STA SQ1_HI           ;write to SQ1_HI
    RTS

;;----------------------------------- Background ------------------------------------;;
LoadBackground1:
  LDA PPU_STATUS
  LDA #$21
  STA PPU_ADDRESS
  LDA #$80
  STA PPU_ADDRESS
  LDX #$00
Background1Loop:
  LDA Background1, X
  STA PPU_DATA
  INX
  CPX #$60
  BNE Background1Loop
LoadAttribute:
  LDA PPU_STATUS         ; read PPU status to reset the high/low latch
  LDA #$23
  STA PPU_ADDRESS        ; write the high byte of $23C0 address
  LDA #$C0
  STA PPU_ADDRESS        ; write the low byte of $23C0 address
  LDX #$00              ; start out at 0
LoadAttributeLoop:
  LDA attribute, x      ; load data from address (attribute + the value in x)
  STA PPU_DATA           ; write to PPU
  INX                   ; X = X + 1
  CPX #$08              ; Compare X to hex $08, decimal 8 - copying 8 bytes
  BNE LoadAttributeLoop
  RTS

UnloadBackground1:
  LDA #$00
  STA PPU_CTRL
  STA PPU_MASK
  LDA PPU_STATUS
  LDA #$20
  STA PPU_ADDRESS
  LDA #$00
  STA PPU_ADDRESS
  LDX #$00
  LDY #$00
UnloadLoopOut:
UnloadLoop:
  LDA #$FF
  STA PPU_DATA
  INX
  BNE UnloadLoop
  INY
  CPY #$04
  BNE UnloadLoopOut
  LDA #%10010000
  STA PPU_CTRL
  LDA #%00011110
  STA PPU_MASK
  RTS


LoadBackground2:
  LDA PPU_STATUS
  LDA #$29
  STA PPU_ADDRESS
  LDA #$80
  STA PPU_ADDRESS
  LDX #$00
Background2Loop:
  LDA Background2, X
  STA PPU_DATA
  INX
  CPX #$60
  BNE Background2Loop
  JSR LoadAttribute
  RTS


LoadBackgroundJeu:
  LDA #$00
  STA PPU_CTRL
  STA PPU_MASK
  LDA PPU_STATUS        ; read PPU status to reset the high/low latch
  LDA #$20
  STA PPU_ADDRESS       ; write the high byte of $2000 address
  LDA #$00
  STA PPU_ADDRESS       ; write the low byte of $2000 address

  LDA backgroundAddrLo
  STA pointerLo         ; put the low byte of the address of background into pointer
  LDA backgroundAddrHi
  STA pointerHi         ; put the high byte of the address into pointer
  
  LDX #$00              ; start at pointer + 0
  LDY #$00
OutsideLoop:
  
InsideLoop:
  LDA (pointerLo), y  ; copy one background byte from address in pointer plus Y
  STA PPU_DATA        ; this runs 256 * 4 times
  
  INY                 ; inside loop counter
  CPY #$00
  BNE InsideLoop      ; run the inside loop 256 times before continuing down
  
  INC pointerHi       ; low byte went 0 to 256, so high byte needs to be changed now
  
  INX
  CPX #$04
  BNE OutsideLoop     ; run the outside loop 256 times before continuing down
  LDA #%10010000
  STA PPU_CTRL
  LDA #%00011110
  STA PPU_MASK
  RTS

;---------------------------------------DATA-----------------------------------
PaletteData:
  .BYTE $0F,$30,$30,$30,  $0F,$30,$30,$30,  $0F,$30,$30,$30,  $0F,$30,$30,$30   ;;background palette
  .BYTE $0F,$30,$30,$30,  $0F,$30,$30,$30,  $0F,$30,$30,$30,  $0F,$30,$30,$30   ;;sprite palette

backgroundAddrLo:
  .BYTE <BackgroundJeu
backgroundAddrHi:
  .BYTE >BackgroundJeu

Background1:
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $09,$0A,$0B,$0C 
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

Background2:
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $02,$03,$04,$05,$06,$07,$05,$08 
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

BackgroundJeu:
  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 1
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 2
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 3
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 4
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 5
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 6
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 7
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 8
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 9
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 10
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 11
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 12
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 13
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 14
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 15
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 16
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 17
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 18
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 19
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 20
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 21
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 22
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 23
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 24
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 25
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 26
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 27
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 28
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 29
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

  .BYTE $00,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00  ;;row 30
  .BYTE $01,$00,$00,$00,$00,$00,$00,$00, $00,$00,$00,$00,$00,$00,$00,$00

attribute:
  .BYTE %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .BYTE %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .BYTE %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .BYTE %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .BYTE %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .BYTE %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .BYTE %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .BYTE %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000

  .BYTE $24,$24,$24,$24, $47,$47,$24,$24 
  .BYTE $47,$47,$47,$47, $47,$47,$24,$24 
  .BYTE $24,$24,$24,$24 ,$24,$24,$24,$24
  .BYTE $24,$24,$24,$24, $55,$56,$24,$24  ;;brick bottoms
  .BYTE $47,$47,$47,$47, $47,$47,$24,$24 
  .BYTE $24,$24,$24,$24 ,$24,$24,$24,$24
  .BYTE $24,$24,$24,$24, $55,$56,$24,$24 

.SEGMENT "CHARS"
  .INCLUDE "charset.asm"