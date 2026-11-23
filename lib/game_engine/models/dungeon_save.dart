/// Mazmorra de zona guardada en el mundo (docs/specs/persistent_dungeons.md).
///
/// [run] es el JSON de `MissionRun` (`SessionJson.missionToJson`) tal
/// cual, como el pozo Loot perdido: el modelo no necesita el catálogo.
class DungeonSave {
  const DungeonSave({
    required this.missionId,
    required this.run,
    this.parkedDay = 0,
  });

  final String missionId;

  /// El estado de la mazmorra (enemigos, cofres, faroles, PdI, pisos...).
  final Map<String, Object?> run;

  /// Día del mundo (`SkyState.day`) en que salió el último jugador. Los
  /// enemigos normales y élite reviven si al volver a entrar pasaron
  /// `respawnDays` días desde acá (nadie adentro todo ese tiempo).
  final int parkedDay;

  Map<String, Object?> toJson() =>
      {'id': missionId, 'run': run, if (parkedDay != 0) 'pd': parkedDay};

  static DungeonSave? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'], run = raw['run'];
    if (id is! String || run is! Map) return null;
    final pd = raw['pd'];
    return DungeonSave(
        missionId: id,
        run: run.cast<String, Object?>(),
        parkedDay: pd is num ? pd.round() : 0);
  }
}
