import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../game_engine/rules/craft_rules.dart';
import '../domain/item_text.dart';
import 'shop_sections.dart';

/// Operación de la mesa de fusión: botón, verbo del botón de confirmar
/// y línea "qué hace" (con las reglas de loot.md § 16 y § 20).
extension CraftOpText on CraftOp {
  String get label => switch (this) {
        CraftOp.transferAffix => 'TRASLADAR MOD',
        CraftOp.transferPassive => 'TRASLADAR PASIVA',
        CraftOp.transferSkill => 'TRASLADAR HABILIDAD',
        CraftOp.removeAffix => 'QUITAR MOD',
        CraftOp.addAffix => 'AGREGAR MOD',
        CraftOp.reroll => 'RE-TIRAR',
        CraftOp.upgradeRarity => 'SUBIR RAREZA',
      };

  String get verb => switch (this) {
        CraftOp.transferAffix => 'TRASLADAR MOD',
        CraftOp.transferPassive => 'TRASLADAR PASIVA',
        CraftOp.transferSkill => 'TRASLADAR HABILIDAD',
        CraftOp.removeAffix => 'QUITAR MOD',
        CraftOp.addAffix => 'USAR CRISTAL',
        CraftOp.reroll => 'USAR ESQUIRLA',
        CraftOp.upgradeRarity => 'USAR PRISMA',
      };

  String get hint => switch (this) {
        CraftOp.transferAffix =>
          'Pasa un mod del arma origen (que se destruye) al destino si tiene '
              'cupo: Común 0 · Mágico 2 · Raro 4 · Épico/Legendario 6. Los mods '
              'fijos de un legendario no se trasladan.',
        CraftOp.transferPassive =>
          'Pasa la pasiva de un Épico (que se destruye) a otra arma Épica: '
              'reemplaza la suya y conserva el nivel base. Las pasivas únicas '
              'no se trasladan.',
        CraftOp.transferSkill =>
          'El destino aprende una habilidad del arma origen (que se '
              'destruye). Cupos: 1 hasta Raro, 2 en Épico y Legendario; lleno, '
              'la nueva reemplaza a la más vieja.',
        CraftOp.removeAffix =>
          'Quita un mod para hacer lugar. Los mods fijos de un legendario no '
              'se quitan.',
        CraftOp.addAffix =>
          '1 Cristal de Era: agrega un mod al azar del nivel del objeto si hay '
              'lugar. Un arma Común no lleva mods (súbele la rareza).',
        CraftOp.reroll =>
          '1 Esquirla del Eco: valores nuevos para cada mod dentro de su tier '
              '(o del rango del único).',
        CraftOp.upgradeRarity =>
          'Prisma Roto: Común → Mágico (1) → Raro (2) → Épico (4). Agrega los '
              'mods que falten y, al llegar a Épico, nombre y pasiva. '
              'Legendario solo se encuentra.',
      };

  bool get needsSource =>
      this == CraftOp.transferAffix ||
      this == CraftOp.transferPassive ||
      this == CraftOp.transferSkill;

  bool get isRandom =>
      this == CraftOp.addAffix ||
      this == CraftOp.reroll ||
      this == CraftOp.upgradeRarity;
}

/// Mesa de fusión libre (pestaña FUSIÓN): operación, arma destino, arma
/// a sacrificar y elemento, con la vista previa del `CraftResult`
/// (vista previa = resultado) antes de confirmar. Ver
/// docs/specs/panels.md § "Armería" (loot v2).
class CraftBench extends StatefulWidget {
  const CraftBench({super.key, required this.shop, this.initialOp});

  final ShopContext shop;
  final CraftOp? initialOp;

  @override
  State<CraftBench> createState() => _CraftBenchState();
}

class _CraftBenchState extends State<CraftBench> {
  late CraftOp _op = widget.initialOp ?? CraftOp.transferAffix;
  String? _target, _source;
  int _pick = 0;

  /// La destino antes de la última operación aleatoria (para mostrar qué
  /// salió).
  ItemInstance? _lastBefore;

  void _setOp(CraftOp op) => setState(() {
        _op = op;
        _pick = 0;
        _lastBefore = null;
      });

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final p = shop.profile;
    final rules = shop.rules;
    final items = shop.owned;
    if (items.isEmpty) return const Text('No tienes armas.');
    final target =
        items.firstWhere((i) => i.uid == _target, orElse: () => items.first);
    _target = target.uid;
    final sources = shop.guards.sacrifices(p, target.uid);
    ItemInstance? source;
    if (_op.needsSource) {
      source = sources.where((i) => i.uid == _source).firstOrNull ??
          sources.firstOrNull;
      _source = source?.uid;
    }
    // Elementos elegibles (mods o habilidades).
    final List<String> picks = switch (_op) {
      CraftOp.transferAffix => [
          for (final a in source?.affixes ?? const <AffixRoll>[])
            affixMarkup(rules, a),
        ],
      CraftOp.transferSkill => [
          for (final id in source == null
              ? const <String>[]
              : rules.items.skillsOf(source))
            protoEsc(skillName(rules, id)),
        ],
      CraftOp.removeAffix => [
          for (final a in target.affixes) affixMarkup(rules, a),
        ],
      _ => const [],
    };
    if (_pick >= picks.length) _pick = 0;
    final skillId = _op == CraftOp.transferSkill && source != null
        ? rules.items.skillsOf(source).elementAtOrNull(_pick)
        : null;
    final action = CraftAction(_op, target.uid,
        sourceUid: source?.uid, index: _pick, skillId: skillId);
    final r = shop.guards.craftPreview(p, action);
    final reason = shop.guards.craft(p, action);

    Widget row(String key, String markup, bool sel, VoidCallback onTap,
            {Widget? trailing}) =>
        PanelListItem(
          key: ValueKey(key),
          selected: sel,
          onTap: () => setState(onTap),
          trailing: trailing,
          child: ProtoText(markup),
        );

    final mats = [
      for (final m in CraftMaterial.values)
        '${m.label.split(' ').first} <b>x${p.material(m)}</b>',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final op in CraftOp.values)
                    PanelButton(op.label,
                        key: ValueKey('craft-op-${op.name}'),
                        selected: op == _op,
                        accent: op == _op ? ProtoColors.gold : null,
                        onPressed: () => _setOp(op)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ProtoText(mats, key: const ValueKey('craft-materials')),
          ],
        ),
        const SizedBox(height: 6),
        PanelHint(_op.hint),
        Expanded(
          child: PanelSplit(
            list: [
              const ListHeader('1. Arma destino'),
              for (final it in items)
                row('craft-target-${it.uid}', itemRowMarkup(rules, it),
                    it.uid == target.uid, () {
                  _target = it.uid;
                  _pick = 0;
                  _lastBefore = null;
                },
                    trailing: it.uid == p.equippedUid
                        ? const Text('EQUIPADA',
                            style: TextStyle(color: ProtoColors.gold))
                        : null),
              if (_op.needsSource) ...[
                const ListHeader('2. Arma a sacrificar (se destruye)'),
                if (sources.isEmpty)
                  Text(
                      retroText('(no hay armas: no puede ser la equipada ni '
                          'la última arma inicial)'),
                      style: const TextStyle(color: ProtoColors.dim)),
                for (final it in sources)
                  row('craft-source-${it.uid}', itemRowMarkup(rules, it),
                      it.uid == source?.uid, () {
                    _source = it.uid;
                    _pick = 0;
                  }),
              ],
              if (_op == CraftOp.transferAffix || _op == CraftOp.transferSkill)
                ListHeader(_op == CraftOp.transferAffix
                    ? '3. Mod a trasladar'
                    : '3. Habilidad a trasladar'),
              if (_op == CraftOp.removeAffix) const ListHeader('2. Mod a quitar'),
              if ((_op == CraftOp.transferAffix ||
                      _op == CraftOp.removeAffix) &&
                  picks.isEmpty &&
                  (_op == CraftOp.removeAffix || source != null))
                Text(retroText('(no tiene mods)'),
                    style: const TextStyle(color: ProtoColors.dim)),
              for (var i = 0; i < picks.length; i++)
                row('craft-pick-$i', picks[i], i == _pick, () => _pick = i),
            ],
            detail: PanelDetail(
              footer: [
                if (r.credits > 0 || r.materials.isNotEmpty)
                  ProtoText(_costMarkup(r, p.credits, p.material)),
                PanelButton(_op.verb,
                    key: const ValueKey('craft-confirm'),
                    accent: ProtoColors.green,
                    reason: reason,
                    onPressed: () {
                      final before = target;
                      if (shop.controller.craft(action)) {
                        setState(() {
                          _lastBefore = _op.isRandom ? before : null;
                          if (_op.needsSource) _source = null;
                          _pick = 0;
                        });
                      }
                    }),
              ],
              children: _preview(target, r),
            ),
          ),
        ),
      ],
    );
  }

  String _costMarkup(CraftResult r, int credits, int Function(CraftMaterial) have) {
    final parts = [
      if (r.credits > 0) 'Costo <b>₵${r.credits}</b>',
      for (final e in r.materials.entries)
        '${e.value} ${e.key.label} (tienes ${have(e.key)})',
    ];
    return parts.join(' + ');
  }

  List<Widget> _preview(ItemInstance target, CraftResult r) {
    final rules = widget.shop.rules;
    final after = r.after;
    final out = <Widget>[
      const Text('RESULTADO', style: TextStyle(color: ProtoColors.gold)),
      const SizedBox(height: 4),
    ];
    final last = _lastBefore;
    if (last != null && last.uid == target.uid && last != target) {
      out.add(ProtoText(
          key: const ValueKey('craft-last'),
          '${protoColor(ProtoColors.green, '¡Listo! Salió:')} '
          '${_diffMods(last, target)}'));
      out.add(const SizedBox(height: 6));
    }
    final name = after == null || rules.items.displayName(after) ==
            rules.items.displayName(target)
        ? itemNameMarkup(rules, target)
        : '${itemNameMarkup(rules, target)} → ${itemNameMarkup(rules, after)}';
    out.add(ProtoText(name, key: const ValueKey('craft-name')));
    if (after != null && after.rarity != target.rarity) {
      out.add(ProtoText('Rareza ${target.rarity.label} → '
          '<b style="color:${rarityHex(after.rarity)}">${after.rarity.label}</b>'));
    }
    if (r.error != null && r.before == null) {
      out.add(const SizedBox(height: 6));
      out.add(ProtoText(
          key: const ValueKey('craft-error'),
          protoColor(ProtoColors.red, 'No se puede: ${protoEsc(r.error!)}')));
    }
    // Mods.
    final shown = after ?? target;
    out.add(const SizedBox(height: 6));
    out.add(ProtoText(
        key: const ValueKey('craft-mods-title'),
        '<span class="k">Mods ${shown.modCount}/${shown.rarity.maxMods}'
        ' (prefijos ${rules.items.prefixCount(shown)}/${shown.rarity.affixSideCap}'
        ' · sufijos ${rules.items.suffixCount(shown)}/${shown.rarity.affixSideCap})</span>'));
    out.add(ProtoText(
        key: const ValueKey('craft-mods'),
        after == null ? _modList(target) : _diffMods(target, after)));
    // Pasiva.
    final pBefore = rules.items.passiveText(target);
    final pAfter = after == null ? pBefore : rules.items.passiveText(after);
    if (pBefore != null || pAfter != null) {
      out.add(const SizedBox(height: 6));
      out.add(ProtoText(
          key: const ValueKey('craft-passive'),
          pBefore == pAfter
              ? 'Pasiva: <span style="color:$kPassiveHex">${protoEsc(pBefore!)}</span>'
              : 'Pasiva: ${protoColor(ProtoColors.dim, protoEsc(pBefore ?? '—'))} → '
                  '<b style="color:$kPassiveHex">${protoEsc(pAfter ?? '—')}</b>'));
    }
    // Habilidades.
    final sBefore = rules.items.skillsOf(target);
    final sAfter = after == null ? sBefore : rules.items.skillsOf(after);
    out.add(const SizedBox(height: 6));
    out.add(ProtoText(
        key: const ValueKey('craft-skills'),
        'Habilidades (trasladadas ${(after ?? target).extraSkills.length}/'
        '${(after ?? target).rarity.skillSlots}): ${[
          for (final id in sAfter)
            sBefore.contains(id)
                ? protoEsc(skillName(rules, id))
                : protoColor(ProtoColors.green,
                    '<b>${protoEsc(skillName(rules, id))}</b> (nueva)'),
        ].join(' · ')}'));
    if (r.replaced != null) {
      out.add(ProtoText(
          key: const ValueKey('craft-replaced'),
          protoColor(ProtoColors.orange,
              'Reemplaza ${protoEsc(r.replaced!)} (se pierde)')));
    }
    if (r.outcomes.isNotEmpty) {
      out.add(const SizedBox(height: 6));
      out.add(ProtoText(
          key: const ValueKey('craft-outcomes'),
          'Puede salir: ${protoColor(ProtoColors.sky, protoEsc(r.outcomes.join(', ')))}'));
    }
    if (r.consumed.isNotEmpty) {
      final p = widget.shop.profile;
      final lost = [
        for (final uid in r.consumed)
          if (p.itemByUid(uid) case final it?) rules.items.displayName(it),
      ].join(', ');
      out.add(const SizedBox(height: 6));
      out.add(ProtoText(
          key: const ValueKey('craft-lost'),
          'Se pierde: ${protoColor(ProtoColors.red, '<b>${protoEsc(lost)}</b> '
              '(con sus mods, pasiva y forja)')}'));
    }
    return out;
  }

  String _modList(ItemInstance it) {
    final rules = widget.shop.rules;
    if (it.affixes.isEmpty) return protoColor(ProtoColors.dim, '(sin mods)');
    return [for (final a in it.affixes) '• ${affixMarkup(rules, a)}'].join('<br>');
  }

  /// Lista de mods después, con lo nuevo en verde y lo quitado en rojo.
  String _diffMods(ItemInstance before, ItemInstance after) {
    final rules = widget.shop.rules;
    final lines = <String>[
      for (final a in before.affixes)
        if (!after.affixes.contains(a))
          '• ${protoColor(ProtoColors.red, '${protoEsc(rules.items.affixText(a))} (se quita)')}',
      for (final a in after.affixes)
        before.affixes.contains(a)
            ? '• ${affixMarkup(rules, a)}'
            : '• ${protoColor(ProtoColors.green, '<b>${protoEsc(rules.items.affixText(a))}</b> (nuevo)')}',
    ];
    return lines.isEmpty ? protoColor(ProtoColors.dim, '(sin mods)') : lines.join('<br>');
  }
}
