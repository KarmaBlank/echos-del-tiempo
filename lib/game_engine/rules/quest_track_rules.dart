import '../data/biomes_catalog.dart';
import '../data/farming_catalog.dart';
import '../data/fishing_catalog.dart';
import '../models/player_profile.dart';
import '../models/world_save.dart';
import 'resident_rules.dart';

/// Tipo de encargo activo que se puede seguir (roles.md § 8).
enum QuestTrackKind {
  encargo('Encargo'),
  pedido('Pedido'),
  orden('Orden');

  const QuestTrackKind(this.label);
  final String label;
}

/// Marca sobre la cabeza de un habitante (roles.md § 8.4).
enum NpcMark { none, news, ready }

/// Un encargo, pedido u orden activo de un habitante, con su avance.
class ActiveQuest {
  const ActiveQuest({
    required this.npc,
    required this.kind,
    required this.title,
    required this.step,
    this.item,
    this.have = 0,
    this.need = 0,
    this.tracked = false,
  });

  final BiomeNpcDef npc;
  final QuestTrackKind kind;
  final String title;

  /// Número del encargo (1-based) o 0.
  final int step;

  /// Lo que pide (pez, cultivo o producto), si es de entregar.
  final String? item;
  final int have;
  final int need;
  final bool tracked;

  String get key => QuestTrackRules.trackKey(kind, npc.id);

  bool get ready => item != null && need > 0 && have >= need;

  /// "Ilda · encargo 3" / "Ilda · orden".
  String get who => step > 0
      ? '${npc.name} · ${kind.label.toLowerCase()} $step'
      : '${npc.name} · ${kind.label.toLowerCase()}';
}

/// Seguimiento de encargos y marcas de habitantes (roles.md § 8): reglas
/// puras; el anfitrión valida SEGUIR y VISTO (`TownOp.track` / `seen`).
abstract final class QuestTrackRules {
  static const maxTracked = 5;

  static String trackKey(QuestTrackKind k, String npc) => '${k.name}:$npc';

  static String itemName(String id) =>
      kFish[id]?.name ?? kCrops[id]?.name ?? id;

  /// Huella de "lo que tiene para decir" un habitante: cambia con un paso
  /// nuevo de su cadena, un pedido nuevo o una orden nueva.
  static String newsKey(ResidentState r) =>
      'q${r.quest}|r${r.request?.name ?? '-'}${r.requestDay}'
      '|o${r.order ?? '-'}${r.orderDay}';

  /// ¿El paso actual ya se lo contó a este jugador?
  static bool seen(PlayerProfile p, ResidentState r) =>
      p.npcSeen[r.npc] == newsKey(r);

  /// ¿Ya habló alguna vez con [npc]? (DIARIO: solo los conocidos tienen
  /// pestaña). Hablar siempre deja su huella en `npcSeen`.
  static bool met(PlayerProfile p, String npc) => p.npcSeen.containsKey(npc);

  /// ¿Ya le contó el paso actual de su cadena?
  static bool questSeen(PlayerProfile p, ResidentState r) =>
      (p.npcSeen[r.npc] ?? '').split('|').first == 'q${r.quest}';

  /// Encargos activos de todos los habitantes para [p].
  static List<ActiveQuest> active(PlayerProfile p, TownState t) => [
        for (final n in kBiomeNpcs) ...forNpc(p, t, n),
      ];

  static List<ActiveQuest> forNpc(
      PlayerProfile p, TownState t, BiomeNpcDef n) {
    final r = t.resident(n.id);
    final out = <ActiveQuest>[];
    final q = ResidentRules.currentQuest(r);
    // El paso activo cuenta recién cuando él lo pidió (lo vio en el
    // diálogo) o si ya tiene avance.
    if (q != null && (r.progress > 0 || questSeen(p, r))) {
      final deliver = q.kind.delivered;
      out.add(ActiveQuest(
        npc: n,
        kind: QuestTrackKind.encargo,
        title: deliver
            ? '${q.n - r.progress} × ${itemName(q.target)}'
            : q.kind.label,
        step: r.quest + 1,
        item: deliver ? q.target : null,
        have: deliver ? ResidentRules.questHave(p, q) : 0,
        need: deliver ? q.n - r.progress : 0,
        tracked: p.tracked
            .contains(trackKey(QuestTrackKind.encargo, n.id)),
      ));
    }
    if (r.request case final req?) {
      out.add(ActiveQuest(
        npc: n,
        kind: QuestTrackKind.pedido,
        title: req.label,
        step: 0,
        tracked:
            p.tracked.contains(trackKey(QuestTrackKind.pedido, n.id)),
      ));
    }
    if (r.order case final o?) {
      out.add(ActiveQuest(
        npc: n,
        kind: QuestTrackKind.orden,
        title: '${r.orderN} × ${itemName(o)}',
        step: 0,
        item: o,
        have: ResidentRules.orderHave(p, o, r.orderQ),
        need: r.orderN,
        tracked: p.tracked.contains(trackKey(QuestTrackKind.orden, n.id)),
      ));
    }
    return out;
  }

  /// Los activos que piden [item].
  static List<ActiveQuest> needing(
          PlayerProfile p, TownState t, String item) =>
      [for (final a in active(p, t)) if (a.item == item) a];

  /// Marca de [n] para [p]: "?" si hay algo listo para entregar, "!" si
  /// tiene algo nuevo que todavía no le contó, nada si no.
  static NpcMark mark(PlayerProfile p, TownState t, BiomeNpcDef n) {
    final r = t.resident(n.id);
    if (forNpc(p, t, n).any((a) => a.ready)) {
      return NpcMark.ready;
    }
    // Vive en el pueblo sin casa (overworld_biomes.md § 10.1): pendiente
    // hasta que le asignen una.
    if (ResidentRules.homeless(t, n.id)) return NpcMark.news;
    final hasNews = ResidentRules.currentQuest(r) != null ||
        r.request != null ||
        r.order != null;
    return hasNews && !seen(p, r) ? NpcMark.news : NpcMark.none;
  }

  /// SEGUIR / DEJAR DE SEGUIR [key]; `null` si no aplica (no existe, o
  /// ya sigue [maxTracked]).
  static PlayerProfile? toggle(PlayerProfile p, TownState t, String key) {
    if (p.tracked.contains(key)) {
      return p.copyWith(tracked: [...p.tracked]..remove(key));
    }
    if (p.tracked.length >= maxTracked) return null;
    if (!active(p, t).any((a) => a.key == key)) return null;
    return p.copyWith(tracked: [...p.tracked, key]);
  }

  /// Marca como visto lo que [npc] tiene para decir.
  static PlayerProfile? markSeen(PlayerProfile p, TownState t, String npc) {
    if (biomeNpc(npc) == null) return null;
    final k = newsKey(t.resident(npc));
    if (p.npcSeen[npc] == k) return null;
    return p.copyWith(npcSeen: {...p.npcSeen, npc: k});
  }

  /// Quita de [p] lo seguido que ya no está activo.
  static PlayerProfile prune(PlayerProfile p, TownState t) {
    if (p.tracked.isEmpty) return p;
    final keys = {for (final a in active(p, t)) a.key};
    final keep = [for (final k in p.tracked) if (keys.contains(k)) k];
    return keep.length == p.tracked.length ? p : p.copyWith(tracked: keep);
  }
}
