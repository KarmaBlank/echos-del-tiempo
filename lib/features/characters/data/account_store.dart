import 'dart:convert';
import 'dart:io';

import '../../lobby/data/json_file_profile_store.dart';
import '../domain/account.dart';

/// Resultado de leer la cuenta: la cuenta y, si pasó algo que el
/// jugador tiene que saber (archivo dañado), el aviso.
class AccountLoad {
  const AccountLoad(this.account, {this.notice, this.migrated = false});

  final Account account;
  final String? notice;

  /// Se armó desde el `profile.json` viejo.
  final bool migrated;
}

/// Dónde vive la cuenta (`account.json`). Ver docs/specs/characters.md § 1.
abstract interface class AccountStore {
  /// La cuenta guardada (vacía si no hay). Puede tirar si el disco falla
  /// y ni siquiera se pudo resguardar el archivo: en ese caso quien la usa
  /// no debe escribir.
  Future<AccountLoad> load();

  Future<void> save(Account account);
}

/// En memoria (tests, plataformas sin carpeta de datos). Guarda el JSON
/// para probar también la ida y vuelta.
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

/// `account.json` en la carpeta de datos del usuario, con la migración
/// desde `profile.json` y el resguardo de un archivo dañado.
class JsonFileAccountStore implements AccountStore {
  JsonFileAccountStore(this.directory, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final Directory directory;
  final DateTime Function() _now;

  static const fileName = 'account.json';

  File get file => File('${directory.path}${Platform.pathSeparator}$fileName');

  File get legacyFile => File(
      '${directory.path}${Platform.pathSeparator}${JsonFileProfileStore.fileName}');

  /// El store de la carpeta de datos del escritorio, o `null` (móvil, web).
  static JsonFileAccountStore? forPlatform() {
    String? dir;
    try {
      dir = JsonFileProfileStore.dataDirectory();
    } on UnsupportedError {
      dir = null;
    }
    return dir == null ? null : JsonFileAccountStore(Directory(dir));
  }

  @override
  Future<AccountLoad> load() async {
    final f = file;
    if (await f.exists()) {
      // Si no se puede leer (bloqueado, permisos) no es "dañado": tira y
      // quien carga queda sin escribir, sin tocar nada.
      final bytes = await f.readAsBytes();
      Account? account;
      try {
        final json = jsonDecode(utf8.decode(bytes));
        if (json is Map<String, Object?>) account = Account.fromJson(json);
      } catch (_) {
        account = null; // JSON roto, UTF-8 inválido o forma inesperada
      }
      if (account != null) return AccountLoad(account);
      return _recoverCorrupt(f);
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
    while (await File('${directory.path}${Platform.pathSeparator}$name')
        .exists()) {
      name = 'account.corrupt-$stamp-${n++}.json';
    }
    await f.copy('${directory.path}${Platform.pathSeparator}$name');
    final fresh = Account();
    await save(fresh);
    return AccountLoad(fresh,
        notice: 'No se pudo leer la cuenta (archivo dañado). Se guardó una '
            'copia en $name y se empezó una cuenta nueva.');
  }

  @override
  Future<void> save(Account account) async {
    await directory.create(recursive: true);
    // Escritura atómica: si se corta a la mitad queda el archivo viejo.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(account.toJson()), flush: true);
    await tmp.rename(file.path);
  }
}
