import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../../core/settings/graphics.dart';
import 'arena_spec.dart';

/// Colores de una arena. Son arte (como los de `MapTheme`): copian la
/// paleta de tiles de cada zona y no pasan por `RetroPalette`.
class ArenaPalette {
  const ArenaPalette({
    required this.sky,
    required this.sky2,
    required this.wall,
    required this.wall2,
    required this.floor,
    required this.floor2,
    required this.joint,
    required this.accent,
    required this.light,
    this.open = false,
  });

  /// Fondo de arriba (cielo / techo / vacío) y su degradado.
  final Color sky, sky2;

  /// Muro / fondo cercano y su detalle.
  final Color wall, wall2;

  /// Piso y su detalle.
  final Color floor, floor2;

  /// Juntas, grietas y sombras del piso.
  final Color joint;

  /// Color propio de la zona (estandartes, runas).
  final Color accent;

  /// Luz ambiente (braseros, anillo, resplandor).
  final Color light;

  /// Al aire libre (el fondo es cielo o vacío, no un muro).
  final bool open;
}

/// Paleta de cada arena (docs/specs/battle_presentation.md § "Arenas").
const Map<ArenaTheme, ArenaPalette> kArenaPalettes = {
  ArenaTheme.pradera: ArenaPalette(
    sky: Color(0xFF5FB4F0), sky2: Color(0xFFBDE8FF),
    wall: Color(0xFF1F5F2A), wall2: Color(0xFF2F7D37),
    floor: Color(0xFF3F8F3A), floor2: Color(0xFF57A84A),
    joint: Color(0xFF2E6E2A), accent: Color(0xFF7BED9F),
    light: Color(0xFFFFF3C4), open: true,
  ),
  ArenaTheme.bosque: ArenaPalette(
    sky: Color(0xFF07170C), sky2: Color(0xFF12321C),
    wall: Color(0xFF113A1C), wall2: Color(0xFF1D5A2A),
    floor: Color(0xFF30683A), floor2: Color(0xFF3E7D44),
    joint: Color(0xFF214A28), accent: Color(0xFF2ED573),
    light: Color(0xFFD8FFB0), open: true,
  ),
  ArenaTheme.ruinas: ArenaPalette(
    sky: Color(0xFF2E3350), sky2: Color(0xFF6C6C8A),
    wall: Color(0xFF34343C), wall2: Color(0xFF82828E),
    floor: Color(0xFF5F5F68), floor2: Color(0xFF6C6C76),
    joint: Color(0xFF3E3E46), accent: Color(0xFFFFD166),
    light: Color(0xFFFFE6A8), open: true,
  ),
  ArenaTheme.cavernas: ArenaPalette(
    sky: Color(0xFF0E1426), sky2: Color(0xFF1C2742),
    wall: Color(0xFF26304A), wall2: Color(0xFF9FDCF5),
    floor: Color(0xFF4A5A70), floor2: Color(0xFF5B6E86),
    joint: Color(0xFF34425A), accent: Color(0xFF48DBFB),
    light: Color(0xFFBFF4FF),
  ),
  ArenaTheme.fortaleza: ArenaPalette(
    sky: Color(0xFF15121C), sky2: Color(0xFF2A2433),
    wall: Color(0xFF221E2A), wall2: Color(0xFF55505F),
    floor: Color(0xFF3A3642), floor2: Color(0xFF47424F),
    joint: Color(0xFF26222E), accent: Color(0xFFFF6B81),
    light: Color(0xFFFFB46B),
  ),
  ArenaTheme.laberinto: ArenaPalette(
    sky: Color(0xFF111827), sky2: Color(0xFF1E2A40),
    wall: Color(0xFF222C3F), wall2: Color(0xFFB08A3A),
    floor: Color(0xFF3B4A63), floor2: Color(0xFF46577A),
    joint: Color(0xFF2A3549), accent: Color(0xFFA29BFE),
    light: Color(0xFFFFD98A),
  ),
  ArenaTheme.grieta: ArenaPalette(
    sky: Color(0xFF1A0806), sky2: Color(0xFF4A1408),
    wall: Color(0xFF1A1618), wall2: Color(0xFFFF7B29),
    floor: Color(0xFF2F2A2C), floor2: Color(0xFF3D3537),
    joint: Color(0xFF1E1A1C), accent: Color(0xFFFF7B29),
    light: Color(0xFFFF9A3C), open: true,
  ),
  ArenaTheme.cementerio: ArenaPalette(
    sky: Color(0xFF0A0614), sky2: Color(0xFF22123A),
    wall: Color(0xFF2E2C35), wall2: Color(0xFF7E8A5A),
    floor: Color(0xFF5A5D5A), floor2: Color(0xFF6C706A),
    joint: Color(0xFF45474A), accent: Color(0xFFDFE6E9),
    light: Color(0xFFC8D6FF), open: true,
  ),
  ArenaTheme.abismo: ArenaPalette(
    sky: Color(0xFF04061A), sky2: Color(0xFF0C1838),
    wall: Color(0xFF262B40), wall2: Color(0xFF8A96C0),
    floor: Color(0xFF4A5372), floor2: Color(0xFF5A6488),
    joint: Color(0xFF323954), accent: Color(0xFF9B59FF),
    light: Color(0xFFB57BFF), open: true,
  ),
  ArenaTheme.corazon: ArenaPalette(
    sky: Color(0xFF0A0818), sky2: Color(0xFF2A1C3A),
    wall: Color(0xFF6B5A2A), wall2: Color(0xFFFFF3C4),
    floor: Color(0xFFD9C58A), floor2: Color(0xFFEFE2B0),
    joint: Color(0xFFB89C56), accent: Color(0xFFE84393),
    light: Color(0xFFFFF3C4), open: true,
  ),
  ArenaTheme.prueba: ArenaPalette(
    sky: Color(0xFF0C0718), sky2: Color(0xFF201238),
    wall: Color(0xFF1C1430), wall2: Color(0xFFC8CCE0),
    floor: Color(0xFF2A2140), floor2: Color(0xFF352A52),
    joint: Color(0xFF1C1530), accent: Color(0xFFC8CCE0),
    light: Color(0xFFE6DAFF),
  ),
  ArenaTheme.pueblo: ArenaPalette(
    sky: Color(0xFF0E1428), sky2: Color(0xFF2A3A66),
    wall: Color(0xFF161D33), wall2: Color(0xFF3D4D80),
    floor: Color(0xFF2D3A55), floor2: Color(0xFF34446A),
    joint: Color(0xFF222C44), accent: Color(0xFF48DBFB),
    light: Color(0xFFFFE6A8), open: true,
  ),
  // v0.8 · Jefe secreto del Abismo.
  ArenaTheme.primordial: ArenaPalette(
    sky: Color(0xFF05020E), sky2: Color(0xFF1A0A30),
    wall: Color(0xFF1A1230), wall2: Color(0xFFC39BFF),
    floor: Color(0xFF2A1F4A), floor2: Color(0xFF3A2A5A),
    joint: Color(0xFF140A2A), accent: Color(0xFFC39BFF),
    light: Color(0xFFE8DFFF), open: true,
  ),
};

/// Colores de los cinco elementos de la arena primordial.
const kPrimordialColors = [
  Color(0xFFFF7B29), // fuego
  Color(0xFF48DBFB), // agua
  Color(0xFFFFD166), // electro
  Color(0xFFBFF4FF), // hielo
  Color(0xFF7BED3F), // veneno
];

/// Jefe base de cada Jefe del Abismo (su set-piece).
const Map<String, String> kAbyssBaseBoss = {
  'golemAbismo': 'golemReloj',
  'hechiceraAbismo': 'hechicera',
  'espectroAbismo': 'espectroCoronado',
  'devoradorAbismo': 'devorador',
};

/// Luz propia de cada jefe (set-piece).
const Map<String, Color> kBossArenaLight = {
  'reyLimo': Color(0xFF7BED9F),
  'matriarca': Color(0xFFB57BFF),
  'golemReloj': Color(0xFFFFD166),
  'sierpe': Color(0xFF9FF3FF),
  'caballeroHueco': Color(0xFF6FF7FF),
  'hechicera': Color(0xFFA29BFE),
  'bestiaMagma': Color(0xFFFF7B29),
  'espectroCoronado': Color(0xFFB8C6FF),
  'centinela': Color(0xFFB57BFF),
  'devorador': Color(0xFFFFD166),
  // v0.8 · Jefes del Abismo: luz fría del vacío.
  'golemAbismo': Color(0xFFC39BFF),
  'hechiceraAbismo': Color(0xFFC39BFF),
  'espectroAbismo': Color(0xFFC39BFF),
  'devoradorAbismo': Color(0xFFC39BFF),
  'ecoPrimordial': Color(0xFFE8DFFF),
};

/// Luz de la segunda fase del Devorador.
const kDevoradorPhase2Light = Color(0xFFD63031);

/// Dibuja las arenas: una capa estática (rasterizada una vez por
/// [ArenaSpec] y cacheada) y una capa animada barata (partículas del
/// ambiente × el ajuste "Partículas"). Coordenadas del mundo de
/// [ArenaStage] (`960 × 540`, pies en `y = 300`).
class ArenaPainter {
  ArenaPainter();

  static const _maxCache = 3;
  final _cache = <String, ui.Image>{};

  /// Capas estáticas en memoria (para tests).
  int get cachedLayers => _cache.length;

  void dispose() {
    for (final i in _cache.values) {
      i.dispose();
    }
    _cache.clear();
  }

  /// Capa estática de [spec] (la rasteriza la primera vez).
  ui.Image layer(ArenaSpec spec) {
    final key = spec.cacheKey;
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit; // más reciente al final
      return hit;
    }
    final pic = recordStatic(spec);
    final img = pic.toImageSync(
        ArenaStage.width.toInt(), ArenaStage.height.toInt());
    pic.dispose();
    _cache[key] = img;
    while (_cache.length > _maxCache) {
      final old = _cache.keys.first;
      _cache.remove(old)!.dispose();
    }
    return img;
  }

  /// Dibuja la arena en [visible] (px del mundo) a [t] ms.
  void paint(Canvas c, Rect visible, double t, ArenaSpec spec,
      {double density = 1}) {
    final pal = paletteOf(spec);
    // Fuera del escenario: el cielo arriba y el piso oscuro abajo.
    _Px.rect(c, pal.sky, visible.left, visible.top, visible.width,
        visible.height);
    final fy = floorTop(spec.kind);
    if (visible.bottom > fy) {
      _Px.rect(c, _shade(pal.floor, 0.55), visible.left, fy, visible.width,
          visible.bottom - fy);
    }
    c.drawImage(layer(spec), Offset.zero, _Px.image);
    _animated(c, visible, t, spec, pal, density);
  }

  /// Paleta de [spec] (con la luz del jefe si corresponde).
  static ArenaPalette paletteOf(ArenaSpec spec) =>
      kArenaPalettes[spec.theme] ?? kArenaPalettes[ArenaTheme.pueblo]!;

  /// Luz principal de [spec]: la del jefe, o la de la zona.
  static Color lightOf(ArenaSpec spec) {
    if (spec.kind == EncounterKind.boss) {
      if (spec.bossType == 'devorador' && spec.phase2) {
        return kDevoradorPhase2Light;
      }
      final l = kBossArenaLight[spec.bossType];
      if (l != null) return l;
    }
    return paletteOf(spec).light;
  }

  /// Borde de atrás del piso (donde empieza el fondo), px del mundo.
  static double floorTop(EncounterKind k) => switch (k) {
        EncounterKind.normal => ArenaStage.floorY - 66,
        EncounterKind.elite => ArenaStage.floorY - 74,
        EncounterKind.boss => ArenaStage.floorY - 92,
      };

  /// Tarima de la pelea (élite y jefe): rectángulo / elipse del piso.
  static Rect platformOf(EncounterKind k) => switch (k) {
        EncounterKind.normal => Rect.fromCenter(
            center: const Offset(ArenaStage.centerX, ArenaStage.floorY - 8),
            width: 300,
            height: 104),
        EncounterKind.elite => Rect.fromCenter(
            center: const Offset(ArenaStage.centerX, ArenaStage.floorY - 8),
            width: 356,
            height: 124),
        EncounterKind.boss => Rect.fromCenter(
            center: const Offset(ArenaStage.centerX, ArenaStage.floorY - 8),
            width: 470,
            height: 164),
      };

  // ------------------------------------------------------------------
  // Capa estática
  // ------------------------------------------------------------------

  /// Graba la capa estática de [spec] (sin cachear).
  static ui.Picture recordStatic(ArenaSpec spec) {
    final r = ui.PictureRecorder();
    final c = Canvas(
        r, const Rect.fromLTWH(0, 0, ArenaStage.width, ArenaStage.height));
    final pal = paletteOf(spec);
    final ft = floorTop(spec.kind);
    _backdrop(c, spec, pal, ft);
    _floor(c, spec, pal, ft);
    switch (spec.kind) {
      case EncounterKind.normal:
        _normalStage(c, spec, pal, ft);
      case EncounterKind.elite:
        _eliteStage(c, spec, pal, ft);
      case EncounterKind.boss:
        _bossStage(c, spec, pal, ft);
    }
    _sideProps(c, spec, pal, ft);
    if (spec.eco) _ecoTint(c, pal);
    if (spec.abyss) _abyssTint(c, pal);
    _vignette(c, spec);
    return r.endRecording();
  }

  // ---------------- fondo ----------------

  static void _backdrop(Canvas c, ArenaSpec s, ArenaPalette p, double ft) {
    const w = ArenaStage.width;
    // Degradado en bandas de 6 px (sin antialias, como pixel art).
    for (var y = 0.0; y < ft; y += 6) {
      final k = (y / ft).clamp(0.0, 1.0);
      _Px.rect(c, Color.lerp(p.sky, p.sky2, k)!, 0, y, w, 6);
    }
    switch (s.theme) {
      case ArenaTheme.pradera:
        _clouds(c, ft, const Color(0xFFFFFFFF));
        _hills(c, ft - 10, 26, const Color(0xFF6FBF5A), 3);
        _hills(c, ft, 18, p.wall2, 7);
        _treeLine(c, ft, p.wall, p.wall2, 22);
      case ArenaTheme.bosque:
        for (var i = 0; i < 26; i++) {
          final x = (i * 41 + _h(i, 2) * 20).floorToDouble();
          final tw = 8.0 + _h(i, 3) * 10;
          _Px.rect(c, const Color(0xFF2A1A0E), x, 0, tw, ft);
          _Px.rect(c, const Color(0xFF3A2414), x + 2, 0, 2, ft);
        }
        _treeLine(c, ft - 30, p.wall, p.wall2, 30);
        _treeLine(c, ft, const Color(0xFF0B2A14), p.wall, 16);
        // Haces de luz entre las copas.
        for (var i = 0; i < 4; i++) {
          final x = 140.0 + i * 210;
          final path = Path()
            ..moveTo(x, 0)
            ..lineTo(x + 18, 0)
            ..lineTo(x + 60, ft)
            ..lineTo(x + 30, ft)
            ..close();
          c.drawPath(path, _Px.fillOf(const Color(0x16D8FFB0)));
        }
      case ArenaTheme.ruinas:
        _clouds(c, ft * 0.7, const Color(0x55C8C8E0));
        _hills(c, ft, 20, const Color(0xFF4A4A58), 5);
        for (var i = 0; i < 9; i++) {
          final x = 40.0 + i * 108;
          final hgt = 30.0 + _h(i, 5) * 60;
          _column(c, x, ft, hgt, p, broken: _h(i, 6) > 0.4);
        }
        // Arco roto al fondo.
        _Px.rect(c, p.wall, 430, ft - 70, 12, 70);
        _Px.rect(c, p.wall, 518, ft - 56, 12, 56);
        _Px.rect(c, p.wall, 430, ft - 78, 70, 10);
        _Px.rect(c, p.wall2, 430, ft - 78, 70, 2);
      case ArenaTheme.cavernas:
        _caveWall(c, ft, p);
        _icicles(c, ft, p);
      case ArenaTheme.fortaleza:
        _brickWall(c, ft, p.wall, p.joint, p.wall2);
        // Almenas.
        for (var x = 0.0; x < ArenaStage.width; x += 32) {
          _Px.rect(c, p.sky, x + 16, ft - 112, 16, 10);
        }
        // Troneras.
        for (var i = 0; i < 6; i++) {
          final x = 90.0 + i * 160;
          _Px.rect(c, const Color(0xFF0B0910), x, ft - 70, 6, 18);
          _Px.rect(c, const Color(0xFF0B0910), x - 3, ft - 64, 12, 4);
        }
      case ArenaTheme.laberinto:
        _brickWall(c, ft, p.wall, p.joint, const Color(0xFF2E3A52));
        for (var x = 0.0; x < ArenaStage.width; x += 96) {
          _Px.rect(c, p.wall2, x, ft - 90, 96, 3);
          _Px.rect(c, _shade(p.wall2, 0.6), x + 44, ft - 90, 8, 90);
        }
        _gear(c, 260, ft - 50, 30, 10, const Color(0xFF3A3A48), 0);
        _gear(c, 700, ft - 44, 24, 8, const Color(0xFF3A3A48), 0.3);
        _gear(c, 480, ft - 64, 18, 8, _shade(p.wall2, 0.5), 0.1);
      case ArenaTheme.grieta:
        _hills(c, ft - 24, 50, const Color(0xFF261012), 2);
        // Agujas de basalto.
        for (var i = 0; i < 12; i++) {
          final x = 20.0 + i * 82 + _h(i, 9) * 20;
          final hgt = 40.0 + _h(i, 8) * 70;
          _spire(c, x, ft, 18 + _h(i, 7) * 14, hgt, p.wall);
        }
        // Cascadas de lava lejanas.
        for (final x in const [150.0, 610.0, 860.0]) {
          _Px.rect(c, const Color(0xFFC0391B), x, 0, 8, ft - 8);
          _Px.rect(c, const Color(0xFFFF7B29), x + 2, 0, 3, ft - 8);
          _Px.rect(c, const Color(0x55FF7B29), x - 6, ft - 14, 20, 8);
        }
        _hills(c, ft, 12, const Color(0xFF1A1618), 9);
      case ArenaTheme.cementerio:
        _stars(c, ft, const Color(0x99DFE6E9), 40, 1);
        _Px.oval(c, const Color(0x33DFE6E9), 760, 60, 26, 26);
        _Px.oval(c, const Color(0xFFDFE6E9), 760, 60, 14, 14);
        _hills(c, ft, 16, const Color(0xFF1C1A24), 6);
        for (var i = 0; i < 14; i++) {
          final x = 30.0 + i * 68 + _h(i, 4) * 20;
          _tomb(c, x, ft - 2, 8 + _h(i, 2) * 6, 12 + _h(i, 1) * 10,
              const Color(0xFF2E2C35), cross: _h(i, 3) > 0.6);
        }
        _deadTree(c, 120, ft, const Color(0xFF221F28));
        _deadTree(c, 830, ft, const Color(0xFF221F28));
      case ArenaTheme.abismo:
        _stars(c, ArenaStage.height, const Color(0xCC8A96C0), 70, 2);
        for (var i = 0; i < 6; i++) {
          final x = 60.0 + i * 160 + _h(i, 1) * 30;
          final y = 40.0 + _h(i, 2) * (ft - 80);
          _islet(c, x, y, 20 + _h(i, 3) * 26, p);
        }
      case ArenaTheme.corazon:
        _stars(c, ft, const Color(0xAAFFF3C4), 50, 3);
        for (var i = 0; i < 10; i++) {
          final x = 30.0 + i * 100 + _h(i, 5) * 30;
          _crystal(c, x, ft, 10 + _h(i, 6) * 10, 30 + _h(i, 7) * 60,
              const Color(0xFFD9C58A), const Color(0xFFFFF3C4));
        }
      case ArenaTheme.prueba:
        _brickWall(c, ft, p.wall, p.joint, const Color(0xFF281D44));
        for (var i = 0; i < 6; i++) {
          final x = 80.0 + i * 160;
          _Px.rect(c, const Color(0xFF8A8EA8), x - 6, ft - 110, 12, 110);
          _Px.rect(c, p.wall2, x - 4, ft - 110, 2, 110);
          _hourglass(c, x, ft - 70, const Color(0xFFC8CCE0),
              const Color(0xFFB57BFF));
        }
      case ArenaTheme.pueblo:
        _stars(c, ft * 0.6, const Color(0x88FFFFFF), 30, 4);
        for (var i = 0; i < 8; i++) {
          final x = 10.0 + i * 122;
          _house(c, x, ft, 70 + _h(i, 1) * 30, 40 + _h(i, 2) * 30, p);
        }
      case ArenaTheme.primordial:
        // Vacío con cristales flotantes de los cinco elementos.
        _stars(c, ArenaStage.height, const Color(0xCCC39BFF), 80, 11);
        for (var i = 0; i < 10; i++) {
          final x = 50.0 + i * 96 + _h(i, 12) * 20;
          final y = 30.0 + _h(i, 13) * (ft - 70);
          final col = kPrimordialColors[i % kPrimordialColors.length];
          _crystal(c, x, y + 30, 6 + _h(i, 14) * 6, 16 + _h(i, 15) * 20,
              _shade(col, 0.6), col);
        }
    }
    // Zócalo: línea entre el fondo y el piso.
    _Px.rect(c, _shade(p.wall, 0.6), 0, ft - 2, ArenaStage.width, 2);
  }

  // ---------------- piso ----------------

  static void _floor(Canvas c, ArenaSpec s, ArenaPalette p, double ft) {
    const w = ArenaStage.width, h = ArenaStage.height;
    _Px.rect(c, p.floor, 0, ft, w, h - ft);
    switch (s.theme) {
      case ArenaTheme.pradera || ArenaTheme.bosque:
        // Pasto: matas y florcitas; en el bosque raíces y hojas.
        for (var i = 0; i < 900; i++) {
          final x = (_h(i, 11) * w).floorToDouble();
          final y = (ft + _h(i, 12) * (h - ft)).floorToDouble();
          _Px.rect(c, p.floor2, x, y, 2, 1);
          _Px.rect(c, p.floor2, x + 1, y - 1, 1, 1);
        }
        for (var i = 0; i < 70; i++) {
          final x = (_h(i, 13) * w).floorToDouble();
          final y = (ft + 6 + _h(i, 14) * (h - ft - 6)).floorToDouble();
          final col = s.theme == ArenaTheme.pradera
              ? [
                  const Color(0xFFFFE066),
                  const Color(0xFFFF8FB1),
                  const Color(0xFFFFFFFF),
                ][i % 3]
              : const Color(0xFF6E4A2A);
          _Px.rect(c, col, x, y, 2, 2);
        }
        if (s.theme == ArenaTheme.bosque) {
          for (var i = 0; i < 12; i++) {
            final x = (_h(i, 15) * w).floorToDouble();
            final y = (ft + 4 + _h(i, 16) * 40).floorToDouble();
            _Px.rect(c, const Color(0xFF3A2414), x, y, 26 + _h(i, 17) * 30, 2);
          }
        }
      case ArenaTheme.ruinas || ArenaTheme.fortaleza || ArenaTheme.pueblo:
        final tw = s.theme == ArenaTheme.pueblo ? 12.0 : 24.0;
        final th = s.theme == ArenaTheme.pueblo ? 8.0 : 14.0;
        _tiles(c, ft, tw, th, p, offsetRows: true);
        if (s.theme == ArenaTheme.ruinas) {
          _cracks(c, ft, p.joint, 40);
          for (var i = 0; i < 160; i++) {
            _Px.rect(c, const Color(0x558A7F6A), (_h(i, 21) * w).floorToDouble(),
                (ft + _h(i, 22) * (h - ft)).floorToDouble(), 3, 1);
          }
        }
      case ArenaTheme.cavernas:
        _tiles(c, ft, 32, 18, p, offsetRows: true);
        for (var i = 0; i < 60; i++) {
          final x = (_h(i, 31) * w).floorToDouble();
          final y = (ft + _h(i, 32) * (h - ft)).floorToDouble();
          _Px.rect(c, const Color(0x669FDCF5), x, y, 8, 1);
          _Px.rect(c, const Color(0x669FDCF5), x + 2, y + 1, 4, 1);
        }
      case ArenaTheme.laberinto:
        _tiles(c, ft, 20, 20, p);
        for (var y = ft + 20; y < h; y += 60) {
          _Px.rect(c, const Color(0x88B08A3A), 0, y, w, 1);
        }
      case ArenaTheme.grieta:
        _tiles(c, ft, 28, 16, p, offsetRows: true);
        _lavaVeins(c, ft);
      case ArenaTheme.cementerio:
        for (var i = 0; i < 700; i++) {
          _Px.rect(c, i.isEven ? p.floor2 : p.joint,
              (_h(i, 41) * w).floorToDouble(),
              (ft + _h(i, 42) * (h - ft)).floorToDouble(), 2, 1);
        }
        for (var i = 0; i < 90; i++) {
          final x = (_h(i, 43) * w).floorToDouble();
          final y = (ft + _h(i, 44) * (h - ft)).floorToDouble();
          _Px.rect(c, p.wall2, x, y, 1, 3);
          _Px.rect(c, p.wall2, x + 2, y + 1, 1, 2);
        }
      case ArenaTheme.abismo || ArenaTheme.primordial:
        // La isla: el piso es roca flotante sobre el vacío.
        _Px.rect(c, p.sky, 0, ft, w, h - ft);
        _stars(c, h, const Color(0x998A96C0), 40, 7, top: ft);
        final isle = Rect.fromLTRB(60, ft + 2, w - 60, ArenaStage.floorY + 90);
        _Px.rect(c, p.joint, isle.left + 6, isle.bottom, isle.width - 12, 10);
        _Px.rect(c, _shade(p.joint, 0.7), isle.left + 30, isle.bottom + 10,
            isle.width - 60, 14);
        for (var i = 0; i < 14; i++) {
          final x = isle.left + 40 + i * (isle.width - 80) / 14;
          _Px.rect(c, _shade(p.joint, 0.6), x, isle.bottom + 24,
              8, 6 + _h(i, 51) * 22);
        }
        _Px.rect(c, p.floor, isle.left, isle.top, isle.width, isle.height);
        _tilesIn(c, isle, 26, 14, p);
        _Px.rect(c, p.wall2, isle.left, isle.top, isle.width, 1);
        _Px.rect(c, _shade(p.floor, 0.7), isle.left, isle.bottom - 3,
            isle.width, 3);
      case ArenaTheme.corazon:
        _tiles(c, ft, 24, 24, p);
        for (var i = 0; i < 80; i++) {
          _Px.rect(c, const Color(0x88FFFFFF), (_h(i, 61) * w).floorToDouble(),
              (ft + _h(i, 62) * (h - ft)).floorToDouble(), 1, 1);
        }
      case ArenaTheme.prueba:
        // Damero de losas violetas con filetes de plata.
        for (var y = ft; y < h; y += 16) {
          for (var x = 0.0; x < w; x += 16) {
            final odd = (((x / 16).floor() + ((y - ft) / 16).floor()) & 1) == 1;
            _Px.rect(c, odd ? p.floor2 : p.floor, x, y, 16, 16);
          }
        }
        for (var y = ft + 48; y < h; y += 48) {
          _Px.rect(c, const Color(0x55C8CCE0), 0, y, w, 1);
        }
    }
    // Sombra del muro sobre el borde de atrás del piso.
    _Px.rect(c, const Color(0x55000000), 0, ft, w, 4);
    _Px.rect(c, const Color(0x2A000000), 0, ft + 4, w, 6);
  }

  // ---------------- normal / élite / jefe ----------------

  /// Normal: un claro / desgaste del piso bajo la pelea (marca el lugar
  /// de cada bando sin tapar nada).
  static void _normalStage(Canvas c, ArenaSpec s, ArenaPalette p, double ft) {
    final r = platformOf(EncounterKind.normal);
    final worn = switch (s.theme) {
      ArenaTheme.pradera => const Color(0x40B89A5A),
      ArenaTheme.bosque => const Color(0x406E5A3A),
      ArenaTheme.abismo => const Color(0x20FFFFFF),
      _ => const Color(0x22000000),
    };
    _Px.ovalRect(c, worn, r);
    _Px.ovalRect(c, worn, r.deflate(18));
  }

  /// Élite: tarima enmarcada, estandartes y braseros (luz más fuerte).
  static void _eliteStage(Canvas c, ArenaSpec s, ArenaPalette p, double ft) {
    final r = platformOf(EncounterKind.elite);
    final rim = _tint(p.floor2, const Color(0xFFFFFFFF), 0.25);
    // Sombra, borde y superficie.
    _Px.rect(c, const Color(0x66000000), r.left + 4, r.top + 6, r.width,
        r.height);
    _Px.rect(c, _shade(p.floor, 0.75), r.left, r.top, r.width, r.height + 4);
    _Px.rect(c, rim, r.left, r.top, r.width, r.height);
    _Px.rect(c, _tint(p.floor, const Color(0xFFFFFFFF), 0.06), r.left + 4,
        r.top + 4, r.width - 8, r.height - 8);
    _tilesIn(c, r.deflate(4), 22, 14,
        ArenaPalette(
          sky: p.sky, sky2: p.sky2, wall: p.wall, wall2: p.wall2,
          floor: _tint(p.floor, const Color(0xFFFFFFFF), 0.06),
          floor2: _tint(p.floor2, const Color(0xFFFFFFFF), 0.06),
          joint: p.joint, accent: p.accent, light: p.light,
        ));
    // Filete dorado y esquineros.
    _Px.stroke(c, const Color(0xFFFFD166), r.deflate(2));
    for (final o in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      _Px.rect(c, const Color(0xFFFFD166), o.dx - 4, o.dy - 4, 8, 8);
      _Px.rect(c, _shade(const Color(0xFFFFD166), 0.6), o.dx - 2, o.dy - 2, 4,
          4);
    }
    // Estandartes en el fondo.
    for (final x in [
      ArenaStage.centerX - 210,
      ArenaStage.centerX - 110,
      ArenaStage.centerX + 110,
      ArenaStage.centerX + 210,
    ]) {
      _banner(c, x, ft - 60, p.accent, const Color(0xFFFFD166));
    }
    // Braseros en las esquinas de atrás.
    for (final x in [r.left + 10, r.right - 10]) {
      _brazier(c, x, r.top + 6);
    }
  }

  /// Jefe: estrado grande con anillo rúnico + set-piece del jefe.
  static void _bossStage(Canvas c, ArenaSpec s, ArenaPalette p, double ft) {
    final r = platformOf(EncounterKind.boss);
    final light = lightOf(s);
    final p2 = s.bossType == 'devorador' && s.phase2;
    _bossBackdrop(c, s, p, ft, light);
    // Estrado: sombra, piedra, superficie.
    _Px.ovalRect(c, const Color(0x77000000), r.shift(const Offset(0, 8)));
    _Px.ovalRect(c, _shade(p.floor, 0.6), r.shift(const Offset(0, 4)));
    _Px.ovalRect(c, _tint(p.floor2, const Color(0xFFFFFFFF), 0.12), r);
    _Px.ovalRect(c, p2 ? const Color(0xFF2A0E14) : p.floor, r.deflate(6));
    // Anillos rúnicos.
    _Px.ovalStroke(c, light.withValues(alpha: 0.9), r.deflate(10), 2);
    _Px.ovalStroke(c, light.withValues(alpha: 0.45), r.deflate(28), 1);
    _Px.ovalStroke(c, light.withValues(alpha: 0.3), r.deflate(64), 1);
    final cx = r.center.dx, cy = r.center.dy;
    for (var i = 0; i < 16; i++) {
      final a = i / 16 * math.pi * 2;
      final x = cx + math.cos(a) * (r.width / 2 - 19);
      final y = cy + math.sin(a) * (r.height / 2 - 19);
      _rune(c, x, y, i, light);
    }
    if (p2) {
      // Grietas incandescentes en el estrado.
      for (var i = 0; i < 9; i++) {
        final a = i / 9 * math.pi * 2 + 0.3;
        _crackLine(c, cx, cy, a, r.width / 2 - 8, r.height / 2 - 8,
            const Color(0xFFFF4757), i);
      }
    }
    // Pilares laterales del jefe.
    for (final x in [r.left - 26, r.right + 26]) {
      _pillar(c, x, ft + 40, p, light);
    }
  }

  /// Fondo propio de cada jefe (barato: formas y luz).
  static void _bossBackdrop(
      Canvas c, ArenaSpec s, ArenaPalette p, double ft, Color light) {
    const cx = ArenaStage.centerX;
    // Resplandor de fondo detrás del jefe.
    for (var k = 0; k < 5; k++) {
      _Px.oval(c, light.withValues(alpha: 0.05 + k * 0.012), cx,
          ft - 10, 260.0 - k * 46, 90.0 - k * 14);
    }
    // Jefes del Abismo: el set-piece de su jefe base.
    switch (kAbyssBaseBoss[s.bossType] ?? s.bossType) {
      case 'reyLimo':
        for (var i = 0; i < 9; i++) {
          final x = 80.0 + i * 100;
          _Px.rect(c, const Color(0xAA4CD47A), x, 0, 6, 20 + _h(i, 3) * 60);
          _Px.oval(c, const Color(0xAA4CD47A), x + 3, 22 + _h(i, 3) * 60, 4, 5);
        }
        for (var i = 0; i < 6; i++) {
          _Px.oval(c, const Color(0x664CD47A), 140.0 + i * 140,
              ArenaStage.floorY + 40 + _h(i, 4) * 40, 24, 6);
        }
      case 'matriarca':
        _web(c, 0, 0, 160, const Color(0x88E6E6F0));
        _web(c, ArenaStage.width, 0, 160, const Color(0x88E6E6F0));
        for (var i = 0; i < 6; i++) {
          final x = 210.0 + i * 108;
          _Px.oval(c, const Color(0xFF6E9F4A), x, ft - 18 - _h(i, 1) * 30, 7, 9);
          _Px.oval(c, const Color(0xFFA6D96A), x - 2, ft - 21 - _h(i, 1) * 30,
              2, 3);
        }
      case 'golemReloj':
        _clockFace(c, cx, ft - 64, 56, const Color(0xFF5A4A2A),
            const Color(0xFFFFD166));
      case 'sierpe':
        for (final x in const [230.0, 360.0, 600.0, 730.0]) {
          _crystal(c, x, ft, 16, 90, const Color(0xFF5BC8E8),
              const Color(0xFFE6FBFF));
        }
        _Px.rect(c, const Color(0x6648DBFB), cx - 40, 0, 80, ft);
        _Px.rect(c, const Color(0x88BFF4FF), cx - 6, 0, 12, ft);
      case 'caballeroHueco':
        // Trono vacío y estandartes rotos.
        _Px.rect(c, const Color(0xFF1A1620), cx - 30, ft - 96, 60, 96);
        _Px.rect(c, const Color(0xFF2E2838), cx - 24, ft - 90, 48, 60);
        _Px.rect(c, const Color(0xFF6FF7FF), cx - 2, ft - 100, 4, 10);
        for (final x in [cx - 150, cx + 150]) {
          _banner(c, x, ft - 90, const Color(0xFF3A3A4A),
              const Color(0xFF6FF7FF), torn: true);
        }
      case 'hechicera':
        for (final x in [cx - 190, cx - 80, cx + 80, cx + 190]) {
          _Px.oval(c, const Color(0xFF3B2A5A), x, ft - 50, 22, 44);
          _Px.oval(c, const Color(0xFF6C5CE7), x, ft - 50, 18, 40);
          _Px.oval(c, const Color(0x99A29BFE), x - 4, ft - 58, 6, 20);
        }
      case 'bestiaMagma':
        for (final x in [cx - 220, cx - 120, cx + 120, cx + 220]) {
          _Px.rect(c, const Color(0xFFC0391B), x - 7, 0, 14, ft);
          _Px.rect(c, const Color(0xFFFF7B29), x - 3, 0, 6, ft);
          _Px.rect(c, const Color(0xFFFFD166), x - 1, 0, 2, ft);
          _Px.oval(c, const Color(0x88FF7B29), x, ft, 22, 6);
        }
        // Foso de lava al frente.
        _Px.rect(c, const Color(0xFF6A1A0A), 0, ArenaStage.floorY + 96,
            ArenaStage.width, 8);
        _Px.rect(c, const Color(0xFFC0391B), 0, ArenaStage.floorY + 104,
            ArenaStage.width, 60);
        _lavaVeins(c, ArenaStage.floorY + 104);
      case 'espectroCoronado':
        _crown(c, cx, ft - 70, const Color(0xFFB8C6FF));
        for (var i = 0; i < 10; i++) {
          final x = 120.0 + i * 80;
          if ((x - cx).abs() < 60) continue;
          _Px.rect(c, const Color(0xFFDFE6E9), x, ft - 14, 3, 10);
          _Px.rect(c, const Color(0xFFB8C6FF), x, ft - 18, 3, 3);
        }
      case 'centinela':
        _Px.rect(c, const Color(0xFF14172A), cx - 34, ft - 120, 68, 120);
        _Px.rect(c, const Color(0xFF262B40), cx - 30, ft - 116, 60, 116);
        _Px.oval(c, const Color(0xFF3A1A6A), cx, ft - 66, 20, 12);
        _Px.oval(c, const Color(0xFFB57BFF), cx, ft - 66, 12, 8);
        _Px.oval(c, const Color(0xFFFFFFFF), cx, ft - 66, 4, 4);
      case 'devorador':
        final p2 = s.phase2;
        final ring = p2 ? const Color(0xFFFF4757) : const Color(0xFFFFD166);
        final ring2 = p2 ? const Color(0xFF6A0A14) : const Color(0xFF6C4AD9);
        _Px.oval(c, p2 ? const Color(0xFF14040A) : const Color(0xFF120A24), cx,
            ft - 40, 220, 110);
        for (var k = 0; k < 6; k++) {
          _Px.ovalStroke(
              c,
              (k.isEven ? ring : ring2).withValues(alpha: 0.75 - k * 0.1),
              Rect.fromCenter(
                  center: Offset(cx, ft - 40),
                  width: 420.0 - k * 64,
                  height: 200.0 - k * 30),
              2);
        }
        _Px.oval(c, const Color(0xFF000000), cx, ft - 40, 40, 20);
        if (p2) {
          // Realidad partida: grietas en el cielo.
          for (var i = 0; i < 7; i++) {
            _crackLine(c, 80.0 + i * 130, 0, math.pi / 2 + (_h(i, 3) - 0.5),
                12, ft * 0.8, const Color(0xFFFF4757), i + 20);
          }
        } else {
          // Fragmentos de relojes que flotan.
          for (var i = 0; i < 6; i++) {
            final x = 110.0 + i * 150;
            if ((x - cx).abs() < 80) continue;
            _clockFace(c, x, 40 + _h(i, 9) * 70, 14, const Color(0xFF6B5A2A),
                const Color(0xFFFFF3C4));
          }
        }
      default:
        break;
    }
  }

  // ---------------- props de los costados ----------------

  static void _sideProps(Canvas c, ArenaSpec s, ArenaPalette p, double ft) {
    final r = platformOf(s.kind);
    // Fuera de la pelea: entre el borde de la tarima y el borde del
    // escenario, de los dos lados (simétrico).
    final xs = <double>[
      r.left - 60, r.left - 130, r.left - 210, //
      r.right + 60, r.right + 130, r.right + 210,
    ];
    for (var i = 0; i < xs.length; i++) {
      final x = xs[i];
      final y = ft + 30 + (i % 3) * 46.0;
      switch (s.theme) {
        case ArenaTheme.pradera:
          _bush(c, x, y, p.wall, p.wall2);
        case ArenaTheme.bosque:
          _stump(c, x, y);
        case ArenaTheme.ruinas:
          _column(c, x, y, 18 + _h(i, 1) * 20, p, broken: true);
        case ArenaTheme.cavernas:
          _crystal(c, x, y, 8, 18 + _h(i, 2) * 16, const Color(0xFF5BC8E8),
              const Color(0xFFE6FBFF));
        case ArenaTheme.fortaleza:
          _weaponRack(c, x, y);
        case ArenaTheme.laberinto:
          _gear(c, x, y - 10, 10, 6, _shade(p.wall2, 0.8), i * 0.2);
        case ArenaTheme.grieta:
          _spire(c, x, y, 12, 22 + _h(i, 3) * 16, p.wall);
          _Px.rect(c, const Color(0xFFFF7B29), x - 1, y - 6, 2, 6);
        case ArenaTheme.cementerio:
          _tomb(c, x, y, 10, 16, const Color(0xFF6E6A70),
              cross: i.isOdd);
        case ArenaTheme.abismo:
          _Px.rect(c, p.wall2, x - 3, y - 14, 6, 14);
          _Px.rect(c, p.accent, x - 1, y - 18, 2, 4);
        case ArenaTheme.corazon:
          _crystal(c, x, y, 8, 20 + _h(i, 4) * 12, const Color(0xFFD9C58A),
              const Color(0xFFFFF3C4));
        case ArenaTheme.prueba:
          _hourglass(c, x, y - 10, const Color(0xFFC8CCE0),
              const Color(0xFFB57BFF));
        case ArenaTheme.pueblo:
          _lamp(c, x, y);
        case ArenaTheme.primordial:
          final col = kPrimordialColors[i % kPrimordialColors.length];
          _crystal(c, x, y, 7, 16 + _h(i, 6) * 14, _shade(col, 0.6), col);
      }
    }
  }

  /// Variante del Abismo (v0.8): el vacío se come los bordes, grietas
  /// violetas en el piso y luz fría.
  static void _abyssTint(Canvas c, ArenaPalette p) {
    const w = ArenaStage.width, h = ArenaStage.height;
    _Px.rect(c, const Color(0x332A0F4A), 0, 0, w, h);
    for (var i = 0; i < 8; i++) {
      _crackLine(c, 40.0 + i * 120, ArenaStage.floorY + 60,
          -math.pi / 2 + (_h(i, 31) - 0.5), 10, 120, const Color(0xFFC39BFF),
          i + 40);
    }
    for (var i = 0; i < 5; i++) {
      final a = 0.20 * (1 - i / 5);
      final d = i * 14.0;
      final col = Color.fromRGBO(20, 6, 40, a);
      _Px.rect(c, col, 0, d, w, 14);
      _Px.rect(c, col, d, 0, 14, h);
      _Px.rect(c, col, w - d - 14, 0, 14, h);
    }
  }

  static void _ecoTint(Canvas c, ArenaPalette p) {
    const w = ArenaStage.width, h = ArenaStage.height;
    _Px.rect(c, const Color(0x1A48DBFB), 0, 0, w, h);
    for (var y = 0.0; y < h; y += 6) {
      _Px.rect(c, const Color(0x0C9FF3FF), 0, y, w, 1);
    }
  }

  static void _vignette(Canvas c, ArenaSpec s) {
    const w = ArenaStage.width, h = ArenaStage.height;
    final k = switch (s.kind) {
      EncounterKind.normal => 0.18,
      EncounterKind.elite => 0.3,
      EncounterKind.boss => 0.42,
    };
    for (var i = 0; i < 6; i++) {
      final a = k * (1 - i / 6);
      final col = Color.fromRGBO(0, 0, 0, a / 3);
      final d = i * 20.0;
      _Px.rect(c, col, d, 0, 20, h);
      _Px.rect(c, col, w - d - 20, 0, 20, h);
      _Px.rect(c, col, 0, h - d - 14, w, 14);
    }
  }

  // ------------------------------------------------------------------
  // Capa animada
  // ------------------------------------------------------------------

  void _animated(Canvas c, Rect v, double t, ArenaSpec s, ArenaPalette p,
      double density) {
    final light = lightOf(s);
    final ft = floorTop(s.kind);
    // Luz de la pelea que respira (élite y jefe).
    if (s.kind != EncounterKind.normal) {
      final r = platformOf(s.kind);
      final k = 0.5 + 0.5 * math.sin(t / 700);
      _Px.ovalRect(c, light.withValues(alpha: 0.05 + 0.04 * k),
          r.deflate(s.kind == EncounterKind.boss ? 30 : 40));
    }
    if (s.kind == EncounterKind.elite) {
      final r = platformOf(s.kind);
      for (final x in [r.left + 10, r.right - 10]) {
        _flame(c, x, r.top + 6 - 9, t, x.toInt());
      }
    }
    if (s.kind == EncounterKind.boss) {
      final r = platformOf(s.kind);
      // Runas del anillo que se encienden en ronda.
      final cx = r.center.dx, cy = r.center.dy;
      final lit = (t / 160).floor() % 16;
      for (var j = 0; j < 3; j++) {
        final i = (lit + j * 5) % 16;
        final a = i / 16 * math.pi * 2;
        _Px.rect(c, light, (cx + math.cos(a) * (r.width / 2 - 19)).floorToDouble() - 2,
            (cy + math.sin(a) * (r.height / 2 - 19)).floorToDouble() - 2, 4, 4);
      }
      if (s.bossType == 'devorador') _vortex(c, t, s.phase2, ft, density);
    }
    // Ambiente de la zona.
    final (n, color, mode) = switch (s.theme) {
      ArenaTheme.pradera => (10, const Color(0xCCFFFFFF), _Mote.drift),
      ArenaTheme.bosque => (14, const Color(0xCC8FD14F), _Mote.fall),
      ArenaTheme.ruinas => (12, const Color(0x88E6D8A8), _Mote.drift),
      ArenaTheme.cavernas => (22, const Color(0xDDE6FBFF), _Mote.fall),
      ArenaTheme.fortaleza => (10, const Color(0xAAFFB46B), _Mote.rise),
      ArenaTheme.laberinto => (10, const Color(0xAAFFD98A), _Mote.twinkle),
      ArenaTheme.grieta => (26, const Color(0xEEFF9A3C), _Mote.rise),
      ArenaTheme.cementerio => (12, const Color(0x99C8D6FF), _Mote.drift),
      ArenaTheme.abismo => (18, const Color(0xCCB57BFF), _Mote.twinkle),
      ArenaTheme.corazon => (20, const Color(0xDDFFF3C4), _Mote.rise),
      ArenaTheme.prueba => (14, const Color(0xCCE6DAFF), _Mote.fall),
      ArenaTheme.pueblo => (8, const Color(0x99FFE6A8), _Mote.twinkle),
      ArenaTheme.primordial => (24, const Color(0xDDC39BFF), _Mote.twinkle),
    };
    var count = scaledCount(n, density);
    if (s.kind == EncounterKind.boss) count += scaledCount(8, density);
    _motes(c, v, t, count, color, mode);
    if (s.abyss) {
      _motes(c, v, t + 9000, scaledCount(10, density),
          const Color(0xBBC39BFF), _Mote.rise);
    }
    if (s.eco) {
      _motes(c, v, t + 5000, scaledCount(8, density),
          const Color(0xAA9FF3FF), _Mote.rise);
    }
    if (s.theme == ArenaTheme.laberinto && s.kind != EncounterKind.normal) {
      _gear(c, 480, ft - 64, 18, 8, _shade(p.wall2, 0.8), t / 4000);
    }
  }

  void _vortex(Canvas c, double t, bool p2, double ft, double density) {
    const cx = ArenaStage.centerX;
    final cy = ft - 40;
    final col = p2 ? const Color(0xFFFF4757) : const Color(0xFFFFD166);
    final n = scaledCount(24, density);
    for (var i = 0; i < n; i++) {
      final k = i % 4;
      final rx = 200.0 - k * 40, ry = 95.0 - k * 18;
      final a = t / (p2 ? 900 : 1600) * (k.isEven ? 1 : -1) + i * 1.7;
      final x = cx + math.cos(a) * rx, y = cy + math.sin(a) * ry;
      _Px.rect(c, col.withValues(alpha: 0.8 - k * 0.15), x.floorToDouble(),
          y.floorToDouble(), 2, 2);
    }
    if (p2) {
      final k = 0.5 + 0.5 * math.sin(t / 220);
      _Px.oval(c, Color.fromRGBO(214, 48, 49, 0.10 + 0.10 * k), cx, cy, 70, 34);
    }
  }

  static void _flame(Canvas c, double x, double y, double t, int seed) {
    final k = math.sin(t / 90 + seed) * 0.5 + 0.5;
    final h = 6 + (k * 4).floorToDouble();
    _Px.oval(c, const Color(0x33FFB46B), x, y, 16, 10);
    _Px.rect(c, const Color(0xFFFF7B29), x - 3, y - h + 4, 6, h);
    _Px.rect(c, const Color(0xFFFFD166), x - 2, y - h + 6, 4, h - 3);
    _Px.rect(c, const Color(0xFFFFFFFF), x - 1, y - 1, 2, 2);
  }

  void _motes(Canvas c, Rect v, double t, int n, Color color, _Mote mode) {
    for (var i = 0; i < n; i++) {
      final hx = _h(i, 71), hy = _h(i, 72), sp = 0.5 + _h(i, 73);
      double x, y;
      switch (mode) {
        case _Mote.fall:
          y = v.top + ((hy + t / 9000 * sp) % 1.0) * v.height;
          x = v.left + hx * v.width + math.sin(t / 700 + i) * 6;
        case _Mote.rise:
          y = v.bottom - ((hy + t / 7000 * sp) % 1.0) * v.height;
          x = v.left + hx * v.width + math.sin(t / 500 + i) * 3;
        case _Mote.drift:
          x = v.left + ((hx + t / 20000 * sp) % 1.0) * v.width;
          y = v.top + hy * v.height + math.sin(t / 900 + i) * 4;
        case _Mote.twinkle:
          x = v.left + hx * v.width;
          y = v.top + hy * v.height;
      }
      final a = mode == _Mote.twinkle
          ? (0.5 + 0.5 * math.sin(t / 300 + i * 2.1)).clamp(0.0, 1.0)
          : 1.0;
      _Px.rect(c, color.withValues(alpha: color.a * a), x.floorToDouble(),
          y.floorToDouble(), i % 3 == 0 ? 2 : 1, i % 3 == 0 ? 2 : 1);
    }
  }

  // ------------------------------------------------------------------
  // Piezas
  // ------------------------------------------------------------------

  /// Pseudoazar fijo en [0, 1).
  static double _h(int i, int salt) {
    var x = (i * 374761393 + salt * 668265263) & 0x7fffffff;
    x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff;
    return (x ^ (x >> 16)) / 0x80000000;
  }

  static Color _shade(Color c, double k) => Color.fromARGB(
      (c.a * 255).round(),
      (c.r * 255 * k).round().clamp(0, 255),
      (c.g * 255 * k).round().clamp(0, 255),
      (c.b * 255 * k).round().clamp(0, 255));

  static Color _tint(Color a, Color b, double k) => Color.lerp(a, b, k)!;

  static void _tiles(Canvas c, double ft, double tw, double th, ArenaPalette p,
      {bool offsetRows = false}) {
    _tilesIn(c, Rect.fromLTRB(0, ft, ArenaStage.width, ArenaStage.height), tw,
        th, p,
        offsetRows: offsetRows);
  }

  static void _tilesIn(Canvas c, Rect r, double tw, double th, ArenaPalette p,
      {bool offsetRows = false}) {
    c.save();
    c.clipRect(r);
    var row = 0;
    for (var y = r.top; y < r.bottom; y += th, row++) {
      final off = offsetRows && row.isOdd ? tw / 2 : 0.0;
      var col = 0;
      for (var x = r.left - off; x < r.right; x += tw, col++) {
        final v = _h(col * 31 + row, 91);
        final fill = v < 0.33 ? p.floor2 : p.floor;
        _Px.rect(c, fill, x, y, tw, th);
        _Px.rect(c, p.joint, x, y, tw, 1);
        _Px.rect(c, p.joint, x, y, 1, th);
        if (v > 0.85) {
          _Px.rect(c, _tint(fill, const Color(0xFFFFFFFF), 0.12), x + 2, y + 2,
              tw / 3, 1);
        }
      }
    }
    c.restore();
  }

  static void _cracks(Canvas c, double ft, Color col, int n) {
    for (var i = 0; i < n; i++) {
      var x = (_h(i, 101) * ArenaStage.width).floorToDouble();
      var y = (ft + _h(i, 102) * (ArenaStage.height - ft)).floorToDouble();
      for (var k = 0; k < 6; k++) {
        _Px.rect(c, col, x, y, 2, 1);
        x += 2;
        y += _h(i * 7 + k, 103) > 0.5 ? 1 : -1;
      }
    }
  }

  static void _lavaVeins(Canvas c, double ft) {
    for (var i = 0; i < 26; i++) {
      var x = (_h(i, 111) * ArenaStage.width).floorToDouble();
      var y = (ft + 6 + _h(i, 112) * (ArenaStage.height - ft)).floorToDouble();
      final len = 6 + (_h(i, 113) * 10).floor();
      for (var k = 0; k < len; k++) {
        _Px.rect(c, const Color(0xFFC0391B), x, y, 3, 2);
        _Px.rect(c, const Color(0xFFFF7B29), x + 1, y, 1, 1);
        x += 3;
        y += _h(i * 11 + k, 114) > 0.5 ? 1 : -1;
      }
    }
  }

  static void _clouds(Canvas c, double maxY, Color col) {
    for (var i = 0; i < 7; i++) {
      final x = (_h(i, 121) * ArenaStage.width).floorToDouble();
      final y = (10 + _h(i, 122) * (maxY * 0.6)).floorToDouble();
      final w = 30 + _h(i, 123) * 40;
      _Px.rect(c, col.withValues(alpha: col.a * 0.8), x, y, w, 6);
      _Px.rect(c, col, x + 6, y - 4, w - 16, 6);
    }
  }

  static void _hills(Canvas c, double base, double amp, Color col, int seed) {
    for (var x = 0.0; x < ArenaStage.width; x += 4) {
      final h = amp *
          (0.6 +
              0.4 * math.sin(x / 70 + seed) * math.cos(x / 130 + seed * 0.7));
      _Px.rect(c, col, x, base - h, 4, h);
    }
  }

  static void _treeLine(Canvas c, double base, Color a, Color b, double amp) {
    for (var x = 0.0; x < ArenaStage.width; x += 6) {
      final i = (x / 6).floor();
      final h = amp * (0.5 + _h(i, 131) * 0.6);
      _Px.rect(c, a, x, base - h, 7, h);
      _Px.rect(c, b, x + 2, base - h, 3, 2);
    }
  }

  static void _column(Canvas c, double x, double base, double h,
      ArenaPalette p,
      {bool broken = false}) {
    _Px.rect(c, p.wall, x - 7, base - h, 14, h);
    _Px.rect(c, p.wall2, x - 5, base - h, 2, h);
    _Px.rect(c, _shade(p.wall, 0.6), x + 4, base - h, 3, h);
    _Px.rect(c, p.wall2, x - 9, base - 4, 18, 4);
    if (broken) {
      _Px.rect(c, p.sky2, x + 1, base - h, 6, 3);
    } else {
      _Px.rect(c, p.wall2, x - 9, base - h - 4, 18, 4);
    }
  }

  static void _caveWall(Canvas c, double ft, ArenaPalette p) {
    for (var x = 0.0; x < ArenaStage.width; x += 8) {
      final i = (x / 8).floor();
      final h = ft - 20 - _h(i, 141) * 30;
      _Px.rect(c, p.wall, x, ft - h, 8, h);
      if (_h(i, 142) > 0.7) {
        _Px.rect(c, p.wall2.withValues(alpha: 0.5), x + 3, ft - h + 6, 1,
            h * 0.5);
      }
    }
  }

  static void _icicles(Canvas c, double ft, ArenaPalette p) {
    for (var i = 0; i < 40; i++) {
      final x = (i * 24 + _h(i, 151) * 10).floorToDouble();
      final h = 8 + _h(i, 152) * 26;
      for (var k = 0; k < h; k += 2) {
        final w = math.max(1.0, 4 - k / h * 4);
        _Px.rect(c, const Color(0xCC9FDCF5), x - w / 2, k.toDouble(), w, 2);
      }
    }
  }

  static void _brickWall(
      Canvas c, double ft, Color wall, Color joint, Color hi) {
    var row = 0;
    for (var y = ft - 120; y < ft; y += 10, row++) {
      for (var x = row.isOdd ? -10.0 : 0.0; x < ArenaStage.width; x += 20) {
        _Px.rect(c, wall, x, y, 20, 10);
        _Px.rect(c, joint, x, y, 20, 1);
        _Px.rect(c, joint, x, y, 1, 10);
        if (_h((x / 20).floor() + row * 50, 161) > 0.8) {
          _Px.rect(c, hi, x + 2, y + 2, 8, 1);
        }
      }
    }
  }

  static void _gear(Canvas c, double x, double y, double r, int teeth,
      Color col, double turn) {
    _Px.oval(c, col, x, y, r, r);
    for (var i = 0; i < teeth; i++) {
      final a = turn * math.pi * 2 + i / teeth * math.pi * 2;
      _Px.rect(c, col, (x + math.cos(a) * (r + 2)).floorToDouble() - 2,
          (y + math.sin(a) * (r + 2)).floorToDouble() - 2, 5, 5);
    }
    _Px.oval(c, _shade(col, 0.6), x, y, r * 0.4, r * 0.4);
  }

  static void _spire(Canvas c, double x, double base, double w, double h,
      Color col) {
    final path = Path()
      ..moveTo(x - w / 2, base)
      ..lineTo(x - w * 0.15, base - h)
      ..lineTo(x + w * 0.1, base - h * 0.85)
      ..lineTo(x + w / 2, base)
      ..close();
    c.drawPath(path, _Px.fillOf(col));
  }

  static void _stars(Canvas c, double maxY, Color col, int n, int salt,
      {double top = 0}) {
    for (var i = 0; i < n; i++) {
      _Px.rect(c, col, (_h(i, 170 + salt) * ArenaStage.width).floorToDouble(),
          (top + _h(i, 180 + salt) * (maxY - top)).floorToDouble(),
          i % 5 == 0 ? 2 : 1, i % 5 == 0 ? 2 : 1);
    }
  }

  static void _tomb(Canvas c, double x, double base, double w, double h,
      Color col,
      {bool cross = false}) {
    if (cross) {
      _Px.rect(c, col, x - 1, base - h, 3, h);
      _Px.rect(c, col, x - w / 2, base - h * 0.7, w, 3);
    } else {
      _Px.rect(c, col, x - w / 2, base - h + 3, w, h - 3);
      _Px.rect(c, col, x - w / 2 + 1, base - h + 1, w - 2, 2);
      _Px.rect(c, _shade(col, 0.6), x - w / 2 + 2, base - h + 5, w - 4, 1);
    }
  }

  static void _deadTree(Canvas c, double x, double base, Color col) {
    _Px.rect(c, col, x - 3, base - 70, 6, 70);
    _Px.rect(c, col, x - 20, base - 56, 18, 3);
    _Px.rect(c, col, x + 2, base - 44, 22, 3);
    _Px.rect(c, col, x - 20, base - 64, 3, 10);
    _Px.rect(c, col, x + 21, base - 52, 3, 10);
  }

  static void _islet(Canvas c, double x, double y, double w, ArenaPalette p) {
    _Px.rect(c, p.floor, x - w / 2, y, w, 4);
    _Px.rect(c, p.joint, x - w / 2 + 2, y + 4, w - 4, 4);
    _Px.rect(c, _shade(p.joint, 0.7), x - w / 4, y + 8, w / 2, 5);
    _Px.rect(c, p.wall2, x - w / 2, y, w, 1);
  }

  static void _crystal(Canvas c, double x, double base, double w, double h,
      Color a, Color b) {
    final path = Path()
      ..moveTo(x - w / 2, base)
      ..lineTo(x - w / 2, base - h * 0.7)
      ..lineTo(x, base - h)
      ..lineTo(x + w / 2, base - h * 0.7)
      ..lineTo(x + w / 2, base)
      ..close();
    c.drawPath(path, _Px.fillOf(a));
    _Px.rect(c, b, x - 1, base - h + 3, 2, h * 0.6);
  }

  static void _hourglass(Canvas c, double x, double y, Color frame, Color sand) {
    _Px.rect(c, frame, x - 7, y - 12, 14, 2);
    _Px.rect(c, frame, x - 7, y + 10, 14, 2);
    for (var k = 0; k < 10; k++) {
      final w = 10 - k;
      _Px.rect(c, const Color(0x66E6DAFF), x - w / 2, y - 10.0 + k, w.toDouble(), 1);
      _Px.rect(c, const Color(0x66E6DAFF), x - w / 2, y + 9.0 - k, w.toDouble(), 1);
    }
    _Px.rect(c, sand, x - 3, y + 6, 6, 3);
    _Px.rect(c, sand, x, y - 1, 1, 7);
  }

  static void _house(Canvas c, double x, double base, double w, double h,
      ArenaPalette p) {
    _Px.rect(c, p.wall, x, base - h, w, h);
    final roof = Path()
      ..moveTo(x - 4, base - h)
      ..lineTo(x + w / 2, base - h - 18)
      ..lineTo(x + w + 4, base - h)
      ..close();
    c.drawPath(roof, _Px.fillOf(const Color(0xFF5A3A6A)));
    for (var i = 0; i < 2; i++) {
      _Px.rect(c, const Color(0xFFFFD98A), x + 10 + i * (w - 28), base - h + 10,
          8, 8);
    }
    _Px.rect(c, p.wall2, x + w / 2 - 5, base - 14, 10, 14);
  }

  static void _bush(Canvas c, double x, double y, Color a, Color b) {
    _Px.oval(c, a, x, y - 6, 12, 7);
    _Px.oval(c, b, x - 3, y - 8, 6, 4);
    _Px.rect(c, const Color(0xFFFF8FB1), x + 4, y - 9, 2, 2);
  }

  static void _stump(Canvas c, double x, double y) {
    _Px.rect(c, const Color(0xFF3A2414), x - 8, y - 10, 16, 10);
    _Px.oval(c, const Color(0xFF6E4A2A), x, y - 10, 8, 3);
    _Px.rect(c, const Color(0xFF8FD14F), x - 10, y - 2, 4, 2);
  }

  static void _weaponRack(Canvas c, double x, double y) {
    _Px.rect(c, const Color(0xFF4A2F1A), x - 10, y - 4, 20, 3);
    for (var k = 0; k < 3; k++) {
      _Px.rect(c, const Color(0xFFB8BCC8), x - 7 + k * 6, y - 22, 2, 20);
      _Px.rect(c, const Color(0xFF4A2F1A), x - 8 + k * 6, y - 6, 4, 2);
    }
  }

  static void _lamp(Canvas c, double x, double y) {
    _Px.rect(c, const Color(0xFF161D33), x - 1, y - 26, 3, 26);
    _Px.rect(c, const Color(0xFFFFD98A), x - 3, y - 32, 7, 6);
    _Px.oval(c, const Color(0x22FFD98A), x, y - 29, 14, 10);
  }

  static void _banner(Canvas c, double x, double top, Color cloth, Color trim,
      {bool torn = false}) {
    _Px.rect(c, const Color(0xFF4A2F1A), x - 10, top - 3, 20, 3);
    _Px.rect(c, cloth, x - 7, top, 14, torn ? 26 : 34);
    _Px.rect(c, trim, x - 7, top, 14, 2);
    _Px.rect(c, trim, x - 7, top, 1, torn ? 26 : 34);
    _Px.rect(c, trim, x + 6, top, 1, torn ? 26 : 34);
    _Px.rect(c, trim, x - 2, top + 10, 4, 6);
    if (!torn) {
      _Px.tri(c, cloth, Offset(x - 7, top + 34), Offset(x + 7, top + 34),
          Offset(x, top + 40));
    } else {
      _Px.rect(c, cloth, x - 7, top + 26, 4, 6);
      _Px.rect(c, cloth, x + 2, top + 26, 3, 3);
    }
  }

  static void _brazier(Canvas c, double x, double y) {
    _Px.rect(c, const Color(0xFF2A2420), x - 2, y - 2, 4, 8);
    _Px.rect(c, const Color(0xFF55505F), x - 6, y - 6, 12, 4);
    _Px.rect(c, const Color(0xFF8C909C), x - 6, y - 6, 12, 1);
  }

  static void _pillar(Canvas c, double x, double base, ArenaPalette p,
      Color light) {
    const h = 120.0;
    _Px.rect(c, const Color(0x55000000), x - 8, base - 2, 22, 6);
    _Px.rect(c, _shade(p.wall, 0.9), x - 9, base - h, 18, h);
    _Px.rect(c, p.wall2.withValues(alpha: 0.6), x - 7, base - h, 2, h);
    _Px.rect(c, _shade(p.wall, 0.5), x + 5, base - h, 4, h);
    _Px.rect(c, _shade(p.wall2, 0.8), x - 12, base - 6, 24, 6);
    _Px.rect(c, _shade(p.wall2, 0.8), x - 12, base - h - 6, 24, 6);
    _Px.rect(c, light, x - 2, base - h + 16, 4, 8);
    _Px.oval(c, light.withValues(alpha: 0.18), x, base - h + 20, 14, 12);
  }

  static void _rune(Canvas c, double x, double y, int i, Color col) {
    final fx = x.floorToDouble(), fy = y.floorToDouble();
    final m = col.withValues(alpha: 0.6);
    switch (i % 4) {
      case 0:
        _Px.rect(c, m, fx - 2, fy - 1, 5, 1);
        _Px.rect(c, m, fx, fy - 2, 1, 5);
      case 1:
        _Px.rect(c, m, fx - 2, fy - 2, 1, 4);
        _Px.rect(c, m, fx - 2, fy - 2, 4, 1);
      case 2:
        _Px.rect(c, m, fx - 1, fy - 1, 3, 3);
      default:
        _Px.rect(c, m, fx - 2, fy + 1, 5, 1);
        _Px.rect(c, m, fx + 2, fy - 2, 1, 3);
    }
  }

  static void _crackLine(Canvas c, double x0, double y0, double a, double rx,
      double ry, Color col, int seed) {
    var x = x0, y = y0;
    const steps = 14;
    for (var k = 0; k < steps; k++) {
      final q = (k + 1) / steps;
      final jx = (_h(seed * 17 + k, 191) - 0.5) * 6;
      final nx = x0 + math.cos(a) * rx * q + jx;
      final ny = y0 + math.sin(a) * ry * q;
      _Px.rect(c, col.withValues(alpha: 0.9 - q * 0.5), math.min(x, nx).floorToDouble(),
          math.min(y, ny).floorToDouble(), (nx - x).abs().ceilToDouble() + 1,
          (ny - y).abs().ceilToDouble() + 1);
      x = nx;
      y = ny;
    }
  }

  static void _web(Canvas c, double x, double y, double r, Color col) {
    final p = Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = false;
    for (var i = 0; i < 7; i++) {
      final a = i / 7 * math.pi;
      c.drawLine(Offset(x, y),
          Offset(x + math.cos(a) * r, y + math.sin(a) * r), p);
    }
    for (var k = 1; k <= 4; k++) {
      c.drawCircle(Offset(x, y), r * k / 4.5, p);
    }
  }

  static void _clockFace(Canvas c, double x, double y, double r, Color rim,
      Color mark) {
    _Px.oval(c, rim, x, y, r + 4, r + 4);
    _Px.oval(c, const Color(0xFF1E1A14), x, y, r, r);
    for (var i = 0; i < 12; i++) {
      final a = i / 12 * math.pi * 2;
      _Px.rect(c, mark, (x + math.cos(a) * (r - 5)).floorToDouble() - 1,
          (y + math.sin(a) * (r - 5)).floorToDouble() - 1, 3, 3);
    }
    final p = Paint()
      ..color = mark
      ..strokeWidth = math.max(1, r / 14)
      ..isAntiAlias = false;
    c.drawLine(Offset(x, y), Offset(x, y - r * 0.7), p);
    c.drawLine(Offset(x, y), Offset(x + r * 0.45, y + r * 0.2), p);
  }

  static void _crown(Canvas c, double x, double y, Color col) {
    _Px.rect(c, col, x - 24, y, 48, 10);
    for (var k = 0; k < 5; k++) {
      _Px.tri(c, col, Offset(x - 24 + k * 12, y), Offset(x - 18 + k * 12, y),
          Offset(x - 21 + k * 12, y - 12));
    }
    _Px.rect(c, const Color(0xFFFFD166), x - 3, y + 2, 6, 6);
    _Px.oval(c, col.withValues(alpha: 0.15), x, y, 60, 30);
  }
}

enum _Mote { fall, rise, drift, twinkle }

/// Primitivas sin antialias.
abstract final class _Px {
  static final _fill = Paint()..isAntiAlias = false;
  static final image = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  static Paint fillOf(Color c) => Paint()
    ..color = c
    ..isAntiAlias = false;

  static void rect(Canvas c, Color color, double x, double y, double w,
      double h) {
    _fill.color = color;
    c.drawRect(Rect.fromLTWH(x.floorToDouble(), y.floorToDouble(),
        w.roundToDouble(), h.roundToDouble()), _fill);
  }

  static void oval(
      Canvas c, Color color, double cx, double cy, double rx, double ry) {
    _fill.color = color;
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx.floorToDouble(), cy.floorToDouble()),
            width: (rx * 2).roundToDouble(),
            height: (ry * 2).roundToDouble()),
        _fill);
  }

  static void ovalRect(Canvas c, Color color, Rect r) {
    _fill.color = color;
    c.drawOval(r, _fill);
  }

  static void ovalStroke(Canvas c, Color color, Rect r, double w) {
    c.drawOval(
        r,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..isAntiAlias = false);
  }

  static void stroke(Canvas c, Color color, Rect r) {
    c.drawRect(
        r,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..isAntiAlias = false);
  }

  static void tri(Canvas c, Color color, Offset a, Offset b, Offset d) {
    c.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(d.dx, d.dy)
          ..close(),
        fillOf(color));
  }
}
