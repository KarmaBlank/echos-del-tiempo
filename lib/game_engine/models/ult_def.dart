import 'elements.dart';
import 'skill.dart';

/// De dónde sale una ULT v2 (docs/specs/ultimates_v2.md § 2.3).
enum UltSource {
  /// Mod "ULT: <nombre>" de un arma Rara / Épica (de objeto).
  weaponMod('weapon_mod', 'Arma Rara / Épica'),

  /// Legendario fijo (de objeto).
  unique('unique', 'Legendario'),

  /// Hito del árbol de la clase (aprendida).
  tree('tree', 'Hito del árbol'),

  /// Hazaña nueva (aprendida).
  feat('feat', 'Hazaña'),

  /// Nodo notable del Atlas, Maestría o Eco con modificador raro
  /// (aprendida).
  eco('eco', 'Ecos y Atlas'),

  /// Fragmento de ULT de un jefe (aprendida).
  boss('boss', 'Fragmento de jefe');

  const UltSource(this.key, this.label);

  /// Clave del YAML (`source.kind`).
  final String key;
  final String label;

  /// Se aprende y queda en el repertorio (las de objeto solo sirven con
  /// el arma equipada).
  bool get learned => this != weaponMod && this != unique;

  static UltSource? byKey(String? k) {
    for (final s in values) {
      if (s.key == k) return s;
    }
    return null;
  }
}

/// Una ULT v2 del catálogo de datos (`assets/data/ults/<id>.ult.yaml`):
/// la habilidad (campos de [SkillDef]) más su fuente,
/// compatibilidad y animación.
class UltDef {
  const UltDef({
    required this.skill,
    required this.source,
    required this.ref,
    required this.element,
    this.weapons = const [],
    this.classes = const [],
    this.how = '',
  });

  final SkillDef skill;
  final UltSource source;

  /// Qué la da, según [source]: id de legendario, `clase:puntos` del
  /// árbol, id de hazaña, nodo del Atlas / `mastery:N` / `eco:raro`, id
  /// del jefe base. Las de mod de arma: vacío.
  final String ref;

  /// Tipos de arma compatibles (vacío = cualquiera).
  final List<String> weapons;

  /// Clases compatibles (vacío = cualquiera).
  final List<String> classes;

  final GameElement element;

  /// Cómo se consigue (texto para el repertorio).
  final String how;

  String get id => skill.id;
  String get name => skill.name;
  /// Toda ULT se lanza con la barra llena ([kUltCost]).
  int get cost => kUltCost.toInt();

  /// Animación FXA (`assets/fx/ult/<id>.fx.yaml`).
  String get fx => skill.id;

  /// La puede usar alguien de [classId] con un arma de tipo [weaponType].
  bool fits(String? classId, String? weaponType) =>
      (weapons.isEmpty || weapons.contains(weaponType)) &&
      (classes.isEmpty || classes.contains(classId));
}
