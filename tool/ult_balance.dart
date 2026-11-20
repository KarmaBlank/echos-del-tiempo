// Mide las 50 ULT v2 (docs/specs/ultimates_v2.md § 3.7): valor esperado
// por punto de carga, con 40 semillas y grupos de 1 a 4, a nivel 1 y 5.
//
//   dart run tool/ult_balance.dart
//
// Valor = daño hecho + vida curada/escudos + turnos ganados (retraso a
// enemigos y adelanto a aliados, en "golpes" del lanzador) + buffs (su
// valor en daño de grupo). Meta: cada ULT dentro de ±15% de la mediana
// de su rol por punto de carga; las 13 de tipo de arma como referencia.
import 'dart:io';

import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/ults_v2_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/skill.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/mulberry32.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';

final _stats =
    StatsCalculator(classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

const _seeds = 40;
const _enemies = ['esqueleto', 'esqueleto', 'esqueleto'];

/// Clase y arma para medir [u] (la primera compatible).
(String, String) loadout(String id) {
  final u = kUltV2[id];
  final cls = u != null && u.classes.isNotEmpty ? u.classes.first : null;
  final type = u != null && u.weapons.isNotEmpty ? u.weapons.first : null;
  for (final w in kWeapons.values) {
    if (type != null && w.type != type) continue;
    if (cls != null && w.classId != cls) continue;
    if (w.tier < 1) continue;
    return (cls ?? w.classId, w.id);
  }
  final c = cls ?? 'guerrero';
  return (c, kClasses[c]!.startWeaponId);
}

BattlePartyMember member(String id, String cls, String weapon,
        {String? sel, int level = 1}) =>
    BattlePartyMember(
      id: id,
      name: id,
      ult: 100,
      hp: null,
      build: PlayerBuild(
        classId: cls,
        level: 20,
        attributes: PlayerAttributes.base(kClasses[cls]!.baseAttributes)
            .add({Attribute.fue: 20, Attribute.esp: 20, Attribute.des: 10}),
        equippedWeapon: kWeapons[weapon]!,
        ultSel: sel,
        ultLevel: level,
      ),
    );

/// Valor medio de lanzar la ULT [id] (o, con [type], la del tipo).
double measure(String id, {int level = 1, String? weaponType}) {
  var total = 0.0;
  var n = 0;
  for (var g = 1; g <= 4; g++) {
    for (var seed = 1; seed <= _seeds; seed++) {
      final rng = mulberry32(seed * 31 + g);
      final engine = BattleEngine(stats: _stats, random: rng);
      final (cls, w) = weaponType == null
          ? loadout(id)
          : (kWeapons.values.firstWhere((x) => x.type == weaponType && x.tier >= 1).classId,
              kWeapons.values.firstWhere((x) => x.type == weaponType && x.tier >= 1).id);
      final party = [
        member('p1', cls, w, sel: weaponType == null ? id : null, level: level),
        for (var i = 2; i <= g; i++) member('p$i', 'guerrero', 'espada_bronce'),
      ];
      var st = engine.start(party: party, enemyTypes: _enemies, triggeredBy: 'p1').state;
      for (final p in st.party.skip(1)) {
        p.hp = (p.maxHp * 0.6).round();
      }
      st = engine.nextTurn(st).state;
      if (st.currentId != 'p1') continue;
      final me = st.party.first;
      final before = {for (final c in [...st.party, ...st.enemies]) c.id: c.nextTurn};
      final step = engine.command(st, 'p1', const UltimateCommand());
      if (step == null) continue;
      // Unidad: un golpe del lanzador con su stat principal.
      final atk = (me.magic > me.attack ? me.magic : me.attack).toDouble();
      var v = 0.0;
      double hpOf(String id) =>
          (st.byId(id)?.maxHp ?? 100).toDouble().clamp(1, 1e9);
      for (final e in step.events) {
        switch (e) {
          case DamageEvent(:final targetId, :final amount) when targetId.startsWith('e'):
            v += amount;
          // Curas y escudos: 1 vida entera de un aliado = 2 golpes.
          case HealEvent(:final targetId, :final amount, :final mana) when !mana:
            v += amount / hpOf(targetId) * 2 * atk;
          case ShieldEvent(:final targetId, :final amount, :final absorbed) when !absorbed:
            v += amount / hpOf(targetId) * 2 * atk;
          case RevivedEvent():
            v += atk * 2;
          default:
            break;
        }
      }
      final s = step.state;
      // Turnos ganados: retraso a enemigos / adelanto a aliados, en
      // fracciones de turno × medio golpe.
      for (final c in [...s.enemies, ...s.party]) {
        final d = c.nextTurn - (before[c.id] ?? c.nextTurn);
        final iv = 100 / c.speed;
        if (!c.isPlayer && c.alive && d > 0) v += (d / iv) * atk * 0.5;
        if (c.isPlayer && c.id != 'p1' && d < 0) v += (-d / iv) * atk * 0.5;
      }
      // Buffs/debuffs (no escudos ni cargas): % × turnos × golpe × 0.5.
      for (final c in [...s.party, ...s.enemies]) {
        for (final f in c.effects) {
          final src = f.sourceId;
          if (src != id && !src.startsWith('ult2_')) continue;
          if (f.stat.name == 'shield' || f.stat.name == 'charge') continue;
          v += f.value.abs().clamp(0, 1) * f.turns * atk * 0.5;
        }
      }
      // Estados aplicados a enemigos: 0.3 golpe por stack.
      v += step.events
              .whereType<StatusAppliedEvent>()
              .where((e) => e.targetId.startsWith('e'))
              .fold(0, (a, e) => a + e.stacks) *
          atk *
          0.3;
      // Disparo cargado / marca diferida: su daño futuro.
      for (final f in s.party.first.effects) {
        if (f.stat.name == 'charge') v += f.value;
      }
      for (final e in s.enemies) {
        if (e.doomTurns > 0) v += e.doom * 0.85;
      }
      total += v / atk;
      n++;
    }
  }
  return n == 0 ? 0 : total / n;
}

void main() {
  final ref = <String, double>{
    for (final t in kAllUltimates.keys) t: measure(t, weaponType: t),
  };
  final refMed = _median(ref.values.toList());
  stdout.writeln('Referencia (13 de tipo de arma, costo 100): mediana '
      '${refMed.toStringAsFixed(2)} golpes de ATQ por ULT');
  String role(SkillDef k) => k.kind == SkillKind.heal
      ? 'C'
      : !k.dealsDamage
      ? 'S'
      : k.allTargets
          ? 'DA'
          : 'D1';
  final rows = <(String, String, double, double)>[];
  for (final u in kUltV2List) {
    final v1 = measure(u.id) / u.cost * 100;
    final v5 = measure(u.id, level: 5) / u.cost * 100;
    rows.add((u.id, role(u.skill), v1, v5));
  }
  final med = {
    for (final r in ['D1', 'DA', 'S', 'C'])
      r: _median([for (final x in rows) if (x.$2 == r) x.$3]),
  };
  var high = 0;
  stdout.writeln('\nid                         rol  nv1/100  nv5/100  vs rol');
  for (final r in rows) {
    final rel = r.$3 / med[r.$2]!;
    final flag = rel > 1.35 ? ' DOMINA' : rel > 1.15 ? ' alta' : rel < 0.85 ? ' baja' : '';
    if (rel > 1.35) high++;
    stdout.writeln('${r.$1.padRight(26)} ${r.$2.padRight(3)} '
        '${r.$3.toStringAsFixed(2).padLeft(7)}  ${r.$4.toStringAsFixed(2).padLeft(7)}'
        '  ${rel.toStringAsFixed(2)}$flag');
  }
  stdout.writeln('\nmedianas por rol: $med · referencia ${refMed.toStringAsFixed(2)} · '
      'dominan (>1.35× su rol): $high');
  // Ninguna domina: nivel 1 dentro de 1.35× la mediana de su rol y nivel
  // 5 (×${1 + 4 * 0.06}) sin pasar 1.7×.
  final top5 = [for (final r in rows) r.$4 / med[r.$2]!].reduce((a, b) => a > b ? a : b);
  stdout.writeln('máximo a nivel 5 vs su rol: ${top5.toStringAsFixed(2)}');
  if (high > 0 || top5 > 1.7) exitCode = 1;
}

double _median(List<double> l) {
  final s = [...l]..sort();
  return s.isEmpty ? 0 : s[s.length ~/ 2];
}

// ignore: unused_element
SkillDef? _skill(String id) => kUltV2Skills[id];
