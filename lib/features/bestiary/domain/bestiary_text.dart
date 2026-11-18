import 'package:material_ui/material_ui.dart';

import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../game_engine/data/enemies_catalog.dart';
import '../../../game_engine/data/enemy_descriptions.dart';
import '../../../game_engine/data/uniques_catalog.dart';
import '../../../game_engine/data/zones_catalog.dart';
import '../../../game_engine/models/bestiary.dart';
import '../../../game_engine/models/enemy_def.dart';
import '../../../game_engine/rules/family_rules.dart';

/// Color de cada familia (ícono, nombre, borde de la ficha).
Color familyColor(EnemyFamily f) => switch (f) {
      EnemyFamily.undead => ProtoColors.cream,
      EnemyFamily.spectre => ProtoColors.violet,
      EnemyFamily.beast => ProtoColors.orange,
      EnemyFamily.arachnid => ProtoColors.pink,
      EnemyFamily.ooze => ProtoColors.mint,
      EnemyFamily.construct => ProtoColors.dim,
      EnemyFamily.fireElemental => ProtoColors.burn,
      EnemyFamily.iceElemental => ProtoColors.ice,
      EnemyFamily.temporal => ProtoColors.sky,
      EnemyFamily.aberration => ProtoColors.crimson,
    };

/// Texto cuando todavía no se lo mató (bestiary.md § 3).
const kBestiaryUnknownHint = 'Derrotalo para agregarlo al bestiario';

/// Una ficha del bestiario: el enemigo, su zona y su rol.
class BestiaryEntry {
  const BestiaryEntry({
    required this.def,
    required this.zone,
    required this.level,
    this.summon = false,
    this.elite = false,
  });

  final EnemyDef def;

  /// Índice de la zona (1..10) donde aparece; 0 = sin zona.
  final int zone;

  /// Nivel nativo del catálogo (`kEnemyBaseLevel`).
  final int level;

  /// Invocación de un jefe (no aparece en el campo).
  final bool summon;

  /// Aparece como élite de su zona.
  final bool elite;

  String get id => def.id;
  EnemyFamily? get family => familyOf(def.id);
  FamilyRule? get rule => familyRuleOf(def.id);

  String get zoneName => zone <= 0 || zone > kZones.length
      ? 'Desconocida'
      : kZones[zone - 1].name;

  String get role => def.boss
      ? 'Jefe'
      : summon
          ? 'Invocación'
          : elite
              ? 'Común · también élite'
              : 'Común';
}

/// Todas las fichas, por zona (comunes, después invocaciones, después el
/// jefe). Sale de las misiones de zona y de las mecánicas de los jefes.
List<BestiaryEntry> bestiaryEntries([Map<String, EnemyDef> enemies = kEnemies]) {
  final zoneOf = <String, int>{};
  final elites = <String>{};
  for (final m in kZoneMissions) {
    final z = m.zone;
    void put(String id) => zoneOf.putIfAbsent(id, () => z);
    for (final g in m.groups) {
      g.forEach(put);
    }
    for (final f in m.floorGroups) {
      for (final g in f) {
        g.forEach(put);
      }
    }
    m.boss.forEach(put);
    if (m.elite.isNotEmpty) {
      put(m.elite);
      elites.add(m.elite);
    }
  }
  final summons = <String>{};
  for (final e in enemies.values) {
    final add = bossMechanicOf(e)?.addType;
    if (add != null) {
      summons.add(add);
      zoneOf.putIfAbsent(add, () => zoneOf[e.id] ?? 0);
    }
  }
  final out = [
    for (final e in enemies.values)
      BestiaryEntry(
        def: e,
        zone: zoneOf[e.id] ?? 0,
        level: kEnemyBaseLevel[e.id] ?? 1,
        summon: summons.contains(e.id),
        elite: elites.contains(e.id),
      ),
  ];
  int rank(BestiaryEntry b) => b.def.boss ? 2 : (b.summon ? 1 : 0);
  out.sort((a, b) {
    final z = a.zone.compareTo(b.zone);
    if (z != 0) return z;
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    return a.level.compareTo(b.level);
  });
  return out;
}

/// Ficha por id (o `null`).
BestiaryEntry? bestiaryEntryOf(String? id) {
  if (id == null) return null;
  for (final e in bestiaryEntries()) {
    if (e.id == id) return e;
  }
  return null;
}

/// Nombre de la familia en su color.
String familyNameMarkup(EnemyFamily f) =>
    protoColor(familyColor(f), '[${f.code}] ${protoEsc(f.label)}');

/// Debilidades / resistencias / inmunidades de la familia [r], una línea
/// por grupo.
String familyTraitsMarkup(FamilyRule r) {
  final traits = familyTraits(r);
  String group(TraitKind k, Color c, String title) {
    final list = [
      for (final t in traits)
        if (t.kind == k) protoEsc(t.label),
    ];
    if (list.isEmpty) return '';
    return '${protoColor(c, title)} ${list.join(', ')}';
  }

  return [
    group(TraitKind.weak, ProtoColors.green, 'Débil:'),
    group(TraitKind.resist, ProtoColors.orange, 'Resiste:'),
    group(TraitKind.immune, ProtoColors.red, 'Inmune:'),
  ].where((s) => s.isNotEmpty).join('<br>');
}

/// "Débil a curas, Sagrado, fuego" en una línea corta (objetivo en el
/// menú de batalla), o vacío.
String familyShortMarkup(String? enemyType) {
  final f = familyOf(enemyType);
  final r = familyRuleOf(enemyType);
  if (f == null || r == null) return '';
  final weak = familyWeakSummary(r);
  return '${familyNameMarkup(f)}'
      '${weak.isEmpty ? '' : ' · ${protoColor(ProtoColors.green, 'débil a ${protoEsc(weak)}')}'}';
}

/// Lo que se ve al pasar el mouse sobre un enemigo (batalla) o en la
/// ficha del bestiario. Sin matarlo: "???" y [kBestiaryUnknownHint].
/// [level]: el nivel real en esta pelea (si se sabe). Con [description],
/// la descripción del dueño (`kEnemyDescriptions`) si hay una.
String enemyInfoMarkup(EnemyDef def, BestiaryProgress bestiary,
    {int? level, bool elite = false, bool description = false}) {
  if (!bestiary.knows(def.id)) {
    return '${protoColor(ProtoColors.gold, '???')}<br>'
        '${protoColor(ProtoColors.dim, kBestiaryUnknownHint)}';
  }
  final f = familyOf(def.id);
  final r = familyRuleOf(def.id);
  final entry = bestiaryEntryOf(def.id);
  final lv = level ?? entry?.level;
  final lines = <String>[
    '${protoColor(ProtoColors.gold, protoEsc(def.name))}'
        '${elite ? ' ${protoColor(ProtoColors.amber, 'ÉLITE')}' : ''}'
        '${lv == null ? '' : ' ${protoColor(ProtoColors.dim, 'Nv $lv')}'}',
    if (f != null) familyNameMarkup(f),
    if (description && (kEnemyDescriptions[def.id] ?? '').isNotEmpty)
      protoColor(ProtoColors.dim, protoEsc(kEnemyDescriptions[def.id]!)),
    if (r != null) familyTraitsMarkup(r),
    if (bossMechanicOf(def) case final m?)
      '${protoColor(ProtoColors.pink, 'Mecánica: ${protoEsc(m.name)}')} — ${m.counter}',
    protoColor(ProtoColors.sky, 'Derrotados: ${bestiary.killsOf(def.id)}'),
  ];
  return lines.where((l) => l.isNotEmpty).join('<br>');
}

/// Zona, nivel y botín (ficha del bestiario).
String enemyDropsMarkup(BestiaryEntry e) {
  final leg = e.def.legendaryId == null ? null : kUniques[e.def.legendaryId];
  return [
    '${protoColor(ProtoColors.dim, 'Zona:')} ${e.zone > 0 ? '${e.zone} · ' : ''}'
        '${protoEsc(e.zoneName)} · ${protoEsc(e.role)} · Nv ${e.level}',
    if (!e.def.passive)
      '${protoColor(ProtoColors.dim, 'Botín:')} ${e.def.xp} XP · '
          '${e.def.credits} créditos'
          '${leg == null ? '' : ' · ${protoColor(ProtoColors.amber, 'legendario ${protoEsc(leg.name)}')}'}',
  ].join('<br>');
}
