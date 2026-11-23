# Spec: Mapa de viaje y exteriores de bioma (v0.26.0; todos los biomas en v0.29.0)

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
- Lista los lugares de `kBiomes`, en orden: PUEBLO, BOSQUE, RUINAS,
  CAVERNAS, GRIETA y ABISMO (v0.29.0). Un bioma todavía cerrado muestra el
  botón gris "ZONA N" con el tooltip "Se abre al llegar a la zona N".
- El lugar actual muestra ACÁ. VIAJAR solo lo puede tocar el dueño del
  mundo (el anfitrión o quien juega solo); al resto el botón le queda gris
  con el tooltip "Decide el anfitrión".
- Viaje instantáneo (sin cinemática en esta pasada).

### 1.1 Desbloqueo (v0.29.0)
- Cada bioma tiene dos zonas (`BiomeDef.zones`); se puede viajar cuando el
  dueño del mundo tiene desbloqueada la primera (`unlockedZone >=
  zones.first`). Lo valida el anfitrión con su perfil (`canTravelTo`).
- BOSQUE 1-2, RUINAS 3-5, CAVERNAS 4-6, GRIETA 7-8, ABISMO 9-10. Las
  familias de enemigos y su escala por nivel son las de cada zona.

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

Todos los exteriores son un `BiomeLayout` de `kBiomeLayouts` (34 × 22,
mismo esqueleto: borde sólido, camino del sur, ramal norte a las dos
entradas, lago con dos muelles, matas, obstáculos y un habitante).
Mapa del Bosque: tema `bosque_ext`: borde de
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

- v0.29.0: sin cambio de protocolo (los ids de bioma nuevos viajan en
  `place` y `travel` como texto).

- Protocolo 46: snapshot `place`; `town.wild`; acciones
  `{"t":"travel","p":"bosque"}` y `{"t":"forage","i":3}`. Host
  autoritativo en todo.
- `TownState.wild` se guarda en el mundo (`accounts/worlds/<id>.json`).
  Al cargarlo (`setWorld`) ningún rebrote espera más que
  `forageRespawnSec` (el reloj de la sala arranca de cero). Saves viejos
  sin `wild` cargan vacío.

## 3.5 Biomas de v0.29.0

Cada uno: tema propio (`map_themes.dart`, solo ahí los colores), lago con
5 peces (2 comunes, raro, épico, legendario) y 2 basuras, 9 matas de 3
productos silvestres, 3 semillas exclusivas (común 0.7, rara 0.25, épica
0.05) y un habitante. Misma pesca y recolección que el Bosque.

| Bioma | Tema | Lago | Peces (legendario al final) | Silvestres | Semillas |
|---|---|---|---|---|---|
| RUINAS | `ruinas_ext` | Estanque de engranajes | Carpa de cobre, Anguila de runa, Pez piñón, Barbo de relojería, Esturión de las Eras | Musgo de cobre, Liquen rúnico, Bayas de engranaje | Lirio mecánico, Calabaza rúnica, Olivo de las Eras |
| CAVERNAS | `cavernas_ext` | Lago helado | Pez de escarcha, Lenguado de cristal, Trucha de hielo, Lucio del eco frío, Pez del Invierno que Vendrá | Cristales de escarcha, Liquen azul, Hongos fríos | Nabo de escarcha, Flor de cristal, Lirio del eco |
| GRIETA | `grieta_ext` | Lago de brasas | Pez ceniza, Bagre de brasa, Salamandra del lago, Dorado ígneo, Pez del Último Fuego | Pimientos de brasa, Flores de ceniza, Raíces ígneas | Chile de volcán, Flor de brasa, Fruta de la forja |
| ABISMO | `abismo_ext` | Mar de ecos | Pez eco, Medusa del mañana, Raya del reloj, Pez paradoja, Leviatán del Futuro Quieto | Polvo de eco, Flores del mañana, Frutos paradoja | Trigo del eco, Rosa del futuro, Árbol paradoja |

- Basura: Engranaje oxidado y Placa rúnica rota (Ruinas), Estalactita
  rota y Guante helado (Cavernas), Escoria y Hueso chamuscado (Grieta),
  Arena de reloj y Manecilla perdida (Abismo).
- Día y noche / clima (day_night_weather.md): los exteriores son al aire
  libre salvo CAVERNAS (`SkyRules.undergroundThemes`): ahí no hay noche
  ni clima.

## 9. Habitantes de bioma (v0.29.0)

Uno por exterior, parado en `BiomeNpcDef.tile` con su sprite
(`items.vida_npc_<id>`, arte provisorio) y su nombre encima. E cerca (26
px) abre su pantalla: una frase (cambia con el día del mundo), el
beneficio que daría en el pueblo y sus semillas en la grilla de oficios
(`LifeItemGrid`, detalle a la derecha).

| Bioma | Habitante | Rol | Beneficio permanente (base + paso por nivel) |
|---|---|---|---|
| BOSQUE | Ilda | Herbolaria | Pociones curan +10 % (+5 %) |
| RUINAS | Velda | Archivista | Mazmorras: 1 sala revelada (+1) al entrar |
| CAVERNAS | Kael | Instructor | +5 % de XP (+3 %) para todo el grupo |
| GRIETA | Brann | Forjador | Mejoras de la forja 5 % (+3 %) más baratas |
| ABISMO | Oren | Vidente | Vida llena al volver y +3 % (+2 %) de vida máxima |

### 9.1 Comercio
- Vende las semillas común y rara de su bioma (`BiomeNpcDef.seeds`,
  precio en oro). Usa la acción de siempre `farmShop buySeed`: el
  anfitrión acepta una semilla que el agropecuario no vende solo si el
  grupo está en el bioma de quien la vende (`BiomeRules.vendorPrice`).
  Sin cambio de red.

## 10. Habitantes en el pueblo (diseño v0.29.0; reglas puras hechas)

El ciclo central: biomas → botín → pueblo → partidas más fuertes. Las
reglas están en `ResidentRules` / `ResidentState` (puras, con test); el
cableado al motor, al guardado y a la UI es deuda (tech_debt.md v0.29.0).
Tunables en Editor → Balance → Pueblo (`res*`).

### 10.1 Invitar
- Relación con el habitante (sube con encargos y pedidos cumplidos). Con
  `resInviteRep` (3) se lo puede invitar al pueblo.
- En EDITAR PUEBLO se pone una CASA (town_editor.md § 3.4) y se le
  asigna. Vive cerca de su casa (camina de día, adentro de noche) y
  conserva su servicio (su grilla de comercio, sus semillas).

### 10.2 Encargos
- Cadena de 2 a 4 pasos por habitante (`kResidentQuests`): recolectar,
  pescar, cultivar, bajar a una mazmorra de su bioma, vencer un élite.
  Cada paso da oro y relación; el último, un objeto único. Se ven en su
  pantalla y en un registro de encargos (subpestañas por habitante,
  grilla, nunca secciones apiladas). Valida el anfitrión; se guarda en el
  mundo. Primera cadena: Ilda (hierbas de rocío ×3, trucha musgosa,
  helecho dulce ×2, Bosque Hondo; premio Frasco de Ilda).

### 10.3 Etapas y beneficio
- Recién llegado → Asentado (`resSettledRep` 5) → Arraigado
  (`resRootedRep` 12). Nivel del beneficio = etapa + nivel del edificio
  − 1 (tope `resMaxTier`), permanente mientras viva en el pueblo y para
  todos los de la sala (lo aplica el anfitrión). Sin casa no hay
  beneficio.
- Valor: `res<rol>Base + res<rol>Step × nivel`. Su pantalla muestra
  "Beneficio: …" y el del nivel siguiente; la fuente, un resumen.

### 10.4 Pedidos, ánimo y edificio
- Cada `resRequestEveryDays` (2) días del mundo, si no tiene pedido,
  pide una mejora: primero subir su edificio (hasta `resMaxHouse` 3, oro
  `resHouseGold` × nivel más botín de su bioma; el sprite cambia por
  nivel y cada nivel abre mejores servicios: mejor stock, opciones de
  forja), después camino a la puerta, faro cerca, huerta o muelle. Se ve
  un "!" sobre él y en el registro.
- Cumplido (construido en la edición, valida el anfitrión): +
  `resRequestRep` (2) de relación y se le pasa el descontento.
- Ignorado `resUnhappyDays` (4) días: "descontento", el beneficio baja un
  nivel (nunca debajo de la base). Nunca se va.
