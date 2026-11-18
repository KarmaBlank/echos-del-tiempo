import 'package:echos_del_tiempo/features/bestiary/domain/bestiary_text.dart';
import 'package:echos_del_tiempo/features/combat/domain/element_text.dart';
import 'package:echos_del_tiempo/features/combat/domain/skill_text.dart';
import 'package:echos_del_tiempo/features/inventory/domain/skill_tip.dart';
import 'package:echos_del_tiempo/game_engine/data/elements_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/bestiary.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:flutter_test/flutter_test.dart';

/// Textos de elementos y reacciones (docs/specs/elemental_reactions.md
/// § 3).
void main() {
  test('cada elemento tiene color; el de su estado (statusHex)', () {
    final hexes = <String>{};
    for (final e in GameElement.values) {
      final h = elementHex(e);
      expect(h, matches(RegExp(r'^#[0-9a-f]{6}$')), reason: e.name);
      if (e.status != null) expect(h, statusHex(e.status!));
      hexes.add(h);
    }
    expect(hexes, hasLength(GameElement.values.length));
    expect(elementHex(GameElement.electro), '#c77dff');
  });

  test('carteles y descripciones con los números del catálogo', () {
    expect(reactionBanner(ReactionKind.electrocucion), '¡ELECTROCUCIÓN!');
    expect(reactionBanner(ReactionKind.explosionToxica), '¡EXPLOSIÓN TÓXICA!');
    expect(reactionBanner(ReactionKind.congelacionSubita),
        '¡CONGELACIÓN SÚBITA!');
    expect(reactionBanner(ReactionKind.derretir), '¡DERRETIR!');
    expect(reactionBanner(ReactionKind.cortocircuito), '¡CORTOCIRCUITO!');
    for (final k in ReactionKind.values) {
      expect(reactionDescription(k), isNotEmpty, reason: k.name);
    }
    expect(reactionDescription(ReactionKind.explosionToxica),
        allOf(contains('50%'), contains('25%')));
    // Un parche de balance cambia el texto.
    final patched = {
      'electrocucion': const ReactionDef(
          kind: ReactionKind.electrocucion, damageMult: 2, stunTurns: 2),
    };
    expect(reactionDescription(ReactionKind.electrocucion, defs: patched),
        allOf(contains('×2'), contains('2 turnos')));
  });

  test('línea de elemento de la ficha de habilidad', () {
    expect(
        elementReactionLine(GameElement.agua),
        'Elemento: Agua · reacciona con Electro (Electrocución, '
        'Cortocircuito) y Hielo (Congelación súbita)');
    expect(elementReactionLine(GameElement.fuego),
        'Elemento: Fuego · reacciona con Veneno (Explosión tóxica) y Hielo (Derretir)');
    expect(elementReactionLine(GameElement.veneno),
        'Elemento: Veneno · reacciona con Fuego (Explosión tóxica)');
    expect(elementReactionLine(GameElement.sagrado),
        'Elemento: Sagrado · sin reacciones');
    // Fuego + Agua, Fuego + Electro, Hielo + Electro: nada.
    expect(elementPartners(GameElement.fuego).keys,
        isNot(anyOf(contains(GameElement.agua), contains(GameElement.electro))));
    expect(elementPartners(GameElement.hielo).keys,
        isNot(contains(GameElement.electro)));
    final m = elementReactionMarkup(GameElement.agua);
    expect(m, contains('<span style="color:#3fa9f5">Agua</span>'));
    expect(m, contains('<span style="color:#c77dff">Electro</span>'));
    expect(m, isNot(contains('<b')));
  });

  test('tooltip de habilidad: línea del elemento salvo Físico', () {
    final bola = kSkills['bola']!;
    final d = describeSkillMarkup(bola, null);
    expect(d.split('<br>')[1], elementReactionMarkup(GameElement.fuego));
    final giro = kSkills['giro']!;
    expect(describeSkillMarkup(giro, null), isNot(contains('Elemento:')));
    expect(skillTipMarkup(bola), contains('reacciona con'));
    // La línea corta de los objetos no lo repite.
    expect(skillOneLineMarkup(bola), isNot(contains('Elemento:')));
  });

  test('estados nuevos y Congelación v0.7', () {
    expect(statusDescriptionOf(StatusKind.wet),
        allOf(contains('2 turnos'), contains('Electro'), contains('×1.5')));
    expect(statusDescriptionOf(StatusKind.charged),
        allOf(contains('1 turno'), contains('Agua'), contains('50%')));
    final f = statusDescriptionOf(StatusKind.freeze);
    expect(f, contains('−6% velocidad'));
    expect(f, contains('+10% de quiebre'));
    expect(f, contains('Quebradizo'));
    expect(f, contains('Derretir'));
    expect(freezeSlowTip(3), allOf(contains('−18%'), contains('+30%')));
    expect(brittleTip(), contains('×1.5'));
    expect(freezeResistTip(2), contains('2 turnos'));
  });

  test('familias: inmunidades que cortan reacciones', () {
    expect(blockedReactions({StatusKind.poison}),
        [(ReactionKind.explosionToxica, StatusKind.poison)]);
    expect(blockedReactions({StatusKind.freeze}).map((r) => r.$1), [
      ReactionKind.congelacionSubita,
      ReactionKind.derretir,
    ]);
    expect(blockedReactionsLine({StatusKind.burn}), isEmpty);
    // Ficha del enemigo / bestiario de un no muerto (inmune a Veneno).
    final info = enemyInfoMarkup(
        kEnemies['esqueleto']!, BestiaryProgress({'esqueleto': 1}));
    expect(info, contains('Sin reacción:'));
    expect(info, contains('Explosión tóxica (inmune a Veneno)'));
  });
}
