; =============================================================================
; LSTamagotchi - Fase 2
; PIC18F4321 @ 32 MHz (8 MHz interno + PLL x4)
; =============================================================================

    LIST P=18F4321
    #include <p18f4321.inc>

; =============================================================================
; BITS DE CONFIGURACION
; =============================================================================

; Oscilador interno, RA6/RA7 como I/O digital
    CONFIG OSC = INTIO2

; Fail-Safe Clock Monitor y switchover desactivados
    CONFIG FCMEN = OFF
    CONFIG IESO = OFF

; Power-up Timer activado
    CONFIG PWRT = ON

; Brown-out Reset desactivado
    CONFIG BOR = OFF
    CONFIG BORV = 3

; Watchdog Timer desactivado
    CONFIG WDT = OFF
    CONFIG WDTPS = 32768

; MCLR activado (RE3 = pin de reset = PCI)
    CONFIG MCLRE = ON

; Timer1 low power desactivado
    CONFIG LPT1OSC = OFF

; PORTB<4:0> como digital I/O (no analogico)
    CONFIG PBADEN = OFF

; CCP2 en RC1
    CONFIG CCP2MX = PORTC

; Stack overflow reset activado
    CONFIG STVREN = ON

; Low Voltage Programming desactivado
    CONFIG LVP = OFF

; Debug desactivado
    CONFIG DEBUG = OFF

; Proteccion de codigo desactivada
    CONFIG CP0 = OFF
    CONFIG CP1 = OFF
    CONFIG CP2 = OFF
    CONFIG CP3 = OFF
    CONFIG CPB = OFF
    CONFIG CPD = OFF

; Proteccion de escritura desactivada
    CONFIG WRT0 = OFF
    CONFIG WRT1 = OFF
    CONFIG WRT2 = OFF
    CONFIG WRT3 = OFF
    CONFIG WRTB = OFF
    CONFIG WRTC = OFF
    CONFIG WRTD = OFF

; Proteccion de lectura de tabla desactivada
    CONFIG EBTR0 = OFF
    CONFIG EBTR1 = OFF
    CONFIG EBTR2 = OFF
    CONFIG EBTR3 = OFF
    CONFIG EBTRB = OFF

; =============================================================================
; VARIABLES EN RAM
; =============================================================================

    UDATA_ACS

delay_cnt1  RES 1
delay_cnt2  RES 1
delay_cnt3  RES 1

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
    MOVLW   B'01110000'         ; IRCF<2:0> = 111 = 8 MHz, SCS<1:0> = 00
    MOVWF   OSCCON

    ; --- Activar PLL x4 (8 MHz x 4 = 32 MHz) ---
    BSF     OSCTUNE, PLLEN

    ; --- Esperar a que el oscilador sea estable ---
    BTFSS   OSCCON, IOFS
    BRA     $-2

    ; --- Todos los pines como digitales (desactivar ADC) ---
    MOVLW   0x0F
    MOVWF   ADCON1

    ; --- Desactivar comparadores ---
    MOVLW   0x07
    MOVWF   CMCON

    ; --- Configurar puertos ---
    ; Por ahora: RA4 como salida (test LED blink)
    ; El resto se configurara en tareas posteriores
    BCF     TRISA, 4            ; RA4 = salida
    BCF     LATA, 4             ; RA4 = LOW inicial

    ; --- Test: parpadear RA4 a ~1 Hz ---

main_loop:
    BSF     LATA, 4             ; RA4 = HIGH (LED encendido)
    CALL    delay_500ms
    BCF     LATA, 4             ; RA4 = LOW (LED apagado)
    CALL    delay_500ms
    BRA     main_loop

; =============================================================================
; RUTINA DE DELAY ~500 ms
; A 32 MHz: Fosc/4 = 8 MHz, Tcy = 125 ns
; Triple bucle anidado:
;   cnt3 x cnt2 x cnt1 x 3 ciclos = ~500 ms
;   21 x 100 x 190 x 3 x 125ns ~= 500 ms (aprox, ajustar si necesario)
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
    DECFSZ  delay_cnt1, F       ; 1 ciclo (o 2 si skip)
    BRA     loop1               ; 2 ciclos
    DECFSZ  delay_cnt2, F
    BRA     loop2
    DECFSZ  delay_cnt3, F
    BRA     loop3
    RETURN

; =============================================================================

    END
