import 'dart:convert';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/balance/balance_codecs.dart';
import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/data/farming_catalog.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/data/npc_talk_catalog.dart';
import '../../../../game_engine/rules/biome_fisher_rules.dart';
import '../../../../game_engine/rules/npc_talk_rules.dart';
import '../../../../game_engine/rules/resident_rules.dart';
import '../../../../game_engine/serialization/npc_data_json.dart';
import '../admin_controller.dart';

/// Un habitante en la grilla del editor NPC (npc_editor.md § 2).
class NpcEntry {
  const NpcEntry(
      {required this.id,
      required this.name,
      required this.role,
      required this.biome,
      required this.rooted,
      required this.sprite,
      required this.portrait});
  final String id;
  final String name;
  final String role;
  final String biome;
  final bool rooted;
  final String sprite;
  final String portrait;

  /// Los que se mudan (con cadena y órdenes).
  bool get mover => !rooted;
}

/// Un pedido de ejemplo (npc_editor.md § 4, GENERAR EJEMPLOS).
typedef NpcSample = ({int day, String text, String reward});

/// Límite blando de caracteres por línea (npc_editor.md § 3).
const kNpcLineSoftLimit = 90;

/// Estado del área NPC del Editor: un borrador en JSON (lo mismo que se
/// guarda) sobre `NpcData.current`; las reglas de los generadores se
/// editan en el borrador del Balance ([balance]).
class NpcEditorController extends ChangeNotifier {
  NpcEditorController({required this.balance, this.spriteImage}) {
    reload();
  }

  final AdminController balance;

  /// Miniatura de un sprite del manifest (`null`: sin catálogo).
  final ui.Image? Function(String id)? spriteImage;

  late Map<String, dynamic> _doc;
  late String _savedJson;
  String? selectedId;
  String? message;

  /// Todos: los que se mudan y los nativos de cada bioma.
  List<NpcEntry> get entries => [
        for (final n in kBiomeNpcs)
          NpcEntry(
              id: n.id,
              name: n.name,
              role: n.role.label,
              biome: n.biome,
              rooted: npcRooted(n.id),
              sprite: n.sprite,
              portrait: n.portrait),
        for (final f in kBiomeFishersDefaults.values)
          NpcEntry(
              id: nativeId(f.biome),
              name: f.name,
              role: 'Pescador',
              biome: f.biome,
              rooted: true,
              sprite: f.sprite,
              portrait: f.sprite),
      ];

  NpcEntry? get selected =>
      entries.where((e) => e.id == selectedId).firstOrNull;

  void select(String id) {
    selectedId = id;
    notifyListeners();
  }

  ui.Image? imageOf(String sprite) =>
      spriteImage?.call('items.vida_$sprite') ??
      spriteImage?.call('vida_$sprite');

  // ------------------------------------------------------------------
  // Borrador
  // ------------------------------------------------------------------

  String get _json => const JsonEncoder.withIndent('  ').convert(_doc);
  bool get dirty => _json != _savedJson;

  /// El borrador de [id] (se crea vacío si falta).
  Map<String, dynamic> npc(String id) =>
      ((_doc['npcs'] as Map<String, dynamic>)[id] ??= <String, dynamic>{})
          as Map<String, dynamic>;

  /// Cambia el borrador.
  void edit(void Function() f) {
    f();
    message = null;
    notifyListeners();
  }

  /// El borrador decodificado, o el error.
  (NpcData?, String?) get draft {
    try {
      return (NpcData.fromJson(_doc), null);
    } on Object catch (e) {
      return (null, '$e');
    }
  }

  /// Descarta lo no guardado (relee lo que usa el juego).
  void reload() {
    _doc = jsonDecode(jsonEncode(NpcData.current.toJson()))
        as Map<String, dynamic>;
    _savedJson = _json;
    message = null;
    notifyListeners();
  }

  /// GUARDAR NPC: escribe el archivo del repo y lo aplica al juego.
  Future<bool> save() async {
    final (d, err) = draft;
    if (d == null) {
      message = 'No se guardó: $err';
      notifyListeners();
      return false;
    }
    final repo = balance.repoPath;
    if (repo == null || !balance.host.supportsFiles) {
      message = 'Sin repo: no se puede guardar';
      notifyListeners();
      return false;
    }
    try {
      await balance.host.writeFile(
          balance.host.join(repo, NpcData.assetPath.replaceAll('/', _sep)),
          d.encode());
    } on Object catch (e) {
      message = 'No se guardó: $e';
      notifyListeners();
      return false;
    }
    d.install();
    _savedJson = _json;
    message = 'Guardado ${NpcData.assetPath}';
    notifyListeners();
    return true;
  }

  String get _sep => balance.host.join('a', 'b').substring(1, 2);

  // ------------------------------------------------------------------
  // Listas (saludos, líneas, temas, pasos)
  // ------------------------------------------------------------------

  /// Mueve el ítem [i] de [list] [delta] lugares.
  void move(List list, int i, int delta) => edit(() {
        final j = i + delta;
        if (j < 0 || j >= list.length) return;
        final x = list.removeAt(i);
        list.insert(j, x);
      });

  void removeAt(List list, int i) => edit(() => list.removeAt(i));

  void add(List list, Object item) => edit(() => list.add(item));

  /// Lista [key] de [m] (se crea si falta).
  static List<dynamic> listOf(Map<String, dynamic> m, String key) =>
      (m[key] ??= <dynamic>[]) as List<dynamic>;

  /// Un tema nuevo con id libre entre [siblings].
  static Map<String, dynamic> newTopic(List siblings) {
    var n = siblings.length + 1;
    final ids = {for (final t in siblings) (t as Map)['id']};
    while (ids.contains('tema_$n')) {
      n++;
    }
    return {
      'id': 'tema_$n',
      'label': 'Tema nuevo',
      'lines': <dynamic>['…'],
    };
  }

  static Map<String, dynamic> newStep() => {
        'kind': QuestKind.recolectar.name,
        'target': '',
        'n': 1,
        'text': '…',
      };

  // ------------------------------------------------------------------
  // Umbrales y generadores
  // ------------------------------------------------------------------

  /// Umbrales de amistad (npc_editor.md § 2).
  List<(String, String)> thresholds(NpcEntry e) {
    final t = ResidentRules.t;
    return e.rooted
        ? [
            (
              'Invitar',
              'amistad ${NpcTalkRules.inviteRep} y '
                  '${NpcTalkRules.inviteOrders} pedidos'
            ),
            ('Amistad por charla', '+${NpcTalkRules.talkRep} (una por día)'),
            ('Amistad por pedido', '+${NpcTalkRules.orderRep}'),
          ]
        : [
            ('Invitar', 'relación ${t.i('resInviteRep')}'),
            ('Asentado', 'relación ${t.i('resSettledRep')}'),
            ('Arraigado', 'relación ${t.i('resRootedRep')}'),
          ];
  }

  /// Generadores de [e] con sus números (npc_editor.md § 4): título,
  /// tipo del Balance y claves.
  List<NpcGenerator> generators(NpcEntry e) => [
        if (e.mover) ...[
          const NpcGenerator('ÓRDENES DE ENTREGA', BalanceKind.town, [
            ('orderEveryDays', 'Cada cuántos días'),
            ('orderRarityLevels', 'Niveles de oficio por rareza'),
            ('orderAnyBiomeLevel', 'Oficio para pedir de cualquier bioma'),
            ('orderQualityLevel', 'Cultivo para pedir calidad rara'),
            ('orderSizeLevel', 'Pesca para pedir tamaño mínimo'),
            ('orderXpPerValue', 'XP × valor'),
            ('orderXpDayCap', 'Tope diario de XP'),
            ('orderGoldPerValue', 'Oro × valor'),
            ('orderRep', 'Relación por orden'),
            ('orderSkillEvery', 'Punto de árbol cada n órdenes'),
          ]),
          const NpcGenerator('PEDIDOS DEL PUEBLO', BalanceKind.town, [
            ('resRequestEveryDays', 'Cada cuántos días'),
            ('resUnhappyDays', 'Días hasta descontento'),
            ('resRequestRep', 'Relación al cumplir'),
          ]),
        ],
        if (e.id == 'brann')
          const NpcGenerator('ENCARGO DE FORJA', BalanceKind.town, [
            ('comGold', 'Oro por nivel del personaje'),
            ('comMat', 'Materiales condensados'),
            ('comLoot', 'Botín del bioma'),
            ('comRareScore', 'Puntaje para rara'),
            ('comEpicScore', 'Puntaje para épica'),
            ('comLegendLevel', 'Oficio para legendaria'),
            ('comIlGap', 'Niveles de objeto por debajo'),
          ]),
        if (e.rooted)
          const NpcGenerator('PEDIDO DEL DÍA', BalanceKind.fishing, [
            ('fisherRarityLevels', 'Niveles de Pesca por rareza'),
            ('fisherXpBase', 'XP de Pesca base'),
            ('fisherXpStep', 'XP de Pesca por nivel'),
            ('fisherCharXpPerValue', 'XP de personaje × valor'),
            ('fisherGoldPerValue', 'Oro × valor'),
          ]),
      ];

  /// Valor del borrador del Balance.
  num value(BalanceKind k, String key) =>
      balance.draftFields(k, k.jsonKey)[key] as num? ?? 0;

  void setValue(BalanceKind k, String key, num v) {
    balance.setField(k, k.jsonKey, key, v);
    notifyListeners();
  }

  int sampleLevel = 10;
  List<NpcSample> samples = const [];

  void setSampleLevel(int lv) {
    sampleLevel = lv.clamp(1, 99);
    notifyListeners();
  }

  /// GENERAR EJEMPLOS: siete días con las reglas del borrador.
  void generateSamples() {
    final e = selected;
    if (e == null) return;
    samples = balance.beforeAfter((_) => _roll(e, sampleLevel)).$2;
    notifyListeners();
  }

  static String _name(String id) => kFish[id]?.name ?? kCrops[id]?.name ?? id;

  static List<NpcSample> _roll(NpcEntry e, int lv) {
    final out = <NpcSample>[];
    for (var day = 1; day <= 7; day++) {
      if (e.rooted) {
        final r = BiomeFisherRules.request(e.biome, day, lv);
        if (r == null) {
          out.add((day: day, text: 'No pide nada', reward: ''));
          continue;
        }
        final w = BiomeFisherRules.reward(r, lv);
        out.add((
          day: day,
          text: '${r.n} × ${_name(r.species)} de ${r.cm} cm o más',
          reward: '${w.gold} oro · ${w.fishXp} XP de Pesca · '
              '${w.charXp} XP',
        ));
      } else {
        final r = ResidentRules.newOrder(ResidentState(e.id), day,
            fishLv: lv, farmLv: lv);
        final o = r.order;
        if (o == null) {
          out.add((day: day, text: 'No pide nada', reward: ''));
          continue;
        }
        final cm = ResidentRules.orderCm(o, r.orderQ);
        final q = kFish.containsKey(o)
            ? (cm > 0 ? ' de $cm cm o más' : '')
            : (r.orderQ > 0
                ? ' (${CropQuality.values[r.orderQ].name} o mejor)'
                : '');
        final w = ResidentRules.orderReward(r);
        out.add((
          day: day,
          text: '${r.orderN} × ${_name(o)}$q',
          reward: '${w.gold} oro · ${w.xp} XP · +${w.rep} relación'
              '${w.point ? ' · punto de árbol' : ''}',
        ));
      }
    }
    if (e.id == 'brann') {
      final c = ResidentRules.commissionCost(lv);
      final rar = ResidentRules.commissionRarity(const ResidentState('brann'),
          fishLv: lv, farmLv: lv);
      out.add((
        day: 0,
        text: 'Encargo de forja: arma nivel '
            '${ResidentRules.commissionItemLevel(lv)}, rareza $rar',
        reward: 'cuesta ${c.cost.gold} oro y ${c.lootN} × ${_name(c.loot)}',
      ));
    }
    return out;
  }
}

/// Un generador de pedidos: título, tipo del Balance y (clave, etiqueta).
class NpcGenerator {
  const NpcGenerator(this.title, this.kind, this.fields);
  final String title;
  final BalanceKind kind;
  final List<(String, String)> fields;
}
