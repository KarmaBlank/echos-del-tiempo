# Spec: Combate y stats

Fuente de verdad: prototipo `ecos-del-tiempo.html`, función `stats(p)`
y el motor de timeline (`battleTick`, `nextTurn`, `dmgEnemy`, `battleCmd`).
Implementación Dart: `lib/game_engine/rules/stats_calculator.dart`
(stats ya portado) + lo que falta abajo.

## Cálculo de stats (YA PORTADO — ver `StatsCalculator.calculate`)

```
maxHp  = 20 + VIT*4 + nivel*2
maxMp  = 4 + ESP*1.5 + nivel
speed  = 6 + AGI*0.5 + DES*0.1 − peso_arma + (mejora_spd * 0.3)
crit   = 0.03 + DES*0.012 + (mejora_crit * 0.02)
defn   = defensa_base_clase + defensa_escudo_arma + (mejora_def * 1)
atk    = fórmula_poder_arma(atributos) * (1 + mejora_pow*0.12)
mag    = fórmula_poder_mágico_arma(atributos) * (1 + mejora_pow*0.12)
```
Después se aplican los mods del árbol de pasivas (ver `passive_tree.md`)
multiplicativamente sobre hp/atk/mag y aditivamente sobre crit/spd/def.

## Timeline de turnos (NO migrado todavía)

- Cada actor (jugador o enemigo) tiene `nextTurnTime` y avanza según
  `100 / velocidad` por turno completo (`IVa` en el prototipo).
- `battleTick` adelanta el reloj global hasta el próximo actor con el
  `nextTurnTime` más bajo.
- El daño es **determinístico** (sin varianza aleatoria oculta): la UI
  siempre puede mostrar el desglose exacto de dónde sale cada número
  (ver `dmgLog` en el prototipo) — este comportamiento DEBE preservarse
  en la migración, es explícitamente parte del diseño (feedback de
  usuario: "los números deben ser claros, sin inconsistencias").
- Crítico: multiplicador fijo (1.5x, o 2.0x con la keystone `halcon`),
  nunca un rango.

## Estados alterados (NO migrado todavía)

- Quemadura / Veneno: stacks **sin límite** (cada stack suma daño por
  turno, sin tope de cantidad de stacks — sí hay un tope de daño por
  stack individual).
- Congelación: a stacks máximos, aturde 1 turno.
- Aturdido: pierde el turno.

## Próximo paso de migración

Portar `battleTick`/`nextTurn`/`dmgEnemy`/`battleCmd` a
`game_engine/rules/battle_engine.dart` como funciones puras que reciben
el estado de batalla + una `GameAction` y devuelven el estado nuevo +
una lista de eventos de UI (daño mostrado, texto flotante, etc.) — el
mismo patrón que `StatsCalculator`, para que sea testeable igual.
