// Chequeo del grafo de dependencias del monorepo (docs/specs/monorepo.md § 3).
//
// Stub del PR 1: todavía no hay paquetes en `packages/`, así que no hay
// aristas que validar. A partir del PR 2 este script recorre los
// `pubspec.yaml` del workspace y falla (exit 1) si aparece una dependencia
// prohibida (paquete puro que declara `flutter`, paquete que importa
// `games/*` o `apps/*`, `adventures_rules` <-> `paradox_rules`).
//
// Uso: `dart run melos run arch` (o `dart run tool/check_deps.dart`).
import 'dart:io';

void main() {
  final packages = Directory('packages');
  if (!packages.existsSync()) {
    stdout.writeln('check_deps: sin packages/ todavía (PR 1), nada que validar.');
    return;
  }
  stdout.writeln('check_deps: TODO (PR 2) validar el grafo de § 3.');
}
