import '../../../core/text/plain_text.dart';
import '../../../core/text/text_detail.dart';
import '../../../game_engine/data/eco_catalog.dart';
import '../../../game_engine/data/weapon_elements_catalog.dart';
import '../../../game_engine/models/atlas.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/eco.dart';
import '../../../game_engine/models/elements.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/loot.dart';
import '../../../game_engine/models/player_state.dart';
import '../../../game_engine/models/upgrade_stat.dart';
import '../../../game_engine/models/weapon.dart';
import '../../../game_engine/rules/eco_rules.dart';
import '../../../game_engine/rules/item_rules.dart';
import '../../../game_engine/rules/loot_filter_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../../game_engine/rules/weapon_weight.dart';
import 'battle_impact.dart';
import 'skill_tip.dart';
import 'weapon_text.dart';

/// Textos de objetos del loot v2 (ficha / tooltip, requisitos, mods) en
/// el markup del prototipo (`ProtoMarkup`). Ver docs/specs/panels.md §
/// "Ficha de objeto".

const _green = '#7bed9f';
const _red = '#ff6b81';
const _sky = '#9fb4ff';
const _orange = '#ff9f43';
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

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

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
String affixMarkup(ProgressionRules rules, AffixRoll a, {ItemInstance? on}) =>
    _c(a.fixed ? _orange : kModHex,
        _esc(modShort(rules.items.affixText(a, on: on))));

/// Texto de un mod (afijo, implícito, pasiva del arma) según TEXTOS:
/// en RESUMIDO sin abreviaturas ni fórmulas (ui_minimal.md § 8).
String modShort(String text) => TextDetail.isSummary
    ? plainShort(text, sentence: text.trimRight().endsWith('.'))
    : text;

/// Nombre visible del lado de un mod (loot.md § "Prefijos y sufijos").
String affixSideLabel(AffixSlot s) =>
    s == AffixSlot.prefix ? 'PREFIJO' : 'SUFIJO';

/// Qué tipo de mod va en cada lado, en palabras del jugador.
String affixSideKind(AffixSlot s) =>
    s == AffixSlot.prefix ? 'ataque' : 'atributos y defensa';

/// Explicación corta de prefijos y sufijos (tooltip de las etiquetas
/// `PREFIJOS` / `SUFIJOS` en fichas y en la forja). [r]: con la rareza,
/// cuántos entran de cada lado.
String affixSidesHelp([Rarity? r]) {
  final cupo = r == null || r.maxMods == 0
      ? 'Cada arma tiene lugar para la mitad de sus mods de cada lado.'
      : 'Un arma ${r.label} lleva hasta ${r.maxMods} mods: hasta '
          '${r.affixSideCap} prefijos y hasta ${r.affixSideCap} sufijos.';
  return '${_c(_sky, 'Prefijos y sufijos')}<br>'
      '${_c(_sky, 'PREFIJO')}: mod de ataque (daño, magia, crítico, '
      'velocidad, estados).<br>'
      '${_c(_sky, 'SUFIJO')}: mod de atributos o defensa (FUE, VIT, HP, '
      'MP, defensa, robo de vida...).<br>'
      '$cupo<br>'
      'Al agregar o traer un mod tiene que quedar lugar de su lado: si los '
      'prefijos están llenos, solo entra un sufijo (y al revés).';
}

/// Mods de [it] agrupados por lado: una línea de título `PREFIJOS
/// (ataque) n/tope` y sus mods, lo mismo con `SUFIJOS`. Los que no tienen
/// lado conocido van al final, sin título. [line] arma cada mod (por
/// defecto `• mod`; la forja marca nuevos y quitados).
List<String> affixGroupsMarkup(ProgressionRules rules, ItemInstance it,
    {String Function(AffixRoll a)? line}) {
  final items = rules.items;
  String mod(AffixRoll a) =>
      line?.call(a) ?? '• ${affixMarkup(rules, a, on: it)}';
  final cap = it.rarity.affixSideCap;
  final out = <String>[];
  for (final side in AffixSlot.values) {
    final group = [
      for (final a in it.affixes)
        if (items.affixOf(a)?.slot == side) a
    ];
    if (group.isEmpty && (it.rarity.maxMods == 0 || cap == 0)) continue;
    out.add('${_c(_sky, '${affixSideLabel(side)}S')} '
        '${_c(_dim, '(${affixSideKind(side)}) ${group.length}/$cap')}');
    for (final a in group) {
      out.add(mod(a));
      if (affixHelpMarkup(rules, a) case final h?) out.add('  $h');
    }
  }
  for (final a in it.affixes) {
    if (items.affixOf(a) != null) continue;
    out.add(mod(a));
  }
  return out;
}

/// Línea de ayuda debajo del afijo Quebrantador en una ficha.
String? affixHelpMarkup(ProgressionRules rules, AffixRoll a) =>
    rules.items.affixOf(a)?.stat == ModStat.breakSkill
        ? _c(_dim, _esc(ItemRules.breakSkillHelp))
        : null;

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
  // ULT libres del arma (ultimates_v2.md § 2.1): el arma no muestra ULT.
  return names.isEmpty ? '—' : names.join(' · ');
}

/// Una línea por habilidad (`• Nombre (8 MP · Físico): efecto · ...`, las
/// trasladadas con `(trasladada)`). La ULT ya no es del arma.
List<String> itemSkillLinesMarkup(ProgressionRules rules, ItemInstance it,
    {DerivedStats? stats}) {
  final cat = rules.catalog;
  final w = cat.weapons[it.baseId];
  return [
    for (final id in rules.items.skillsOf(it))
      if (cat.skills[id] case final s?)
        '• ${skillOneLineMarkup(s, stats: stats)}'
            '${(w?.skillIds.contains(id) ?? false) ? '' : ' ${_c(_orange, '(trasladada)')}'}',
  ];
}

/// Línea plegable dentro de una sección de tip: `head` a la vista y
/// `detail` en su propio ▸ (lo dibuja `RetroTipFold`). Separadores
/// U+0001 (cabeza / detalle) y U+0002 (saltos del detalle).
/// Color de cada elemento en los textos (mismos tonos que el aura).
String elementHex(GameElement e) => switch (e) {
      GameElement.fisico => '#dfe6e9',
      GameElement.fuego => '#ff7b29',
      GameElement.hielo => '#74b9ff',
      GameElement.veneno => '#7bed9f',
      GameElement.sagrado => '#fff3b0',
      GameElement.agua => '#3fa9f5',
      GameElement.electro => '#c39bff',
    };

/// Elemento de base como pasiva fija (weapon_identity.md § 4): `null` sin
/// elemento.
String? weaponElementMarkup(ItemInstance it) {
  final e = weaponElementOf(it);
  if (e == null) return null;
  final hex = elementHex(e);
  const every = kWeaponElementHitsPerStack;
  final pct = (kWeaponElementSynergy * 100).round();
  final name = _esc(e.label);
  return '${_c(hex, '<b style="color:$hex">Elemento $name</b>')} '
      '${_c(_dim, '(fijo)')} '
      '${_c(hex, 'Ataque básico de $name: +1 pila cada $every golpes · '
          '+$pct % a habilidades de $name')}';
}

String tipSubFold(String head, String detail) =>
    '$head\u0001${detail.replaceAll('<br>', '\u0002')}';

/// Habilidades del tooltip plegado: una línea cada una y el detalle en
/// su propio ▸ (ui_style.md § "Tooltips cortos").
List<String> _skillFolds(
    ProgressionRules rules, ItemInstance it, DerivedStats? stats) {
  final cat = rules.catalog;
  final w = cat.weapons[it.baseId];
  String one((String, String) p, [String tail = '']) =>
      p.$2.isEmpty ? '• ${p.$1}$tail' : tipSubFold('${p.$1}$tail', p.$2);
  return [
    for (final id in rules.items.skillsOf(it))
      if (cat.skills[id] case final s?)
        one(
            skillShortLineMarkup(s, stats: stats),
            (w?.skillIds.contains(id) ?? false)
                ? ''
                : ' ${_c(_orange, '(trasladada)')}'),
  ];
}

/// `Forja +3/8 (Poder 2, Crítico 1)`.
String forgeText(ItemInstance it) {
  final f = it.forge;
  final parts = [
    for (final s in UpgradeStat.values)
      if (f.level(s) > 0) '${s.label} ${f.level(s)}',
  ];
  return 'Forja +${it.forgeLevel}/${ItemRules.forgeCapOf(it)}'
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
  bool skills = true,
  bool skillDetails = false,
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
  // Travesía: las armas no piden nivel ni atributos (roguelike.md § 12.2).
  if (w != null && !rules.ignoreRequirements) {
    l.add(requirementsLineMarkup(w, level, attributes));
  }
  if (stats != null) {
    l.add('ATQ <b>${stats.attack}</b> · MAG <b>${stats.magic}</b>'
        '${_c(_dim, ' (con tus atributos)')}');
  }
  // Peso: siempre, también las ligeras (panels.md § "Peso del arma").
  if (w != null) l.addAll(weightLinesMarkup(rules, w, stats: stats));
  final implicit = w == null ? const <ItemMod>[] : items.implicitMods(w);
  if (implicit.isNotEmpty) {
    l.add('<span class="k">Implícito:</span> '
        '${implicit.map((m) => _esc(modShort(m.text))).join(', ')}');
  }
  if (it.rarity.maxMods > 0 || it.affixes.isNotEmpty) {
    l.add('<span class="k">Mods ${it.modCount}/${it.rarity.maxMods}</span>');
    l.addAll(affixGroupsMarkup(rules, it));
  }
  // El mod "ULT: <nombre>" ya no se muestra: la ULT se aprende al
  // conseguir el arma (ultimates_v2.md § 2.1).
  if (weaponElementMarkup(it) case final el?) l.add(el);
  final passive = items.passiveText(it);
  if (passive != null) {
    l.add('${_c(kPassiveHex, '<b style="color:$kPassiveHex">Pasiva</b>')} '
        '${_c(kPassiveHex, _esc(modShort(passive)))}');
  }
  if (it.forgeLevel > 0 || ItemRules.forgeCapOf(it) > 0) l.add(forgeText(it));
  // [skillDetails]: qué hace cada una (el texto de la batalla, en una
  // línea; tooltips de la grilla). [skills] `false`: las dibuja el que
  // llama (fichas con `SkillChips`).
  if (skills && skillDetails) {
    l.add('<span class="k">Habilidades:</span>');
    l.addAll(itemSkillLinesMarkup(rules, it, stats: stats));
  } else if (skills) {
    l.add('<span class="k">Habilidades:</span> ${itemSkillsMarkup(rules, it)}');
  }
  final flavor = items.uniqueOf(it)?.flavor;
  if (flavor != null && flavor.isNotEmpty) l.add(_c(_dim, _esc(flavor)));
  return l.join('<br>');
}

/// Ficha corta de un arma (tooltips v0.9.7, ui_style.md § "Tooltips
/// cortos"): [summary] con lo esencial (nombre, rareza · tipo · nivel,
/// requisitos, ATQ / MAG y una línea `Mods 2/4 · Pasiva · 3 habilidades`)
/// y [sections] plegables (`Mods`, `Pasiva`, `Habilidades`, `Peso y
/// forja`, `Historia`) con el **mismo** texto que [itemTooltipMarkup]:
/// nada se pierde, solo se pliega.
({String summary, List<(String, String)> sections}) itemTipParts(
  ProgressionRules rules,
  ItemInstance it, {
  required int level,
  required PlayerAttributes attributes,
  DerivedStats? stats,
  bool equipped = false,
}) {
  // TEXTOS en RESUMIDO (ui_minimal.md § 8.4): ficha corta de verdad y
  // todo lo demás en MÁS DETALLE.
  if (TextDetail.isSummary) {
    return itemTipSummaryParts(rules, it,
        level: level, attributes: attributes, stats: stats, equipped: equipped);
  }
  final items = rules.items;
  final w = items.baseOf(it);
  final base = w?.name ?? it.baseId;
  final generated = it.rarity.index >= Rarity.raro.index;
  final head = <String>[
    itemNameMarkup(rules, it),
    '<span class="k">${it.rarity.label} · ${w?.type ?? '?'} · '
        'nivel de objeto ${it.itemLevel}</span>'
        '${generated ? ' ${_c(_dim, _esc(base))}' : ''}'
        '${equipped ? ' ${_c(_orange, 'EQUIPADA')}' : ''}',
    if (w != null && !rules.ignoreRequirements)
      requirementsLineMarkup(w, level, attributes),
    if (stats != null)
      'ATQ <b>${stats.attack}</b> · MAG <b>${stats.magic}</b>'
          '${_c(_dim, ' (con tus atributos)')}',
  ];
  // Mods (implícito, afijos y ULT especial).
  final implicit = w == null ? const <ItemMod>[] : items.implicitMods(w);
  final mods = <String>[
    if (implicit.isNotEmpty)
      '<span class="k">Implícito:</span> '
          '${implicit.map((m) => _esc(modShort(m.text))).join(', ')}',
    ...affixGroupsMarkup(rules, it),
  ];
  final passive = items.passiveText(it);
  final skills = itemSkillLinesMarkup(rules, it, stats: stats);
  final weight = <String>[
    if (w != null) ...weightLinesMarkup(rules, w, stats: stats),
    if (it.forgeLevel > 0 || ItemRules.forgeCapOf(it) > 0) forgeText(it),
  ];
  final flavor = items.uniqueOf(it)?.flavor;
  final hasMods = it.rarity.maxMods > 0 || it.affixes.isNotEmpty;
  final element = weaponElementMarkup(it);
  final el = weaponElementOf(it);
  final counts = [
    if (hasMods) 'Mods ${it.modCount}/${it.rarity.maxMods}',
    if (el != null) _c(elementHex(el), _esc(el.label)),
    if (passive != null) _c(kPassiveHex, 'Pasiva'),
    '${skills.length} ${skills.length == 1 ? 'habilidad' : 'habilidades'}',
    if (w != null) weightClassOf(w).label,
  ];
  head.add(_c(_sky, counts.join(' · ')));
  return (
    summary: head.join('<br>'),
    sections: [
      ('Mods', mods.join('<br>')),
      if (element != null) ('Elemento', element),
      if (passive != null) ('Pasiva', _c(kPassiveHex, _esc(modShort(passive)))),
      ('Habilidades', _skillFolds(rules, it, stats).join('<br>')),
      ('Peso y forja', weight.join('<br>')),
      if (flavor != null && flavor.isNotEmpty)
        ('Historia', _c(_dim, _esc(flavor))),
    ],
  );
}

/// Título del plegable con la ficha completa en RESUMIDO.
const kMoreDetailTitle = 'MÁS DETALLE';

/// Rol del arma en una línea: `Espada pesada · daño físico`.
String weaponRoleLine(WeaponDef w, ItemInstance it) {
  final el = weaponElementOf(it);
  final kind = w.mag != null && w.mag!.base > w.atk.base
      ? 'daño mágico'
      : 'daño ${(el ?? GameElement.fisico).label.toLowerCase()}';
  final t = w.type.isEmpty ? '?' : w.type[0].toUpperCase() + w.type.substring(1);
  return '$t ${weightClassOf(w).label.toLowerCase()} · $kind';
}

/// Ficha RESUMIDA de un arma (TEXTOS, ui_minimal.md § 8.4): nombre,
/// rareza y tipo, rol en una línea, stat principal, cada mod en una línea
/// corta, implícito y pasiva cortos. La ficha DETALLADA entera va en el
/// único plegable [kMoreDetailTitle].
({String summary, List<(String, String)> sections}) itemTipSummaryParts(
  ProgressionRules rules,
  ItemInstance it, {
  required int level,
  required PlayerAttributes attributes,
  DerivedStats? stats,
  bool equipped = false,
}) {
  final items = rules.items;
  final w = items.baseOf(it);
  String short(String t) => _esc(plainShort(t, sentence: false));
  final l = <String>[
    itemNameMarkup(rules, it),
    '<span class="k">${it.rarity.label}</span>'
        '${equipped ? ' ${_c(_orange, 'EQUIPADA')}' : ''}',
    if (w != null) _c(_sky, _esc(weaponRoleLine(w, it))),
    if (stats != null)
      'ATQ <b>${stats.attack}</b> · MAG <b>${stats.magic}</b>'
    else if (w != null)
      (w.mag != null && w.mag!.base > w.atk.base)
          ? 'MAG base <b>${w.mag!.base.round()}</b>'
          : 'ATQ base <b>${w.atk.base.round()}</b>',
    if (w != null && !rules.ignoreRequirements &&
        missingRequirements(w, attributes).isNotEmpty)
      requirementsLineMarkup(w, level, attributes),
  ];
  final implicit = w == null ? const <ItemMod>[] : items.implicitMods(w);
  for (final m in implicit) {
    l.add(_c(_dim, '• ${short(m.text)}'));
  }
  for (final a in it.affixes) {
    l.add(_c(a.fixed ? _orange : kModHex,
        '• ${short(items.affixText(a, on: it))}'));
  }
  final passive = items.passiveText(it);
  if (passive != null) {
    l.add(_c(kPassiveHex,
        'Pasiva: ${_esc(plainShort(passive, maxChars: 40, sentence: false))}'));
  }
  final full = TextDetail.run(
      TextDetail.full,
      () => itemTooltipMarkup(rules, it,
          level: level,
          attributes: attributes,
          stats: stats,
          equipped: equipped,
          skillDetails: true));
  return (summary: l.join('<br>'), sections: [(kMoreDetailTitle, full)]);
}

// ---------------------------------------------------------------------
// Peso (docs/specs/loot.md § 1.1, panels.md § "Peso del arma")
// ---------------------------------------------------------------------

/// Color de cada categoría de peso: Ligera verde, Media amarilla,
/// Pesada naranja.
String weightClassHex(WeightClass c) => switch (c) {
      WeightClass.ligera => _green,
      WeightClass.media => '#ffd166',
      WeightClass.pesada => _orange,
    };

/// Etiqueta corta en su color (`Pesada`), para filas de listas.
String weightTagMarkup(WeaponDef w) {
  final c = weightClassOf(w);
  return _c(weightClassHex(c), c.label);
}

/// Qué cambia por la categoría (sin el nombre): `sin penalización de
/// velocidad` / `−0.5 vel. · algo más lenta a cambio de poder` /
/// `−1.3 vel. · suele dar más ATQ`.
String weightTradeoffText(WeaponDef w) => TextDetail.isSummary
    ? switch (weightClassOf(w)) {
        WeightClass.ligera => 'no te frena',
        WeightClass.media => 'un poco más lenta, más poder',
        WeightClass.pesada => 'más lenta, más ataque',
      }
    : switch (weightClassOf(w)) {
        WeightClass.ligera => 'sin penalización de velocidad',
        WeightClass.media =>
          '−${fmtNum(w.weight)} vel. · algo más lenta a cambio de poder',
        WeightClass.pesada => '−${fmtNum(w.weight)} vel. · suele dar más ATQ',
      };

/// Líneas del peso de la ficha: `Ligera · sin penalización de velocidad`
/// o `Pesada: −1.3 vel. · suele dar más ATQ`, y con [stats] (los de quien
/// mira **con** esta arma) lo que le cuesta en turnos.
List<String> weightLinesMarkup(ProgressionRules rules, WeaponDef w,
    {DerivedStats? stats}) {
  final c = weightClassOf(w);
  final tag = '<b style="color:${weightClassHex(c)}">${c.label}</b>';
  final head = c == WeightClass.ligera
      ? '$tag ${_c(_dim, '· ${weightTradeoffText(w)}')}'
      : '$tag: ${_c(_dim, weightTradeoffText(w))}';
  final turn = stats == null ? null : weightTurnLine(rules, stats, w.weight);
  return [head, if (turn != null) _c(_dim, turn)];
}

/// Ficha de una pila (pociones, éteres, materiales).
String stackTooltipMarkup(StackKind k, int count) {
  final m = k.material;
  final desc = switch (k) {
    StackKind.potion => 'Cura vida (también fuera de batalla).',
    StackKind.ether => 'Recupera maná (también fuera de batalla).',
    StackKind.aether =>
      'Revive a un aliado caído con toda la vida (solo en batalla).',
    _ => m!.description,
  };
  return '<b style="color:#78e6dc">${_esc(k.label)}</b> x$count<br>'
      '${_c(_sky, m == null ? 'Consumible' : 'Material de fusión')} · '
      'máx. ${k.maxStack}<br>${_esc(modShort(desc))}';
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
  if (parts.isEmpty) {
    return chances.isEmpty
        ? 'sin materiales'
        : 'puede salir: ${chances.join(', ')}';
  }
  final sure = parts.join(' · ');
  return chances.isEmpty ? sure : '$sure (puede salir: ${chances.join(', ')})';
}

/// Habilidad por id → nombre (o el id).
String skillName(ProgressionRules rules, String id) =>
    rules.catalog.skills[id]?.name ?? id;

/// La pasiva de [it] como quedaría con [forgeLevels] niveles de forja.
String? passiveAtMarkup(
    ProgressionRules rules, ItemInstance it, int forgeLevels) {
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
  l.add(_c(
      _dim,
      'Se abre en el Portal del Eco (pueblo). Se consume al '
      'entrar, se complete o no.'));
  return l.join('<br>');
}
