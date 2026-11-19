import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/ecos_log.dart';
import '../../../game_engine/models/build_plan.dart';
import '../../characters/data/account_repository.dart';
import '../../characters/domain/account.dart';
import '../../characters/presentation/characters_providers.dart';

/// El plan de build del personaje elegido (`null` = sin personaje).
class BuildPlanState {
  const BuildPlanState(this.characterId, this.plan, [this.slots = const {}]);

  static const none = BuildPlanState(null, BuildPlan.empty);

  final String? characterId;
  final BuildPlan plan;

  /// Los planes de las demás ranuras de la cuenta (los compañeros de la
  /// party jugando solo; solo_party.md § 6.2).
  final Map<String, BuildPlan> slots;

  /// El plan de la ranura [characterId] (`null` o la elegida = [plan]).
  BuildPlan planFor(String? characterId) =>
      characterId == null || characterId == this.characterId
          ? plan
          : slots[characterId] ?? BuildPlan.empty;
}

/// Dueño del plan del personaje **elegido** en la cuenta
/// (docs/specs/build_planner.md § 1): lo lee del slot, lo sigue si
/// cambia la cuenta (título, otra pantalla) y guarda cada edición.
class BuildPlanController extends StateNotifier<BuildPlanState> {
  BuildPlanController(this.repository) : super(BuildPlanState.none) {
    final now = repository.current;
    if (now != null) _sync(now);
    unawaited(repository.load().then((a) {
      if (mounted) _sync(a);
    }).catchError((Object _) {}));
    _sub = repository.changes.listen(_sync);
  }

  final AccountRepository repository;
  StreamSubscription<Account>? _sub;

  void _sync(Account a) {
    final sel = a.selected;
    final slots = {
      for (final c in a.characters)
        if (c.id != sel?.id && c.plan != null) c.id: c.plan!,
    };
    final next = BuildPlanState(sel?.id, sel?.plan ?? BuildPlan.empty, slots);
    if (next.characterId == state.characterId &&
        next.plan == state.plan &&
        _sameSlots(next.slots, state.slots)) {
      return;
    }
    state = next;
  }

  static bool _sameSlots(Map<String, BuildPlan> a, Map<String, BuildPlan> b) =>
      a.length == b.length &&
      a.entries
          .every((e) => identical(b[e.key], e.value) || b[e.key] == e.value);

  /// Plan de otro personaje de la cuenta (pantalla del título).
  BuildPlan planOf(String characterId) =>
      repository.current?.byId(characterId)?.plan ?? BuildPlan.empty;

  /// Guarda [plan] en el elegido (o en [characterId]).
  Future<void> save(BuildPlan plan, {String? characterId}) async {
    final id = characterId ?? state.characterId;
    if (id == null) {
      // Sin personaje en la cuenta (tests, caso borde): solo en memoria.
      state = BuildPlanState(null, plan);
      return;
    }
    if (id == state.characterId) {
      state = BuildPlanState(id, plan, state.slots);
    } else {
      state = BuildPlanState(state.characterId, state.plan, {
        ...state.slots,
        id: plan,
      });
    }
    try {
      await repository
          .update((a) => a.withPlan(id, plan.isEmpty ? null : plan));
    } catch (e) {
      // El repositorio reintenta solo; el plan ya quedó en memoria.
      EcosLog.error('Guardado del plan de build', e);
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }
}

final buildPlanProvider =
    StateNotifierProvider<BuildPlanController, BuildPlanState>(
        (ref) => BuildPlanController(ref.watch(accountRepositoryProvider)));
