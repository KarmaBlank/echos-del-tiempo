import '../data/elements_catalog.dart';
import '../data/enemy_families.dart';
import '../models/battle_state.dart';
import '../models/skill.dart';
import '../models/status.dart';

export '../data/enemy_families.dart';

// Reglas de las familias de enemigos (docs/specs/bestiary.md § 1): qué
// familia es un enemigo, qué tipos de daño lleva un golpe y cuánto lo
// cambia la familia. Puro Dart: lo usan el motor de batalla, el bestiario
// y (las notables del árbol) cualquier regla que necesite "contra no
// muertos".

/// Familia del tipo de enemigo [enemyType], o `null` (sin dato).
EnemyFamily? familyOf(String? enemyType) =>
    enemyType == null ? null : kEnemyFamily[enemyType];

/// Reglas de la familia de [enemyType], o `null`.
FamilyRule? familyRuleOf(String? enemyType) {
  final f = familyOf(enemyType);
  return f == null ? null : kFamilyRules[f];
}

/// [c] es de la familia / raza [f] (para notables / pasivas:
/// `isFamily(target, EnemyFamily.undead)`). Simétrico desde v0.7: vale
/// para jugadores con raza (elemental_reactions.md § 5.4).
bool isFamily(Combatant? c, EnemyFamily f) => c != null && c.family == f;

/// Familia / raza del combatiente, o `null`.
EnemyFamily? familyOfCombatant(Combatant? c) => c?.family;

/// Tipo de daño de familia de un elemento (`null`: físico y veneno).
DamageTag? damageTagOf(GameElement e) => switch (e) {
      GameElement.fuego => DamageTag.fire,
      GameElement.hielo => DamageTag.ice,
      GameElement.sagrado => DamageTag.holy,
      GameElement.agua => DamageTag.water,
      GameElement.electro => DamageTag.electric,
      GameElement.fisico || GameElement.veneno => null,
    };

/// Tipos de daño de un golpe con la habilidad [sk] (`null` = ataque
/// normal, físico). Las curas / regeneraciones son Sagradas (la luz del
/// creyente).
Set<DamageTag> skillDamageTags(SkillDef? sk) {
  if (sk == null) return const {DamageTag.physical};
  final tags = <DamageTag>{};
  switch (sk.kind) {
    case SkillKind.physical:
      tags.add(DamageTag.physical);
    case SkillKind.magical:
      tags.add(DamageTag.magical);
    case SkillKind.heal:
    case SkillKind.regen:
      tags.add(DamageTag.holy);
    default:
      break;
  }
  for (final st in [if (sk.status != null) sk.status!, ...sk.extraStatuses]) {
    switch (st.kind) {
      case StatusKind.burn:
        tags.add(DamageTag.fire);
      case StatusKind.freeze:
        tags.add(DamageTag.ice);
      case StatusKind.holy:
        tags.add(DamageTag.holy);
      default:
        break;
    }
  }
  if (kHolySkillIds.contains(sk.id)) tags.add(DamageTag.holy);
  // v0.7: el elemento de la habilidad (Agua, Electro...).
  final el = damageTagOf(elementOf(sk.id));
  if (el != null) tags.add(el);
  return tags;
}

/// Un factor de familia que entró en un golpe (para el log y la UI).
class FamilyFactor {
  const FamilyFactor(this.tag, this.value);
  final DamageTag tag;
  final double value;
  bool get weak => value > 1;
}

/// Factores de la familia [r] para un golpe con [tags]: el del tipo
/// (físico / mágico) y, de los elementos, la debilidad más alta y la
/// resistencia más fuerte (no se multiplican dos debilidades: Consagrar
/// a un no muerto es Sagrado ×1.5, no ×1.5 × 1.25 por el fuego).
List<FamilyFactor> familyFactors(FamilyRule? r, Set<DamageTag> tags) {
  if (r == null || tags.isEmpty) return const [];
  final out = <FamilyFactor>[];
  for (final t in tags) {
    if (t.isElement) continue;
    final v = r.damage[t];
    if (v != null && v != 1) out.add(FamilyFactor(t, v));
  }
  FamilyFactor? weak, resist;
  for (final t in tags) {
    if (!t.isElement) continue;
    final v = r.damage[t];
    if (v == null || v == 1) continue;
    if (v > 1 && (weak == null || v > weak.value)) weak = FamilyFactor(t, v);
    if (v < 1 && (resist == null || v < resist.value)) {
      resist = FamilyFactor(t, v);
    }
  }
  return [...out, if (weak != null) weak, if (resist != null) resist];
}

/// Producto de [familyFactors].
double familyMultiplier(FamilyRule? r, Set<DamageTag> tags) =>
    familyFactors(r, tags).fold(1.0, (m, f) => m * f.value);

/// Stacks de [kind] que le entran a la familia [r] al aplicarle [n]
/// (mín. 1); 0 si es inmune.
int familyStacks(FamilyRule? r, StatusKind kind, int n) {
  if (r == null) return n;
  if (r.immune.contains(kind)) return 0;
  final d = r.stacks[kind] ?? 0;
  if (d == 0) return n;
  final out = n + d;
  return out < 1 ? 1 : out;
}

/// Tipo de un rasgo de familia para la UI.
enum TraitKind { weak, resist, immune, special }

/// Un rasgo para mostrar ("Sagrado ×1.5"). Solo datos de juego: sin
/// textos de ambientación (las descripciones son del dueño,
/// `data/enemy_descriptions.dart`).
class FamilyTrait {
  const FamilyTrait(this.kind, this.label);
  final TraitKind kind;
  final String label;

  @override
  String toString() => label;
}

String _x(double v) {
  final s = v.toStringAsFixed(2);
  return '×${s.replaceFirst(RegExp(r'\.?0+$'), '')}';
}

/// Rasgos de la familia [r], en el orden en que se muestran: debilidades,
/// resistencias e inmunidades.
List<FamilyTrait> familyTraits(FamilyRule r) {
  final out = <FamilyTrait>[];
  if (r.healHarm > 0) {
    out.add(FamilyTrait(TraitKind.weak,
        'las curas le hacen daño (${(r.healHarm * 100).round()}% de la cura)'));
  }
  for (final e in r.damage.entries) {
    if (e.value > 1) {
      out.add(
          FamilyTrait(TraitKind.weak, '${_cap(e.key.label)} ${_x(e.value)}'));
    }
  }
  for (final e in r.stacks.entries) {
    if (e.value > 0) {
      out.add(FamilyTrait(TraitKind.weak, '${e.key.label} +${e.value} stack'));
    }
  }
  if (r.breakMult > 1) {
    out.add(FamilyTrait(TraitKind.weak, 'Quiebre ${_x(r.breakMult)}'));
  }
  if (r.delayMult > 1) {
    out.add(FamilyTrait(TraitKind.weak, 'Retrasos ${_x(r.delayMult)}'));
  }
  if (r.markMult > 1) {
    out.add(FamilyTrait(TraitKind.weak, 'Marca ${_x(r.markMult)}'));
  }
  if (r.holyTick > 1) {
    out.add(FamilyTrait(
        TraitKind.weak, 'daño del estado Sagrado ${_x(r.holyTick)}'));
  }
  for (final e in r.damage.entries) {
    if (e.value < 1) {
      out.add(
          FamilyTrait(TraitKind.resist, '${_cap(e.key.label)} ${_x(e.value)}'));
    }
  }
  for (final e in r.stacks.entries) {
    if (e.value < 0) {
      out.add(FamilyTrait(TraitKind.resist, '${e.key.label} ${e.value} stack'));
    }
  }
  for (final k in r.immune) {
    out.add(FamilyTrait(TraitKind.immune, k.label));
  }
  return out;
}

/// "Débil a Sagrado, fuego" (corto, para la línea del objetivo).
String familyWeakSummary(FamilyRule r) {
  final weak = [
    if (r.healHarm > 0) 'curas',
    for (final e in r.damage.entries)
      if (e.value > 1) e.key.label,
    for (final e in r.stacks.entries)
      if (e.value > 0) e.key.label,
    if (r.breakMult > 1) 'quiebre',
    if (r.delayMult > 1) 'retrasos',
    if (r.markMult > 1) 'Marca',
  ];
  return weak.toSet().join(', ');
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
