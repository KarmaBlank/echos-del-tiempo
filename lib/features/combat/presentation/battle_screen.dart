import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/design/ds_layout_host.dart';
import '../../../core/layout/layout_catalog.dart';
import '../../../core/layout/layout_doc.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_panel.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/data/classes_catalog.dart';
import '../../../game_engine/data/elements_catalog.dart' show elementOfDual;
import '../../../game_engine/data/enemy_families.dart'
    show ComboRulesDef, EnemyFamily;
import '../../../game_engine/data/skills_catalog.dart';
import '../../../game_engine/data/weapon_duals_catalog.dart';
import '../../../game_engine/models/battle_command.dart';
import '../../../game_engine/models/battle_event.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/bestiary.dart';
import '../../../game_engine/models/skill.dart';
import '../../../game_engine/models/status.dart';
import '../../../game_engine/rules/battle_engine.dart'
    show BattleEngine, ultReady, ultimateOf;
import '../../../game_engine/rules/dual_rules.dart';
import '../../../game_engine/rules/family_rules.dart'
    show healCanTargetFoe, healOnFoeDamage, isTargetableHeal, skillHealAmount;
import '../../../game_engine/rules/js_math.dart';
import '../../../game_engine/rules/skill_requirements.dart';
import '../../bestiary/domain/bestiary_text.dart';
import '../../bestiary/presentation/enemy_info_card.dart';
import '../domain/skill_text.dart';
import '../domain/turn_order.dart';
import 'enemy_live_info.dart';
import 'battle_bar_layout.dart';
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
    this.companions = const {},
    this.auto = const {},
    this.onAuto,
    this.actionGate,
    this.layout,
    this.layoutHooks,
    this.layoutCatalog,
  });

  /// Layout de la barra de abajo y perillas de la escena (Editor →
  /// LAYOUT, pantalla `battle`); `null` = el del [layoutCatalog].
  final LayoutDoc? layout;
  final DsLayoutHooks? layoutHooks;

  /// `null` = `LayoutCatalog.instance`.
  final LayoutCatalog? layoutCatalog;

  /// Compañeros de la party de este dispositivo (docs/specs/
  /// solo_party.md § 4): su turno abre la ventana de comandos (sin AUTO)
  /// y su tarjeta muestra la ULT y el botón AUTO.
  final Set<String> companions;

  /// Compañeros con AUTO prendido.
  final Set<String> auto;

  /// Prende / apaga el AUTO de un compañero; `null` = sin botón.
  final void Function(String id, bool on)? onAuto;

  /// TUTORIAL: por qué la acción `id` del menú está desactivada (`null` =
  /// habilitada). `null` = sin tutorial.
  final String? Function(String actionId)? actionGate;

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

  /// Submenú de una cura de un blanco con no muertos a la vista
  /// (bestiary.md § 1.4.1): elegir aliado o enemigo.
  SkillDef? _healMode;

  /// Algún submenú de "¿a quién?" abierto.
  bool get _picking => _potMode != null || _healMode != null;

  /// Hay un aliado caído (el Éter solo sirve así).
  bool get _anyDown =>
      widget.battle.party.any((q) => !q.alive && !q.isSummon);

  /// Categoría elegida en la ventana de comandos.
  BattleCategory _category = BattleCategory.weapon;

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

  /// Enemigos que afectaría la habilidad elegida (cursor o mouse): todos
  /// si es a TODOS, el objetivo si es a 1; vacío si no es una habilidad
  /// contra enemigos. La escena los marca.
  Set<String> get highlightedTargets {
    final cur = widget.battle.current;
    if (!widget.canAct || cur == null || !cur.isPlayer) return const {};
    if (_category != BattleCategory.skills &&
        _category != BattleCategory.weapon) {
      return const {};
    }
    final v = _visible(cur);
    if (_selected < 0 || _selected >= v.length) return const {};
    final id = v[_selected].id;
    if (_healMode != null) {
      return id.startsWith('heal-foe-') ? {id.substring(9)} : const {};
    }
    if (!id.startsWith('skill-')) return const {};
    final sk = kSkills[id.substring(6)];
    if (sk == null) return const {};
    return switch (skillReach(sk)) {
      SkillReach.allFoes => {for (final e in _foes) e.id},
      SkillReach.oneFoe => {if (target case final t?) t},
      _ => const {},
    };
  }

  late final BattleSceneController scene =
      BattleSceneController(random: widget.random);
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  /// Margen y separación de la barra de abajo (px de pantalla).
  static const _margin = 6.0;

  /// Líneas anteriores del log (la más vieja primero) para el REGISTRO
  /// EXTENDIDO (accessibility.md § 9.7); cada una vence sola.
  final _logHistory = <String>[];
  final _logTimers = <Timer>[];

  /// Líneas anteriores del log que se ven (tests).
  List<String> get logHistory => List.unmodifiable(_logHistory);

  void _clearLogHistory() {
    for (final t in _logTimers) {
      t.cancel();
    }
    _logTimers.clear();
    _logHistory.clear();
  }

  void _pushLog(String line) {
    if (line.isEmpty) return;
    _logHistory.add(line);
    late final Timer timer;
    timer = Timer(
        Duration(milliseconds: (kBattleLogHistoryS * 1000).round()), () {
      _logTimers.remove(timer);
      if (!mounted) return;
      setState(() => _logHistory.remove(line));
    });
    _logTimers.add(timer);
    while (_logHistory.length > kBattleLogLines - 1) {
      _logHistory.removeAt(0);
      _logTimers.removeAt(0).cancel();
    }
  }

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
    _clearLogHistory();
    _ticker.dispose();
    scene.dispose();
    super.dispose();
  }

  void _resetMenu() {
    _potMode = null;
    _healMode = null;
    _category = BattleCategory.weapon;
    _selected = 0;
    _page = 0;
  }

  @override
  void didUpdateWidget(BattleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // REGISTRO EXTENDIDO: la línea que se reemplaza pasa al historial.
    if (oldWidget.battleId != widget.battleId ||
        !widget.sceneOptions.extendedLog) {
      _clearLogHistory();
    } else if (oldWidget.battle.log != widget.battle.log) {
      _pushLog(oldWidget.battle.log);
    }
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
    if (!_picking && c == _category) return;
    setState(() {
      _potMode = null;
      _healMode = null;
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
  /// confirman, Q/Tab cambian de objetivo, P va a PASAR (otra P: pasa el
  /// turno) y Esc sale del submenú (o vuelve a la primera página).
  /// Devuelve si la tecla se usó.
  bool handleKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.keyQ || key == LogicalKeyboardKey.tab) {
      cycleTarget();
      return true;
    }
    if (key == LogicalKeyboardKey.escape && _picking) {
      setState(() {
        _potMode = null;
        _healMode = null;
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
    // P: va a PASAR; con PASAR ya elegido, pasa el turno (dos toques: no
    // se pierde un turno por una tecla suelta).
    if (key == LogicalKeyboardKey.keyP) {
      if (acting) {
        if (!_picking && _category == BattleCategory.pass) {
          _send(const PassCommand());
        } else {
          selectCategory(BattleCategory.pass);
        }
      }
      return true;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      if (acting && !_picking) {
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
      'Daño físico ATQ ${cur.attack}:${_est(cur, cur.attack, crit: false)}'
      '<br>${critLineMarkup(cur, cur.attack)}'
      '${cur.stunOnAttackChance > 0 ? '<br>${hexSpan('#ffeaa7', '${jsRound(cur.stunOnAttackChance * 100)}% de aturdir')}' : ''}'
      '${cur.branch == 'creyente' ? '<br>${hexSpan('#7bed9f', '25%: cura 2% al grupo')}' : cur.branch == 'inherente' ? '<br>${hexSpan('#fff3b0', '25%: aplica Sagrado')}' : ''}';

  /// Una fila de DÚOS: [cur] con [q] haciendo el dúo [id]. Id estable:
  /// `duo-<aliado>` el de clase (como en v0.8.2) y `duo-<aliado>-<id>`
  /// los de armas.
  BattleAction _duoAction(Combatant cur, Combatant q, String id, DualDef du) {
    const mp = BattleEngine.dualMpCost;
    final ok = cur.mp >= mp && q.mp >= mp;
    final sum = (math.max(cur.attack, cur.magic) + math.max(q.attack, q.magic)) *
        du.power;
    final el = elementOfDual(du);
    final w = du.weapons;
    final pair = w == null
        ? '${protoEsc(kClasses[cur.classId]?.name ?? cur.classId ?? '?')} + '
            '${protoEsc(kClasses[q.classId]?.name ?? q.classId ?? '?')}'
        : '${protoEsc(cur.weaponType ?? '?')} + ${protoEsc(q.weaponType ?? '?')}';
    return BattleAction(
      id: w == null ? 'duo-${q.id}' : 'duo-${q.id}-$id',
      name: '★ ${du.name} (+${protoEsc(q.name)})',
      value: '${hexSpan(w == null ? '#9fb4ff' : '#ffd166', '[$pair]')} '
          '${_est(cur, sum, all: true, crit: false)} ${_stTag(du.status)}',
      // Mismo camino que HABILIDADES: DsCost, alcance y resumen.
      mpCost: mp,
      reach: SkillReach.allFoes,
      summary: [
        hexSpan(SkillReach.allFoes.hex, 'A TODOS'),
        el.label,
        hexSpan('#ffd166', '${jsRound(sum)} c/u'),
        _stTag(du.status),
        '$mp MP cada uno',
      ].join(' · '),
      dual: true,
      description: '<b>★ ${du.name}</b> <span class="k">dúo '
          '${w == null ? 'de clase' : 'de armas'}: ${protoEsc(cur.name)} + '
          '${protoEsc(q.name)}</span><br>'
          '${w == null ? 'Clases' : 'Armas'}: $pair · elemento '
          '${el.label}<br>'
          '(máx(ATQ, MAG) tuyo + suyo) × ${fm(du.power)} = <b>'
          '${jsRound(sum)}</b> a TODOS los enemigos<br>'
          '${critLineMarkup(cur, sum, all: true)}<br>'
          '${statusApplicationMarkup(du.status)}<br>'
          '$mp MP cada uno · ${protoEsc(q.name)} pierde su próximo turno',
      reason: ok ? null : 'Hace falta $mp MP cada uno.',
      onSelect: ok
          ? () => _send(DualCommand(q.id, dualId: w == null ? null : id))
          : null,
    );
  }

  /// Una fila de HABILIDADES: costo en MP y Pulso, Instante, y el motivo
  /// si falta algo ([missing]).
  BattleAction _skillAction(
      SkillDef sk, Combatant cur, String? tg, List<String> missing,
      {String? separatorBefore}) {
    final ok = missing.isEmpty;
    // Instante: ya encadenaste una en este turno, esta lo termina.
    final instant = sk.instant && !cur.chained;
    final lines = ok
        ? const <String>[]
        : SkillRequirements.missingLines(
            sk, cur, _foes.where((e) => e.id == tg).firstOrNull,
            foes: _foes);
    // Condición especial (no el MP/Pulso que ya se ve en rojo): tooltip.
    final special = lines.where((l) => l.startsWith('Necesita')).toList();
    return BattleAction(
      disabledHint: special.isEmpty ? null : special.join('\n'),
      id: 'skill-${sk.id}',
      name: '${sk.name}${sk.delay > 0 ? ' ⏳' : ''}',
      // Fila: etiquetas (INSTANTE, alcance) y costos del sistema de
      // diseño; la cifra va en el resumen del detalle.
      value: _skillInfo(sk, cur, crit: false).trim(),
      instant: instant,
      reach: skillReach(sk),
      mpCost: sk.mp > 0 || sk.pulse == 0 ? sk.mp : null,
      pulseCost: sk.pulse > 0 ? sk.pulse : null,
      summary: skillSummaryMarkup(sk, cur),
      description: describeSkillMarkup(sk, cur),
      // Una línea roja por condición que falta (arriba del detalle).
      reason: ok ? null : lines.join('\n'),
      separatorBefore: separatorBefore,
      // Precondición (objetivo Fisurado, stacks, vida baja…) cumplida.
      conditionReady: ok && sk.requires.isNotEmpty,
      onSelect: !ok
          ? null
          : isTargetableHeal(sk)
              // Cura: con no muertos a la vista se elige a quién; si no,
              // va como siempre (al más herido o al grupo).
              ? () => _foes.any((e) => healCanTargetFoe(sk, e))
                  ? setState(() {
                      _healMode = sk;
                      _selected = 0;
                    })
                  : _send(SkillCommand(sk.id))
              : () => _send(SkillCommand(sk.id, targetId: tg)),
    );
  }

  /// Filas del submenú de la cura [sk]: el más herido (o el grupo), cada
  /// aliado vivo (si es de un blanco) y cada enemigo al que la cura daña (con el daño previsto).
  List<BattleAction> _healTargets(SkillDef sk, Combatant cur) {
    final b = widget.battle;
    final a = skillHealAmount(cur, sk);
    final mult = const ComboRulesDef().healFoeMult;
    return [
      BattleAction(
        id: 'heal-lowest',
        name: sk.lowestAlly ? 'Al más herido' : 'Al grupo',
        value: hexSpan('#7bed9f', '+$a${sk.lowestAlly ? '' : ' c/u'}'),
        description: sk.lowestAlly
            ? '${protoEsc(sk.name)} al aliado con menos vida: +$a HP'
            : '${protoEsc(sk.name)} a cada aliado: +$a HP',
        onSelect: () => _send(SkillCommand(sk.id)),
      ),
      for (final q in b.party)
        if (q.alive && sk.lowestAlly)
          BattleAction(
            id: 'heal-ally-${q.id}',
            name: q.id == cur.id
                ? 'Yo (${protoEsc(q.name)})'
                : protoEsc(q.name),
            value: hexSpan('#7bed9f', '+$a'),
            cost: hexSpan('#9fb4ff', '${q.hp}/${q.maxHp} HP'),
            description: '${protoEsc(sk.name)} para ${protoEsc(q.name)}: '
                '${q.hp}/${q.maxHp} HP → +$a',
            onSelect: () => _send(SkillCommand(sk.id, targetId: q.id)),
          ),
      for (final e in _foes)
        if (healCanTargetFoe(sk, e))
          BattleAction(
            id: 'heal-foe-${e.id}',
            name: protoEsc(e.name),
            value: hexSpan('#ff6b81',
                '−${healOnFoeDamage(a, e, mult: mult)}'),
            cost: hexSpan('#9fb4ff', '${e.hp}/${e.maxHp} HP'),
            description: '${protoEsc(sk.name)} contra ${protoEsc(e.name)}: '
                'Daño a no muertos: ${healOnFoeDamage(a, e, mult: mult)} '
                '(Sagrado)',
            onSelect: () => _send(SkillCommand(sk.id, targetId: e.id)),
          ),
      BattleAction(
        id: 'back',
        name: '← Volver',
        description: 'Vuelve a las habilidades (Esc).',
        onSelect: () => setState(() {
          _healMode = null;
          _selected = 0;
        }),
      ),
    ];
  }

  /// Defender en ARMA (battle_attack_menu.md § 6): ½ daño, próximo turno
  /// × 0.7, +2 Pulso (+1 si ya defendió el turno anterior) y carga de ULT.
  BattleAction _defendAction(Combatant cur) {
    final pulse = cur.guardStreak
        ? BattleEngine.defendPulseRepeat
        : BattleEngine.defendPulse;
    final ult = BattleEngine.defendUlt.round();
    final hit = BattleEngine.defendHitUlt.round();
    return BattleAction(
      id: 'defend',
      name: 'Defender',
      value: hexSpan('#74b9ff', '½ daño'),
      cost: hexSpan(kPulseHex, '+$pulse Pulso'),
      summary: '${hexSpan('#74b9ff', '½ daño')} · '
          '${hexSpan(kPulseHex, '+$pulse Pulso')} · '
          '${hexSpan('#ee70ad', '+$ult ULT')}',
      description: '<b>Defender</b><br>Recibís la mitad del daño hasta tu '
          'próximo turno, y tu siguiente turno llega 30% antes.<br>'
          '+$pulse de Pulso${cur.guardStreak ? ' (defendiste el turno '
              'anterior: rinde menos)' : ' (+${BattleEngine.defendPulseRepeat}'
              ' si repetís)'}. Carga +$ult de ULT, y +$hit más si te '
          'golpean defendiendo.<br><span class="k">El tiempo agotado '
          'defiende solo, sin este premio.</span>',
      onSelect: () => _send(const DefendCommand()),
    );
  }

  /// Las categorías del menú de [cur] con sus acciones (las vacías no
  /// están). Cada acción con su id estable.
  List<BattleCategoryEntry> _entries(Combatant cur) {
    final b = widget.battle;
    final tg = target;
    final ult = ultimateOf(cur);
    final allies = b.party.where((q) => q.alive && q.id != cur.id).toList();
    final out = <BattleCategoryEntry>[];
    // MP, Pulso y precondiciones (combo_balance.md § 5.2): si falta algo,
    // el botón sale desactivado con "Necesita: …".
    final foes = _foes;
    final tgC = foes.where((e) => e.id == tg).firstOrNull;
    final defs = [
      for (final id in cur.skillIds)
        if (kSkills[id] case final sk?) sk,
    ];
    final instants = defs.where((s) => s.instant).toList();

    out.add(BattleCategoryEntry(BattleCategory.weapon, [
      BattleAction(
        id: 'attack',
        name: 'Atacar',
        value: _est(cur, cur.attack, crit: false),
        description: _attackDesc(cur),
        onSelect: () => _send(AttackCommand(targetId: tg)),
      ),
      // Defender con valor (battle_attack_menu.md § 6): fila 2 de ARMA,
      // así por teclado es `2` (una tecla al empezar el turno).
      _defendAction(cur),
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
      // Las Instante viven en ARMA (battle_attack_menu.md § 6: "un
      // instante es más un ataque que una habilidad"), sin separador
      // (v0.20.6: ya llevan su etiqueta INSTANTE); el panel de la derecha
      // explica la regla (battle_presentation.md).
      for (final sk in instants)
        _skillAction(
            sk, cur, tg, SkillRequirements.missing(sk, cur, tgC, foes: foes)),
    ]));

    // HABILIDADES: las que terminan el turno (las Instante están en ARMA).
    final skills = [
      for (final sk in defs.where((s) => !s.instant))
        _skillAction(
            sk, cur, tg, SkillRequirements.missing(sk, cur, tgC, foes: foes)),
    ];
    if (skills.isNotEmpty) {
      out.add(BattleCategoryEntry(BattleCategory.skills, skills,
          badge: hexSpan('#9fb4ff', '${skills.length}')));
    }

    // Dúos (v0.8.3, combat.md § "Dúos"): por cada aliado vivo, el de
    // clase (si el par tiene) y los de armas de sus tipos de arma.
    final duos = [
      for (final q in allies)
        for (final id in dualIdsFor(kAllDuals, cur, q))
          if (kAllDuals[id] case final du?) _duoAction(cur, q, id, du),
    ];
    if (duos.isNotEmpty) {
      out.add(BattleCategoryEntry(BattleCategory.duos, duos,
          badge: hexSpan('#ffd166', '${duos.length}')));
    }

    if (ult != null) {
      final ready = cur.ult >= kUltCost;
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
              ultCharge: cur.ult.floor(),
              reach: skillReach(ult),
              summary: skillSummaryMarkup(ult, cur),
              dual: true,
              description: describeSkillMarkup(ult, cur, ultimate: true),
              reason: ready
                  ? null
                  : 'La barra ULT tiene que estar llena.',
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
            count: cur.potions,
            reach: SkillReach.ally,
            summary: '${hexSpan(SkillReach.ally.hex, 'A un aliado')} · '
                '${hexSpan('#7bed9f', '+45% HP')} · revive',
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
            count: cur.ethers,
            reach: SkillReach.ally,
            summary: '${hexSpan(SkillReach.ally.hex, 'A un aliado')} · '
                '${hexSpan('#74b9ff', '+50% MP')}',
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
          // Éter (loot.md § 17.6): solo sobre un aliado caído.
          if (cur.aethers > 0)
            BattleAction(
              id: 'aether',
              name: 'Éter',
              value: hexSpan('#ffd166', '100%'),
              count: cur.aethers,
              reach: SkillReach.ally,
              summary: '${hexSpan(SkillReach.ally.hex, 'A un caído')} · '
                  '${hexSpan('#ffd166', 'revive con toda la vida')}',
              description: 'Éter ▸ elegir a quién<br>Revive a un aliado '
                  'caído con el 100% de su vida máx. y le quita '
                  '${statusNameMarkup(StatusKind.burn)} y '
                  '${statusNameMarkup(StatusKind.poison)}.',
              reason: _anyDown ? null : 'No hay aliados caídos.',
              onSelect: _anyDown
                  ? () => setState(() {
                        _potMode = BattleItem.aether;
                        _selected = 0;
                      })
                  : null,
            ),
        ],
        badge: hexSpan(
            '#9fb4ff', 'x${cur.potions + cur.ethers + cur.aethers}')));

    // Pasar turno (v0.8.3, combat.md § "Pasar turno"). AUTO nunca pasa.
    // Después de una Instante, la misma tecla termina el turno sin el
    // adelanto (combat.md § "Pulso e Instante").
    out.add(BattleCategoryEntry(BattleCategory.pass, [
      if (cur.chained)
        BattleAction(
          id: 'pass',
          name: 'Terminar turno',
          cost: hexSpan('#9fb4ff', 'próximo ×1'),
          description: '<b>Terminar turno</b> <span class="k">P</span><br>'
              'Ya usaste una habilidad Instante: terminás el turno sin la '
              'acción que te queda. El próximo turno llega como siempre.',
          onSelect: () => _send(const PassCommand()),
        )
      else
        BattleAction(
          id: 'pass',
          name: 'Pasar turno',
          cost: hexSpan('#9fb4ff', 'próximo ×½'),
          description: '<b>Pasar turno</b> <span class="k">P</span><br>'
              'Terminás el turno sin actuar; tu próximo turno llega antes '
              '(a la mitad del intervalo). Sin carga de ULT ni defensa: '
              'sirve para esperar la reacción o el cebado de un aliado.',
          onSelect: () => _send(const PassCommand()),
        ),
    ]));
    // TUTORIAL (combat_tutorial.md § 4.1): solo lo del paso, el resto
    // desactivado con el motivo.
    final gate = widget.actionGate;
    if (gate == null) return out;
    return [
      for (final e in out)
        BattleCategoryEntry(
            e.category,
            [
              for (final a in e.actions)
                if (gate(a.id) case final why?)
                  BattleAction(
                    id: a.id,
                    name: a.name,
                    value: a.value,
                    cost: a.cost,
                    instant: a.instant,
                    reach: a.reach,
                    mpCost: a.mpCost,
                    pulseCost: a.pulseCost,
                    ultCharge: a.ultCharge,
                    count: a.count,
                    summary: a.summary,
                    description: a.description,
                    dual: a.dual,
                    reason: why,
                    disabledHint: why,
                    onSelect: null,
                  )
                else
                  a,
            ],
            badge: e.badge),
    ];
  }

  /// Las acciones que se ven: los aliados de la poción elegida, o la
  /// página de la categoría (con `Más ▸` / `← Volver` si pasa de 9).
  List<BattleAction> _visible(Combatant cur) {
    final b = widget.battle;
    final item = _potMode;
    if (_healMode case final sk?) return _healTargets(sk, cur);
    if (item == BattleItem.aether) {
      return [
        for (final q in b.party)
          if (!q.alive && !q.isSummon)
            BattleAction(
              id: 'give-${q.id}',
              name: protoEsc(q.name),
              value: hexSpan('#ffd166', '+${q.maxHp} ¡revive!'),
              cost: hexSpan('#9fb4ff', '0/${q.maxHp} HP'),
              description: 'Éter para ${protoEsc(q.name)}: revive con '
                  '${q.maxHp}/${q.maxHp} HP',
              onSelect: () =>
                  _send(ItemCommand(BattleItem.aether, targetPlayerId: q.id)),
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

  /// Actor de la franja de turnos bajo el mouse (sin ficha).
  String? _hoverSlot;

  /// Enemigo con la ficha abierta (tests).
  String? get hoveredEnemy => _hoverId;

  /// Actor señalado con el mouse, en la arena o en la franja de turnos:
  /// se resalta en las dos (battle_presentation.md § "Identificador de
  /// repetidos").
  String? get hoveredId => _hoverId ?? _hoverSlot ?? _hoverAlly;

  /// Aliado señalado con el mouse en la lista del grupo o en la arena.
  String? _hoverAlly;

  /// Grupo compacto (battle_presentation.md § "Grupo compacto"): sin
  /// compañeros propios (`FeatureFlags.soloParty` apagado o grupo de uno
  /// solo) abajo va solo la tarjeta propia y los demás, en la lista de la
  /// derecha de la arena.
  bool get compactParty => widget.companions.isEmpty;

  void _hoverRow(String? id) {
    if (id == _hoverAlly) return;
    setState(() => _hoverAlly = id);
  }

  void _hoverScene(Offset local) {
    final slot = _slotAt(local);
    final e = slot == null ? _foeAt(local) : null;
    final ally = slot == null && e == null ? _allyAt(local) : null;
    if (slot == _hoverSlot &&
        e?.id == _hoverId &&
        ally == _hoverAlly &&
        (e == null || _hoverAt == local)) {
      return;
    }
    setState(() {
      _hoverSlot = slot;
      _hoverAlly = ally;
      _hoverId = e?.id;
      _hoverAt = e == null ? null : local;
    });
  }

  /// Id del actor cuyo ícono de la franja de turnos está bajo [local].
  String? _slotAt(Offset local) {
    final f = scene.frame;
    if (f == null) return null;
    final v = local / f.geometry.scale;
    for (final s in BattleScenePainter.timelineSlots(
        f.battle, f.geometry.virtualWidth.toDouble(), f.geometry)) {
      if (s.rect.inflate(1).contains(v)) return s.id;
    }
    return null;
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
              enemy: hv,
              bestiary: best,
              level: widget.enemyLevel,
              // Debilidades gratis (battle_attack_menu.md § 6): si la
              // ficha todavía dice "???", las muestra el estado en vivo.
              live: EnemyLiveInfo(
                  enemy: hv,
                  affinities:
                      !hv.practice && !best.knows(hv.enemyType))),
        ),
      ),
    );
  }

  /// Clic en la escena: elige al enemigo vivo bajo el puntero.
  void _tapScene(Offset local) {
    // Un toque durante la cinemática de un dúo la saltea (v0.8.3).
    if (scene.skipDuo()) return;
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

  /// El aliado bajo [local] (coordenadas de la escena), o `null`.
  String? _allyAt(Offset local) {
    final f = scene.frame;
    if (f == null) return null;
    final vp = SceneViewport(f.geometry.worldRect, scene.viewFor(f));
    if (!vp.area.contains(local)) return null;
    final w = vp.toWorld(local);
    for (final p in f.battle.party) {
      if (f.layout.boxOf(p.id).inflate(2).contains(w)) return p.id;
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
  ///
  /// Con más de `BattlePartyBar.slotCount` en [partySize] (dos filas de
  /// tarjetas con ULT y AUTO de los compañeros, v0.13.1): + 9 % del
  /// alto, hasta 68 %.
  static double barHeight(double h,
      [double textFactor = 1, int partySize = 1, bool compact = false]) {
    final f = textFactor < 1 ? 1.0 : textFactor;
    final big = partySize > BattlePartyBar.slotCount;
    // Grupo compacto (v0.20.6): la tarjeta va a la izquierda del menú, en
    // la misma fila; sin la fila de abajo, la barra baja a 30 % (34 % con
    // texto grande) y la escena gana ese alto.
    final base = compact ? (f <= 1 ? 0.30 : 0.34) : 0.42;
    return math
        .min(h * (base + 0.08 * (f - 1) + (big ? 0.09 : 0)),
            h * (big ? 0.68 : 0.62))
        .clamp(math.min(260.0, h * 0.6), double.infinity);
  }

  /// Si hay un submenú abierto (el de pociones o una página del menú
  /// que no es la primera): `Esc` lo cierra en vez de abrir la pausa.
  bool get hasSubmenu => _picking || _page > 0;

  @override
  Widget build(BuildContext context) {
    scene.options = widget.sceneOptions;
    if (widget.layout == null) {
      // Recarga en caliente del layout y las perillas (Editor → LAYOUT).
      return ListenableBuilder(
          listenable: widget.layoutCatalog ?? LayoutCatalog.instance,
          builder: (context, _) => _body(context));
    }
    return _body(context);
  }

  /// El layout de la batalla vigente (barra y perillas).
  LayoutDoc get _layoutDoc =>
      widget.layout ??
      (widget.layoutCatalog ?? LayoutCatalog.instance)
          .docFor(BattleBarLayout.spec);

  Widget _body(BuildContext context) {
    final b = widget.battle;
    return ColoredBox(
      color: ProtoColors.bg,
      child: LayoutBuilder(builder: (context, cons) {
        final size = cons.biggest;
        final barH = barHeight(size.height, RetroType.factorOf(context),
            compactParty ? 1 : b.party.length, compactParty);
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
      final sprites = widget.sprites;
      Size enemySize(Combatant e) {
        final type = sprites.enemySpriteId(e.enemyType ?? '', e.phase);
        final img = sprites?.enemy(type);
        final sc = (sprites?.enemyScale(type) ?? 1) * (e.elite ? 1.45 : 1);
        return Size((img?.width ?? 16) * sc, (img?.height ?? 14) * sc);
      }

      BattleLayout layoutFor(SceneGeometry g) => BattleLayout.compute(
          b, widget.arena,
          vw: g.virtualWidth, enemySize: enemySize);
      // Perillas de Editor → LAYOUT (battle_presentation.md § "Cámara y
      // encuadre", § "Textos flotantes").
      final doc = _layoutDoc;
      final zoomOut = BattleBarLayout.spec
          .param(doc, BattleBarLayout.cameraZoomOut)
          .round();
      final floatMargin =
          BattleBarLayout.spec.param(doc, BattleBarLayout.floatTopMargin);
      // Franja adaptable: la grande solo si no baja el zoom de la arena.
      final g = SceneGeometry.adaptive(cons.biggest,
          textFactor: RetroType.factorOf(context),
          zoomOf: (g) =>
              layoutFor(g).frame(g, widget.arena, zoomOut: zoomOut).zoom);
      final layout = layoutFor(g);
      scene.frame = SceneFrame(
        battle: b,
        geometry: g,
        layout: layout,
        arena: widget.arena,
        sprites: widget.sprites,
        localId: widget.localId,
        targetId: widget.canAct ? target : null,
        highlightIds: {
          ...highlightedTargets,
          if (hoveredId case final h?) h,
        },
        hoverId: hoveredId,
        turnTimeLeft: widget.turnTimeLeft,
        turnLimit: widget.turnLimit,
        zoomOut: zoomOut,
        floatTopMargin: floatMargin,
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
              top: (g.logTop * s).roundToDouble(),
              width: (g.virtualWidth * s).roundToDouble(),
              height: (BattleScenePainter.logHeight * s).roundToDouble(),
              child: _LogBand(
                battle: b,
                turnTimeLeft: widget.turnTimeLeft,
                localId: widget.localId,
                scale: s,
              ),
            ),
            // REGISTRO EXTENDIDO: las líneas anteriores, debajo de la
            // banda y centradas (no tapan la barra del objetivo).
            if (widget.sceneOptions.extendedLog && _logHistory.isNotEmpty)
              Positioned(
                top: g.stripPx,
                left: g.virtualWidth * s * 0.25,
                width: g.virtualWidth * s * 0.5,
                child: IgnorePointer(
                    child: BattleLogHistory(lines: _logHistory)),
              ),
            // Grupo compacto: los demás aliados, a la derecha.
            if (compactParty && _others(b).isNotEmpty)
              Positioned(
                right: 6,
                top: g.stripPx + 6,
                bottom: 6,
                width: math.min(
                    BattleAllyList.width *
                        math.max(1.0, RetroType.factorOf(context)),
                    g.size.width * 0.3),
                child: BattleAllyList(
                  battle: b,
                  members: _others(b),
                  sprites: widget.sprites,
                  hoverId: hoveredId,
                  onHover: _hoverRow,
                ),
              ),
            // El objetivo: nombre, vida y quiebre (arriba a la izquierda).
            if (_foes.where((e) => e.id == target).firstOrNull case final tg?)
              Positioned(
                left: 8,
                top: g.stripPx + 4,
                child: IgnorePointer(child: TargetBar(enemy: tg)),
              ),
          ],
        ),
      );
    });
  }

  /// Los aliados de la lista compacta: todos menos el propio.
  List<Combatant> _others(BattleState b) {
    final me = _me?.id;
    return [for (final p in b.party) if (p.id != me) p];
  }

  /// La barra de abajo: la ventana de comandos (o de quién es el turno)
  /// y la barra del grupo.
  Widget _bar(BattleState b, Combatant? me) {
    // Grupo compacto (sin compañeros): la tarjeta propia va a la
    // izquierda del menú, en la misma fila (battle_presentation.md
    // § "Barra de abajo"). Con compañeros, la barra del grupo sigue
    // debajo.
    if (compactParty) {
      final card = me == null ? null : _partyBar(b, me);
      final row = _menu(card: card) ??
          BattleBarRow(
            layout: widget.layout,
            hooks: widget.layoutHooks,
            menuBorder: false,
            slots: {
              BattleBarLayout.card: (_) => card,
              BattleBarLayout.waiting: (_) => _waiting(b, me),
            },
          );
      return row;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _menu() ?? _waiting(b, me)),
        const SizedBox(height: _margin),
        _partyBar(b, me),
      ],
    );
  }

  Widget _partyBar(BattleState b, Combatant? me) {
    if (compactParty) {
      // A la izquierda del menú: arriba y con scroll si el alto no
      // alcanza; si es angosta, las cifras van arriba de las barras.
      return LayoutBuilder(
          key: const ValueKey('battle-card'),
          builder: (context, box) => SingleChildScrollView(
              child: _partyBarOf(b, me,
                  stackBars: box.maxWidth <
                      RetroType.em(context, 12) + 150)));
    }
    return _partyBarOf(b, me);
  }

  Widget _partyBarOf(BattleState b, Combatant? me, {bool stackBars = false}) {
    return BattlePartyBar(
          stackBars: stackBars,
          battle: b,
          localId: me?.id,
          sprites: widget.sprites,
          turnTimeLeft: widget.turnTimeLeft,
          points: me == null ? 0 : widget.pendingPoints[me.id] ?? 0,
          companions: widget.companions,
          auto: widget.auto,
          onAuto: widget.onAuto,
          onlyLocal: compactParty,
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
    } else if (widget.companions.contains(cur.id)) {
      // Compañero con AUTO (sin AUTO se abre la ventana de comandos).
      who = 'Turno de ${protoEsc(cur.name)} '
          '(${widget.auto.contains(cur.id) ? 'AUTO' : 'compañero'})';
    } else if (cur.isPlayer) {
      who = '<b>Turno de ${protoEsc(cur.name)}</b>';
    } else {
      who = '<b style="color:#ff6b81">Turno de ${protoEsc(cur.name)}</b>';
    }
    var mine = '';
    if (me != null && cur?.id != me.id) {
      final i = predictTurns(b, turnWindow(b)).indexOf(me.id);
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
                  style: DsText.title(),
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
  Widget? _menu({Widget? card}) {
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
      BattleItem.aether => '¿A quién revives con el Éter (100% de la vida)?',
      _ when _healMode != null =>
        '¿A quién lanzas ${protoEsc(_healMode!.name)}? (a un no muerto le '
            'hace daño)',
      // Después de una Instante el turno sigue (combat.md).
      _ => cur.chained
          ? hexSpan(kInstantHex, 'Encadenaste: te queda una acción')
          : null,
    };
    final targetLine = tg == null
        ? ''
        : 'Objetivo: <b style="color:#ff6b81">${protoEsc(tg.name)}</b> '
            '<span class="k">${tg.hp}/${tg.maxHp} HP</span>'
            '${breakInfoMarkup(tg)}'
            // Familia y debilidades, solo si ya se lo mató (bestiary.md).
            '${tg.practice ? ' · ${familyShortMarkup(null, family: EnemyFamily.training)}' : widget.bestiary?.knows(tg.enemyType) ?? false ? ' · ${familyShortMarkup(tg.enemyType)}' : ''}';
    return BattleCommandWindow(
      actorName: widget.companions.contains(cur.id)
          ? 'Turno de ${cur.name} (compañero)'
          : '¡Tu turno! ${cur.name}',
      categories: entries,
      category: _category,
      visible: visible,
      selected: _selected,
      header: header,
      target: targetLine,
      resources:
          '<span style="color:#74b9ff">MP ${cur.mp.floor()}/${cur.maxMp}</span>'
          ' · <span style="color:${ultReady(cur) ? '#ee70ad' : '#a29bfe'}">'
          'ULT ${cur.ult.floor()}%</span>',
      extra: bossMechanicRow(widget.battle),
      mp: cur.mp,
      pulse: cur.pulse,
      card: card,
      layout: widget.layout,
      layoutHooks: widget.layoutHooks,
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
                    // Una línea y al alto de la banda (16 px virtuales):
                    // si no entra a lo ancho, termina en "…".
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.noScaling,
                    // Los glifos de respaldo (→) no agrandan la línea.
                    strutStyle: StrutStyle(
                        fontSize: big
                            ? px
                            : math.min(
                                RetroType.fixedScaler(context)
                                    .scale(RetroType.small),
                                (box.maxHeight - 2) / 1.25),
                        height: 1.25,
                        forceStrutHeight: true),
                    style: TextStyle(
                        fontFamilyFallback: RetroType.bodyFallback,
                        fontFamily: big
                            ? RetroType.pixelFamily
                            : RetroType.familyFor(RetroType.small),
                        fontSize: big
                            ? px
                            : math.min(
                                RetroType.fixedScaler(context)
                                    .scale(RetroType.small),
                                (box.maxHeight - 2) / 1.25),
                        height: 1.25,
                        color: DsColors.textPrimary),
                  ),
                ),
              ),
            ),
            if (showTimer)
              Container(
                width: timerW,
                margin: EdgeInsets.only(
                    right: 2 * scale, top: scale, bottom: 2 * scale),
                color: ProtoColors.bg,
                alignment: Alignment.center,
                child: Text(
                  retroText('$who ${left.ceil().clamp(0, 99)}s'),
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: RetroType.pixelFamily,
                    fontSize: timerPx,
                    color: left <= 10 ? DsColors.danger : DsColors.selected,
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

/// Las líneas anteriores del log de batalla (REGISTRO EXTENDIDO,
/// accessibility.md § 9.7): caja del fondo del tema, la más nueva abajo
/// y más clara; texto de lectura (sigue el tamaño y la fuente).
class BattleLogHistory extends StatelessWidget {
  const BattleLogHistory({super.key, required this.lines});

  /// La más vieja primero.
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('battle-log-history'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: ProtoColors.bg.withValues(alpha: 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, l) in lines.indexed)
            Text(retroText(l),
                key: ValueKey('battle-log-line-$i'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: RetroType.style(RetroType.small,
                    color: i == lines.length - 1
                        ? DsColors.textPrimary
                        : DsColors.textSecondary)),
        ],
      ),
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
