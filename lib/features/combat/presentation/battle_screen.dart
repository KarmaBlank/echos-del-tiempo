import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/retro_bar.dart';
import '../../../app/theme/retro_panel.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/data/skills_catalog.dart';
import '../../../game_engine/models/battle_command.dart';
import '../../../game_engine/models/battle_event.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/status.dart';
import 'game_sprites.dart';
import 'pixel_sprite.dart';

/// Pantalla de batalla 8 bits: enemigos arriba, log en el medio, grupo y
/// menú de comandos abajo. Estilo en docs/specs/ui_style.md; menú y
/// teclas en docs/specs/exploration.md § "Batalla".
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
    this.canAct = false,
    this.turnTimeLeft,
    this.sprites,
  });

  final BattleState battle;

  /// Eventos del último paso (números de daño flotando).
  final List<BattleEvent> events;

  /// Le toca al jugador de este dispositivo: se muestra el menú.
  final bool canAct;

  /// Segundos que le quedan al jugador de turno (`TURN_LIMIT − turnT`).
  final double? turnTimeLeft;

  /// Manda un comando del actor de turno. Devuelve si fue aceptado.
  final bool Function(BattleCommand command) onCommand;

  /// Sprites ya cargados; sin ellos se dibuja la inicial del actor.
  final GameSprites? sprites;

  @override
  State<BattleView> createState() => BattleViewState();
}

/// Una opción del menú plano numerado (`btn` del prototipo).
class _Option {
  const _Option(this.label, this.onSelect);
  final String label;

  /// `null` = deshabilitada.
  final VoidCallback? onSelect;
}

class BattleViewState extends State<BattleView> {
  /// Enemigo apuntado (`tgt` del prototipo).
  String? _target;

  /// Submenú de poción abierto (`potMode`).
  BattleItem? _potMode;

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
  void didUpdateWidget(BattleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.canAct && _potMode != null) _potMode = null;
  }

  /// `cycleTarget`: el siguiente enemigo vivo.
  void cycleTarget() {
    final foes = _foes;
    if (foes.isEmpty) return;
    final i = foes.indexWhere((e) => e.id == target);
    setState(() => _target = foes[(i + 1) % foes.length].id);
  }

  void _send(BattleCommand cmd) {
    if (widget.onCommand(cmd)) setState(() => _potMode = null);
  }

  /// Teclas de batalla: 1-9 eligen la opción N, Q/Tab cambian de
  /// objetivo, Esc sale del submenú. Devuelve si la tecla se usó.
  bool handleKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.keyQ || key == LogicalKeyboardKey.tab) {
      cycleTarget();
      return true;
    }
    if (key == LogicalKeyboardKey.escape && _potMode != null) {
      setState(() => _potMode = null);
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
    final cur = widget.battle.current;
    if (!widget.canAct || cur == null) return true;
    final opts = _options(cur);
    if (n < opts.length) opts[n].onSelect?.call();
    return true;
  }

  List<_Option> _options(Combatant cur) {
    final b = widget.battle;
    final item = _potMode;
    if (item != null) {
      final pot = item == BattleItem.potion;
      return [
        for (final q in b.party)
          if (pot || q.alive)
            _Option(
              '${q.id == cur.id ? 'Yo (${q.name})' : q.name} '
              '${pot ? '${q.hp}/${q.maxHp} HP' : '${q.mp.floor()}/${q.maxMp} MP'}'
              '${pot && !q.alive ? ' ¡revive!' : ''}',
              () => _send(ItemCommand(item, targetPlayerId: q.id)),
            ),
        _Option('< Volver', () => setState(() => _potMode = null)),
      ];
    }
    final tg = target;
    final ult = kUltimates[cur.weaponType];
    final allies = b.party.where((q) => q.alive && q.id != cur.id);
    return [
      _Option('Atacar', () => _send(AttackCommand(targetId: tg))),
      if (ult != null)
        _Option('★ ULTIMATE: ${ult.name} [${cur.ult.floor()}%]',
            cur.ult >= 100 ? () => _send(UltimateCommand(targetId: tg)) : null),
      for (final id in cur.skillIds)
        if (kSkills[id] case final sk?)
          _Option('${sk.name} ${sk.mp}MP',
              cur.mp >= sk.mp ? () => _send(SkillCommand(id, targetId: tg)) : null),
      for (final q in allies)
        _Option(
          '★ ${kDuals[dualKey(cur.classId ?? '', q.classId ?? '')]?.name ?? 'Dúo'}'
          ' (+${q.name}) 4MP c/u',
          cur.mp >= 4 && q.mp >= 4 ? () => _send(DualCommand(q.id)) : null,
        ),
      _Option('Poción de vida x${cur.potions} ▸',
          cur.potions > 0 ? () => setState(() => _potMode = BattleItem.potion) : null),
      _Option('Poción de maná x${cur.ethers} ▸',
          cur.ethers > 0 ? () => setState(() => _potMode = BattleItem.ether) : null),
      _Option('Defender', () => _send(const DefendCommand())),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.battle;
    final tg = target;
    return ColoredBox(
      color: RetroPalette.night,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: _EnemyRow(
                    battle: b,
                    events: widget.events,
                    target: widget.canAct ? tg : null,
                    sprites: widget.sprites,
                    onTap: (id) => setState(() => _target = id),
                  ),
                ),
                const SizedBox(height: 16),
                RetroPanel(
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            retroText(b.log),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        if (widget.turnTimeLeft case final left?)
                          Text(
                            'TIEMPO ${left.ceil().clamp(0, 99)}s',
                            style: TextStyle(
                              fontSize: 8,
                              color: left <= 10
                                  ? RetroPalette.red
                                  : RetroPalette.gold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  flex: 4,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _PartyPanel(
                            battle: b,
                            events: widget.events,
                            sprites: widget.sprites),
                      ),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _commandPanel()),
                    ],
                  ),
                ),
              ],
            ),
            if (b.outcome != null) _EndOverlay(outcome: b.outcome!),
          ],
        ),
      ),
    );
  }

  Widget _commandPanel() {
    final cur = widget.battle.current;
    if (cur == null || !cur.isPlayer) {
      return const RetroPanel(child: Center(child: Text('...')));
    }
    if (!widget.canAct) {
      return RetroPanel(
        child: Center(
          child: Text(retroText('TURNO DE ${cur.name.toUpperCase()}'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 8, color: RetroPalette.muted)),
        ),
      );
    }
    final options = _options(cur);
    return RetroPanel(
      selected: true,
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              retroText(_potMode == null
                  ? '¡TU TURNO! ${cur.name.toUpperCase()}'
                  : '¿A QUIÉN?'),
              style: const TextStyle(color: RetroPalette.gold),
            ),
            const SizedBox(height: 4),
            Text('Q/Tab: objetivo · 1-9: elegir',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: RetroPalette.muted)),
            const SizedBox(height: 12),
            for (var i = 0; i < options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _MenuOption('${i + 1}. ${options[i].label}',
                    onTap: options[i].onSelect),
              ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Piezas
// ----------------------------------------------------------------------

/// Opción de menú estilo JRPG: '>' y dorado al pasar el mouse.
class _MenuOption extends StatefulWidget {
  const _MenuOption(this.label, {this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  State<_MenuOption> createState() => _MenuOptionState();
}

class _MenuOptionState extends State<_MenuOption> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final color = !enabled
        ? RetroPalette.muted
        : _hover
            ? RetroPalette.gold
            : RetroPalette.ink;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          retroText('${_hover && enabled ? '> ' : '  '}${widget.label}'),
          style: TextStyle(color: color, fontSize: 8, height: 1.5),
        ),
      ),
    );
  }
}

/// Stacks de estado como letras (Q V C A S R), como el prototipo.
String _statusLine(Combatant c) {
  const letters = {
    StatusKind.burn: 'Q',
    StatusKind.poison: 'V',
    StatusKind.freeze: 'C',
    StatusKind.stun: 'A',
    StatusKind.holy: 'S',
    StatusKind.regen: 'R',
  };
  return [
    for (final k in StatusKind.values)
      if (c.stacks(k) > 0) '${letters[k]}${c.stacks(k)}',
    if (c.defending) 'DEF',
    if (c.protecting) 'PROT',
    if (c.taunt > 0) 'PROV',
  ].join(' ');
}

/// Daño recibido en el último paso, para mostrarlo flotando.
String? _lastHit(String id, List<BattleEvent> events) {
  var total = 0;
  var crit = false;
  for (final e in events) {
    if (e is DamageEvent && e.targetId == id) {
      total += e.amount;
      crit = crit || e.critical;
    }
  }
  return total == 0 ? null : '-$total${crit ? '!' : ''}';
}

/// Recuadro con la inicial: solo si los sprites no cargaron.
class _PlaceholderSprite extends StatelessWidget {
  const _PlaceholderSprite(this.letter, {required this.size});

  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: RetroPalette.panelDark,
        border: Border.all(color: RetroPalette.muted, width: 2),
      ),
      child: Text(letter, style: const TextStyle(color: RetroPalette.muted)),
    );
  }
}

/// Píxeles de pantalla por píxel de sprite en batalla.
const _enemyPixel = 6.0;
const _heroPixel = 2.0;

class _EnemyRow extends StatelessWidget {
  const _EnemyRow({
    required this.battle,
    required this.events,
    required this.target,
    required this.sprites,
    required this.onTap,
  });

  final BattleState battle;
  final List<BattleEvent> events;
  final String? target;
  final GameSprites? sprites;
  final void Function(String id) onTap;

  @override
  Widget build(BuildContext context) {
    // Se achica en ventanas chicas en vez de desbordar.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final e in battle.enemies)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _EnemyCard(
                enemy: e,
                active: battle.currentId == e.id,
                targeted: target == e.id,
                hit: _lastHit(e.id, events),
                sprites: sprites,
                onTap: e.alive ? () => onTap(e.id) : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _EnemyCard extends StatelessWidget {
  const _EnemyCard({
    required this.enemy,
    required this.active,
    required this.targeted,
    required this.sprites,
    this.hit,
    this.onTap,
  });

  final Combatant enemy;
  final bool active;
  final bool targeted;
  final GameSprites? sprites;
  final String? hit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    final type = enemy.enemyType ?? '';
    final img = sprites?.enemy(type);
    final scale = _enemyPixel *
        (sprites?.enemyScale(type) ?? 1) *
        (enemy.elite ? 1.45 : 1);
    final spriteW = (img?.width ?? 16) * scale;
    final card = Opacity(
      opacity: enemy.alive ? 1 : 0.3,
      child: SizedBox(
        width: spriteW + 64 < 240 ? 240 : spriteW + 64,
        child: RetroPanel(
          selected: targeted,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 24,
                child: Text(
                  hit ?? (active ? 'ACTUA' : ''),
                  style: TextStyle(
                      color: hit != null ? RetroPalette.gold : RetroPalette.red),
                ),
              ),
              if (img != null)
                PixelSprite(img, scale: scale)
              else
                _PlaceholderSprite(enemy.name.substring(0, 1),
                    size: enemy.boss ? 128 : 96),
              const SizedBox(height: 16),
              Text(
                retroText('${targeted ? '> ' : ''}${enemy.elite ? '★' : ''}'
                    '${enemy.name}'),
                textAlign: TextAlign.center,
                maxLines: 1,
                style: small?.copyWith(
                    color: targeted ? RetroPalette.gold : RetroPalette.ink),
              ),
              const SizedBox(height: 8),
              RetroBar(
                  value: enemy.hp,
                  max: enemy.maxHp,
                  color: enemy.boss || enemy.elite
                      ? RetroPalette.gold
                      : RetroPalette.red),
              const SizedBox(height: 8),
              Text('${enemy.hp}/${enemy.maxHp}  ${_statusLine(enemy)}',
                  style: small, maxLines: 1),
            ],
          ),
        ),
      ),
    );
    if (onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }
}

class _PartyPanel extends StatelessWidget {
  const _PartyPanel(
      {required this.battle, required this.events, required this.sprites});

  final BattleState battle;
  final List<BattleEvent> events;
  final GameSprites? sprites;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return RetroPanel(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final p in battle.party)
            Opacity(
              opacity: p.alive ? 1 : 0.4,
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(battle.currentId == p.id ? '>' : '',
                        style: const TextStyle(color: RetroPalette.gold)),
                  ),
                  SizedBox(
                    width: 40,
                    child: switch (sprites?.hero(p.classId ?? '')) {
                      final img? => PixelSprite(img, scale: _heroPixel),
                      null => const SizedBox.shrink(),
                    },
                  ),
                  SizedBox(
                    width: 160,
                    child: Text(p.alive ? p.name : '${p.name} KO',
                        maxLines: 1, overflow: TextOverflow.clip),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: RetroBar(
                                  value: p.hp,
                                  max: p.maxHp,
                                  color: RetroPalette.green),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RetroBar(
                                  value: p.mp,
                                  max: p.maxMp,
                                  color: RetroPalette.muted),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RetroBar(
                                  value: p.ult,
                                  max: 100,
                                  color: RetroPalette.gold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'HP ${p.hp}/${p.maxHp} MP ${p.mp.floor()}/${p.maxMp} '
                          'ULT ${p.ult.floor()}% ${_statusLine(p)} '
                          '${_lastHit(p.id, events) ?? ''}',
                          style: small,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
      color: RetroPalette.night.withValues(alpha: 0.8),
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
                  color: outcome.victory ? RetroPalette.gold : RetroPalette.red,
                ),
              ),
              if (outcome.victory) ...[
                const SizedBox(height: 24),
                Text('+${outcome.xp} XP   +${outcome.credits} CREDITOS'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
