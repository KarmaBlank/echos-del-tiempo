# Spec: Mapa de viaje y exteriores de bioma (v0.26.0, primera pasada)

Estado: implementado en v0.26.0. Precisa `town_loop.md` § 2 y § 11b
(exteriores y refuerzos) y § 6 (dificultad por sala). Lore: únicamente
`docs/lore.md`. Números tunables en Editor → Balance → Pueblo
(`kTuning[TuningId.town]`).

Código: `lib/game_engine/data/biomes_catalog.dart` (lugares, layout del
Bosque, peces y semillas), `lib/game_engine/rules/biome_rules.dart`
(reglas puras), `session_engine_biome.dart` (acciones del host),
`panels/travel_panel.dart` (UI). Tests:
`test/game_engine/overworld_biomes_test.dart`.

## 1. Mapa de viaje

- Se abre con E en el **camino del borde sur** (las dos últimas filas,
  sobre tile de camino) del pueblo y de cada exterior, o con MAPA DE
  VIAJE en la fuente rúnica (por si una ampliación tapa el camino).
- Lista los lugares de `kBiomes`, en orden: PUEBLO, BOSQUE (abiertos) y
  RUINAS, CAVERNAS, GRIETA en gris con "Próximamente" (botón deshabilitado
  gris, sin tooltip: el motivo ya está escrito).
- El lugar actual muestra ACÁ. VIAJAR solo lo puede tocar el dueño del
  mundo (el anfitrión o quien juega solo); al resto el botón le queda gris
  con el tooltip "Decide el anfitrión".
- Viaje instantáneo (sin cinemática en esta pasada).

## 2. Lugar del grupo

- `GameSession.place`: `null` = pueblo, si no el id del bioma
  (`bosque`). Viaja en el snapshot (`place`, protocolo 48).
- `SessionEngine.mapFor`: en `lobby` / `prep` sin misión, si `place` es
  `bosque` devuelve `MapGenerator.bosque(picked)`; si no, el pueblo.
- El mapa del exterior es `lobby = true` (zona segura, sin combate) y
  lleva `GameMap.place`; `WorldRules.townSpot` no ofrece los lugares del
  pueblo ahí, y la capa de la huerta, sus carteles y la edición del
  pueblo no se dibujan.
- Al volver de cualquier mazmorra (`toLobby`) el grupo aparece en el
  **pueblo** (ahí está el comerciante): `place = null`.

## 3. Exterior del Bosque

Mapa a mano de 34 × 22 (`BosqueLayout`), tema `bosque_ext`: borde de
árboles, camino de tierra del sur al cruce del norte, lago al este con dos
muelles, ocho matas y dos entradas de mazmorra.

### 3.1 Lago del Bosque
- Tabla propia `kForestFish`: Mojarra de sombra, Bagre de raíz (comunes),
  Trucha musgosa (rara), Lucio rúnico (épico) y **Salmón del Eco Quieto**
  (legendario: un eco del futuro que remonta un río que todavía no
  existe; siempre llega).
- Misma pesca de siempre (barra, caña, muelles con `dockBonus`, pity,
  botín del agua). Sin bonus de lago del pueblo (ni capacidad ni cría).
- Basura del Bosque: Hojarasca mojada y Rama empapada.
- La auto-pesca sigue usando el lago del pueblo.

### 3.2 Recolección
- 8 matas (`BosqueLayout.forage`) de 3 tipos: **Moras**, **Hierbas** y
  **Hongos**, que dan Moras del bosque, Hierba de rocío y Hongo ámbar
  (productos silvestres, bioma `silvestre`: van a la bolsa de cosechas
  con calidad normal y se venden al comerciante como cualquier cosecha).
- E a menos de 26 px del centro de la mata. El host valida distancia y
  rebrote; otorga y marca `TownState.wild["bosque:<i>"] = ahora +
  forageRespawnSec` (240 s). La mata se ve pelada (`Q`) hasta rebrotar.
- Cuenta como **Cultivo**: `forageXp × (rareza + 1)` de XP de Cultivo.
  Sin XP de personaje en esta pasada.
- Con `forageSeedChance` (0.12) también da una semilla del Bosque.

### 3.3 Semillas del Bosque
- `kForestSeeds` (peso): Helecho dulce (común, 0.7), Arándano de sombra
  (raro, 0.25), Seta del reloj (épica, 0.05). Son `CropDef` con bioma
  `bosque`: se plantan en la huerta del pueblo como cualquier semilla y
  pueden devolver semilla al cosechar.
- No se venden ni salen de los hallazgos de la huerta
  (`FarmingRules.rareSeed` solo sortea las del pueblo).

### 3.4 Entradas de mazmorra
- Pradera Esmeralda (zona 1) y Bosque Hondo (zona 2), con el arco de
  siempre (`ZoneEntrance`): E propone la misión de la zona o vota que sí,
  con el desbloqueo de siempre. El tablero del pueblo sigue andando igual.

## 4. Party

- Primera pasada: **todos viajan juntos**, lo decide el anfitrión
  (`TravelAction`). Al viajar, todos aparecen alrededor de la llegada del
  lugar.
- Futuro (deuda): party dividida, `ubicación` por jugador
  (`pueblo | bioma:<id> | mazmorra:<id>:<piso>`, town_loop.md § 11b).

## 5. Refuerzos

- Quien entra a la sala mientras el grupo está en una misión aparece en
  la llegada del piso actual (ya era así).
- Si hay batalla, entra a esa pelea (`BattleEngine.join`) con su primer
  turno en `reloj + intervalo × (1 + reinforceDelay)` (1 intervalo
  extra). En el tutorial no hay demora. Aviso en el chat.
- Los modos por ronda / por bando reparten turnos a su manera; la demora
  vale para la línea de tiempo (ver deuda).

## 6. Dificultad por sala

- `BiomeRules.roomSize(presentes, ausentes)` = presentes + ausentes ×
  `absentWeight` (0.6). `BattleEngine.start(roomExtra:)` interpola vida
  y ATQ de los enemigos entre el tamaño del grupo y el siguiente.
- Hoy todos los de la sala bajan juntos, así que `roomExtra = 0` siempre;
  la regla queda lista para la party dividida.

## 7. Tunables (Pueblo)

| Clave | Valor | Qué |
|---|---|---|
| `forageRespawnSec` | 240 | Rebrote de cada mata (s) |
| `forageSeedChance` | 0.12 | Chance de semilla del Bosque al recolectar |
| `forageXp` | 6 | XP de Cultivo base por recolectar |
| `reinforceDelay` | 1 | Intervalos extra del refuerzo en batalla |
| `absentWeight` | 0.6 | Peso de cada ausente en la dificultad |

## 8. Red y guardado

- Protocolo 46: snapshot `place`; `town.wild`; acciones
  `{"t":"travel","p":"bosque"}` y `{"t":"forage","i":3}`. Host
  autoritativo en todo.
- `TownState.wild` se guarda en el mundo (`accounts/worlds/<id>.json`).
  Al cargarlo (`setWorld`) ningún rebrote espera más que
  `forageRespawnSec` (el reloj de la sala arranca de cero). Saves viejos
  sin `wild` cargan vacío.
