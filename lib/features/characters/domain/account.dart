import '../../../game_engine/models/atlas.dart';
import '../../../game_engine/models/bestiary.dart';
import '../../../game_engine/models/build_plan.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/atlas_rules.dart';
import '../../../game_engine/rules/balance_migration.dart';
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
    this.plan,
  });

  final String id;
  final PlayerProfile profile;
  final DateTime? created;

  /// Plan de build (docs/specs/build_planner.md § 1; JSON `plan`,
  /// opcional). Local: no viaja por la red.
  final BuildPlan? plan;

  /// `null` = nunca jugó.
  final DateTime? lastPlayed;

  /// Nombre como se muestra (vacío → `Héroe`).
  String get displayName =>
      profile.name.trim().isEmpty ? Account.defaultName : profile.name;

  CharacterSlot copyWith(
          {PlayerProfile? profile,
          DateTime? lastPlayed,
          BuildPlan? Function()? plan}) =>
      CharacterSlot(
        id: id,
        profile: profile ?? this.profile,
        created: created,
        lastPlayed: lastPlayed ?? this.lastPlayed,
        plan: plan != null ? plan() : this.plan,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        if (created != null) 'new': created!.toIso8601String(),
        if (lastPlayed != null) 'last': lastPlayed!.toIso8601String(),
        'p': profile.toJson(),
        if (plan case final pl? when !pl.isEmpty) 'plan': pl.toJson(),
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
      plan: BuildPlan.fromJson(raw['plan']),
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
    BestiaryProgress? bestiary,
    List<String> party = const [],
    Set<String> partyAuto = const {},
    this.tutorialVersion = 0,
  })  : characters = List.unmodifiable(characters),
        selectedId = _pick(characters, selectedId),
        party = List.unmodifiable(party),
        partyAuto = Set.unmodifiable(partyAuto),
        stash = stash ?? Stash.empty(),
        atlas = atlas ?? AtlasProgress.empty,
        bestiary = bestiary ?? BestiaryProgress.empty;

  static const maxCharacters = 8;

  /// Compañeros de la party jugando solo (docs/specs/solo_party.md § 2).
  static const maxCompanions = 3;
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

  /// Bestiario, compartido por todos los personajes (JSON `best`,
  /// opcional; docs/specs/bestiary.md § 2).
  final BestiaryProgress bestiary;

  /// Party jugando solo (JSON `party.c`, opcional; solo_party.md § 2.1):
  /// ids de ranura tal como se guardaron. Usar [companions].
  final List<String> party;

  /// Compañeros con AUTO prendido (JSON `party.auto`).
  final Set<String> partyAuto;

  /// Última versión del TUTORIAL que completó la cuenta (JSON `tutV`,
  /// junto a `bv`; docs/specs/combat_tutorial.md § 2). 0 = nunca. Por
  /// cuenta, no por personaje.
  final int tutorialVersion;

  /// La party saneada: ranuras que existen, sin repetir, nunca el
  /// elegido, hasta [maxCompanions].
  List<String> get companions => sanitizeParty(party);

  /// [ids] saneados como [companions].
  List<String> sanitizeParty(Iterable<String> ids) {
    final out = <String>[];
    for (final id in ids) {
      if (id == selectedId || out.contains(id) || byId(id) == null) continue;
      out.add(id);
      if (out.length >= maxCompanions) break;
    }
    return out;
  }

  /// Cambia la party (se guarda saneada).
  Account withParty(Iterable<String> ids) =>
      _copy(party: sanitizeParty(ids));

  /// Prende o apaga el AUTO de un compañero.
  Account withAuto(String id, bool on) => _copy(
      partyAuto: on ? {...partyAuto, id} : ({...partyAuto}..remove(id)));

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
    BestiaryProgress? bestiary,
    List<String>? party,
    Set<String>? partyAuto,
    int? tutorialVersion,
  }) =>
      Account(
        characters: characters ?? this.characters,
        selectedId: selectedId ?? this.selectedId,
        seq: seq ?? this.seq,
        stash: stash ?? this.stash,
        atlas: atlas ?? this.atlas,
        bestiary: bestiary ?? this.bestiary,
        party: party ?? this.party,
        partyAuto: partyAuto ?? this.partyAuto,
        tutorialVersion: tutorialVersion ?? this.tutorialVersion,
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

  /// Elige a [id]; si estaba en la party, sale de ella (un personaje no
  /// es líder y compañero a la vez).
  Account select(String id) => byId(id) == null
      ? this
      : _copy(
          selectedId: id,
          party: party.contains(id)
              ? [
                  for (final c in party)
                    if (c != id) c
                ]
              : null);

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
      bestiary: bestiary,
      party: [
        for (final c in party)
          if (c != id) c
      ],
      partyAuto: {...partyAuto}..remove(id),
      tutorialVersion: tutorialVersion,
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

  /// Cambia (o borra, con `null`) el plan de build de un personaje.
  Account withPlan(String id, BuildPlan? plan) => _copy(characters: [
        for (final c in characters)
          c.id == id ? c.copyWith(plan: () => plan) : c,
      ]);

  Account withStash(Stash stash) => _copy(stash: stash);

  Account withAtlas(AtlasProgress atlas) => _copy(atlas: atlas);

  /// Marca el TUTORIAL completado en la versión [version] (nunca baja).
  Account withTutorial(int version) => _copy(
      tutorialVersion:
          version > tutorialVersion ? version : tutorialVersion);

  Account withBestiary(BestiaryProgress bestiary) =>
      _copy(bestiary: bestiary);

  Map<String, Object?> toJson() => {
        'v': formatVersion,
        // Balance con el que se guardó (combo_balance.md § 6b): las
        // cuentas sin `bv` se migran una vez al cargar.
        'bv': kBalanceVersion,
        // TUTORIAL (combat_tutorial.md § 2): opcional, 0 = nunca.
        if (tutorialVersion > 0) 'tutV': tutorialVersion,
        'sel': selectedId,
        'seq': seq,
        'chars': [for (final c in characters) c.toJson()],
        'stash': stash.toJson(),
        if (atlas.nodes.isNotEmpty || atlas.done.isNotEmpty)
          'atlas': atlas.toJson(),
        if (!bestiary.isEmpty) 'best': bestiary.toJson(),
        if (party.isNotEmpty || partyAuto.isNotEmpty)
          'party': {'c': party, 'auto': partyAuto.toList()},
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
    final party = json['party'];
    List<String> strings(Object? v) =>
        v is List ? [for (final x in v) if (x is String) x] : const [];
    return Account(
      party: party is Map ? strings(party['c']) : const [],
      partyAuto: party is Map ? strings(party['auto']).toSet() : const {},
      characters: chars,
      selectedId: json['sel'] is String ? json['sel'] as String : null,
      seq: seq is num ? seq.toInt() : 0,
      stash: Stash.fromJson(json['stash']),
      atlas: const AtlasRules()
          .sanitize(AtlasProgress.fromJson(json['atlas'])),
      // Cuentas de antes de la v0.6: sin `best`, bestiario vacío.
      bestiary: BestiaryProgress.fromJson(json['best']),
      tutorialVersion: json['tutV'] is num ? (json['tutV'] as num).toInt() : 0,
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

/// Migra [a] al balance v0.9 (combo_balance.md § 6b): las armas de cada
/// personaje y del alijo. Los créditos de las armas de un personaje van a
/// ese personaje; los del alijo, al elegido. Devuelve la cuenta y el aviso
/// único (`null` si no hubo nada que devolver). Idempotente.
(Account, String?) migrateAccountBalance(Account a,
    {BalanceMigration rules = const BalanceMigration()}) {
  var total = const BalanceRefund();
  var next = a;
  for (final c in a.characters) {
    final (p, r) = rules.migrateProfile(c.profile);
    if (r.isEmpty) continue;
    total += r;
    next = next.replace(c.id, p, lastPlayed: c.lastPlayed);
  }
  var stash = a.stash;
  var stashRefund = const BalanceRefund();
  for (var i = 0; i < Stash.size; i++) {
    final it = stash.cells[i]?.item;
    if (it == null) continue;
    final (m, r) = rules.migrateItem(it);
    if (r.isEmpty) continue;
    stashRefund += r;
    stash = stash.put(i, StashEntry.item(m));
  }
  if (!stashRefund.isEmpty) {
    total += stashRefund;
    next = next.withStash(stash);
    final sel = next.selectedId == null ? null : next.byId(next.selectedId!);
    if (sel != null && stashRefund.credits > 0) {
      next = next.replace(sel.id,
          sel.profile.copyWith(credits: sel.profile.credits + stashRefund.credits),
          lastPlayed: sel.lastPlayed);
    }
  }
  if (total.isEmpty) return (next, null);
  return (
    next,
    'Rebalance v0.9: te devolvimos lo que cambió. ${total.lines.join('; ')}.',
  );
}
