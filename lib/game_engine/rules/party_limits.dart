/// Máximo de jugadores por sala que usa cada build si su composition
/// root no fija otro (docs/specs/netcode.md § "Máximo de jugadores").
///
/// No es un tope del motor: `SessionEngine(maxPlayers:)` y
/// `ProtocolNetSession(maxPlayers:)` lo reciben por constructor (desde
/// `FeatureFlags.maxPlayers`) y las fórmulas de grupo del balance son
/// funciones de n con topes propios (combo_balance.md § 3.3).
const kDefaultMaxPlayers = 8;

/// Tamaño de grupo en el que termina la interpolación "solo → 4" del tope
/// por golpe (combo_balance.md § 3.2); de ahí en adelante sigue bajando
/// hasta su piso.
const kPartyBalanceRef = 4;
