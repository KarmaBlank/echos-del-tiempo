# Spec: Pantalla de título

Pedido del dueño (sobre v0.36.0, captura a 1920×1080): el título nuevo
"se ve horrible y está roto": botones de abajo cortados a la mitad,
tarjeta del personaje cortada, fechas con "…", BUSCAR encima de la
versión y todo metido en un panel grande con borde. Esta spec fija el
título por defecto. El layout es dato (`assets/layouts/title.screen.json`,
docs/specs/screen_editor.md); la pantalla armada en código (fallback,
sin archivo) sigue la misma disposición.

## 1. Disposición (v0.37.4: menú mínimo + flujo por pasos)

Pedido del dueño (sobre v0.37.2): el título tiene que ser minimalista y
JUGAR tiene que ser la primera acción obvia (a la izquierda confundía).
Lienzo de diseño 1280×720 (todo escala igual hasta 2560×1440):

```
                         ECOS DEL TIEMPO

                          > JUGAR          (principal)
                          VER NOTAS DEL PARCHE [NUEVO]
                          OPCIONES
                          SALIR

 v0.37.4 [BUSCAR]                       avisos / red      [?]
```

- Solo el nombre del juego, centrado, sin subtítulo.
- Menú principal centrado: JUGAR (principal, arriba), VER NOTAS DEL
  PARCHE (con la insignia NUEVO, § 4.1), OPCIONES (los ajustes) y SALIR
  (tono peligro, confirma). Nada más: personajes, mundos, alijo, build,
  bestiario y hazañas viven dentro del flujo de JUGAR (§ 1.1).
- Abajo a la izquierda, el hueco `version`: la versión instalada y
  BUSCAR (buscar actualizaciones; mientras busca, "buscando"; si falla,
  el motivo y REINTENTAR). Si hay una versión nueva, en su lugar solo el
  botón compacto ACTUALIZAR; después, el porcentaje de la descarga o
  REINTENTAR si falla. Nunca el panel grande de actualización (no entra
  en la esquina).
- Abajo a la derecha, el hueco `estadoRed` en texto Detalle, y el "?" de
  los atajos en la esquina. Arriba a la derecha, `avisos` (cuenta).

### 1.1 Flujo de JUGAR (un paso por pantalla)

Cada paso es una pantalla propia, con su título, VOLVER (abajo a la
izquierda, también Esc) y la acción para seguir (abajo a la derecha).

1. Modo: SOLITARIO o COOPERATIVO.
2. SOLITARIO → Mundo → Personaje → entra al juego.
3. COOPERATIVO → CREAR SALA o UNIRSE (deshabilitados con el motivo en
   texto si la red no está disponible).
   - CREAR SALA → Mundo → Personaje → abre la sala como anfitrión.
   - UNIRSE → Código (un solo campo; menos de 4 caracteres: "Escribí el
     código de la sala.") → Personaje → se une.
- Mundo: la lista de mundos agrupada por etiqueta con CREAR, CAMBIAR
  NOMBRE y BORRAR (con confirmación); CONTINUAR sigue con el elegido.
  La Travesía no tiene mundos: se saltea el paso.
- Personaje: carrusel de tarjetas (flechas anterior / siguiente, el
  elegido centrado; la tarjeta "+ NUEVO" al final si hay lugar). Debajo,
  NUEVO PERSONAJE, CAMBIAR NOMBRE, BORRAR, ALIJO, BUILD, BESTIARIO y
  HAZAÑAS (las del Mundo; la Travesía solo las tres primeras). La
  acción principal dice JUGAR, CREAR SALA o UNIRSE según el camino;
  doble clic o Enter sobre el elegido hace lo mismo. Con la cuenta vacía
  (o NUEVO PERSONAJE) se ve el creador en el mismo paso.
- Al volver de una partida se vuelve al menú principal (con el motivo
  de la desconexión en `estadoRed`, si lo hubo). Un error al conectar
  deja al jugador en el paso Personaje con el motivo.
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

En el carrusel del paso Personaje (§ 1.1). Ningún dato se corta con
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
