# Spec (aprobada): Endgame — qué hacer después del nivel 50

> **Estado (v0.4.0):** implementados § 1 (Ecos), § 2 (Atlas del
> Tiempo), § 4 primer punto (Maestría), § 5 (varios personajes) y las
> reglas de § 7 que les tocan. Detalle con números:
> docs/specs/ecos_atlas.md.
> **v0.5.0:** § 4 Ascensión (Pruebas del Tiempo, 8 ascensiones,
> mini-árboles, kit) y § 8 completos, con las reglas co-op de § 7 que les
> tocan: detalle con números en docs/specs/ascension.md.
> **v0.8.0:** § 3 Jefes del Abismo completo (docs/specs/abyss_bosses.md).
> Pendientes: § 6 (Temporadas) y las Grietas del Atlas (nodos bloqueados
> "Próximamente").

Pregunta del dueño: "si llegaste a nivel 50, ¿qué más podrías hacer con el
personaje? ¿O ya terminaste y te creás otro? ¿Cómo sería el endgame? Revisá
cómo lo hacen los ARPG de loot". Se toman las **mecánicas** del género (mapas como loot
con tiers y modificadores, árbol de progresión de endgame, jefes
pináculo, subclases, temporadas); nombres y contenido son propios.

## 0. El loop en una frase

Campaña 1→50 por las 10 zonas (10 jefes) → **Ecos** (mapas de endgame
que caen como loot, con tier y modificadores) → el **Atlas del Tiempo**
(árbol de endgame) moldea qué Ecos y qué loot aparecen → **Jefes del
Abismo** (versiones extremas) → armar el equipo perfecto con crafteo →
probar otra build en otro personaje → nueva **Temporada**.

## 1. Ecos (mapas de endgame)

- Al vencer al jefe final (nivel 50) se desbloquea el **Portal del Eco**
  en el pueblo. Los **Ecos** caen como objetos (en el inventario, con
  filtro de loot como cualquier ítem) desde el nivel 45.
- Cada Eco tiene: **tier 1–16** (nivel de monstruos 50 → 80 "de
  dificultad", sin subir el nivel del personaje), un **tipo de zona**
  (generador del mundo: bosque, cavernas, ruinas, laberinto, abismo), un
  **jefe** de los 10 al final, y **modificadores** aleatorios por rareza
  (mismo sistema de rarezas que las armas):
  - de dificultad: enemigos con +vida, +velocidad, quiebre más alto,
    aplican Quemadura, jugadores con −curación, sin regeneración…
  - cada modificador suma **+% cantidad y +% rareza de loot**.
- Usarlo abre una mazmorra de 1–3 pisos generada por semilla; completarlo
  puede soltar Ecos del mismo tier o del siguiente (el loop se sostiene
  solo). Fallar consume el Eco.
- Crafteo de Ecos con los mismos materiales (re-tirar modificadores,
  subir rareza) y un material nuevo, **Ancla Temporal** (sube el tier).
- **Implementado (v0.4.0)**: ecos_atlas.md § 1–4 (tier → nivel 48 + 2t,
  9 modificadores con +% cantidad y rareza, drops desde nivel 45, 1–3
  pisos con el generador de su zona, crafteo con Esquirla / Cristal /
  Prisma / Ancla).
  Zonas: el "tipo de zona" es una de las 10 zonas (su generador, tema,
  enemigos y música), no solo los 5 generadores de la lista de arriba.

## 2. Atlas del Tiempo

- Árbol de endgame **compartido por todos los personajes del perfil**.
- Se ganan puntos completando Ecos nuevos (bonus por tier y por jefe).
- Nodos: más Ecos de cierto tipo de zona, más chance de legendarios,
  jefes con loot extra, Ecos con un modificador gratis, "Grietas" (un
  evento dentro del Eco: oleadas por tiempo con loot extra), etc.
- **Implementado (v0.4.0)**: ecos_atlas.md § 5 (26 nodos, 51 de costo,
  44 puntos máximos; puntos por la primera vez de cada tier, zona y
  jefe — no por combinación, para que el árbol tenga decisiones). Las
  Grietas quedan como nodos "Próximamente".

## 3. Jefes del Abismo (pináculo)

- Versiones extremas de 4 jefes (Gólem Reloj, Hechicera del Eco, Espectro
  Coronado, Devorador) + un jefe secreto final.
- Para invocarlos hay que juntar **Fragmentos** que caen en Ecos de tier
  alto. Sueltan legendarios exclusivos y materiales raros.
- **Implementado (v0.8.0)**: docs/specs/abyss_bosses.md. 4 Fragmentos
  (Reloj, Eco, Corona, Eras) desde Ecos T10+, 5 abren su jefe (se
  consumen al entrar); el secreto (Eco Primordial) pide los 4 vencidos y
  1 de cada Fragmento. Peleas directas de 2–3 fases a nivel 85–90 con
  aviso del próximo movimiento y furia; 6 legendarios exclusivos, Esencia
  del Abismo (re-tira con ventaja los mods fijos de un legendario) y 1
  punto de Atlas por jefe (2 el secreto). Pestaña ABISMO del Portal.
  Co-op primero con variante solo en cada mecánica (§ 7).

## 4. Progreso del personaje en el endgame

- **Nivel 50 es el tope.** Después la XP llena la **Maestría**: cada
  nivel de maestría da 1 punto extra de árbol (tope 20), con una curva
  muy lenta — es un objetivo largo, no obligatorio.
  **Implementado (v0.4.0)**: ecos_atlas.md § 6.
- **Ascensión** (subclases): al completar una **Prueba del Tiempo**
  (mazmorra especial con trampas y un jefe) en nivel 30, 40 y 50 se
  ganan puntos de ascensión. Cada clase elige **1 de 2 ascensiones**,
  con un mini-árbol de ~8 nodos muy fuertes que definen la build:

| Clase | Ascensión A | Ascensión B |
|---|---|---|
| Guerrero | Berserker (vida baja = más daño, robo de vida) | Señor de la Guerra (gritos que buffean al grupo) |
| Maga | Cronomante (manipula el timeline: adelanta aliados, retrasa enemigos) | Elementalista (combos Quemadura/Congelación/Veneno) |
| Tirador | Francotirador (críticos enormes a un objetivo) | Trampero (trampas y daño en área) |
| Paladín | Templario (daño sagrado y aturdir) | Guardián (escudos y protección del grupo) |

- **Implementado (v0.5.0)**: ascension.md § 1–4 (Pruebas en nivel 30 /
  40 / 50 con púas y Pulsos del Tiempo, 2 puntos cada una = 6; mini-árbol
  de 8 nodos con 10 de costo; 2 habilidades y una ULT por ascensión;
  reiniciar y cambiar de ascensión gratis).
- **Equipo**: la búsqueda de armas perfectas (mods de tier alto,
  legendarios, crafteo) es el motor del endgame, como en los ARPG de loot.

## 5. Varios personajes y alijo compartido

- El perfil pasa a tener **varios personajes** (slots) y un **alijo
  compartido** entre ellos (pestañas de inventario grande), para pasar
  objetos a un personaje nuevo y probar otras builds.
- **Implementado** (spec propia: docs/specs/characters.md): cuenta
  local `account.json` con hasta 8 personajes y el elegido; el título es
  la selección de personaje (crear, renombrar, borrar con confirmación
  escrita); alijo de 3 pestañas × 8 × 6 (2 generales + ECOS desde v0.11.1, que se
  abre también en partida con `ALIJO [B]`) con armas, Ecos y materiales (hasta
  999 por tipo). Créditos y pociones siguen siendo de cada personaje.
  El `profile.json` viejo se migra como personaje #1 y queda de copia.

## 6. Temporadas (opcional)

- Cada tanto se abre una **Temporada**: personajes nuevos desde cero en
  un "reino de temporada" con una mecánica nueva (ej.: Ecos con un
  evento especial); al terminar, los personajes pasan al reino normal.
  Encaja con el actualizador: cada versión grande puede traer una.

## 7. Co-op primero, solo jugable

Decisión del dueño: "pensá el contenido singleplayer, pero el foco es
co-op".
- **Escalado 1–4 jugadores** en todo (vida, quiebre y ULT enemigas ya
  escalan con el grupo; los Ecos y Jefes del Abismo también).
- **Bonus de grupo**: +10% cantidad de loot por jugador extra en Ecos;
  el Atlas avanza para cada jugador que completa el Eco.
- **Mecánicas que premian jugar juntos**: técnicas dúo (ya existen),
  revivir, ascensiones con buffs de grupo, mecánicas de jefe que piden
  coordinarse (proteger al marcado, romper cristales entre varios,
  quebrar antes de la ULT).
- **Solo viable**: las mismas mecánicas son resolubles por un jugador
  (el escalado baja vida y quiebre; los jefes con mecánicas de grupo
  tienen una variante solo, p. ej. la marca del Centinela apunta al
  único jugador pero se puede contrarrestar defendiendo).
- El host del grupo usa su Atlas para los modificadores del Eco; cada
  jugador recibe sus puntos de Atlas.
- **Implementado para los Ecos (v0.4.0)**: escalado 1–4 de siempre,
  +10% de cantidad por jugador extra, Atlas del host, puntos para cada
  uno (ecos_atlas.md § 7).
- **Implementado para los Jefes del Abismo (v0.8.0)**: escalado 1–4, cada
  jugador tira sus Fragmentos y su botín exclusivo, puntos de Atlas para
  cada uno; mecánicas de grupo con variante solo (abyss_bosses.md § 2.3).
- **Implementado para la Ascensión (v0.5.0)**: cada jugador que supera
  una Prueba gana sus propios puntos; Señor de la Guerra, Guardián y
  Templario tienen auras y buffs de grupo (ascension.md § 1.2, § 3).

## 8. La ascensión tiene que **sentirse**

Decisión del dueño: "sí, pero que se sienta eso". Al ascender:
- **Cinemática** de ascensión al vencer la Prueba (como las ULT: la
  pantalla se detiene, el personaje se transforma, cartel con el nombre
  de la ascensión) y sonido propio.
- **Cambio visual permanente**: sprite con paleta y detalles nuevos por
  ascensión (capa, aura, arma brillante), aura en batalla y en el mapa.
- **ULT nueva o mejorada** por ascensión y 2 habilidades de kit propias
  (el Guardián 3: el kit clásico del Paladín, mejorado).
- Los nodos del mini-árbol son de impacto (cambian cómo se juega, no
  +5%): p. ej. Cronomante "tus habilidades que retrasan también
  adelantan al aliado más lento"; Berserker "por debajo de 50% de vida
  cada golpe te da otro turno parcial".
- Título visible en el HUD y en el chat ("Ana, Cronomante").
- **Implementado (v0.5.0)**: ascension.md § 5 (cinemática de 5.2 s con
  sonido y jingle propios, sprite `<clase>_<ascensión>` con respaldo al de
  la clase, aura en batalla y en el mapa, título en HUD, chat, paneles de
  grupo y tarjetas del título).

## 9. Decisiones del dueño

1. Loop **Ecos + Atlas + Jefes del Abismo**: sí.
2. **Ascensión** con 2 subclases por clase: sí, y que se sienta (§ 8).
3. **Varios personajes** por perfil con **alijo compartido**: sí.
4. **Temporadas**: más adelante (se diseñan, no se activan todavía).
5. **Foco co-op**, con el contenido solo pensado (§ 7).
