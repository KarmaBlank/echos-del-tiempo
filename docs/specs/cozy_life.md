# Spec: Vida cozy (rama feat/cozy-life, protocolo Mundo 91)

Primer paso del orden del dueño. Sigue `design_pillars.md`. Código puro en
`lib/game_engine/rules/cozy_rules.dart` y `data/cozy_catalog.dart`; sala en
`session_engine_cozy.dart` (parte de `session_engine.dart`). Tunables:
Editor → Balance → **Regiones de bioma** (`TuningId.regions`, claves
`cozy*`, `gather*`, `search*`, `raft*`, `decor*`, `scarecrow*`).

Fuera de alcance (pasos siguientes): modo automático con R, widget de
escritorio, tienda, jefes e invocaciones.

## 1. Pesca cozy

- **Música:** pescando (o en balsa) fuera del pueblo suena `Music.cozy`
  (charango lento, 66 bpm, procedural en `tracks/cozy_theme.dart`) a
  `cozyMusicLevel`. En el pueblo sigue la ocarina de `Music.fishing`.
  No hay pista grabada: la pieza es procedural (hook en el catálogo de
  música; cambiar la pieza es cambiar el id).
- **Ambiente:** cada `cozyAmbGapMinSec`–`cozyAmbGapMaxSec` s suena, según
  el lugar y la hora, agua (`amb.water`), pájaros de día (`amb.bird`) o
  grillos de noche (`amb.cricket`), además del soplo/goteo de
  `biome_regions.md § 7.2.3`. Recetas procedurales en `sfx_recipes.dart`
  (sin archivos de audio; hooks `Sfx.amb*`).
- **Luciérnagas:** de noche, pescando o en balsa, hasta `cozyFireflies`
  puntitos de luz que flotan cerca del jugador sobre el agua
  (`fishing_layer.dart`).
- **Cámara y HUD:** pescando, la cámara se acerca un nivel entero del
  zoom del mundo (`worldZoomFishSteps`, ver `exploration.md § Cámara`,
  "Zoom del mundo"), con corte instantáneo; si el jugador ya está en el
  nivel máximo no hay acercamiento. El HUD baja a `cozyHudOpacity`. Al
  soltar la caña vuelve al nivel elegido por el jugador. El HUD, los
  menús y los paneles nunca cambian de tamaño ni de lugar. v0.49.28:
  reemplaza el acercamiento fraccional suave (`cozyFishZoom`,
  `cozyFishZoomSec`, quitados), que deformaba el pixel art.
- **Decorar la balsa:** cosmético, barato, en el pescador del bioma
  (pestaña BALSA). Piezas: farol (`raftLanternCost`), techito
  (`raftRoofCost`) y pintura (`raftPaintCost`, 4 colores). Comprar una pieza
  la prende; tocar una comprada la prende/apaga (la pintura es una sola a
  la vez). Se guarda en el perfil (`life.rd` compradas, `life.ro` puestas).
  Pantalla (v0.49.33): grilla de INVENTARIO (`LifeItemGrid`), sin precio
  debajo de la casilla; el precio (`₵`), si la tenés y si está puesta
  van en la ficha del mouse y en el detalle. COMPRAR gris sin oro, con
  el motivo en el tooltip.

## 2. Huerta cozy

- **Ambiente** (parado en una huerta propia del pueblo): azada al arar,
  agua al regar (eventos), pájaros de día, grillos de noche y lluvia sobre
  los cultivos cuando llueve (`amb.rain`).
- **Decoraciones** en EDITAR PUEBLO, como el faro (mismo flujo: elegir,
  apoyar, mover, borrar): cerco, espantapájaros, maceta y farolito. El
  caminito de piedra pasó a ser un camino de Piedra de la herramienta
  CAMINOS (town_editor.md § 4.6); los saves viejos se migran solos. 1×1, no sólidas, en pasto o camino. Costo `decor<Id>Cost`.
  Viajan en `town.dc` (`[[id, x, y], ...]`). Id estable `deco@x,y`.
- **Espantapájaros:** +`scarecrowQualityBias` de sesgo de calidad en las
  parcelas a `scarecrowRadius` tiles o menos (no se acumula). Opcional y
  chico (pilar 4).

## 3. Recolectar manteniendo E

- Las matas del exterior ya no se toman con un toque: **mantener E** (o el
  click) llena una barrita como la de la mina; al completarse se manda
  `ForageAction`. Soltar antes cancela. Con el mouse (v0.49.9, sin
  herramienta en la mano): mantener el clic sobre la mata (o un tile al
  lado) o sobre el árbol de enfrente hace lo mismo que mantener E
  (`gatherPress`, soltar = `gatherHoldEnd`); un clic sobre una parcela
  madura cosecha, como E. Los avisos dicen `[Mantené E/Clic]`.
- Duración: `gatherHoldSec × (1 − gatherSpeedPerLevel × (nivel de Cultivo
  − 1))`, nunca menos que `gatherHoldMinSec`.
- **Mantener = repetir (v0.49.16):** mientras E o el botón del mouse
  siguen apretados, cada `holdRepeatSec` s se vuelve a mirar el objetivo
  (E: lo de enfrente; clic: el tile bajo el cursor con las mismas reglas
  del clic, si no lo de enfrente) y, si hay uno válido, se hace la acción
  de nuevo: picar (el pico sigue a su ritmo de golpe y, con el mouse,
  apunta al tile al lado bajo el cursor), arar / plantar / regar /
  cosechar la parcela de enfrente, o empezar la barrita en la próxima
  mata o árbol. Caminar no corta el mantener; solo una barrita en curso
  se reinicia si cambia su objetivo. Cada objetivo se trabaja una vez por
  mantener (la misma parcela no pasa de plantar a regar sola; un árbol ya
  buscado hoy se saltea sin aviso). Hablar, abrir cofres o paneles,
  viajar y los santuarios siguen siendo de un solo toque: el repetir
  nunca llama a `interact`. En co-op cada repetición manda la misma
  acción que un toque.
- **PNJ de la mina** (minera / ermitaño): E o clic a su lado abre su
  cuadro de diálogo (panel `mineNpc`) con su frase del día; hablar tiene
  prioridad sobre picar (antes solo dejaba una línea en el chat y el clic
  con el pico picaba).
- **Buscar en árboles:** mantener E frente a un árbol común del exterior
  (tile `T`) busca. El anfitrión tira (`CozyRules.searchRoll`):
  semilla del bioma (`searchSeedChance`), hongo (`searchMushroomChance`),
  nido (`searchNestChance`: lombrices) o, rara vez, una **receta de abono**
  nueva (`searchRecipeChance`; si ya las sabe todas, una bolsa de abono).
  Si no sale nada: "Nada esta vez". Da `searchXp` de Cultivo.
- **Árboles buscables:** no todos. Cada día, cerca de `treeSearchFraction`
  (0.33) de los árboles del exterior con un lado caminable se pueden
  buscar; la elección es determinista por bioma + día + tile
  (`CozyRules.searchable`, hash FNV), igual en todos los pares sin estado
  extra en la red, y cambia al día siguiente. El anfitrión rechaza los
  demás y el cliente no muestra aviso frente a ellos. Los buscables se
  mueven suave y sueltan un par de hojitas de píxel (`TreeRustleLayer`,
  solo tiles en pantalla); una vez buscado hoy, se quedan quietos.
  En el pueblo no se busca (solo exteriores de bioma).
- **Límite diario:** cada árbol una vez por jugador por día; clave
  `wx:<jugador>:<bioma>:v<layout>:t<x>.<y>:<día>` en `town.daily` (misma
  poda y migración que el botín de la intemperie, `wild_loot_rules.dart`).
- **Recetas de abono** (`kCompostRecipes`): cosechas → bolsas de abono.
  Se preparan desde el diario de Cultivo (PREPARAR). Se guardan en
  `life.farm.rc`.

## 4. Diarios de oficio (DIARIO [J] → pestaña OFICIOS)

Subpestañas solo de los oficios que el jugador tiene (algo hecho):
PESCA (especies, récord, dónde y cuándo la pescó por primera vez:
`life.ff` especie → `[día, lugar, veces]`), MINERÍA (minerales y vetas
de `life.ol`), CULTIVO (cosechas de `cropLog`, semillas que tiene y
recetas de abono). Grilla con detalle a la derecha (`LifeItemGrid`). No
toca PERSONAJE → OFICIOS.

## 5. Red

Host autoritativo. Acción nueva `cozy` (`CozyAction`: `op` search /
raftDeco / compost, `id`, `x`, `y`). Nuevos campos: `town.dc`,
`life.rd`, `life.ro`, `life.ff`, `life.farm.rc`. **Mundo protocolo 91**
(otras ramas usan 89 → 90; esta rama salta a 91 para no chocar).
