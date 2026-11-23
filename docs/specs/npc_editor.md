# Spec: Editor de habitantes (NPC)

Área **NPC** del Editor (game_editor.md § 6). Todo lo que dicen y piden
los habitantes se escribe a mano acá; nada de la charla se genera.

## 1. Datos

- `assets/data/npcs/npcs.json` (un solo archivo, JSON) con, por id de
  habitante:
  - `greet`: saludos (uno al azar al abrir).
  - `topics`: temas de HABLAR (recursivos en `sub`): `id`, `label`,
    `lines`, y condiciones `talks`, `orders`, `rep`, `where`
    (`any` · `biome` · `town`). Los valores en 0 / `any` se omiten.
  - `rooted`, `decline`, `gift` (arraigados, overworld_biomes.md § 12.3).
  - `quests`: cadena de encargos escrita a mano (overworld_biomes.md
    § 10.2): `kind`, `target`, `n`, `text`, `gold`, `rep`, `reward`. El
    orden de la lista es el orden de la cadena (cada paso es el
    "siguiente" del anterior).
  - `ambient` (solo pescadores nativos): las frases sueltas de la orilla.
- Lector único: `NpcDataLoader` (lib/core/data) lee el archivo al
  arrancar y `NpcData.install` lo pone encima de los catálogos del motor
  (`kNpcTalks`, `kResidentQuests`, `kBiomeFishers`). Solo ids conocidos;
  archivo roto o ausente = quedan los valores del código (respaldo) y se
  loguea.
- Los valores del código (`kNpcTalksDefaults`, `kResidentQuestsDefaults`,
  `kBiomeFishersDefaults`) son solo el respaldo si el archivo falta o
  está roto; el archivo manda. El test del archivo comprueba que se lee,
  que vuelve sin pérdida y que usa ids válidos (habitantes conocidos,
  temas sin repetir, objetos únicos existentes), no que sea igual al
  código. La migración se probó igual al código al crearlo.
- Las reglas de los pedidos generados (órdenes de entrega, pedidos del
  pueblo, encargos de forja de Brann, pedido del día del pescador) son
  números de `kTuning` (grupos `town` y `fishing`), editables por el
  parche de balance de siempre (`balance.json`). El editor NPC los
  muestra agrupados por generador y los guarda con GUARDAR del Balance.
  El protocolo no cambia: ni la charla ni los encargos viajan por la red
  (cada par lee el mismo archivo; el anfitrión valida).

## 2. Lista

Grilla de todos los habitantes (los que se mudan y los nativos de cada
bioma) con el detalle a la derecha. Ficha: nombre, rol, bioma de origen,
se muda / arraigado, sprite y retrato (ids del manifest) y umbrales de
amistad:

- Se mudan: invitar `resInviteRep`, asentado `resSettledRep`, arraigado
  `resRootedRep`.
- Arraigados: invitar `NpcTalkRules.inviteRep` con
  `NpcTalkRules.inviteOrders` pedidos cumplidos.

## 3. DIÁLOGO

- Saludos, árbol de temas (con líneas que unen tema y sub-tema) y, para
  arraigados, las frases al invitarlos.
- Cada tema muestra sus condiciones: charlas, pedidos, amistad y lugar.
- Agregar, borrar, subir y bajar saludos, temas, sub-temas y líneas.
- Cada línea con contador de caracteres; más de **90** (límite blando)
  se marca en naranja: el tono es lore en pinceladas, nunca historia
  larga (docs/lore.md es la única fuente).
- PROBAR: abre el `DsDialogueBox` real con el avance elegido (charlas,
  pedidos, amistad y lugar) y deja recorrer la conversación.
- GUARDAR NPC escribe `assets/data/npcs/npcs.json` del repo y aplica al
  momento; RECARGAR descarta lo no guardado.

## 4. PEDIDOS

- Cadena a mano (solo los que se mudan): pasos editables, agregar,
  borrar y reordenar. El último paso entrega el objeto único.
- Generadores (reglas, no pedidos):
  - Órdenes de entrega (todos los que se mudan): cada cuántos días,
    niveles de oficio para rareza, cualquier bioma, calidad y tamaño,
    XP / oro por valor, tope diario, amistad, punto de árbol.
  - Pedidos del pueblo (§ 10.4): cada cuántos días, días hasta
    descontento, amistad.
  - Encargo de forja (solo Brann, roles.md § 4): oro, materiales, botín,
    rareza por puntaje, legendaria, brecha de nivel.
  - Pedido del día (pescadores nativos, fishing.md § 12): niveles por
    rareza, XP y oro.
- GENERAR EJEMPLOS: con un nivel de oficio / personaje elegido, tira
  siete días seguidos con las reglas del borrador y muestra qué pediría
  y qué paga.

## 5. Pendiente

- No hay condiciones de estación u hora del día en los generadores (el
  motor no las tiene); se agregan cuando existan.
- Las frases sueltas de los habitantes que se mudan (`BiomeNpcDef.lines`)
  y los textos del objeto único siguen en código.
