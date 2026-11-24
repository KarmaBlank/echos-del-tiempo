import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/data/enemies_catalog.dart';
import '../../../../game_engine/data/world_events_catalog.dart';
import '../admin_controller.dart';
import 'npc_editor_controller.dart' show NpcEditorController, npcLocaleTags;

/// Editor → EVENTOS (docs/specs/world_events.md § 7): a JSON draft (the
/// same that is saved) over [kWorldEvents].
class EventsEditorController extends ChangeNotifier {
  EventsEditorController({required this.balance, List<String>? locales})
      : locales = locales ?? npcLocaleTags() {
    reload();
  }

  final AdminController balance;

  /// Every language a text must have (same list as the NPC editor).
  final List<String> locales;

  late Map<String, dynamic> _doc;
  late String _savedJson;

  /// Selected event id (`null` = GENERAL).
  String? selectedId;

  /// Category filter (`null` = all).
  WorldEventCategory? filter;
  String? message;

  Map<String, dynamic> get doc => _doc;

  List<Map<String, dynamic>> get events => [
        for (final e in (_doc['events'] as List)) (e as Map).cast<String, dynamic>()
      ];

  List<Map<String, dynamic>> get visible => [
        for (final e in events)
          if (filter == null || e['category'] == filter!.name) e
      ];

  Map<String, dynamic>? get selected =>
      events.where((e) => e['id'] == selectedId).firstOrNull;

  String get _json => const JsonEncoder.withIndent('  ').convert(_doc);
  bool get dirty => _json != _savedJson;

  void select(String? id) {
    selectedId = id;
    notifyListeners();
  }

  void setFilter(WorldEventCategory? c) {
    filter = c;
    notifyListeners();
  }

  void edit(void Function() f) {
    f();
    message = null;
    notifyListeners();
  }

  /// The decoded draft, or the error.
  (WorldEventsConfig?, String?) get draft {
    try {
      return (WorldEventsConfig.fromJson(_doc), null);
    } on Object catch (e) {
      return (null, '$e');
    }
  }

  /// Everything that blocks saving.
  List<String> get problems {
    final (d, err) = draft;
    if (d == null) return [err ?? 'inválido'];
    return d.validate(locales,
        biomes: {for (final b in kBiomes) b.id},
        residents: {for (final n in kBiomeNpcs) n.id},
        enemies: kEnemies.keys.toSet());
  }

  void reload() {
    _doc = jsonDecode(jsonEncode(kWorldEvents.toJson())) as Map<String, dynamic>;
    // The draft keeps every list (the doc mutates in place). Each
    // event carries all its texts.
    for (final e in events) {
      for (final k in const ['title', 'notice', 'body']) {
        e[k] = <String, dynamic>{
          for (final t in locales) t: '${(e[k] as Map?)?[t] ?? ''}',
        };
      }
    }
    _savedJson = _json;
    message = null;
    notifyListeners();
  }

  /// A new event of [c] with a free id.
  void add(WorldEventCategory c) => edit(() {
        final ids = {for (final e in events) e['id']};
        var n = 1;
        while (ids.contains('${c.name}_$n')) {
          n++;
        }
        final id = '${c.name}_$n';
        (_doc['events'] as List).add(<String, dynamic>{
          'id': id,
          'category': c.name,
          'weight': 1,
          'duration': 3,
          'title': NpcEditorController.newText('Evento nuevo', locales),
          'notice': NpcEditorController.newText('…', locales),
          'body': NpcEditorController.newText('…', locales),
          if (c == WorldEventCategory.lore) ...{
            'resident': kBiomeNpcs.first.id,
            'objective': LoreObjective.defeat.name,
            'target': 'slime',
            'n': 1,
          },
        });
        selectedId = id;
      });

  void remove(String id) => edit(() {
        (_doc['events'] as List).removeWhere((e) => (e as Map)['id'] == id);
        if (selectedId == id) selectedId = null;
      });

  /// GUARDAR EVENTOS: writes the repo file and applies it.
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
          balance.host
              .join(repo, WorldEventsConfig.assetPath.replaceAll('/', sep)),
          '${const JsonEncoder.withIndent('  ').convert(d.toJson())}\n');
    } on Object catch (e) {
      message = 'No se guardó: $e';
      notifyListeners();
      return false;
    }
    kWorldEvents = d;
    _savedJson = _json;
    message = 'Guardado ${WorldEventsConfig.assetPath}';
    notifyListeners();
    return true;
  }
}
