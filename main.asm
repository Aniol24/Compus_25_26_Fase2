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
GOTO HIGH_RSI

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

; Caras Tamagotchi - dibujo en matriz
WS_Color_G          EQU 0x00B       ; componente verde del color de la cara
WS_Color_R          EQU 0x00C       ; componente rojo del color de la cara
WS_Color_B          EQU 0x00D       ; componente azul del color de la cara
WS_Fila             EQU 0x00E       ; byte de la fila actual del sprite
WS_Cont_Fila        EQU 0x00F       ; contador de filas (8)
WS_Cont_Bit_Pixel   EQU 0x010       ; contador de bits dentro de una fila (8)

; Sistema de edad y salud (Timer0 ISR)
Seg_Cnt             EQU 0x011       ; ticks de 20ms dentro de un segundo (0-49)
Min_Seg_Cnt         EQU 0x012       ; segundos dentro de un minuto (0-59)
Edat                EQU 0x013       ; edad (0-100, pasos de 10)
Hunger_Cnt          EQU 0x014       ; contador de segundos de hambre (0-255)
Health_State        EQU 0x015       ; 0=saludable, 1=advertencia
Food_Tokens         EQU 0x016       ; tokens de comida (0-5)
update_display      EQU 0x01A       ; flag: ISR pone 1, main loop limpia
is_dead             EQU 0x01B       ; flag de muerte (1=muerto)

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

Init_Timer_State
    CLRF Seg_Cnt,0
    CLRF Min_Seg_Cnt,0
    CLRF Edat,0
    CLRF Hunger_Cnt,0
    CLRF Health_State,0
    CLRF is_dead,0
    CLRF update_display,0
    MOVLW D'5'
    MOVWF Food_Tokens,0
RETURN

Carrega_Timer0
    BCF INTCON,TMR0IF,0
    MOVLW b'10000001'
    MOVWF T0CON,0               ; Timer0 ON, 16-bit, internal, prescaler 1:4
    MOVLW 0x63
    MOVWF TMR0H,0
    MOVLW 0xC0
    MOVWF TMR0L,0
RETURN

Init_Interrupcions
    MOVLW b'11100000'
    MOVWF INTCON,0              ; GIE + PEIE + TMR0IE
    BCF RCON,IPEN,0             ; sin niveles de prioridad
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

; Inicializar menu: estado 0 (Jugar), LED debug apagado, RGB cyan
Init_Menu
    CLRF Menu_State,0
    BCF LATA,3,0
    CALL Actualitza_LED_Menu
RETURN

;-------------------------------------------------------------------------------
;                          Bucle Menu
;-------------------------------------------------------------------------------

Bucle_Menu
    ; Comprobar muerte
    BTFSC is_dead,0,0
    GOTO Bucle_Muerte
    ; Comprobar flag de actualizacion del display
    BTFSS update_display,0,0
    GOTO BM_Polling
    CALL Actualitza_Display
BM_Polling
    ; Comprobar RB1 (LeftOption)
    BTFSC PORTB,1,0
    GOTO Comprova_Right
    BSF LATA,3,0
    CALL Espera_Rebots
Deixa_Boto_Left
    BTFSS PORTB,1,0
    GOTO Deixa_Boto_Left
    BCF LATA,3,0
    CALL Espera_Rebots
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
    BSF LATA,3,0
    CALL Espera_Rebots
Deixa_Boto_Right
    BTFSS PORTB,3,0
    GOTO Deixa_Boto_Right
    BCF LATA,3,0
    CALL Espera_Rebots
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
    BSF LATA,3,0
    CALL Espera_Rebots
Deixa_Boto_Select
    BTFSS PORTB,2,0
    GOTO Deixa_Boto_Select
    BCF LATA,3,0
    CALL Espera_Rebots
    ; Saltar al modo seleccionado
    MOVF Menu_State,0,0
    BTFSC STATUS,Z,0
    GOTO Mode_Jugar
    MOVLW D'1'
    CPFSEQ Menu_State,0
    GOTO Mode_Reset
    GOTO Mode_Alimentar

;-------------------------------------------------------------------------------
;                              Modos
;-------------------------------------------------------------------------------

; Placeholder: otorga +1 token (max 5) y vuelve al menu
Mode_Jugar
    MOVLW D'5'
    CPFSEQ Food_Tokens,0
    INCF Food_Tokens,1,0
    GOTO Bucle_Menu

; Consumir 1 token y reiniciar hambre
Mode_Alimentar
    MOVF Food_Tokens,0,0
    BTFSC STATUS,Z,0
    GOTO Bucle_Menu             ; sin tokens, volver al menu
    DECF Food_Tokens,1,0
    CLRF Hunger_Cnt,0
    CLRF Health_State,0
    BSF update_display,0,0
    GOTO Bucle_Menu

; Reinicializar todo el estado (replica la secuencia de boot)
Mode_Reset
Desactiva_GIE_Reset
    BCF INTCON,GIE,0
    BTFSC INTCON,GIE,0
    BRA Desactiva_GIE_Reset
    CLRF Edat,0
    CLRF Hunger_Cnt,0
    CLRF Health_State,0
    CLRF Seg_Cnt,0
    CLRF Min_Seg_Cnt,0
    CLRF is_dead,0
    CLRF update_display,0
    MOVLW D'5'
    MOVWF Food_Tokens,0
    CLRF Menu_State,0
    CALL Actualitza_LED_Menu
    CALL Carrega_Timer0
    CALL Dibuixa_Cara_Edat
    GOTO Bucle_Menu

;-------------------------------------------------------------------------------
;                          Estado de muerte
;-------------------------------------------------------------------------------

; Cara actual en rojo, bucle infinito (solo MCLR recupera)
Bucle_Muerte
    CLRF WS_Color_G,0
    MOVLW BRILLO
    MOVWF WS_Color_R,0
    CLRF WS_Color_B,0
    CALL Selecciona_Cara_Edat
    CALL Dibuixa_Cara
Muerte_Loop
    GOTO Muerte_Loop

;-------------------------------------------------------------------------------
;                    Actualizacion del display (event-driven)
;-------------------------------------------------------------------------------

; Llamado desde main loop cuando update_display esta activo
Actualitza_Display
    CLRF update_display,0
    BTFSC is_dead,0,0
    GOTO Bucle_Muerte
    CALL Dibuixa_Cara_Edat
RETURN

; Dibuja la cara segun edad con color segun salud
Dibuixa_Cara_Edat
    ; Determinar color segun Health_State
    MOVF Health_State,0,0
    BTFSC STATUS,Z,0
    GOTO DCE_Verde
    ; Amarillo: G=BRILLO, R=BRILLO, B=0
    MOVLW BRILLO
    MOVWF WS_Color_G,0
    MOVLW BRILLO
    MOVWF WS_Color_R,0
    CLRF WS_Color_B,0
    GOTO DCE_Dibuja

DCE_Verde
    ; Verde: G=BRILLO, R=0, B=0
    MOVLW BRILLO
    MOVWF WS_Color_G,0
    CLRF WS_Color_R,0
    CLRF WS_Color_B,0

DCE_Dibuja
    CALL Selecciona_Cara_Edat
    CALL Dibuixa_Cara
RETURN

; Configura TBLPTR segun Edat (0-29=Child, 30-59=Teen, 60+=Adult)
Selecciona_Cara_Edat
    MOVLW D'30'
    CPFSLT Edat,0
    GOTO SCE_No_Child
    ; Child (Edat < 30)
    MOVLW LOW(FACE_CHILD)
    MOVWF TBLPTRL,0
    MOVLW HIGH(FACE_CHILD)
    MOVWF TBLPTRH,0
    CLRF TBLPTRU,0
RETURN

SCE_No_Child
    MOVLW D'60'
    CPFSLT Edat,0
    GOTO SCE_Adult
    ; Teen (30 <= Edat < 60)
    MOVLW LOW(FACE_TEEN)
    MOVWF TBLPTRL,0
    MOVLW HIGH(FACE_TEEN)
    MOVWF TBLPTRH,0
    CLRF TBLPTRU,0
RETURN

SCE_Adult
    ; Adult (Edat >= 60)
    MOVLW LOW(FACE_ADULT)
    MOVWF TBLPTRL,0
    MOVLW HIGH(FACE_ADULT)
    MOVWF TBLPTRH,0
    CLRF TBLPTRU,0
RETURN

;-------------------------------------------------------------------------------
;                       Dibujo de caras en matriz
;-------------------------------------------------------------------------------

; Dibuja un sprite 8x8 en la matriz WS2812B
; Entrada: TBLPTR apunta a la tabla del sprite (8 bytes)
;          WS_Color_G, WS_Color_R, WS_Color_B = color de los pixeles encendidos
Dibuixa_Cara
Desactiva_GIE_Cara
    BCF INTCON,GIE,0
    BTFSC INTCON,GIE,0
    BRA Desactiva_GIE_Cara
    MOVLW D'8'
    MOVWF WS_Cont_Fila,0

DC_Bucle_Fila
    TBLRD*+
    MOVFF TABLAT,WS_Fila
    MOVLW D'8'
    MOVWF WS_Cont_Bit_Pixel,0

DC_Bucle_Bit
    BTFSC WS_Fila,7,0
    GOTO DC_Pixel_On
    ; Pixel apagado: enviar negro (0,0,0)
    MOVLW 0x00
    CALL WS_Envia_Byte
    MOVLW 0x00
    CALL WS_Envia_Byte
    MOVLW 0x00
    CALL WS_Envia_Byte
    GOTO DC_Siguiente_Bit

DC_Pixel_On
    ; Pixel encendido: enviar color (G,R,B)
    MOVF WS_Color_G,0,0
    CALL WS_Envia_Byte
    MOVF WS_Color_R,0,0
    CALL WS_Envia_Byte
    MOVF WS_Color_B,0,0
    CALL WS_Envia_Byte

DC_Siguiente_Bit
    RLNCF WS_Fila,1,0
    DECFSZ WS_Cont_Bit_Pixel,1,0
    BRA DC_Bucle_Bit
    DECFSZ WS_Cont_Fila,1,0
    BRA DC_Bucle_Fila

    CALL WS_Reset
    BSF INTCON,GIE,0
RETURN

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
;                           ISR - Timer0 (cada 20ms)
;-------------------------------------------------------------------------------

HIGH_RSI
    ; Si esta muerto, no contar tiempo
    BTFSC is_dead,0,0
    GOTO RSI_Fin

    ; Contar tick de 20ms
    INCF Seg_Cnt,1,0
    MOVLW D'50'
    CPFSEQ Seg_Cnt,0
    GOTO RSI_Fin                    ; no ha pasado 1 segundo

    ; --- Frontera de 1 segundo ---
    CLRF Seg_Cnt,0
    INCF Hunger_Cnt,1,0

    ; Comprobar muerte por hambre (>= 180s)
    MOVLW D'180'
    CPFSLT Hunger_Cnt,0
    GOTO RSI_Muerte_Hambre

    ; Comprobar advertencia (>= 90s)
    MOVLW D'90'
    CPFSLT Hunger_Cnt,0
    GOTO RSI_Advertencia

    ; Saludable (< 90s): comprobar si ha cambiado
    MOVF Health_State,0,0
    BTFSC STATUS,Z,0
    GOTO RSI_Minuto                 ; ya era saludable, no cambiar
    CLRF Health_State,0
    BSF update_display,0,0
    GOTO RSI_Minuto

RSI_Muerte_Hambre
    BSF is_dead,0,0
    BSF update_display,0,0
    GOTO RSI_Fin

RSI_Advertencia
    ; Comprobar si ya era advertencia
    MOVLW D'1'
    CPFSEQ Health_State,0
    GOTO RSI_Adv_Cambio
    GOTO RSI_Minuto                 ; ya era advertencia
RSI_Adv_Cambio
    MOVLW D'1'
    MOVWF Health_State,0
    BSF update_display,0,0

RSI_Minuto
    ; Contar segundos dentro del minuto
    INCF Min_Seg_Cnt,1,0
    MOVLW D'60'
    CPFSEQ Min_Seg_Cnt,0
    GOTO RSI_Fin                    ; no ha pasado 1 minuto

    ; --- Frontera de 1 minuto ---
    CLRF Min_Seg_Cnt,0
    MOVLW D'10'
    ADDWF Edat,1,0

    ; Comprobar muerte por edad (>= 100)
    MOVLW D'100'
    CPFSLT Edat,0
    GOTO RSI_Muerte_Edad

    ; Solo redibujar si la cara cambia (umbrales 30 y 60)
    MOVLW D'30'
    CPFSEQ Edat,0
    GOTO RSI_Check_60
    BSF update_display,0,0
    GOTO RSI_Fin

RSI_Check_60
    MOVLW D'60'
    CPFSEQ Edat,0
    GOTO RSI_Fin
    BSF update_display,0,0
    GOTO RSI_Fin

RSI_Muerte_Edad
    MOVLW D'100'
    MOVWF Edat,0
    BSF is_dead,0,0
    BSF update_display,0,0

RSI_Fin
    CALL Carrega_Timer0
RETFIE FAST

;-------------------------------------------------------------------------------
;                              MAIN
;-------------------------------------------------------------------------------

MAIN
    ; Forzar RA4 como salida LOW antes de configurar oscilador
    ; para que el WS2812B no capte ruido durante el arranque
    BCF TRISA,4,0
    BCF LATA,4,0
    CALL Init_Oscilador
    CALL Init_Puertos
    CALL WS_Reset
    CALL Init_Timer_State
    CALL Init_Menu
    CALL Dibuixa_Cara_Edat
    CALL Carrega_Timer0
    CALL Init_Interrupcions
    GOTO Bucle_Menu

;-------------------------------------------------------------------------------
;                        Tablas de sprites en flash
;-------------------------------------------------------------------------------

; Cada tabla tiene 8 bytes, un byte por fila (MSB = pixel izquierdo)
FACE_CHILD
    DB 0x00, 0x00, 0x18, 0x24, 0x24, 0x18, 0x00, 0x00

FACE_TEEN
    DB 0x00, 0x3C, 0x42, 0x5A, 0x42, 0x42, 0x3C, 0x00

FACE_ADULT
    DB 0x7E, 0x81, 0xA5, 0x81, 0xA5, 0x99, 0x81, 0x7E

END
