import 'package:material_ui/material_ui.dart';

import '../../../core/screen_layout/screen_bindings.dart';
import '../../theme/retro_type.dart';
import '../ds_tokens.dart';
import 'ds_registry_defaults.dart';

/// Nivel atómico (design_system.md § 6 bis).
enum DsLevel { atom, molecule, organism, template }

extension DsLevelLabel on DsLevel {
  String get label => switch (this) {
        DsLevel.atom => 'ÁTOMOS',
        DsLevel.molecule => 'MOLÉCULAS',
        DsLevel.organism => 'ORGANISMOS',
        DsLevel.template => 'PLANTILLAS',
      };
}

/// Estilos de texto con nombre del DS (los únicos que un layout elige).
enum DsTextStyleId { display, title, subtitle, body, detail }

extension DsTextStyleInfo on DsTextStyleId {
  String get label => switch (this) {
        DsTextStyleId.display => 'Display',
        DsTextStyleId.title => 'Título',
        DsTextStyleId.subtitle => 'Subtítulo',
        DsTextStyleId.body => 'Texto',
        DsTextStyleId.detail => 'Detalle',
      };

  /// Tamaño nominal en px.
  double get nominal => switch (this) {
        DsTextStyleId.display => RetroType.display,
        DsTextStyleId.title => RetroType.title,
        DsTextStyleId.subtitle => RetroType.label,
        DsTextStyleId.body => RetroType.body,
        DsTextStyleId.detail => RetroType.small,
      };

  /// Color por defecto del estilo (rol de texto).
  Color get color => switch (this) {
        DsTextStyleId.display || DsTextStyleId.title => DsColors.textTitle,
        DsTextStyleId.subtitle => DsColors.textSubtitle,
        DsTextStyleId.body => DsColors.textPrimary,
        DsTextStyleId.detail => DsColors.textSecondary,
      };

  TextStyle style([Color? c]) => switch (this) {
        DsTextStyleId.display => DsText.display(c),
        DsTextStyleId.title => DsText.title(c),
        DsTextStyleId.subtitle => DsText.subtitle(c),
        DsTextStyleId.body => DsText.body(c),
        DsTextStyleId.detail => DsText.detail(c),
      };

  static DsTextStyleId? parse(String? s) =>
      DsTextStyleId.values.where((v) => v.name == s).firstOrNull;
}

/// Props que el inspector deja editar.
enum DsProp { text, variant, size, textStyle, role, align, action, dataSource, slot }

/// Variante o tamaño con nombre.
class DsVariant {
  const DsVariant(this.id, this.label);
  final String id;
  final String label;
}

/// Lo que la fábrica recibe para dibujar un elemento.
class DsElementContext {
  const DsElementContext({
    this.text = '',
    this.variant,
    this.size,
    this.textStyle,
    this.align = TextAlign.start,
    this.onPressed,
    this.tooltip,
    this.data = const [],
    this.slot,
    this.slotLabel,
    this.preview = false,
  });

  final String text;
  final String? variant;
  final String? size;
  final DsTextStyleId? textStyle;
  final TextAlign align;

  /// `null` = deshabilitado (gris).
  final VoidCallback? onPressed;
  final String? tooltip;
  final List<ScreenDataEntry> data;

  /// Hueco armado por la pantalla (o `null` en el editor).
  final Widget? slot;
  final String? slotLabel;

  /// Dibujado en el editor (sin lógica real).
  final bool preview;
}

typedef DsPreviewFactory = Widget Function(
    BuildContext context, DsElementContext element);

/// Un componente del DS registrado para la paleta del editor de
/// pantallas (docs/specs/screen_editor.md § 1).
class DsComponentSpec {
  const DsComponentSpec({
    required this.id,
    required this.name,
    required this.level,
    required this.build,
    this.variants = const [],
    this.sizes = const [],
    this.props = const {},
    this.textStyles = const [],
    this.defaultText,
    this.defaultSize = const Size(160, 40),
    this.interactive = false,
    this.surface,
    this.textColor,
    this.textPadding = EdgeInsets.zero,
  });

  final String id;
  final String name;
  final DsLevel level;
  final List<DsVariant> variants;
  final List<DsVariant> sizes;
  final Set<DsProp> props;

  /// Estilos de texto permitidos (el primero es el por defecto).
  final List<DsTextStyleId> textStyles;
  final String? defaultText;
  final Size defaultSize;

  /// Clickeable: entra en objetivo de clic, foco y acción.
  final bool interactive;

  /// Si es una superficie: su color de fondo por variante (para el
  /// contraste de lo que tenga encima). `null` = transparente.
  final Color? Function(String? variant)? surface;

  /// Color del texto por variante y estilo (contraste).
  final Color Function(String? variant, DsTextStyleId style)? textColor;

  /// Aire entre la caja y el texto (texto recortado).
  final EdgeInsets textPadding;
  final DsPreviewFactory build;

  String? get defaultVariant => variants.firstOrNull?.id;
  String? get defaultSizeId => sizes.firstOrNull?.id;
  DsTextStyleId? get defaultTextStyle => textStyles.firstOrNull;

  bool hasVariant(String? v) => variants.any((x) => x.id == v);
}

/// Registro de componentes del DS. Un componente nuevo que se registre
/// (en [dsDefaultComponents] o con [register]) aparece en la paleta.
class DsRegistry {
  DsRegistry([Iterable<DsComponentSpec> specs = const []]) {
    specs.forEach(register);
  }

  static final instance = DsRegistry(dsDefaultComponents);

  final _specs = <String, DsComponentSpec>{};

  void register(DsComponentSpec s) {
    if (_specs.containsKey(s.id)) {
      throw StateError('componente repetido: ${s.id}');
    }
    _specs[s.id] = s;
  }

  DsComponentSpec? operator [](String id) => _specs[id];
  List<DsComponentSpec> get all => _specs.values.toList();
  List<DsComponentSpec> byLevel(DsLevel l) =>
      [for (final s in _specs.values) if (s.level == l) s];
}
