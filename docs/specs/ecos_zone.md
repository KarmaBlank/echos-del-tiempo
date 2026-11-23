# Spec: Ecos por zona (propuesta, sin implementar)

Estado: **pendiente** (pedido del dueño en v0.34.0; anotado en
tech_debt.md § v0.34.0). No se implementó en esta rama porque cambia la
economía de los Ecos (ecos_atlas.md) y pide decisiones del dueño.

## 1. Pedido

- Los Ecos pasan a ser **de una zona**. En el exterior del bioma de esa
  zona (overworld_biomes.md) hay **portales del Eco**, uno por tier.
- En el mapa de viaje, "Ecos de esta zona" lleva a ese exterior.
- Cada portal abre un Eco de su tier, **generado al azar cada vez**
  (los Ecos nunca persisten: persistent_dungeons.md § 0).

## 2. Hoy (ecos_atlas.md)

- Un solo Portal del Eco en el pueblo; se activa al vencer al jefe de la
  zona 10. Un Eco es un **objeto** (`EcoItem`: tier, zona, jefe, rareza,
  mods, pisos, semilla) que cae como loot y se gasta al abrirlo
  (`ProposeEcoAction(uid)`); el Ancla sube su tier.
- `WorldEngine.enter` ya mete al jugador en una instancia nueva `dN`
  desde el pueblo o desde un exterior; un Eco es de quien lo abre.

## 3. Propuesta con el menor cambio

1. `PoiKind`/tile `ecoPortal` nuevo en el layout del exterior de cada
   bioma (`BiomeLayout`), N portales en fila con cartel `T1..Tn`.
2. `[E]` en un portal → el mismo panel del Portal del Eco filtrado: los
   Ecos del inventario cuya `zona` es la del bioma y cuyo tier es el del
   portal. ABRIR manda el `ProposeEcoAction(uid)` de siempre; el host
   valida además que el jugador esté en el exterior de esa zona.
3. Sin un Eco de ese tier: (opción A) el portal no abre; (opción B) abre
   un Eco "base" de ese tier generado al azar (`EcoRules.generate` con
   `zone` fija) sin consumir nada. **Decisión del dueño**: B cambia toda
   la economía (los Ecos dejarían de ser loot).
4. Desbloqueo de tiers por portal: (propuesta) T1 con la zona vencida;
   T(n+1) al completar un Eco Tn de esa zona (el Atlas ya anota
   tier × zona).
5. "Ecos de esta zona" en el mapa de viaje: botón al lado de VIAJAR
   que viaja al exterior y deja al jugador frente a los portales.
6. El Portal del pueblo queda como acceso a todos (o se retira):
   **decisión del dueño**.

Protocolo: no necesita acción nueva si se mantiene el objeto Eco (3A);
3B pide `ProposeEcoAction` con tier y zona en vez de uid.
