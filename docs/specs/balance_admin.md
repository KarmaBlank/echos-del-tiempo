# Spec: Balance y Admin (parches de balance + monitoreo)

Pedido del dueño: "una web que pueda levantar o una aplicación Flutter, de
monitoreo, y que me deje tirar parches de balanceo: elegir una habilidad,
un arma, cosas, y cambiarle números, bajarle, subirle, quitar, agregar
condición, etc. Y desde ahí mismo poder lanzar un parche que genera una
nueva update minor con notas del parche".

Dos piezas:

1. **Capa de balance** (Dart puro, `lib/game_engine/balance/`): un JSON
   versionado (`assets/balance/balance.json`) que se aplica **encima** de
   los catálogos `const` al arrancar. Sin el archivo, o vacío, el juego
   es idéntico al de siempre.
2. **App de admin** (flavor `lib/app/flavors/main_admin.dart` +
   `lib/features/admin/`): navegador de entidades, editores tipados,
   vista previa de impacto con el motor real, diff, generador de notas
   de parche, guía/lanzador del release y monitoreo.

Código:
- Capa de balance: `lib/game_engine/balance/` (`balance_fields.dart`,
  `balance_codecs.dart`, `balance_patch.dart`, `balance_apply.dart`,
  `balance_hash.dart`).
- Carga en el juego: `lib/core/balance/balance_asset_loader.dart`
  (lee el asset con `rootBundle`; nunca lanza).
- Admin: `lib/features/admin/{domain,data,presentation}`.

Tests: `test/game_engine/balance_test.dart`,
`test/features/admin/*`, `test/netcode/balance_handshake_test.dart`.

## 1. Formato de `assets/balance/balance.json`

```json
{
  "schema": 1,
  "basedOn": "0.5.0",
  "overrides": {
    "skill":       { "sismo": { "power": 1.4, "mp": 5 } },
    "ultimate":    { "espada": { "power": 3.2 } },
    "dual":        { "guerrero+maga": { "power": 1.6 } },
    "weapon":      { "hacha_rompe": { "level": 5, "price": 700,
                                      "atk": { "base": 16, "fue": 0.9 } } },
    "enemy":       { "slime": { "hp": 32, "inflicts": null } },
    "enemyUlt":    { "eult_diluvio": { "power": 1.8 } },
    "class":       { "paladin": { "baseDefense": 3 } },
    "affix":       { "feroz": { "weight": 900, "disabled": false } },
    "passiveNode": { "filo_na": { "effects": { "crit": 0.06 } } },
    "mechanic":    { "frenesi": { "effects": [
                       { "kind": "buffSelf", "value": 0.25, "turns": 2,
                         "stat": "speed" } ] } }
  }
}
```

- `schema`: versión del formato. Hoy **1**. Un `schema` mayor al
  soportado → se ignora el archivo entero (error).
- `basedOn`: versión del juego con la que se armó (informativo; lo
  escribe el admin).
- `overrides.<tipo>.<id>.<campo>`: **reemplaza** el valor del campo
  entero (listas y mapas también: no hay merges parciales adentro de un
  campo). Lo que no aparece queda como en el código.
- El admin solo escribe los campos que difieren del código (si volvés un
  número a su valor base, la entrada desaparece).

### 1.1 Tipos de entidad y campos editables

| Tipo (`overrides.`) | Origen | Campos |
|---|---|---|
| `skill` | `GameCatalog.skills` (armas, kit de ascensión, variantes) | `mp`, `power`, `delay`, `critBonus`, `allTargets`, `cleanse`, `amount`, `hits`, `status`, `extraStatuses`, `debuffs`, `partyBuffs`, `selfBuff`, `hpCost`, `lifeSteal`, `detonate`, `catalyst` (v0.7), `execute`, `trap`, `partyShield`, `partyShieldTurns`, `advanceAllies`, `selfTurn`, `protect`, `revive`, `overheal`, `drainHeal`, `allyShield`, `selfShield`, `shieldTurns`, `shieldReflect`, `shieldBurst`, `shieldGrow`, `pierce`, `bounces`, `charge`, `breakBonus`, `ultDrain`, `disabled` |
| `ultimate` | `GameCatalog.ultimates` (clave = tipo de arma) | los mismos de `skill` salvo `mp` y `disabled` |
| `dual` | `GameCatalog.duals` | `power`, `status` |
| `weapon` | `GameCatalog.weapons` | `tier`, `level`, `price`, `weight`, `shieldDefense`, `requirements`, `atk`, `mag`, `skillIds` |
| `enemy` | `GameCatalog.enemies` | `hp`, `attack`, `speed`, `xp`, `credits`, `breakMax`, `armor`, `evasion`, `delayHit`, `markHit`, `pierce`, `areaAttack`, `inflicts`, `inflictCycle` |
| `enemyUlt` | `GameCatalog.enemyUlts` | `power`, `allTargets`, `status`, `delayAll`, `wipeBuffs`, `guaranteedCrit`, `perAdd`, `turns` |
| `class` | `GameCatalog.classes` | `baseDefense`, `baseAttributes`, `stunOnAttackChance`, `pierceWeakness`, `statusWeakness` |
| `affix` | `kAffixes` | `weight`, `tiers`, `disabled` |
| `passiveNode` | `kPassiveTree.nodes` | `effects`, `disabled` |
| `mechanic` | `kMechanics` + `kAscensionMechanics` | `chance`, `threshold`, `minStacks`, `status`, `effects`, `description`, `disabled` |
| `reaction` (v0.7) | `kReactions` (`GameCatalog.reactions`) | `damageMult`, `perStack`, `splash`, `bossCap`, `stunTurns` |
| `elementStatus` (v0.7) | `kElementStatuses` (wet, charged, freeze) | `turns`, `slowPerStack`, `breakPerStack`, `brittleMult` |

Codificación de valores compuestos:

- Estado: `{"kind":"burn","stacks":2,"chance":0.3}` (`chance` opcional;
  `kind` = nombre de `StatusKind`). `null` = sin estado.
- Buff/debuff: `{"stat":"attack","value":-0.2,"turns":2}` (`BuffStat`).
- Atributos: `{"fue":18,"des":10}` (`Attribute`, enteros).
- Fórmula de poder: `{"base":16,"fue":0.85}`; `mag: null` = sin MAG.
- Tiers de afijo: `[{"tier":1,"minLevel":40,"min":33,"max":40,"weight":20}]`.
- Efectos de nodo: `{"atk":0.05,"crit":0.02}` (claves que ya usa el
  árbol: `hp`, `mp`, `atk`, `mag`, `crit`, `spd`, `def`, `ult`, `heal`,
  `burn`, `poi`, `frz`, `key`, …).
- Efectos de mecánica: `[{"kind":"buffSelf","value":0.2,"turns":2,
  "stat":"speed","status":null}]` (`ProcEffectKind`).

### 1.2 "Quitar" / desactivar (`disabled: true`)

Desactivar nunca borra datos (las partidas guardadas y los objetos ya
tirados siguen resolviéndose):

- **Habilidad**: sale de los `skillIds` de **todas las bases de arma**
  (ya no la otorga ningún arma nueva). Sigue en el catálogo: un objeto
  con esa habilidad fusionada/trasladada la sigue usando.
- **Afijo**: peso 0 → ya no sale en drops ni crafteo; los objetos que lo
  tienen lo conservan.
- **Nodo del árbol**: efectos vacíos (`{}`) → el nodo se puede tomar pero
  no da nada.
- **Mecánica**: sin efectos (`[]`) → no hace nada.

"Agregar condición" = agregar/quitar estados (`status`,
`extraStatuses`, `inflicts`, `inflictCycle`), debuffs/buffs
(`debuffs`, `partyBuffs`, `selfBuff`) o efectos de mecánica (`effects`).

## 2. Validación

`BalancePatch.parse(texto, contexto)` devuelve el parche **ya filtrado**
y la lista de problemas (`BalanceIssue`: ruta `skill.sismo.power`,
mensaje en castellano, error/aviso). Nunca lanza.

- JSON roto, raíz que no es objeto o `schema` no soportado → parche
  vacío + error.
- Tipo desconocido, id inexistente, campo desconocido o no editable en
  ese tipo, `disabled` en un tipo que no lo admite → se descarta esa
  entrada + error.
- Valor de tipo incorrecto, fuera de rango (tabla de rangos en
  `balance_codecs.dart`), enum desconocido (`StatusKind`, `BuffStat`,
  `Attribute`, `ProcEffectKind`), `skillIds` con una habilidad
  inexistente, tiers con `max < min` o repetidos → se descarta **ese
  campo** + error; el resto del parche se aplica.
- Avisos (no descartan): habilidad de daño con poder 0, arma sin
  habilidades, descripción de mecánica sin cambios cuando cambiaron sus
  números.

El juego aplica solo lo válido y escribe los errores en `ecos.log`
(`EcosLog.warn`). El admin no deja guardar con errores.

## 3. Aplicación

- `BalancePatch.applyTo(GameCatalog)` → `GameCatalog` nuevo (habilidades,
  ULT, duales, armas, enemigos, ULT enemigas, clases) con
  `balanceHash` = hash del parche. `registerSharedDependencies(balance:)`
  registra ese catálogo.
- `BalanceRegistries.install(patch)` parchea **en el lugar** los
  registros globales mutables que el motor consulta directo
  (`kAffixes`, `kMechanics`, `kAscensionMechanics`, `kPassiveTree.nodes`).
  Guarda los originales la primera vez; `install` siempre parte de los
  originales y `restore()` los devuelve (tests, vista previa del admin).
- Parche vacío → `GameCatalog.standard` tal cual (`identical`) y
  registros sin tocar. Test: `balance_test.dart` "parche vacío".

Límites conocidos (v1, a propósito para no tocar catálogos):
- Las ULT de ascensión (`kAscensionUltimates`) y las mecánicas de jefe
  (`kBossMechanics`) son `const` y el motor las lee directo: no se
  editan todavía.
- Algunos textos de UI leen los `const` directo (`kSkills[id]?.name`,
  tooltips de `kEnemies`): muestran nombres (que no se editan) y, en
  pocos lugares, números base. Los números del motor sí salen del
  catálogo parcheado.
- Las bases de arma que se leen con `GameCatalog.standard` por defecto
  (`Stash.fromJson`, `const LootFilterRules()`) usan el catálogo base;
  no afectan el combate.

## 4. Co-op: hash de balance en el apretón de manos

El host corre el motor, pero cliente y host deben ver el mismo catálogo
(textos, previsualizaciones, snapshot). Por eso:

- `GameCatalog.balanceHash`: `"base"` sin parche; si no,
  `"b1-xxxxxxxx"` = FNV-1a de 32 bits del JSON canónico (claves
  ordenadas) de los overrides **válidos**.
- `hello` lleva `"b":<hash>` (clave nueva y opcional: **no** cambia
  `kProtocolVersion`).
- El host compara: `b` distinto al suyo → `reject balance` ("El host
  tiene otro parche de balance: actualizá el juego"). Un cliente viejo
  (sin `b`) cuenta como `"base"`; si el host tiene parche, se le
  rechaza con `reject version` (el cliente viejo no conoce el motivo
  `balance`).
- Regla de versión: **todo parche de balance sale como release nuevo**
  (sube el PATCH: 0.5.x → 0.5.x+1). El auto-actualizador lo ofrece y
  hasta actualizar no se puede jugar con quien ya lo tiene.

## 5. App de admin

`flutter run -d windows -t lib/app/flavors/main_admin.dart`. Web: el
código no importa `dart:io` fuera de `data/admin_host_io.dart` (export
condicional; en web, `StubAdminHost` sin disco, procesos ni log), pero el
repo todavía no tiene la plataforma web (`flutter create . --platforms
web`, a propósito sin agregar).

- **No** llama a `registerSharedDependencies`: no toca
  `%APPDATA%\EcosDelTiempo` (ni cuenta, ni ajustes, ni `ecos.log`).
- Repo: el directorio actual si tiene un `pubspec.yaml` con
  `name: echos_del_tiempo`; si no, `--dart-define=ECOS_REPO=<ruta>`; si
  no, se elige en la pestaña Parche.

Pestañas:

1. **Balance**: navegador (búsqueda + filtro por tipo: habilidades, ULT,
   duales, armas, afijos, enemigos, ULT enemigas, clases, nodos del
   árbol, mecánicas, ascensiones — estas solo enlazan a su kit y sus
   mecánicas) y editor tipado: por campo, valor del código, del
   `balance.json` guardado y el nuevo; ± con paso por campo; listas de
   estados/buffs/efectos con agregar/quitar; "restaurar" por campo y por
   entidad. Errores de validación en vivo.
2. **Impacto** (al lado del editor, solo con lo que corresponde):
   - Habilidad/ULT/arma: daño de un uso contra un muñeco (DEF del enemigo
     elegido) al nivel X con stats típicos, antes vs después, sin y con
     crítico, con el motor real (`BattleEngine`, azar fijo).
   - Batalla rápida: N batallas simuladas (semillas fijas, mulberry32)
     de un personaje típico contra un enemigo elegido escalado al nivel X
     (`ZoneRules.scaleBattle`): % de victorias, turnos propios para
     ganar (TTK) y vida restante, antes vs después.
   - Enemigo/ULT enemiga: lo mismo, con la clase elegida.
   Personaje típico: atributos base de la clase + `(nivel−1)·3` puntos
   repartidos ⅔ al atributo principal del arma y ⅓ a VIT; arma = la de la
   habilidad (o la inicial de la clase). Política de la IA: usa la
   habilidad cuando le alcanza el MP, si no ataca; ULT cuando está
   cargada.
3. **Cambios**: diff de lo pendiente (borrador vs `balance.json`
   guardado) con valores efectivos; descartar por cambio. Guardar →
   escribe `assets/balance/balance.json` (solo sin errores).
4. **Parche**: versión siguiente (PATCH por defecto, MINOR opcional)
   leída del `pubspec.yaml`; notas auto-generadas y editables ("Golpe
   Sísmico: poder 1.2 → 1.4"); "Escribir archivos" → `balance.json` +
   `docs/patch_notes/vX.Y.Z.md`; pasos exactos (rama → commit → PR →
   merge → `tool/release.ps1 -Version X.Y.Z -NotesFile
   docs\patch_notes\vX.Y.Z.md` en `echos-release`), copiables. En
   escritorio, botón para correr el script con salida en vivo, **siempre**
   detrás de un diálogo que nombra la versión y pide escribirla (con
   `-DryRun` marcado por defecto). El admin nunca hace push ni `gh`.
5. **Monitoreo**: releases de GitHub, señalización de Firestore y
   visor de `ecos.log`.

### 5.1 Notas de parche

Una línea por entidad, agrupadas por tipo, con los valores efectivos:

```
## Habilidades
- **Golpe Sísmico**: poder 1.2 → 1.4; MP 6 → 5.
- **Chispa**: estado Quemadura ×1 → Quemadura ×2.
- **Corte Giratorio**: desactivada (ya no la otorgan las armas).
## Enemigos
- **Limo**: vida 30 → 32.
```

Fracciones (`critBonus`, `armor`, …) se muestran en %. El dueño edita el
texto libremente antes de escribirlo.

## 6. Monitoreo (sin telemetría)

- **GitHub**: `GET https://api.github.com/repos/KarmaBlank/echos-del-tiempo/releases?per_page=30`
  (público, sin token, 60 pedidos/hora): versión, fecha, prerelease,
  descargas por asset (`download_count`) y total.
- **Firestore** (proyecto `echos-del-tiempo`, API REST como
  `firestore_rest_signaling.dart`):
  - Contar salas: `runAggregationQuery` con `count` sobre `rooms`. Las
    reglas desplegadas tienen `allow list: if false` en `rooms`, así que
    hoy responde 403 y el admin lo explica. **No se cambian las
    reglas.** Para habilitarlo haría falta, por ejemplo, autenticación
    del admin (`request.auth.uid == '<uid del dueño>'`) con
    `allow list` solo para él, o un documento contador escrito por los
    hosts (`stats/rooms`, `increment`), o una Cloud Function
    programada que cuente con credenciales de servidor.
  - Buscar una sala por código (`get` está permitido): existe, creada,
    vence, y cuántos pares (`peers`, `list` permitido) tiene.
- **ecos.log**: lectura de `%APPDATA%\EcosDelTiempo\ecos.log` (y
  `ecos.log.1`), filtros por nivel y texto. Solo lectura.

## 7. Propuesta (no implementada): telemetría de balance opt-in

Objetivo: saber qué habilidades/armas se usan y cuánto tardan las
batallas para balancear con datos.

- **Opt-in explícito** en Ajustes ("Compartir estadísticas anónimas de
  partidas"), apagado por defecto, revocable; sin cuenta.
- Qué se manda, **solo agregados por batalla**: versión del juego,
  `balanceHash`, zona/nivel del enemigo, clase y ascensión, base de arma,
  ids de habilidades usadas y cuántas veces, turnos, victoria/derrota,
  tamaño del grupo. **Nada** de nombre de personaje, código de sala, IP
  guardada, chat ni identificadores del equipo. Un id de instalación
  aleatorio rotado cada 30 días para deduplicar (o ninguno).
- Transporte: un endpoint propio (Cloud Function con App Check) que
  escribe en una colección con TTL de 90 días; el cliente manda en lote
  al terminar la sesión. Reglas: solo `create` con esquema validado,
  nada de `read` público.
- Privacidad: aunque sea anónimo, la IP llega al servidor → aviso en el
  diálogo de opt-in y en la página del release; cumplimiento tipo GDPR
  (base: consentimiento; derecho a borrar = sin id persistente no hay
  qué borrar). Solo el host manda por batalla (evita duplicados en co-op)
  y solo si **el host** aceptó; los clientes no envían datos ajenos sin
  su propio consentimiento → el host manda solo sus filas.
- En el admin: una pestaña con uso por habilidad, TTK medio por
  zona y tasa de derrota, comparando antes/después de cada parche
  (`balanceHash`).
