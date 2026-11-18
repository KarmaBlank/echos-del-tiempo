import 'dart:async';

import '../../../core/persistence/ecos_log.dart';
import '../../../game_engine/models/atlas.dart';
import '../../../game_engine/models/atlas_store.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/profile_store.dart';
import '../domain/account.dart';
import 'account_store.dart';

/// Dueño de la cuenta en memoria: la lee una vez del [store], aplica los
/// cambios en orden y escribe la cuenta entera después de cada uno. El
/// título y la sesión (por [SelectedCharacterProfileStore]) comparten la
/// misma instancia: no importa si se juega solo, como anfitrión o como
/// cliente, es el mismo personaje del mismo archivo. Si una escritura
/// falla se reintenta sola (con espera creciente) hasta que salga, y el
/// error queda en [saveError] para avisarle al jugador. Ver
/// docs/specs/characters.md § 1.
class AccountRepository {
  AccountRepository(
    this.store, {
    DateTime Function()? now,
    this.retryDelays = defaultRetryDelays,
  }) : now = now ?? DateTime.now;

  final AccountStore store;
  final DateTime Function() now;

  /// Esperas entre reintentos de una escritura fallida (la última se
  /// repite).
  final List<Duration> retryDelays;

  static const defaultRetryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];

  Account? _account;
  Future<Account>? _loading;
  Future<void> _writes = Future.value();
  final _changes = StreamController<Account>.broadcast();
  final _status = StreamController<String?>.broadcast();

  /// La última cuenta que llegó a disco.
  Account? _written;
  Timer? _retry;
  int _failures = 0;

  /// Aviso de la carga (archivo dañado, disco, otra ventana), para
  /// mostrar en el título.
  String? notice;

  /// No se escribe a disco (la lectura falló sin poder resguardar el
  /// archivo, u otra ventana del juego ya tiene la cuenta: no se la pisa).
  bool readOnly = false;

  /// El último guardado falló y todavía no salió un reintento; `null` si
  /// todo está en disco.
  String? get saveError => _saveError;
  String? _saveError;

  /// Cada cambio de [saveError] (`null` = se pudo guardar de nuevo).
  Stream<String?> get saveStatus => _status.stream;

  /// Hay cambios en memoria que todavía no llegaron a disco.
  bool get dirty => !readOnly && !identical(_written, _account);

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
      if (l.notice != null) EcosLog.error('Carga: ${l.notice}');
      _account ??= l.account;
      _written = _account;
      EcosLog.info('Cuenta cargada (${_account!.characters.length} '
          'personajes${l.migrated ? ', migrada de profile.json' : ''})');
    } on AccountLockedException {
      readOnly = true;
      notice = 'Ecos del Tiempo ya está abierto en otra ventana: esta no '
          'guarda nada para no pisar tu progreso. Cierra esta y sigue en '
          'la otra (o cierra todas y vuelve a abrir el juego).';
      EcosLog.error('Carga: la cuenta ya está abierta en otra ventana');
      _account ??= Account();
    } catch (e) {
      readOnly = true;
      notice = 'No se pudo leer la cuenta ($e). Esta vez no se guardará '
          'nada para no pisar el archivo.';
      EcosLog.error('Carga', e);
      _account ??= Account();
    }
    return _account!;
  }

  /// Aplica [change] a la cuenta actual y la guarda. Los cambios se
  /// aplican y se escriben en el orden en que llegan. Tira si falla la
  /// escritura (la cuenta en memoria queda cambiada igual y se reintenta
  /// sola).
  Future<Account> update(Account Function(Account) change) async {
    await load();
    final next = change(_account!);
    if (identical(next, _account)) return next;
    _account = next;
    _changes.add(next);
    if (readOnly) return next;
    await _write(next);
    return next;
  }

  /// Escribe [a] después de las escrituras pendientes. Tira si falla.
  Future<void> _write(Account a) {
    final write = _writes.then((_) => store.save(a));
    _writes = write.then((_) => _saved(a), onError: (Object e) => _failed(e));
    return write;
  }

  void _saved(Account a) {
    _written = a;
    if (!identical(a, _account)) return; // hay otra en camino
    _retry?.cancel();
    _retry = null;
    _failures = 0;
    if (_saveError != null) {
      EcosLog.info('Guardado: se pudo guardar de nuevo');
      _setError(null);
    }
  }

  void _failed(Object e) {
    EcosLog.error('Guardado (intento ${_failures + 1})', e);
    _setError('No se pudo guardar ($e). Se sigue intentando.');
    if (_retry != null) return;
    final wait = retryDelays.isEmpty
        ? Duration.zero
        : retryDelays[_failures.clamp(0, retryDelays.length - 1)];
    _failures++;
    _retry = Timer(wait, () {
      _retry = null;
      final a = _account;
      if (a != null && dirty) unawaited(_write(a).catchError((Object _) {}));
    });
  }

  void _setError(String? e) {
    if (_saveError == e) return;
    _saveError = e;
    if (!_status.isClosed) _status.add(e);
  }

  /// Espera las escrituras pendientes y, si quedó algo sin guardar,
  /// intenta una vez más (salida de la app, tests). Nunca tira.
  Future<void> flush() async {
    await _writes;
    final a = _account;
    if (a == null || !dirty) return;
    _retry?.cancel();
    _retry = null;
    try {
      await _write(a);
    } on Object {
      // Queda en [saveError] y en el registro.
    }
  }
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

/// `AtlasStore` sobre la cuenta: el Atlas es uno solo para todos los
/// personajes (docs/specs/ecos_atlas.md § 5).
class AccountAtlasStore implements AtlasStore {
  AccountAtlasStore(this.repository);

  final AccountRepository repository;

  @override
  Future<AtlasProgress> load() async => (await repository.load()).atlas;

  @override
  Future<void> save(AtlasProgress atlas) async {
    await repository.update((a) => a.withAtlas(atlas));
  }
}
