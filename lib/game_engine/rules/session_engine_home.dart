part of 'session_engine.dart';

// The player house (docs/specs/player_house.md): beds and sleeping. The
// host decides everything; skipping time runs the normal world step
// (`_Op.tick`) second by second, never just moves the clock.

extension _HomeOp on _Op {
  /// `sleep`: into a bed (in reach of one, inside the house) or out of it.
  bool sleep(SessionPlayer p, bool on) {
    if (p.isCompanion) return false;
    if (!on) {
      if (!p.inBed) return false;
      p.inBed = false;
      return true;
    }
    if (!HomeInteriorRules.isHome(s.place) ||
        s.mode != SessionMode.lobby ||
        p.inBed ||
        HomeInteriorRules.bedNear(p.x, p.y) == null) {
      return false;
    }
    p.inBed = true;
    p.moving = false;
    p.fishLine = null;
    say('${p.name} se acostó.');
    return true;
  }

  /// Out of the house, or walked away from the bed, means out of bed
  /// (host tick).
  void leaveBedsOutside() {
    final home = HomeInteriorRules.isHome(s.place);
    for (final p in players) {
      if (!p.inBed) continue;
      if (!home || HomeInteriorRules.bedNear(p.x, p.y) == null) {
        p.inBed = false;
      }
    }
  }

  /// One room (no instances, or tests): everyone in bed sleeps now; else
  /// the wait count for the HUD.
  void sleepCheck() {
    final (x, n) = HomeInteriorRules.sleepers(players);
    if (x == 0) {
      s.sleepWait = null;
      return;
    }
    if (x < n) {
      s.sleepWait = (x, n);
      return;
    }
    fastForward(HomeInteriorRules.skipSeconds(s.town.sky));
  }

  /// Advances the world [seconds] with the normal step, 1 s at a time
  /// (crops, animals, helpers, weather, residents, events, timers), then
  /// wakes everyone up.
  void fastForward(double seconds) {
    final toMorning = SkyRules.isNight(s.town.sky);
    var left = seconds;
    while (left > 1e-9) {
      final dt = math.min(1.0, left);
      tick(dt);
      left -= dt;
    }
    for (final p in players) {
      p.inBed = false;
    }
    s.sleepWait = null;
    events.add(SleptEvent(toMorning: toMorning));
    say(toMorning
        ? 'Durmieron hasta la mañana.'
        : 'Descansaron hasta que cayó la noche.');
  }
}
