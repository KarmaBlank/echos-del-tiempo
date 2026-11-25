# Spec: Ecos por zona (v0.35.0, protocolo 59)

Estado: implementado en v0.35.0 (diseño aprobado por el dueño). Cambia
ecos_atlas.md § 1 y § 4 (dónde se abre un Eco) y overworld_biomes.md
(plano de los exteriores).

Código: `lib/game_engine/rules/eco_portal_rules.dart` (portales,
desbloqueo, motivos), `BiomeLayout.ecoPortals`
(`data/biomes_catalog.dart`), `SessionEngine._proposeEco`,
`WorldEngine.travel` / `enter`. UI: `features/endgame/presentation/`
`eco_zone_hub.dart` (organismo `EcoZoneHub` + molécula `EcoTierGrid`),
`eco_zone_portal_panel.dart`, `eco_portal_panel.dart` (pestaña ZONAS) y
`world/presentation/panels/travel_panel.dart` (pestaña ECOS).

## 1. Regla

- Un Eco sigue siendo **un objeto** (`EcoItem`, loot; ecos_atlas.md § 2)
  de una zona y un tier. Se abre **solo** en el portal de Ecos de su
  zona, en el exterior del bioma de esa zona. Sin un Eco de ese tier y
  zona el portal no abre nada: el panel lo dice y ABRIR queda gris.
- El Portal del Eco del pueblo **ya no abre Ecos**: es el centro de viaje
  (ZONAS), el crafteo (ECOS), el ATLAS y el ABISMO.
- Los Ecos nunca persisten (persistent_dungeons.md § 0).

## 2. Portales en el exterior

- Un portal **por zona** (no uno por tier: 2 zonas × 16 tiers no entran
  en 34 tiles de ancho). El tier se elige en el panel del portal.
- `BiomeLayout.ecoPortals`: para cada entrada `(zona, x, 3)`, un portal
  de 3 tiles (`Tile.portal`, el mismo arte del portal del pueblo como
  placeholder) centrado en el primer `x' ≥ x + 3` con `x' % 3 == 1`, en
  la fila de la entrada, con camino debajo y el cartel
  `ECOS · ZONA n` encima. Ej.: Bosque zonas 1 y 2 en x 13 y 28.
- `[E] Portal de Ecos` a ≤ 14 px del borde del portal
  (`EcoPortalRules.near`).

## 3. Desbloqueo por personaje

- **T1**: vencido el jefe de la zona (zonas 1–9: `unlockedZone > zona`;
  zona 10: `ecosUnlocked`, el Devorador de Eras).
- **T(n+1)**: completado un Eco Tn de esa zona. Perfil `ecoTiers`
  (JSON `ezt`, `{"zona": tier}`): el tier más alto completado por zona;
  se anota en el host al completar el Eco, para cada jugador presente
  (`EcoPortalRules.recordCompleted`). Perfiles viejos: vacío (solo T1).
- Tiers cerrados: grises, con tooltip del motivo
  ("Vencé al jefe de …" / "Completá un Eco Tn de esta zona para abrir el
  Tn+1").
- El Ancla puede subir un Eco por encima del tier abierto: se guarda
  hasta abrir ese portal.

## 4. Abrir (portal de la zona)

1. `[E]` en el portal → panel PORTAL DE ECOS · ZONA n: grilla de tiers
   (con cuántos Ecos tenés de cada uno), lista de tus Ecos de esa zona y
   ese tier, ficha y ABRIR (gris con motivo: tier cerrado, sin Eco, en
   misión, lejos del portal).
2. ABRIR manda `ProposeEcoAction(uid)` de siempre. El host valida: modo
   lobby sin votación, el Eco en el inventario, el jugador **frente al
   portal de la zona del Eco** en ese exterior y el tier abierto. Si no,
   lo rechaza (también desde el pueblo).
3. Movimiento libre (free_movement.md § 2.1): el que abre (y sus
   compañeros de solitario) entra solo a una instancia nueva `dN`, sin
   votación ni LISTO, con el `place` del exterior (al salir vuelve ahí).
   El Eco se consume al empezar. `WorldEngine.enter` copia la posición
   del jugador a la instancia nueva para que la validación del portal
   valga ahí también.
4. Sumarse: como hasta ahora, **no** se puede sumar a un Eco ajeno (es
   de quien lo abrió; free_movement.md § 1). Un amigo que quiera ir abre
   su propio Eco.

ABRIR gris con motivo (`ecoZoneOpenBlocked`): tier cerrado,
sin Eco del tier, **alguien sin el TUTORIAL** (`TutorialRules.missing`:
"Primero, todos tienen que hacer el TUTORIAL. Falta: …"; el motor ya lo
rechazaba con `tutorialLocked`), fuera de misión, votación abierta o
lejos del portal.

## 5. Viajar a un portal

- `TravelAction(lugar, ecoZone: n)` (JSON `ez`, protocolo 59): viaja al
  exterior del portal de la zona n (tiene que ser `lugar`) y deja al
  jugador y sus compañeros frente a él (`EcoPortalSpot.front`). Si ya
  está en ese exterior, solo lo acerca. Mismas reglas que viajar
  (overworld_biomes.md, free_movement.md § 2.2).
- **Centro de viaje** (`EcoZoneHub`, un solo organismo): grilla de las 10
  zonas (tiers abiertos y cantidad de Ecos) y, a la derecha, la grilla de
  tiers de la elegida con IR AL PORTAL (gris con motivo si el bioma está
  cerrado o estás en misión). El tier elegido queda preseleccionado al
  abrir el portal. Está en:
  - Portal del Eco del pueblo, pestaña ZONAS (la primera);
  - Mapa de viaje, pestaña ECOS (reemplaza el botón "Ecos de esta
    zona").
- La pestaña ECOS del Portal del pueblo sigue con la lista y el crafteo
  (ecos_atlas.md § 4.1); en lugar de ABRIR tiene IR AL PORTAL a la zona
  de ese Eco.

## 6. Protocolo

59: plano de los exteriores con los portales (los pares arman el mapa),
`travel` con `ez`, perfil con `ezt`. `ProposeEcoAction` no cambia.

## 7. Deuda

- Un portal por tier (16 en fila) con su propio arte.
- Sumarse a un Eco ajeno.
- Arte propio del portal de zona (hoy el del pueblo).
