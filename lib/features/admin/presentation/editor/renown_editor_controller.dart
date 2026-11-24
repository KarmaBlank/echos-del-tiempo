import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/data/enemies_catalog.dart';
import '../../../../game_engine/data/renown_catalog.dart';
import '../admin_controller.dart';
import 'npc_editor_controller.dart' show NpcEditorController, npcLocaleTags;

/// The sub-tabs of Editor → RENOMBRE (renown_town_growth.md § 8).
enum RenownTab { sources, tiers, lines, events }

/// Editor → RENOMBRE (docs/specs/renown_town_growth.md § 8): a JSON draft
/// (the same that is saved) over [kRenown].
class RenownEditorController extends ChangeNotifier {
  RenownEditorController({required this.balance, List<String>? locales})
      : locales = locales ?? npcLocaleTags() {
    reload();
  }

  final AdminController balance;

  /// Every language a text must have (same list as the NPC editor).
  final List<String> locales;

  late Map<String, dynamic> _doc;
  late String _savedJson;

  RenownTab tab = RenownTab.sources;

  /// NIVELES: `tiers` or `townTiers`.
  String ladder = 'tiers';

  /// Selected index in the ladder, line id or event id.
  int? tierIndex;
  String? lineId, eventId;

  /// FRASES filter (`null` = all; an actor or a resident id).
  String? whoFilter;
  String? message;

  Map<String, dynamic> get doc => _doc;

  List<Map<String, dynamic>> _list(String k) => [
        for (final e in (_doc[k] as List)) (e as Map).cast<String, dynamic>()
      ];

  List<Map<String, dynamic>> get tiers => _list(ladder);
  List<Map<String, dynamic>> get lines => _list('lines');
  List<Map<String, dynamic>> get events => _list('events');

  List<Map<String, dynamic>> get visibleLines => [
        for (final l in lines)
          if (whoFilter == null || l['who'] == whoFilter) l
      ];

  Map<String, dynamic>? get selectedTier {
    final t = tiers, i = tierIndex;
    return i == null || i < 0 || i >= t.length ? null : t[i];
  }

  Map<String, dynamic>? get selectedLine =>
      lines.where((l) => l['id'] == lineId).firstOrNull;
  Map<String, dynamic>? get selectedEvent =>
      events.where((e) => e['id'] == eventId).firstOrNull;

  String get _json => const JsonEncoder.withIndent('  ').convert(_doc);
  bool get dirty => _json != _savedJson;

  void edit(void Function() f) {
    f();
    message = null;
    notifyListeners();
  }

  void setTab(RenownTab t) => edit(() => tab = t);
  void setLadder(String k) => edit(() {
        ladder = k;
        tierIndex = null;
      });
  void selectTier(int? i) => edit(() => tierIndex = i);
  void selectLine(String? id) => edit(() => lineId = id);
  void selectEvent(String? id) => edit(() => eventId = id);
  void setWho(String? w) => edit(() => whoFilter = w);

  /// Every valid `who` of a recognition line.
  static List<String> get whoOptions =>
      [...RecognitionWho.actors, for (final n in kBiomeNpcs) n.id];

  (RenownConfig?, String?) get draft {
    try {
      return (RenownConfig.fromJson(_doc), null);
    } on Object catch (e) {
      return (null, '$e');
    }
  }

  /// Everything that blocks saving.
  List<String> get problems {
    final (d, err) = draft;
    if (d == null) return [err ?? 'inválido'];
    return d.validate(locales,
        residents: {for (final n in kBiomeNpcs) n.id},
        enemies: kEnemies.keys.toSet());
  }

  Map<String, dynamic> _full(Object? m) => <String, dynamic>{
        for (final t in locales) t: '${(m as Map?)?[t] ?? ''}',
      };

  void reload() {
    _doc = jsonDecode(jsonEncode(kRenown.toJson())) as Map<String, dynamic>;
    // Every text carries all the languages (the draft mutates in place).
    for (final k in const ['tiers', 'townTiers']) {
      for (final t in _list(k)) {
        t['name'] = _full(t['name']);
      }
    }
    for (final l in _list('lines')) {
      l['text'] = _full(l['text']);
    }
    for (final e in _list('events')) {
      for (final k in const ['title', 'propose', 'accept', 'signup']) {
        e[k] = _full(e[k]);
      }
    }
    _savedJson = _json;
    message = null;
    notifyListeners();
  }

  String _freeId(String base, Iterable<Object?> taken) {
    final ids = taken.toSet();
    var n = 1;
    while (ids.contains('${base}_$n')) {
      n++;
    }
    return '${base}_$n';
  }

  void addTier() => edit(() {
        final t = tiers;
        final min = t.isEmpty ? 0 : (t.last['min'] as num).round() + 50;
        (_doc[ladder] as List).add(<String, dynamic>{
          'min': min,
          'name': NpcEditorController.newText('Nivel nuevo', locales),
        });
        tierIndex = t.length;
      });

  void removeTier(int i) => edit(() {
        (_doc[ladder] as List).removeAt(i);
        tierIndex = null;
      });

  void addLine() => edit(() {
        final who = whoFilter ?? RecognitionWho.visitor;
        final id = _freeId(who, [for (final l in lines) l['id']]);
        (_doc['lines'] as List).add(<String, dynamic>{
          'id': id,
          'who': who,
          'minRenown': 30,
          'text': NpcEditorController.newText('…', locales),
        });
        lineId = id;
      });

  void removeLine(String id) => edit(() {
        (_doc['lines'] as List).removeWhere((l) => (l as Map)['id'] == id);
        if (lineId == id) lineId = null;
      });

  void addEvent() => edit(() {
        final id = _freeId('tourney', [for (final e in events) e['id']]);
        (_doc['events'] as List).add(<String, dynamic>{
          'id': id,
          'kind': TownEventKind.tournament.name,
          'proposer': kBiomeNpcs.first.id,
          'minRep': 8,
          'delay': 2,
          'cooldown': 10,
          'rounds': [
            ['slime'],
            ['slime'],
            ['slime'],
          ],
          'prize': 100,
          for (final k in const ['title', 'propose', 'accept', 'signup'])
            k: NpcEditorController.newText('…', locales),
        });
        eventId = id;
      });

  void removeEvent(String id) => edit(() {
        (_doc['events'] as List).removeWhere((e) => (e as Map)['id'] == id);
        if (eventId == id) eventId = null;
      });

  /// GUARDAR RENOMBRE: writes the repo file and applies it.
  Future<bool> save() async {
    final (d, _) = draft;
    final p = problems;
    if (d == null || p.isNotEmpty) {
      message = 'No se guardó: ${p.first}';
      notifyListeners();
      return false;
    }
    final repo = balance.repoPath;
    if (repo == null || !balance.host.supportsFiles) {
      message = 'Sin repo: no se puede guardar';
      notifyListeners();
      return false;
    }
    final sep = balance.host.join('a', 'b').substring(1, 2);
    try {
      await balance.host.writeFile(
          balance.host.join(repo, RenownConfig.assetPath.replaceAll('/', sep)),
          '${const JsonEncoder.withIndent('  ').convert(d.toJson())}\n');
    } on Object catch (e) {
      message = 'No se guardó: $e';
      notifyListeners();
      return false;
    }
    kRenown = d;
    _savedJson = _json;
    message = 'Guardado ${RenownConfig.assetPath}';
    notifyListeners();
    return true;
  }
}
