# Variantes procedurales de NPC

Muchos NPC (visitantes y peregrinos de eventos, PNJ de la mina,
pescadores de los campamentos de bioma) compartían el mismo sprite
provisorio. Este sistema genera, a partir de unos pocos cuerpos base, una
variante distinta por NPC, determinista y pixel-perfect. Los habitantes
(Ilda, Velda, Kael, Brann, Oren) conservan su sprite hecho a mano.

## 1. Datos

`assets/sprites/npc_variants.yaml`, leído **solo** por `SpriteCatalog`
(`loadNpcVariants`). Nada de esto está en Dart.

- `bases`: cuerpo base = clave de `items:` del manifest + qué color del
  PNG pertenece a qué región (`hair`, `skin`, `clothes`, `pants`,
  `accent`, con sufijos `_dark` / `_light` para sombras y brillos). Los
  colores sin región (contorno, ojos, metal) no cambian.
- `palettes`: colores curados por región (tonos de fantasía medieval;
  `magitec` para autómatas). Nunca colores al azar.
- `parts`: partes en capas como grilla de caracteres (`.` vacío, `o`
  contorno, `h` pelo, `s` piel, `c`/`C` ropa, `p` pantalón, `a`/`A`
  acento, `m`/`M` metal, `w` madera, `g` brillo magitec), con `slot`
  (`head`, `chin`, `neck`, `back`, `hand`, `magitec`), `anchor` y
  `pivot`. `under: true` pinta solo sobre transparente (mochilas).
- `variants`: una por NPC. La clave es el id de sprite que ya usa el juego
  (`npc_ev_visitante`, `npc_mina_miner`, `npc_pesc_bosque`, ...) con
  `base`, `seed`, `palette`, `parts` (permitidas), `tweak` y, opcional,
  `fixed` (aspecto congelado, § 5).

## 2. Generación (`lib/core/procedural/npc_variants.dart`, Dart puro)

1. RNG `splitmix32` con la semilla (igual en toda plataforma).
2. Un color por región de la paleta (siempre se consume un número por
   región, así cambiar una paleta no corre las demás elecciones).
3. Por ranura, entre las partes permitidas: va con probabilidad 0.65
   (la ranura `magitec` siempre va).
4. Retoque de silueta (si `tweak`): con 50 %, si la fila superior está
   vacía se quita y se duplica la primera fila de ropa: torso un píxel
   más alto, mismos pies, mismo tamaño.
5. Anclas calculadas de las regiones (sin coordenadas a mano): `top`
   (centro de la fila más alta), `chin` (debajo de la piel de la cara),
   `back` (borde izquierdo del torso), `hand` (borde derecho, a media
   altura).
6. Se pintan las partes. Todo sobre RGBA crudo: sin re-muestreo, sin
   suavizado; la transparencia del base se conserva.

## 3. Carga y rendimiento

`SpriteCatalog.npcVariantImages()` genera todas las variantes **una vez**
y las cachea como `ui.Image`. `GameSprites.load` las suma al mapa de
íconos de oficio con su id (`lifeIcon('npc_ev_visitante', ...)`), así que
el dibujo por frame no cambia ni cuesta nada extra. La entrada
`items.vida_<id>` del manifest queda como respaldo si la variante falla;
si el Editor tiene un override PNG de esa entrada, gana el override.

## 4. Override local

`overrides/npc_variants.yaml` (interfaz `NpcVariantsOverrideSource`,
carpeta de overrides del Editor) reemplaza al del repo entero cuando
existe. Roto o ausente = el del repo.

## 5. Editor: Visuales → VARIANTES NPC

Grilla de NPCs con variante | vista previa grande | receta:

- slider de semilla, **GENERAR** (vuelve a generar de la semilla) y
  **RE-ROLL** (otra semilla);
- cuerpo, paleta y partes permitidas como botones; muestra los colores
  elegidos;
- **GUARDAR COMO FIJO**: congela colores, partes y retoque en `fixed:`;
  el juego deja de regenerarlo. Tocar cualquier perilla suelta lo fijo.
  Sin `fixed`, el NPC se regenera de la semilla en cada carga (mismo
  resultado siempre);
- **GUARDAR RECETA**: guarda semilla/paleta/partes;
- **NUEVO NPC**: copia el aspecto actual a un id nuevo (`a-z0-9_`); ese
  id se usa como `sprite` en los datos del NPC.

## 6. Tests (`test/core/procedural/npc_variants_test.dart`)

Determinismo, semillas distintas → imágenes distintas, recoloreo que
conserva transparencia, retoque que conserva tamaño y pies, aspecto fijo
(ignora la semilla, sobrevive encode/parse), que todo NPC de eventos,
mina y pescadores tenga variante y resuelva, presupuesto de carga
(< 1.5 s para todas) y el flujo del Editor (re-roll, fijo, nuevo).
