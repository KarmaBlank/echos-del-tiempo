import '../../../app/theme/proto_markup.dart';
import '../../../core/i18n/game_text.dart';
import '../../../game_engine/data/abyss_catalog.dart';
import '../../../game_engine/data/uniques_catalog.dart';
import '../../../game_engine/models/atlas.dart';
import '../../../game_engine/models/eco.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/rules/abyss_rules.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/atlas_rules.dart';
import '../../../game_engine/rules/eco_portal_rules.dart';
import '../../../game_engine/rules/eco_rules.dart';
import '../../inventory/domain/item_names.dart';
import 'endgame_names.dart';

/// Textos del Portal del Eco, del Atlas y de los Jefes del Abismo
/// (docs/specs/ecos_atlas.md, abyss_bosses.md) en el idioma activo
/// (`GameText`, docs/specs/i18n.md § 3.5). Los motivos que en el motor
/// están en es-AR (`lockReason`, `cannotCraft`, `cannotOpen`,
/// `cannotTake`) tienen acá su espejo con claves.

String _t(String key, [Map<String, Object?> args = const {}]) =>
    GameText.t(key, args);

/// Ayuda `[?]` del portal.
String get kEcoPortalHelp => _t('ui.endgame.portal.help');

/// Por qué el portal T[tier] de [zone] sigue cerrado (o `null`): espejo
/// de `EcoPortalRules.lockReason`.
String? ecoLockText(PlayerProfile p, int zone, int tier, {String? zoneName}) {
  if (!EcoPortalRules.zoneBeaten(p, zone)) {
    return _t('ui.endgame.lock.beat_boss', {
      'named': zoneName == null ? 'no' : 'yes',
      'name': zoneName ?? '',
      'zone': zone,
    });
  }
  if (tier > EcoPortalRules.unlockedTier(p, zone)) {
    return _t(
        'ui.endgame.lock.complete_tier', {'prev': tier - 1, 'tier': tier});
  }
  return null;
}

/// Por qué no se puede abrir [e] en el portal T[tier] de [zone] ahora
/// (o `null`; ecos_zone.md § 4). [near]: el jugador sigue frente al portal.
String? ecoZoneOpenBlocked(GameSession s, PlayerProfile p, EcoItem? e,
    int zone, int tier,
    {required bool near, String? zoneName}) {
  final lock = ecoLockText(p, zone, tier, zoneName: zoneName);
  if (lock != null) return lock;
  if (e == null) return _t('ui.endgame.blocked.need_eco', {'tier': tier});
  if (s.mode != SessionMode.lobby) {
    return _t('ui.endgame.blocked.outside_mission');
  }
  if (s.vote != null) return _t('ui.endgame.blocked.vote_open');
  if (!near) return _t('ui.endgame.blocked.get_closer');
  return null;
}

/// Por qué no se puede craftear (modo, Eco en votación y espejo de
/// `EcoRules.cannotCraft`) o `null`.
String? ecoCraftBlocked(
    GameSession s, String localId, PlayerProfile p, EcoItem e, EcoCraftOp op) {
  if (!s.canShop) return _t('ui.endgame.only_in_town');
  if (s.ecoOwner == localId && s.eco?.uid == e.uid) {
    return _t('ui.endgame.blocked.eco_in_vote');
  }
  final own = p.ecoByUid(e.uid);
  if (own == null) return _t('ui.endgame.craft.no_eco');
  if (EcoRules.blocked(own, op) != null) {
    return _t(switch (op) {
      EcoCraftOp.reroll => 'ui.endgame.craft.no_mods',
      EcoCraftOp.addMod => 'ui.endgame.craft.max_mods',
      EcoCraftOp.rarity => 'ui.endgame.craft.max_rarity',
      EcoCraftOp.tier => 'ui.endgame.craft.max_tier',
    });
  }
  final c = EcoRules.cost(own, op)!;
  if (p.material(c.$1) < c.$2) {
    return _t('ui.endgame.craft.missing', {'material': c.$1.endgameTr});
  }
  return null;
}

/// FUSIONAR (ecos_atlas.md § 4.2): `(se puede, motivo)`. Sin los Ecos
/// completos el botón va gris SIN motivo (es lo normal); el motivo sale
/// solo en los casos raros (fuera del pueblo, Eco en votación, tier 16,
/// faltan Anclas).
(bool, String?) ecoFuseState(
    GameSession s, String localId, PlayerProfile p, List<String> uids) {
  if (!s.canShop) return (false, _t('ui.endgame.only_in_town'));
  if (s.ecoOwner == localId && uids.contains(s.eco?.uid)) {
    return (false, _t('ui.endgame.blocked.eco_in_vote'));
  }
  return switch (EcoRules.cannotFuse(p, uids)) {
    null => (true, null),
    EcoFuseBlock.maxTier => (false, _t('ui.endgame.fuse.max_tier')),
    EcoFuseBlock.material => (
        false,
        _t('ui.endgame.craft.missing',
            {'material': CraftMaterial.ancla.endgameTr})
      ),
    _ => (false, null),
  };
}

/// Etiqueta del botón de crafteo (`MODS NUEVOS (Esquirla del Eco ×1)`).
String ecoCraftLabel(EcoItem e, EcoCraftOp op) {
  final c = EcoRules.cost(e, op);
  final what = _t('ui.endgame.craft.op.${op.name}');
  return c == null
      ? what
      : _t('ui.endgame.craft.label_cost',
          {'what': what, 'material': c.$1.endgameTr, 'n': c.$2});
}

/// Fila de mejora del Portal: `<b>+1 tier</b> 1 Anc.` (el costo en
/// `dim`).
String ecoCraftRowMarkup(EcoItem e, EcoCraftOp op) {
  final c = EcoRules.cost(e, op);
  final what = _t('ui.endgame.craft.row.${op.name}');
  return '<b>$what</b>'
      '${c == null ? '' : ' <span style="color:#7d8bc4">${c.$2} ${_t('ui.endgame.material_abbr.${c.$1.name}')}</span>'}';
}

// ---------------------------------------------------------------------
// Jefes del Abismo v0.8 (docs/specs/abyss_bosses.md § 4). Sin lore:
// nombres y textos de mecánica.
// ---------------------------------------------------------------------

/// Ayuda `[?]` de la pestaña ABISMO.
String get kAbyssHelp => _t('ui.endgame.abyss.help');

/// Costo de [d] (espejo de `AbyssRules.costText`).
String abyssCostText(AbyssBossDef d) => d.fragment == null
    ? _t('ui.endgame.abyss.cost_each')
    : '${d.fragmentCost} ${d.fragment!.endgameTr}';

/// Por qué no se puede abrir [d] ahora (o `null`; espejo de
/// `AbyssRules.cannotOpen`).
String? abyssOpenBlocked(
    GameSession s, PlayerProfile p, AbyssBossDef d, AbyssRules rules) {
  if (s.mode != SessionMode.lobby) return _t('ui.endgame.only_in_town');
  if (s.vote != null) return _t('ui.endgame.blocked.vote_open');
  if (!p.ecosUnlocked) return _t('ui.endgame.abyss.beat_devourer');
  if (d.secret && !AbyssRules.beatAllFour(p)) {
    return _t('ui.endgame.abyss.beat_four');
  }
  for (final e in rules.cost(d).entries) {
    final have = p.material(e.key);
    if (have < e.value) {
      return _t('ui.endgame.abyss.missing',
          {'material': e.key.endgameTr, 'have': have, 'need': e.value});
    }
  }
  return null;
}

/// Nombre visible de [d]: `???` hasta vencerlo (el secreto, hasta vencer
/// a los 4).
String abyssBossLabel(PlayerProfile p, AbyssBossDef d) {
  if (d.secret && !AbyssRules.visible(p, d)) {
    return _t('ui.endgame.abyss.secret');
  }
  return AbyssRules.known(p, d) || !d.secret ? d.tr : '???';
}

/// Ficha de [d] (markup): nivel, fases, costo, mecánica y recompensas.
String abyssDetailMarkup(
    PlayerProfile p, AbyssBossDef d, AbyssRules rules, String counter) {
  if (d.secret && !AbyssRules.visible(p, d)) {
    return _t('ui.endgame.abyss.secret_detail', {
      'title': _t('ui.endgame.abyss.secret'),
      'beaten': p.abyssKills.where((n) => n <= 4).length,
      'cost': abyssCostText(d),
    });
  }
  final legs = [
    for (final id in d.legendaryIds)
      if (kUniques[id] case final u?) protoEsc(u.text),
  ];
  return _t('ui.endgame.abyss.detail', {
    'name': protoEsc(d.tr),
    'beaten': AbyssRules.known(p, d) ? 'yes' : 'no',
    'level': d.level,
    'phases': [
      for (var i = 0; i < d.phases.length; i++) protoEsc(d.phaseTr(i)),
    ].join(' → '),
    'cost': abyssCostText(d),
    'enrage': d.enrageTurns,
    'counter': counter,
    'legendaries': legs.join(_t('ui.endgame.abyss.or')),
    'chance': (d.legendaryChance * 100).round(),
    'points': d.atlasPoints,
  });
}

/// Nombre corto de un Fragmento (`Reloj`).
String abyssFragmentShort(CraftMaterial m) =>
    _t('ui.endgame.fragment_short.${m.name}');

/// Línea de Fragmentos del jugador.
String abyssFragmentsMarkup(PlayerProfile p) => [
      for (final f in kFragments)
        '${protoEsc(abyssFragmentShort(f))} <b>${p.material(f)}</b>',
      '${_t('ui.endgame.essence_short')} '
          '<b>${p.material(CraftMaterial.esencia)}</b>',
    ].join(' · ');

/// Línea del resultado de un Jefe del Abismo vencido.
String abyssResultText(String name, int points) => points > 0
    ? _t('ui.endgame.abyss.result_points', {'name': name, 'points': points})
    : _t('ui.endgame.abyss.result_again', {'name': name});

/// Texto de la Maestría para la barra / el panel.
String masteryText(PlayerProfile p) => p.mastery >= PlayerProfile.maxMastery
    ? _t('ui.endgame.mastery_max')
    : _t('ui.endgame.mastery', {'n': p.mastery});

/// Línea del resultado de un Eco completado con lo que ganó tu Atlas.
String ecoAtlasText(AtlasGain? g) {
  if (g == null || g.points == 0) return _t('ui.endgame.atlas.gain_none');
  final what = [
    for (final k in g.keys)
      switch (k[0]) {
        't' => _t('ui.endgame.atlas.gain_tier', {'tier': k.substring(1)}),
        'z' => _t('ui.endgame.atlas.gain_zone'),
        _ => _t('ui.endgame.atlas.gain_boss'),
      },
  ];
  return _t(
      'ui.endgame.atlas.gain', {'points': g.points, 'list': what.join(', ')});
}

/// Por qué no se puede tomar el nodo [id] del Atlas (o `null`): espejo
/// de `AtlasRules.cannotTake`.
String? atlasTakeBlocked(AtlasRules rules, AtlasProgress p, String id) {
  final n = rules.node(id);
  if (n == null) return _t('ui.endgame.atlas.unknown_node');
  if (n.locked) return _t('ui.endgame.atlas.soon');
  if (rules.has(p, id)) return _t('ui.endgame.atlas.already_taken');
  if (!n.links.any((l) => rules.has(p, l))) {
    return _t('ui.endgame.atlas.not_linked');
  }
  if (rules.free(p) < n.cost) {
    return _t('ui.endgame.atlas.missing_points', {'cost': n.cost});
  }
  return null;
}
