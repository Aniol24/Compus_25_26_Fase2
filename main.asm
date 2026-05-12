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

; Debounce
Part_Low_Rebots     EQU 0x009
Part_High_Rebots    EQU 0x00A

; Test 7 segmentos
Digito              EQU 0x008       ; valor actual (0-9)
DP_State            EQU 0x00B       ; 0=DP apagado, 1=DP encendido

; Constantes
NUM_PIXELS          EQU D'64'       ; 8x8 = 64 LEDs
BRILLO              EQU 0x20        ; brillo reducido

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

    ; RA3 como salida (LED debug)
    BCF TRISA,3,0
    BCF LATA,3,0

    ; RA4 como salida (WS2812B)
    BCF TRISA,4,0
    BCF LATA,4,0

    ; RD0-RD7 como salida (7 segmentos)
    CLRF TRISD,0
    CLRF LATD,0

    ; RB1, RB2, RB3 como entrada (botones)
    BSF TRISB,1,0
    BSF TRISB,2,0
    BSF TRISB,3,0

    ; Activar pull-ups internas de PORTB
    BCF INTCON2,RBPU,0
RETURN

;-------------------------------------------------------------------------------
;                           Driver WS2812B
;-------------------------------------------------------------------------------

; Envia un byte por RA4 (MSB primero)
WS_Envia_Byte
    MOVWF WS_Dato,0
    MOVLW D'8'
    MOVWF WS_Cont_Bits,0

WS_Bucle_Bit
    BSF LATA,4,0
    NOP
    BTFSS WS_Dato,7,0
    BCF LATA,4,0
    NOP
    NOP
    BCF LATA,4,0
    RLNCF WS_Dato,1,0
    DECFSZ WS_Cont_Bits,1,0
    GOTO WS_Bucle_Bit
RETURN

; Senal de reset (>50us LOW en RA4)
WS_Reset
    BCF LATA,4,0
    MOVLW D'134'
    MOVWF WS_Temp,0
WS_Reset_Bucle
    DECFSZ WS_Temp,1,0
    GOTO WS_Reset_Bucle
RETURN

;-------------------------------------------------------------------------------
;                           Delays
;-------------------------------------------------------------------------------

; Delay de ~16ms para debounce
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
;                    Actualizar display (7seg + matriz + RA3)
;-------------------------------------------------------------------------------

; Escribe el valor de Digito en PORTD como patron de 7 segmentos
; Por ahora: salida directa del digito en binario en RD0-RD6
; (se ajustara cuando se descubra el mapping real)
Actualitza_7Seg
    ; Cargar TBLPTR con la tabla de segmentos
    MOVLW LOW(TAULA_7SEG)
    MOVWF TBLPTRL,0
    MOVLW HIGH(TAULA_7SEG)
    MOVWF TBLPTRH,0
    CLRF TBLPTRU,0
    ; Sumar offset = Digito
    MOVF Digito,0,0
    ADDWF TBLPTRL,1,0
    BTFSC STATUS,C,0
    INCF TBLPTRH,1,0
    ; Leer byte de la tabla
    TBLRD*
    MOVF TABLAT,0,0
    MOVWF WS_Temp,0
    ; Aplicar DP si esta activo
    BTFSC DP_State,0,0
    BSF WS_Temp,7,0
    ; Escribir a PORTD
    MOVF WS_Temp,0,0
    MOVWF LATD,0
RETURN

; Actualizar LED RA3: encendido si Digito == 0
Actualitza_RA3
    MOVF Digito,0,0
    BTFSS STATUS,Z,0
    GOTO RA3_Off
    BSF LATA,3,0
RETURN
RA3_Off
    BCF LATA,3,0
RETURN

; Dibujar en la matriz: primeros N pixeles encendidos (N = Digito), resto apagados
Actualitza_Matriu
    BCF INTCON,GIE,0

    ; Enviar Digito pixeles en blanco
    MOVF Digito,0,0
    BTFSC STATUS,Z,0
    GOTO AM_Apagados
    MOVWF WS_Cont_Pixels,0

AM_Encendidos
    MOVLW BRILLO
    CALL WS_Envia_Byte              ; G
    MOVLW BRILLO
    CALL WS_Envia_Byte              ; R
    MOVLW BRILLO
    CALL WS_Envia_Byte              ; B
    DECFSZ WS_Cont_Pixels,1,0
    GOTO AM_Encendidos

AM_Apagados
    ; Calcular pixeles restantes: 64 - Digito
    MOVLW NUM_PIXELS
    MOVWF WS_Cont_Pixels,0
    MOVF Digito,0,0
    SUBWF WS_Cont_Pixels,1,0

    ; Si todos encendidos (no deberia pasar con max 9), saltar
    MOVF WS_Cont_Pixels,0,0
    BTFSC STATUS,Z,0
    GOTO AM_Fin

AM_Apagados_Bucle
    MOVLW 0x00
    CALL WS_Envia_Byte              ; G
    MOVLW 0x00
    CALL WS_Envia_Byte              ; R
    MOVLW 0x00
    CALL WS_Envia_Byte              ; B
    DECFSZ WS_Cont_Pixels,1,0
    GOTO AM_Apagados_Bucle

AM_Fin
    CALL WS_Reset
    BSF INTCON,GIE,0
RETURN

; Actualizar todo: 7seg + RA3 + matriz
Actualitza_Tot
    CALL Actualitza_7Seg
    CALL Actualitza_RA3
    CALL Actualitza_Matriu
RETURN

;-------------------------------------------------------------------------------
;                          Bucle principal
;-------------------------------------------------------------------------------

Bucle_Test
    ; Comprobar RB1 (Left = decrementar)
    BTFSC PORTB,1,0
    GOTO Comprova_Right
    BSF LATA,3,0
    CALL Espera_Rebots
Deixa_Boto_Left
    BTFSS PORTB,1,0
    GOTO Deixa_Boto_Left
    CALL Espera_Rebots
    ; Decrementar: si 0 -> 9, sino -1
    MOVF Digito,0,0
    BTFSC STATUS,Z,0
    GOTO Left_Wrap
    DECF Digito,1,0
    GOTO Left_Fi
Left_Wrap
    MOVLW D'9'
    MOVWF Digito,0
Left_Fi
    CALL Actualitza_Tot
    GOTO Bucle_Test

Comprova_Right
    ; Comprobar RB3 (Right = incrementar)
    BTFSC PORTB,3,0
    GOTO Comprova_Select
    BSF LATA,3,0
    CALL Espera_Rebots
Deixa_Boto_Right
    BTFSS PORTB,3,0
    GOTO Deixa_Boto_Right
    CALL Espera_Rebots
    ; Incrementar: si 9 -> 0, sino +1
    INCF Digito,1,0
    MOVLW D'10'
    CPFSEQ Digito,0
    GOTO Right_Fi
    CLRF Digito,0
Right_Fi
    CALL Actualitza_Tot
    GOTO Bucle_Test

Comprova_Select
    ; Comprobar RB2 (Select = toggle DP)
    BTFSC PORTB,2,0
    GOTO Bucle_Test
    BSF LATA,3,0
    CALL Espera_Rebots
Deixa_Boto_Select
    BTFSS PORTB,2,0
    GOTO Deixa_Boto_Select
    CALL Espera_Rebots
    ; Toggle DP_State bit 0
    MOVLW 0x01
    XORWF DP_State,1,0
    CALL Actualitza_Tot
    GOTO Bucle_Test

;-------------------------------------------------------------------------------
;                              MAIN
;-------------------------------------------------------------------------------

MAIN
    CALL Init_Oscilador
    CALL Init_Puertos
    CALL WS_Reset

    ; Estado inicial: digito 0, DP apagado
    CLRF Digito,0
    CLRF DP_State,0
    CALL Actualitza_Tot

    GOTO Bucle_Test

;-------------------------------------------------------------------------------
;                     Tabla de segmentos (placeholder)
;-------------------------------------------------------------------------------

; Patron para RD0-RD6 por digito (0-9)
; RD7 se usa para el punto decimal (controlado por DP_State)
; NOTA: estos valores son placeholder - ajustar segun el mapping real del display
;   bit0=RD0, bit1=RD1, ..., bit6=RD6
;   Asumiendo display catodo comun con: RD0=a, RD1=b, RD2=c, RD3=d, RD4=e, RD5=f, RD6=g
TAULA_7SEG
    DB 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F

END
