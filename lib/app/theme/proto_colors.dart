import 'package:material_ui/material_ui.dart';

import 'ui_theme.dart';
import 'vision_palette.dart';

/// Paleta de la UI HTML del prototipo (`<style>` y los `color:` en línea
/// de `hud()`, `descSkill`, `weaponTip`, `renderPanel`, ...). Ver
/// docs/specs/ui_style.md § "Paleta".
///
/// Los colores de interfaz (fondos, paneles, botones, bordes y texto) son
/// [ThemeColor]: cambian con el TEMA DE INTERFAZ (accessibility.md § 8).
///
/// Los colores con significado (`green`, `red`, `crimson`, `hp`, `mp`)
/// son [VisionColor]: siguen siendo `const` pero se pintan con la paleta
/// del modo daltónico activo (docs/specs/accessibility.md § 3).
abstract final class ProtoColors {
  /// Fondo de `body`; `#tip` con alfa `f5`.
  static const bg = ThemeColor(UiSlot.bg);

  /// Texto base de `body`.
  static const ink = ThemeColor(UiSlot.ink);

  /// `.pbox`, `.panel`, `#menu`.
  static const panel = ThemeColor(UiSlot.panel);

  /// Borde de `.pbox`, `.mrow`, canvas.
  static const panelBorder = ThemeColor(UiSlot.panelBorder);

  /// `button`.
  static const button = ThemeColor(UiSlot.button);
  static const buttonBorder = ThemeColor(UiSlot.buttonBorder);
  static const buttonHover = ThemeColor(UiSlot.buttonHover);
  static const buttonHoverBorder = ThemeColor(UiSlot.buttonHoverBorder);

  /// `input`.
  static const input = ThemeColor(UiSlot.input);
  static const inputBorder = ThemeColor(UiSlot.inputBorder);

  /// Nombres y títulos (rol `title`, accessibility.md § 8): con los
  /// colores COMPLETOS es [gold]; por roles, casi blanco.
  static const title = ThemeColor(UiSlot.title);

  /// `<b>` del tip y del menú, créditos, jugador local, títulos.
  static const gold = ThemeColor(UiSlot.gold);

  /// `.k` del tip, clase y nivel, DEF/VEL, `small`.
  static const sky = ThemeColor(UiSlot.sky);

  /// `.help`, XP y créditos, "Turno en N".
  static const dim = ThemeColor(UiSlot.dim);

  /// `#chatlog`.
  static const chat = ThemeColor(UiSlot.chat);

  /// `.sys`, `#mission`, curas, requisitos cumplidos, `TIENES`.
  static const green = VisionColor(VisionSlot.good);

  /// Relleno de `.hp`.
  static const hp = VisionColor(VisionSlot.hp);

  /// Relleno de `.mp`.
  static const mp = VisionColor(VisionSlot.mp);

  /// Fondo de `.bar`.
  static const barBg = ThemeColor(UiSlot.barBg);

  /// MP de técnicas, DEF de escudo, éter, Congelación.
  static const ice = ThemeColor(UiSlot.ice);

  /// `#err`, requisitos que faltan, `+% crít`, tiempo ≤ 10 s.
  static const red = VisionColor(VisionSlot.bad);

  /// Timer ≤ 10 s del menú, golpe crítico recibido.
  static const crimson = VisionColor(VisionSlot.crimson);

  /// Arma equipada, `(fusión)`, avisos.
  static const orange = ThemeColor(UiSlot.orange);

  /// Borde de `button.dual`.
  static const amber = Color(0xFFFF9F1C);

  /// ULT lista / nombre de la ULT en los tips.
  static const pink = ThemeColor(UiSlot.pink);

  /// ULT cargando.
  static const violet = ThemeColor(UiSlot.violet);

  /// Protege, aturdir del Paladín.
  static const cream = Color(0xFFFFEAA7);

  /// Sagrado.
  static const holy = Color(0xFFFFF3B0);

  /// Regeneración.
  static const mint = Color(0xFF55EFC4);

  /// Quemadura.
  static const burn = Color(0xFFFF7B29);

  /// Provoca.
  static const taunt = Color(0xFFFF7675);

  /// Sombra del título y del rango grande.
  static const titleShadow = Color(0xFFA3471D);

  static const white = Color(0xFFFFFFFF);

  /// Rareza Común (significado: no cambia con el tema).
  static const common = Color(0xFFDCDCDC);

  /// Sombra de cajas flotantes (tooltips, fichas, tarjetas): negro al
  /// 67 % en todos los temas.
  static const shadow = Color(0xAA000000);

  /// Fondo translúcido del HUD (cajas de avisos, objetivos, registro de
  /// loot, velos detrás de paneles): el fondo del tema activo con [alpha].
  /// Accessibility.md § 8.4: toda caja de la UI sigue al tema.
  static Color scrim([double alpha = 0.67]) =>
      UiTheme.of(UiSlot.bg).withValues(alpha: alpha);

  /// `#rgb`, `#rrggbb` o `#rrggbbaa` (orden CSS) → [Color]; `null` si no
  /// se entiende.
  static Color? parse(String hex) {
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 3) h = h.split('').map((c) => c + c).join();
    if (h.length == 6) h = '${h}ff';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    // CSS es RRGGBBAA; Flutter, AARRGGBB.
    final c = Color(((v & 0xFF) << 24) | (v >> 8));
    // Hex viejo → token suavizado; hex de un color con significado (o de
    // una rareza) → el del modo daltónico activo.
    return legacy[c.toARGB32()] ??
        _canonical[c.toARGB32()] ??
        VisionPalette.remap(c);
  }

  /// Accesibilidad (v0.5, docs/specs/accessibility.md § 2): los colores
  /// de texto del prototipo se veían "fosforescentes" o no llegaban a AA;
  /// los tokens de arriba son la versión suavizada (≈ mitad de saturación,
  /// ≥ 4.5:1 sobre `button`). El markup que todavía escribe el hex viejo
  /// se pinta con el token nuevo.
  static const legacy = <int, Color>{
    // Hex del prototipo (y de la primera pasada AA) → token suavizado.
    0xFFE8ECFF: ink,
    0xFFFFD166: gold,
    0xFF9FB4FF: sky,
    0xFF7D8BC4: dim,
    0xFF8D99CB: dim,
    0xFF7BED9F: green,
    0xFFFF6B81: red,
    0xFFFF4757: crimson,
    0xFFFF6B78: crimson,
    0xFFFF9F43: orange,
    0xFFA29BFE: violet,
    0xFFE84393: pink,
    0xFFEE70AD: pink,
    0xFF74B9FF: ice,
  };

  /// Hex de AZUL de cada token de texto → el token (el markup que arma
  /// [hex] vuelve a ser el token, y sigue al tema y a los roles).
  static final Map<int, Color> _canonical = {
    for (final s in const [
      UiSlot.ink,
      UiSlot.gold,
      UiSlot.sky,
      UiSlot.dim,
      UiSlot.chat,
      UiSlot.ice,
      UiSlot.orange,
      UiSlot.violet,
      UiSlot.pink,
    ])
      UiTheme.inTheme(InterfaceTheme.blue, s).toARGB32(): ThemeColor(s),
  };

  /// `#rrggbb` de [c] (para armar markup). Un token escribe su valor
  /// canónico (AZUL / modo daltónico apagado): [parse] lo vuelve a leer
  /// como el token, en el tema y el modo que estén activos al pintar.
  static String hex(Color c) {
    final v = switch (c) {
      ThemeColor() => c.base,
      VisionColor() => VisionPalette.inMode(ColorVision.off, c.slot),
      _ => c,
    };
    return '#${(v.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }
}
