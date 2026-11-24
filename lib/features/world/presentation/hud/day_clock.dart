import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/retro_panel.dart';
import '../../../../game_engine/rules/sky_rules.dart';
import '../../../../game_engine/rules/weather_rules.dart';
import '../../domain/town_names.dart';
import '../world_strings.dart';

/// Reloj del día del HUD (day_night_weather.md § 1.1): "Día N · HH:MM",
/// el ícono del clima de ahora en el lugar ([place], `null` = pueblo) y la
/// marca de la estación (weather_seasons.md § 6.2). El mouse encima dice
/// el clima, la estación y el pronóstico (tooltip de tamaño fijo).
class DayClock extends StatefulWidget {
  const DayClock({super.key, required this.sky, this.place});

  final SkyState sky;
  final String? place;

  @override
  State<DayClock> createState() => _DayClockState();
}

class _DayClockState extends State<DayClock> {
  /// Desplegado: muestra la estación siguiente y cuándo empieza.
  bool _open = false;

  SkyState get sky => widget.sky;
  String? get place => widget.place;

  @override
  Widget build(BuildContext context) {
    if (!sky.started) return const SizedBox.shrink();
    final night = SkyRules.isNight(sky);
    final w = SkyRules.nowIn(sky, place);
    final season = WeatherRules.season(sky.day);
    final label = context.t('ui.world.clock.day',
        {'day': sky.day, 'time': SkyRules.clockLabel(sky)});
    final now = w == Weather.despejado
        ? context.t(night ? 'ui.world.clock.clear_night' : 'ui.world.clock.clear')
        : w.text;
    final next = Season.values[(season.index + 1) % Season.values.length];
    final left = WeatherRules.daysToNextSeason(sky.day);
    // Solo la estación actual; el último día avisa qué viene mañana.
    final lastDay = left <= 1;
    final seasonLine = lastDay
        ? context.t('ui.world.clock.season_last',
            {'season': season.text, 'next': next.text})
        : season.text;
    // Two rows (weather_seasons.md § 6.2): weather + clock, season + days
    // left. Each icon has its own tooltip; texts never clip (ellipsis as
    // a last resort, full text in the tooltip).
    Widget row(Widget icon, String text, Key key) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            SizedBox(width: DsSpace.xs),
            Flexible(
              child: Text(text,
                  key: key,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: DsText.body(DsColors.textPrimary)),
            ),
          ],
        );
    final weatherIcon = DsTooltip(
      card: DsTooltipCard(title: now, children: [
        Text(context.t('ui.world.clock.forecast', {'weather': sky.tomorrow.text}),
            style: DsText.detail()),
      ]),
      child: CustomPaint(
          key: ValueKey('hud-weather-${w.name}'),
          size: const Size.square(12),
          painter: _WeatherIcon(w, night)),
    );
    final seasonIcon = DsTooltip(
      card: DsTooltipCard(title: season.text, children: [
        Text(
            context.t('ui.world.clock.season', {
              'season': season.text,
              'day': WeatherRules.seasonDay(sky.day),
              'len': WeatherRules.seasonDays,
            }),
            style: DsText.detail()),
        Text(
            context.t('ui.world.clock.next_season',
                {'season': next.text, 'n': left}),
            style: DsText.detail()),
      ]),
      child: CustomPaint(
          key: ValueKey('hud-season-${season.name}'),
          size: const Size.square(12),
          painter: _SeasonIcon(season)),
    );
    final after = Season.values[(season.index + 2) % Season.values.length];
    final toggle = DsTooltip(
      card: DsTooltipCard(
          title: context.t(_open
              ? 'ui.world.clock.season_hide'
              : 'ui.world.clock.season_more')),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: const ValueKey('hud-season-toggle'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: EdgeInsets.only(left: DsSpace.xs),
            child: Text(_open ? '▾' : '▸',
                style: DsText.body(DsColors.textSecondary)),
          ),
        ),
      ),
    );
    Widget detail(String text, Key key) => Padding(
          padding: EdgeInsets.only(left: 12 + DsSpace.xs, top: DsSpace.xs),
          child: Text(text,
              key: key,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: DsText.detail()),
        );
    return RetroPanel(
      key: const ValueKey('hud-day-clock'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(weatherIcon, label, const ValueKey('hud-clock-text')),
          SizedBox(height: DsSpace.xs),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
                child: row(seasonIcon, seasonLine,
                    const ValueKey('hud-season-text'))),
            toggle,
          ]),
          if (_open) ...[
            detail(
                context.t('ui.world.clock.season', {
                  'season': season.text,
                  'day': WeatherRules.seasonDay(sky.day),
                  'len': WeatherRules.seasonDays,
                }),
                const ValueKey('hud-season-now')),
            detail(
                context.t('ui.world.clock.season_next',
                    {'season': next.text, 'n': left}),
                const ValueKey('hud-season-next')),
            detail(
                context.t('ui.world.clock.season_after',
                    {'season': after.text}),
                const ValueKey('hud-season-after')),
          ],
        ],
      ),
    );
  }
}

void _paintCells(Canvas canvas, Size size, List<String> rows, Color main,
    Color drop, Paint p) {
  final k = size.width / 6;
  for (var y = 0; y < 6; y++) {
    for (var x = 0; x < 6; x++) {
      final ch = rows[y][x];
      if (ch == '.' || ch == ' ') continue;
      p.color = ch == 'o' ? drop : main;
      canvas.drawRect(Rect.fromLTWH(x * k, y * k, k, k), p);
    }
  }
}

/// Ícono de 6×6 celdas: sol, luna, lluvia, tormenta, niebla o nieve.
class _WeatherIcon extends CustomPainter {
  _WeatherIcon(this.weather, this.night);
  final Weather weather;
  final bool night;

  static const _sun = ['..x x.', '.xxxx.', 'xxxxxx', 'xxxxxx', '.xxxx.', '.x..x.'];
  static const _moon = ['..xxx.', '.xx...', 'xx....', 'xx....', '.xx...', '..xxx.'];
  static const _cloud = ['..xx..', '.xxxx.', 'xxxxxx', '......', '.o.o..', 'o.o...'];
  static const _storm = ['..xx..', '.xxxx.', 'xxxxxx', '...o..', '..o...', '.o....'];
  static const _fog = ['......', 'xxxxx.', '......', '.xxxxx', '......', 'xxxx..'];
  static const _snow = ['..xx..', '.xxxx.', 'xxxxxx', '......', 'o..o..', '..o..o'];
  static final _p = Paint()..isAntiAlias = false;

  @override
  void paint(Canvas canvas, Size size) {
    final (rows, main, drop) = switch (weather) {
      Weather.despejado when night =>
        (_moon, DsColors.textSecondary as Color, DsColors.mp),
      Weather.despejado => (_sun, DsColors.actionPrimary, DsColors.actionPrimary),
      Weather.lluvia => (_cloud, DsColors.textSecondary as Color, DsColors.mp),
      Weather.tormenta =>
        (_storm, DsColors.textSecondary as Color, DsColors.warning),
      Weather.fog =>
        (_fog, DsColors.textSecondary as Color, DsColors.textSecondary as Color),
      Weather.snow => (_snow, DsColors.textSecondary as Color, DsColors.textPrimary),
    };
    _paintCells(canvas, size, rows, main, drop, _p);
  }

  @override
  bool shouldRepaint(_WeatherIcon old) =>
      old.weather != weather || old.night != night;
}

/// Ícono de 6×6 celdas de la estación: brote, sol fuerte, hoja o copo.
class _SeasonIcon extends CustomPainter {
  _SeasonIcon(this.season);
  final Season season;

  static const _sprout = ['......', '.x..x.', '..xx..', '..o...', '..o...', '.ooo..'];
  static const _summer = ['x.x.x.', '.xxx..', 'xxxxx.', '.xxx..', 'x.x.x.', '......'];
  static const _leaf = ['...xx.', '..xxx.', '.xxxx.', '.xxx..', '.o....', 'o.....'];
  static const _flake = ['..x...', 'x.x.x.', '.xxx..', 'xxxxx.', '.xxx..', 'x.x.x.'];
  static final _p = Paint()..isAntiAlias = false;

  @override
  void paint(Canvas canvas, Size size) {
    final (rows, main, drop) = switch (season) {
      Season.spring => (_sprout, DsColors.success, DsColors.textSecondary as Color),
      Season.summer => (_summer, DsColors.actionPrimary, DsColors.actionPrimary),
      Season.autumn => (_leaf, DsColors.warning, DsColors.textSecondary as Color),
      Season.winter => (_flake, DsColors.textPrimary, DsColors.textPrimary),
    };
    _paintCells(canvas, size, rows, main, drop, _p);
  }

  @override
  bool shouldRepaint(_SeasonIcon old) => old.season != season;
}
