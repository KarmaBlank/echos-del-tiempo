import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_panel.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/data/skills_catalog.dart';
import '../../../game_engine/models/battle_command.dart';
import '../../../game_engine/models/battle_event.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/bestiary.dart';
import '../../../game_engine/models/skill.dart';
import '../../../game_engine/models/status.dart';
import '../../../game_engine/rules/battle_engine.dart' show ultimateOf;
import '../../../game_engine/rules/js_math.dart';
import '../../bestiary/domain/bestiary_text.dart';
import '../../bestiary/presentation/enemy_info_card.dart';
import '../domain/skill_text.dart';
import '../domain/turn_order.dart';
import 'battle_command_window.dart';
import 'battle_hud.dart';
import 'game_sprites.dart';
import 'scene/battle_layout.dart';
import 'scene/battle_painter.dart';
import 'scene/battle_scene.dart';

/// Pantalla de batalla pixel art: arriba la escena del prototipo (grupo
/// y enemigos sobre el mapa, efectos, franja de turnos y log) y abajo una
/// barra fija que nunca la tapa: mis datos (solo el jugador local), el
/// menú de comandos (`#menu`) y el resto del grupo en filas compactas,
/// con los textos y colores del prototipo. Escena y efectos en
/// docs/specs/battle_presentation.md; barra, menú y teclas en
/// docs/specs/exploration.md § "Batalla".
///
/// No tiene lógica de juego: dibuja el [battle] que recibe y entrega los
/// comandos del jugador local por [onCommand]. Quien la usa decide de
/// dónde sale el estado (hoy: la sesión, `SessionBattleScreen`).
class BattleView extends StatefulWidget {
  const BattleView({
    super.key,
    required this.battle,
    required this.onCommand,
    this.events = const [],
    this.eventSeq = 0,
    this.battleId = 0,
    this.canAct = false,
    this.turnTimeLeft,
    this.turnLimit = 30,
    this.sprites,
    this.arena,
    this.localId,
    this.random,
    this.pendingPoints = const {},
    this.sceneOptions = const SceneOptions(),
    this.bestiary,
    this.enemyLevel,
  });

  /// Bestiario de la cuenta (docs/specs/bestiary.md § 3): al pasar el
  /// mouse sobre un enemigo se ve su ficha si ya se lo mató, o "???".
  /// `null` = sin fichas (previsualización).
  final BestiaryProgress? bestiary;

  /// Nivel de los enemigos de esta pelea (`SessionBattle.level`).
  final int? enemyLevel;

  final BattleState battle;

  /// Eventos del último paso del motor (se animan una vez por [eventSeq]).
  final List<BattleEvent> events;

  /// Sube con cada paso nuevo (`SessionView.battleEventSeq`).
  final int eventSeq;

  /// Identifica la batalla (`SessionBattle.id`): otra = escena limpia.
  final int battleId;

  /// Le toca al jugador de este dispositivo: se muestra el menú.
  final bool canAct;

  /// Segundos que le quedan al jugador de turno (`TURN_LIMIT − turnT`).
  final double? turnTimeLeft;

  /// Segundos de un turno entero (tiempo de turno de la sala).
  final double turnLimit;

  /// Manda un comando del actor de turno. Devuelve si fue aceptado.
  final bool Function(BattleCommand command) onCommand;

  /// Sprites ya cargados; sin ellos se dibujan rectángulos.
  final GameSprites? sprites;

  /// Dónde ocurre la batalla en el mapa; sin arena, fondo liso.
  final BattleArena? arena;

  /// Jugador de este dispositivo (nombre dorado en la escena, `.pbox.me`).
  final String? localId;

  /// Azar de las partículas (los tests lo fijan).
  final math.Random? random;

  /// Puntos de atributo sin repartir por jugador (`+N pts` de la caja).
  final Map<String, int> pendingPoints;

  /// Ajustes del jugador para la escena (sacudida, destellos, números,
  /// velocidad; docs/specs/settings.md). Solo cambian cómo se ve.
  final SceneOptions sceneOptions;

  @override
  State<BattleView> createState() => BattleViewState();
}

/// Teclas numéricas del menú de batalla (1-9).
const kBattleMenuKeys = 9;

/// La página [page] del menú de batalla (docs/specs/exploration.md §
/// "Batalla"). Con [keys] opciones o menos, todas juntas. Si no, la
/// página 0 conserva [head] (Atacar, Liberar, ULT) y [tail] (pociones y
/// Defender), mete las de [middle] (técnicas y dúos) que entran y
/// `more(n)` (n = las que quedan); las páginas siguientes muestran el
/// resto de [middle] (con otro `more` si no entra) y terminan en [back].
/// Nunca devuelve más de [keys] opciones. [page] fuera de rango = la
/// última.
List<T> battleMenuPage<T>(
  List<T> head,
  List<T> middle,
  List<T> tail,
  int page, {
  required T Function(int hidden) more,
  required T back,
  int keys = kBattleMenuKeys,
}) {
  if (head.length + middle.length + tail.length <= keys) {
    return [...head, ...middle, ...tail];
  }
  final room = math.max(0, keys - head.length - tail.length - 1);
  final pages = <List<T>>[
    [
      ...head,
      ...middle.take(room),
      more(middle.length - room),
      ...tail,
    ],
  ];
  var i = room;
  while (i < middle.length) {
    final left = middle.length - i;
    if (left <= keys - 1) {
      pages.add([...middle.skip(i), back]);
      i = middle.length;
    } else {
      final n = keys - 2;
      pages.add([...middle.skip(i).take(n), more(left - n), back]);
      i += n;
    }
  }
  return pages[page.clamp(0, pages.length - 1)];
}

class BattleViewState extends State<BattleView>
    with SingleTickerProviderStateMixin {
  /// Enemigo apuntado (`tgt` del prototipo).
  String? _target;

  /// Submenú de poción abierto (`potMode`): elegir a quién.
  BattleItem? _potMode;

  /// Categoría elegida en la ventana de comandos.
  BattleCategory _category = BattleCategory.attack;

  /// Acción elegida (índice en la lista que se ve).
  int _selected = 0;

  /// Página de la categoría cuando tiene más de 9 acciones
  /// ([battleMenuPage]).
  int _page = 0;

  /// Página de la categoría que se ve (0 = la primera).
  int get menuPage => _page;

  /// Categoría que se ve (tests).
  BattleCategory get category => _category;

  /// Acción elegida (tests).
  int get selectedAction => _selected;

  late final BattleSceneController scene =
      BattleSceneController(random: widget.random);
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  /// Margen y separación de la barra de abajo (px de pantalla).
  static const _margin = 6.0;

  List<Combatant> get _foes =>
      widget.battle.enemies.where((e) => e.alive).toList();

  /// El objetivo actual, o el primer enemigo vivo si cayó.
  String? get target {
    final foes = _foes;
    if (foes.isEmpty) return null;
    if (foes.any((e) => e.id == _target)) return _target;
    return foes.first.id;
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1000;
      _last = elapsed;
      scene.advance(dt);
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    scene.dispose();
    super.dispose();
  }

  void _resetMenu() {
    _potMode = null;
    _category = BattleCategory.attack;
    _selected = 0;
    _page = 0;
  }

  @override
  void didUpdateWidget(BattleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Turno nuevo (u otro actor) o sin poder actuar: el menú vuelve al
    // principio (nunca queda elegida una acción del turno anterior).
    if (!widget.canAct ||
        oldWidget.battle.currentId != widget.battle.currentId) {
      _resetMenu();
    }
  }

  /// `cycleTarget`: el siguiente enemigo vivo.
  void cycleTarget() {
    final foes = _foes;
    if (foes.isEmpty) return;
    final i = foes.indexWhere((e) => e.id == target);
    setState(() => _target = foes[(i + 1) % foes.length].id);
  }

  void _send(BattleCommand cmd) {
    if (widget.onCommand(cmd)) setState(_resetMenu);
  }

  /// Cambia de categoría (la lista vuelve a la primera acción).
  void selectCategory(BattleCategory c) {
    if (_potMode == null && c == _category) return;
    setState(() {
      _potMode = null;
      _category = c;
      _selected = 0;
      _page = 0;
    });
  }

  void _moveCategory(int d) {
    final cur = widget.battle.current;
    if (cur == null) return;
    final cats = [for (final e in _entries(cur)) e.category];
    if (cats.isEmpty) return;
    final i = cats.indexOf(_category);
    final n = (i < 0 ? 0 : i + d).clamp(0, cats.length - 1);
    selectCategory(cats[n]);
  }

  /// Teclas de batalla: 1-9 eligen la acción N de la lista que se ve,
  /// ↑/↓ mueven la elegida, ←/→ cambian de categoría, Enter/Espacio
  /// confirman, Q/Tab cambian de objetivo y Esc sale del submenú (o
  /// vuelve a la primera página). Devuelve si la tecla se usó.
  bool handleKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.keyQ || key == LogicalKeyboardKey.tab) {
      cycleTarget();
      return true;
    }
    if (key == LogicalKeyboardKey.escape && _potMode != null) {
      setState(() {
        _potMode = null;
        _selected = 0;
      });
      return true;
    }
    if (key == LogicalKeyboardKey.escape && _page > 0) {
      setState(() {
        _page = 0;
        _selected = 0;
      });
      return true;
    }
    final cur = widget.battle.current;
    final acting = widget.canAct && cur != null && cur.isPlayer;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      if (acting && _potMode == null) {
        _moveCategory(key == LogicalKeyboardKey.arrowLeft ? -1 : 1);
      }
      return true;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      if (acting) {
        final n = _visible(cur).length;
        if (n > 0) {
          setState(() => _selected =
              (_selected + (key == LogicalKeyboardKey.arrowUp ? -1 : 1)) % n);
        }
      }
      return true;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      if (acting) {
        final v = _visible(cur);
        if (_selected >= 0 && _selected < v.length) {
          v[_selected].onSelect?.call();
        }
      }
      return true;
    }
    const digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    final n = digits.indexOf(key);
    if (n < 0) return false;
    if (!acting) return true;
    final opts = _visible(cur);
    if (n < opts.length) {
      setState(() => _selected = n);
      opts[n].onSelect?.call();
    }
    return true;
  }

  // ---------------- menú (`hud()`, líneas 1205-1223) ----------------

  /// `Quiebre n/m` del enemigo [e] (docs/specs/break_and_enemy_ults.md
  /// § 1), con `¡VULNERABLE!` si está quebrado y `¡ULT!` si la avisó.
  static String breakInfoMarkup(Combatant e) {
    if (!e.hasBreak && !e.ultPending) return '';
    final parts = <String>[
      if (e.hasBreak)
        e.broken
            ? hexSpan('#ffe14d', '¡VULNERABLE! ×1.5')
            : hexSpan('#ffe14d',
                'Quiebre ${e.breakGauge.floor()}/${e.breakMax.round()}'),
      if (e.ultPending) hexSpan('#ff3355', '¡ULT!'),
    ];
    return ' · ${parts.join(' ')}';
  }

  /// `est(v, all)`: daño estimado en dorado y el crítico en `#7d8bc4`.
  /// Sin [crit] (filas del menú) solo la cifra: el crítico va en la
  /// descripción.
  static String _est(Combatant p, num v,
          {bool all = false, bool crit = true}) =>
      ' <span style="color:#ffd166">${jsRound(v)}${all ? ' c/u' : ''}</span>'
      '${crit ? '<span style="color:#7d8bc4"> (crít ${jsRound(v * p.critMultiplier)})</span>' : ''}';

  /// `+N` / `P%` y la letra del estado en su color.
  static String _stTag(StatusApplication st) => hexSpan(
      statusHex(st.kind),
      '${st.chance != null ? '${jsRound(st.chance! * 100)}% ' : '+${st.stacks}'}'
      '${statusLetterOf(st.kind)}');

  /// Lo que se agrega al nombre de una técnica (`info`, línea 1217).
  static String _skillInfo(SkillDef tk, Combatant p, {bool crit = true}) =>
      (tk.charge > 0
          ? _est(p, p.attack * tk.charge, crit: crit)
          : _skillInfoBase(tk, p, crit: crit)) +
      variantTagMarkup(tk);

  static String _skillInfoBase(SkillDef tk, Combatant p, {bool crit = true}) {
    switch (tk.kind) {
      case SkillKind.heal:
        return ' ${hexSpan('#7bed9f', '+${jsRound(p.magic * tk.power + 6)}${tk.lowestAlly ? '' : ' c/u'}')}';
      case SkillKind.haste:
        return ' ${hexSpan('#ffd166', 'adelanta aliados')}';
      case SkillKind.taunt:
        return ' ${hexSpan('#ff7675', 'te atacan a ti ×${tk.amount}')}';
      case SkillKind.guard:
        return ' ${hexSpan('#74b9ff', 'equipo recibe ½')}';
      case SkillKind.regen:
        return ' ${hexSpan('#7bed9f', '+${jsRound(p.magic * tk.power + 4)}${tk.lowestAlly ? '' : ' c/u'} + regen 5%×3')}';
      case SkillKind.defenseUp:
        // Fortaleza del Guardián: también escudo al grupo.
        return ' ${hexSpan('#74b9ff', 'DEF +${tk.amount} (ahora ${p.defense})${tk.partyShield > 0 ? ' + escudo a todos' : ''}')}';
      case SkillKind.protect:
        return ' ${hexSpan('#ffeaa7', 'absorbe el daño de aliados')}';
      case SkillKind.bulwark:
        return ' ${hexSpan('#74b9ff', 'cura 30%, defensa y protección')}';
      case SkillKind.support:
        // Kit de ascensión: el primer efecto, corto.
        final b = tk.partyBuffs.firstOrNull;
        // Variantes (escudos, debuffs sin daño): solo su etiqueta.
        if (b == null &&
            tk.partyShield <= 0 &&
            variantTagMarkup(tk).isNotEmpty) {
          return '';
        }
        return ' ${hexSpan('#ffb142', b != null ? 'grupo ${b.stat.label} ${jsRound(b.value * 100)}%' : tk.partyShield > 0 ? 'escudo a todos' : tk.advanceAllies > 0 ? 'adelanta aliados' : tk.trap > 0 ? 'trampas' : tk.selfBuff != null ? 'crítico seguro' : 'apoyo')}';
      case SkillKind.physical || SkillKind.magical:
        final st = tk.status;
        return _est(p,
                (tk.kind == SkillKind.magical ? p.magic : p.attack) * tk.power,
                all: tk.allTargets, crit: crit) +
            (st != null ? ' ${_stTag(st)}' : '') +
            (tk.critBonus > 0
                ? hexSpan('#ff6b81', ' +${jsRound(tk.critBonus * 100)}% crít')
                : '');
    }
  }

  /// Descripción de Atacar.
  static String _attackDesc(Combatant cur) =>
      '<b>Atacar</b> <span class="k">sin costo</span><br>'
      'Daño físico ATQ ${cur.attack}:${_est(cur, cur.attack)}'
      '${cur.stunOnAttackChance > 0 ? '<br>${hexSpan('#ffeaa7', '${jsRound(cur.stunOnAttackChance * 100)}% de aturdir')}' : ''}'
      '${cur.branch == 'creyente' ? '<br>${hexSpan('#7bed9f', '25%: cura 2% al grupo')}' : cur.branch == 'inherente' ? '<br>${hexSpan('#fff3b0', '25%: aplica Sagrado')}' : ''}';

  /// Las categorías del menú de [cur] con sus acciones (las vacías no
  /// están). Cada acción con su id estable.
  List<BattleCategoryEntry> _entries(Combatant cur) {
    final b = widget.battle;
    final tg = target;
    final ult = ultimateOf(cur);
    final allies = b.party.where((q) => q.alive && q.id != cur.id).toList();
    final out = <BattleCategoryEntry>[];

    out.add(BattleCategoryEntry(BattleCategory.attack, [
      BattleAction(
        id: 'attack',
        name: 'Atacar',
        value: _est(cur, cur.attack, crit: false),
        description: _attackDesc(cur),
        onSelect: () => _send(AttackCommand(targetId: tg)),
      ),
      // Telaraña de la Matriarca: Atacar sobre un aliado atrapado lo libera.
      for (final q in allies)
        if (q.webbed)
          BattleAction(
            id: 'free-${q.id}',
            name: 'Liberar a ${protoEsc(q.name)}',
            cost: hexSpan('#edeff5', '½ turno'),
            description: '<b>Liberar</b><br>Cortás la telaraña de '
                '${protoEsc(q.name)}: no pierde su turno. Te cuesta medio '
                'turno.',
            onSelect: () => _send(AttackCommand(targetId: q.id)),
          ),
    ]));

    final skills = [
      for (final id in cur.skillIds)
        if (kSkills[id] case final sk?)
          BattleAction(
            id: 'skill-$id',
            name: '${sk.name}${sk.delay > 0 ? ' ⏳' : ''}',
            value: _skillInfo(sk, cur, crit: false).trim(),
            cost: hexSpan('#74b9ff', '${sk.mp} MP'),
            description: describeSkillMarkup(sk, cur),
            reason: cur.mp >= sk.mp ? null : 'Falta maná (${sk.mp} MP).',
            onSelect: cur.mp >= sk.mp
                ? () => _send(SkillCommand(id, targetId: tg))
                : null,
          ),
    ];
    if (skills.isNotEmpty) {
      out.add(BattleCategoryEntry(BattleCategory.skills, skills,
          badge: hexSpan('#9fb4ff', '${skills.length}')));
    }

    final duos = [
      for (final q in allies)
        if (kDuals[dualKey(cur.classId ?? '', q.classId ?? '')] case final du?)
          BattleAction(
            id: 'duo-${q.id}',
            name: '★ ${du.name} (+${protoEsc(q.name)})',
            value:
                '${_est(cur, (math.max(cur.attack, cur.magic) + math.max(q.attack, q.magic)) * du.power, all: true, crit: false)} ${_stTag(du.status)}',
            cost: hexSpan('#74b9ff', '4 MP c/u'),
            dual: true,
            description: '<b>★ ${du.name}</b> <span class="k">dúo con '
                '${protoEsc(q.name)}</span><br>'
                '(máx(ATQ, MAG) tuyo + suyo) × ${fm(du.power)} = <b>'
                '${jsRound((math.max(cur.attack, cur.magic) + math.max(q.attack, q.magic)) * du.power)}</b>'
                ' a TODOS los enemigos<br>'
                '${statusApplicationMarkup(du.status)}<br>'
                '4 MP cada uno · ${protoEsc(q.name)} pierde su próximo turno',
            reason:
                cur.mp >= 4 && q.mp >= 4 ? null : 'Hace falta 4 MP cada uno.',
            onSelect: cur.mp >= 4 && q.mp >= 4
                ? () => _send(DualCommand(q.id))
                : null,
          ),
    ];
    if (duos.isNotEmpty) {
      out.add(BattleCategoryEntry(BattleCategory.duos, duos,
          badge: hexSpan('#ffd166', '${duos.length}')));
    }

    if (ult != null) {
      final ready = cur.ult >= 100;
      out.add(BattleCategoryEntry(
          BattleCategory.ultimate,
          [
            BattleAction(
              id: 'ult',
              name: '★ ${ult.name}',
              value: ult.dealsDamage
                  ? _est(
                      cur,
                      (ult.kind == SkillKind.magical ? cur.magic : cur.attack) *
                          ult.power,
                      all: ult.allTargets)
                  : hexSpan('#74b9ff', 'apoyo'),
              cost:
                  hexSpan(ready ? '#ee70ad' : '#a29bfe', '${cur.ult.floor()}%'),
              dual: true,
              description: describeSkillMarkup(ult, cur, ultimate: true),
              reason: ready ? null : 'La barra ULT tiene que llegar al 100%.',
              onSelect:
                  ready ? () => _send(UltimateCommand(targetId: tg)) : null,
            ),
          ],
          badge:
              hexSpan(ready ? '#ee70ad' : '#a29bfe', '${cur.ult.floor()}%')));
    }

    out.add(BattleCategoryEntry(
        BattleCategory.items,
        [
          BattleAction(
            id: 'potion',
            name: 'Poción de vida',
            value: hexSpan('#7bed9f', '+45%'),
            cost: hexSpan('#9fb4ff', 'x${cur.potions}'),
            description:
                '<b>Poción de vida</b> ▸ elegir a quién<br>Cura 45% de '
                'la vida máx. del aliado que elijas (o a ti). Revive a un aliado '
                'caído y quita ${statusNameMarkup(StatusKind.burn)} y '
                '${statusNameMarkup(StatusKind.poison)}.',
            reason: cur.potions > 0 ? null : 'No te quedan.',
            onSelect: cur.potions > 0
                ? () => setState(() {
                      _potMode = BattleItem.potion;
                      _selected = 0;
                    })
                : null,
          ),
          BattleAction(
            id: 'ether',
            name: 'Poción de maná',
            value: hexSpan('#74b9ff', '+50%'),
            cost: hexSpan('#9fb4ff', 'x${cur.ethers}'),
            description:
                '<b>Poción de maná</b> ▸ elegir a quién<br>Restaura 50% '
                'del maná máx. del aliado que elijas (o a ti).',
            reason: cur.ethers > 0 ? null : 'No te quedan.',
            onSelect: cur.ethers > 0
                ? () => setState(() {
                      _potMode = BattleItem.ether;
                      _selected = 0;
                    })
                : null,
          ),
        ],
        badge: hexSpan('#9fb4ff', 'x${cur.potions + cur.ethers}')));

    out.add(BattleCategoryEntry(BattleCategory.defend, [
      BattleAction(
        id: 'defend',
        name: 'Defender',
        value: hexSpan('#74b9ff', '½ daño'),
        description: '<b>Defender</b><br>Recibes la mitad del daño hasta tu '
            'próximo turno, y tu siguiente turno llega 30% antes.',
        onSelect: () => _send(const DefendCommand()),
      ),
    ]));
    return out;
  }

  /// Las acciones que se ven: los aliados de la poción elegida, o la
  /// página de la categoría (con `Más ▸` / `← Volver` si pasa de 9).
  List<BattleAction> _visible(Combatant cur) {
    final b = widget.battle;
    final item = _potMode;
    if (item != null) {
      final pot = item == BattleItem.potion;
      return [
        for (final q in b.party)
          if (pot || q.alive)
            BattleAction(
              id: 'give-${q.id}',
              name: q.id == cur.id
                  ? 'Yo (${protoEsc(q.name)})'
                  : protoEsc(q.name),
              value: hexSpan(pot ? '#7bed9f' : '#74b9ff',
                  '+${pot ? jsRound(q.maxHp * 0.45) : jsRound(q.maxMp * 0.5)}${!q.alive ? ' ¡revive!' : ''}'),
              cost: hexSpan(
                  '#9fb4ff',
                  pot
                      ? '${q.hp}/${q.maxHp} HP'
                      : '${q.mp.floor()}/${q.maxMp} MP'),
              description: pot
                  ? '<b>Poción de vida</b> para ${protoEsc(q.name)}: '
                      '${q.hp}/${q.maxHp} HP → +${jsRound(q.maxHp * 0.45)}'
                  : '<b>Poción de maná</b> para ${protoEsc(q.name)}: '
                      '${q.mp.floor()}/${q.maxMp} MP → +${jsRound(q.maxMp * 0.5)}',
              onSelect: () => _send(ItemCommand(item, targetPlayerId: q.id)),
            ),
        BattleAction(
          id: 'back',
          name: '← Volver',
          description: 'Vuelve a los objetos (Esc).',
          onSelect: () => setState(() {
            _potMode = null;
            _selected = 0;
          }),
        ),
      ];
    }
    final entries = _entries(cur);
    final entry = entries.firstWhere((e) => e.category == _category,
        orElse: () => entries.first);
    // Más de 9 en una categoría: se pagina (las teclas llegan a 9).
    return battleMenuPage(
        const <BattleAction>[], entry.actions, const [], _page,
        more: (n) => BattleAction(
              id: 'more',
              name: 'Más ▸',
              value: hexSpan('#9fb4ff', '+$n'),
              description: 'Más acciones de esta categoría. Esc vuelve a la '
                  'primera página.',
              onSelect: () => setState(() {
                _page++;
                _selected = 0;
              }),
            ),
        back: BattleAction(
          id: 'page-back',
          name: '← Volver',
          description: 'Vuelve a la primera página (Esc).',
          onSelect: () => setState(() {
            _page = 0;
            _selected = 0;
          }),
        ));
  }

  /// Enemigo bajo el puntero (ficha del bestiario) y dónde está el
  /// puntero en la escena.
  String? _hoverId;
  Offset? _hoverAt;

  /// Enemigo con la ficha abierta (tests).
  String? get hoveredEnemy => _hoverId;

  void _hoverScene(Offset local) {
    final e = _foeAt(local);
    if (e?.id == _hoverId && (e == null || _hoverAt == local)) return;
    setState(() {
      _hoverId = e?.id;
      _hoverAt = e == null ? null : local;
    });
  }

  /// La ficha del enemigo bajo el mouse (o `null`).
  Widget? _hoverCard() {
    final best = widget.bestiary, at = _hoverAt;
    final hv = _foes.where((e) => e.id == _hoverId).firstOrNull;
    if (best == null || at == null || hv == null) return null;
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomSingleChildLayout(
          delegate: PointerCardLayout(at),
          child: EnemyInfoCard(
              enemy: hv, bestiary: best, level: widget.enemyLevel),
        ),
      ),
    );
  }

  /// Clic en la escena: elige al enemigo vivo bajo el puntero.
  void _tapScene(Offset local) {
    final e = _foeAt(local);
    if (e != null) setState(() => _target = e.id);
  }

  /// El enemigo vivo bajo [local] (coordenadas de la escena), o `null`.
  Combatant? _foeAt(Offset local) {
    final f = scene.frame;
    if (f == null) return null;
    final vp = SceneViewport(f.geometry.worldRect, scene.viewFor(f));
    if (!vp.area.contains(local)) return null;
    final w = vp.toWorld(local);
    final wx = w.dx, wy = w.dy;
    for (final e in _foes) {
      final p = f.layout.of(e.id);
      final type = widget.sprites.enemySpriteId(e.enemyType ?? '', e.phase);
      final img = widget.sprites?.enemy(type);
      final sc = (widget.sprites?.enemyScale(type) ?? 1) * (e.elite ? 1.45 : 1);
      final w = (img?.width ?? 16) * sc, h = (img?.height ?? 14) * sc;
      if ((wx - p.dx).abs() <= w / 2 + 4 &&
          wy >= p.dy - h - 4 &&
          wy <= p.dy + 4) {
        return e;
      }
    }
    return null;
  }

  /// El jugador de este dispositivo: [BattleView.localId]; sin él
  /// (tests, previsualización), el de turno si puede actuar o el primero.
  Combatant? get _me {
    final party = widget.battle.party;
    for (final p in party) {
      if (p.id == widget.localId) return p;
    }
    final cur = widget.battle.current;
    if (widget.localId == null &&
        widget.canAct &&
        cur != null &&
        cur.isPlayer) {
      return cur;
    }
    return party.isEmpty ? null : party.first;
  }

  /// Alto de la barra de batalla (ventana de comandos + grupo) para una
  /// pantalla de alto [h] y el texto agrandado [textFactor]
  /// (`RetroType.factorOf`): más alta con texto grande; la escena se
  /// achica (los sprites son chicos).
  static double barHeight(double h, [double textFactor = 1]) {
    final f = textFactor < 1 ? 1.0 : textFactor;
    return math
        .min(h * (0.42 + 0.08 * (f - 1)), h * 0.62)
        .clamp(math.min(260.0, h * 0.6), double.infinity);
  }

  /// Si hay un submenú abierto (el de pociones o una página del menú
  /// que no es la primera): `Esc` lo cierra en vez de abrir la pausa.
  bool get hasSubmenu => _potMode != null || _page > 0;

  @override
  Widget build(BuildContext context) {
    final b = widget.battle;
    scene.options = widget.sceneOptions;
    return ColoredBox(
      color: ProtoColors.bg,
      child: LayoutBuilder(builder: (context, cons) {
        final size = cons.biggest;
        final barH = barHeight(size.height, RetroType.factorOf(context));
        final me = _me;
        return Stack(
          children: [
            Column(
              children: [
                // La escena usa solo el alto que deja la barra: nunca
                // queda tapada.
                Expanded(child: _scene(b)),
                SizedBox(
                  height: barH,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        _margin, _margin, _margin, _margin),
                    child: _bar(b, me),
                  ),
                ),
              ],
            ),
            // Ficha del bestiario del enemigo bajo el mouse: sobre toda la
            // pantalla (la escena está arriba, mismas coordenadas), así una
            // ficha larga de jefe no se recorta.
            if (_hoverCard() case final card?) card,
            // La parte de pantalla de la ULT, encima también de la barra.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: BattleOverlayPainter(scene)),
              ),
            ),
            // El cartel final espera a que termine la cinemática.
            if (b.outcome != null)
              ListenableBuilder(
                listenable: scene,
                builder: (context, _) => scene.ult != null || scene.holding
                    ? const SizedBox.shrink()
                    : _EndOverlay(outcome: b.outcome!),
              ),
          ],
        );
      }),
    );
  }

  Widget _scene(BattleState b) {
    return LayoutBuilder(builder: (context, cons) {
      // Las etiquetas crecen con el texto y la ventana (accessibility.md).
      final g = SceneGeometry.fit(cons.biggest,
          textFactor: RetroType.factorOf(context));
      final sprites = widget.sprites;
      final layout = BattleLayout.compute(b, widget.arena, vw: g.virtualWidth,
          enemySize: (e) {
        final type = sprites.enemySpriteId(e.enemyType ?? '', e.phase);
        final img = sprites?.enemy(type);
        final sc = (sprites?.enemyScale(type) ?? 1) * (e.elite ? 1.45 : 1);
        return Size((img?.width ?? 16) * sc, (img?.height ?? 14) * sc);
      });
      scene.frame = SceneFrame(
        battle: b,
        geometry: g,
        layout: layout,
        arena: widget.arena,
        sprites: widget.sprites,
        localId: widget.localId,
        targetId: widget.canAct ? target : null,
        turnTimeLeft: widget.turnTimeLeft,
        turnLimit: widget.turnLimit,
      );
      scene.sync(
        battleId: widget.battleId,
        eventSeq: widget.eventSeq,
        events: widget.events,
        state: b,
        layout: layout,
      );
      final s = g.scale;
      return ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: MouseRegion(
                onHover: (d) => _hoverScene(d.localPosition),
                onExit: (_) => _hoverScene(const Offset(-1e6, -1e6)),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _tapScene(d.localPosition),
                  child: CustomPaint(painter: BattleScenePainter(scene)),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: (38 * s).roundToDouble(),
              width: (g.virtualWidth * s).roundToDouble(),
              height: (16 * s).roundToDouble(),
              child: _LogBand(
                battle: b,
                turnTimeLeft: widget.turnTimeLeft,
                localId: widget.localId,
                scale: s,
              ),
            ),
            // El objetivo: nombre, vida y quiebre (arriba a la izquierda).
            if (_foes.where((e) => e.id == target).firstOrNull case final tg?)
              Positioned(
                left: 8,
                top: (54 * s).roundToDouble() + 4,
                child: IgnorePointer(child: TargetBar(enemy: tg)),
              ),
          ],
        ),
      );
    });
  }

  /// La barra de abajo: la ventana de comandos (o de quién es el turno)
  /// y la barra del grupo.
  Widget _bar(BattleState b, Combatant? me) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _menu() ?? _waiting(b, me)),
        const SizedBox(height: _margin),
        BattlePartyBar(
          battle: b,
          localId: me?.id,
          sprites: widget.sprites,
          turnTimeLeft: widget.turnTimeLeft,
          points: me == null ? 0 : widget.pendingPoints[me.id] ?? 0,
        ),
      ],
    );
  }

  /// Fuera de mi turno: de quién es el turno y cuándo me toca.
  Widget _waiting(BattleState b, Combatant? me) {
    final cur = b.current;
    final String who;
    if (cur == null) {
      who = hexSpan('#7d8bc4', '…');
    } else if (cur.id == me?.id) {
      who = '<b>Tu turno</b>';
    } else if (cur.isPlayer) {
      who = '<b>Turno de ${protoEsc(cur.name)}</b>';
    } else {
      who = '<b style="color:#ff6b81">Turno de ${protoEsc(cur.name)}</b>';
    }
    var mine = '';
    if (me != null && cur?.id != me.id) {
      final i = predictTurns(b, 10).indexOf(me.id);
      if (!me.alive) {
        mine = hexSpan('#7d8bc4', 'Estás fuera de combate');
      } else if (i >= 0) {
        mine = hexSpan('#7d8bc4', 'Tu turno en $i');
      }
    }
    return BattleBarPanel(
      key: const ValueKey('battle-waiting'),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              bossMechanicRow(b),
              ProtoText(who,
                  style: RetroType.style(RetroType.title),
                  textAlign: TextAlign.center),
              if (mine.isNotEmpty) ...[
                const SizedBox(height: 8),
                ProtoText(mine, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// La ventana de comandos: solo en el turno del jugador local (el
  /// prototipo la oculta en cualquier otro momento).
  Widget? _menu() {
    final cur = widget.battle.current;
    if (!widget.canAct || cur == null || !cur.isPlayer) return null;
    final entries = _entries(cur);
    if (!entries.any((e) => e.category == _category)) {
      _category = entries.first.category;
    }
    final visible = _visible(cur);
    if (_selected >= visible.length) _selected = 0;
    final tg = _foes.where((e) => e.id == target).firstOrNull;
    final String? header = switch (_potMode) {
      BattleItem.potion => '<b>¿A quién le das la Poción de vida (+45% vida, '
          'revive, quita ${statusNameMarkup(StatusKind.burn)} y '
          '${statusNameMarkup(StatusKind.poison)})?</b>',
      BattleItem.ether => '<b>¿A quién le das la Poción de maná (+50% '
          'maná)?</b>',
      _ => null,
    };
    final targetLine = tg == null
        ? ''
        : 'Objetivo: <b style="color:#ff6b81">${protoEsc(tg.name)}</b> '
            '<span class="k">${tg.hp}/${tg.maxHp} HP</span>'
            '${breakInfoMarkup(tg)}'
            // Familia y debilidades, solo si ya se lo mató (bestiary.md).
            '${widget.bestiary?.knows(tg.enemyType) ?? false ? ' · ${familyShortMarkup(tg.enemyType)}' : ''}';
    return BattleCommandWindow(
      actorName: '¡Tu turno! ${cur.name}',
      categories: entries,
      category: _category,
      visible: visible,
      selected: _selected,
      header: header,
      target: targetLine,
      resources:
          '<span style="color:#74b9ff">MP ${cur.mp.floor()}/${cur.maxMp}</span>'
          ' · <span style="color:${cur.ult >= 100 ? '#ee70ad' : '#a29bfe'}">'
          'ULT ${cur.ult.floor()}%</span>',
      extra: bossMechanicRow(widget.battle),
      onCategory: selectCategory,
      onHoverAction: (i) {
        if (i != _selected) setState(() => _selected = i);
      },
    );
  }
}

// ----------------------------------------------------------------------
// Piezas
// ----------------------------------------------------------------------

/// Banda del log (`txt(B.log, ...)` en blanco) y `drawTurnLabel` (caja
/// negra a la derecha con `TÚ 25s`, dorado o `#ff6b81` con ≤ 10 s).
class _LogBand extends StatelessWidget {
  const _LogBand({
    required this.battle,
    required this.turnTimeLeft,
    required this.localId,
    required this.scale,
  });

  final BattleState battle;
  final double? turnTimeLeft;
  final String? localId;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final cur = battle.current;
    final left = turnTimeLeft;
    final showTimer = left != null && cur != null && cur.isPlayer;
    final who = cur == null
        ? ''
        : cur.id == localId
            ? 'TÚ'
            : (cur.name.length > 6 ? cur.name.substring(0, 6) : cur.name);
    // La banda tiene el alto de la escena (16 px virtuales): su texto no
    // crece con el ajuste (sigue nítido); el log completo está en la
    // ventana de comandos y el detalle en las tarjetas.
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: RetroType.fixedScaler(context)),
      child: LayoutBuilder(builder: (context, box) {
        final log = retroText(battle.log);
        // La caja del reloj crece si el texto no entra (tamaño del texto).
        // Press Start al múltiplo de 8 que entra en la banda (el reloj y,
        // si cabe en una línea, el log).
        final bandPx = math.max(
            8.0, ((box.maxHeight - 2) / 1.25 / 8).floor() * 8.0);
        final timerPx = math.max(RetroType.em(context, 1), bandPx);
        final timerW = math.max(82 * scale, 7 * timerPx + 8);
        final labelW = showTimer ? timerW + 2 * scale : 0.0;
        // Press Start al múltiplo de 8 más grande que entra en el alto de
        // la banda (16 px virtuales × la escala de la escena: 16 a
        // 1280×720, 24 a 1920×1080) y en una línea; si no entra, el texto
        // de lectura.
        final room = box.maxWidth - labelW - 16;
        var px = bandPx;
        while (px >= 16 && px * log.length > room) {
          px -= 8;
        }
        final big = px >= 16 && log.length <= 52;
        return Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: Text(
                    log,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    textScaler: big ? TextScaler.noScaling : null,
                    style: TextStyle(
                        fontFamilyFallback: RetroType.bodyFallback,
                        fontFamily: big
                            ? RetroType.pixelFamily
                            : RetroType.familyFor(RetroType.small),
                        fontSize: big ? px : RetroType.small,
                        height: 1.25,
                        color: ProtoColors.white),
                  ),
                ),
              ),
            ),
            if (showTimer)
              Container(
                width: timerW,
                margin: EdgeInsets.only(
                    right: 2 * scale, top: scale, bottom: 2 * scale),
                color: const Color(0xFF000000),
                alignment: Alignment.center,
                child: Text(
                  retroText('$who ${left.ceil().clamp(0, 99)}s'),
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: RetroType.pixelFamily,
                    fontSize: timerPx,
                    color: left <= 10 ? ProtoColors.red : ProtoColors.gold,
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _EndOverlay extends StatelessWidget {
  const _EndOverlay({required this.outcome});

  final BattleOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ColoredBox(
      color: ProtoColors.bg.withValues(alpha: 0.35),
      child: Center(
        child: RetroPanel(
          selected: true,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                outcome.victory ? '¡VICTORIA!' : 'DERROTA',
                style: text.displayLarge?.copyWith(
                  color: outcome.victory ? ProtoColors.gold : ProtoColors.red,
                  shadows: const [
                    Shadow(
                        color: ProtoColors.titleShadow, offset: Offset(3, 3)),
                  ],
                ),
              ),
              if (outcome.victory) ...[
                const SizedBox(height: 24),
                Text(
                    retroText(
                        '+${outcome.xp} XP · +₵${outcome.credits} para cada uno'),
                    style: const TextStyle(color: ProtoColors.gold)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
