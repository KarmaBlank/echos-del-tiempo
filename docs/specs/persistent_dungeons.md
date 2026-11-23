# Spec: Mazmorras persistentes por mundo (v0.34.0, protocolo 58)

Estado: implementado en v0.34.0. Cambia free_movement.md § 2.3–2.4
(la instancia ya no se descarta), lighting.md § 5.6, worldgen.md § 6.6 y
missions.md (vuelta al pueblo).

## 0. Alcance

Solo las **mazmorras de zona del Mundo** (misiones del mostrador con
`zone > 0`). Ecos, Atlas, Pruebas del Tiempo, Jefes del Abismo, la
Travesía y el TUTORIAL siguen como siempre: al azar y nuevos en cada
entrada, sin guardar nada (`DungeonRules.persistent`). Sin mundo (sala
sin `worldId`, p. ej. los tests viejos) tampoco se guarda.

## 1. Semilla por mundo

- `semilla = FNV-1a(worldId + "|" + missionId) mod 10⁹`
  (`DungeonRules.seedFor`). Misma mazmorra siempre en ese mundo; otra en
  otro mundo. Los pisos salen de esa semilla como siempre (worldgen.md
  § 6.6).
- La primera entrada la genera y la puebla (`_startZoneMission` con esa
  semilla). Desde ahí el estado guardado manda: el mapa no cambia más.
- Mundos viejos: no tienen nada guardado; la primera entrada genera desde
  la semilla del mundo. Nada que migrar.

## 2. Estado guardado

`TownState.dungeons` (`missionId → DungeonSave`, JSON `dg` en el archivo
del mundo). Solo del anfitrión: **no** va en `farmJson` (no viaja).

`DungeonSave`: `run` = el JSON de `MissionRun` tal cual
(`SessionJson.missionToJson`) y `pd` = día del mundo (`SkyState.day`)
en que se guardó. Ahí está todo:

- faroles encendidos y demás PdI usados (`poiUsed`), PdI vistos,
- cofres abiertos y fragmentos / sellos tomados (`items[].done`),
- enemigos vencidos (normales, élite, jefe) y su posición,
- piso actual y barreras abiertas (`floor`, `opened`, `open`),
- misiones opcionales cumplidas (`questsDone`).

### 2.1 Cuándo se guarda

- Sale el último jugador (salir solo o desconectarse): la instancia se
  **estaciona** en el pueblo del mundo en vez de descartarse
  (`WorldEngine._dropEmpty` → `SessionEngine.parkDungeon`).
- Vuelta al pueblo (`toLobby`: victoria con LISTO, derrota): se guarda
  igual. **Completar la misión no borra la mazmorra**: queda con el jefe
  vencido y el altar de la Ofrenda.
- Al guardar el mundo (vuelta al pueblo, cerrar la sala) las mazmorras
  que siguen abiertas se guardan como están (`WorldEngine.savedTown`):
  un reinicio del anfitrión no pierde nada.

### 2.2 Volver a entrar

`ENTRAR` en una mazmorra guardada la restaura (`DungeonRules.restore`):
el grupo aparece en la llegada del piso guardado. Cada visita empieza de
cero en lo que es de la visita: tiempo, K.O., XP y créditos de batalla,
élites y armas de élite del resultado, bendición y viento. Las misiones
opcionales **falladas** se pueden volver a intentar; las **cumplidas** no
vuelven.

Si el guardado está dañado o es de otra misión se ignora y se genera de
nuevo desde la semilla.

### 2.3 Niebla de exploración

Es del jugador (lighting.md § 5.4), no del host. `FogOfWar` guarda lo
explorado por clave `"<misión>:<semilla>"` (la semilla ya es del mundo)
en `archive`: 1 bit por tile en base64 (`w,h,<bits>`; un atlas de 3 pisos
ronda los 4–6 KB). Al volver a entrar se recupera. En el disco:
`accounts/fog.json` del dispositivo (`FogStore`), con las 48 más
recientes; se escribe al volver al pueblo y al cerrar la sala.

## 3. Reaparición (cada 5 días vacía)

- `respawnDays` = 5 (Editor → Balance, grupo `Mazmorras`).
- Al volver a entrar, si pasaron `respawnDays` días del mundo o más desde
  que se guardó (= desde que salió el último), los enemigos **normales y
  élite** vencidos reviven en su lugar de origen. El reloj vuelve a
  contar en cada salida: con alguien adentro nunca reaparece nada.
- **Quedan como están**: faroles, cofres abiertos, fragmentos y sellos
  tomados, barreras abiertas, PdI usados, opcionales cumplidas y el jefe.
- Cofres: **no** se rellenan. El loot de la mazmorra es la pelea (los
  revividos sueltan su botín normal); rellenar cofres haría de la
  mazmorra una granja sin riesgo. Queda anotado por si el dueño lo quiere.

## 4. Ofrenda del jefe

- Con el jefe vencido, su sala tiene un **altar de la Ofrenda** en el
  lugar del jefe (se dibuja con el relicario y el cartel OFRENDA). `[E]
  Ofrenda del jefe` a `altarReach` (40 px) abre el panel OFRENDA.
- Costo en la zona `z` (`kTuning['dungeon']`, todo editable):
  - Esquirlas del Eco: `esqBase + esqPerZone × z` (2 + 2z).
  - Cristales de Era desde la zona `crisFrom` (2): `crisPerZone × (z − 1)`.
  - Prismas Rotos desde la zona `prismaFrom` (4): `prismaPerZone × (z − 3)`.
- OFRENDAR (`OfferBossAction`, `offer`): el host valida campo, vivo,
  piso del jefe, distancia y materiales; los cobra a quien ofrenda y
  revive al jefe en su lugar (con la gracia de inicio para no pelear al
  instante). La pelea y el fin de misión son los de siempre, con sus
  recompensas normales.
- Vale aunque falten días para la reaparición: se puede revivir al jefe
  con la mazmorra vacía, o después, cuando ya volvieron los monstruos (y
  hay que pasar entre ellos).
- Panel (sistema de diseño): `PanelFrame` + `DsCraftGridTemplate` con
  cada material pedido (cuántos tenés, cuántos faltan) y el detalle a la
  derecha; OFRENDAR gris con el motivo (`Faltan Esquirla del Eco`).

## 5. Red

- Protocolo 58: la acción `offer`. El estado guardado no viaja; el
  cliente ve la mazmorra restaurada como cualquier `mission`.

## 6. Fuera de alcance (deuda)

- Ver tech_debt.md § v0.34.0.
