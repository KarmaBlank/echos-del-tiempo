# Deuda técnica

## Monorepo: nombres en inglés y formato (docs/specs/monorepo.md § 0.1)

- Convención: todo el monorepo se nombra en inglés (carpetas, paquetes,
  identificadores, tags). Los identificadores en español que ya existen
  (`mundo`, `travesia`, `TravesiaMeta`, `session_engine_run`,
  `-Juego Mundo|Travesia` de `release.ps1`, `GameModeKind`/`WireGame`
  con ids `mundo`/`travesia`, archivos como `hazanas_*`) se migran de a
  poco al tocar el código. El texto que ve el jugador sigue en español.
  Ojo: ids que viajan por red o quedan en guardados (`WireGame.id`,
  claves de JSON) solo se cambian con migración/versión de protocolo.
- `dart format` no está aplicado: 650 de 1015 archivos de `lib test tool`
  cambiarían, así que `melos run format` falla. Formatear todo en un PR
  propio, sin ramas abiertas.

## v0.33.0 (movimiento libre por jugador)

Tests salteados (prioridad: salir rápido). Solo tests de reglas en
`test/game_engine/free_movement_test.dart` (viajar solo, entrar solo,
sumarse a amigos, dos mazmorras a la vez, `aw` en el snapshot).

- Sin test del controlador ni de red: difusión por instancia
  (`broadcast(only:)`), eventos por jugador, vista del anfitrión cuando él
  mismo cambia de instancia.
- Sin test de: vuelta al pueblo al cerrar una mazmorra con varios
  jugadores, refuerzo que entra a una pelea en curso por ENTRAR, compañeros
  de solitario que siguen al líder entre instancias, Eco / Prueba / Jefe
  del Abismo / TUTORIAL en instancia propia, pausa compartida.
- Sin widget test de la línea "En otro lugar" del HUD ni del mapa de viaje
  sin "Decide el anfitrión". Sin capturas nuevas en docs/release_shots.
- `SessionEngine.freeMovement` lo prende solo el composition root
  (`service_locator.dart`). Los tests viejos de flujo de grupo (votación,
  preparación, loopback) siguen con el flag apagado: prueban el camino
  de una sola sala, no el del juego. Falta migrarlos.
- Salir solo (`leaveD`): sin test de la piedra de paso ni del botón del
  HUD; el loot propio que quedó en el piso no se recupera al salir; sin
  cinemática ni confirmación.
- No hay unirse a un Eco ni a un TUTORIAL ajeno (solo misión / Prueba /
  Jefe del Abismo iguales).
- La UI de votación / preparación (VotePanel, PrepPanel) queda en el código
  pero el Mundo ya no la muestra (la votación se resuelve sola). El modo de
  combate se elige desde los ajustes.
- `lastStateBytes` del registro de rendimiento queda con el último envío,
  no el más grande del tick.

## v0.31.0 (roles de exploración)

Tests salteados (prioridad: salir rápido). Solo tests de reglas en
`test/game_engine/roles_v031_test.dart`.

- Sin test de sesión: primera captura, agua brillante en `_fishBite`,
  `fisherReq`, XP de Herrería al forjar / encargar / condensar, `town.dy`
  al reabrir la sala, rechazo de acciones de un habitante mudado en su
  bioma.
- Sin test de widget: BESTIARIO DE PESCA, pantalla del pescador nativo,
  tarjeta de HERRERÍA, costo con descuento en la forja, clic sobre un
  habitante o pescador. Sin capturas nuevas en docs/release_shots.
- Party dividida: el pescador todavía no se queda afuera mientras el
  grupo baja (viajan todos juntos).
- Animales y CORRAL (farming.md § 13): solo el spec.
- Pedido de tamaño: la bolsa no guarda tamaños; se valida con el récord.
- El pescador nativo camina en elipse sin mirar obstáculos; el agua
  brillante no evita muelles.
- Paridad de XP pueblo / mazmorras: sigue sin simular.
- Sprites de los pescadores nativos: reusan el del pescador.
- Horarios de peces y afinidad de cultivos: derivados por rareza / id, sin
  tabla escrita a mano; sin test de sesión de la tirada filtrada ni del
  crecimiento con afinidad; sin registro de cultivos con "???" ni filtros
  por bioma / hora en SEMILLAS y COSECHAS.

## v0.30.0 (habitantes en el pueblo y roles)

Tests salteados (prioridad: salir rápido). Hay tests de reglas en
`test/game_engine/residents_v030_test.dart` y `biomes_v029_test.dart`.

- Sin test de sesión de las acciones `town` nuevas (invite / assign /
  gift / turnIn / fulfil / invest / order / commission), de la CASA con
  candado y cobro, ni de los beneficios aplicados (poción, XP, forja,
  PdI revelados, vida máxima y vida llena al volver).
- Sin test de widget de la pantalla del habitante (pestañas), del
  REGISTRO DE ENCARGOS, de las opciones de la CASA en EDITAR PUEBLO ni
  del resumen de la FUENTE. Sin capturas de los habitantes caminando.
- (Hecho en v0.31.0) La forja muestra y valida en el cliente el costo sin el descuento de
  Brann (el anfitrión cobra con descuento); la tienda no sabe del pueblo.
- Brann descuenta solo la forja de estadísticas (no reforja, afijos ni
  "tiradas").
- Velda revela los primeros N PdI de cada piso (no salas del mapa).
- (Hecho en v0.31.0) Los habitantes del pueblo se hablan con E; el clic sobre ellos no abre
  su pantalla todavía.
- (Hecho en v0.31.0) Las órdenes piden especie y calidad, todavía no tamaño de pez.
- (Hecho en v0.31.0) El tope diario de XP por órdenes y el encargo de forja de "uno por día"
  viven en memoria del anfitrión (se reinician al reabrir la sala).
- Paridad de XP pueblo / mazmorras (roles.md § 1): los números
  (`orderXpPerValue`, `orderXpDayCap`, `lifeLevelCharXp`) son una primera
  pasada sin medir; falta una simulación por hito de zona.
- (Hecho en v0.31.0) Árboles de oficio sin nodos de poder de aventurero; sin oficio de
  Herrería (roles.md § 5).
- Sprites: casas por nivel y habitantes son arte provisorio (los
  habitantes reusan granjero y pescador).
- (Hecho en v0.31.0) El habitante sigue también en su bioma después de mudarse.

## v0.27.0

- test/game_engine/sky_session_test.dart: en la sala (anfitrión) el reloj avanza con `farmTick`, el día nuevo toma el pronóstico, la lluvia riega las parcelas de `s.town` y la tormenta tira `LightningEvent` (JSON `bolt` ida y vuelta).
- test/game_engine/helpers_session_test.dart: `helperUpgrade` valida dueño, oficio, nivel y pago; vuelta con RITMO / RED / RAREZA / HALLAZGO; pescadores con tormenta sacan `stormFisher`; hire cobra fibra / cebo.
- test/features/world/helper_panel_test.dart: pestaña MEJORAS (MEJORAR gris con el motivo, sube el rango) en granjero y pescador.
- test/features/inventory/condense_life_test.dart: sección OFICIOS de CONDENSAR (×1 / ×5 / MÁX, gris sin materiales, "Solo en el Mundo" en la Travesía).
- test/features/world/town_edit_faro_test.dart: CONSTRUIR → FARO (gris sin oro), fantasma 1×1, MOVER y BORRAR un faro; hover con la info.
- test/features/world/sky_layer_test.dart: noche y luces no se dibujan en mazmorras ni en EDITAR PUEBLO; destello del rayo 0 con destellos apagados; cartel del pronóstico.
- test/features/world/session_music_test.dart: crossfade real a `townNight` al cruzar el atardecer con `SessionMusic` (solo está el de `trackFor`).
- El cielo arranca en el día 1 en mundos viejos; no hay forma de ver la hora fuera del tinte (un reloj en el HUD queda pendiente).

## v0.26.0 (mapa de viaje y Bosque, primera pasada)

Tests salteados (prioridad del dueño: salir rápido). Solo hay tests de
reglas en `test/game_engine/overworld_biomes_test.dart`:

- Sin test de widget del MAPA DE VIAJE (botón gris para el no anfitrión,
  PRÓXIMAMENTE, ACÁ). Se ve en `tool/shots/v0260_bosque_shots_test.dart`.
- Sin test de red con dos peers viajando (cliente que ve el cambio de
  mapa por snapshot) ni de `forage` por cable más allá del round-trip de
  `SessionJson`.
- Sin test de pesca en el lago del Bosque (tabla `kForestFish`, basura del
  Bosque); la tirada es la misma de siempre con otra lista.
- Sin test de plantar y cosechar las semillas del Bosque en la huerta
  (son `CropDef` comunes: pasan por el mismo camino que las del pueblo).
- Sin test de que la huerta, la edición del pueblo y los carteles del
  pueblo no se dibujan en el exterior (`map_game.dart`).
- Sin test del prompt `[E] Mapa de viaje` / `[E] Recolectar` ni del
  botón MAPA DE VIAJE de la fuente.

Funcionalidad pendiente:

- Party dividida (unos en el pueblo, otros en un bioma o en la
  mazmorra) y ubicación por jugador (town_loop.md § 11b). Hoy viajan
  todos juntos y decide el anfitrión.
- Con la party dividida, `roomExtra` de la dificultad por sala: hoy es
  siempre 0 porque todos bajan.
- Demora del refuerzo en los modos por ronda / por bando: solo está
  probada en la línea de tiempo (`nextTurn`).
- "Pedir ayuda" y el viaje del refuerzo (§ 11b): no hay.
- XP de personaje por recolectar; respawn por misiones
  (`biome.nodeRespawnMissions`): solo por tiempo.
- Cinemática de viaje y música propia del Bosque.
- Arte procedural de las matas (`ForagePalette`): sin entrada en
  `sprite_manifest.yaml` todavía.
- Los demás biomas (Ruinas, Cavernas, Grieta) se ven en gris.
## v0.25.7

- test/features/world/farming_world_test.dart: CONTRATAR GRANJERO desde la fuente con nivel y oro: clic en la huerta contrata (helper +1, se cobra) y sale del modo elegir; no dueño ve los botones grises con el motivo.
- test/features/world/town_strip_cards_test.dart: lado al tope muestra la tarjeta gris "Límite de ampliación alcanzado" / "Límite de este lado" y el clic en la franja no abre AMPLIAR (solo se vio en la captura).

## v0.25.5

- test/features/world/helper_panel_test.dart: pantalla del granjero (G al lado del NPC): PASAR 1 / 10 / TODO y DEVOLVER entre las dos grillas, filtro por rareza y buscador, TAREAS cambia los bits, RECOGER TODO del cofre.
- test/features/world/helper_map_test.dart: hover de un ayudante (contorno del área y tooltip "Próximo ciclo"), E en el cofre recoge, aviso "[G] Ayudante" sumado al de la huerta, NPC no tapa las labores.
- test/game_engine/helpers_session_test.dart: vuelta en la sala (anfitrión): granjero y pescador alineados al reloj, cofre lleno frena, hire / fire / giveSeeds / takeSeeds / helperTasks / collectChest validan dueño y huerta; JSON de las acciones nuevas.
- test/game_engine/town_editor_test.dart: dos huertas pegadas se funden y pasan las parcelas a la esquina nueva.
- test/features/world/life_items_view_test.dart: sub-filtro de HERRAMIENTAS y elegir lago al soltar.

## v0.25.1

- test/features/world/tool_hud_test.dart: abonar con el casillero ABONO
  (E con abono propio sobre parcela plantada → `fert` puesto y el abono
  elegido descontado; "Ya tiene abono" después; clic en `hud-fert-pick`
  cambia de abono con dos o más propios; aviso "· [F] Abonar").
- test/features/world/tool_hud_layout_test.dart: la barra de 4 casilleros
  (480 px) sin tapar chat ni pociones con texto grande (TextSize huge).
- test/features/world/life_grid_shots_test.dart: VENDER pesca (CANJEAR
  de un legendario en el detalle) y la grilla angosta (detalle arriba,
  ancho < 560).

## v0.25.8

- Sin test nuevo: que `PixelIcon` use el PNG de `items.<forma>` cuando
  está cargado y el dibujo procedural cuando falta (se verificó solo con
  las capturas de tool/shots/v0257_iconos_armas_shots_test.dart).
- No se corrió la suite completa: solo test/features/admin,
  inventory, combat (sprite_catalog, held_weapon) y world (ground_loot,
  life_grid_shots).
- Las armas en mano (weapon_overlay.dart) siguen con el dibujo procedural.
## v0.25.6

- Sin test propio: ficha RESUMIDA del arma (`itemTipSummaryParts`), el
  ejemplo de TEXTOS en Ajustes y los textos y la comparación de
  herramientas de oficio (`life_tool_text.dart`); verificados con
  tool/shots/v0256_textos_ult_shots_test.dart y a mano.
- tool/shots/v0256: `pumpPanel` fija su propio tamaño, así que la
  captura de 1024×640 de la ULT sale igual a la de 1280×720; falta una
  captura real a 1024×640.

## v0.29.0

- (Hecho en v0.30.0.) Habitantes en el pueblo (overworld_biomes.md § 10, town_editor.md
  § 3.4): solo estaban las reglas puras y el modelo (`ResidentRules`,
  `ResidentState`, cadena de encargos de Ilda) con test. Falta: guardar
  `ResidentState` en `TownState` / mundo, acciones de red (invitar,
  asignar casa, entregar encargo; subiría el protocolo a 51), la
  construcción CASA en `kConstructions` con sprites por nivel, el
  habitante caminando en el pueblo con rutina de día y noche, el "!" de
  pedido, el registro de encargos, aplicar los beneficios (pociones,
  salas reveladas, XP, forja, vida), el resumen en la fuente y las
  cadenas de Velda, Kael, Brann y Oren. Ningún habitante está completo
  de punta a punta en el juego todavía.
- La relación con el habitante todavía no sube con nada.
- Exteriores nuevos: mismo esqueleto que el Bosque; sin capturas ni test
  de UI de la pantalla del habitante ni del botón "ZONA N" del mapa de
  viaje.
- Peces y semillas nuevos usan el ícono genérico de su tipo.

## v0.32.0 (diálogo de habitantes y encargos seguidos)

- Marca de encargo en las casillas de inventario / baúl ("Lo pide Ilda
  (encargo 3)") y la marca de habitantes en el minimapa: sin hacer.
- DIARIO desde PERSONAJE: sin botón todavía (J, HUD y FUENTE sí).
- El avance "Tenés" cuenta la bolsa de oficios, no el baúl.
- Sin test de UI de la pantalla del habitante ni del DIARIO ni del HUD
  de seguidos; sin capturas nuevas.
- La tienda del habitante no tiene filtros (una sola categoría).
## v0.32.0

- Iluminación (lighting.md): la batalla no tiene oscuridad (una pelea en
  una mazmorra oscura se ve con luz normal). El minimapa y el mapa
  grande no se oscurecen ni hay niebla de exploración que respete la luz.
- Los enemigos fuera de la luz se esconden del todo; falta la silueta.
- `LightRules.carried(bonus:)` es solo el gancho: ninguna linterna,
  pasiva ni habitante sube el radio todavía. Hechizos no emiten luz.
- Sin test de UI ni captura comparativa de la capa de luz
  (`MapLightLayer`); solo tests puros de `LightRules`.
- Los números de `kLightDefs` son constantes del catálogo, no están en
  Editor → Balance (`kTuning`).
## v0.30.1 (plantilla TRASPASO)

- El alijo (`StashBoard`) no se migró a `DsTransferTemplate`: tiene
  pestañas, eco, armas equipadas, pilas y teclado propios; migrarlo sin
  cambiar comportamiento pide un paso aparte.
- El COFRE del ayudante solo se recoge entero (RECOGER TODO): sacar un
  ítem suelto pediría una acción nueva del protocolo.
- Sin test de UI de la pantalla del ayudante ni del lago con la plantilla
  (solo el test de `DsTransferTemplate`); sin captura nueva de la galería.

## v0.34.0 (mazmorras persistentes)

- Ecos por zona (portales por tier en el exterior de cada bioma,
  "Ecos de esta zona" en el mapa de viaje): solo especificado en
  docs/specs/ecos_zone.md; pide decisiones del dueño (economía del objeto
  Eco, desbloqueo de tiers, qué pasa con el Portal del pueblo).
- El grupo `Mazmorras` de `kTuning` (reaparición y costo de la Ofrenda)
  no tiene codec en Editor → Balance todavía: se cambia en el código.
- El mundo se escribe a disco al volver al pueblo y al cerrar la sala:
  si un amigo es el último en salir de una mazmorra y el anfitrión se
  cae antes de su próxima vuelta al pueblo, se pierde lo de esa visita.
- El loot que quedó en el piso de una mazmorra guardada no se guarda
  (va al Loot perdido como siempre al volver; al salir solo se pierde).
- Cofres no se rellenan con la reaparición (decisión documentada); los
  revividos dan su botín normal.
- La niebla se guarda en el dispositivo (`accounts/fog.json`), no en el
  perfil: jugar el mismo personaje en otra PC no la trae. Las 48 claves
  más recientes (también entran las de Ecos, que no vuelven).
- El altar usa el dibujo del relicario: falta un sprite propio de altar
  (sprite_manifest) y una marca en el minimapa.
- Sin test de widget del panel OFRENDA ni captura de la galería.

## Llama errante (v0.37.0)

- Sin test del motor que verifique que un enemigo detecta antes al
  jugador con la llama prendida en lo oscuro (`_enemyAi`); solo hay tests
  de `LightRules.aggroFactor` / `wispBonusFor` y del ida y vuelta de la
  acción `wisp`. Falta el ida y vuelta de `wi` en el snapshot.
- Sin test visual / captura del dibujo de la llama (`_drawWisp`).
- La predicción local no la prende al instante: se ve cuando vuelve el
  snapshot del host.

## Idiomas (v0.38.0, docs/specs/i18n.md)

- Test de glifos: zh-Hans se saltea (`pendingFont` en
  `test/i18n/glyph_coverage_test.dart`) hasta que entre Fusion Pixel
  subseteada; al agregarla, mapear zh a esa fuente y sacar el salto.
- Idioma automático: sin binding de Steamworks (`steamLanguageProvider`
  devuelve `null`); se usa el idioma del sistema.
- Solo están migrados el menú del título y lo principal de OPCIONES
  (pestañas, título, salidas, IDIOMA). El resto de OPCIONES y del juego
  sigue en literales (línea base en
  `test/i18n/hardcoded_strings_baseline.json`, fase 2).
- El lint de textos fijos es por línea y por patrones (`Text(`,
  `DsButton(`, `label:`…): no ve literales que llegan por variables ni
  concatenaciones partidas en varias líneas.
- Los layouts de datos guardan `text` (es-AR) y `textKey`: el Editor de
  pantallas todavía no edita `textKey` (fase 4); en es-AR manda `text`.
- `showQuitGameDialog` y la confirmación de la pausa siguen con su
  pregunta en español.

## Idiomas fase 3 (v0.40.0)

- Tres mecanismos para traducir catálogos (`CatalogText` + `item_names.dart`,
  `catalog_names.dart` `.tr` + `GameText.current`, `DataKeys` +
  `Strings.data`): unificarlos en uno (`docs/specs/i18n.md` §3.7).
