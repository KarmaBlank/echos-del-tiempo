# Spec: Editor de pantallas (screen editor)

Pedido del dueño: en el Editor, poder editar libremente y "lindo" las
pantallas del juego, empezando por la pantalla de TÍTULO (la actual "me
parece muy horrible"). Complementa a editor_layout.md: aquel mueve
*slots* entre *regiones* de pantallas armadas en código (sin x/y); éste
compone una pantalla entera sobre un lienzo con posiciones y anclas.

Estado: implementado (fase 1: TÍTULO). Las demás pantallas siguen con
editor_layout.md hasta que se registren acá (§ 8).

## 1. Piezas y dónde viven

| Pieza | Archivo | Qué hace |
|---|---|---|
| Registro del sistema de diseño | `lib/app/design/registry/ds_registry.dart` | `DsRegistry`: cada componente registra id, nombre, nivel (Átomo / Molécula / Organismo / Plantilla), variantes, tamaños, props editables y fábrica de vista previa |
| Componentes registrados | `lib/app/design/registry/ds_registry_defaults.dart` | La lista de los componentes del DS que la paleta ofrece |
| Vista en tiempo de ejecución | `lib/app/design/registry/ds_screen_view.dart` | `DsScreenView`: dibuja un `ScreenLayout` con los componentes del registro y los *bindings* de la pantalla |
| Modelo (datos) | `lib/core/screen_layout/screen_layout.dart` | `ScreenLayout` / `ScreenElement`, JSON, anclas y colocación |
| Bindings por pantalla | `lib/core/screen_layout/screen_bindings.dart` | Acciones, fuentes de datos (con datos de ejemplo) y huecos con nombre de cada pantalla |
| Lector único | `lib/core/screen_layout/screen_layout_catalog.dart` | `ScreenLayoutCatalog`: única clase que lee `assets/layouts/<pantalla>.screen.json` |
| Editor | `lib/features/screen_editor/` | Controlador, chequeos (VERIFICAR), guardado en disco y la página PANTALLAS del Editor. Carpeta cohesiva: se muda entera a `apps/echoes_editor` en la migración a monorepo |

## 2. Archivo de layout

`assets/layouts/<pantalla>.screen.json` (la carpeta ya está en el
pubspec). Coordenadas en píxeles de diseño sobre la resolución base del
juego (`width` × `height`, 1280 × 720):

```json
{
  "screen": "title", "version": 1, "width": 1280, "height": 720,
  "elements": [
    {"id": "title-name", "component": "text", "text": "ECOS DEL TIEMPO",
     "textStyle": "display", "role": "titulo", "variant": "normal",
     "x": 240, "y": 56, "w": 800, "h": 64,
     "hAnchor": "center", "vAnchor": "top", "align": "center"},
    {"id": "title-quit", "component": "button", "variant": "peligro",
     "text": "SALIR DEL JUEGO", "action": "salirDelJuego", "focusOrder": 3,
     "x": 1000, "y": 650, "w": 240, "h": 40,
     "hAnchor": "right", "vAnchor": "bottom"}
  ]
}
```

- El orden de `elements` es el orden Z (el último queda arriba).
- `component`, `variant`, `size`, `textStyle` solo admiten valores del
  registro: **nunca colores libres**. El color sale de la variante (tono)
  y del estilo de texto, y éstos de los tokens del tema.
- `action`, `dataSource` y `slot` son **nombres** del registro de
  bindings de la pantalla; el archivo nunca tiene código.
- Desconocido = se ignora con log (un componente que ya no existe no
  rompe la pantalla).

### 2.1 Anclas y escala

Escala `s = min(anchoVentana / width, altoVentana / height)`. Por eje:

| Ancla | Posición |
|---|---|
| `left` / `top` | distancia al borde izquierdo / superior × `s` |
| `right` / `bottom` | distancia al borde derecho / inferior × `s` |
| `center` | desplazamiento desde el centro × `s` |
| `stretch` | márgenes a ambos bordes × `s`; el tamaño llena el resto |

El contenido se dibuja a tamaño de diseño y se escala por `s` (pixel
art nítido; el texto respeta los estilos del DS). `align` (start /
center / end) alinea el texto dentro de su caja.

## 3. Carga en el juego

`ScreenLayoutCatalog.instance.load()` se llama desde
`LayoutCatalog.instance.load()` (los flavors ya lo hacen al arrancar).
`get(screen)` devuelve el layout válido o `null`. La pantalla de TÍTULO
usa el layout si existe; si falta o no parsea, dibuja la pantalla
armada en código de siempre (fallback). En el Editor (flavor admin) el
catálogo lee del repo en disco, así lo guardado se ve sin recompilar.

## 4. Bindings: lo visual no sabe de lógica

Cada pantalla registra un `ScreenBindingSpec` (dato puro):

- **Acciones** (`configuracion`, `salirDelJuego`, `ayudaTeclas`,
  `nuevaPartida`, ...): nombre + etiqueta. En el juego la pantalla da un
  `ScreenAction(onPressed, tooltip)` por nombre; una acción sin handler
  (o `onPressed == null`) deja el botón deshabilitado, gris.
- **Fuentes de datos** (`personajes`, `inventarioJugador`,
  `semillasAyudante`): nombre + etiqueta + datos de ejemplo. El editor
  muestra con ellos qué ítems aparecerían; en el juego la pantalla
  entrega la lista real.
- **Huecos** (`slot`): organismos ligados a lógica que la pantalla
  arma ella misma (TÍTULO: `personajes` = mundo + selector + sala /
  creador; `avisos` = versión nueva y avisos de la cuenta; `estadoRed`).
  El layout decide dónde van y su tamaño, nunca qué hacen.

## 5. El editor (Editor → PANTALLAS)

- **Paleta** a la izquierda con subpestañas ÁTOMOS / MOLÉCULAS /
  ORGANISMOS / PLANTILLAS, en grilla. Sale del registro: un componente
  nuevo que se registre aparece solo.
- **Lienzo** a la resolución del juego, escalado para entrar. Clic =
  elegir; arrastrar = mover con imán a la grilla de 8 px; la esquina
  inferior derecha = redimensionar. Barra: GRILLA, ADELANTE / ATRÁS
  (orden Z), DUPLICAR, BORRAR, DESHACER.
- **VISTA PREVIA** en tamaños comunes de ventana (1280×720, 1366×768,
  1600×900, 1920×1080, 2560×1440, 1280×800, 1024×768) con las anclas
  aplicadas.
- **Inspector** a la derecha: texto, variante y tamaño (solo los del
  componente), estilo de texto (solo los del DS), rol semántico, ancla
  horizontal y vertical, alineación, orden de foco, acción, fuente de
  datos (con la lista de ítems que aparecerían) o hueco; x/y/ancho/alto.
- **GUARDAR** escribe `assets/layouts/<pantalla>.screen.json` en el repo
  y recarga el catálogo. **RESTAURAR** vuelve a lo guardado.

## 6. VERIFICAR

Corre por elemento y lista avisos con arreglo sugerido; los que se
pueden arreglar solos traen **APLICAR**.

| Chequeo | Regla | Arreglo |
|---|---|---|
| Contraste | texto vs fondo (superficie de abajo o fondo de pantalla, por tokens) ≥ 4,5:1; ≥ 3:1 en Título / Display | variante de tono normal |
| Texto mínimo | tamaño nominal × escala en la ventana más chica (1024×768) ≥ 7 px | estilo Texto |
| Jerarquía | un solo `titulo`; los `subtitulo` debajo del título; no hay subtítulo sin título | bajar a subtítulo |
| Rol vs estilo | `titulo` → Display/Título, `subtitulo` → Subtítulo, `texto` → Texto, `detalle` → Detalle | estilo del rol |
| Objetivo de clic | interactivos ≥ 32 × 32 efectivos en la ventana más chica | agrandar |
| Texto recortado | el texto medido con su estilo entra en su caja | agrandar la caja |
| Orden de foco | todo interactivo tiene orden, sin repetidos, y sigue la lectura (arriba→abajo, izq→der) | renumerar |
| Deshabilitado gris | botón sin acción (o acción inexistente) queda gris; no puede pedir acento | variante secundaria |
| Bindings | fuente de datos / hueco existe en la pantalla | primera disponible |
| Fuera del lienzo | la caja entra en la resolución base | meter adentro |

## 7. Reglas que respeta

Sin literales de color fuera de los archivos de tema; sin negritas; sin
esquinas redondeadas; tooltips con el tope fijo del DS; textos de UI en
castellano rioplatense; nombres de código en inglés.

## 8. Pendiente

- Registrar el resto de las pantallas (pausa, lobby, ajustes) con sus
  bindings y huecos.
- Plantillas con hijos (DsColumnsTemplate / DsTransferTemplate con
  contenido anidado): hoy la plantilla registrada es la superficie de
  panel; las plantillas con hijos se colocan como huecos.
- Override local + PUBLICAR AL REPO como en editor_layout.md (hoy
  GUARDAR escribe directo en el repo).
- Selección múltiple y guías de alineación.
