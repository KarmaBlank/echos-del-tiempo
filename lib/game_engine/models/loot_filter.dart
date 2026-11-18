import 'build_wants.dart';
import 'item.dart';

// Filtros de loot (docs/specs/loot.md § 13): reglas en orden, gana la
// primera que coincide. El texto (importar / exportar / guardar en el
// perfil) lo leen y escriben `LootFilterRules.parse` / `serialize`.

/// Comparación de una condición numérica.
enum FilterOp {
  eq('='),
  ne('!='),
  lt('<'),
  le('<='),
  gt('>'),
  ge('>=');

  const FilterOp(this.symbol);
  final String symbol;

  bool test(num a, num b) => switch (this) {
        FilterOp.eq => a == b,
        FilterOp.ne => a != b,
        FilterOp.lt => a < b,
        FilterOp.le => a <= b,
        FilterOp.gt => a > b,
        FilterOp.ge => a >= b,
      };

  static FilterOp? bySymbol(String s) {
    for (final o in values) {
      if (o.symbol == s) return o;
    }
    if (s == '==') return FilterOp.eq;
    return null;
  }
}

/// Qué es lo que cayó (condición `Objeto`).
enum LootKind {
  arma('Arma'),
  material('Material'),
  pocion('Pocion'),

  /// Eco (docs/specs/ecos_atlas.md § 3).
  eco('Eco');

  const LootKind(this.word);
  final String word;
}

/// Una condición de una regla. [keyword] y [args] son su forma de texto.
sealed class FilterCondition {
  const FilterCondition();
  String get keyword;
  String get args;
  String get text => args.isEmpty ? keyword : '$keyword $args';

  @override
  bool operator ==(Object other) =>
      other is FilterCondition && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// `Rareza >= Raro`.
class RarityCondition extends FilterCondition {
  const RarityCondition(this.op, this.rarity);
  final FilterOp op;
  final Rarity rarity;
  @override
  String get keyword => 'Rareza';
  @override
  String get args =>
      '${op == FilterOp.eq ? '' : '${op.symbol} '}${rarity.label}';
}

/// `Tipo espada hacha` (cualquiera de esos tipos de arma).
class TypeCondition extends FilterCondition {
  const TypeCondition(this.types);
  final List<String> types;
  @override
  String get keyword => 'Tipo';
  @override
  String get args => types.join(' ');
}

/// `Base espada_ignea arco_corto`.
class BaseCondition extends FilterCondition {
  const BaseCondition(this.baseIds);
  final List<String> baseIds;
  @override
  String get keyword => 'Base';
  @override
  String get args => baseIds.join(' ');
}

/// `Clase guerrero` (familia de la base).
class FamilyCondition extends FilterCondition {
  const FamilyCondition(this.families);
  final List<String> families;
  @override
  String get keyword => 'Clase';
  @override
  String get args => families.join(' ');
}

/// `NivelObjeto >= 10`.
class ItemLevelCondition extends FilterCondition {
  const ItemLevelCondition(this.op, this.level);
  final FilterOp op;
  final int level;
  @override
  String get keyword => 'NivelObjeto';
  @override
  String get args => '${op.symbol} $level';
}

/// `NivelRelativo <= -6` (nivel del objeto − tu nivel).
class RelativeLevelCondition extends FilterCondition {
  const RelativeLevelCondition(this.op, this.delta);
  final FilterOp op;
  final int delta;
  @override
  String get keyword => 'NivelRelativo';
  @override
  String get args => '${op.symbol} $delta';
}

/// `Mods >= 3` (cantidad de afijos).
class ModCountCondition extends FilterCondition {
  const ModCountCondition(this.op, this.count);
  final FilterOp op;
  final int count;
  @override
  String get keyword => 'Mods';
  @override
  String get args => '${op.symbol} $count';
}

/// `TieneMod feroz <= 2`: tiene el afijo (y, si se da, con tier que
/// cumple la comparación; T1 es el mejor). Un mod fijo de legendario
/// cuenta como tier 1.
class HasModCondition extends FilterCondition {
  const HasModCondition(this.affixId, {this.op, this.tier});
  final String affixId;
  final FilterOp? op;
  final int? tier;
  @override
  String get keyword => 'TieneMod';
  @override
  String get args =>
      op == null || tier == null ? affixId : '$affixId ${op!.symbol} $tier';
}

/// `Pasiva` / `Pasiva No`: tiene pasiva de arma.
class PassiveCondition extends FilterCondition {
  const PassiveCondition(this.has);
  final bool has;
  @override
  String get keyword => 'Pasiva';
  @override
  String get args => has ? '' : 'No';
}

/// `Material esquirla prisma`.
class MaterialCondition extends FilterCondition {
  const MaterialCondition(this.materials);
  final List<CraftMaterial> materials;
  @override
  String get keyword => 'Material';
  @override
  String get args => [for (final m in materials) m.name].join(' ');
}

/// `Objeto Arma` / `Material` / `Pocion`.
class KindCondition extends FilterCondition {
  const KindCondition(this.kinds);
  final List<LootKind> kinds;
  @override
  String get keyword => 'Objeto';
  @override
  String get args => [for (final k in kinds) k.word].join(' ');
}

/// `Utilizable` / `Utilizable No`: cumplís el nivel y los requisitos de
/// atributos de la base con tus atributos actuales.
class UsableCondition extends FilterCondition {
  const UsableCondition(this.usable);
  final bool usable;
  @override
  String get keyword => 'Utilizable';
  @override
  String get args => usable ? '' : 'No';
}

/// `Tier >= 5` (solo Ecos; docs/specs/ecos_atlas.md § 3).
class TierCondition extends FilterCondition {
  const TierCondition(this.op, this.tier);
  final FilterOp op;
  final int tier;
  @override
  String get keyword => 'Tier';
  @override
  String get args => '${op.symbol} $tier';
}

/// `Build` / `Build Mod Pasiva` / `Build No` ("Coincide con mi build"):
/// el arma cumple algo del plan de build de quien la mira (con [kinds],
/// alguna de esas clases; vacío = cualquiera). Con [has] `false`, no
/// cumple nada del plan. Solo armas. Docs/specs/loot.md § 13.
class BuildCondition extends FilterCondition {
  const BuildCondition({this.kinds = const [], this.has = true});
  final List<BuildMatch> kinds;
  final bool has;
  @override
  String get keyword => 'Build';
  @override
  String get args => has ? [for (final k in kinds) k.word].join(' ') : 'No';
}

/// Color RGBA (0–255).
class FilterColor {
  const FilterColor(this.r, this.g, this.b, [this.a = 255]);
  final int r, g, b, a;

  String get text => a == 255 ? '$r $g $b' : '$r $g $b $a';

  @override
  bool operator ==(Object other) =>
      other is FilterColor &&
      other.r == r &&
      other.g == g &&
      other.b == b &&
      other.a == a;

  @override
  int get hashCode => Object.hash(r, g, b, a);
}

/// Formas del ícono del minimapa.
enum MapIconShape { circulo, estrella, triangulo, cuadrado, diamante }

/// Colores del ícono del minimapa.
enum MapIconColor { blanco, rojo, verde, azul, amarillo, naranja, violeta, celeste }

class MapIcon {
  const MapIcon(this.shape, this.color);
  final MapIconShape shape;
  final MapIconColor color;

  @override
  bool operator ==(Object other) =>
      other is MapIcon && other.shape == shape && other.color == color;

  @override
  int get hashCode => Object.hash(shape, color);
}

/// Sonidos de un filtro (la UI los traduce a su catálogo de SFX).
const kLootFilterSounds = [
  'alerta',
  'campana',
  'gema',
  'legendario',
  'material',
  'suave',
];

/// Cómo se muestra lo que coincide. `null` = el valor por defecto.
class FilterStyle {
  const FilterStyle({
    this.textColor,
    this.borderColor,
    this.backgroundColor,
    this.size,
    this.sound,
    this.icon,
  });

  final FilterColor? textColor;
  final FilterColor? borderColor;
  final FilterColor? backgroundColor;

  /// Tamaño del texto ([minSize]–[maxSize], por defecto [defaultSize]).
  final int? size;
  final String? sound;
  final MapIcon? icon;

  static const minSize = 18;
  static const maxSize = 45;
  static const defaultSize = 32;

  static const empty = FilterStyle();

  /// Este estilo con lo que falta tomado de [base].
  FilterStyle over(FilterStyle base) => FilterStyle(
        textColor: textColor ?? base.textColor,
        borderColor: borderColor ?? base.borderColor,
        backgroundColor: backgroundColor ?? base.backgroundColor,
        size: size ?? base.size,
        sound: sound ?? base.sound,
        icon: icon ?? base.icon,
      );

  @override
  bool operator ==(Object other) =>
      other is FilterStyle &&
      other.textColor == textColor &&
      other.borderColor == borderColor &&
      other.backgroundColor == backgroundColor &&
      other.size == size &&
      other.sound == sound &&
      other.icon == icon;

  @override
  int get hashCode =>
      Object.hash(textColor, borderColor, backgroundColor, size, sound, icon);
}

/// Una regla: mostrar u ocultar lo que cumple TODAS sus condiciones.
class FilterRule {
  const FilterRule({
    required this.show,
    this.name,
    this.conditions = const [],
    this.style = FilterStyle.empty,
  });

  final bool show;

  /// Nombre opcional (comentario en la línea `Mostrar # nombre`).
  final String? name;
  final List<FilterCondition> conditions;
  final FilterStyle style;

  @override
  bool operator ==(Object other) =>
      other is FilterRule &&
      other.show == show &&
      other.name == name &&
      other.style == style &&
      other.conditions.length == conditions.length &&
      [
        for (var i = 0; i < conditions.length; i++)
          other.conditions[i] == conditions[i]
      ].every((x) => x);

  @override
  int get hashCode =>
      Object.hash(show, name, style, Object.hashAll(conditions));
}

/// Un filtro de loot completo.
class LootFilter {
  const LootFilter(this.rules);
  final List<FilterRule> rules;

  @override
  bool operator ==(Object other) =>
      other is LootFilter &&
      other.rules.length == rules.length &&
      [for (var i = 0; i < rules.length; i++) other.rules[i] == rules[i]]
          .every((x) => x);

  @override
  int get hashCode => Object.hashAll(rules);
}

/// Resultado de evaluar un drop.
class FilterVerdict {
  const FilterVerdict(this.visible, this.style,
      [this.ruleIndex, this.build = const {}]);
  final bool visible;

  /// Qué cumple del plan de build de quien lo mira (vacío = nada o sin
  /// plan). La UI le pone ★ a la etiqueta (build_planner.md § 6).
  final Set<BuildMatch> build;

  bool get buildMatch => build.isNotEmpty;

  /// Estilo final (la regla sobre el estilo por defecto de la rareza).
  final FilterStyle style;

  /// Índice de la regla que coincidió (`null` = ninguna).
  final int? ruleIndex;
}
