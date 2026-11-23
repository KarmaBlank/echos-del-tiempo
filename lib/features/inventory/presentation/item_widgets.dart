import 'package:material_ui/material_ui.dart';
import '../domain/item_names.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/theme/vision_palette.dart';
import '../../../core/procedural/item_icons.dart';
import '../../../core/procedural/weapon_look.dart';
import '../../build_planner/presentation/build_fit_badge.dart' show kPlanColor;
import '../../../game_engine/models/eco.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/loot.dart';
import '../../../game_engine/models/loot_filter.dart';
import '../../../game_engine/rules/loot_filter_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';
import 'inventory_strings.dart';

/// Piezas visuales de objetos (loot v2): colores de rareza, ícono pixel,
/// casilla de inventario y etiqueta de loot con el estilo del filtro.
/// Ver docs/specs/panels.md § "Ficha de objeto" e § "Inventario".

/// Colores de rareza: los mismos del filtro en el mapa
/// (`LootFilterRules.rarityColor`).
abstract final class RarityColors {
  /// Con el modo daltónico, el de su paleta (`VisionPalette`).
  static Color of(Rarity r) => filterColor(LootFilterRules.rarityColor(r));

  /// [FilterColor] → [Color] (los de rareza por defecto, con el modo
  /// daltónico).
  static Color filterColor(FilterColor c) =>
      VisionPalette.remap(Color.fromARGB(c.a, c.r, c.g, c.b));

  /// Letra de la rareza (C M R E L): la rareza no se dice solo con el
  /// color (daltonismo; docs/specs/accessibility.md § 2).
  static String letter(Rarity r) => switch (r) {
        Rarity.comun => 'C',
        Rarity.magico => 'M',
        Rarity.raro => 'R',
        Rarity.epico => 'E',
        Rarity.legendario => 'L',
      };

  /// Color de una pila (materiales: celeste, como el filtro por defecto).
  static const stack = Color(0xFF78E6DC);
}

// ---------------------------------------------------------------------
// Íconos pixel (8 × 8)
// ---------------------------------------------------------------------
// Las formas y el pintor son el generador `item_icon`
// (lib/core/procedural/item_icons.dart; game_editor.md § 7.5).

/// Clave del ícono de un tipo de arma: las armas con escudo muestran la
/// combinación (`espada+escudo` → `espada_escudo`); un tipo con escudo
/// sin forma propia cae al escudo solo.
String iconKeyForType(String type) {
  if (kItemIconRows.containsKey(type)) return type;
  if (type.contains('escudo')) {
    final k = type.replaceAll('+', '_');
    return kItemIconRows.containsKey(k) ? k : 'escudo';
  }
  return 'espada';
}

/// Clave y color de acento del ícono de una pila.
(String, Color) iconForStack(StackKind k) => switch (k) {
      StackKind.potion => ('pocion', ProtoColors.red),
      StackKind.ether => ('pocion', ProtoColors.ice),
      StackKind.aether => ('pocion', ProtoColors.gold),
      StackKind.esquirla => ('esquirla', RarityColors.stack),
      StackKind.cristal => ('cristal', ProtoColors.violet),
      StackKind.prisma => ('prisma', ProtoColors.gold),
      StackKind.ancla => ('ancla', ProtoColors.sky),
      // Jefes del Abismo v0.8: Fragmentos y Esencia.
      StackKind.fragReloj => ('fragmento', ProtoColors.gold),
      StackKind.fragEco => ('fragmento', ProtoColors.ice),
      StackKind.fragCorona => ('fragmento', ProtoColors.violet),
      StackKind.fragEras => ('fragmento', ProtoColors.orange),
      StackKind.esencia => ('esencia', ProtoColors.crimson),
    };

/// Ícono pixel (8 × 8 escalado) sin difuminado.
class PixelIcon extends StatelessWidget {
  const PixelIcon(this.iconKey,
      {super.key,
      this.accent = ProtoColors.ice,
      this.size = 32,
      this.procKey,
      this.look});

  final String iconKey;
  final Color accent;
  final double size;

  /// Entrada `items.<procKey>` del manifest cuyas perillas usa
  /// (`procKeyForType`); `null` = las de la familia `items`.
  final String? procKey;

  /// Identidad del arma (aura sutil del elemento, ULT, variante).
  final WeaponLook? look;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: ItemIconPainter(
            kItemIconRows[iconKey] ?? kItemIconRows['espada']!, accent,
            procKey == null ? 'items' : 'items.$procKey',
            look: look)
          ..pngKey = ItemIconImages.keyOf(
              kItemIconRows.containsKey(iconKey) ? iconKey : 'espada'),
      );
}

// ---------------------------------------------------------------------
// Casilla
// ---------------------------------------------------------------------

/// Lo que hay en una casilla, resuelto para dibujar.
class CellContent {
  const CellContent.item(ItemInstance this.item)
      : stack = null,
        eco = null,
        count = 1;
  const CellContent.stack(StackKind this.stack, this.count)
      : item = null,
        eco = null;
  const CellContent.eco(EcoItem this.eco)
      : item = null,
        stack = null,
        count = 1;

  final ItemInstance? item;
  final StackKind? stack;

  /// Eco (docs/specs/ecos_atlas.md § 2).
  final EcoItem? eco;
  final int count;
}

/// Color del marco de los Ecos (turquesa, como el filtro por defecto).
const kEcoColor = Color(0xFF5AE6D2);

/// Casilla de inventario de [size] px: fondo `input`, borde del color de
/// la rareza (2 px; dorado y 3 px si está elegida), el ícono y, en las
/// pilas, la cantidad abajo a la derecha.
class ItemCell extends StatelessWidget {
  const ItemCell({
    super.key,
    required this.rules,
    this.content,
    this.selected = false,
    this.highlight = false,
    this.size = 44,
    this.buildMatch = false,
  });

  final ProgressionRules rules;
  final CellContent? content;
  final bool selected;

  /// El arma cumple metas del plan de build: ★ arriba a la derecha
  /// (docs/specs/build_planner.md § 4.1).
  final bool buildMatch;

  /// Destino posible de un arrastre o de MOVER.
  final bool highlight;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = content;
    final Color border;
    Widget? icon;
    // Escala de la casilla (44 px = 1): el ícono crece en proporción.
    final k = size / 44;
    if (c?.item case final it?) {
      border = RarityColors.of(it.rarity);
      final type = rules.catalog.weapons[it.baseId]?.type ?? 'espada';
      icon = PixelIcon(iconKeyForType(type),
          accent: RarityColors.of(it.rarity),
          size: size - 12 * k,
          procKey: procKeyForType(type),
          look: WeaponLook.of(it));
    } else if (c?.eco case final e?) {
      border = RarityColors.of(e.rarity);
      // Más chico y arriba: abajo a la derecha va el tier.
      icon = Align(
          alignment: const Alignment(-0.5, -0.6),
          child: PixelIcon('eco', accent: kEcoColor, size: size - 16 * k));
    } else if (c?.stack case final st?) {
      border = ProtoColors.panelBorder;
      final (key, accent) = iconForStack(st);
      icon = PixelIcon(key,
          accent: accent,
          size: size - 12 * k,
          procKey: key == 'pocion' ? 'pocion' : null);
    } else {
      border = ProtoColors.panelBorder;
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: highlight ? ProtoColors.buttonHover : ProtoColors.input,
        border: Border.all(
          color: selected ? ProtoColors.gold : border,
          width: selected ? 3 : RetroTheme.thinBorderWidth,
        ),
      ),
      child: Stack(
        children: [
          if (icon != null) Center(child: icon),
          // Letra de la rareza arriba a la izquierda (no solo el color).
          if ((c?.item?.rarity ?? c?.eco?.rarity) case final r?)
            Positioned(
              left: 2,
              top: 1,
              child: Text(RarityColors.letter(r),
                  key: const ValueKey('cell-rarity'),
                  textScaler: RetroType.fixedScaler(context),
                  style: TextStyle(
                      fontFamily: RetroType.pixelFamily,
                      fontSize: RetroType.label,
                      height: 1,
                      color: RarityColors.of(r),
                      shadows: const [Shadow(offset: Offset(1, 1))])),
            ),
          if (buildMatch)
            Positioned(
              right: 2,
              top: 1,
              child: Text('★',
                  key: const ValueKey('cell-build'),
                  textScaler: RetroType.fixedScaler(context),
                  style: const TextStyle(
                      fontFamily: RetroType.pixelFamily,
                      fontSize: RetroType.label,
                      height: 1,
                      color: kPlanColor,
                      shadows: [Shadow(offset: Offset(1, 1))])),
            ),
          if (c?.eco case final e?)
            Positioned(
              right: 2,
              bottom: 0,
              child: Text('T${e.tier}',
                  // Casilla de tamaño fijo: nítido pero sin agrandarse.
                  textScaler: RetroType.fixedScaler(context),
                  style: const TextStyle(
                      fontFamily: RetroType.pixelFamily,
                      fontSize: RetroType.label,
                      color: kEcoColor,
                      shadows: [Shadow(offset: Offset(1, 1))])),
            ),
          if (c?.stack != null)
            Positioned(
              right: 2,
              bottom: 0,
              child: Text('${c!.count}',
                  textScaler: RetroType.fixedScaler(context),
                  style: const TextStyle(
                      fontFamily: RetroType.pixelFamily,
                      fontSize: RetroType.label,
                      color: ProtoColors.ink,
                      shadows: [Shadow(offset: Offset(1, 1))])),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Etiqueta de loot (estilo del filtro)
// ---------------------------------------------------------------------

/// Etiqueta de un drop como se vería en el mapa con el estilo del filtro
/// ([verdict]): color de texto, borde y fondo; tamaño [RetroType.small]
/// (≥ 36 en el filtro: [RetroType.title]). Oculto: texto `dim` y `(oculto)`.
class LootLabel extends StatelessWidget {
  const LootLabel({
    super.key,
    required this.text,
    required this.verdict,
    this.hiddenNote,
    this.tooltip,
  });

  final String text;
  final FilterVerdict verdict;
  /// `null` = the generic `(oculto)` note.
  final String? hiddenNote;

  /// Ficha al pasar el mouse (markup).
  final String? tooltip;

  /// Tamaño de letra para un tamaño de filtro (18–45).
  static double fontSizeFor(int? size) =>
      (size ?? FilterStyle.defaultSize) >= 36
          ? RetroType.title
          : RetroType.small;

  @override
  Widget build(BuildContext context) {
    final st = verdict.style;
    // ★ = cumple tu plan de build (build_planner.md § 6).
    final text = verdict.buildMatch ? '★ ${this.text}' : this.text;
    Widget label;
    if (!verdict.visible) {
      final note =
          hiddenNote ?? invStrings(context).t('ui.inventory.item.hidden');
      label = Text(retroText('$text $note'),
          style: const TextStyle(
              color: ProtoColors.dim, decoration: TextDecoration.lineThrough));
    } else {
      final bg = st.backgroundColor;
      final bd = st.borderColor;
      label = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: bg == null
              ? ProtoColors.scrim(0.8)
              : RarityColors.filterColor(bg),
          border: bd == null
              ? null
              : Border.all(color: RarityColors.filterColor(bd), width: 2),
        ),
        child: Text(retroText(text),
            style: TextStyle(
                fontFamilyFallback: RetroType.bodyFallback,
                fontFamily: RetroType.familyFor(fontSizeFor(st.size)),
                fontSize: fontSizeFor(st.size),
                height: 1.4,
                color: st.textColor == null
                    ? ProtoColors.ink
                    : RarityColors.filterColor(st.textColor!))),
      );
    }
    if (tooltip != null) label = RetroTooltip(message: tooltip!, child: label);
    return label;
  }
}

/// Texto de una etiqueta de drop: nombre del arma o `N Material`.
String dropLabelText(ProgressionRules rules, LootDrop d) {
  final it = d.item;
  if (it != null) return localItemName(rules.items, it);
  final eco = d.eco;
  if (eco != null) return rules.ecos.fullName(eco);
  return d.count > 1 ? '${d.count} ${d.stack!.label}' : d.stack!.label;
}
