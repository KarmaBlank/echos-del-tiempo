# Controles del mapa

## Cursor de acción

Una sola regla (`game_engine/rules/action_targeting.dart`,
`ActionTargeting.select`) decide sobre qué actúa E / el clic. El aviso de
abajo, el recuadro en el mapa y la entrada leen la misma selección: lo
que marca el cursor es lo que hace E.

**Alcance:** `actionReachTiles` (Balance, por defecto 1): el tile del
jugador y sus 8 vecinos.

**Candidatos:** todo lo que responde a E, cada uno en su tile y con su
propio rango de antes (px):
- NPC: habitante del bioma y del pueblo, pescador nativo, PNJ de la mina
  (minera), NPC hechos con datos (Editor), actores de eventos del mundo
  (visitas, errantes, élites) y portales de grieta.
- Lugares del pueblo: tablero, armería, forja, taller, estatua, torre del
  loot perdido, puesto propio, comerciante, fuente rúnica, Portal del Eco,
  estación de carros, camino de viaje y carteles (E lee el cartel en un
  aviso).
- Exterior: portal de Ecos, bocas de mina, piedras de paso, cofres y
  santuarios de lo salvaje, muelle de balsa, matas y árboles revisables
  (desde cualquier lado).
- Mina: salida, pozo, rocas y hallazgos (cofre, reliquia, hongos, piedra
  de lore, lugar de la estación).
- Huerta: la parcela; cofres de oficio. Entradas de misión (arcos).
- Los ayudantes siguen con G / clic (E queda para la huerta).

Alcance de la elección: 3 tiles (cada candidato ya pasó su propio rango).
**No hay prioridad fija entre tipos**: dos cosas de tipos distintos una al
lado de la otra se eligen con el mouse o con WASD como cualquier par.

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
aviso; un árbol ya revisado hoy queda en gris).

**Contorno o recuadro (por tipo):** lo que tiene silueta de sprite lleva
un contorno blanco de 1 px alrededor de la silueta en vez del recuadro:
todos los NPC y actores de eventos, el cofre de oficio, la armería, la
forja y el taller (sprites), y el cofre de lo salvaje (su caja, pintada en
el tile, lleva el mismo contorno). Lo que está pintado en el suelo lleva
el recuadro: piedras de paso, portales, santuarios, bocas de mina, fuente,
carteles, matas, árboles, parcelas y rocas. Solo un objetivo marcado a la
vez: con la selección en algo que no es herramienta, el recuadro de la
huerta y el de la mina no se dibujan.

**Aviso:** siempre describe la selección ("[E] Hablar con X", "[E] Entrar
a la mina", "[E] Leer cartel"…). Sin selección quedan los avisos sin
objetivo (pesca en la orilla, ayudante, sellos y escaleras en misión).

**Hablar no se repite:** E / clic sobre algo que no es herramienta (hablar,
abrir, viajar, leer) actúa una sola vez aunque se mantenga; solo matas,
árboles, parcelas y rocas repiten.

**Red:** es solo de presentación y entrada; las acciones que se mandan son
las mismas de antes (sin cambio de protocolo).
