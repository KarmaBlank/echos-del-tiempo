/// Bindings con nombre de cada pantalla (docs/specs/screen_editor.md § 4):
/// lo único que un layout de datos conoce de la lógica. Dato puro.
library;

/// Acción que un botón puede disparar (p. ej. `nuevaPartida`).
class ScreenActionSpec {
  const ScreenActionSpec(this.id, this.label);
  final String id;
  final String label;
}

/// Una fila de datos de ejemplo / real (nombre + detalle corto).
class ScreenDataEntry {
  const ScreenDataEntry(this.label, [this.detail = '']);
  final String label;
  final String detail;
}

/// Fuente de datos para un organismo con datos (grilla de inventario,
/// lista de personajes...). [sample] = datos de ejemplo para el editor.
class ScreenDataSourceSpec {
  const ScreenDataSourceSpec(this.id, this.label, this.sample);
  final String id;
  final String label;
  final List<ScreenDataEntry> sample;
}

/// Hueco que la pantalla arma ella misma (organismo ligado a lógica).
class ScreenSlotSpec {
  const ScreenSlotSpec(this.id, this.label);
  final String id;
  final String label;
}

/// Lo que una pantalla ofrece a su layout.
class ScreenBindingSpec {
  const ScreenBindingSpec({
    required this.screen,
    required this.label,
    this.actions = const [],
    this.dataSources = const [],
    this.slots = const [],
  });

  final String screen;
  final String label;
  final List<ScreenActionSpec> actions;
  final List<ScreenDataSourceSpec> dataSources;
  final List<ScreenSlotSpec> slots;

  ScreenActionSpec? action(String? id) =>
      actions.where((a) => a.id == id).firstOrNull;
  ScreenDataSourceSpec? dataSource(String? id) =>
      dataSources.where((a) => a.id == id).firstOrNull;
  ScreenSlotSpec? slot(String? id) => slots.where((a) => a.id == id).firstOrNull;
}

/// Registro de bindings por pantalla.
class ScreenBindingRegistry {
  ScreenBindingRegistry([Iterable<ScreenBindingSpec> specs = const []]) {
    specs.forEach(register);
  }

  /// El del juego, con las pantallas editables.
  static final instance = ScreenBindingRegistry([titleBindings]);

  final _specs = <String, ScreenBindingSpec>{};

  void register(ScreenBindingSpec s) => _specs[s.screen] = s;
  ScreenBindingSpec? operator [](String screen) => _specs[screen];
  List<ScreenBindingSpec> get all => _specs.values.toList();
}

/// TÍTULO (lib/features/lobby/presentation/title_screen.dart).
const titleBindings = ScreenBindingSpec(
  screen: 'title',
  label: 'TÍTULO',
  actions: [
    ScreenActionSpec('nuevaPartida', 'Jugar con el personaje elegido'),
    ScreenActionSpec('crearPersonaje', 'Crear personaje'),
    ScreenActionSpec('configuracion', 'Abrir configuración'),
    ScreenActionSpec('salirDelJuego', 'Salir del juego'),
    ScreenActionSpec('ayudaTeclas', 'Atajos de teclado'),
    ScreenActionSpec('abrirAlijo', 'Abrir el alijo'),
    ScreenActionSpec('abrirBestiario', 'Abrir el bestiario'),
    ScreenActionSpec('abrirHazanas', 'Abrir las hazañas'),
  ],
  dataSources: [
    ScreenDataSourceSpec('personajes', 'Personajes de la cuenta', [
      ScreenDataEntry('Ana', 'Maga · nv 12'),
      ScreenDataEntry('Bruno', 'Guerrero · nv 9'),
      ScreenDataEntry('Cata', 'Tiradora · nv 4'),
    ]),
    ScreenDataSourceSpec('inventarioJugador', 'Inventario del jugador', [
      ScreenDataEntry('Espada de bronce', 'Arma · común'),
      ScreenDataEntry('Poción menor', 'Consumible · x5'),
      ScreenDataEntry('Engranaje', 'Material · x12'),
      ScreenDataEntry('Báculo del eco', 'Arma · rara'),
    ]),
    ScreenDataSourceSpec('semillasAyudante', 'Semillas del ayudante', [
      ScreenDataEntry('Semilla de trigo', 'x8'),
      ScreenDataEntry('Semilla de zanahoria', 'x3'),
      ScreenDataEntry('Bulbo lunar', 'x1'),
    ]),
  ],
  slots: [
    ScreenSlotSpec('personajes', 'Mundo, personajes y sala'),
    ScreenSlotSpec('avisos', 'Avisos (versión nueva, cuenta)'),
    ScreenSlotSpec('estadoRed', 'Estado de red'),
  ],
);
