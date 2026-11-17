# Spec: Árbol de pasivas (tipo Path of Exile)

Fuente de verdad del comportamiento: prototipo `ecos-del-tiempo.html`,
objeto `TREE` + funciones `treeHas/treeCan/treePts/treeMods`.
Implementación Dart: `lib/game_engine/{models,rules}/passive_tree*.dart`.
Tests: `test/game_engine/passive_tree_rules_test.dart`.

## Reglas

1. Cada clase tiene un nodo de **inicio** fijo, que se considera siempre
   tomado y NO cuenta contra los puntos disponibles del jugador.
2. El jugador gana **1 punto de árbol por nivel ganado después del 1**
   (nivel 5 → 4 puntos totales).
3. Un nodo solo se puede tomar si:
   - todavía no lo tiene, **y**
   - tiene al menos 1 punto disponible (`puntos_totales - nodos_tomados`), **y**
   - está conectado (`links`) a un nodo que ya tiene (inicio incluido), **y**
   - no tiene una keystone excluyente ya tomada (tabla `exclusions`).
4. Las **keystones** (`kind: 'k'`) son el nodo final de cada rama y
   pueden traer trade-offs fijos, aparte de su efecto declarado:
   - `furia`: +35% ATQ, −4 DEF
   - `mente`: +30% MAG, −20% vida máx.
   - `halcon`: críticos ×2.0 en vez de ×1.5, pero −15% ATQ
   - `toxicidad`: +2 stacks de Veneno en habilidades, −10% ATQ
   - `creyente` / `inherente`: mutuamente excluyentes entre sí
5. `treeMods` se recalcula sumando los efectos de **todos** los nodos
   tomados + el de inicio, cada vez que cambia el build (nunca se cachea
   stale: ver `StatsCalculator.calculate`, que llama a `aggregate` en
   cada recálculo de stats).

## No migrado todavía

- El árbol completo con los 4 "centros" de clase y los nodos puente
  entre ellos (`b_ne`, `b_se`, `b_sw`, `b_nw`) — hoy solo hay un árbol
  de ejemplo de 3 nodos en los tests. Portar el `TREE` completo del
  prototipo es el próximo paso de `game_engine/models/passive_tree.dart`
  (un data file, no requiere cambiar reglas).
- Persistencia (perfil local) de `PlayerPassiveProgress`.
