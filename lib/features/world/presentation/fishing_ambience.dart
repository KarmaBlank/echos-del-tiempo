import 'dart:async';
import 'dart:math' as math;

import '../../../core/audio/sfx_catalog.dart';
import '../../../core/audio/sfx_service.dart';
import '../../../game_engine/data/biomes_catalog.dart';
import '../../../game_engine/rules/map_generator.dart';
import '../../../game_engine/rules/region_ambience_rules.dart';
import 'session_view.dart';

/// Quiet ambience while the local player fishes
/// (docs/specs/biome_regions.md § 7.2.3): every so often a very soft
/// breeze, a drip under a roof, or nothing, per place. The music duck is
/// in `SessionMusic`.
class FishingAmbiencePlayer {
  FishingAmbiencePlayer(this.sfx,
      {required this.fishing, double Function()? rand})
      : _rand = rand ?? math.Random().nextDouble;

  final SfxService sfx;
  final bool Function() fishing;
  final double Function() _rand;

  Timer? _timer;
  FishingAmbience _kind = FishingAmbience.none;

  /// Sounds played (tests).
  int played = 0;

  /// The ambience id of [kind] (`null` = silence).
  static String? soundOf(FishingAmbience kind) => switch (kind) {
        FishingAmbience.breeze => Sfx.ambBreeze,
        FishingAmbience.drip => Sfx.ambDrip,
        FishingAmbience.none => null,
      };

  void onView(SessionView? view) {
    final on = view != null && fishing();
    if (!on) {
      stop();
      return;
    }
    final place = view.session.place;
    var indoor = false;
    final me = view.me;
    if (me != null) {
      if (biomeLayout(place) case final lay?) {
        const ts = MapGenerator.tileSize;
        indoor = lay.isIndoor((me.x / ts).floor(), (me.y / ts).floor());
      }
    }
    _kind = RegionAmbienceRules.ambienceFor(place, indoor: indoor);
    _timer ??= _schedule();
  }

  Timer _schedule() => Timer(
          Duration(
              milliseconds:
                  (RegionAmbienceRules.nextGapSec(_rand()) * 1000).round()),
          () {
        _timer = null;
        final id = soundOf(_kind);
        if (id != null) {
          sfx.play(tunedSfx(id, vol: RegionAmbienceRules.ambienceVolume));
          played++;
        }
        if (fishing()) _timer = _schedule();
      });

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
