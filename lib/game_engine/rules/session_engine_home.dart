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
        HomeInteriorRules.bedNear(HomeInteriorRules.layoutOf(s), p.x, p.y) ==
            null) {
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
      if (!home ||
          HomeInteriorRules.bedNear(HomeInteriorRules.layoutOf(s), p.x, p.y) ==
              null) {
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

extension _HomeEditOp on _Op {
  /// EDITAR CASA (player_house.md § 8): only inside the house, in the
  /// lobby, and only the player whose layout the room shows.
  bool homeEdit(SessionPlayer p, HomeEditAction a) {
    if (p.isCompanion ||
        !HomeInteriorRules.isHome(s.place) ||
        s.mode != SessionMode.lobby ||
        HomeInteriorRules.layoutOwner(s) != p.id) {
      return false;
    }
    final prof = p.profile;
    final PlayerProfile? next = switch (a.op) {
      HomeOp.place => a.id == null || a.x == null || a.y == null
          ? null
          : HomeInteriorRules.placePiece(prof, s.town, a.id!, a.x!, a.y!)
              .profile,
      HomeOp.move => a.uid == null || a.x == null || a.y == null
          ? null
          : HomeInteriorRules.move(prof, a.uid!, a.x!, a.y!),
      HomeOp.remove =>
        a.uid == null ? null : HomeInteriorRules.remove(prof, a.uid!),
      HomeOp.surface => a.id == null
          ? null
          : HomeInteriorRules.surface(prof, s.town, a.id!).profile,
      HomeOp.paint => a.n == null ? null : HomeInteriorRules.paint(prof, a.n!),
      HomeOp.rack => a.uid == null
          ? null
          : HomeInteriorRules.rack(prof, a.uid!, a.weapons),
    };
    if (next == null) return false;
    _profileChange(p, next);
    // Whoever lay in a bed that moved or went away gets up.
    leaveBedsOutside();
    return true;
  }
}
