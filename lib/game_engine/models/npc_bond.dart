/// Lazo con un habitante (overworld_biomes.md § 12): cuántas veces le
/// hablaste (una por día del mundo), y para los arraigados (los que no se
/// mudan) su amistad, pedidos cumplidos y si ya le hiciste la invitación.
/// Puro e inmutable; viaja en `TownState.bonds` (JSON `nat`).
class NpcBond {
  const NpcBond(this.npc,
      {this.talks = 0,
      this.talkDay = 0,
      this.rep = 0,
      this.orders = 0,
      this.declined = false});

  /// Id del habitante (`ilda`, …) o del arraigado (`pesc_<bioma>`).
  final String npc;

  /// Charlas contadas (una por día del mundo).
  final int talks;

  /// Día del mundo de la última charla contada.
  final int talkDay;

  /// Amistad de un arraigado (los que se mudan usan `ResidentState.rep`).
  final int rep;

  /// Pedidos del día cumplidos (arraigados).
  final int orders;

  /// Ya lo invitaste y te dijo que no (y te dio su regalo).
  final bool declined;

  NpcBond copyWith(
          {int? talks, int? talkDay, int? rep, int? orders, bool? declined}) =>
      NpcBond(npc,
          talks: talks ?? this.talks,
          talkDay: talkDay ?? this.talkDay,
          rep: rep ?? this.rep,
          orders: orders ?? this.orders,
          declined: declined ?? this.declined);

  Map<String, Object?> toJson() => {
        'n': npc,
        if (talks > 0) 't': talks,
        if (talkDay > 0) 'td': talkDay,
        if (rep > 0) 'r': rep,
        if (orders > 0) 'o': orders,
        if (declined) 'd': true,
      };

  static NpcBond? fromJson(Object? j) {
    if (j is! Map || j['n'] is! String) return null;
    int i(String k) => ((j[k] as num?)?.toInt() ?? 0).clamp(0, 1 << 30);
    return NpcBond(j['n'] as String,
        talks: i('t'),
        talkDay: i('td'),
        rep: i('r'),
        orders: i('o'),
        declined: j['d'] == true);
  }
}
