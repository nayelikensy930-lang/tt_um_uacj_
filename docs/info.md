# tt_um_uacj — VGA Logo Bouncer

Diseño digital para [Tiny Tapeout](https://tinytapeout.com) que muestra un logotipo de **128×40 píxeles** rebotando sobre una pantalla VGA 640×480 @ 25 MHz, con efectos visuales configurables en tiempo real desde los pines de entrada.

---

## Descripción general

El diseño genera una señal VGA estándar (640×480, 60 Hz) y anima un logotipo de bitmap que rebota dentro del área visible, cambiando de color en cada colisión con el borde de la pantalla. Varios efectos visuales se controlan bit a bit desde los 8 pines de entrada (`ui_in`).

---

## Pinout

### Entradas (`ui_in`)

| Bit | Nombre         | Descripción                                           |
|-----|----------------|-------------------------------------------------------|
| 0   | `cfg_tile`     | Modo mosaico: repite el logotipo en toda la pantalla  |
| 1   | `cfg_color`    | Habilita paleta de colores dinámica                   |
| 2   | `cfg_invert`   | Invierte los colores de primer plano y fondo          |
| 3   | `cfg_slow`     | Reduce la velocidad de animación a la mitad           |
| 4   | `cfg_flip`     | Voltea el logotipo verticalmente                      |
| 5   | `cfg_checker`  | Activa fondo ajedrezado                               |
| 6   | `cfg_scanline` | Simula líneas de exploración CRT (scanlines)          |
| 7   | `cfg_glitch`   | Activa el motor de corrupción visual (glitch)         |

### Salidas (`uo_out`) — TinyVGA PMOD

| Bits    | Señal  |
|---------|--------|
| `[7]`   | HSYNC  |
| `[6]`   | B[0]   |
| `[5]`   | G[0]   |
| `[4]`   | R[0]   |
| `[3]`   | VSYNC  |
| `[2]`   | B[1]   |
| `[1]`   | G[1]   |
| `[0]`   | R[1]   |

Compatible con el **TinyVGA PMOD** estándar de Tiny Tapeout.

### Bidireccionales (`uio_*`)

No utilizados. `uio_out` y `uio_oe` se mantienen en `0`.

---

## Parámetros de temporización

| Parámetro      | Valor  |
|----------------|--------|
| Reloj (`clk`)  | 25 MHz (periodo 40 ns) |
| Reset          | Activo en bajo (`rst_n`) |
| Resolución     | 640 × 480 píxeles       |
| Refresco       | ~60 Hz                  |
| Tamaño del logo| 128 × 40 píxeles        |

---

## Módulos

### `tt_um_uacj` (top)

Módulo principal. Instancia los demás módulos e implementa:

- **Lógica de rebote**: el logotipo parte desde (200, 200) y viaja en diagonal. Al tocar cualquier borde, invierte la dirección correspondiente.
- **Flash en colisión**: durante 6 cuadros tras un rebote, el logotipo se muestra en blanco brillante.
- **Divisor de velocidad** (`cfg_slow`): cuando está activo, el logotipo avanza un píxel cada dos cuadros.
- **Color dinámico**: el índice de color se incrementa en cada rebote; se aplica a logotipo, fondo y patrón ajedrezado mediante la paleta de 8 colores.

### `hvsync_generator`

Genera las señales de sincronía horizontal y vertical conforme al estándar VGA:

| Parámetro       | Valor |
|-----------------|-------|
| H_DISPLAY       | 640   |
| H_FRONT porch   | 16    |
| H_SYNC          | 96    |
| H_BACK porch    | 48    |
| V_DISPLAY       | 480   |
| V_BOTTOM border | 10    |
| V_SYNC          | 2     |
| V_TOP border    | 33    |

Expone `hpos` y `vpos` (10 bits c/u) y la señal `display_on` que indica cuándo el haz se encuentra dentro del área visible.

### `bitmap_rom`

ROM de solo lectura de **640 bytes** (40 filas × 16 bytes) que almacena el logotipo en formato bitmap monócromático de 128×40 píxeles.

- Dirección: `addr = y[5:0] * 16 + x[6:3]`
- Extracción de pixel: `pixel = mem[addr][x[2:0]]`
- Soporta lectura invertida en Y mediante `cfg_flip`.

### `palette`

LUT de 8 colores en formato `RRGGBB` de 6 bits (2 bits por canal):

| Índice | Color   | Valor      |
|--------|---------|------------|
| 0      | Cian    | `001011`   |
| 1      | Rosa    | `110110`   |
| 2      | Verde   | `101101`   |
| 3      | Naranja | `111000`   |
| 4      | Morado  | `110011`   |
| 5      | Amarillo| `011111`   |
| 6      | Rojo    | `110001`   |
| 7      | Blanco  | `111111`   |

Se instancia tres veces: logotipo, fondo y color del patrón ajedrezado.

---

## Motor de glitch

Cuando `cfg_glitch = 1`, se activa un motor de corrupción visual basado en un **LFSR de 8 bits** (taps en posiciones 7, 5, 4, 3). El motor opera en tres estados:

| Estado | Descripción                          |
|--------|--------------------------------------|
| 0      | Inactivo, espera disparador          |
| 1      | Corrupción activa (`glitch_timer` cuadros) |
| 2      | Recuperación (1 cuadro de transición)|

Efectos aplicados durante la corrupción:

- **XOR horizontal/vertical**: desplaza píxeles con una máscara derivada del LFSR.
- **Tearing horizontal**: filasseleccionadas se desplazan lateralmente.
- **Aberración cromática**: cada canal RGB recibe un XOR independiente del LFSR.
- **Intercambio de canales**: R↔G y G↔B se permutan según bits del LFSR.
- **Flash de inversión**: a intensidad máxima, los colores se invierten en algunos cuadros.

El glitch también se activa automáticamente cada ~150 cuadros cuando `cfg_glitch = 1`.

---

## Cómo usar

1. Conecta el **TinyVGA PMOD** a los pines `uo_out`.
2. Conecta el monitor VGA al PMOD.
3. Aplica reloj de **25 MHz** en `clk`.
4. Mantén `rst_n = 0` brevemente al inicio y luego suéltalo (`rst_n = 1`).
5. Controla los efectos con los 8 bits de `ui_in` según la tabla de pinout.

---

## Archivos del proyecto

| Archivo               | Descripción                                  |
|-----------------------|----------------------------------------------|
| `tt_um_uacj.v`        | Módulo top: animación, efectos, salida RGB   |
| `hvsync_generator.v`  | Generador de sincronía VGA                   |
| `bitmap_rom.v`        | ROM del logotipo (128×40, 1 bpp)             |
| `palette.v`           | LUT de paleta de 8 colores                   |
| `config.json`         | Configuración de Tiny Tapeout (reloj 25 MHz) |

---

## Licencia

Apache 2.0 — © 2024 Tiny Tapeout LTD / UACJ IIT

