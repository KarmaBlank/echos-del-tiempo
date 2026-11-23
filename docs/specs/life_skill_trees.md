# Spec: Árboles de talentos de los oficios (OFICIOS)

Estado: implementado en v0.23.0. Relacionadas: `fishing.md`,
`farming.md`, `ascension.md` (el patrón del árbol chico y su reinicio).
Código: `data/life_tree_catalog.dart`, `rules/life_tree_rules.dart`,
`panels/life_skills_view.dart`. Números: Editor → Balance → Oficios:
árboles (`kTuning['lifeTree']`).

## 1. Pestaña OFICIOS (PERSONAJE)
Desde v0.24.4 en tres columnas: tarjetas de oficio | árbol | detalle del
nodo. Cada tarjeta, entera: nombre y puntos libres, "Nivel N" grande,
"cur / need XP · faltan n", la barra y las herramientas.
Entre ATRIBUTOS e INVENTARIO. A la izquierda una fila por oficio (Pesca,
Cultivo) con nivel, XP actual / XP para el siguiente y barra; abajo el
detalle del nodo elegido (texto con los números del Balance, costo,
estado, TOMAR y REINICIAR (GRATIS)). A la derecha el árbol del oficio
elegido: nodos cuadrados (sin esquinas redondeadas), dorados si están
tomados, borde verde si se pueden tomar; tooltip de ancho fijo.

## 2. Puntos y reglas
- Puntos ganados: `(nivel del oficio − 1) × pointsPerLevel` (1), por
  oficio (no se mezclan).
- Se toma un nodo si alcanza el costo, está unido a uno tomado (o a la
  raíz, que viene gratis) y nadie de su grupo excluyente está tomado.
- Reinicio gratis por oficio (como la ascensión). Al cargar un perfil
  los nodos inválidos se descartan en orden.
- Los puntos libres suman a la insignia de PERSONAJE (`UnusedPoints
  .oficios`, entra en `characterTotal`) y a la de la pestaña OFICIOS.

## 3. Árbol de Pesca (13 nodos)
Raíz Pescador (+5 % XP). Rama izquierda (Paciencia): Muñeca firme (zona
+6 %), luego Ojo de boya (picada 8 % antes) o Zona ancha (zona
+10 %), y Pulso quieto (mayor: zona +10 %, picada 10 %). Rama derecha
(Hondura): Rastreador (botín del agua × 1.15), luego Ojo de ruinas
(botín × 1.2) o Llamado del eco (rareza +10 %), y Mareas del tiempo
(mayor: rareza +20 %). Centro: Regateo (precio +10 %), desde cualquiera
de las dos primeras. Fila 4, excluyentes: Red de pescador (auto-pesca +1
pez) o Lance del Mañana (rareza +15 %). Final: Maestro del lago
(precio +10 %, XP +15 %).

## 4. Árbol de Cultivo (13 nodos)
Raíz Granjero (+5 % XP). Izquierda (Tierra): Surco parejo (crece +8 %),
luego Riego profundo (riego +30 %) o Tierra viva (crece +12 %), y
Raíz del tiempo (mayor: crece +12 %, calidad +0.1). Derecha (Cosecha):
Mano fina (calidad +0.1), luego Doble surco (+10 % cosecha doble) o
Ojo de semilla (hallazgos × 1.25), y Cosecha del eco (mayor: calidad
+0.2, hallazgos × 1.15). Centro: Puesto propio (precio +10 %). Fila 4,
excluyentes: Capataz (ayudante +50 % parcelas) o Manos propias
(+15 % cosecha doble). Final: Maestro de la huerta (precio +10 %, XP
+15 %).

## 5. Dónde se aplican (host)
| Efecto | Regla |
|---|---|
| zone, bite | `FishingRules.rodBonus` (zona y picada; el minijuego local los usa igual) |
| legend | rareza de la tirada del pez |
| loot | chance del botín del agua |
| auto | peces por auto-pesca |
| sell | precio del pescado / la cosecha en el agropecuario |
| xp | XP de Pesca / Cultivo |
| grow | velocidad del cultivo (se guarda al plantar en `b`) |
| quality | puntaje de quien planta, riega y cosecha (farming.md § 2.4) |
| extra | chance de cosecha doble |
| seed | chance de hallazgo de la huerta |
| water | duración del riego |
| helper | parcelas del ayudante (el mejor Capataz de la sala) |

## 6. Red y JSON
Acción `lifeTree {k: pesca|cultivo, n?}` (sin `n` = reiniciar).
Perfil: `life.ft` (Pesca) y `life.farm.tree` (Cultivo); sin las claves
(saves viejos) = árboles vacíos.

## 7. Los oficios como progresión del personaje (v0.30.0)
Visión completa en roles.md.
- Subir de nivel Pesca o Cultivo da XP de personaje (`lifeLevelCharXp`
  × nivel nuevo, tablero Pueblo), sin el tope por estadía. Las órdenes de
  los habitantes suman XP de personaje y puntos de árbol (roles.md § 3).
- v0.31.0: nodos de poder de aventurero (vida y ATQ / MAG) en los tres
  árboles; Pesca y Cultivo pasan a 16 nodos. Oficio de Herrería con su
  árbol de 8 nodos (roles.md § 5 y § 6), acción `lifeTree {k: herreria}`,
  perfil `life.st` / `life.sx`.
