# Problemas encontrados

## 1. LEDs fantasma en la primera fila tras arranque (POR)

**Fecha:** 2026-05-08

**Sintoma:** Al alimentar el PIC (power-on reset), aparecen pixeles fantasma en la primera fila de la matriz WS2812B (pixel 0 y alrededores). El resto de la cara se muestra correctamente. El problema NO ocurre al usar Mode_Reset desde el menu.

### Antes del fix (pixeles blancos)

![LEDs fantasma blancos](images/ghost_leds_white.png)

Se observan LEDs blancos en la columna izquierda (primera fila) que no deberian estar encendidos. La cara del tamagotchi se muestra desplazada.

### Despues de anadir update_display flag (pixeles verdes)

![LEDs fantasma verdes](images/ghost_leds_green.png)

Tras anadir el flag `update_display` para que `Bucle_Menu` redibuje en la primera iteracion, el pixel fantasma paso a ser verde (el color correcto de la cara) en vez de blanco, pero seguia apareciendo el pixel 0 encendido.

### Resultado esperado (display limpio - tras Mode_Reset)

![Display limpio](images/display_clean.png)

Asi se ve correctamente tras usar Mode_Reset desde el menu.

### Analisis

La diferencia clave entre MAIN (falla) y Mode_Reset (funciona):

- **Mode_Reset:** Cuando se ejecuta, RA4 lleva mucho tiempo en LOW (todo el tiempo del bucle de menu). El WS2812B esta en estado reset limpio antes del primer byte.
- **MAIN (boot):** RA4 se configura como salida LOW en `Init_Puertos`, pero entre esa configuracion y el primer `Dibuixa_Cara_Edat` hay muy poco tiempo. El WS2812B necesita >50us de LOW para entrar en estado reset. Durante el power-on, el pin RA4 estaba flotando (TRISA=0xFF por defecto en POR), y el WS2812B pudo captar ruido como datos validos.

### Intentos de solucion

1. **Doble llamada a `Dibuixa_Cara_Edat`:** No funciono. El segundo dibujo aterriza limpio pero el problema seguia.
2. **`WS_Reset` antes del primer dibujo:** Anade >50us de LOW garantizado antes de transmitir. Parcialmente efectivo.
3. **Flag `update_display` + `Espera_Rebots` (16ms):** Combina un primer dibujo en init con un segundo dibujo via flag en `Bucle_Menu`, con 16ms de espera adicional. Pendiente de verificacion.

### Estado

En investigacion.
