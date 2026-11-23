import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/retro_panel.dart';
import '../../../../game_engine/rules/sky_rules.dart';
import '../world_strings.dart';

/// Reloj del día del HUD (day_night_weather.md § 1.1): "Día N · HH:MM"
/// y el ícono del clima de ahora. El mouse encima dice el clima y el
/// pronóstico (tooltip de tamaño fijo, siempre encima del HUD).
class DayClock extends StatelessWidget {
  const DayClock({super.key, required this.sky});

  final SkyState sky;

  @override
  Widget build(BuildContext context) {
    if (!sky.started) return const SizedBox.shrink();
    final night = SkyRules.isNight(sky);
    final w = SkyRules.now(sky);
    final label = context.t('ui.world.clock.day',
        {'day': sky.day, 'time': SkyRules.clockLabel(sky)});
    final now = w == Weather.despejado
        ? context.t(night ? 'ui.world.clock.clear_night' : 'ui.world.clock.clear')
        : w.label;
    return DsTooltip(
      card: DsTooltipCard(title: now, children: [
        Text(SkyRules.forecast(sky), style: DsText.detail()),
      ]),
      child: RetroPanel(
        key: const ValueKey('hud-day-clock'),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
                size: const Size.square(12),
                painter: _WeatherIcon(w, night)),
            SizedBox(width: DsSpace.xs),
            Text(label, style: DsText.body(DsColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

/// Ícono de 6×6 celdas: sol, luna, lluvia o tormenta.
class _WeatherIcon extends CustomPainter {
  _WeatherIcon(this.weather, this.night);
  final Weather weather;
  final bool night;

  static const _sun = ['..x x.', '.xxxx.', 'xxxxxx', 'xxxxxx', '.xxxx.', '.x..x.'];
  static const _moon = ['..xxx.', '.xx...', 'xx....', 'xx....', '.xx...', '..xxx.'];
  static const _cloud = ['..xx..', '.xxxx.', 'xxxxxx', '......', '.o.o..', 'o.o...'];
  static const _storm = ['..xx..', '.xxxx.', 'xxxxxx', '...o..', '..o...', '.o....'];

  @override
  void paint(Canvas canvas, Size size) {
    final (rows, main, drop) = switch (weather) {
      Weather.despejado when night =>
        (_moon, DsColors.textSecondary as Color, DsColors.mp),
      Weather.despejado => (_sun, DsColors.actionPrimary, DsColors.actionPrimary),
      Weather.lluvia => (_cloud, DsColors.textSecondary as Color, DsColors.mp),
      Weather.tormenta =>
        (_storm, DsColors.textSecondary as Color, DsColors.warning),
    };
    final k = size.width / 6;
    final p = Paint()..isAntiAlias = false;
    for (var y = 0; y < 6; y++) {
      for (var x = 0; x < 6; x++) {
        final ch = rows[y][x];
        if (ch == '.' || ch == ' ') continue;
        p.color = ch == 'o' ? drop : main;
        canvas.drawRect(Rect.fromLTWH(x * k, y * k, k, k), p);
      }
    }
  }

  @override
  bool shouldRepaint(_WeatherIcon old) =>
      old.weather != weather || old.night != night;
}
