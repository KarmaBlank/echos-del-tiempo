import '../data/biomes_catalog.dart';
import '../data/tuning_catalog.dart';

/// Etapa de un habitante en el pueblo (overworld_biomes.md § 10.3).
enum ResidentStage {
  recienLlegado('Recién llegado'),
  asentado('Asentado'),
  arraigado('Arraigado');

  const ResidentStage(this.label);
  final String label;
}

/// Pedido de mejora del pueblo de un habitante (§ 10.4).
enum ResidentRequest { casa, camino, faro, huerta, muelle }

/// Tipo de paso de una cadena de encargos (§ 10.2).
enum QuestKind { recolectar, pescar, cultivar, mazmorra, elite }

/// Un paso de la cadena de encargos de un habitante.
class QuestStepDef {
  const QuestStepDef(this.kind, this.target, this.n, this.text,
      {this.gold = 0, this.rep = 1, this.reward});
  final QuestKind kind;

  /// Producto, pez, cultivo o zona (según [kind]).
  final String target;
  final int n;
  final String text;
  final int gold;

  /// Relación que suma al cumplirlo.
  final int rep;

  /// Objeto único al final de la cadena.
  final String? reward;
}

/// Cadenas de encargos (§ 10.2). Primera pasada: la de Ilda completa.
const kResidentQuests = <String, List<QuestStepDef>>{
  'ilda': [
    QuestStepDef(QuestKind.recolectar, 'hierba_rocio', 3,
        'Traeme tres hierbas de rocío: las de esta mañana, no las de ayer.',
        gold: 60),
    QuestStepDef(QuestKind.pescar, 'trucha_musgo', 1,
        'Una trucha musgosa. Dicen que guarda el agua de un río más viejo.',
        gold: 120),
    QuestStepDef(QuestKind.cultivar, 'helecho_dulce', 2,
        'Plantá helecho dulce en tu huerta y traeme dos.', gold: 150),
    QuestStepDef(QuestKind.mazmorra, '2', 1,
        'Bajá al Bosque Hondo. Algo de allá abajo me cambia las moras.',
        gold: 300, rep: 2, reward: 'frasco_ilda'),
  ],
};

/// Estado de un habitante invitado al pueblo (§ 10). Puro e inmutable.
class ResidentState {
  const ResidentState(this.npc,
      {this.house = 0,
      this.rep = 0,
      this.quest = 0,
      this.progress = 0,
      this.request,
      this.requestDay = 0,
      this.unhappy = false});

  final String npc;

  /// Nivel de su edificio (0 = sin casa).
  final int house;
  final int rep;

  /// Paso actual de su cadena (= cantidad hecha) y avance del paso.
  final int quest;
  final int progress;
  final ResidentRequest? request;

  /// Día del mundo en que pidió [request].
  final int requestDay;

  /// "Descontento" (§ 10.4): pedido ignorado demasiados días.
  final bool unhappy;

  ResidentState copyWith(
          {int? house,
          int? rep,
          int? quest,
          int? progress,
          ResidentRequest? request,
          bool clearRequest = false,
          int? requestDay,
          bool? unhappy}) =>
      ResidentState(npc,
          house: house ?? this.house,
          rep: rep ?? this.rep,
          quest: quest ?? this.quest,
          progress: progress ?? this.progress,
          request: clearRequest ? null : (request ?? this.request),
          requestDay: requestDay ?? this.requestDay,
          unhappy: unhappy ?? this.unhappy);

  Map<String, Object?> toJson() => {
        'n': npc,
        if (house > 0) 'h': house,
        if (rep > 0) 'r': rep,
        if (quest > 0) 'q': quest,
        if (progress > 0) 'p': progress,
        if (request != null) 'rq': request!.name,
        if (requestDay > 0) 'rd': requestDay,
        if (unhappy) 'u': true,
      };

  static ResidentState? fromJson(Object? j) {
    if (j is! Map || j['n'] is! String) return null;
    int i(String k) => (j[k] as num?)?.toInt() ?? 0;
    return ResidentState(j['n'] as String,
        house: i('h'),
        rep: i('r'),
        quest: i('q'),
        progress: i('p'),
        request: ResidentRequest.values
            .where((r) => r.name == j['rq'])
            .firstOrNull,
        requestDay: i('rd'),
        unhappy: j['u'] == true);
  }
}

/// Reglas de los habitantes del pueblo (overworld_biomes.md § 10). Puras;
/// los números en `kTuning[TuningId.town]` (`res*``.
abstract final class ResidentRules {
  static TuningDef get t => tuning(TuningId.town);

  /// Se lo puede invitar: relación con él en su bioma ≥ `inviteRep`.
  static bool canInvite(int rep) => rep >= t.i('resInviteRep');

  /// Etapa por relación (`settledRep`, `rootedRep`).
  static ResidentStage stage(ResidentState r) => r.rep >= t.i('resRootedRep')
      ? ResidentStage.arraigado
      : r.rep >= t.i('resSettledRep')
          ? ResidentStage.asentado
          : ResidentStage.recienLlegado;

  /// Nivel del beneficio: etapa + nivel del edificio, menos uno si está
  /// descontento (nunca por debajo de la base, 0). Sin casa no hay
  /// beneficio (-1).
  static int tier(ResidentState r) {
    if (r.house <= 0) return -1;
    final raw = stage(r).index + r.house - 1;
    return (r.unhappy ? raw - 1 : raw).clamp(0, t.i('resMaxTier'));
  }

  /// Valor del beneficio permanente del rol en el nivel [tier] (≥ 0).
  static double benefit(NpcRole role, int tier) {
    if (tier < 0) return 0;
    final k = role.name;
    return t.d('res${k}Base') + t.d('res${k}Step') * tier;
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  /// "Beneficio: …" con el valor del nivel [tier].
  static String benefitText(BiomeNpcDef n, int tier) =>
      n.benefit.replaceAll('{v}', _fmt(benefit(n.role, tier < 0 ? 0 : tier)));

  /// Paso actual de la cadena (`null` = terminada o sin cadena).
  static QuestStepDef? currentQuest(ResidentState r) {
    final c = kResidentQuests[r.npc];
    if (c == null || r.quest >= c.length) return null;
    return c[r.quest];
  }

  /// Avanza la cadena con [n] del tipo [kind] / [target]. Devuelve el
  /// nuevo estado y el paso completado (para pagar oro y objeto).
  static (ResidentState, QuestStepDef?) advance(
      ResidentState r, QuestKind kind, String target, [int n = 1]) {
    final q = currentQuest(r);
    if (q == null || q.kind != kind || q.target != target || n <= 0) {
      return (r, null);
    }
    final p = r.progress + n;
    if (p < q.n) return (r.copyWith(progress: p), null);
    return (
      r.copyWith(quest: r.quest + 1, progress: 0, rep: r.rep + q.rep),
      q
    );
  }

  /// Costo en oro del nivel [next] del edificio (`houseGold` × nivel).
  static int houseCost(int next) => t.i('resHouseGold') * next;

  /// Un día nuevo del mundo ([day]): si no tiene pedido, pide la próxima
  /// mejora cada `requestEveryDays`; si lo ignoran `unhappyDays`, queda
  /// descontento.
  static ResidentState onDay(ResidentState r, int day) {
    final req = r.request;
    if (req == null) {
      if (day - r.requestDay < t.i('resRequestEveryDays')) return r;
      return r.copyWith(request: nextRequest(r), requestDay: day);
    }
    if (day - r.requestDay >= t.i('resUnhappyDays') && !r.unhappy) {
      return r.copyWith(unhappy: true);
    }
    return r;
  }

  /// Lo próximo que va a pedir: primero subir la casa, después el resto.
  static ResidentRequest nextRequest(ResidentState r) =>
      r.house < t.i('resMaxHouse')
          ? ResidentRequest.casa
          : ResidentRequest.values[1 + r.rep % (ResidentRequest.values.length - 1)];

  /// Pedido cumplido: suma relación, se le pasa el descontento.
  static ResidentState fulfill(ResidentState r, int day) => r.request == null
      ? r
      : r.copyWith(
          clearRequest: true,
          requestDay: day,
          unhappy: false,
          rep: r.rep + t.i('resRequestRep'),
          house: r.request == ResidentRequest.casa ? r.house + 1 : r.house);
}
