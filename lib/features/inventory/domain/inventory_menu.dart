import '../../../game_engine/models/eco.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../../core/i18n/strings.dart';
import 'item_text.dart';

/// Buscador y menú de acciones del inventario (v0.9.7, docs/specs/panels.md
/// § "Inventario" y loot.md § 17.4). Dart puro: la pestaña solo dibuja.

/// Acciones del menú contextual, en el orden en que se muestran.
enum InventoryMenuAction {
  equip('Equipar', 'equipar'),
  compare('Comparar', 'comparar'),
  move('Mover', 'mover'),
  give('Dar a...', 'dar'),
  drop('Tirar', 'tirar'),
  salvage('Desarmar', 'desarmar'),
  sell('Vender', 'vender');

  const InventoryMenuAction(this.labelEs, this.verbEs);

  /// Spanish source text (the shown one comes from [label]).
  final String labelEs;
  final String verbEs;

  String get _id => switch (this) {
        InventoryMenuAction.equip => 'equip',
        InventoryMenuAction.compare => 'compare',
        InventoryMenuAction.move => 'move',
        InventoryMenuAction.give => 'give',
        InventoryMenuAction.drop => 'drop',
        InventoryMenuAction.salvage => 'salvage',
        InventoryMenuAction.sell => 'sell',
      };

  /// Menu label in the active language.
  String label(Strings s) => s.t('ui.inventory.menu.action.$_id');

  /// Infinitive for the reason (`No podés <verb> ...`).
  String verb(Strings s) => s.t('ui.inventory.menu.verb.$_id');
}

/// El motivo corto de las reglas (`Equipada`, `Arma inicial`, `No en
/// batalla`...) como una línea para el menú: "No podés desarmar el arma
/// equipada", "No podés dársela a otro jugador: está equipada".
/// Los motivos de contexto (`No en batalla`, `No hay compañeros en la
/// sala`, `Solo en el lobby o en el campo`) quedan como vienen.
String inventoryReasonLine(Strings s, InventoryMenuAction a, String reason) {
  final r = reason.trim();
  if (r == 'Equipada' || r == 'Está equipada') {
    return switch (a) {
      InventoryMenuAction.give => s.t('ui.inventory.menu.reason.give_equipped'),
      InventoryMenuAction.equip =>
        s.t('ui.inventory.menu.reason.already_equipped'),
      _ => s.t('ui.inventory.menu.reason.equipped', {'verb': a.verb(s)}),
    };
  }
  if (r == 'Arma inicial') {
    return a == InventoryMenuAction.give
        ? s.t('ui.inventory.menu.reason.give_starter')
        : s.t('ui.inventory.menu.reason.starter', {'verb': a.verb(s)});
  }
  if (a == InventoryMenuAction.equip &&
      (r.startsWith('Requisitos') || r.startsWith('Nivel'))) {
    return s.t('ui.inventory.menu.reason.cannot_equip', {'reason': r});
  }
  return r;
}

/// Motivo corto para la misma línea del menú (v0.9.9): "equipada",
/// "arma inicial", "sin compañeros"... El completo
/// ([inventoryReasonLine]) va en el tooltip de la fila.
String inventoryReasonShort(Strings s, InventoryMenuAction a, String reason) {
  final r = reason.trim();
  if (r == 'Equipada' || r == 'Está equipada') {
    return s.t(a == InventoryMenuAction.equip
        ? 'ui.inventory.menu.short.already_equipped'
        : 'ui.inventory.menu.short.equipped');
  }
  if (r == 'Arma inicial') return s.t('ui.inventory.menu.short.starter');
  if (r == 'No hay compañeros en la sala' ||
      r == s.t('ui.inventory.menu.reason.no_mates')) {
    return s.t('ui.inventory.menu.short.no_mates');
  }
  if (r == 'No en batalla') return s.t('ui.inventory.menu.short.in_battle');
  if (r.length <= 24) return r;
  final cut = r.indexOf(RegExp(r'[:.]'));
  final head = cut > 0 ? r.substring(0, cut) : r;
  // Whole clause, never cut with an ellipsis (ui_style.md, v0.36.1).
  return head;
}

/// Minúsculas sin tildes (para buscar).
String foldSearch(String s) {
  const from = 'áéíóúüñ';
  const to = 'aeiouun';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString();
}

final _tags = RegExp(r'<[^>]*>');

/// Texto plano de un markup (sin etiquetas ni entidades comunes).
String plainText(String markup) => markup
    .replaceAll(_tags, ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'");

/// Lo que mira el buscador de un arma: nombre, base, tipo, rareza, mods,
/// pasiva y habilidades.
String itemSearchText(ProgressionRules rules, ItemInstance it) {
  final items = rules.items;
  final w = items.baseOf(it);
  return foldSearch([
    items.displayName(it),
    w?.name ?? it.baseId,
    w?.type ?? '',
    it.rarity.label,
    for (final a in it.affixes) plainText(affixMarkup(rules, a, on: it)),
    items.passiveText(it) ?? '',
    for (final id in items.skillsOf(it)) rules.catalog.skills[id]?.name ?? '',
  ].join(' '));
}

/// ¿[it] / [eco] coincide con [query]? Todas las palabras tienen que
/// aparecer (en cualquier orden). Vacío = todo coincide.
bool inventoryMatches(ProgressionRules rules, String query,
    {ItemInstance? item, EcoItem? eco, String? label}) {
  final words = foldSearch(query)
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return true;
  final text = item != null
      ? itemSearchText(rules, item)
      : eco != null
          ? foldSearch('${rules.ecos.fullName(eco)} eco ${eco.rarity.label}')
          : foldSearch(label ?? '');
  return words.every(text.contains);
}
