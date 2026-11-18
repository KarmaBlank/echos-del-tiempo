import '../../../game_engine/models/atlas.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/atlas_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';
import 'stash.dart';

/// Un personaje de la cuenta: su perfil (formato de siempre) con un `id`
/// estable y las fechas de creación y de la última partida.
class CharacterSlot {
  const CharacterSlot({
    required this.id,
    required this.profile,
    this.created,
    this.lastPlayed,
  });

  final String id;
  final PlayerProfile profile;
  final DateTime? created;

  /// `null` = nunca jugó.
  final DateTime? lastPlayed;

  /// Nombre como se muestra (vacío → `Héroe`).
  String get displayName =>
      profile.name.trim().isEmpty ? Account.defaultName : profile.name;

  CharacterSlot copyWith({PlayerProfile? profile, DateTime? lastPlayed}) =>
      CharacterSlot(
        id: id,
        profile: profile ?? this.profile,
        created: created,
        lastPlayed: lastPlayed ?? this.lastPlayed,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        if (created != null) 'new': created!.toIso8601String(),
        if (lastPlayed != null) 'last': lastPlayed!.toIso8601String(),
        'p': profile.toJson(),
      };

  static CharacterSlot? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'], p = raw['p'];
    if (id is! String || id.isEmpty || p is! Map) return null;
    return CharacterSlot(
      id: id,
      profile: PlayerProfile.fromJson(Map<String, Object?>.from(p)),
      created: _date(raw['new']),
      lastPlayed: _date(raw['last']),
    );
  }

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;
}

/// La cuenta local: hasta [maxCharacters] personajes, el elegido y el
/// alijo compartido. Inmutable. Ver docs/specs/characters.md § 1.
class Account {
  Account({
    List<CharacterSlot> characters = const [],
    String? selectedId,
    this.seq = 0,
    Stash? stash,
    AtlasProgress? atlas,
  })  : characters = List.unmodifiable(characters),
        selectedId = _pick(characters, selectedId),
        stash = stash ?? Stash.empty(),
        atlas = atlas ?? AtlasProgress.empty;

  static const maxCharacters = 8;
  static const formatVersion = 1;
  static const defaultName = 'Héroe';

  final List<CharacterSlot> characters;

  /// `id` del elegido; `null` solo si no hay personajes.
  final String? selectedId;

  /// Contador de `id` (`c<n>`): nunca se reusa uno borrado.
  final int seq;
  final Stash stash;

  /// Atlas del Tiempo, compartido por todos los personajes (JSON `atlas`,
  /// opcional; docs/specs/ecos_atlas.md § 5).
  final AtlasProgress atlas;

  bool get isFull => characters.length >= maxCharacters;

  CharacterSlot? get selected => byId(selectedId);

  CharacterSlot? byId(String? id) {
    for (final c in characters) {
      if (c.id == id) return c;
    }
    return null;
  }

  static String? _pick(List<CharacterSlot> list, String? id) {
    if (list.isEmpty) return null;
    return list.any((c) => c.id == id) ? id : list.first.id;
  }

  Account _copy({
    List<CharacterSlot>? characters,
    String? selectedId,
    int? seq,
    Stash? stash,
    AtlasProgress? atlas,
  }) =>
      Account(
        characters: characters ?? this.characters,
        selectedId: selectedId ?? this.selectedId,
        seq: seq ?? this.seq,
        stash: stash ?? this.stash,
        atlas: atlas ?? this.atlas,
      );

  /// Agrega un personaje con un `id` nuevo y lo elige. `null` si está
  /// llena.
  Account? add(PlayerProfile profile, {DateTime? now}) {
    if (isFull) return null;
    final ids = {for (final c in characters) c.id};
    var n = seq + 1;
    while (ids.contains('c$n')) {
      n++;
    }
    final slot = CharacterSlot(id: 'c$n', profile: profile, created: now);
    return _copy(
        characters: [...characters, slot], selectedId: slot.id, seq: n);
  }

  Account select(String id) => byId(id) == null ? this : _copy(selectedId: id);

  /// Borra un personaje; si era el elegido, pasa al primero que quede.
  Account remove(String id) {
    final rest = [
      for (final c in characters)
        if (c.id != id) c
    ];
    return Account(
      characters: rest,
      selectedId: selectedId == id ? null : selectedId,
      seq: seq,
      stash: stash,
      atlas: atlas,
    );
  }

  /// Reemplaza el perfil de un personaje (y la fecha si se da).
  Account replace(String id, PlayerProfile profile, {DateTime? lastPlayed}) =>
      _copy(characters: [
        for (final c in characters)
          c.id == id ? c.copyWith(profile: profile, lastPlayed: lastPlayed) : c,
      ]);

  /// Anota la última partida de un personaje.
  Account touch(String id, DateTime when) => _copy(characters: [
        for (final c in characters)
          c.id == id ? c.copyWith(lastPlayed: when) : c,
      ]);

  Account withStash(Stash stash) => _copy(stash: stash);

  Account withAtlas(AtlasProgress atlas) => _copy(atlas: atlas);

  Map<String, Object?> toJson() => {
        'v': formatVersion,
        'sel': selectedId,
        'seq': seq,
        'chars': [for (final c in characters) c.toJson()],
        'stash': stash.toJson(),
        if (atlas.nodes.isNotEmpty || atlas.done.isNotEmpty)
          'atlas': atlas.toJson(),
      };

  /// Lectura tolerante (lo que falta toma su valor por defecto; entradas
  /// de `chars` inválidas o con `id` repetido se descartan). Quien la
  /// lee debe validar que [json] sea un objeto.
  factory Account.fromJson(Map<String, Object?> json) {
    final chars = <CharacterSlot>[];
    final ids = <String>{};
    final raw = json['chars'];
    if (raw is List) {
      // Sin recortar a [maxCharacters]: un archivo editado a mano con más
      // no pierde personajes (solo no deja crear otro).
      for (final r in raw) {
        final c = CharacterSlot.fromJson(r);
        if (c != null && ids.add(c.id)) chars.add(c);
      }
    }
    final seq = json['seq'];
    return Account(
      characters: chars,
      selectedId: json['sel'] is String ? json['sel'] as String : null,
      seq: seq is num ? seq.toInt() : 0,
      stash: Stash.fromJson(json['stash']),
      atlas: const AtlasRules()
          .sanitize(AtlasProgress.fromJson(json['atlas'])),
    );
  }
}

/// Lo que necesita reglas del juego: armar un personaje nuevo y recortar
/// nombres. Ver docs/specs/characters.md § 2.
class CharacterRules {
  const CharacterRules(this.progression);

  final ProgressionRules progression;

  /// Nombre recortado (10) o `Héroe` si queda vacío.
  static String cleanName(String raw) {
    var name = raw.trim();
    if (name.isEmpty) return Account.defaultName;
    if (name.length > ProgressionRules.maxNameLength) {
      name = name.substring(0, ProgressionRules.maxNameLength).trim();
    }
    return name;
  }

  /// Perfil nuevo de nivel 1 de la clase [classId], ya normalizado
  /// (atributos base, arma inicial equipada, pociones iniciales).
  PlayerProfile starter(String name, String classId) => progression
      .normalize(PlayerProfile(name: cleanName(name), classId: classId));

  /// Crea el personaje y lo elige; `null` si la cuenta está llena o la
  /// clase no existe.
  Account? create(Account a, String name, String classId, {DateTime? now}) {
    if (!progression.catalog.classes.containsKey(classId)) return null;
    return a.add(starter(name, classId), now: now);
  }

  Account rename(Account a, String id, String name) {
    final c = a.byId(id);
    if (c == null) return a;
    return a.replace(id, c.profile.copyWith(name: cleanName(name)));
  }

  /// El texto escrito confirma el borrado de [c] (sin distinguir
  /// mayúsculas ni espacios de los extremos).
  static bool confirmsDelete(CharacterSlot c, String typed) =>
      typed.trim().toLowerCase() == c.displayName.trim().toLowerCase();

  /// Borra [id] solo si [typed] lo confirma; si no, `null`.
  static Account? delete(Account a, String id, String typed) {
    final c = a.byId(id);
    if (c == null || !confirmsDelete(c, typed)) return null;
    return a.remove(id);
  }
}
