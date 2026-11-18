import '../../../game_engine/models/eco.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/atlas_rules.dart';
import '../../../game_engine/rules/eco_rules.dart';

/// Textos del Portal del Eco y del Atlas (docs/specs/ecos_atlas.md).

/// Ayuda `[?]` del portal.
const kEcoPortalHelp = '<b>Portal del Eco</b><br>'
    '<span class="k">ECOS</span>: mapas de endgame que caen como loot desde '
    'nivel 45. Cada uno tiene tier (monstruos nivel 50 a 80), zona, jefe y '
    'modificadores que lo hacen más difícil pero suman <b>cantidad</b> y '
    '<b>rareza</b> de botín. ABRIR propone el Eco al grupo; se consume al '
    'entrar, se complete o no.<br>'
    'Crafteo: Esquirla (mods nuevos), Cristal (+1 mod), Prisma (rareza), '
    'Ancla Temporal (+1 tier; cae solo en Ecos).<br>'
    '<span class="k">ATLAS</span>: árbol de toda tu cuenta. La primera vez '
    'que completás un tier, una zona o un jefe ganás puntos. Reiniciar es '
    'gratis. En grupo vale el Atlas del anfitrión; los puntos los gana cada '
    'uno.<br>'
    '+10% de cantidad de botín por cada jugador extra en el Eco.';

/// Por qué no se puede abrir [e] ahora (o `null`).
String? ecoOpenBlocked(GameSession s, PlayerProfile p, EcoItem e) {
  if (!p.ecosUnlocked) return 'Vencé al Devorador de Eras';
  if (s.mode != SessionMode.lobby) return 'Solo en el pueblo';
  if (s.vote != null) return 'Ya hay una votación';
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
