part of 'session_engine.dart';

// Pesca y comerciante en la sala (docs/specs/fishing.md § 6). El
// minijuego corre en cada cliente; el anfitrión tira el pez al clavar,
// valida el resultado (picada pendiente, tiempos mínimos, caña) y otorga.

/// Picada pendiente de un jugador (solo en el motor del anfitrión).
class FishPending {
  FishPending(this.fish, this.at);
  final FishCatch fish;
  final double at;
}

/// Estado de pesca del anfitrión (no viaja en el snapshot).
class FishingHostState {
  final pending = <String, FishPending>{};
  final lastCast = <String, double>{};
  final nextAuto = <String, double>{};

  /// XP de personaje ganada pescando en esta estadía en el pueblo.
  final charXp = <String, int>{};

  /// Quién ya avisó en el chat que se puso a pescar (por estadía).
  final announced = <String>{};

  /// Especies del lago del pueblo del mundo (`TownState.lake`).
  List<String> lake = kTownLakeDefault;

  void newStay() {
    pending.clear();
    charXp.clear();
    announced.clear();
  }
}

extension _FishingOp on _Op {
  FishingHostState get _f => e.fishing;
  TuningDef get _ft => FishingRules.t;

  bool _inTown(SessionPlayer p) =>
      s.mode == SessionMode.lobby && s.run == null && !p.isCompanion;

  bool fishingAction(SessionPlayer p, SessionAction a) {
    switch (a) {
      case FishBiteAction(:final power):
        return _fishBite(p, power);
      case FishResultAction(:final success):
        return _fishResult(p, success);
      case AutoFishAction():
        return _autoFish(p);
      case SellFishAction(:final species, :final materials):
        if (!_inTown(p)) return false;
        final r = FishingRules.sell(p.profile,
            species: species, materials: materials);
        if (r == null) return false;
        _profileChange(p, r.profile);
        say('${p.name} vendió ${r.sold} pescado${r.sold == 1 ? '' : 's'}'
            '${r.credits > 0 ? ' por ${r.credits} de oro' : ''}'
            '${r.esquirlas > 0 ? '${r.credits > 0 ? ' y' : ' por'} '
                '${r.esquirlas} Esquirla${r.esquirlas == 1 ? '' : 's'}' : ''}.');
        return true;
      case ExchangeFishAction(:final species):
        if (!_inTown(p)) return false;
        if (!_profileChange(
            p, FishingRules.exchangeLegendary(p.profile, species))) {
          return false;
        }
        say('${p.name} canjeó ${kFish[species]!.name} por materiales raros.');
        return true;
      case BuyRodAction(:final rodId):
        if (!_inTown(p)) return false;
        if (!_profileChange(p, FishingRules.buyRod(p.profile, rodId))) {
          return false;
        }
        say('${p.name} compró ${kRods[rodId]!.name}.');
        return true;
      case EquipRodAction(:final rodId):
        return _inTown(p) &&
            _profileChange(p, FishingRules.equipRod(p.profile, rodId));
      default:
        return false;
    }
  }

  bool _fishBite(SessionPlayer p, double power) {
    if (!_inTown(p) || !FishingRules.plausible(p.profile)) return false;
    if (WorldRules.townSpot(p.x, p.y) != TownSpot.fishing) return false;
    final last = _f.lastCast[p.id];
    if (last != null && s.time - last < _ft.d('minCastSec')) return false;
    _f.lastCast[p.id] = s.time;
    final bonus = FishingRules.rodBonus(p.profile);
    final rare =
        bonus.rare + _ft.d('distanceBonus') * power.clamp(0.0, 1.0);
    final fish = FishingRules.roll(_rand, _f.lake,
        rareBonus: rare, pity: p.profile.life.pity);
    _f.pending[p.id] = FishPending(fish, s.time);
    events.add(FishBiteEvent(p.id, fish.species, fish.sizeCm));
    if (_f.announced.add(p.id)) say('${p.name} se puso a pescar.');
    return true;
  }

  bool _fishResult(SessionPlayer p, bool success) {
    final pend = _f.pending[p.id];
    if (pend == null || !_inTown(p)) return false;
    if (success && s.time - pend.at < _ft.d('minReelSec')) return false;
    _f.pending.remove(p.id);
    if (success) _grantFish(p, pend.fish);
    return true;
  }

  bool _autoFish(SessionPlayer p) {
    if (!_inTown(p)) return false;
    final next = _f.nextAuto[p.id];
    if (next != null && s.time < next) return false;
    _f.nextAuto[p.id] = s.time + _ft.d('autoCooldownSec');
    final bonus = FishingRules.rodBonus(p.profile);
    final n = math.max(1, _ft.i('autoCount'));
    for (var i = 0; i < n; i++) {
      final fish = FishingRules.roll(_rand, _f.lake,
          rareBonus: bonus.rare, auto: true);
      _grantFish(p, fish, auto: true);
    }
    return true;
  }

  void _grantFish(SessionPlayer p, FishCatch c, {bool auto = false}) {
    final lvl0 = FishingRules.level(p.profile);
    var prof = FishingRules.addCatch(p.profile, c, auto: auto);
    // XP de personaje con tope por estadía (town_loop.md § 11c).
    final used = _f.charXp[p.id] ?? 0;
    final cxp = math.min(FishingRules.charXp(c, auto: auto),
        math.max(0, _ft.i('charXpCap') - used));
    if (cxp > 0) {
      _f.charXp[p.id] = used + cxp;
      final g = rules.gainXp(prof, cxp);
      prof = g.profile;
      if (g.levelsGained > 0) events.add(LevelUpEvent(p.id, prof.level));
    }
    _profileChange(p, prof, gain: true);
    events.add(FishCaughtEvent(p.id, c.species, c.sizeCm, auto: auto));
    say('${p.name} pescó ${c.def.name} (${c.sizeCm} cm, ${c.rarity.label})'
        '${auto ? ' con la red' : ''}.');
    final lvl1 = FishingRules.level(prof);
    if (lvl1 > lvl0) say('${p.name} subió Pesca a nivel $lvl1.');
  }
}
