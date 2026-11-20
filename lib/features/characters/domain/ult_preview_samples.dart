import '../../../game_engine/models/passive_mechanic.dart' show BuffStat;
import '../../../game_engine/models/skill.dart';
import '../../../game_engine/rules/js_math.dart';
import '../../combat/domain/skill_text.dart';

/// Qué muestra un número de ejemplo de la vista previa de una ULT.
enum UltSampleKind { damage, heal, shield, status, breakBar, buff }

/// Un número / efecto de ejemplo sobre los objetivos de la vista previa
/// (docs/specs/ultimates_v2.md § 2.5). [hex] = color `#rrggbb`.
class UltSample {
  const UltSample(this.kind, this.text, this.hex);

  final UltSampleKind kind;
  final String text;
  final String hex;

  @override
  String toString() => '${kind.name}:$text';
}

/// A quién apunta la vista previa y con cuántas figuras (1–3).
typedef UltPreviewReach = ({bool foes, int count});

UltPreviewReach ultPreviewReach(SkillDef sk) => switch (skillReach(sk)) {
      SkillReach.oneFoe => (foes: true, count: 1),
      SkillReach.allFoes => (foes: true, count: 3),
      SkillReach.ally => (foes: false, count: 1),
      SkillReach.party => (foes: false, count: 3),
      SkillReach.self => (foes: false, count: 1),
    };

/// Los números de ejemplo de [sk] (ya nivelada) con los stats del
/// personaje: las mismas fórmulas que el motor (daño ATQ/MAG × poder,
/// cura `(MAG × poder + 6) × (1 + cura)`, escudo = fracción de la vida
/// máx.). Dart puro: lo testea `flutter test` sin UI.
List<UltSample> ultPreviewSamples(
  SkillDef sk, {
  required int attack,
  required int magic,
  required int maxHp,
  double healBonus = 0,
}) {
  final out = <UltSample>[];
  final dmg = sk.kind == SkillKind.physical || sk.kind == SkillKind.magical;
  final base = sk.charge > 0
      ? attack * sk.charge
      : (sk.kind == SkillKind.magical ? magic : attack) * sk.power;
  if (dmg || (sk.kind == SkillKind.support && sk.power > 0)) {
    final v = jsRound(base);
    out.add(UltSample(UltSampleKind.damage,
        sk.hits > 1 ? '$v ×${sk.hits}' : '$v', '#ffd166'));
  }
  if (sk.kind == SkillKind.heal || sk.kind == SkillKind.regen) {
    final v = jsRound((magic * sk.power + 6) * (1 + healBonus));
    out.add(UltSample(UltSampleKind.heal, '+$v', '#55efc4'));
  }
  final shield = sk.partyShield > 0
      ? sk.partyShield
      : sk.allyShield > 0
          ? sk.allyShield
          : sk.selfShield;
  if (shield > 0) {
    out.add(UltSample(UltSampleKind.shield,
        'ESCUDO ${jsRound(maxHp * shield)}', '#74b9ff'));
  }
  for (final st in [if (sk.status != null) sk.status!, ...sk.extraStatuses]) {
    final n = st.chance != null
        ? '${jsRound(st.chance! * 100)}%'
        : '+${st.stacks}';
    out.add(
        UltSample(UltSampleKind.status, '$n ${st.kind.label}', statusHex(st.kind)));
  }
  if (sk.breaks || sk.breakBonus > 0) {
    out.add(const UltSample(UltSampleKind.breakBar, 'QUIEBRE', '#ffe14d'));
  }
  for (final b in [...sk.partyBuffs, if (sk.selfBuff != null) sk.selfBuff!]) {
    final pct = jsRound(b.value * 100);
    out.add(UltSample(
        UltSampleKind.buff, '${b.stat.label} +$pct%', '#9fb4ff'));
  }
  for (final b in sk.debuffs) {
    // Como el texto de la habilidad: la marca suma daño recibido; ATQ y
    // velocidad bajan.
    final pct = jsRound(b.value.abs() * 100);
    out.add(UltSample(
        UltSampleKind.buff,
        switch (b.stat) {
          BuffStat.damageTaken => 'MARCA +$pct%',
          BuffStat.attack || BuffStat.speed => '${b.stat.label} −$pct%',
          _ => '${b.stat.label} ${b.value < 0 ? '−' : '+'}$pct%',
        },
        '#ff6b81'));
  }
  if (out.isEmpty) {
    out.add(UltSample(UltSampleKind.buff, sk.name.toUpperCase(), '#9fb4ff'));
  }
  return out;
}
