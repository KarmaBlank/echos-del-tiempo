import '../../../app/theme/proto_markup.dart';
import '../../../game_engine/data/abyss_catalog.dart';
import '../../../game_engine/data/uniques_catalog.dart';
import '../../../game_engine/models/eco.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/rules/abyss_rules.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/atlas_rules.dart';
import '../../../game_engine/rules/eco_portal_rules.dart';
import '../../../game_engine/rules/eco_rules.dart';

/// Textos del Portal del Eco y del Atlas (docs/specs/ecos_atlas.md).

/// Ayuda `[?]` del portal.
const kEcoPortalHelp = '<b>Portal del Eco</b><br>'
    '<span class="k">ZONAS</span>: cada zona tiene su portal de Ecos en el '
    'exterior de su bioma, con un tier por Eco. IR te lleva hasta ahí. T1 '
    'se abre al vencer al jefe de la zona; cada Eco completado abre el tier '
    'siguiente de esa zona.<br>'
    '<span class="k">ECOS</span>: mapas de endgame que caen como loot desde '
    'nivel 45. Cada uno tiene tier (monstruos nivel 50 a 80), zona, jefe y '
    'modificadores que lo hacen más difícil pero suman <b>cantidad</b> y '
    '<b>rareza</b> de botín. Se abren en el portal de su zona '
    '(este portal ya no abre Ecos); se consume al entrar, se complete o '
    'no.<br>'
    'Crafteo: Esquirla (mods nuevos), Cristal (+1 mod), Prisma (rareza), '
    'Ancla Temporal (+1 tier; cae solo en Ecos).<br>'
    '<span class="k">ATLAS</span>: árbol de toda tu cuenta. La primera vez '
    'que completás un tier, una zona o un jefe ganás puntos. Reiniciar es '
    'gratis. En grupo vale el Atlas del anfitrión; los puntos los gana cada '
    'uno.<br>'
    '+10% de cantidad de botín por cada jugador extra en el Eco.';

/// Por qué no se puede abrir [e] en el portal T[tier] de [zone] ahora
/// (o `null`; ecos_zone.md § 4). [near]: el jugador sigue frente al portal.
String? ecoZoneOpenBlocked(GameSession s, PlayerProfile p, EcoItem? e,
    int zone, int tier,
    {required bool near, String? zoneName}) {
  final lock = EcoPortalRules.lockReason(p, zone, tier, zoneName: zoneName);
  if (lock != null) return lock;
  if (e == null) return 'Necesitás un Eco T$tier de esta zona';
  if (s.mode != SessionMode.lobby) return 'Solo fuera de misión';
  if (s.vote != null) return 'Ya hay una votación';
  if (!near) return 'Acercate al portal';
  return null;
}

/// Por qué no se puede craftear (modo y Eco en votación) o `null`.
String? ecoCraftBlocked(
    GameSession s, String localId, PlayerProfile p, EcoItem e, EcoCraftOp op) {
  if (!s.canShop) return 'Solo en el pueblo';
  if (s.ecoOwner == localId && s.eco?.uid == e.uid) return 'Eco en votación';
  return EcoRules.cannotCraft(p, e.uid, op);
}

/// Etiqueta del botón de crafteo (`ESQUIRLA ×1`).
String ecoCraftLabel(EcoItem e, EcoCraftOp op) {
  final c = EcoRules.cost(e, op);
  final what = switch (op) {
    EcoCraftOp.reroll => 'MODS NUEVOS',
    EcoCraftOp.addMod => '+1 MOD',
    EcoCraftOp.rarity => 'RAREZA',
    EcoCraftOp.tier => '+1 TIER',
  };
  return c == null ? what : '$what (${c.$1.label} ×${c.$2})';
}

/// Fila de mejora del Portal: `<b>+1 Tier</b> 1 Ancla` (el costo en
/// `dim`).
String ecoCraftRowMarkup(EcoItem e, EcoCraftOp op) {
  final c = EcoRules.cost(e, op);
  final what = switch (op) {
    EcoCraftOp.reroll => 'Mods nuevos',
    EcoCraftOp.addMod => '+1 mod',
    EcoCraftOp.rarity => 'Rareza',
    EcoCraftOp.tier => '+1 tier',
  };
  return '<b>$what</b>'
      '${c == null ? '' : ' <span style="color:#7d8bc4">${c.$2} ${c.$1.label.substring(0, 3)}.</span>'}';
}

// ---------------------------------------------------------------------
// Jefes del Abismo v0.8 (docs/specs/abyss_bosses.md § 4). Sin lore:
// nombres y textos de mecánica.
// ---------------------------------------------------------------------

/// Ayuda `[?]` de la pestaña ABISMO.
const kAbyssHelp = '<b>Jefes del Abismo</b><br>'
    'Versiones extremas de 4 jefes (nivel 85–90) y un jefe secreto. '
    '<span class="k">Fragmentos</span>: caen en Ecos de tier 10 o más '
    '(más tier, rareza y mods = más chance; el Eco cuyo jefe coincide da '
    'más de ese Fragmento). 5 abren su jefe; se consumen al entrar.<br>'
    'Pelea directa, sin mazmorra: fases, avisos del próximo movimiento y '
    'furia si tarda. Cada jugador gana su propio botín: el legendario '
    'exclusivo es seguro la primera vez; Esencias del Abismo (forja).<br>'
    'El secreto pide vencer a los 4 y 1 Fragmento de cada uno.';

/// Por qué no se puede abrir [d] ahora (o `null`).
String? abyssOpenBlocked(
    GameSession s, PlayerProfile p, AbyssBossDef d, AbyssRules rules) {
  if (s.mode != SessionMode.lobby) return 'Solo en el pueblo';
  if (s.vote != null) return 'Ya hay una votación';
  return rules.cannotOpen(p, d);
}

/// Nombre visible de [d]: `???` hasta vencerlo (el secreto, hasta vencer
/// a los 4).
String abyssBossLabel(PlayerProfile p, AbyssBossDef d) {
  if (d.secret && !AbyssRules.visible(p, d)) return '??? · Jefe secreto';
  return AbyssRules.known(p, d) || !d.secret ? d.name : '???';
}

/// Ficha de [d] (markup): nivel, fases, costo, mecánica y recompensas.
String abyssDetailMarkup(
    PlayerProfile p, AbyssBossDef d, AbyssRules rules, String counter) {
  if (d.secret && !AbyssRules.visible(p, d)) {
    return '<b>??? · Jefe secreto</b><br>'
        '<span class="k">Requisito:</span> vencer a los 4 Jefes del Abismo '
        '(${p.abyssKills.where((n) => n <= 4).length}/4).<br>'
        '<span class="k">Costo:</span> ${rules.costText(d)}.';
  }
  final legs = [
    for (final id in d.legendaryIds)
      if (kUniques[id] case final u?) protoEsc(u.name),
  ];
  return '<b>${protoEsc(d.name)}</b>'
      '${AbyssRules.known(p, d) ? ' <span class="k">(vencido)</span>' : ''}<br>'
      '<span class="k">Nivel</span> ${d.level} · '
      '<span class="k">Fases</span> ${d.phases.map((f) => protoEsc(f.name)).join(' → ')}<br>'
      '<span class="k">Costo:</span> ${rules.costText(d)} (se consume al entrar)<br>'
      '<span class="k">Furia:</span> en su turno ${d.enrageTurns}<br>'
      '$counter<br>'
      '<span class="k">Recompensas:</span> ${legs.join(' o ')} (seguro la '
      'primera vez, después ${(d.legendaryChance * 100).round()}%), '
      'Esencia del Abismo, +${d.atlasPoints} punto${d.atlasPoints == 1 ? '' : 's'} '
      'de Atlas la primera vez.';
}

/// Línea de Fragmentos del jugador.
String abyssFragmentsMarkup(PlayerProfile p) => [
      for (final f in kFragments)
        '${protoEsc(f.label.split(' ').last)} <b>${p.material(f)}</b>',
      'Esencia <b>${p.material(CraftMaterial.esencia)}</b>',
    ].join(' · ');

/// Línea del resultado de un Jefe del Abismo vencido.
String abyssResultText(String name, int points) => points > 0
    ? '$name vencido: +$points punto${points == 1 ? '' : 's'} de Atlas'
    : '$name vencido de nuevo';

/// Texto de la Maestría para la barra / el panel.
String masteryText(PlayerProfile p) => p.mastery >= PlayerProfile.maxMastery
    ? 'MAESTRÍA MÁX'
    : 'MAESTRÍA ${p.mastery}';

/// Línea del resultado de un Eco completado con lo que ganó tu Atlas.
String ecoAtlasText(AtlasGain? g) {
  if (g == null || g.points == 0) {
    return 'Atlas: sin primeras veces esta vez (ya completaste ese tier, '
        'zona y jefe).';
  }
  final what = [
    for (final k in g.keys)
      switch (k[0]) {
        't' => 'tier ${k.substring(1)}',
        'z' => 'zona nueva',
        _ => 'jefe nuevo',
      },
  ];
  return '+${g.points} punto${g.points == 1 ? '' : 's'} de Atlas: '
      '${what.join(', ')}';
}
