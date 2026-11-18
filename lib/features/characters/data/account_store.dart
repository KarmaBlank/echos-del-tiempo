import 'dart:convert';
import 'dart:io';

import '../../lobby/data/json_file_profile_store.dart';
import '../domain/account.dart';

/// Resultado de leer la cuenta: la cuenta y, si pasÃ³ algo que el
/// jugador tiene que saber (archivo daÃ±ado), el aviso.
class AccountLoad {
  const AccountLoad(this.account, {this.notice, this.migrated = false});

  final Account account;
  final String? notice;

  /// Se armÃ³ desde el `profile.json` viejo.
  final bool migrated;
}

/// DÃ³nde vive la cuenta (`account.json`). Ver docs/specs/characters.md Â§ 1.
abstract interface class AccountStore {
  /// La cuenta guardada (vacÃ­a si no hay). Puede tirar si el disco falla
  /// y ni siquiera se pudo resguardar el archivo: en ese caso quien la usa
  /// no debe escribir.
  Future<AccountLoad> load();

  Future<void> save(Account account);
}

/// En memoria (tests, plataformas sin carpeta de datos). Guarda el JSON
/// para probar tambiÃ©n la ida y vuelta.
class InMemoryAccountStore implements AccountStore {
  InMemoryAccountStore([Account? initial]) : _json = initial?.toJson();

  Map<String, Object?>? _json;
  int saves = 0;

  @override
  Future<AccountLoad> load() async => AccountLoad(
      _json == null ? Account() : Account.fromJson(_decode(_json!)));

  @override
  Future<void> save(Account account) async {
    saves++;
    _json = account.toJson();
  }

  /// Ida y vuelta por texto, como en disco.
  static Map<String, Object?> _decode(Map<String, Object?> json) =>
      jsonDecode(jsonEncode(json)) as Map<String, Object?>;
}


/// Otra ventana del juego ya tiene la cuenta: esta no debe escribir (cada
/// una pisaría lo de la otra con su copia vieja).
class AccountLockedException implements Exception {
  const AccountLockedException();

  @override
  String toString() => 'el juego ya está abierto en otra ventana';
}

/// `account.json` en la carpeta de datos del usuario, con la migración
/// desde `profile.json`, el resguardo de un archivo dañado, reintentos si
/// Windows tiene el archivo trabado un momento y una sola ventana dueña
/// de la cuenta (`ecos.lock`). Ver docs/specs/characters.md § 1.
class JsonFileAccountStore implements AccountStore {
  JsonFileAccountStore(
    this.directory, {
    DateTime Function()? now,
    this.retryDelays = defaultRetryDelays,
    this.singleInstance = false,
  }) : _now = now ?? DateTime.now;

  final Directory directory;
  final DateTime Function() _now;

  /// Esperas entre intentos de leer / escribir / renombrar (antivirus o
  /// indexador con el archivo abierto un instante).
  final List<Duration> retryDelays;

  /// Toma `ecos.lock` al cargar: una segunda ventana queda sin guardar.
  /// Lo prende [forPlatform] (la app); los tests lo eligen.
  final bool singleInstance;

  static const defaultRetryDelays = [
    Duration(milliseconds: 100),
    Duration(milliseconds: 300),
    Duration(milliseconds: 800),
  ];

  static const fileName = 'account.json';
  static const lockName = 'ecos.lock';

  RandomAccessFile? _lock;

  String _path(String name) =>
      '${directory.path}${Platform.pathSeparator}$name';

  File get file => File(_path(fileName));

  /// La copia completa que se escribe antes de reemplazar [file].
  File get tempFile => File('${file.path}.tmp');

  File get legacyFile => File(_path(JsonFileProfileStore.fileName));

  /// El store de la carpeta de datos del escritorio, o `null` (móvil, web).
  static JsonFileAccountStore? forPlatform() {
    String? dir;
    try {
      dir = JsonFileProfileStore.dataDirectory();
    } on UnsupportedError {
      dir = null;
    }
    return dir == null
        ? null
        : JsonFileAccountStore(Directory(dir), singleInstance: true);
  }

  /// Toma la cuenta para esta ventana. Tira [AccountLockedException] si
  /// otra ventana ya la tiene. El sistema la suelta al cerrarse el proceso.
  Future<void> _claim() async {
    if (!singleInstance || _lock != null) return;
    await directory.create(recursive: true);
    final raf = await File(_path(lockName)).open(mode: FileMode.write);
    try {
      await raf.lock(FileLock.exclusive);
    } on FileSystemException {
      await raf.close();
      throw const AccountLockedException();
    }
    _lock = raf;
  }

  /// Suelta `ecos.lock` (tests; en la app lo suelta el sistema al salir).
  Future<void> release() async {
    final l = _lock;
    _lock = null;
    if (l == null) return;
    try {
      await l.unlock();
    } on FileSystemException {
      // Ya suelto.
    }
    await l.close();
  }

  /// [op] con reintentos ante [FileSystemException]; tira la última.
  Future<T> _retry<T>(Future<T> Function() op) async {
    for (var i = 0;; i++) {
      try {
        return await op();
      } on FileSystemException {
        if (i >= retryDelays.length) rethrow;
        await Future<void>.delayed(retryDelays[i]);
      }
    }
  }

  static Account? _parse(List<int> bytes) {
    try {
      final json = jsonDecode(utf8.decode(bytes));
      if (json is Map<String, Object?>) return Account.fromJson(json);
    } catch (_) {
      // JSON roto, UTF-8 inválido o forma inesperada.
    }
    return null;
  }

  /// La copia `.tmp` si quedó completa (un guardado cortado justo entre
  /// escribirla y reemplazar `account.json`).
  Future<Account?> _fromTemp() async {
    try {
      final t = tempFile;
      if (!await t.exists()) return null;
      return _parse(await t.readAsBytes());
    } on FileSystemException {
      return null;
    }
  }

  static Future<bool> _newer(File a, File b) async {
    try {
      return (await a.lastModified()).isAfter(await b.lastModified());
    } on FileSystemException {
      return false;
    }
  }

  @override
  Future<AccountLoad> load() async {
    await _claim();
    final f = file;
    if (await f.exists()) {
      // Si no se puede leer (bloqueado, permisos) no es "dañado": tira y
      // quien carga queda sin escribir, sin tocar nada.
      final bytes = await _retry(f.readAsBytes);
      final account = _parse(bytes);
      final tmp = await _fromTemp();
      if (account != null) {
        // Una copia completa MÁS NUEVA que no llegó a reemplazarlo (el
        // reemplazo y el plan B fallaron): es el último guardado.
        if (tmp != null && await _newer(tempFile, f)) {
          await save(tmp);
          return AccountLoad(tmp);
        }
        return AccountLoad(account);
      }
      if (tmp != null) {
        await save(tmp);
        return AccountLoad(tmp,
            notice: 'La cuenta estaba dañada; se recuperó el último '
                'guardado completo.');
      }
      return _recoverCorrupt(f);
    }
    // Sin `account.json` pero con la copia completa: el reemplazo se cortó.
    final tmp = await _fromTemp();
    if (tmp != null) {
      await save(tmp);
      return AccountLoad(tmp);
    }
    // Migración: el perfil único de antes pasa a ser el personaje #1.
    final legacy = legacyFile;
    if (await legacy.exists()) {
      final p = await JsonFileProfileStore(legacy).load();
      if (p != null) {
        DateTime? when;
        try {
          when = await legacy.lastModified();
        } on FileSystemException {
          when = null;
        }
        final a = Account().add(p, now: when)!;
        final migrated = when == null ? a : a.touch(a.selectedId!, when);
        await save(migrated);
        return AccountLoad(migrated, migrated: true);
      }
    }
    return AccountLoad(Account());
  }

  /// Copia el archivo dañado (nunca se borra) y empieza una cuenta vacía.
  /// Si la copia falla, tira: no se pisa nada.
  Future<AccountLoad> _recoverCorrupt(File f) async {
    final t = _now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${t.year}${two(t.month)}${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
    var name = 'account.corrupt-$stamp.json';
    var n = 2;
    while (await File(_path(name)).exists()) {
      name = 'account.corrupt-$stamp-${n++}.json';
    }
    await f.copy(_path(name));
    final fresh = Account();
    await save(fresh);
    return AccountLoad(fresh,
        notice: 'No se pudo leer la cuenta (archivo dañado). Se guardó una '
            'copia en $name y se empezó una cuenta nueva.');
  }

  @override
  Future<void> save(Account account) async {
    final text = jsonEncode(account.toJson());
    await directory.create(recursive: true);
    // Escritura atómica: primero la copia completa, después el reemplazo.
    // Si se corta a la mitad queda el archivo viejo (o la copia, que
    // [load] recupera).
    final tmp = tempFile;
    await _retry(() => tmp.writeAsString(text, flush: true));
    try {
      await _retry(() => tmp.rename(file.path));
      return;
    } on FileSystemException {
      // Windows no deja reemplazar un archivo abierto por otro proceso
      // (antivirus, indexador). Plan B: escribir encima; la copia `.tmp`
      // queda completa hasta que esto termine.
    }
    await _retry(() => file.writeAsString(text, flush: true));
    try {
      await tmp.delete();
    } on FileSystemException {
      // Queda la copia (es igual al archivo): no molesta.
    }
  }
}
