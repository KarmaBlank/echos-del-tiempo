import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../game_engine/models/world_save.dart';
import '../data/world_store.dart';

/// Dónde se guardan los mundos; sin registro (tests), en memoria.
final worldStoreProvider = Provider<WorldStore>((ref) =>
    sl.isRegistered<WorldStore>() ? sl<WorldStore>() : InMemoryWorldStore());

/// Los mundos de la cuenta (town_loop.md § 11c). `null` mientras carga.
final worldBookProvider =
    StateNotifierProvider<WorldBookController, WorldBook?>(
        (ref) => WorldBookController(ref.watch(worldStoreProvider)));

/// Lista de mundos con guardado: crear, renombrar, borrar, elegir y
/// guardar el pueblo del mundo jugado.
class WorldBookController extends StateNotifier<WorldBook?> {
  WorldBookController(this.store, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(null) {
    loading = _load();
  }

  final WorldStore store;
  final DateTime Function() _now;
  late final Future<void> loading;

  Future<void> _load() async {
    try {
      final b = await store.load();
      if (mounted) state = b;
    } catch (_) {
      // Sin disco: un mundo en memoria esta vez.
      if (mounted) {
        state = WorldBook().create(
            WorldBook.firstWorldName, WorldLabel.cooperativo,
            now: _now(), id: 'w1');
      }
    }
  }

  Future<void> _set(WorldBook b) async {
    state = b;
    try {
      await store.save(b);
    } catch (_) {}
  }

  Future<void> create(String name, WorldLabel label) async {
    await loading;
    final now = _now();
    await _set((state ?? WorldBook())
        .create(name, label, now: now, id: newWorldId(now)));
  }

  Future<void> rename(String id, String name) async {
    await loading;
    if (state case final b?) await _set(b.rename(id, name));
  }

  Future<void> remove(String id) async {
    await loading;
    if (state case final b?) await _set(b.remove(id));
  }

  Future<void> select(String id) async {
    await loading;
    if (state case final b?) await _set(b.select(id));
  }

  /// Guarda el pueblo del mundo [id] (al volver de misión, al salir).
  void saveTown(String id, TownState town) {
    final b = state;
    final w = b?.byId(id);
    if (b == null || w == null) return;
    unawaited(_set(b.put(w.copyWith(town: town))));
  }
}
