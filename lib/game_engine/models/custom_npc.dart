import '../data/npc_talk_catalog.dart' show TalkTime;
import 'localized_text.dart';

/// Where a data-made NPC shows up (docs/specs/npc_editor.md § 6).
enum CustomNpcSpawn {
  /// Always in town, at its tile.
  town,

  /// In the biome [CustomNpcDef.place], at its tile. With
  /// [CustomNpcDef.invitable], once invited it lives in town instead.
  biome,

  /// Next to the actor of world event [CustomNpcDef.place] while it is
  /// active (wherever the event shows up).
  event,

  /// In the mines of biome [CustomNpcDef.place] (empty = every mine), at
  /// its tile.
  mine,
}

/// An NPC made entirely from data in the Editor (npc_editor.md § 6): no
/// code, no hand-drawn art (its sprite is usually an NPC variant,
/// npc_variants.md). Lives in `npcs.json` under `def`; its dialogue is the
/// usual `greet` / `topics` of the same entry. Pure and immutable.
class CustomNpcDef {
  const CustomNpcDef({
    required this.id,
    required this.name,
    this.bio = LocalizedText.empty,
    this.bioDraft = true,
    required this.sprite,
    this.spawn = CustomNpcSpawn.town,
    this.place = '',
    this.x = 0,
    this.y = 0,
    this.time = TalkTime.any,
    this.invitable = false,
  });

  final String id;
  final LocalizedText name;

  /// Short lore (bio). BORRADOR while [bioDraft]: missing languages do
  /// not block saving.
  final LocalizedText bio;
  final bool bioDraft;

  /// Sprite id (`items.vida_<sprite>` or an NPC variant id).
  final String sprite;
  final CustomNpcSpawn spawn;

  /// Biome id (`biome`, `mine`) or world event id (`event`).
  final String place;

  /// Tile (town, biome, mine); offset in tiles from the event actor.
  final int x, y;

  /// When it is out (world clock, `SkyRules.isNight`).
  final TalkTime time;

  /// A biome NPC that the INVITAR topic action moves to town.
  final bool invitable;

  Map<String, Object?> toJson() => {
        'name': name.toJson(),
        'bio': bio.toJson(),
        if (!bioDraft) 'bio_final': true,
        'sprite': sprite,
        'spawn': spawn.name,
        if (place.isNotEmpty) 'place': place,
        'x': x,
        'y': y,
        if (time != TalkTime.any) 'time': time.name,
        if (invitable) 'invitable': true,
      };

  /// [FormatException] if [j] is not a def map.
  static CustomNpcDef fromJson(String id, Object? j) {
    if (j is! Map) throw FormatException('def inválido: $id');
    T pick<T extends Enum>(List<T> vs, Object? v, T fallback) =>
        vs.where((e) => e.name == v).firstOrNull ?? fallback;
    int n(Object? v) => v is num ? v.toInt() : 0;
    final sprite = j['sprite'];
    return CustomNpcDef(
      id: id,
      name: LocalizedText.fromJson(j['name']),
      bio: LocalizedText.fromJson(j['bio']),
      bioDraft: j['bio_final'] != true,
      sprite: sprite is String && sprite.isNotEmpty ? sprite : id,
      spawn: pick(CustomNpcSpawn.values, j['spawn'], CustomNpcSpawn.town),
      place: j['place'] is String ? j['place'] as String : '',
      x: n(j['x']),
      y: n(j['y']),
      time: pick(TalkTime.values, j['time'], TalkTime.any),
      invitable: j['invitable'] == true,
    );
  }
}

/// The data-made NPCs the game uses now (installed by `NpcData.install`).
final Map<String, CustomNpcDef> kCustomNpcs = {};
