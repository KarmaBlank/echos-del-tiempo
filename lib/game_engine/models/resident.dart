/// Pedido de mejora del pueblo de un habitante (overworld_biomes.md
/// § 10.4).
enum ResidentRequest {
  casa('Subir mi casa de nivel'),
  camino('Un camino hasta mi puerta'),
  faro('Un faro cerca de mi casa'),
  huerta('Una huerta cerca de mi casa'),
  muelle('Un lago con muelle cerca de mi casa');

  const ResidentRequest(this.label);
  final String label;
}

/// Estado de un habitante de bioma para el mundo (overworld_biomes.md
/// § 10): la relación se guarda desde el primer regalo o encargo, aunque
/// todavía no viva en el pueblo. Puro e inmutable; viaja en
/// `TownState.residents`.
class ResidentState {
  const ResidentState(this.npc,
      {this.house = 0,
      this.rep = 0,
      this.quest = 0,
      this.progress = 0,
      this.request,
      this.requestDay = 0,
      this.unhappy = false,
      this.invited = false,
      this.giftDay = 0,
      this.relic = false,
      this.order,
      this.orderN = 0,
      this.orderQ = 0,
      this.orderDay = 0,
      this.orders = 0,
      this.leftAt = 0});

  /// Reloj de la sala (`GameSession.time`) en que salió de su bioma
  /// caminando hacia el pueblo (overworld_biomes.md § 10.1); 0 = no está
  /// saliendo. Lo limpia el anfitrión cuando llega al borde.
  final double leftAt;

  /// Orden de entrega (§ 10.5): producto, cultivo o pez que pide, cuántos
  /// y calidad mínima (índice de `CropQuality`; peces 0). `null` = nada.
  final String? order;
  final int orderN;
  final int orderQ;

  /// Día del mundo de la última orden (pedida o entregada).
  final int orderDay;

  /// Órdenes entregadas en total.
  final int orders;

  final String npc;

  /// Nivel de la casa donde vive (0 = sin casa). Lo copia el anfitrión
  /// de la CASA asignada (`ResidentRules.sync`).
  final int house;
  final int rep;

  /// Paso actual de su cadena (= cantidad hecha) y avance del paso.
  final int quest;
  final int progress;
  final ResidentRequest? request;

  /// Día del mundo en que pidió [request] (o en que se cumplió el último).
  final int requestDay;

  /// "Descontento" (§ 10.4): pedido ignorado demasiados días.
  final bool unhappy;

  /// Vive en el pueblo (lo invitaron).
  final bool invited;

  /// Día del mundo del último regalo que sumó relación.
  final int giftDay;

  /// Tiene su objeto único (terminó la cadena).
  final bool relic;

  ResidentState copyWith(
          {int? house,
          int? rep,
          int? quest,
          int? progress,
          ResidentRequest? request,
          bool clearRequest = false,
          int? requestDay,
          bool? unhappy,
          bool? invited,
          int? giftDay,
          bool? relic,
          String? order,
          bool clearOrder = false,
          int? orderN,
          int? orderQ,
          int? orderDay,
          int? orders,
          double? leftAt}) =>
      ResidentState(npc,
          house: house ?? this.house,
          rep: rep ?? this.rep,
          quest: quest ?? this.quest,
          progress: progress ?? this.progress,
          request: clearRequest ? null : (request ?? this.request),
          requestDay: requestDay ?? this.requestDay,
          unhappy: unhappy ?? this.unhappy,
          invited: invited ?? this.invited,
          giftDay: giftDay ?? this.giftDay,
          relic: relic ?? this.relic,
          order: clearOrder ? null : (order ?? this.order),
          orderN: clearOrder ? 0 : (orderN ?? this.orderN),
          orderQ: clearOrder ? 0 : (orderQ ?? this.orderQ),
          orderDay: orderDay ?? this.orderDay,
          orders: orders ?? this.orders,
          leftAt: leftAt ?? this.leftAt);

  Map<String, Object?> toJson() => {
        'n': npc,
        if (house > 0) 'h': house,
        if (rep > 0) 'r': rep,
        if (quest > 0) 'q': quest,
        if (progress > 0) 'p': progress,
        if (request != null) 'rq': request!.name,
        if (requestDay > 0) 'rd': requestDay,
        if (unhappy) 'u': true,
        if (invited) 'i': true,
        if (giftDay > 0) 'gd': giftDay,
        if (relic) 'rl': true,
        if (order != null) 'o': [order, orderN, orderQ],
        if (orderDay > 0) 'od': orderDay,
        if (orders > 0) 'os': orders,
        if (leftAt > 0) 'la': leftAt,
      };

  static ResidentState? fromJson(Object? j) {
    if (j is! Map || j['n'] is! String) return null;
    int i(String k) => ((j[k] as num?)?.toInt() ?? 0).clamp(0, 1 << 30);
    final o = j['o'];
    final ord = o is List && o.length == 3 && o[0] is String ? o : null;
    return ResidentState(j['n'] as String,
        house: i('h'),
        rep: i('r'),
        quest: i('q'),
        progress: i('p'),
        request: ResidentRequest.values
            .where((r) => r.name == j['rq'])
            .firstOrNull,
        requestDay: i('rd'),
        unhappy: j['u'] == true,
        invited: j['i'] == true,
        giftDay: i('gd'),
        relic: j['rl'] == true,
        order: ord?[0] as String?,
        orderN: ord == null ? 0 : ((ord[1] as num?)?.toInt() ?? 1).clamp(1, 99),
        orderQ: ord == null ? 0 : ((ord[2] as num?)?.toInt() ?? 0).clamp(0, 3),
        orderDay: i('od'),
        orders: i('os'),
        leftAt: switch (j['la']) {
          final num v when v.isFinite && v > 0 => v.toDouble(),
          _ => 0,
        });
  }

  @override
  bool operator ==(Object other) =>
      other is ResidentState &&
      other.npc == npc &&
      other.house == house &&
      other.rep == rep &&
      other.quest == quest &&
      other.progress == progress &&
      other.request == request &&
      other.requestDay == requestDay &&
      other.unhappy == unhappy &&
      other.invited == invited &&
      other.giftDay == giftDay &&
      other.relic == relic &&
      other.order == order &&
      other.orderN == orderN &&
      other.orderQ == orderQ &&
      other.orderDay == orderDay &&
      other.orders == orders &&
      other.leftAt == leftAt;

  @override
  int get hashCode => Object.hash(npc, house, rep, quest, progress, request,
      requestDay, unhappy, invited, giftDay, relic, order, orderN, orderDay,
      orders, leftAt);
}
