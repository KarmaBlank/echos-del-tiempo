import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/retro_panel.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/data/skills_catalog.dart';
import '../../../game_engine/models/battle_command.dart';
import '../../../game_engine/models/battle_event.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/skill.dart';
import '../../../game_engine/models/status.dart';
import 'battle_controller.dart';

/// Pantalla de batalla 8 bits: enemigos arriba, log en el medio, grupo y
/// menú de comandos abajo. Estilo en docs/specs/ui_style.md.
///
/// Los sprites todavía no existen (`assets/sprites` está vacío): cada
/// actor se dibuja como un recuadro con su inicial hasta que se carguen
/// por `SpriteCatalog`.
class BattleScreen extends ConsumerStatefulWidget {
  const BattleScreen({super.key, required this.setup});

  final BattleSetup setup;

  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

enum _Menu { root, skills, target, items, itemTarget, dual }

class _BattleScreenState extends ConsumerState<BattleScreen> {
  _Menu _menu = _Menu.root;

  /// Comando que espera que se elija un enemigo.
  BattleCommand Function(String targetId)? _pendingTarget;
  BattleItem? _pendingItem;

  void _reset() => setState(() {
        _menu = _Menu.root;
        _pendingTarget = null;
        _pendingItem = null;
      });

  void _send(BattleCommand cmd) {
    ref.read(battleControllerProvider(widget.setup).notifier).command(cmd);
    _reset();
  }

  /// Si hay más de un enemigo vivo, pide objetivo; si no, ejecuta directo.
  void _withTarget(BattleState b, BattleCommand Function(String?) build) {
    final foes = b.enemies.where((e) => e.alive).toList();
    if (foes.length <= 1) {
      _send(build(null));
    } else {
      setState(() {
        _pendingTarget = build;
        _menu = _Menu.target;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(battleControllerProvider(widget.setup));
    final b = view.battle;
    final targeting = _menu == _Menu.target && view.waitingForPlayer;

    return Scaffold(
      body: SafeArea(
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
                      events: view.lastEvents,
                      onTap:
                          targeting ? (id) => _send(_pendingTarget!(id)) : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  RetroPanel(
                    child: SizedBox(
                      height: 72,
                      child: Text(
                        retroText(b.log),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
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
                          child:
                              _PartyPanel(battle: b, events: view.lastEvents),
                        ),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: _commandPanel(view)),
                      ],
                    ),
                  ),
                ],
              ),
              if (b.outcome != null) _EndOverlay(outcome: b.outcome!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _commandPanel(BattleView view) {
    final b = view.battle;
    final cur = b.current;
    if (!view.waitingForPlayer || cur == null || !cur.isPlayer) {
      return const RetroPanel(child: Center(child: Text('...')));
    }
    final allies = b.party.where((q) => q.alive && q != cur).toList();

    final List<Widget> options = switch (_menu) {
      _Menu.root => [
          _MenuOption('ATACAR',
              onTap: () => _withTarget(b, (t) => AttackCommand(targetId: t))),
          _MenuOption('TÉCNICA',
              onTap: () => setState(() => _menu = _Menu.skills)),
          _MenuOption('ULT ${cur.ult.floor()}%',
              onTap: cur.ult >= 100 ? () => _ultimate(b, cur) : null),
          _MenuOption('DÚO',
              onTap: cur.mp >= 4 && allies.any((q) => q.mp >= 4)
                  ? () => setState(() => _menu = _Menu.dual)
                  : null),
          _MenuOption('OBJETO',
              onTap: () => setState(() => _menu = _Menu.items)),
          _MenuOption('DEFENDER', onTap: () => _send(const DefendCommand())),
        ],
      _Menu.skills => [
          for (final id in cur.skillIds)
            if (kSkills[id] case final SkillDef sk)
              _MenuOption('${sk.name}  ${sk.mp}MP',
                  onTap: cur.mp >= sk.mp ? () => _skill(b, sk) : null),
          _MenuOption('VOLVER', onTap: _reset),
        ],
      _Menu.target => [
          const Text('Elegí un enemigo'),
          for (final e in b.enemies.where((e) => e.alive))
            _MenuOption(e.name, onTap: () => _send(_pendingTarget!(e.id))),
          _MenuOption('VOLVER', onTap: _reset),
        ],
      _Menu.items => [
          _MenuOption('Poción de vida x${cur.potions}',
              onTap:
                  cur.potions > 0 ? () => _pickItem(BattleItem.potion) : null),
          _MenuOption('Poción de maná x${cur.ethers}',
              onTap: cur.ethers > 0 ? () => _pickItem(BattleItem.ether) : null),
          _MenuOption('VOLVER', onTap: _reset),
        ],
      _Menu.itemTarget => [
          const Text('¿A quién?'),
          for (final q in b.party)
            if (_pendingItem == BattleItem.potion || q.alive)
              _MenuOption(q.name,
                  onTap: () =>
                      _send(ItemCommand(_pendingItem!, targetPlayerId: q.id))),
          _MenuOption('VOLVER', onTap: _reset),
        ],
      _Menu.dual => [
          const Text('¿Con quién?'),
          for (final q in allies)
            _MenuOption(q.name,
                onTap: q.mp >= 4 ? () => _send(DualCommand(q.id)) : null),
          _MenuOption('VOLVER', onTap: _reset),
        ],
    };

    return RetroPanel(
      selected: true,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(retroText('TURNO: ${cur.name.toUpperCase()}'),
                style: const TextStyle(color: RetroPalette.gold)),
            const SizedBox(height: 16),
            for (final o in options)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: o),
          ],
        ),
      ),
    );
  }

  void _skill(BattleState b, SkillDef sk) {
    if (sk.dealsDamage && !sk.allTargets) {
      _withTarget(b, (t) => SkillCommand(sk.id, targetId: t));
    } else {
      _send(SkillCommand(sk.id));
    }
  }

  void _ultimate(BattleState b, Combatant cur) {
    final ult = kUltimates[cur.weaponType];
    if (ult != null && ult.dealsDamage && !ult.allTargets) {
      _withTarget(b, (t) => UltimateCommand(targetId: t));
    } else {
      _send(const UltimateCommand());
    }
  }

  void _pickItem(BattleItem item) => setState(() {
        _pendingItem = item;
        _menu = _Menu.itemTarget;
      });
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
          style: TextStyle(color: color),
        ),
      ),
    );
  }
}

/// Barra de vida/maná/ULT pixelada.
class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.max, required this.color});

  final num value;
  final num max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final f = max <= 0 ? 0.0 : (value / max).clamp(0, 1).toDouble();
    return Container(
      height: 16,
      decoration: BoxDecoration(
        color: RetroPalette.night,
        border: Border.all(color: RetroPalette.ink, width: 2),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: f,
          heightFactor: 1,
          child: ColoredBox(color: color),
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

/// Recuadro con la inicial: reemplazo hasta que haya sprites.
class _PlaceholderSprite extends StatelessWidget {
  const _PlaceholderSprite(this.letter,
      {required this.size, required this.color});

  final String letter;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: RetroPalette.panelDark,
        border: Border.all(color: color, width: 4),
      ),
      child: Text(letter,
          style: TextStyle(fontSize: size >= 96 ? 32 : 16, color: color)),
    );
  }
}

class _EnemyRow extends StatelessWidget {
  const _EnemyRow({required this.battle, required this.events, this.onTap});

  final BattleState battle;
  final List<BattleEvent> events;
  final void Function(String id)? onTap;

  @override
  Widget build(BuildContext context) {
    // Se achica en ventanas chicas en vez de desbordar.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final e in battle.enemies)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _EnemyCard(
                enemy: e,
                active: battle.currentId == e.id,
                hit: _lastHit(e.id, events),
                onTap: onTap != null && e.alive ? () => onTap!(e.id) : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _EnemyCard extends StatelessWidget {
  const _EnemyCard(
      {required this.enemy, required this.active, this.hit, this.onTap});

  final Combatant enemy;
  final bool active;
  final String? hit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    final card = Opacity(
      opacity: enemy.alive ? 1 : 0.3,
      child: SizedBox(
        width: 240,
        child: RetroPanel(
          selected: active || onTap != null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 24,
                child: hit == null
                    ? null
                    : Text(hit!,
                        style: const TextStyle(color: RetroPalette.gold)),
              ),
              _PlaceholderSprite(
                enemy.name.substring(0, 1),
                size: enemy.boss ? 128 : 96,
                color: enemy.elite || enemy.boss
                    ? RetroPalette.gold
                    : RetroPalette.red,
              ),
              const SizedBox(height: 16),
              Text(enemy.name, textAlign: TextAlign.center, maxLines: 1),
              const SizedBox(height: 8),
              _Bar(value: enemy.hp, max: enemy.maxHp, color: RetroPalette.red),
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
  const _PartyPanel({required this.battle, required this.events});

  final BattleState battle;
  final List<BattleEvent> events;

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
                    width: 176,
                    child: Text(p.alive ? p.name : '${p.name} KO', maxLines: 1),
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
                              child: _Bar(
                                  value: p.hp,
                                  max: p.maxHp,
                                  color: RetroPalette.green),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _Bar(
                                  value: p.mp,
                                  max: p.maxMp,
                                  color: RetroPalette.muted),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _Bar(
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
                Text('+${outcome.xp} XP   +${outcome.credits} CRÉDITOS'),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('> VOLVER'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
