# Spec: Pesca y comerciante (fase 3 de town_loop.md, v0.22.0)

Precisa town_loop.md § 3.1 (pesca), § 3.3 (comercio), § 10 (red), § 10b
(solo y pocos clics), § 11c (habilidades de vida y herramientas) y § 12.
Solo el Mundo: la Travesía no tiene pueblo (rechaza todas las acciones).

Código: datos en `lib/game_engine/data/fishing_catalog.dart`, reglas
puras en `lib/game_engine/rules/fishing_rules.dart`, minijuego puro en
`lib/game_engine/rules/fishing_minigame.dart`, sala en
`session_engine_fishing.dart`; UI en `panels/fishing_panel.dart` y
`panels/trader_panel.dart`. Tunables: Editor → Balance → **Pesca**
(`TuningId.fishing`).

## 1. Dónde

- Los tres puntos de pesca del lago (`f`, `TownLayout.fishingSpots`):
  E abre el panel PESCA.
- El cartel del lago (`Y`): aviso local con la cantidad de especies del
  lago y tu nivel de Pesca.
- El puesto del comerciante (`M`): E abre COMERCIANTE.
- Se quitaron los avisos "Pronto".

## 2. Peces

`FishDef {id, name, rarity, biome, minCm, maxCm, price, xp, lore}`.
Rarezas: común, raro, épico, legendario.

### 2.1 Biomas y el lago del pueblo
- Cada especie tiene `biome` (`zona1` … `zona10`). Hoy solo existen las
  de `zona1`.
- El lago del pueblo es **del mundo**: `TownState.lake` (lista de ids;
  `null` = las de `zona1`, `kTownLakeDefault`). El anfitrión lo carga con
  `SessionEngine.setWorld(lake:)` y tira los peces solo de esa lista.
- **Futuro (no implementado):** cada bioma tendrá su exterior con lagos
  y especies propias. Un pez de otro bioma se podrá convertir en
  "Cría de <pez>", un objeto que suma esa especie a `TownState.lake`.
  No hace falta tocar reglas: solo agregar la especie a la lista.

### 2.2 Tirada (anfitrión)
- Rareza por pesos `weightComun/Raro/Epico/Legendario` (70/22/7/1). Los
  no comunes × (1 + bonus de rareza), con bonus = rareza efectiva de la
  caña + `distanceBonus` (0.3) × carga del lance.
- Especie al azar entre las del lago de esa rareza (si no hay, baja una
  rareza). Tamaño uniforme en `[minCm, maxCm]`.
- Pity: `pityAfter` (200) capturas sin legendario → legendario seguro.
  La auto-pesca no suma ni consume pity.

### 2.3 Legendarios (tema de ecos)
Carpa del Mañana (eco del futuro), Esturión de la Era Antigua (del
pasado avanzado) y Pez del Reloj Quieto. Nombres propuestos; esperan el
OK del dueño (lore.md).

## 3. Pesca del personaje

`PlayerProfile.life` (`LifeSkills`, JSON `life`): `fx` XP total de
Pesca, `rods` cañas propias, `rod` la equipada, `bag` bolsa de Pescados
(especie → cantidad, apilable, aparte del inventario de armas), `pity`.

- Nivel: XP para pasar del nivel l = `xpBase` × l^`xpExp` (40, 1.5);
  tope `maxLevel` (30).
- XP de Pesca por captura = `xp` de la especie × `xp<Rareza>` (1 / 2.5 /
  6 / 15) × tamaño relativo (cm / promedio, entre 0.5 y 1.6).
- XP de personaje: `charXp<Rareza>` (2 / 5 / 12 / 30) con tope
  `charXpCap` (60) **por estadía en el pueblo** (se reinicia al volver de
  una misión: "por misión del ciclo" de town_loop.md § 11c).
- PERSONAJE (pestaña ATRIBUTOS) muestra una línea OFICIOS: nivel, XP,
  caña y cantidad de pescados.
- Migración: un perfil sin `life` recibe la Caña de rama equipada.

## 4. Minijuego (local, puro)

Fases: listo → carga (mantener; 1.2 s al máximo) → vuelo (0.5 s) →
espera (señuelos) → picada → clavado → barra → sacado / escapado.

- Espera hasta la picada: entre `biteMinSec` y `biteMaxSec` (2.5 / 7)
  × (1 − bonus de picada de la caña). Hasta `nibblesMax` (3) señuelos
  antes: la boya tiembla pero no es la picada.
- Reaccionar antes de la picada real la pierde. La picada dura
  `biteWindowSec` (1.1 s).
- Al clavar, el cliente manda `fBite` y espera el pez del anfitrión
  (3 s sin respuesta = se escapa).
- Barra vertical: la zona sube mientras se mantiene y cae al soltar
  (con inercia); tamaño `zoneBase` (0.24) × (1 + bonus de zona). El pez
  se mueve hacia objetivos al azar, más rápido y más seguido según
  `barSpeed` × `diff<Rareza>` (0.6 / 0.9 / 1.25 / 1.6). El progreso
  arranca en `progressStart` (0.25), sube `progressGain` (0.1/s) con el
  pez adentro y baja `progressDrain` (0.12/s) afuera. Lleno = sacado;
  vacío = escapado. Unos 15–30 s por pez contando la espera.
- Sensación: boya que tiembla y se hunde, anillo en la picada,
  salpicadura de partículas al caer y al sacar, sacudida de la escena
  con el pez afuera, sonidos del banco (lance, caída, señuelo, picada,
  tirón, sacado, escapado).
- Mouse/toque mantenido o Espacio. Cerrar el panel en plena pelea cuenta
  como escapado.
- Arte procedural (`ui: escena_pesca, icono_pez` en
  `sprite_manifest.yaml`); colores en `FishingPalette`.

## 5. Cañas y comerciante

### 5.1 Cañas (espacio de herramienta, aparte de las armas)
| Caña | Rareza | Nivel | Picada | Zona | Rareza+ | Precio |
|---|---|---|---|---|---|---|
| Caña de rama | común | 1 | 0 | 0 | 0 | inicial |
| Caña de roble | raro | 5 | 15 % | 15 % | 20 % | 400 |
| Caña de bronce rúnico | épico | 12 | 30 % | 30 % | 45 % | 1500 |
| Caña del Eco | legendario | 22 | 45 % | 50 % | 80 % | 5000 |

Efectividad (town_loop.md § 11c): `ratio = clamp(nivel / requerido, 0,
1)`, `bonus = base × (bonusFloor + (1 − bonusFloor) × ratio^bonusCurve)`
(0.4, 1.5). Se compran en el comerciante y se equipan ahí.

### 5.2 Venta
- Por especie (VENDER) o VENDER TODO (no incluye legendarios).
- Cobrar en ORO (precio base) o en MATERIALES (se elige en cada venta):
  valor × `matRate` (1.2) en Esquirlas del Eco, una cada `matValue` (25)
  de oro; el resto se paga en oro.
- Legendario: CANJEAR → `legendCristales` (3) Cristales de Era +
  `legendPrismas` (1) Prisma Roto.
- Cebos y ofertas rotativas: más adelante (la tabla de cañas ya tiene
  precio, el panel lista lo que está en el catálogo).

## 6. Auto-pesca

Botón AUTO-PESCA del panel: `autoCount` (3) peces de una, con XP ×
`autoMult` (0.4), tamaños de la mitad baja del rango, **nunca
legendarios**; espera `autoCooldownSec` (30 s) del anfitrión entre usos.

## 7. Red (protocolo 42)

- Acciones: `fBite {pw}` (clavó; carga del lance), `fRes {ok}`,
  `fAuto`, `fSell {sp?, mat?}`, `fSwap {sp}`, `rodBuy {r}`, `rodEq {r}`.
- Eventos: `fBite {id, sp, cm}` (el pez que tiró el anfitrión),
  `fCaught {id, sp, cm, auto?}`.
- El anfitrión valida: en el pueblo, no compañero, parado en un punto de
  pesca, caña equipada propia, `minCastSec` (2 s) entre picadas, una
  picada pendiente por jugador y `minReelSec` (1.5 s) mínimos de pelea.
  El cliente solo dice si lo sacó; especie, tamaño y rareza los decide
  el anfitrión. Estado no persistido (`SessionEngine.fishing`).
- Chat: "X se puso a pescar." (una vez por estadía), "X pescó <pez> (N
  cm, rareza)." y subidas de nivel de Pesca.
- El perfil lleva `life`; viaja como siempre en `hello` y en el estado.
