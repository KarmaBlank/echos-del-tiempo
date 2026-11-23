# Spec: Pantalla de título

Pedido del dueño (sobre v0.36.0, captura a 1920×1080): el título nuevo
"se ve horrible y está roto": botones de abajo cortados a la mitad,
tarjeta del personaje cortada, fechas con "…", BUSCAR encima de la
versión y todo metido en un panel grande con borde. Esta spec fija el
título por defecto. El layout es dato (`assets/layouts/title.screen.json`,
docs/specs/screen_editor.md); la pantalla armada en código (fallback,
sin archivo) sigue la misma disposición.

## 1. Disposición (menú principal de RPG, minimalista)

Lienzo de diseño 1280×720 (todo escala igual hasta 2560×1440):

```
 ECOS DEL TIEMPO                 ┌ MUNDO ─────────────────────────┐
                                 │ selector de mundo              │
 > JUGAR            (principal)  │ PERSONAJES (n/8)               │
   NUEVO PERSONAJE               │ [tarjeta] [tarjeta] [tarjeta]  │
   VER NOTAS DEL PARCHE [NUEVO]  │ [tarjeta] [+ NUEVO]            │
   CONFIGURACIÓN                 │ RENOMBRAR BORRAR ALIJO ...     │
   SALIR DEL JUEGO               │ ABRIR SALA o [código] UNIRSE   │
                                 └────────────────────────────────┘
 [ACTUALIZAR] (solo si hay)      avisos de la cuenta     red ·  [?]
```

- Solo el nombre del juego, sin subtítulo.
- Columna de acciones a la izquierda, una debajo de otra, del mismo
  ancho, con aire entre botones. JUGAR es la única principal (dorada);
  SALIR DEL JUEGO va en tono peligro.
- A la derecha, el hueco `personajes` (mundo + grilla de tarjetas +
  acciones del elegido + sala) sin panel con borde alrededor: las
  tarjetas ya son superficies. Si no entra, se desplaza (rueda / teclado).
- Abajo a la izquierda, el hueco `version` (v0.37.1): vacío (sin
  versión ni "buscando…" ni BUSCAR) salvo que haya una versión nueva;
  ahí solo el botón ACTUALIZAR (la misma acción del actualizador; después
  el progreso de la descarga o REINTENTAR si falla). Nunca se pisa con
  otra caja.
- Abajo a la derecha, el hueco `estadoRed` en texto Detalle, y el "?" de
  los atajos en la esquina.
- El creador de personaje (cuenta vacía o NUEVO PERSONAJE) ocupa el
  hueco `personajes`; la columna de la izquierda queda.

## 2. Sin recortes

- `DsScreenView` dibuja cada elemento a tamaño de diseño y lo escala por
  `s`. El texto adentro usa el "Tamaño del texto" del jugador **sin** el
  factor de ventana (ese ya lo pone `s`): antes se aplicaban los dos y a
  1920×1080 el texto quedaba ×2,25 en una caja ×1,5 (botones cortados).
- Textos y botones de un layout se achican para entrar en su caja si el
  texto grande no entra (nunca se cortan ni se desbordan).
- Los huecos se desplazan si su contenido no entra.
- Tests con golden a 1280×720 y 1920×1080 que fallan ante cualquier
  desborde (`RenderFlex overflowed`) o texto recortado.

## 3. Tarjetas de personaje

Grilla (3 por fila en el hueco por defecto). Ningún dato se corta con
"…": si no entra, baja de renglón. La fecha va corta: `Jugado: 19/11/26`.

## 4. Notas del parche

Botón **VER NOTAS DEL PARCHE** (acción `verNotasParche`) abre un panel:

- Izquierda: lista de versiones, la más nueva arriba (orden semántico,
  no alfabético). Elegir con clic o flechas.
- Derecha: las notas de la elegida renderizadas desde el markdown:
  `#`/`##`/`###` como encabezados (sin negrita, por tamaño y color),
  `- ` como viñetas con sangría, párrafos; `**`, `` ` `` y enlaces se
  muestran como texto plano. Ancho de lectura fijo (≈ 72 caracteres).
- Se desplaza con la rueda, la barra, flechas / RePág / AvPág / Inicio /
  Fin. Esc o CERRAR cierra.
- Fuente: `docs/release_notes/*.md` empaquetados como assets (funciona
  sin red; lo que baja el actualizador solo trae la versión nueva). El
  Mundo lista `vX.Y.Z.md`; la Travesía, `travesia-vX.Y.Z.md`. Archivos
  con otro nombre (notas sin numerar) se ignoran.

### 4.1 Insignia NUEVO (v0.37.1)

- El botón muestra la insignia `NUEVO` (`DsBadge`, al lado del texto)
  cuando la versión más nueva de las notas empaquetadas es posterior a
  la última vista (orden semántico; nunca vistas = hay nuevas).
- Al tocar el botón, la versión más nueva queda como vista y la
  insignia desaparece. Se guarda global (no por cuenta) en los ajustes
  del juego (`game.json`, clave `seenPatchNotes`).
- En el layout de datos, la acción lleva la insignia
  (`ScreenAction.badge`) y el componente botón la dibuja.
