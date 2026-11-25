import 'dart:async';
import 'dart:math' as math;

import '../../../core/audio/sfx_catalog.dart';
import '../../../core/audio/sfx_service.dart';
import '../../../game_engine/rules/cozy_rules.dart';
import '../../../game_engine/rules/region_ambience_rules.dart';
import '../../../game_engine/rules/sky_rules.dart';
import 'session_view.dart';

/// Cozy ambience (cozy_life.md § 1–2): while the local player fishes or
/// rides a raft (water) or works in a farm, every few seconds a soft
/// sound of the place: lapping water, a bird by day, crickets at night,
/// rain on the crops. Runs beside `FishingAmbiencePlayer`.
class CozyAmbiencePlayer {
  CozyAmbiencePlayer(this.sfx,
      {required this.water, required this.farm, double Function()? rand})
      : _rand = rand ?? math.Random().nextDouble;

  final SfxService sfx;

  /// Fishing or on a raft.
  final bool Function() water;

  /// Working a farm plot.
  final bool Function() farm;
  final double Function() _rand;

  Timer? _timer;
  List<CozySound> _sounds = const [];

  /// Sounds played (tests).
  int played = 0;

  static String soundOf(CozySound s) => switch (s) {
        CozySound.water => Sfx.ambWater,
        CozySound.bird => Sfx.ambBird,
        CozySound.cricket => Sfx.ambCricket,
        CozySound.rain => Sfx.ambRain,
      };

  /// The sounds for [view] now (empty = off).
  List<CozySound> soundsFor(SessionView? view) {
    if (view == null) return const [];
    final w = water(), f = farm();
    if (!w && !f) return const [];
    final sky = view.session.town.sky;
    final wx = sky.weather;
    return CozyRules.sounds(
        night: SkyRules.darkness(sky) > 0.25,
        rain: f && (wx == Weather.lluvia || wx == Weather.tormenta),
        water: w);
  }

  void onView(SessionView? view) {
    _sounds = soundsFor(view);
    if (_sounds.isEmpty) {
      stop();
      return;
    }
    _timer ??= _schedule();
  }

  Timer _schedule() => Timer(
          Duration(
              milliseconds: (CozyRules.nextGapSec(_rand()) * 1000).round()),
          () {
        _timer = null;
        if (_sounds.isEmpty) return;
        final id = soundOf(CozyRules.pick(_sounds, _rand()));
        sfx.play(tunedSfx(id, vol: RegionAmbienceRules.ambienceVolume));
        played++;
        _timer = _schedule();
      });

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
