/// Versión semántica `MAYOR.MENOR.PARCHE[-pre][+build]` para comparar el
/// tag de un release de GitHub (`v0.2.0`) con la versión instalada. Ver
/// docs/specs/distribution.md § "Versionado".
///
/// Reglas de orden (SemVer 2.0): números de izquierda a derecha; una
/// versión con prerelease (`1.0.0-beta.1`) es MENOR que la misma sin
/// prerelease (`1.0.0`); los identificadores del prerelease se comparan
/// uno a uno (numéricos como número, el resto como texto, numérico <
/// texto). El `+build` se ignora.
class SemVer implements Comparable<SemVer> {
  const SemVer(this.major, this.minor, this.patch, [this.prerelease = const []]);

  final int major;
  final int minor;
  final int patch;

  /// Identificadores del prerelease (`beta.1` → `['beta', '1']`); vacío
  /// en una versión final.
  final List<String> prerelease;

  bool get isPrerelease => prerelease.isNotEmpty;

  static final _pattern = RegExp(
      r'^[vV]?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
      r'(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?'
      r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$');

  /// `v1.2.3`, `1.2.3`, `1.2.3-rc.1`, `1.2.3+4`. Basura o vacío → `null`
  /// (nunca lanza: el tag lo escribe una persona).
  static SemVer? tryParse(String? text) {
    if (text == null) return null;
    final m = _pattern.firstMatch(text.trim());
    if (m == null) return null;
    final major = int.tryParse(m.group(1)!);
    final minor = int.tryParse(m.group(2)!);
    final patch = int.tryParse(m.group(3)!);
    if (major == null || minor == null || patch == null) return null;
    final pre = m.group(4);
    return SemVer(
        major, minor, patch, pre == null ? const [] : pre.split('.'));
  }

  @override
  int compareTo(SemVer other) {
    for (final (a, b) in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      if (a != b) return a.compareTo(b);
    }
    if (prerelease.isEmpty || other.prerelease.isEmpty) {
      // Final > prerelease; dos finales iguales → 0.
      return other.prerelease.length.sign - prerelease.length.sign;
    }
    final n = prerelease.length < other.prerelease.length
        ? prerelease.length
        : other.prerelease.length;
    for (var i = 0; i < n; i++) {
      final c = _compareIdent(prerelease[i], other.prerelease[i]);
      if (c != 0) return c;
    }
    return prerelease.length.compareTo(other.prerelease.length);
  }

  static int _compareIdent(String a, String b) {
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null) return -1;
    if (nb != null) return 1;
    return a.compareTo(b);
  }

  bool operator >(SemVer other) => compareTo(other) > 0;
  bool operator <(SemVer other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) => other is SemVer && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, prerelease.join('.'));

  @override
  String toString() =>
      '$major.$minor.$patch${isPrerelease ? '-${prerelease.join('.')}' : ''}';
}
