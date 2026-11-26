# Controles del mapa

## Cursor de acción

Una sola regla (`game_engine/rules/action_targeting.dart`,
`ActionTargeting.select`) decide sobre qué actúa E / el clic. El aviso de
abajo, el recuadro en el mapa y la entrada leen la misma selección: lo
que marca el cursor es lo que hace E.

**Alcance:** `actionReachTiles` (Balance, por defecto 1): el tile del
jugador y sus 8 vecinos.

**Candidatos:** matas, árboles revisables (desde cualquier lado, no solo
el de enfrente), parcelas de la huerta, rocas / hallazgos de la mina y
habitantes (NPC).

**Orden de elección:**
1. Mouse: el tile bajo el puntero, si está a alcance y tiene algo. Vale
   mientras el jugador no se mueva de donde estaba cuando se movió el
   mouse; al caminar, manda el teclado hasta que el mouse se mueva otra vez.
2. Teclado: el vecino en la última dirección de WASD (eje dominante;
   empate = horizontal; sin dirección = abajo).
3. El más cercano: primero los posibles, después distancia, después y, x
   (determinista).

**Mantener E / clic** (cozy_life.md § 3): al terminar un objetivo pasa al
siguiente más cercano sin repetir (los ya hechos en el mantener se saltan);
el mouse sigue mandando. Una parcela bloqueada se saltea.

**Clic:** a alcance actúa sobre la selección; lejos no hace nada.

**Color:** verde si la acción se puede, naranja si no (el motivo va en el
aviso; un árbol ya revisado hoy queda en gris). Los NPC no llevan
recuadro: el elegido se dibuja con un contorno blanco de 1 px alrededor de
su silueta; solo uno a la vez. El aviso sigue diciendo "[E] Hablar con X".

**Red:** es solo de presentación y entrada; las acciones que se mandan son
las mismas de antes (sin cambio de protocolo).
