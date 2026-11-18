import '../../../game_engine/data/eco_catalog.dart';
import '../../../game_engine/models/atlas.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/eco.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/loot.dart';
import '../../../game_engine/models/player_state.dart';
import '../../../game_engine/models/upgrade_stat.dart';
import '../../../game_engine/models/weapon.dart';
import '../../../game_engine/rules/eco_rules.dart';
import '../../../game_engine/rules/loot_filter_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';
import 'weapon_text.dart';

/// Textos de objetos del loot v2 (ficha / tooltip, requisitos, mods) en
/// el markup del prototipo (`ProtoMarkup`). Ver docs/specs/panels.md §
/// "Ficha de objeto".

const _green = '#7bed9f';
const _red = '#ff6b81';
const _sky = '#9fb4ff';
const _orange = '#ff9f43';
const _pink = '#e84393';
const _dim = '#7d8bc4';

/// Azul claro de los mods (como los de los ARPG, legible sobre el panel).
const kModHex = '#9fc4ff';

/// Violeta de las pasivas de arma.
const kPassiveHex = '#c39bff';

/// `#rrggbb` del color de una rareza (`LootFilterRules.rarityColor`:
/// Común blanco, Mágico azul, Raro amarillo, Épico violeta, Legendario
/// naranja), el mismo que usa el filtro en el mapa.
String rarityHex(Rarity r) {
  final c = LootFilterRules.rarityColor(r);
  String h(int v) => v.toRadixString(16).padLeft(2, '0');
  return '#${h(c.r)}${h(c.g)}${h(c.b)}';
}

/// `<span style="color:#hex">`.
String _c(String hex, String text) => '<span style="color:$hex">$text</span>';

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// Requisitos que faltan con [a], p. ej. `FUE 14 DES 8`.
String missingRequirements(WeaponDef w, PlayerAttributes a) => [
      for (final e in w.requirements.entries)
        if (a[e.key] < e.value) '${attributeShort(e.key)} ${e.value}',
    ].join(' ');

/// `Requiere: Nv L FUE 14 DES 8`, cada uno verde (cumple) o rojo (falta).
String requirementsLineMarkup(WeaponDef w, int level, PlayerAttributes a) {
  final parts = [
    _c(level >= w.level ? _green : _red, 'Nv ${w.level}'),
    for (final e in w.requirements.entries)
      _c(a[e.key] >= e.value ? _green : _red,
          '${attributeShort(e.key)} ${e.value}'),
  ];
  return 'Requiere: ${parts.join(' ')}';
}

/// Nombre de un objeto en el color de su rareza (negrita).
String itemNameMarkup(ProgressionRules rules, ItemInstance it) =>
    '<b style="color:${rarityHex(it.rarity)}">'
    '${_esc(rules.items.displayName(it))}</b>';

/// Texto de un mod con su tier, en azul (los fijos de un único, naranja).
String affixMarkup(ProgressionRules rules, AffixRoll a) =>
    _c(a.fixed ? _orange : kModHex, _esc(rules.items.affixText(a)));

/// Habilidades del objeto (base y trasladadas) y la ULT del tipo.
String itemSkillsMarkup(ProgressionRules rules, ItemInstance it) {
  final cat = rules.catalog;
  final w = cat.weapons[it.baseId];
  final names = [
    for (final id in rules.items.skillsOf(it))
      if (cat.skills[id] case final s?)
        (w?.skillIds.contains(id) ?? false)
            ? _esc(s.name)
            : '${_esc(s.name)} ${_c(_orange, '(trasladada)')}',
  ];
  final ult = w == null ? null : cat.ultimates[w.type]?.name;
  return [
    names.isEmpty ? '—' : names.join(' · '),
    if (ult != null) _c(_pink, 'ULT: ${_esc(ult)}'),
  ].join(' · ');
}

/// `Forja +3/8 (Poder 2, Crítico 1)`.
String forgeText(ItemInstance it) {
  final f = it.forge;
  final parts = [
    for (final s in UpgradeStat.values)
      if (f.level(s) > 0) '${s.label} ${f.level(s)}',
  ];
  return 'Forja +${it.forgeLevel}/${it.rarity.forgeCap}'
      '${parts.isEmpty ? '' : ' (${parts.join(', ')})'}';
}

/// Ficha completa de un arma (tooltip y detalle). [level] y [attributes]
/// son los de quien mira (colorean los requisitos); [stats] = sus stats
/// si la equipara (ATQ / MAG con mods y forja), opcional.
String itemTooltipMarkup(
  ProgressionRules rules,
  ItemInstance it, {
  required int level,
  required PlayerAttributes attributes,
  DerivedStats? stats,
  bool equipped = false,
}) {
  final items = rules.items;
  final w = items.baseOf(it);
  final l = <String>[itemNameMarkup(rules, it)];
  final base = w?.name ?? it.baseId;
  final generated = it.rarity.index >= Rarity.raro.index;
  l.add('<span class="k">${it.rarity.label} · ${w?.type ?? '?'} · '
      'nivel de objeto ${it.itemLevel}</span>'
      '${generated ? ' ${_c(_dim, _esc(base))}' : ''}'
      '${equipped ? ' ${_c(_orange, 'EQUIPADA')}' : ''}');
  if (w != null) l.add(requirementsLineMarkup(w, level, attributes));
  if (stats != null) {
    l.add('ATQ <b>${stats.attack}</b> · MAG <b>${stats.magic}</b>'
        '${_c(_dim, ' (con tus atributos)')}');
  }
  final implicit = w == null ? const <ItemMod>[] : items.implicitMods(w);
  if (implicit.isNotEmpty) {
    l.add('<span class="k">Implícito:</span> '
        '${implicit.map((m) => _esc(m.text)).join(', ')}');
  }
  if (it.rarity.maxMods > 0 || it.affixes.isNotEmpty) {
    l.add('<span class="k">Mods ${it.modCount}/${it.rarity.maxMods}</span>');
    for (final a in it.affixes) {
      l.add('• ${affixMarkup(rules, a)}');
    }
  }
  final passive = items.passiveText(it);
  if (passive != null) {
    l.add('${_c(kPassiveHex, '<b style="color:$kPassiveHex">Pasiva</b>')} '
        '${_c(kPassiveHex, _esc(passive))}');
  }
  if (it.forgeLevel > 0 || it.rarity.forgeCap > 0) l.add(forgeText(it));
  l.add('<span class="k">Habilidades:</span> ${itemSkillsMarkup(rules, it)}');
  if (w != null && w.weight > 0) {
    l.add(_c(_dim, 'Peso ${fmtNum(w.weight)} (−${fmtNum(w.weight)} vel.)'));
  }
  final flavor = items.uniqueOf(it)?.flavor;
  if (flavor != null && flavor.isNotEmpty) l.add(_c(_dim, _esc(flavor)));
  return l.join('<br>');
}

/// Ficha de una pila (pociones, éteres, materiales).
String stackTooltipMarkup(StackKind k, int count) {
  final m = k.material;
  final desc = switch (k) {
    StackKind.potion => 'Cura vida en batalla.',
    StackKind.ether => 'Recupera maná en batalla.',
    _ => m!.description,
  };
  return '<b style="color:#78e6dc">${_esc(k.label)}</b> x$count<br>'
      '${_c(_sky, m == null ? 'Consumible' : 'Material de fusión')} · '
      'máx. ${k.maxStack}<br>${_esc(desc)}';
}

/// Una línea para listas: nombre en su color + `Nv · tipo`.
String itemRowMarkup(ProgressionRules rules, ItemInstance it) {
  final w = rules.items.baseOf(it);
  return '${itemNameMarkup(rules, it)}<br>'
      '<small>${it.rarity.label} · ${w?.type ?? '?'} · Nv ${w?.level ?? 1}'
      '</small>';
}

/// Plural de una rareza para los lotes: `Comunes`, `Mágicos`...
String rarityPlural(Rarity r) => switch (r) {
      Rarity.comun => 'Comunes',
      Rarity.magico => 'Mágicos',
      Rarity.raro => 'Raros',
      Rarity.epico => 'Épicos',
      Rarity.legendario => 'Legendarios',
    };

/// Lo que se gana al desarmar o vender (`CraftResult`): `+₵N`,
/// `+2 Esquirla del Eco` y lo que puede salir. Texto plano.
String gainsText(
    {int credits = 0,
    Map<CraftMaterial, int> materials = const {},
    List<String> chances = const []}) {
  final parts = [
    if (credits > 0) '+₵$credits',
    for (final e in materials.entries) '+${e.value} ${e.key.label}',
  ];
  final sure = parts.isEmpty ? 'nada seguro' : parts.join(' · ');
  return chances.isEmpty ? sure : '$sure (puede salir: ${chances.join(', ')})';
}

/// Habilidad por id → nombre (o el id).
String skillName(ProgressionRules rules, String id) =>
    rules.catalog.skills[id]?.name ?? id;

/// La pasiva de [it] como quedaría con [forgeLevels] niveles de forja.
String? passiveAtMarkup(ProgressionRules rules, ItemInstance it, int forgeLevels) {
  final t = rules.crafting.passiveAt(it, forgeLevels);
  return t == null ? null : _c(kPassiveHex, _esc(t));
}

// ---------------------------------------------------------------------
// Ecos (docs/specs/ecos_atlas.md § 2)
// ---------------------------------------------------------------------

/// Turquesa de los Ecos.
const kEcoHex = '#5ae6d2';

/// Nombre de un Eco en el color de su rareza, con su tier.
String ecoNameMarkup(ProgressionRules rules, EcoItem e) =>
    '<b style="color:${rarityHex(e.rarity)}">'
    '${_esc(rules.ecos.displayName(e))}</b> ${_c(kEcoHex, 'T${e.tier}')}';

/// Ficha de un Eco: tier y nivel, zona, jefe, pisos, mods y lo que suman
/// al botín. [atlas] = efectos del Atlas de la sala (Potencia cambia el
/// bonus); [players] = jugadores en la sala (+10% cantidad por extra).
String ecoTooltipMarkup(ProgressionRules rules, EcoItem e,
    {AtlasEffects atlas = AtlasEffects.none, int players = 1}) {
  final eco = rules.ecos;
  final z = eco.zoneOf(e);
  final l = <String>[
    ecoNameMarkup(rules, e),
    '<span class="k">Eco ${e.rarity.label} · Tier ${e.tier} · '
        'monstruos nivel ${e.monsterLevel}</span>',
    'Zona: <b>${_esc(z?.name ?? '?')}</b> · '
        '${e.floors} piso${e.floors == 1 ? '' : 's'}',
    'Jefe: <b style="color:$_orange">${_esc(eco.bossName(e))}</b>',
  ];
  final cap = ecoModRange(e.rarity).$2;
  if (cap > 0 || e.mods.isNotEmpty) {
    l.add('<span class="k">Modificadores ${e.mods.length}/$cap</span>');
    for (final m in e.mods) {
      final d = kEcoMods[m.id];
      l.add('• ${_c(_red, _esc(EcoRules.modText(m)))}'
          '${d == null ? '' : ' ${_c(_dim, '(+${d.quantity}% cant. +${d.rarity}% rar.)')}'}');
    }
  }
  final b = EcoRules.lootBonus(e, atlas: atlas, players: players);
  l.add('Botín: ${_c(_green, '+${(b.quantity * 100).round()}% cantidad')} · '
      '${_c(_green, '+${(b.rarity * 100).round()}% rareza')}'
      '${players > 1 ? ' ${_c(_dim, '(con el grupo)')}' : ''}');
  l.add(_c(_dim, 'Se abre en el Portal del Eco (pueblo). Se consume al '
      'entrar, se complete o no.'));
  return l.join('<br>');
}
