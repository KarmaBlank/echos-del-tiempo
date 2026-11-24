# Spec: Editor de habitantes (NPC)

Área **NPC** del Editor (game_editor.md § 6). Todo lo que dicen y piden
los habitantes se escribe a mano acá; nada de la charla se genera.

## 1. Datos

- `assets/data/npcs/npcs.json` (un solo archivo, JSON) con, por id de
  habitante:
  - `greet`: saludos (uno al azar al abrir).
  - `topics`: temas de HABLAR (recursivos en `sub`): `id`, `label`,
    `lines`, condiciones `talks`, `orders`, `rep`, `where`
    (`any` · `biome` · `town`) y `time` (`any` · `day` · `night`, § 3.2),
    y `action` (§ 3.3). Los valores en 0 / `any` / `none` se omiten.
  - `rooted`, `decline`, `gift` (arraigados, overworld_biomes.md § 12.3).
  - `ambient`: frases sueltas. Los que se mudan: la frase del día (una por
    día del mundo, en orden; antes `BiomeNpcDef.lines`). Los pescadores
    nativos: las frases de la orilla.
  - `night` (los que se mudan): el motivo de cada salida nocturna por id
    de `NightOuting` (antes `ui.town.npc.night.*`). El lugar sigue en
    código.
  - `invite_accept` y `house_thanks` (`day` / `night`) (los que se
    mudan): lo que dicen al aceptar la invitación y al recibir casa (antes
    claves i18n `ui.town.npc.invite_accept` / `house_thanks_*`).
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
  (cada par lee el mismo archivo; el anfitrión valida). El idioma tampoco:
  cada par muestra el suyo.

### 1.1 Idiomas

- Todo texto de diálogo (saludos, etiquetas de temas, líneas, frases al
  invitar, frases sueltas, de noche, al aceptar y de gracias por la casa)
  es un mapa por idioma: `{"es-AR": "…", "en": "…", "zh-Hans": "…"}`
  (`LocalizedText`, `version: 2`). El regalo (`gift`) y los textos de
  los encargos (`quests`) quedan como estaban.
- La lista de idiomas sale de `assets/i18n/locales.json` (publicados y
  ocultos, en el orden de `LocaleId`); nunca está escrita a mano en el
  editor. Un idioma nuevo ahí hace que todos los textos lo pidan.
- El lector acepta también el formato viejo (`version: 1`): un string
  suelto es el texto es-AR.
- En el juego, un idioma vacío cae a es-AR (`LocalizedText.resolve`): nunca
  se ve una línea en blanco. El idioma activo lo publica la capa i18n
  (`LocalizedText.activeTag`).
- Migración (v0.43): el español existente pasó a es-AR; en y zh-Hans se
  llenaron desde las claves i18n que existían (salidas nocturnas,
  aceptar, gracias por la casa); el resto quedó vacío y el editor lo marca.
- Las tres frases fijas de HABLAR ("Hablar", "¿De qué querés hablar?",
  "Volver") y sus vecinas son claves i18n: `ui.town.npc.talk`,
  `talk_prompt`, `talk_back`, `talk_again`, `talk_more`,
  `talk_nothing`.

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

- Sub-pestañas (nada de secciones apiladas): SALUDOS, TEMAS (árbol con
  líneas que unen tema y sub-tema), FRASE DEL DÍA / ORILLA, y AL INVITARLO
  (arraigados) o NOCHE e INVITAR Y CASA (los que se mudan).
- Cada texto muestra un campo por idioma; los vacíos se marcan en rojo.
- Cada tema muestra sus condiciones: charlas, pedidos, amistad y lugar.
- Agregar, borrar, subir y bajar saludos, temas, sub-temas y líneas.
- Cada línea con contador de caracteres; más de **90** (límite blando)
  se marca en naranja: el tono es lore en pinceladas, nunca historia
  larga (docs/lore.md es la única fuente).
- PROBAR (§ 3.4): abre el `DsDialogueBox` real con el avance elegido
  (charlas, pedidos, amistad y lugar), el idioma y la hora (día / noche), y
  deja recorrer la conversación con el mismo HABLAR del juego (Saltar,
  VOLVER sube un nivel y en la raíz vuelve al saludo).
- GUARDAR NPC escribe `assets/data/npcs/npcs.json` del repo y aplica al
  momento; RECARGAR descarta lo no guardado.

### 3.1 Validación

- GUARDAR NPC queda bloqueado, con el motivo a la vista ("faltan idiomas en
  N textos" y el primero), mientras falte cualquier idioma de la lista en
  cualquier texto; zh-Hans incluido aunque esté oculto
  (`NpcData.missingLocales`).

### 3.2 Hora

- `time` del tema: `any` (siempre), `day` o `night`, con el reloj del
  mundo (`SkyRules.isNight` del pueblo). Un tema fuera de hora no cuenta
  como "hay más para hablar".

### 3.3 Acciones

- `action` del tema, de una lista fija: `none` (solo charla), `invite`
  (invitar: el arraigado declina y regala; el que se muda acepta),
  `trade` (comerciar: COMPRAR del que se muda, puesto del pescador) y
  `house` (asignar casa). El editor ubica, nombra y condiciona la opción;
  el comportamiento vive en el código (`TalkActions` de cada pantalla),
  con los mismos motivos de bloqueo que el menú. Una acción que la pantalla
  no soporta no se muestra. Ninguna acción abre un encargo: los encargos
  siguen siendo su menú.

### 3.4 PROBAR

- Selector de idioma (la misma lista) y de hora; las acciones se muestran
  como `[ACCIÓN]` sin ejecutarse.

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
- Los textos del objeto único siguen en código.
- Las traducciones en / zh-Hans de saludos, temas, líneas, frases sueltas y
  frases al invitar: las escribe el dueño en el editor.
