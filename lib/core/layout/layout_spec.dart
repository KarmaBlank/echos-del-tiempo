import 'layout_doc.dart';

/// Región que declara el código de una pantalla (§ 2.1). El editor no
/// crea regiones (§ 5, P3).
class LayoutRegionSpec {
  const LayoutRegionSpec(this.id,
      {this.axis = LayoutAxis.column,
      this.label,
      this.spacing = 'md',
      this.runSpacing = 'xs',
      this.align});
  final String id;
  final LayoutAxis axis;
  final String? label;

  /// Separación entre líneas de una región `wrap`.
  final String runSpacing;

  /// Alineación de la región (`wrap`: de cada línea; `column`: de los
  /// hijos). `null` = al principio.
  final LayoutAlign? align;

  /// Separación entre slots de una región `wrap` (nombre de `DsSpace`).
  final String spacing;
}

/// Slot del catálogo de una pantalla (§ 2.4): lo que es y qué se le
/// permite. El widget lo arma la pantalla (builder por id); esto es solo
/// la parte de datos, testeable sin UI.
class LayoutSlotSpec {
  const LayoutSlotSpec(
    this.id, {
    required this.label,
    this.movable = true,
    this.hideable = false,
    this.allowedRegions,
    this.group = false,
    this.interactive = false,
    this.gap = 'sm',
    this.groupAxis = LayoutAxis.wrap,
    this.lead,
    this.groupGap = 'sm',
    this.groupRunSpacing = 'xs',
  });

  /// `pantalla.grupo[.elemento]`, estable.
  final String id;
  final String label;

  /// `false`: atado a lógica o geometría del juego (grillas, tablero).
  final bool movable;

  /// Se puede ocultar. Nunca una acción única (§ 5, P5).
  final bool hideable;

  /// Regiones (o grupos) donde puede ir; `null` = cualquiera de la
  /// pantalla.
  final Set<String>? allowedRegions;

  /// Contiene otros slots (una fila de botones).
  final bool group;

  /// Tiene objetivos de clic (se mide el mínimo de 32×32).
  final bool interactive;

  /// Separación antes del slot cuando no es el primero de su región
  /// (nombre de `DsSpace`: xs/sm/md/lg/xl, `none` o píxeles fijos como `6`). Es del template, no del YAML.
  final String gap;

  /// Eje por defecto de un grupo.
  final LayoutAxis groupAxis;

  /// En una región `wrap`: espacio extra antes del slot (separador
  /// visual entre bloques de una barra). `null` = solo el `spacing`.
  final String? lead;

  /// Separación entre los hijos de un grupo en fila o wrap.
  final String groupGap;

  /// Separación entre líneas de un grupo `wrap`.
  final String groupRunSpacing;
}

/// Lo que una pantalla migrada declara en código: regiones, catálogo de
/// slots y el layout por defecto (el de hoy, reexpresado como datos).
class LayoutScreenSpec {
  LayoutScreenSpec({
    required this.screen,
    required this.title,
    required this.regions,
    required List<LayoutSlotSpec> slots,
    required this.defaults,
  }) : slots = {for (final s in slots) s.id: s};

  final String screen;
  final String title;
  final List<LayoutRegionSpec> regions;
  final Map<String, LayoutSlotSpec> slots;

  /// Layout por defecto en código (§ 2.6): si falta el YAML, la pantalla
  /// se ve igual que hoy.
  final LayoutDoc defaults;

  LayoutRegionSpec? region(String id) {
    for (final r in regions) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Contenedores válidos: regiones + grupos.
  Set<String> get containers => {
        for (final r in regions) r.id,
        for (final s in slots.values)
          if (s.group) s.id,
      };

  /// ¿Puede ir [slot] en [container]? (catálogo + no meterse en sí mismo).
  bool allows(String slot, String container) {
    final s = slots[slot];
    if (s == null || !containers.contains(container)) return false;
    if (container == slot) return false;
    if (!s.movable) {
      return defaults.placementOf(slot)?.region == container;
    }
    final allowed = s.allowedRegions;
    return allowed == null || allowed.contains(container);
  }
}
