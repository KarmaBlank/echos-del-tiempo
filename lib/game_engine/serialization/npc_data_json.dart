import 'dart:convert';

import '../data/npc_talk_catalog.dart';
import '../rules/biome_fisher_rules.dart';
import '../rules/resident_rules.dart';

/// Textos y cadenas de encargos de los habitantes como datos
/// (docs/specs/npc_editor.md § 1): `assets/data/npcs/npcs.json`. Puro;
/// el lector de assets vive en `lib/core/data/npc_data_loader.dart`.
class NpcData {
  const NpcData(
      {required this.talks, required this.quests, required this.ambient});

  static const assetPath = 'assets/data/npcs/npcs.json';
  static const version = 1;

  /// Charla por id de habitante.
  final Map<String, NpcTalkDef> talks;

  /// Cadena de encargos escrita a mano por id (solo los que se mudan).
  final Map<String, List<QuestStepDef>> quests;

  /// Frases sueltas de la orilla por id de pescador nativo
  /// (`pesc_<bioma>`).
  final Map<String, List<String>> ambient;

  /// Los valores del código (el respaldo).
  static NpcData get defaults => NpcData(
        talks: kNpcTalksDefaults,
        quests: kResidentQuestsDefaults,
        ambient: {
          for (final f in kBiomeFishersDefaults.values)
            nativeId(f.biome): f.lines,
        },
      );

  /// Lo que usa el juego ahora.
  static NpcData get current => NpcData(
        talks: Map.of(kNpcTalks),
        quests: Map.of(kResidentQuests),
        ambient: {
          for (final f in kBiomeFishers.values) nativeId(f.biome): f.lines,
        },
      );

  /// Ids que el juego conoce (los otros se ignoran al instalar).
  static Set<String> get knownIds => {
        ...kNpcTalksDefaults.keys,
        ...kResidentQuestsDefaults.keys,
        for (final b in kBiomeFishersDefaults.keys) nativeId(b),
      };

  // ------------------------------------------------------------------
  // JSON
  // ------------------------------------------------------------------

  Map<String, Object?> toJson() {
    final ids = <String>{...talks.keys, ...quests.keys, ...ambient.keys};
    return {
      'version': version,
      'npcs': {
        for (final id in ids)
          id: {
            if (talks[id] case final t?) ...talkToJson(t),
            if (quests[id] case final q?)
              'quests': [for (final s in q) stepToJson(s)],
            if (ambient[id] case final a?) 'ambient': a,
          },
      },
    };
  }

  String encode() =>
      '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';

  /// Lanza [FormatException] si el archivo no tiene la forma esperada.
  static NpcData fromJson(Object? j) {
    if (j is! Map || j['npcs'] is! Map) {
      throw const FormatException('falta "npcs"');
    }
    final talks = <String, NpcTalkDef>{};
    final quests = <String, List<QuestStepDef>>{};
    final ambient = <String, List<String>>{};
    for (final MapEntry(key: id, value: v) in (j['npcs'] as Map).entries) {
      if (id is! String || v is! Map) {
        throw FormatException('habitante inválido: $id');
      }
      if (v.containsKey('greet') || v.containsKey('topics')) {
        talks[id] = talkFromJson(v);
      }
      if (v['quests'] is List) {
        quests[id] = [for (final s in v['quests'] as List) stepFromJson(s)];
      }
      if (v['ambient'] is List) ambient[id] = _strings(v['ambient']);
    }
    return NpcData(talks: talks, quests: quests, ambient: ambient);
  }

  static NpcData decode(String raw) => fromJson(jsonDecode(raw));

  static Map<String, Object?> talkToJson(NpcTalkDef t) => {
        'greet': t.greet,
        'topics': [for (final x in t.topics) topicToJson(x)],
        if (t.rooted) 'rooted': true,
        if (t.decline.isNotEmpty) 'decline': t.decline,
        if (t.gift.isNotEmpty) 'gift': t.gift,
      };

  static NpcTalkDef talkFromJson(Map v) => NpcTalkDef(
        greet: _strings(v['greet']),
        topics: [
          for (final x in (v['topics'] as List? ?? const [])) topicFromJson(x)
        ],
        rooted: v['rooted'] == true,
        decline: _strings(v['decline']),
        gift: v['gift'] as String? ?? '',
      );

  static Map<String, Object?> topicToJson(TalkTopic t) => {
        'id': t.id,
        'label': t.label,
        'lines': t.lines,
        if (t.talks > 0) 'talks': t.talks,
        if (t.orders > 0) 'orders': t.orders,
        if (t.rep > 0) 'rep': t.rep,
        if (t.where != TalkWhere.any) 'where': t.where.name,
        if (t.sub.isNotEmpty) 'sub': [for (final s in t.sub) topicToJson(s)],
      };

  static TalkTopic topicFromJson(Object? j) {
    if (j is! Map || j['id'] is! String || j['label'] is! String) {
      throw FormatException('tema inválido: $j');
    }
    return TalkTopic(
        j['id'] as String, j['label'] as String, _strings(j['lines']),
        talks: _int(j['talks']),
        orders: _int(j['orders']),
        rep: _int(j['rep']),
        where:
            TalkWhere.values.where((w) => w.name == j['where']).firstOrNull ??
                TalkWhere.any,
        sub: [
          for (final s in (j['sub'] as List? ?? const [])) topicFromJson(s)
        ]);
  }

  static Map<String, Object?> stepToJson(QuestStepDef s) => {
        'kind': s.kind.name,
        'target': s.target,
        'n': s.n,
        'text': s.text,
        if (s.gold != 0) 'gold': s.gold,
        if (s.rep != 1) 'rep': s.rep,
        if (s.reward != null) 'reward': s.reward,
      };

  static QuestStepDef stepFromJson(Object? j) {
    if (j is! Map || j['target'] is! String) {
      throw FormatException('paso inválido: $j');
    }
    final kind = QuestKind.values.where((k) => k.name == j['kind']).firstOrNull;
    if (kind == null) throw FormatException('tipo de paso: ${j['kind']}');
    return QuestStepDef(kind, j['target'] as String, _int(j['n'], 1),
        j['text'] as String? ?? '',
        gold: _int(j['gold']),
        rep: _int(j['rep'], 1),
        reward: j['reward'] as String?);
  }

  static List<String> _strings(Object? j) =>
      j is List ? [for (final s in j) '$s'] : const [];

  static int _int(Object? j, [int fallback = 0]) =>
      (j as num?)?.toInt() ?? fallback;

  // ------------------------------------------------------------------
  // Instalar
  // ------------------------------------------------------------------

  /// Pone estos datos encima de los catálogos del motor (solo ids
  /// conocidos). Devuelve los ids ignorados.
  List<String> install() {
    restore();
    final known = knownIds;
    final skipped = <String>[];
    for (final MapEntry(key: id, value: t) in talks.entries) {
      if (!known.contains(id)) {
        skipped.add(id);
        continue;
      }
      kNpcTalks[id] = t;
    }
    for (final MapEntry(key: id, value: q) in quests.entries) {
      if (!kResidentQuestsDefaults.containsKey(id)) {
        skipped.add(id);
        continue;
      }
      kResidentQuests[id] = q;
    }
    for (final f in kBiomeFishersDefaults.values) {
      final lines = ambient[nativeId(f.biome)];
      if (lines != null && lines.isNotEmpty) {
        kBiomeFishers[f.biome] = BiomeFisherDef(f.biome, f.name, lines);
      }
    }
    return skipped;
  }

  /// Vuelve a los valores del código.
  static void restore() {
    kNpcTalks
      ..clear()
      ..addAll(kNpcTalksDefaults);
    kResidentQuests
      ..clear()
      ..addAll(kResidentQuestsDefaults);
    kBiomeFishers
      ..clear()
      ..addAll(kBiomeFishersDefaults);
  }
}
