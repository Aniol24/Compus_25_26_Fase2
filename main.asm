LIST P=PIC18F4321 F=INHX32
#include <p18f4321.inc>

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

ORG 0x0000
GOTO MAIN

ORG 0x0008
RETFIE FAST

ORG 0x0018
RETFIE FAST

;-------------------------------------------------------------------------------
;                              Variables
;-------------------------------------------------------------------------------

; Contadores para delays
Delay_Cnt1          EQU 0x001
Delay_Cnt2          EQU 0x002
Delay_Cnt3          EQU 0x003

; WS2812B
WS_Dato             EQU 0x004       ; byte que se esta enviando
WS_Cont_Bits        EQU 0x005       ; contador de bits (8)
WS_Cont_Pixels      EQU 0x006       ; contador de pixeles
WS_Temp             EQU 0x007       ; variable temporal

; Menu
Menu_State          EQU 0x008       ; 0=Jugar, 1=Alimentar, 2=Reset

; Debounce
Part_Low_Rebots     EQU 0x009
Part_High_Rebots    EQU 0x00A

; Constantes
NUM_PIXELS          EQU D'64'       ; 8x8 = 64 LEDs
BRILLO              EQU 0x20        ; brillo reducido para tests

;-------------------------------------------------------------------------------
;                        Configuracion inicial
;-------------------------------------------------------------------------------

Init_Oscilador
    ; Oscilador interno a 8 MHz
    MOVLW b'01110000'
    MOVWF OSCCON,0

    ; Activar PLL x4 (8 MHz x 4 = 32 MHz)
    BSF OSCTUNE,6,0

    ; Esperar a que el oscilador sea estable
Espera_Estable
    BTFSS OSCCON,2,0
    GOTO Espera_Estable
RETURN

Init_Puertos
    ; Todos los pines como digitales (desactivar ADC)
    MOVLW 0x0F
    MOVWF ADCON1,0

    ; Desactivar comparadores
    MOVLW 0x07
    MOVWF CMCON,0

    ; RA3, RA4, RA5 como salida
    BCF TRISA,3,0
    BCF TRISA,4,0
    BCF TRISA,5,0
    BCF LATA,3,0
    BCF LATA,4,0
    BCF LATA,5,0

    ; RE0, RE1 como salida (LED RGB verde y azul)
    BCF TRISE,0,0
    BCF TRISE,1,0
    BCF LATE,0,0
    BCF LATE,1,0

    ; RB1, RB2, RB3 como entrada (botones)
    BSF TRISB,1,0
    BSF TRISB,2,0
    BSF TRISB,3,0

    ; Activar pull-ups internas de PORTB
    BCF INTCON2,RBPU,0
RETURN

;-------------------------------------------------------------------------------
;                           LED RGB Menu
;-------------------------------------------------------------------------------

; Jugar = cyan (R=0, G=1, B=1)
Posa_LED_Cyan
    BCF LATA,5,0
    BSF LATE,0,0
    BSF LATE,1,0
RETURN

; Alimentar = magenta (R=1, G=0, B=1)
Posa_LED_Magenta
    BSF LATA,5,0
    BCF LATE,0,0
    BSF LATE,1,0
RETURN

; Reset = blanco (R=1, G=1, B=1)
Posa_LED_Blanc
    BSF LATA,5,0
    BSF LATE,0,0
    BSF LATE,1,0
RETURN

; Actualitza el color del LED RGB segun Menu_State
Actualitza_LED_Menu
    MOVF Menu_State,0,0
    ; Si Menu_State == 0 -> Cyan
    BTFSC STATUS,Z,0
    GOTO ALE_Cyan
    ; Si Menu_State == 1 -> Magenta
    MOVLW D'1'
    CPFSEQ Menu_State,0
    GOTO ALE_Blanc
    GOTO ALE_Magenta

ALE_Cyan
    CALL Posa_LED_Cyan
RETURN

ALE_Magenta
    CALL Posa_LED_Magenta
RETURN

ALE_Blanc
    CALL Posa_LED_Blanc
RETURN

; Inicializar menu: estado 0 (Jugar), LEDs debug apagados, RGB cyan
Init_Menu
    CLRF Menu_State,0
    BCF LATA,3,0
    BCF LATA,4,0
    CALL Actualitza_LED_Menu
RETURN

;-------------------------------------------------------------------------------
;                          Bucle Menu
;-------------------------------------------------------------------------------

Bucle_Menu
    ; Comprobar RB1 (LeftOption)
    BTFSC PORTB,1,0
    GOTO Comprova_Right
    CALL Espera_Rebots
Deixa_Boto_Left
    BTFSS PORTB,1,0
    GOTO Deixa_Boto_Left
    CALL Espera_Rebots
    ; Debug LED: RA3=0, RA4=1
    BCF LATA,3,0
    BSF LATA,4,0
    ; Decrement ciclic: si 0 -> 2, sino -1
    MOVF Menu_State,0,0
    BTFSC STATUS,Z,0
    GOTO Menu_Left_Wrap
    DECF Menu_State,1,0
    GOTO Menu_Left_Fi
Menu_Left_Wrap
    MOVLW D'2'
    MOVWF Menu_State,0
Menu_Left_Fi
    CALL Actualitza_LED_Menu
    GOTO Bucle_Menu

Comprova_Right
    ; Comprobar RB3 (RightOption)
    BTFSC PORTB,3,0
    GOTO Comprova_Select
    CALL Espera_Rebots
Deixa_Boto_Right
    BTFSS PORTB,3,0
    GOTO Deixa_Boto_Right
    CALL Espera_Rebots
    ; Debug LED: RA3=1, RA4=0
    BSF LATA,3,0
    BCF LATA,4,0
    ; Increment ciclic: si 2 -> 0, sino +1
    INCF Menu_State,1,0
    MOVLW D'3'
    CPFSEQ Menu_State,0
    GOTO Menu_Right_Fi
    CLRF Menu_State,0
Menu_Right_Fi
    CALL Actualitza_LED_Menu
    GOTO Bucle_Menu

Comprova_Select
    ; Comprobar RB2 (Select)
    BTFSC PORTB,2,0
    GOTO Bucle_Menu
    CALL Espera_Rebots
Deixa_Boto_Select
    BTFSS PORTB,2,0
    GOTO Deixa_Boto_Select
    CALL Espera_Rebots
    ; Debug LED: RA3=1, RA4=1
    BSF LATA,3,0
    BSF LATA,4,0
    ; Saltar al modo seleccionado
    MOVF Menu_State,0,0
    BTFSC STATUS,Z,0
    GOTO Mode_Jugar
    MOVLW D'1'
    CPFSEQ Menu_State,0
    GOTO Mode_Reset
    GOTO Mode_Alimentar

;-------------------------------------------------------------------------------
;                       Modos (placeholder)
;-------------------------------------------------------------------------------

; Bucles muertos - solo reset (PCI/MCLR) sale de aqui
Mode_Jugar
    GOTO Mode_Jugar

Mode_Alimentar
    GOTO Mode_Alimentar

Mode_Reset
    GOTO Mode_Reset

;-------------------------------------------------------------------------------
;                           Driver WS2812B
;-------------------------------------------------------------------------------

; Envia un byte por RA4 (MSB primero)
; Entrada: W = byte a enviar
;
; Timing por bit a 32 MHz (Tcy = 125ns):
;   Bit 0: T0H = 3 ciclos (375ns), T0L = 8 ciclos (1000ns)
;   Bit 1: T1H = 6 ciclos (750ns), T1L = 5 ciclos (625ns)
WS_Envia_Byte
    MOVWF WS_Dato,0
    MOVLW D'8'
    MOVWF WS_Cont_Bits,0

WS_Bucle_Bit
    BSF LATA,4,0                    ; HIGH
    NOP
    BTFSS WS_Dato,7,0              ; testar MSB
    BCF LATA,4,0                    ; LOW si bit=0 (T0H = 3 ciclos)
    NOP
    NOP
    BCF LATA,4,0                    ; LOW siempre (T1H = 6 ciclos)
    RLNCF WS_Dato,1,0              ; rotar para siguiente bit
    DECFSZ WS_Cont_Bits,1,0
    BRA WS_Bucle_Bit
RETURN

; Senal de reset (>50us LOW en RA4)
; 134 x 3 ciclos x 125ns = ~50us
WS_Reset
    BCF LATA,4,0
    MOVLW D'134'
    MOVWF WS_Temp,0
WS_Reset_Bucle
    DECFSZ WS_Temp,1,0
    BRA WS_Reset_Bucle
RETURN

;-------------------------------------------------------------------------------
;                          Tests WS2812B
;-------------------------------------------------------------------------------

; Test 1: Todos los LEDs en rojo (G=0, R=BRILLO, B=0)
WS_Test_Todo_Rojo
    BCF INTCON,GIE,0
    MOVLW NUM_PIXELS
    MOVWF WS_Cont_Pixels,0

WS_TR_Bucle
    MOVLW 0x00
    CALL WS_Envia_Byte              ; G = 0
    MOVLW BRILLO
    CALL WS_Envia_Byte              ; R = BRILLO
    MOVLW 0x00
    CALL WS_Envia_Byte              ; B = 0
    DECFSZ WS_Cont_Pixels,1,0
    BRA WS_TR_Bucle

    CALL WS_Reset
    BSF INTCON,GIE,0
RETURN

; Test 2: Solo pixel 0 en verde, resto apagado
WS_Test_Primer_Verde
    BCF INTCON,GIE,0

    ; Pixel 0: verde
    MOVLW BRILLO
    CALL WS_Envia_Byte              ; G = BRILLO
    MOVLW 0x00
    CALL WS_Envia_Byte              ; R = 0
    MOVLW 0x00
    CALL WS_Envia_Byte              ; B = 0

    ; Pixeles 1-63: apagados
    MOVLW NUM_PIXELS - 1
    MOVWF WS_Cont_Pixels,0

WS_PV_Bucle
    MOVLW 0x00
    CALL WS_Envia_Byte
    MOVLW 0x00
    CALL WS_Envia_Byte
    MOVLW 0x00
    CALL WS_Envia_Byte
    DECFSZ WS_Cont_Pixels,1,0
    BRA WS_PV_Bucle

    CALL WS_Reset
    BSF INTCON,GIE,0
RETURN

; Test 3: Fila 0 verde + pixel 8 rojo (verificar orden lineal)
; Resultado confirmado: orden LINEAL (todas las filas izquierda a derecha)
WS_Test_Orden
    BCF INTCON,GIE,0

    ; Pixeles 0-7: verde (fila 0)
    MOVLW D'8'
    MOVWF WS_Cont_Pixels,0

WS_TO_Verde
    MOVLW BRILLO
    CALL WS_Envia_Byte              ; G
    MOVLW 0x00
    CALL WS_Envia_Byte              ; R
    MOVLW 0x00
    CALL WS_Envia_Byte              ; B
    DECFSZ WS_Cont_Pixels,1,0
    BRA WS_TO_Verde

    ; Pixel 8: rojo (inicio fila 1)
    MOVLW 0x00
    CALL WS_Envia_Byte              ; G
    MOVLW BRILLO
    CALL WS_Envia_Byte              ; R
    MOVLW 0x00
    CALL WS_Envia_Byte              ; B

    ; Pixeles 9-63: apagados
    MOVLW D'55'
    MOVWF WS_Cont_Pixels,0

WS_TO_Apagado
    MOVLW 0x00
    CALL WS_Envia_Byte
    MOVLW 0x00
    CALL WS_Envia_Byte
    MOVLW 0x00
    CALL WS_Envia_Byte
    DECFSZ WS_Cont_Pixels,1,0
    BRA WS_TO_Apagado

    CALL WS_Reset
    BSF INTCON,GIE,0
RETURN

;-------------------------------------------------------------------------------
;                           Delays
;-------------------------------------------------------------------------------

; Delay de ~500ms a 32 MHz
; 21 x 100 x 190 x 3 ciclos x 125ns ~= 500ms
Delay_500ms
    MOVLW D'21'
    MOVWF Delay_Cnt3,0
Bucle_D3
    MOVLW D'100'
    MOVWF Delay_Cnt2,0
Bucle_D2
    MOVLW D'190'
    MOVWF Delay_Cnt1,0
Bucle_D1
    DECFSZ Delay_Cnt1,1,0
    BRA Bucle_D1
    DECFSZ Delay_Cnt2,1,0
    BRA Bucle_D2
    DECFSZ Delay_Cnt3,1,0
    BRA Bucle_D3
RETURN

; Delay de ~16ms para debounce (rebotes)
Espera_Rebots
    MOVLW (.128)
    MOVWF Part_Low_Rebots,0
    MOVLW (.178)
    MOVWF Part_High_Rebots,0
Bucle_Rebots
    INCF Part_Low_Rebots,1,0
    BTFSS STATUS,C,0
    GOTO Bucle_Rebots
    MOVLW (.128)
    MOVWF Part_Low_Rebots,0
    INCF Part_High_Rebots,1,0
    BTFSS STATUS,C,0
    GOTO Bucle_Rebots
RETURN

;-------------------------------------------------------------------------------
;                              MAIN
;-------------------------------------------------------------------------------

MAIN
    CALL Init_Oscilador
    CALL Init_Puertos
    CALL Init_Menu
    GOTO Bucle_Menu

END
