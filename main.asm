; =============================================================================
; LSTamagotchi - Fase 2
; PIC18F4321 @ 32 MHz (8 MHz interno + PLL x4)
; =============================================================================

    LIST P=18F4321
    #include <p18f4321.inc>

; =============================================================================
; BITS DE CONFIGURACION
; =============================================================================

; Oscilador interno, RA6/RA7 como I/O
    CONFIG OSC = INTIO2
; Power-up Timer activado
    CONFIG PWRT = ON
; Watchdog desactivado
    CONFIG WDT = OFF
; RE3 = reset (PCI)
    CONFIG MCLRE = ON
; PORTB como digital I/O
    CONFIG PBADEN = DIG
; Low Voltage Programming desactivado
    CONFIG LVP = OFF

; =============================================================================
; CONSTANTES
; =============================================================================

NUM_PIXELS  EQU D'64'
WS_PIN      EQU 4               ; RA4

; Brillo reducido para tests (0xFF = max, 0x20 = suave)
BRIGHT      EQU 0x20

; =============================================================================
; VARIABLES EN RAM (Access Bank)
; =============================================================================

    UDATA_ACS

delay_cnt1  RES 1
delay_cnt2  RES 1
delay_cnt3  RES 1

ws_data     RES 1               ; byte que se esta enviando
ws_bit_cnt  RES 1               ; contador de bits (8)
ws_pix_cnt  RES 1               ; contador de pixeles
ws_temp     RES 1               ; variable temporal

; =============================================================================
; VECTOR DE RESET
; =============================================================================

    ORG 0x0000
    GOTO    init

; =============================================================================
; VECTOR DE INTERRUPCION ALTA PRIORIDAD
; =============================================================================

    ORG 0x0008
    RETFIE

; =============================================================================
; VECTOR DE INTERRUPCION BAJA PRIORIDAD
; =============================================================================

    ORG 0x0018
    RETFIE

; =============================================================================
; INICIALIZACION
; =============================================================================

    ORG 0x0020

init:
    ; --- Configurar oscilador a 8 MHz interno ---
    MOVLW   B'01110000'
    MOVWF   OSCCON

    ; --- Activar PLL x4 (8 MHz x 4 = 32 MHz) ---
    BSF     OSCTUNE, PLLEN

    ; --- Esperar a que el oscilador sea estable ---
    BTFSS   OSCCON, IOFS
    BRA     $-2

    ; --- Todos los pines como digitales ---
    MOVLW   0x0F
    MOVWF   ADCON1

    ; --- Desactivar comparadores ---
    MOVLW   0x07
    MOVWF   CMCON

    ; --- RA4 como salida (WS2812B data) ---
    BCF     TRISA, WS_PIN
    BCF     LATA, WS_PIN

    ; --- Reset inicial de la tira LED ---
    CALL    ws_reset

; =============================================================================
; MAIN LOOP - Tests WS2812B
;
; Test 1: Todos los LEDs en rojo
; Test 2: Solo el primer LED en verde
; Test 3: Fila 0 verde + pixel 8 rojo (determinar orden lineal/serpentina)
; =============================================================================

main_loop:
    ; --- Test 1: Todos rojo ---
    CALL    ws_test_all_red
    CALL    delay_500ms
    CALL    delay_500ms
    CALL    delay_500ms
    CALL    delay_500ms

    ; --- Test 2: Solo pixel 0 verde ---
    CALL    ws_test_first_green
    CALL    delay_500ms
    CALL    delay_500ms
    CALL    delay_500ms
    CALL    delay_500ms

    ; --- Test 3: Fila 0 verde + pixel 8 rojo ---
    CALL    ws_test_order
    CALL    delay_500ms
    CALL    delay_500ms
    CALL    delay_500ms
    CALL    delay_500ms

    BRA     main_loop

; =============================================================================
; WS2812B DRIVER
; =============================================================================

; -----------------------------------------------------------------------------
; ws_send_byte - Envia un byte por RA4 (MSB primero)
; Entrada: WREG = byte a enviar
;
; Timing por bit a 32 MHz (Tcy = 125ns):
;   Bit 0: T0H = 3 ciclos (375ns), T0L = 8 ciclos (1000ns)
;   Bit 1: T1H = 6 ciclos (750ns), T1L = 5 ciclos (625ns)
; Total por bit: 11 ciclos (1375ns)
; -----------------------------------------------------------------------------

ws_send_byte:
    MOVWF   ws_data
    MOVLW   D'8'
    MOVWF   ws_bit_cnt

ws_bit_loop:
    BSF     LATA, WS_PIN       ; HIGH
    NOP
    BTFSS   ws_data, 7         ; test MSB
    BCF     LATA, WS_PIN       ; LOW si bit=0 (T0H = 3 ciclos)
    NOP
    NOP
    BCF     LATA, WS_PIN       ; LOW siempre (T1H = 6 ciclos)
    RLNCF   ws_data, F         ; rotar para siguiente bit
    DECFSZ  ws_bit_cnt, F
    BRA     ws_bit_loop
    RETURN

; -----------------------------------------------------------------------------
; ws_reset - Senal de reset (>50us LOW en RA4)
; 134 x 3 ciclos x 125ns = ~50us
; -----------------------------------------------------------------------------

ws_reset:
    BCF     LATA, WS_PIN
    MOVLW   D'134'
    MOVWF   ws_temp
ws_reset_loop:
    DECFSZ  ws_temp, F
    BRA     ws_reset_loop
    RETURN

; =============================================================================
; TEST 1: Todos los LEDs en rojo
; Envia 64 pixeles: G=0, R=BRIGHT, B=0
; =============================================================================

ws_test_all_red:
    BCF     INTCON, GIE
    MOVLW   NUM_PIXELS
    MOVWF   ws_pix_cnt

ws_tar_loop:
    MOVLW   0x00
    CALL    ws_send_byte        ; G = 0
    MOVLW   BRIGHT
    CALL    ws_send_byte        ; R = BRIGHT
    MOVLW   0x00
    CALL    ws_send_byte        ; B = 0
    DECFSZ  ws_pix_cnt, F
    BRA     ws_tar_loop

    CALL    ws_reset
    BSF     INTCON, GIE
    RETURN

; =============================================================================
; TEST 2: Solo el primer LED en verde, resto apagado
; Pixel 0: G=BRIGHT, R=0, B=0
; Pixeles 1-63: apagados
; =============================================================================

ws_test_first_green:
    BCF     INTCON, GIE

    ; Pixel 0: verde
    MOVLW   BRIGHT
    CALL    ws_send_byte        ; G = BRIGHT
    MOVLW   0x00
    CALL    ws_send_byte        ; R = 0
    MOVLW   0x00
    CALL    ws_send_byte        ; B = 0

    ; Pixeles 1-63: apagados
    MOVLW   NUM_PIXELS - 1
    MOVWF   ws_pix_cnt

ws_tfg_loop:
    MOVLW   0x00
    CALL    ws_send_byte
    MOVLW   0x00
    CALL    ws_send_byte
    MOVLW   0x00
    CALL    ws_send_byte
    DECFSZ  ws_pix_cnt, F
    BRA     ws_tfg_loop

    CALL    ws_reset
    BSF     INTCON, GIE
    RETURN

; =============================================================================
; TEST 3: Determinar orden lineal vs serpentina
; Pixeles 0-7 (fila 0): verde
; Pixel 8: rojo
; Pixeles 9-63: apagados
;
; Si lineal:     el LED rojo esta al inicio de la fila 2 (izquierda)
; Si serpentina: el LED rojo esta al final de la fila 2 (derecha)
; =============================================================================

ws_test_order:
    BCF     INTCON, GIE

    ; Pixeles 0-7: verde
    MOVLW   D'8'
    MOVWF   ws_pix_cnt

ws_to_green:
    MOVLW   BRIGHT
    CALL    ws_send_byte        ; G
    MOVLW   0x00
    CALL    ws_send_byte        ; R
    MOVLW   0x00
    CALL    ws_send_byte        ; B
    DECFSZ  ws_pix_cnt, F
    BRA     ws_to_green

    ; Pixel 8: rojo
    MOVLW   0x00
    CALL    ws_send_byte        ; G
    MOVLW   BRIGHT
    CALL    ws_send_byte        ; R
    MOVLW   0x00
    CALL    ws_send_byte        ; B

    ; Pixeles 9-63: apagados
    MOVLW   D'55'
    MOVWF   ws_pix_cnt

ws_to_off:
    MOVLW   0x00
    CALL    ws_send_byte
    MOVLW   0x00
    CALL    ws_send_byte
    MOVLW   0x00
    CALL    ws_send_byte
    DECFSZ  ws_pix_cnt, F
    BRA     ws_to_off

    CALL    ws_reset
    BSF     INTCON, GIE
    RETURN

; =============================================================================
; RUTINA DE DELAY ~500 ms
; =============================================================================

delay_500ms:
    MOVLW   D'21'
    MOVWF   delay_cnt3
loop3:
    MOVLW   D'100'
    MOVWF   delay_cnt2
loop2:
    MOVLW   D'190'
    MOVWF   delay_cnt1
loop1:
    DECFSZ  delay_cnt1, F
    BRA     loop1
    DECFSZ  delay_cnt2, F
    BRA     loop2
    DECFSZ  delay_cnt3, F
    BRA     loop3
    RETURN

; =============================================================================

    END
