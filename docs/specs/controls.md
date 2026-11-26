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
Al caminar mientras se mantiene, el objetivo se vuelve a elegir con el
mismo orden (mouse, WASD, el más cercano) entre lo que queda a alcance, o
no hay ninguno: el tile clicado al empezar solo vale mientras siga a
alcance (`ActionTargeting.heldAim`). Un objetivo lejano nunca sigue
avanzando, y la barra de progreso y el recuadro nunca se dibujan sobre un
tile fuera de alcance.

**Clic:** a alcance actúa sobre la selección; lejos no hace nada.

**Color:** verde si la acción se puede, naranja si no (el motivo va en el
aviso; un árbol ya revisado hoy queda en gris).

**Contorno o recuadro (por tipo):** el recuadro verde / naranja queda
solo para los objetivos de trabajo en el suelo (parcelas, rocas / vetas,
matas, árboles). Todo lo demás lleva un contorno blanco de 1 px alrededor
de su silueta: NPC y actores con sprite (silueta del sprite); objetos
pintados en sus tiles (portales de Ecos, arcos de misión, piedras de
paso, santuarios, fuente rúnica, bocas de mina, carteles, estaciones,
cofres de lo salvaje y de la mina): la silueta son los píxeles donde el
tile con el objeto difiere del mismo tile con suelo, y el contorno se
dibuja debajo de los actores (nunca encima del jugador); portales de
grieta: un óvalo blanco. Solo un objetivo marcado a la vez: con la
selección en algo que no es herramienta, el recuadro de la huerta y el de
la mina no se dibujan.

**Vías de la mina:** la vía de la estación (`MiningRules.track`) son
tiles de vía en el suelo (dos rieles sobre durmientes, autotile como los
cercos), debajo de los actores.

**Aviso:** siempre describe la selección ("[E] Hablar con X", "[E] Entrar
a la mina", "[E] Leer cartel"…). Sin selección quedan los avisos sin
objetivo (pesca en la orilla, ayudante, sellos y escaleras en misión).

**Hablar no se repite:** E / clic sobre algo que no es herramienta (hablar,
abrir, viajar, leer) actúa una sola vez aunque se mantenga; solo matas,
árboles, parcelas y rocas repiten.

**Red:** es solo de presentación y entrada; las acciones que se mandan son
las mismas de antes (sin cambio de protocolo).

## Edición del pueblo

Teclas de EDITAR PUEBLO (town_editor.md § 1.7):

| Tecla | Acción |
|---|---|
| 1 / 2 / 3 / 4 | CONSTRUIR / MOVER / BORRAR / CAMINOS (fila de números o teclado numérico) |
| Esc | vuelve un paso; en MOVER, BORRAR o CAMINOS vuelve a CONSTRUIR; en CONSTRUIR sale |
| WASD / flechas | mueven la cámara |
| Arrastrar | mueve la cámara; en CAMINOS pinta |
| Shift o botón derecho (CAMINOS) | borra el camino dibujado |
| Rueda | zoom |
