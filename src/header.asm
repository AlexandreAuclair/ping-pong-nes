.SEGMENT "HEADER"
  .BYTE "NES"
  .BYTE $1a ; ID
  .BYTE $02 ; 2 * 16kb ROM
  .BYTE $01 ; 1 * 8kb ROM
  .BYTE %00000001 ; mapper and mirroring
  .BYTE $00
  .BYTE $00
  .BYTE $00
  .BYTE $00
  .BYTE $00, $00, $00, $00 ; filler bytes

.SEGMENT "VECTORS"
  .WORD NMI
  .WORD RESET
  .WORD 0