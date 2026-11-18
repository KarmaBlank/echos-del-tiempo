import '../../../game_engine/balance/balance_codecs.dart';
import '../../../game_engine/balance/balance_registries.dart';
import '../../../game_engine/data/ascension_catalog.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/skill.dart';
import 'balance_diff.dart';

/// Una entrada del navegador del admin. [kind] `null` = ascensión (solo
/// lectura: enlaza a su kit y sus mecánicas).
class AdminEntry {
  const AdminEntry({
    required this.kind,
    required this.id,
    required this.name,
    required this.detail,
    this.links = const [],
  });

  final BalanceKind? kind;
  final String id;
  final String name;
  final String detail;

  /// Entidades relacionadas (kit y mecánicas de una ascensión).
  final List<(BalanceKind, String)> links;

  /// Clave del filtro (`skill`, `weapon`, … o `ascension`).
  String get category => kind?.jsonKey ?? ascensionCategory;

  String get categoryLabel => kind?.singular ?? 'Ascensión';

  static const ascensionCategory = 'ascension';

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = _fold(query);
    return _fold(name).contains(q) || _fold(id).contains(q) || _fold(detail).contains(q);
  }
}

/// Minúsculas sin tildes (búsqueda "sismico" → "Golpe Sísmico").
String _fold(String s) {
  const from = 'áéíóúüñ';
  const to = 'aeiouun';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = from.indexOf(c);
    b.write(i < 0 ? c : to[i]);
  }
  return b.toString();
}

const _skillKinds = {
  SkillKind.physical: 'física',
  SkillKind.magical: 'mágica',
  SkillKind.heal: 'cura',
  SkillKind.regen: 'regeneración',
  SkillKind.haste: 'prisa',
  SkillKind.taunt: 'provocar',
  SkillKind.guard: 'guardia',
  SkillKind.defenseUp: 'DEF+',
  SkillKind.protect: 'protección',
  SkillKind.bulwark: 'baluarte',
  SkillKind.support: 'apoyo',
};

/// Todas las entidades del catálogo base, en el orden de los tipos.
List<AdminEntry> buildAdminIndex(BalanceBase base) {
  final out = <AdminEntry>[];
  final c = base.catalog;
  for (final s in c.skills.values) {
    out.add(AdminEntry(
        kind: BalanceKind.skill,
        id: s.id,
        name: s.name,
        detail: '${_skillKinds[s.kind]} · MP ${s.mp} · poder ${trimNum(s.power)}'
            '${s.allTargets ? ' · a todos' : ''}'));
  }
  for (final e in c.ultimates.entries) {
    out.add(AdminEntry(
        kind: BalanceKind.ultimate,
        id: e.key,
        name: e.value.name,
        detail: 'ULT de ${e.key} · poder ${trimNum(e.value.power)}'));
  }
  for (final e in c.duals.entries) {
    out.add(AdminEntry(
        kind: BalanceKind.dual,
        id: e.key,
        name: e.value.name,
        detail: '${e.key} · poder ${trimNum(e.value.power)}'));
  }
  for (final w in c.weapons.values) {
    out.add(AdminEntry(
        kind: BalanceKind.weapon,
        id: w.id,
        name: w.name,
        detail: '${w.type} · nivel ${w.level} · tier ${w.tier} · ${w.classId}'));
  }
  for (final e in c.enemies.values) {
    out.add(AdminEntry(
        kind: BalanceKind.enemy,
        id: e.id,
        name: e.name,
        detail: '${e.boss ? 'jefe · ' : ''}vida ${e.hp} · ATQ ${e.attack} · '
            'vel ${trimNum(e.speed)}'));
  }
  for (final u in c.enemyUlts.values) {
    out.add(AdminEntry(
        kind: BalanceKind.enemyUlt,
        id: u.id,
        name: u.name,
        detail: 'poder ${trimNum(u.power)}${u.allTargets ? ' · a todos' : ''}'));
  }
  for (final cl in c.classes.values) {
    out.add(AdminEntry(
        kind: BalanceKind.classDef,
        id: cl.id,
        name: cl.name,
        detail: 'DEF ${cl.baseDefense} · arma inicial ${cl.startWeaponId}'));
  }
  for (final a in base.affixes.values) {
    out.add(AdminEntry(
        kind: BalanceKind.affix,
        id: a.id,
        name: a.name,
        detail: '${a.slot == AffixSlot.prefix ? 'prefijo' : 'sufijo'} · '
            '${a.stat.name} · peso ${a.weight}'));
  }
  for (final n in base.nodes.values) {
    final kind = switch (n.kind) {
      'st' => 'inicio',
      'n' => 'notable',
      'k' => 'keystone',
      _ => 'nodo',
    };
    out.add(AdminEntry(
        kind: BalanceKind.passiveNode,
        id: n.id,
        name: n.name,
        detail: '$kind${n.pathId == null ? '' : ' · ${n.pathId}'} · '
            '${n.effects.entries.map((e) => '${e.key} ${trimNum(e.value)}').join(', ')}'));
  }
  for (final m in base.mechanics.values) {
    out.add(AdminEntry(
        kind: BalanceKind.mechanic,
        id: m.id,
        name: m.name,
        detail: '${m.trigger.name} · ${m.description}'));
  }
  for (final a in kAscensions.values) {
    out.add(AdminEntry(
      kind: null,
      id: a.id,
      name: a.name,
      detail: '${a.classId} · ${a.theme}',
      links: [
        for (final s in a.skillIds)
          if (c.skills.containsKey(s)) (BalanceKind.skill, s),
        for (final n in a.nodes)
          if (n.mechanicId != null && base.mechanics.containsKey(n.mechanicId))
            (BalanceKind.mechanic, n.mechanicId!),
      ],
    ));
  }
  return out;
}
