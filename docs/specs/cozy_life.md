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
- **Cámara y HUD:** pescando, la cámara se acerca a `cozyFishZoom` (fracción
  del mapa visible, < 1 = más cerca) con suavizado; el HUD baja a
  `cozyHudOpacity` y se achica a `cozyHudScale`. Al soltar la caña vuelve.
  v0.49.14: el acercamiento ya no tiembla. Avanza lineal en el tiempo
  (`cozyFishZoomSec`, 0.6 s, igual a cualquier FPS) con curva suave
  (smoothstep) de ida y de vuelta, y el centro de la vista queda quieto
  mientras cambia el zoom: el seguimiento de la cámara no pelea con él.
- **Decorar la balsa:** cosmético, barato, en el pescador del bioma
  (pestaña BALSA). Piezas: farol (`raftLanternCost`), techito
  (`raftRoofCost`) y pintura (`raftPaintCost`, 4 colores). Comprar una pieza
  la prende; tocar una comprada la prende/apaga (la pintura es una sola a
  la vez). Se guarda en el perfil (`life.rd` compradas, `life.ro` puestas).

## 2. Huerta cozy

- **Ambiente** (parado en una huerta propia del pueblo): azada al arar,
  agua al regar (eventos), pájaros de día, grillos de noche y lluvia sobre
  los cultivos cuando llueve (`amb.rain`).
- **Decoraciones** en EDITAR PUEBLO, como el faro (mismo flujo: elegir,
  apoyar, mover, borrar): cerco, espantapájaros, maceta, caminito de piedra
  y farolito. 1×1, no sólidas, en pasto o camino. Costo `decor<Id>Cost`.
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
- **Buscar en árboles:** mantener E frente a un árbol común del exterior
  (tile `T`) busca. El anfitrión tira (`CozyRules.searchRoll`):
  semilla del bioma (`searchSeedChance`), hongo (`searchMushroomChance`),
  nido (`searchNestChance`: lombrices) o, rara vez, una **receta de abono**
  nueva (`searchRecipeChance`; si ya las sabe todas, una bolsa de abono).
  Si no sale nada: "Nada esta vez". Da `searchXp` de Cultivo.
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
