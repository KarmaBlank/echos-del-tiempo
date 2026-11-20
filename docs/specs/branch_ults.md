# Spec: ULT de camino en armas (v0.8.1)

Pedido del dueño: "3 ULTs por camino elegido". Decisión posterior: **no van
en el árbol**; salen en **armas**, como un mod especial "ULT: <nombre>"
(como "otorga habilidad" de los ARPG). El árbol no cambia.

Implementación: `lib/game_engine/data/branch_ults_catalog.dart`
(`kBranchUltList`, `kBranchUlts`, `kBranchUltWeaponTypes`,
`kBranchUltLooks`, `kBranchUltElement`, `kWeaponUltSkills`,
`ownWeaponUlt`, `itemUlt`). Tests: `test/game_engine/branch_ults_test.dart`,
`test/features/inventory/branch_ult_tooltip_test.dart`.

## 1. Catálogo

- 3 ULT por cada camino del árbol v6 (48 caminos; el Invocador trae las
  suyas: summoner.md § 7) = **144 ULT**, ids `ult_<nombre>`.
- Solo campos existentes de `SkillDef` (poder, a todos, estados,
  buffs / escudos de grupo, curas, revivir, perforar / rebotar / ráfaga,
  disparo cargado, debuffs, quiebre, Silencio, catalizador, remate,
  trampas): **sin cambios de motor**. El texto de cada una sale del
  tooltip de habilidad (`skillTipMarkup`), siempre fiel a sus campos.
- Elemento: el del estado que aplica; curas Sagrado; el resto Físico
  (`elementOf` cae en `kBranchUltElement`).
- Aspecto y sonido: cada una usa el guion de cinemática, el color de FX y
  el sonido de una ULT existente (`kBranchUltLooks`; `ultScriptFor`,
  `skillColor` y el banco de sonidos lo resuelven).

## 2. En las armas

- `ItemInstance.ultId` (JSON `ul`, aditivo): reemplaza la ULT del tipo de
  arma de **esa** arma. Se ve en el tooltip como mod rosa "ULT: <nombre>"
  y como la ULT del arma (fichas de habilidad, comparación).
- Sale al generar un arma **Rara (8%)** o **Épica (20%)**; una ULT al azar
  entre las compatibles con el tipo de la base (`branchUltsForType`).
  Mágicas y Comunes nunca.
- **Legendarios**: `UniqueDef.ultId` fijo (siempre la traen; lista § 4).
- `ItemRules.sanitize` descarta el mod si la ULT no existe, no es del
  tipo o la rareza no es Rara / Épica.
- **No se traslada por fusión** (es del objeto); Esencia / Prisma sin
  cambios. Se vende y se filtra como cualquier arma.
- Filtro de botín: `ULT` (cualquiera), `ULT <nombre>`, `ULT No`.

## 3. Prioridad en combate (`ultimateOf`)

1. ULT de la ascensión de tu clase (sin cambios).
2. La propia del arma: mod "ULT: <nombre>" > la del legendario > la de la
   base (tomos del Invocador, `kWeaponUltOf`).
3. La del tipo de arma.

## 4. Legendarios con ULT propia

- Juramento del Alba (`juramentoAlba`) → Corte Perfecto
- Segadora de Eras (`segadoraEras`) → Guillotina
- Fauce del Volcán (`fauceVolcan`) → Forja Divina
- Rompemundos (`rompemundos`) → Terremoto
- Lanza del Horizonte (`lanzaHorizonte`) → Ojo de la Tormenta
- Corazón de Ascua (`corazonAscua`) → Infierno
- Invierno Perpetuo (`inviernoPerpetuo`) → Cero Absoluto
- Códice del Último Día (`codiceUltimoDia`) → Era Detenida
- Relámpago Dormido (`relampagoDormido`) → Tormenta de Rayos
- Susurro de la Víbora (`susurroVibora`) → Veneno Letal
- Ojo del Halcón Solar (`ojoHalconSolar`) → Diluvio de Flechas
- Trueno de Bronce (`truenoBronce`) → Disparo Relámpago
- Ballesta del Juicio Final (`ballestaJuicio`) → Gran Cacería
- Égida del Primer Rey (`egidaPrimerRey`) → Muralla Eterna
- Martillo del Ocaso Sagrado (`martilloOcasoSagrado`) → Sentencia Divina
- Relicario de la Misericordia (`relicarioMisericordia`) → Milagro
- Bastión de las Mil Eras (`bastionMilEras`) → Bastión Absoluto

## 5. Caminos → ULT → tipos de arma

| Camino | ULT | Tipos |
|---|---|---|
| `muralla` | Muro Viviente · Contragolpe Total · Espinas de Acero | espada, hacha, lanza |
| `sangre` | Banquete de Sangre · Hemorragia · Pacto Carmesí | espada, hacha, dagas |
| `quiebre` | Terremoto · Quebrantahuesos · Martilleo | hacha, lanza, martillo+escudo |
| `gritos` | Grito de Guerra Total · Rugido Atronador · Himno de Batalla | espada, hacha, lanza |
| `filo` | Mil Filos · Corte Perfecto · Desarme Total | espada, dagas, lanza |
| `arcano` | Nova Arcana · Sobrecarga de Maná · Silencio Arcano | varita, tomo, báculo |
| `brasa` | Infierno · Supernova · Lluvia de Ceniza | báculo, varita |
| `cronos` | Paradoja Temporal · Bucle · Era Detenida | tomo, varita |
| `escarcha` | Cero Absoluto · Ataúd de Hielo · Ventisca Perpetua | báculo, tomo |
| `prisma` | Arcoíris · Prisma Roto · Descomposición Total | báculo, varita, tomo |
| `viento` | Vendaval · Ciclón · Viento de Cola | arco, dagas, lanza |
| `lluvia` | Diluvio de Flechas · Lluvia Ácida · Granizada | arco, ballesta |
| `precision` | Tiro Imposible · Ojo de Halcón · Disparo Marcador | rifle, arco, ballesta |
| `acecho` | Emboscada · Red de Trampas · Presa Marcada | arco, ballesta, dagas |
| `toxina` | Plaga · Veneno Letal · Niebla Tóxica | arco, ballesta, dagas |
| `luz` | Amanecer · Rayo Solar · Luz Sanadora | maza+escudo, espada+escudo, báculo |
| `juicio` | Sentencia Divina · Veredicto · Martillo de Justicia | martillo+escudo, maza+escudo |
| `fe` | Milagro · Gracia Eterna · Ola de Fe | maza+escudo, báculo, espada+escudo |
| `vigilia` | Vigilia Eterna · Juramento · Penitencia Sagrada | espada+escudo, maza+escudo, martillo+escudo |
| `bastion` | Bastión Absoluto · Égida Reflejante · Escudo Explosivo | espada+escudo, martillo+escudo, maza+escudo |
| `hojaArcana` | Hoja Rúnica · Acero Arcano · Égida Rúnica Mayor | espada, varita, báculo |
| `runas` | Runa Explosiva · Círculo Rúnico · Disparo Rúnico | varita, tomo, rifle |
| `centinela` | Faro · Guardia del Centinela · Flecha de Luz | ballesta, arco, maza+escudo |
| `coloso` | Pisotón del Coloso · Coloso Inamovible · Puño de Titán | martillo+escudo, hacha, espada+escudo |
| `estandarte` | Estandarte de Guerra · Carga del Estandarte · Bandera Inmortal | espada, lanza, maza+escudo |
| `sintonia` | Armonía · Resonancia · Acorde Final | varita, tomo, rifle |
| `vinculo` | Lazo Vital · Corazones Unidos · Sacrificio Compartido | báculo, maza+escudo, arco |
| `refugio` | Refugio Seguro · Cúpula Mayor · Retirada Táctica | espada+escudo, martillo+escudo, tomo |
| `verdugo` | Guillotina · Cosecha de Almas · Juicio Público | espada, hacha, dagas |
| `tempestad` | Martillo de Tormenta · Galerna · Ojo de la Tormenta | hacha, lanza, espada |
| `vanguardia` | Avanzada · Toque de Carga · Escolta Real | espada, lanza, espada+escudo |
| `marea` | Tsunami · Remolino Abisal · Marea Alta | báculo, tomo, lanza |
| `voltio` | Tormenta de Rayos · Rayo en Cadena · Descarga Suprema | varita, báculo, tomo |
| `alquimia` | Gran Transmutación · Piedra Filosofal · Elixir Volátil | tomo, báculo, varita |
| `monzon` | Monzón · Aguacero · Tromba Marina | arco, ballesta, rifle |
| `centella` | Disparo Relámpago · Cadena Voltaica · Tensión Máxima | rifle, arco, ballesta |
| `monteria` | Gran Cacería · Cepo Mayor · Trofeo de Caza | arco, ballesta |
| `exorcismo` | Purificación · Exorcismo · Destierro | maza+escudo, martillo+escudo, espada+escudo |
| `manantial` | Fuente Eterna · Bautismo · Desborde Sagrado | maza+escudo, espada+escudo, báculo |
| `pararrayos` | Pararrayos Viviente · Jaula de Faraday · Retorno a Tierra | espada+escudo, martillo+escudo, maza+escudo |
| `forja` | Forja Divina · Acero Fundido · Yunque | hacha, espada, báculo |
| `galvanica` | Electrólisis · Circuito Cerrado · Arco de Plasma | varita, rifle, tomo |
| `eclipse` | Eclipse Total · Sombra Sagrada · Crepúsculo | arco, dagas, maza+escudo |
| `glaciar` | Avalancha · Escudo Glaciar · Témpano | martillo+escudo, hacha, espada+escudo |
| `tactica` | Plan Maestro · Fuego Cruzado · Golpe Coordinado | rifle, lanza, varita |
| `coro` | Gran Himno · Canon Eterno · Crescendo | varita, tomo, lanza |
| `santuario` | Santuario · Altar Sagrado · Último Rezo | maza+escudo, báculo, tomo |
| `fortaleza` | Muralla Eterna · Torre del Homenaje · Ciudadela | espada+escudo, martillo+escudo, maza+escudo |

## v0.17.0 (ultimates_v2.md)

Las 144 ULT de camino **ya no caen** en botín nuevo: el mod "ULT" de las
armas Raras / Épicas sale del pool de las 12 ULT v2 de arma de su tipo.
Las armas ya caídas conservan su `ul` (sanitize lo sigue aceptando) y,
desde v0.17, esa ULT entra al repertorio del personaje y no se pierde.
Los legendarios con ULT de camino la siguen trayendo.