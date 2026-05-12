# 7-Segment Mapping Test Guide

## Objetivo

Descubrir qué pin PORTD (RD0-RD6) controla qué segmento (a-g) del display 7 segmentos, y si es cátodo común o ánodo común.

## Referencia: segmentos estándar

```
   aaaa
  f    b
  f    b
   gggg
  e    c
  e    c
   dddd   .dp
```

## Antes de empezar

1. Flashear el firmware de `test/7seg-mapping`
2. Tener a mano este documento para anotar resultados
3. La matriz WS2812B muestra N píxeles encendidos = dígito N (referencia visual)
4. RA3 se enciende cuando el dígito es 0

## Paso 1: Comprobar tipo de display (cátodo o ánodo común)

Con el dígito en **8** (todos los segmentos activos con el mapping placeholder):

- ¿Se encienden TODOS los segmentos? → **Cátodo común** (1 = ON)
- ¿Se apagan TODOS los segmentos? → **Ánodo común** (0 = ON, hay que invertir la lógica)
- ¿Se encienden ALGUNOS? → Cátodo común pero el mapping de pines es diferente

**Resultado:** ______________________

## Paso 2: Identificar cada pin RD individualmente

Cambiar el firmware NO es necesario. Usar los dígitos que activan pocos segmentos para deducir el mapping. Pero si prefieres, puedes anotar qué segmentos se encienden para cada dígito:

| Dígito | Píxeles en matriz | Segmentos que se encienden (a,b,c,d,e,f,g) | ¿Correcto? |
|--------|-------------------|---------------------------------------------|------------|
| 0      | 0 (RA3 encendido) |                                             |            |
| 1      | 1                 |                                             |            |
| 2      | 2                 |                                             |            |
| 3      | 3                 |                                             |            |
| 4      | 4                 |                                             |            |
| 5      | 5                 |                                             |            |
| 6      | 6                 |                                             |            |
| 7      | 7                 |                                             |            |
| 8      | 8                 |                                             |            |
| 9      | 9                 |                                             |            |

## Paso 3: Decimal Point (DP)

Con cualquier dígito, pulsar **Select (RB2)** para activar el punto decimal.

- ¿Qué segmento se enciende/apaga al pulsar Select? → Ese es RD7
- ¿Se enciende el punto decimal real del display? **Sí / No**

**Resultado:** ______________________

## Paso 4: Deducir el mapping pin → segmento

Usando la tabla del Paso 2, deducir qué pin controla qué segmento.

El firmware placeholder asume: `RD0=a, RD1=b, RD2=c, RD3=d, RD4=e, RD5=f, RD6=g, RD7=dp`

Mapping real descubierto:

| Pin  | Segmento |
|------|----------|
| RD0  | a (top)  |
| RD1  | g (middle) |
| RD2  | c (lower-right) |
| RD3  | d (bottom) |
| RD4  | e (lower-left) |
| RD5  | f (upper-left) |
| RD6  | b (upper-right) |
| RD7  | dp |

**Nota:** El mapping es casi estándar, excepto que **b y g están intercambiados** (RD1=g en vez de b, RD6=b en vez de g).

## Información extra a anotar

- ¿El display tiene punto decimal? **Sí / No**
- ¿El display es cátodo común o ánodo común? __________
- ¿Los segmentos se iluminan correctamente para el dígito 8? (todos encendidos) **Sí / No**
- ¿Algún segmento no funciona o está siempre encendido? __________
- ¿Algún pin de PORTD parece no estar conectado al display? __________

## Cómo interpretar los resultados

Para deducir el mapping, el dígito **1** es clave: solo activa b y c (los dos segmentos de la derecha). El patrón que el firmware envía para 1 es `0x06` = bits 1 y 2 activos = RD1 y RD2. Si al mostrar "1" se encienden los segmentos correctos (b y c), entonces RD1=b y RD2=c. Si se encienden otros segmentos, el mapping es diferente.

Dígitos útiles para deducir:
- **1** (`0x06` = RD1,RD2): debería encender b,c
- **7** (`0x07` = RD0,RD1,RD2): debería encender a,b,c
- **4** (`0x66` = RD1,RD2,RD5,RD6): debería encender b,c,f,g

Con estos tres ya puedes deducir a, b, c, f, g. Los dígitos 2 y 6 revelan d y e.
