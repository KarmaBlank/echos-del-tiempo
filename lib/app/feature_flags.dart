import '../game_engine/rules/party_limits.dart';

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

  /// Atajos de prueba del endgame (dar Ecos desde el Portal). Solo
  /// `main_dev`: el motor rechaza `DevGrantEcoAction` sin esto
  /// (docs/specs/ecos_atlas.md § 8).
  final bool devTools;

  /// Jugar solo con compañeros (party de personajes de la cuenta;
  /// docs/specs/solo_party.md). Apagado en la build principal desde
  /// v0.9.14: sin esto el título no ofrece PARTY y la sesión arranca
  /// solo con el personaje elegido (la party guardada se ignora, no se
  /// borra).
  final bool soloParty;

  /// Máximo de jugadores por sala (contando al host y compañeros). Único
  /// lugar para cambiarlo: el motor y la red lo reciben de acá por
  /// constructor (docs/specs/netcode.md § "Máximo de jugadores").
  final int maxPlayers;

  const FeatureFlags({
    this.unlockAllCharacters = false,
    this.showDebugOverlay = false,
    this.enableExperimentalFeatures = false,
    this.restrictedCharacterIds = const {},
    this.devTools = false,
    this.soloParty = false,
    this.maxPlayers = kDefaultMaxPlayers,
  });

  static FeatureFlags instance = const FeatureFlags();

  bool isCharacterAllowed(String classId) =>
      unlockAllCharacters ||
      restrictedCharacterIds.isEmpty ||
      restrictedCharacterIds.contains(classId);
}
