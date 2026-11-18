import 'dart:async';

import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/profile_store.dart';
import '../domain/account.dart';
import 'account_store.dart';

/// Dueño de la cuenta en memoria: la lee una vez del [store], aplica los
/// cambios en orden y escribe la cuenta entera después de cada uno. El
/// título y la sesión (por [SelectedCharacterProfileStore]) comparten la
/// misma instancia. Ver docs/specs/characters.md § 1.
class AccountRepository {
  AccountRepository(this.store, {DateTime Function()? now})
      : now = now ?? DateTime.now;

  final AccountStore store;
  final DateTime Function() now;

  Account? _account;
  Future<Account>? _loading;
  Future<void> _writes = Future.value();
  final _changes = StreamController<Account>.broadcast();

  /// Aviso de la carga (archivo dañado, disco), para mostrar en el título.
  String? notice;

  /// No se escribe a disco (la lectura falló sin poder resguardar el
  /// archivo: no se lo pisa).
  bool readOnly = false;

  /// La cuenta ya cargada, o `null` antes de [load].
  Account? get current => _account;

  /// Cada cambio aplicado (después de [update]).
  Stream<Account> get changes => _changes.stream;

  Future<Account> load() {
    final a = _account;
    if (a != null) return Future.value(a);
    return _loading ??= _read();
  }

  Future<Account> _read() async {
    try {
      final l = await store.load();
      notice = l.notice;
      _account ??= l.account;
    } catch (e) {
      readOnly = true;
      notice = 'No se pudo leer la cuenta ($e). Esta vez no se guardará '
          'nada para no pisar el archivo.';
      _account ??= Account();
    }
    return _account!;
  }

  /// Aplica [change] a la cuenta actual y la guarda. Los cambios se
  /// aplican y se escriben en el orden en que llegan. Tira si falla la
  /// escritura (la cuenta en memoria queda cambiada igual).
  Future<Account> update(Account Function(Account) change) async {
    await load();
    final next = change(_account!);
    if (identical(next, _account)) return next;
    _account = next;
    _changes.add(next);
    if (readOnly) return next;
    final write = _writes.then((_) => store.save(next));
    _writes = write.catchError((Object _) {});
    await write;
    return next;
  }

  /// Espera a que terminen las escrituras pendientes (tests, salida).
  Future<void> flush() => _writes;
}

/// `ProfileStore` de la sesión sobre la cuenta: lee y escribe el
/// personaje **elegido**. Así la sala y la red no saben que hay varios.
class SelectedCharacterProfileStore implements ProfileStore {
  SelectedCharacterProfileStore(this.repository);

  final AccountRepository repository;

  @override
  Future<PlayerProfile?> load() async =>
      (await repository.load()).selected?.profile;

  @override
  Future<void> save(PlayerProfile profile) async {
    final when = repository.now();
    await repository.update((a) {
      final sel = a.selectedId;
      if (sel != null) return a.replace(sel, profile, lastPlayed: when);
      // Sin personajes (caso borde): se agrega si hay lugar.
      final added = a.add(profile, now: when);
      return added == null ? a : added.touch(added.selectedId!, when);
    });
  }
}
