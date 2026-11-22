import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../core/audio/sfx_catalog.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/models/item.dart' show Rarity;
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/models/session_event.dart';
import '../../../../game_engine/rules/fishing_minigame.dart';
import '../../../../game_engine/rules/fishing_rules.dart';
import '../../../inventory/presentation/item_widgets.dart';
import '../map/map_themes.dart';
import '../session_controller.dart';
import '../session_sfx.dart' show sfxServiceProvider;
import '../session_view.dart';

/// Color de una rareza de pez (los de las armas).
Color fishRarityColor(FishRarity r) => RarityColors.of(switch (r) {
      FishRarity.comun => Rarity.comun,
      FishRarity.raro => Rarity.raro,
      FishRarity.epico => Rarity.epico,
      FishRarity.legendario => Rarity.legendario,
    });

/// Línea compacta de oficios para PERSONAJE (fishing.md § 3).
Widget lifeSkillsLine(PlayerProfile p) {
  final lvl = FishingRules.level(p);
  final (cur, need) = FishingRules.progress(p.life.fishXp);
  return Padding(
    padding: EdgeInsets.only(top: DsSpace.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DsSectionHeader('OFICIOS'),
        Text(
            'Pesca nivel $lvl${need > 0 ? ' · $cur/$need XP' : ' · máximo'}'
            ' · ${kRods[p.life.rod]!.name} · Pescados ${p.life.bagTotal}',
            key: const ValueKey('life-fishing'),
            style: DsText.detail()),
      ],
    ),
  );
}

/// Panel PESCA (fishing.md § 4): la escena del lago con sombras de peces,
/// lance con carga, picada y la barra de captura. El minijuego es local;
/// el pez lo tira el anfitrión y el resultado lo valida él.
class FishingPanel extends ConsumerStatefulWidget {
  const FishingPanel(
      {super.key, required this.view, required this.controller, this.game});

  final SessionView view;
  final SessionController controller;

  /// Para tests y capturas: un minijuego ya armado.
  final FishingMinigame? game;

  @override
  ConsumerState<FishingPanel> createState() => _FishingPanelState();
}

class _Shadow {
  _Shadow(this.x, this.y, this.size, this.vx, this.vy);
  double x, y, vx, vy;
  final double size;
}

class _Particle {
  _Particle(this.x, this.y, this.vx, this.vy);
  double x, y, vx, vy, life = 0.6;
}

class _FishingPanelState extends ConsumerState<FishingPanel>
    with SingleTickerProviderStateMixin {
  final _rand = math.Random();
  late FishingMinigame _game;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  StreamSubscription<SessionEvent>? _sub;
  final _shadows = <_Shadow>[];
  final _particles = <_Particle>[];
  FishPhase _prev = FishPhase.idle;
  bool _sent = false;
  double _t = 0;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _game = widget.game ?? _newGame();
    _prev = _game.phase;
    // Sombras: más grandes = más raras (según las especies del lago).
    final lake = widget.controller.world?.town.lake ?? kTownLakeDefault;
    for (final id in lake) {
      final r = kFish[id]?.rarity ?? FishRarity.comun;
      if (r == FishRarity.legendario && _rand.nextDouble() > 0.5) continue;
      _shadows.add(_Shadow(_rand.nextDouble(), 0.1 + _rand.nextDouble() * 0.6,
          0.025 + 0.018 * r.index, (_rand.nextDouble() - 0.5) * 0.08,
          (_rand.nextDouble() - 0.5) * 0.04));
    }
    _sub = widget.controller.events.listen(_onEvent);
    _ticker = createTicker(_onTick)..start();
  }

  FishingMinigame _newGame() {
    final p = widget.view.me?.profile;
    final b = p == null
        ? (bite: 0.0, zone: 0.0, rare: 0.0)
        : FishingRules.rodBonus(p);
    return FishingMinigame(_rand.nextDouble,
        biteBonus: b.bite, zoneBonus: b.zone);
  }

  void _onEvent(SessionEvent e) {
    if (e case FishBiteEvent(:final playerId, :final species, :final sizeCm)
        when playerId == widget.view.localId) {
      _game.hook(FishCatch(species, sizeCm));
    }
  }

  void _play(String id) => ref.read(sfxServiceProvider).play(id);

  void _splash(double x, double y, [int n = 10]) {
    for (var i = 0; i < n; i++) {
      final a = _rand.nextDouble() * math.pi;
      final v = 0.15 + _rand.nextDouble() * 0.25;
      _particles.add(_Particle(x, y, math.cos(a) * v, -math.sin(a) * v));
    }
  }

  (double, double) get _bobber =>
      (0.5, 0.82 - 0.62 * _game.power.clamp(0.0, 1.0));

  void _onTick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    _t += dt;
    _game.tick(dt);
    for (final s in _shadows) {
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      if (s.x < 0.05 || s.x > 0.95) s.vx = -s.vx;
      if (s.y < 0.08 || s.y > 0.72) s.vy = -s.vy;
      if (_rand.nextDouble() < dt * 0.3) {
        s.vx = (_rand.nextDouble() - 0.5) * 0.08;
      }
    }
    for (final p in _particles) {
      p
        ..x += p.vx * dt
        ..y += p.vy * dt
        ..vy += 0.6 * dt
        ..life -= dt;
    }
    _particles.removeWhere((p) => p.life <= 0);
    _phaseFx();
    // Clavado sin respuesta del anfitrión: se escapa.
    if (_game.phase == FishPhase.hooking && _game.phaseTime > 3) {
      _game.cancel();
    }
    if (mounted) setState(() {});
  }

  void _phaseFx() {
    final ph = _game.phase;
    if (_game.nibbling && _game.phaseTime % 1 < 0.02) _play(Sfx.turnTick);
    if (ph == _prev) return;
    final (bx, by) = _bobber;
    switch (ph) {
      case FishPhase.flying:
        _play(Sfx.frenzyWhoosh);
      case FishPhase.waiting:
        _play(Sfx.potion);
        _splash(bx, by, 6);
      case FishPhase.bite:
        _play(Sfx.bell);
      case FishPhase.hooking:
        _sent = false;
        _play(Sfx.whump);
        widget.controller.fishBite(_game.power);
      case FishPhase.reel:
        _play(Sfx.clang);
      case FishPhase.won:
        _play(Sfx.lootPickup);
        _splash(bx, by, 16);
        if (!_sent) {
          _sent = true;
          widget.controller.fishResult(true);
        }
      case FishPhase.lost:
        _play(Sfx.thaw);
        if (_prev == FishPhase.reel && !_sent) {
          _sent = true;
          widget.controller.fishResult(false);
        }
      default:
        break;
    }
    _prev = ph;
  }

  @override
  void dispose() {
    _ticker.dispose();
    unawaited(_sub?.cancel());
    _focus.dispose();
    // Cerrar a mitad de la pelea cuenta como escapado.
    if (_game.phase == FishPhase.reel && !_sent) {
      widget.controller.fishResult(false);
    }
    super.dispose();
  }

  String get _hint => switch (_game.phase) {
        FishPhase.idle => 'Mantené para cargar el lance y soltá para tirar.',
        FishPhase.charging => 'Cargando… soltá para tirar.',
        FishPhase.flying => 'La boya vuela…',
        FishPhase.waiting => _game.nibbling
            ? 'Tantea… todavía no.'
            : 'Esperá la picada. Si tirás antes, se va.',
        FishPhase.bite => '¡PICÓ! Tocá ya.',
        FishPhase.hooking => 'Clavado…',
        FishPhase.reel =>
          'Mantené para subir la zona, soltá para bajarla. Tené al pez adentro.',
        FishPhase.won =>
          '¡Sacaste ${_game.fish?.def.name ?? 'un pez'} (${_game.fish?.sizeCm ?? 0} cm)! Tocá para lanzar de nuevo.',
        FishPhase.lost =>
          '${_game.lostReason ?? 'Se escapó.'} Tocá para lanzar de nuevo.',
      };

  @override
  Widget build(BuildContext context) {
    final p = widget.view.me?.profile;
    final c = widget.controller;
    final lvl = p == null ? 1 : FishingRules.level(p);
    final (cur, need) = FishingRules.progress(p?.life.fishXp ?? 0);
    return PanelFrame(
      key: const ValueKey('panel-fishing'),
      title: 'PESCA',
      width: 720,
      onClose: c.closePanel,
      actions: [
        PanelButton('AUTO-PESCA',
            key: const ValueKey('fish-auto'), onPressed: c.autoFish),
        PanelButton('CERRAR',
            key: const ValueKey('fish-close'), onPressed: c.closePanel),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Text('PESCA NIVEL $lvl', style: DsText.subtitle()),
            SizedBox(width: DsSpace.sm),
            if (need > 0)
              Text('$cur/$need XP', style: DsText.detail()),
            const Spacer(),
            Text(
                '${kRods[p?.life.rod ?? kStarterRod]!.name} · '
                'Pescados ${p?.life.bagTotal ?? 0}',
                key: const ValueKey('fish-rod'),
                style: DsText.detail()),
          ]),
          SizedBox(height: DsSpace.sm),
          Focus(
            focusNode: _focus,
            autofocus: true,
            onKeyEvent: (_, e) {
              if (e.logicalKey != LogicalKeyboardKey.space) {
                return KeyEventResult.ignored;
              }
              if (e is KeyDownEvent) _game.press();
              if (e is KeyUpEvent) _game.release();
              return KeyEventResult.handled;
            },
            child: Listener(
              key: const ValueKey('fish-scene'),
              onPointerDown: (_) => _game.press(),
              onPointerUp: (_) => _game.release(),
              child: SizedBox(
                height: 320,
                child: CustomPaint(
                  painter: _ScenePainter(_game, _shadows, _particles, _t,
                      _bobber),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          SizedBox(height: DsSpace.sm),
          Text(_hint,
              key: const ValueKey('fish-hint'),
              style: _game.phase == FishPhase.bite
                  ? DsText.body(DsColors.reward)
                  : DsText.body()),
          Text(
              'Auto-pesca: ${FishingRules.t.i('autoCount')} peces chicos con '
              'menos XP, nunca legendarios.',
              style: DsText.detail()),
        ],
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.g, this.shadows, this.particles, this.t, this.bobber);
  final FishingMinigame g;
  final List<_Shadow> shadows;
  final List<_Particle> particles;
  final double t;
  final (double, double) bobber;

  @override
  void paint(Canvas canvas, Size size) {
    final reel = g.phase == FishPhase.reel;
    // Sacudida del tirón: el pez afuera de la zona.
    final shake = reel && !g.fishInside ? math.sin(t * 60) * 2.0 : 0.0;
    final w = size.width, h = size.height;
    final lakeW = reel ? w - 90 : w;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, lakeW, h));
    canvas.translate(shake, 0);
    canvas.drawRect(Rect.fromLTWH(0, 0, lakeW, h),
        Paint()..color = FishingPalette.waterDeep);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.35, lakeW, h * 0.65),
        Paint()..color = FishingPalette.water);
    // Ondas.
    final rp = Paint()
      ..color = FishingPalette.ripple
      ..strokeWidth = 1;
    for (var i = 0; i < 9; i++) {
      final y = h * (0.1 + i * 0.09);
      final x = (lakeW * ((i * 0.37 + t * 0.03) % 1));
      canvas.drawLine(Offset(x, y), Offset(x + 18, y), rp);
    }
    // Sombras de peces.
    final sp = Paint()..color = FishingPalette.shadow;
    for (final s in shadows) {
      final r = s.size * lakeW;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(s.x * lakeW, s.y * h), width: r * 2, height: r),
          sp);
    }
    // Juncos y muelle.
    final reed = Paint()
      ..color = FishingPalette.reed
      ..strokeWidth = 2;
    for (var i = 0; i < 6; i++) {
      final x = 8.0 + i * 7;
      canvas.drawLine(Offset(x, h), Offset(x + math.sin(t + i) * 2, h - 26), reed);
    }
    final dock = Rect.fromLTWH(lakeW / 2 - 40, h - 26, 80, 26);
    canvas.drawRect(dock, Paint()..color = FishingPalette.dock);
    for (var x = dock.left; x < dock.right; x += 10) {
      canvas.drawLine(Offset(x, dock.top), Offset(x, dock.bottom),
          Paint()..color = FishingPalette.dockDark);
    }
    // Línea y boya.
    final rod = Offset(lakeW / 2, h - 26);
    final show = g.phase != FishPhase.idle && g.phase != FishPhase.charging;
    if (g.phase == FishPhase.charging) {
      final cp = Paint()..color = FishingPalette.foam;
      canvas.drawRect(
          Rect.fromLTWH(lakeW / 2 - 50, h - 34, 100 * g.power, 5), cp);
    }
    if (show) {
      var (bx, by) = bobber;
      if (g.phase == FishPhase.flying) {
        final k = (g.phaseTime / FishingMinigame.flySec).clamp(0.0, 1.0);
        by = 0.9 - (0.9 - by) * k - math.sin(k * math.pi) * 0.15;
      }
      var dip = 0.0;
      if (g.nibbling) dip = 3;
      if (g.phase == FishPhase.bite || g.phase == FishPhase.hooking) {
        dip = 7 + math.sin(t * 30) * 2;
      }
      if (reel) dip = 5 + math.sin(t * 18) * 3;
      final b = Offset(bx * lakeW, by * h + dip);
      canvas.drawLine(rod, b, Paint()..color = FishingPalette.line);
      if (g.phase == FishPhase.bite) {
        canvas.drawCircle(b, 14 + math.sin(t * 20) * 3,
            Paint()
              ..color = FishingPalette.foam
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      }
      canvas.drawCircle(b, 5, Paint()..color = FishingPalette.bobber);
      canvas.drawCircle(b.translate(0, -3), 2.5, Paint()..color = FishingPalette.foam);
    }
    final pp = Paint()..color = FishingPalette.foam;
    for (final p in particles) {
      canvas.drawCircle(Offset(p.x * lakeW, p.y * h), 2 * p.life / 0.6 + 0.5, pp);
    }
    canvas.restore();
    if (reel) _bar(canvas, Rect.fromLTWH(w - 80, 6, 34, h - 12));
  }

  void _bar(Canvas canvas, Rect r) {
    canvas.drawRect(r, Paint()..color = DsColors.surfaceSunken);
    canvas.drawRect(
        r,
        Paint()
          ..color = DsColors.border
          ..style = PaintingStyle.stroke);
    double y(double v) => r.bottom - v * r.height;
    final zone = Rect.fromLTRB(
        r.left + 2, y(g.zonePos + g.zoneSize), r.right - 2, y(g.zonePos));
    canvas.drawRect(
        zone,
        Paint()
          ..color = (g.fishInside ? DsColors.success : DsColors.warning)
              .withValues(alpha: 0.55));
    // Pez.
    final fc = fishRarityColor(g.fish?.rarity ?? FishRarity.comun);
    final fy = y(g.fishPos);
    final body = Rect.fromCenter(
        center: Offset(r.center.dx, fy), width: 20, height: 9);
    canvas.drawOval(body, Paint()..color = fc);
    canvas.drawPath(
        Path()
          ..moveTo(body.right - 2, fy)
          ..lineTo(body.right + 6, fy - 5)
          ..lineTo(body.right + 6, fy + 5)
          ..close(),
        Paint()..color = fc);
    // Progreso.
    final pr = Rect.fromLTWH(r.right + 8, r.top, 8, r.height);
    canvas.drawRect(pr, Paint()..color = DsColors.surfaceSunken);
    canvas.drawRect(
        Rect.fromLTRB(pr.left, pr.bottom - g.progress * pr.height, pr.right,
            pr.bottom),
        Paint()..color = DsColors.reward);
  }

  @override
  bool shouldRepaint(_ScenePainter old) => true;
}
