import '../../../game_engine/models/build_plan.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/build_plan_rules.dart';

/// Tope de avisos de build (docs/specs/build_planner.md § 5): como mucho
/// [max] cada [windowS] segundos; lo que sobra se junta en una línea
/// "Build: +N avances".
class BuildNoticeThrottle {
  BuildNoticeThrottle({this.max = 3, this.windowS = 4});

  final int max;
  final double windowS;
  final _sent = <double>[];

  /// Los textos que salen ahora de [notices] (en el segundo [now]).
  List<String> admit(List<BuildNotice> notices, double now) {
    _sent.removeWhere((t) => now - t >= windowS);
    final room = max - _sent.length;
    if (notices.isEmpty || room <= 0) return const [];
    final out = <String>[];
    if (notices.length <= room) {
      out.addAll(notices.map((n) => n.text));
    } else {
      // Primero las metas hechas; lo demás se resume.
      final sorted = [
        ...notices.where((n) => n.done),
        ...notices.where((n) => !n.done),
      ];
      out.addAll(sorted.take(room - 1).map((n) => n.text));
      out.add('Build: +${sorted.length - (room - 1)} avances');
    }
    for (var i = 0; i < out.length; i++) {
      _sent.add(now);
    }
    return out;
  }
}

/// Sigue el progreso del plan del jugador local y dice qué avisar en cada
/// perfil nuevo (§ 5). Puro: sin Flutter ni red. Un plan o un personaje
/// distinto (u el primer perfil) solo toma una base nueva, sin avisar.
class BuildTracker {
  BuildTracker(this.rules, {BuildNoticeThrottle? throttle})
      : throttle = throttle ?? BuildNoticeThrottle();

  final BuildPlanRules rules;
  final BuildNoticeThrottle throttle;

  BuildPlan? _plan;
  PlayerProfile? _profile;
  BuildProgress? _last;

  /// Progreso del último perfil visto.
  BuildProgress? get last => _last;

  /// Olvida la base (el próximo perfil no avisa nada).
  void reset() {
    _plan = null;
    _profile = null;
    _last = null;
  }

  /// Avisos que produce [p] con [plan] (ya pasados por el tope).
  List<String> observe(BuildPlan plan, PlayerProfile? p, double now) {
    if (p == null) return const [];
    if (identical(p, _profile) && plan == _plan) return const [];
    final prev = _last;
    final samePlan = plan == _plan;
    final sameChar = _profile != null &&
        _profile!.classId == p.classId &&
        _profile!.name == p.name;
    _plan = plan;
    _profile = p;
    _last = plan.goalCount == 0 ? BuildProgress.none : rules.evaluate(plan, p);
    if (prev == null || !samePlan || !sameChar || plan.goalCount == 0) {
      return const [];
    }
    return throttle.admit(BuildPlanRules.diff(prev, _last!), now);
  }
}
