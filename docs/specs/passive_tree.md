# Spec: Árbol de pasivas (tipo Path of Exile)

> **Versión vigente: v3** — docs/specs/passive_tree_v3.md (352 nodos:
> anillo central, 20 clusters de clase con bifurcaciones, 4 puentes
> híbridos y 4 clusters de grupo; 60 notables y 20 keystones). La v2
> (docs/specs/passive_tree_v2.md, 112 nodos) queda como historia. Las reglas de puntos de abajo siguen valiendo; la sección
> "Datos y UI" describe la v1 (40 nodos), que ya no está en el código:
> los perfiles con árbol v1 se reinician gratis al cargarlos.

Fuente de verdad del comportamiento: prototipo `ecos-del-tiempo.html`,
objeto `TREE` + funciones `treeHas/treeCan/treePts/treeMods`.
Implementación Dart: `lib/game_engine/{models,rules}/passive_tree*.dart`.
Tests: `test/game_engine/passive_tree_rules_test.dart`.

## Reglas

1. Cada clase tiene un nodo de **inicio** fijo, que se considera siempre
   tomado y NO cuenta contra los puntos disponibles del jugador.
2. El jugador gana **1 punto de árbol por nivel ganado después del 1**
   (nivel 5 → 4 puntos totales). **Desde la v0.8 (árbol v6) son 2 por
   nivel y por Maestría** (nivel 5 → 8; passive_tree_v6.md § 7).
3. Un nodo solo se puede tomar si:
   - todavía no lo tiene, **y**
   - tiene al menos 1 punto disponible (`puntos_totales - nodos_tomados`), **y**
   - está conectado (`links`) a un nodo que ya tiene (inicio incluido), **y**
   - no tiene una keystone excluyente ya tomada (tabla `exclusions`).
4. Las **keystones** (`kind: 'k'`) son el nodo final de cada rama y
   pueden traer trade-offs fijos, aparte de su efecto declarado (v2 suma
   `egida`: −20% ATQ y MAG, y `danza`: crítico máx. 40%):
   - `furia`: +35% ATQ, −4 DEF
   - `mente`: +30% MAG, −20% vida máx.
   - `halcon`: críticos ×2.0 en vez de ×1.5, pero −15% ATQ
   - `toxicidad`: +2 stacks de Veneno en habilidades, −10% ATQ
   - `creyente` / `inherente`: mutuamente excluyentes entre sí
5. `treeMods` se recalcula sumando los efectos de **todos** los nodos
   tomados + el de inicio, cada vez que cambia el build (nunca se cachea
   stale: ver `StatsCalculator.calculate`, que llama a `aggregate` en
   cada recálculo de stats).

## Datos y UI (v1, reemplazado)

El `TREE` completo de la v1 (40 nodos: 4 centros de clase con 2 ramas de 4 nodos
y los puentes `b_ne`, `b_se`, `b_sw`, `b_nw`) está en
`lib/game_engine/data/passive_tree_catalog.dart`; los nodos tomados se
guardan en el perfil (`tree`, progression.md). El dibujo, los textos
(`fxTxt`, `KEYS`) y los motivos de bloqueo están en
docs/specs/panels.md § "Árbol".
