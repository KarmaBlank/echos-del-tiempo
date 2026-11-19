import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_state.dart';
import '../../../game_engine/models/skill.dart';
import '../../../game_engine/rules/battle_engine.dart';
import '../../../game_engine/rules/js_math.dart';
import '../../../game_engine/rules/progression_rules.dart';
import 'skill_tip.dart';

/// Qué cambia **en batalla** al pasar de [before] a [after] (forja de un
/// arma, un punto de atributo): líneas en markup con tus números reales,
/// calculadas con el mismo código que la batalla (`BattleEngine.interval`
/// para el turno, ATQ / MAG × poder de cada habilidad de [weapon],
/// `defensePercent`, crítico). Solo las líneas que cambian. Ver
/// docs/specs/panels.md § "En batalla (v0.5.1)".
List<String> battleImpactLines(ProgressionRules rules, DerivedStats before,
    DerivedStats after,
    {ItemInstance? weapon}) {
  final out = <String>[];
  String up(num a, num b, {bool higherIsBetter = true}) {
    final better = (b > a) == higherIsBetter;
    return '<b style="color:${better ? '#7bed9f' : '#ff6b81'}">'
        '${_fmt(b)}</b>';
  }

  // Turnos: el tiempo entre turnos de la línea de tiempo.
  if ((before.speed - after.speed).abs() > 1e-6) {
    out.add(turnIntervalLine(rules, before, after.speed));
  }
  // Daño: el básico y cada habilidad del arma.
  final skills = <SkillDef>[
    if (weapon != null)
      for (final id in rules.items.skillsOf(weapon))
        if (rules.catalog.skills[id] case final s?) s,
  ];
  if (before.attack != after.attack) {
    final parts = [
      'Atacar ${before.attack} → ${up(before.attack, after.attack)}',
      for (final s in skills)
        if (s.kind == SkillKind.physical)
          '${s.name} ${jsRound(before.attack * s.power)} → '
              '${up(before.attack * s.power, jsRound(after.attack * s.power))}'
              '${s.allTargets ? ' c/u' : ''}',
    ];
    out.add(parts.join(' · '));
  }
  if (before.magic != after.magic) {
    final parts = [
      for (final s in skills)
        if (s.kind == SkillKind.magical)
          '${s.name} ${jsRound(before.magic * s.power)} → '
              '${up(before.magic * s.power, jsRound(after.magic * s.power))}'
        else if (s.kind == SkillKind.heal)
          '${s.name} cura ${jsRound(before.magic * s.power + 6)} → '
              '${up(before.magic * s.power + 6, jsRound(after.magic * s.power + 6))}',
    ];
    out.add(parts.isEmpty
        ? 'Poder mágico ${before.magic} → ${up(before.magic, after.magic)} '
            '(habilidades mágicas y curas)'
        : parts.join(' · '));
  }
  if ((before.critChance - after.critChance).abs() > 1e-6 ||
      before.critMultiplier != after.critMultiplier) {
    out.add('Crítico ${jsRound(before.critChance * 100)}% → '
        '${up(before.critChance * 100, jsRound(after.critChance * 100))}% de '
        'chance (daño ×${_fmt(after.critMultiplier)})');
  }
  if ((before.defensePercent - after.defensePercent).abs() > 1e-6) {
    const hit = 20;
    out.add('Daño recibido −${jsRound(before.defensePercent * 100)}% → '
        '−${up(before.defensePercent * 100, jsRound(after.defensePercent * 100))}%: '
        'un golpe de $hit te saca ${jsRound(hit * (1 - before.defensePercent))} → '
        '${up(hit * (1 - before.defensePercent), jsRound(hit * (1 - after.defensePercent)), higherIsBetter: false)}');
  }
  if (before.maxHp != after.maxHp) {
    out.add('Vida ${before.maxHp} → ${up(before.maxHp, after.maxHp)}');
  }
  if (before.maxMp != after.maxMp) {
    final s = skills.where((s) => s.mp > 0).firstOrNull;
    out.add('Maná ${before.maxMp} → ${up(before.maxMp, after.maxMp)}'
        '${s == null ? '' : ' (${s.name}: ${before.maxMp ~/ s.mp} → ${after.maxMp ~/ s.mp} usos)'}');
  }
  return out;
}

/// Cambio del tiempo entre turnos (`BattleEngine.interval`, el de la
/// batalla) al pasar de una velocidad a otra.
class TurnChange {
  const TurnChange(this.before, this.after);

  /// Tiempo entre turnos antes y después.
  final double before;
  final double after;

  /// `+12` = 12% más seguido; `-12` = 12% más lento.
  int get percent => jsRound((before / after - 1) * 100);

  /// Si es más rápido: cada cuántos turnos se gana uno (0 = no aplica).
  int get extraTurnEvery =>
      before > after ? jsRound(after / (before - after)) : 0;
}

/// [TurnChange] de la velocidad de [stats] (sin buffs: fuera de la
/// batalla) a la misma ficha con velocidad [afterSpeed].
TurnChange turnChange(
    ProgressionRules rules, DerivedStats stats, double afterSpeed) {
  final engine = BattleEngine(stats: rules.stats, catalog: rules.catalog);
  final u = tipUser(stats)!;
  final ib = engine.interval(u);
  u.speed = afterSpeed;
  return TurnChange(ib, engine.interval(u));
}

/// `Tu turno llega cada 10.4 → 9.9 de tiempo (≈5% más seguido; +1 turno
/// cada ~19)` (markup), de la velocidad de [before] a [afterSpeed].
String turnIntervalLine(
    ProgressionRules rules, DerivedStats before, double afterSpeed) {
  final t = turnChange(rules, before, afterSpeed);
  final ib = t.before, ia = t.after;
  final pct = t.percent;
  final every = t.extraTurnEvery;
  return 'Tu turno llega cada ${_fmt(ib)} → '
      '<b style="color:${ia < ib ? '#7bed9f' : '#ff6b81'}">${_fmt(ia)}</b> de tiempo'
      '${pct > 0 ? ' (≈$pct% más seguido${every > 0 && every < 100 ? '; +1 turno cada ~$every' : ''})' : pct < 0 ? ' (≈${-pct}% más lento)' : ''}';
}

/// Lo que el peso [weight] del arma le cuesta en turnos a quien tiene
/// [stats] (los suyos **con** esa arma): `Por el peso tu turno llega cada
/// 10.6 de tiempo en vez de 9.3 (≈12% más lento)`. `null` si no pesa.
String? weightTurnLine(
    ProgressionRules rules, DerivedStats stats, double weight) {
  if (weight <= 1e-9) return null;
  // Sin el peso tendría `speed + weight` (la fórmula lo resta 1:1).
  final t = turnChange(rules, stats, stats.speed + weight);
  // t.before = con el peso, t.after = sin él.
  final pct = -TurnChange(t.after, t.before).percent;
  return 'Por el peso tu turno llega cada '
      '<b style="color:#ff6b81">${_fmt(t.before)}</b> de tiempo en vez de '
      '${_fmt(t.after)}${pct > 0 ? ' (≈$pct% más lento)' : ''}';
}

/// `En batalla:` + las líneas (o `null` si nada cambia).
String? battleImpactMarkup(ProgressionRules rules, DerivedStats before,
    DerivedStats after,
    {ItemInstance? weapon}) {
  final l = battleImpactLines(rules, before, after, weapon: weapon);
  if (l.isEmpty) return null;
  return '<span class="k">En batalla:</span><br>${l.join('<br>')}';
}

String _fmt(num x) =>
    x == x.roundToDouble() ? '${x.round()}' : x.toStringAsFixed(1);
