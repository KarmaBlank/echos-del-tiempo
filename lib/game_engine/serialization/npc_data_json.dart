import 'dart:convert';

import '../data/npc_talk_catalog.dart';
import '../models/custom_npc.dart';
import '../rules/biome_fisher_rules.dart';
import '../rules/resident_rules.dart';

/// Textos y cadenas de encargos de los habitantes como datos
/// (docs/specs/npc_editor.md § 1): `assets/data/npcs/npcs.json`. Puro;
/// el lector de assets vive en `lib/core/data/npc_data_loader.dart`.
class NpcData {
  const NpcData(
      {required this.talks, required this.quests, this.customs = const {}});

  static const assetPath = 'assets/data/npcs/npcs.json';

  /// 2: every text is a per-language map (npc_editor.md § 1.1). Version 1
  /// (plain strings = es-AR) is still read.
  static const version = 2;

  /// Charla por id de habitante (with its loose, night, invite and
  /// house lines).
  final Map<String, NpcTalkDef> talks;

  /// Cadena de encargos escrita a mano por id (solo los que se mudan).
  final Map<String, List<QuestStepDef>> quests;

  /// NPCs hechos solo con datos (npc_editor.md § 6): `def` de su entrada.
  final Map<String, CustomNpcDef> customs;

  /// Los valores del código (el respaldo).
  static NpcData get defaults =>
      const NpcData(talks: kNpcTalksDefaults, quests: kResidentQuestsDefaults);

  /// Lo que usa el juego ahora.
  static NpcData get current =>
      NpcData(
          talks: Map.of(kNpcTalks),
          quests: Map.of(kResidentQuests),
          customs: Map.of(kCustomNpcs));

  /// Ids que el juego conoce (los otros se ignoran al instalar).
  static Set<String> get knownIds => {
        ...kNpcTalksDefaults.keys,
        ...kResidentQuestsDefaults.keys,
        for (final b in kBiomeFishersDefaults.keys) nativeId(b),
      };

  // ------------------------------------------------------------------
  // Validation (npc_editor.md § 3.1)
  // ------------------------------------------------------------------

  /// Every dialogue text lacking one of [locales] (tags), as
  /// `"<npc> · <where>: <tags>"`. Empty = complete. Saving is blocked
  /// while this is not empty.
  List<String> missingLocales(List<String> locales) {
    final out = <String>[];
    void check(String id, String where, LocalizedText t) {
      final m = t.missing(locales);
      if (m.isNotEmpty) out.add('$id · $where: ${m.join(', ')}');
    }

    void lines(String id, String where, List<LocalizedText> l) {
      for (var i = 0; i < l.length; i++) {
        check(id, '$where ${i + 1}', l[i]);
      }
    }

    void topics(String id, List<TalkTopic> list, String path) {
      for (final x in list) {
        final p = path.isEmpty ? x.id : '$path/${x.id}';
        check(id, 'tema $p', x.label);
        lines(id, 'tema $p línea', x.lines);
        topics(id, x.sub, p);
      }
    }

    for (final d in customs.values) {
      check(d.id, 'nombre', d.name);
      if (!d.bioDraft) check(d.id, 'lore', d.bio);
    }
    for (final MapEntry(key: id, value: t) in talks.entries) {
      lines(id, 'saludo', t.greet);
      topics(id, t.topics, '');
      lines(id, 'al invitarlo', t.decline);
      lines(id, 'frase suelta', t.ambient);
      for (final MapEntry(key: k, value: v) in t.night.entries) {
        check(id, 'noche $k', v);
      }
      if (!t.rooted && npcHasResidentLines(id)) {
        check(id, 'acepta invitación', t.inviteAccept);
        check(id, 'gracias por la casa (día)', t.thanksDay);
        check(id, 'gracias por la casa (noche)', t.thanksNight);
      }
    }
    return out;
  }

  /// Residents (they move to town) have invite / house lines.
  static bool npcHasResidentLines(String id) =>
      kResidentQuestsDefaults.containsKey(id);

  // ------------------------------------------------------------------
  // JSON
  // ------------------------------------------------------------------

  Map<String, Object?> toJson() {
    final ids = <String>{...customs.keys, ...talks.keys, ...quests.keys};
    return {
      'version': version,
      'npcs': {
        for (final id in ids)
          id: {
            if (customs[id] case final d?) 'def': d.toJson(),
            if (talks[id] case final t?) ...talkToJson(t),
            if (quests[id] case final q?)
              'quests': [for (final s in q) stepToJson(s)],
          },
      },
    };
  }

  String encode() =>
      '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';

  /// Lanza [FormatException] si el archivo no tiene la forma esperada.
  /// Reads version 1 (plain strings) and 2 (per-language maps).
  static NpcData fromJson(Object? j) {
    if (j is! Map || j['npcs'] is! Map) {
      throw const FormatException('falta "npcs"');
    }
    final talks = <String, NpcTalkDef>{};
    final quests = <String, List<QuestStepDef>>{};
    final customs = <String, CustomNpcDef>{};
    for (final MapEntry(key: id, value: v) in (j['npcs'] as Map).entries) {
      if (id is! String || v is! Map) {
        throw FormatException('habitante inválido: $id');
      }
      if (v.containsKey('def')) {
        customs[id] = CustomNpcDef.fromJson(id, v['def']);
      }
      if (v.containsKey('greet') ||
          v.containsKey('topics') ||
          v.containsKey('ambient')) {
        talks[id] = talkFromJson(v);
      }
      if (v['quests'] is List) {
        quests[id] = [for (final s in v['quests'] as List) stepFromJson(s)];
      }
    }
    return NpcData(talks: talks, quests: quests, customs: customs);
  }

  static NpcData decode(String raw) => fromJson(jsonDecode(raw));

  static List<Map<String, String>> _textsToJson(List<LocalizedText> l) =>
      [for (final x in l) x.toJson()];

  static bool _blank(LocalizedText t) =>
      t.byLocale.values.every((s) => s.isEmpty);

  static Map<String, Object?> talkToJson(NpcTalkDef t) => {
        'greet': _textsToJson(t.greet),
        'topics': [for (final x in t.topics) topicToJson(x)],
        if (t.rooted) 'rooted': true,
        if (t.decline.isNotEmpty) 'decline': _textsToJson(t.decline),
        if (t.gift.isNotEmpty) 'gift': t.gift,
        if (t.ambient.isNotEmpty) 'ambient': _textsToJson(t.ambient),
        if (t.night.isNotEmpty)
          'night': {
            for (final e in t.night.entries) e.key: e.value.toJson(),
          },
        if (!_blank(t.inviteAccept)) 'invite_accept': t.inviteAccept.toJson(),
        if (!_blank(t.thanksDay) || !_blank(t.thanksNight))
          'house_thanks': {
            'day': t.thanksDay.toJson(),
            'night': t.thanksNight.toJson(),
          },
      };

  static NpcTalkDef talkFromJson(Map v) {
    final thanks = v['house_thanks'];
    return NpcTalkDef(
      greet: _texts(v['greet']),
      topics: [
        for (final x in (v['topics'] as List? ?? const [])) topicFromJson(x)
      ],
      rooted: v['rooted'] == true,
      decline: _texts(v['decline']),
      gift: v['gift'] as String? ?? '',
      ambient: _texts(v['ambient']),
      night: {
        if (v['night'] case final Map n)
          for (final e in n.entries)
            '${e.key}': LocalizedText.fromJson(e.value),
      },
      inviteAccept: LocalizedText.fromJson(v['invite_accept']),
      thanksDay: thanks is Map
          ? LocalizedText.fromJson(thanks['day'])
          : LocalizedText.empty,
      thanksNight: thanks is Map
          ? LocalizedText.fromJson(thanks['night'])
          : LocalizedText.empty,
    );
  }

  static Map<String, Object?> topicToJson(TalkTopic t) => {
        'id': t.id,
        'label': t.label.toJson(),
        'lines': _textsToJson(t.lines),
        if (t.talks > 0) 'talks': t.talks,
        if (t.orders > 0) 'orders': t.orders,
        if (t.rep > 0) 'rep': t.rep,
        if (t.renown > 0) 'renown': t.renown,
        if (t.where != TalkWhere.any) 'where': t.where.name,
        if (t.time != TalkTime.any) 'time': t.time.name,
        if (t.action != TalkAction.none) 'action': t.action.name,
        if (t.sub.isNotEmpty) 'sub': [for (final s in t.sub) topicToJson(s)],
      };

  static TalkTopic topicFromJson(Object? j) {
    if (j is! Map ||
        j['id'] is! String ||
        (j['label'] is! String && j['label'] is! Map)) {
      throw FormatException('tema inválido: $j');
    }
    return TalkTopic(j['id'] as String, LocalizedText.fromJson(j['label']),
        _texts(j['lines']),
        talks: _int(j['talks']),
        orders: _int(j['orders']),
        rep: _int(j['rep']),
        renown: _int(j['renown']),
        where:
            TalkWhere.values.where((w) => w.name == j['where']).firstOrNull ??
                TalkWhere.any,
        time: TalkTime.values.where((w) => w.name == j['time']).firstOrNull ??
            TalkTime.any,
        action: TalkAction.fromName(j['action']),
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

  static List<LocalizedText> _texts(Object? j) =>
      j is List ? [for (final s in j) LocalizedText.fromJson(s)] : const [];

  static int _int(Object? j, [int fallback = 0]) =>
      (j as num?)?.toInt() ?? fallback;

  // ------------------------------------------------------------------
  // Instalar
  // ------------------------------------------------------------------

  /// Pone estos datos encima de los catálogos del motor (solo ids
  /// conocidos). Devuelve los ids ignorados.
  List<String> install() {
    restore();
    final defaults = knownIds;
    final skipped = <String>[];
    for (final MapEntry(key: id, value: d) in customs.entries) {
      // Un NPC de datos nunca pisa a uno del código.
      if (defaults.contains(id)) {
        skipped.add(id);
        continue;
      }
      kCustomNpcs[id] = d;
    }
    final known = {...defaults, ...kCustomNpcs.keys};
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
    return skipped;
  }

  /// Vuelve a los valores del código.
  static void restore() {
    kCustomNpcs.clear();
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
