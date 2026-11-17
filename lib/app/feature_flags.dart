/// Flags que cada `main_*.dart` (composition root) configura al arrancar.
/// `features/*` lee esto para decidir qué mostrar/habilitar — nunca
/// hardcodea "si es la versión dev, hacé X".
///
/// Esto es lo que te permite builds tipo "solo salen ciertos
/// personajes" o "solo yo pruebo features nuevas" sin ramas de código
/// por todos lados: es una sola composición distinta por flavor.
class FeatureFlags {
  final bool unlockAllCharacters;
  final bool showDebugOverlay;
  final bool enableExperimentalFeatures;
  final Set<String> restrictedCharacterIds; // vacío = todos permitidos

  const FeatureFlags({
    this.unlockAllCharacters = false,
    this.showDebugOverlay = false,
    this.enableExperimentalFeatures = false,
    this.restrictedCharacterIds = const {},
  });

  static FeatureFlags instance = const FeatureFlags();

  bool isCharacterAllowed(String classId) =>
      unlockAllCharacters ||
      restrictedCharacterIds.isEmpty ||
      restrictedCharacterIds.contains(classId);
}
