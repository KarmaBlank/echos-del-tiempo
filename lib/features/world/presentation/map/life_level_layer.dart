import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/data/life_tree_catalog.dart';
import 'farm_layer.dart' show MapText;
import 'map_themes.dart';

/// Una subida de nivel de oficio vista en el estado de la sala.
class LifeLevelUp {
  const LifeLevelUp(this.playerId, this.name, this.kind, this.level, this.t0);
  final String playerId, name;
  final LifeSkillKind kind;
  final int level;
  final double t0;

  /// "Pescador N" / "Granjero N".
  String get title =>
      '${kind == LifeSkillKind.pesca ? 'Pescador' : 'Granjero'} $level';
}

/// Cartel flotante "¡Subiste de nivel!" sobre quien sube Pesca o Cultivo
/// (farming.md § 2.6). Sale del perfil que manda el host: cada cliente
/// compara el nivel de oficio de cada jugador con el último que vio, así
/// lo ven todos sin eventos nuevos (mismo protocolo).
class MapLifeLevelLayer {
  /// Duración del cartel (ms).
  static const ms = 2500.0;

  final _last = <String, (int, int)>{};
  final _signs = <LifeLevelUp>[];

  List<LifeLevelUp> get signs => List.unmodifiable(_signs);

  /// Mira los niveles actuales de [playerId]; devuelve las subidas nuevas
  /// (la primera vez que lo ve, solo lo anota).
  List<LifeLevelUp> observe(
      String playerId, String name, int fish, int farm, double t) {
    final prev = _last[playerId];
    _last[playerId] = (fish, farm);
    if (prev == null) return const [];
    final out = [
      if (fish > prev.$1)
        LifeLevelUp(playerId, name, LifeSkillKind.pesca, fish, t),
      if (farm > prev.$2)
        LifeLevelUp(playerId, name, LifeSkillKind.cultivo, farm, t),
    ];
    // Si subió los dos a la vez, el segundo sale un poco después.
    for (var i = 0; i < out.length; i++) {
      final u = out[i];
      _signs.add(LifeLevelUp(u.playerId, u.name, u.kind, u.level, t + i * 900));
    }
    return out;
  }

  /// Dibuja los carteles arriba de cada personaje (encima del nombre).
  void draw(Canvas c, double t, String localId,
      (double, double)? Function(String) posOf, MapText text) {
    _signs.removeWhere((s) => t - s.t0 > ms);
    for (final s in _signs) {
      final k = (t - s.t0) / ms;
      if (k < 0) continue;
      final pos = posOf(s.playerId);
      if (pos == null) continue;
      final fade = k < 0.75 ? 1.0 : 1 - (k - 0.75) / 0.25;
      final x = pos.$1, y = pos.$2 - 50 - k * 14;
      final box = Rect.fromLTRB(x - 58, y - 10, x + 58, y + 11);
      c.drawRect(box.inflate(1),
          Paint()..color = LifeLevelPalette.frame.withValues(alpha: fade));
      c.drawRect(
          box,
          Paint()
            ..color = LifeLevelPalette.back
                .withValues(alpha: LifeLevelPalette.back.a * fade));
      final line1 = s.playerId == localId
          ? '¡Subiste de nivel!'
          : '${s.name} subió de nivel';
      text(line1, x, y, LifeLevelPalette.title.withValues(alpha: fade), 6);
      text(
          s.title,
          x,
          y + 8,
          (s.kind == LifeSkillKind.pesca
                  ? LifeLevelPalette.fish
                  : LifeLevelPalette.farm)
              .withValues(alpha: fade),
          6);
    }
  }
}
