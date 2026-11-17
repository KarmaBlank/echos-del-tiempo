# Spec (aprobada, sin implementar): 10 jefes

Pedido del dueño: "que haya más bosses, unos 10". Hoy hay 3 (Rey Limo,
Gólem Reloj, Devorador de Eras). Se agregan 7 para tener **uno por zona**
del mundo nuevo (worldgen.md), repartidos en los niveles 1–50. Cada jefe
tiene: sprite propio (pixel art generado por `tool/export_sprites.dart`,
como los demás), stats que escalan con el nivel de la zona, barra de
quiebre, **una mecánica propia** que obliga a jugar distinto, ULT con
cinemática y sonido, y loot garantizado (Mágico o mejor; chance de su
legendario).

| # | Jefe | Zona (tipo) | Nivel | Mecánica propia | ULT |
|---|---|---|---|---|---|
| 1 | Rey Limo | Pradera (bosque) | 5 | Se divide en 2 limos al bajar del 50% | Diluvio Ácido |
| 2 | Matriarca Araña | Bosque Hondo (bosque) | 10 | Teje telarañas: un jugador pierde su turno si no lo liberan con un golpe | Nido Venenoso |
| 3 | Gólem Reloj | Ruinas Cronales (ruinas) | 15 | Cada 3 turnos "rebobina" y se cura lo recibido en el último turno, salvo que esté quebrado | Engranaje del Fin |
| 4 | Sierpe de Escarcha | Cavernas Heladas (cavernas) | 20 | Congela el campo: todos pierden 10% de velocidad por turno hasta romper sus cristales | Aliento Glacial |
| 5 | Caballero Hueco | Fortaleza Caída (ruinas) | 25 | Postura: alterna escudo (−70% daño físico) y espada (−70% daño mágico) | Juicio Hueco |
| 6 | Hechicera del Eco | Laberinto Temporal (laberinto) | 30 | Crea 2 ecos de sí misma; solo la real recibe daño completo | Coro de Ecos |
| 7 | Bestia de Magma | Grieta Ígnea (cavernas) | 35 | Charcos de lava: Quemadura extra a quien se defienda | Erupción Total |
| 8 | Espectro Coronado | Cementerio de Eras (abismo) | 40 | Invoca espectros; mientras vivan, es inmune a estados | Lamento Eterno |
| 9 | Centinela del Vacío | Abismo del Tiempo (abismo) | 45 | Marca a un jugador: si no se lo protege, recibe el próximo golpe ×2 | Colapso del Vacío |
| 10 | Devorador de Eras | Corazón del Tiempo (abismo) | 50 | Jefe final: 2 fases; en la 2.ª, Colapso Temporal cada 2 acciones | Fin de las Eras |

- Las mecánicas usan el sistema de disparadores del motor (como los
  notables) y se muestran en la barra de batalla con un chip y tooltip
  que explica cómo contrarrestarlas.
- Cada jefe tiene un cartel de entrada al empezar la pelea (nombre y
  título) y música/sonido de jefe.
- Élites y comunes nuevos por zona se definen junto con el mundo.

## Decisiones del dueño

1. Los 10 jefes de la tabla, aprobados.
2. **Repetibles**: cada misión de su zona se puede repetir y el jefe
   vuelve con nueva chance de su legendario. En el endgame aparecen al
   final de los Ecos y en versión extrema como Jefes del Abismo
   (endgame.md).
3. Foco co-op (endgame.md § 7): las mecánicas que piden coordinación
   tienen variante resoluble en solo.
