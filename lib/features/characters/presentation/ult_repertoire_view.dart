import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../game_engine/data/achievements_catalog.dart';
import '../../../game_engine/data/classes_catalog.dart';
import '../../../game_engine/data/enemies_catalog.dart';
import '../../../game_engine/data/uniques_catalog.dart';
import '../../../game_engine/data/ults_v2_catalog.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/ult_def.dart';
import '../../../game_engine/models/weapon.dart';
import '../../../game_engine/rules/ult_rules.dart';
import '../../../core/audio/sfx_service.dart';
import '../../../game_engine/models/player_state.dart';
import '../../../game_engine/models/skill.dart';
import '../../combat/domain/skill_text.dart';
import '../../combat/presentation/game_sprites.dart';
import 'ult_preview_panel.dart';

/// Pestaña ULT de PERSONAJE (docs/specs/ultimates_v2.md § 2.1 y § 2.4):
/// elegir la ULT activa del repertorio, mejorarla (nivel, próximo efecto,
/// costo y MEJORAR con confirmación) y ver las 50 con su fuente.
class UltRepertoireView extends StatefulWidget {
  const UltRepertoireView({
    super.key,
    required this.profile,
    required this.weapon,
    required this.item,
    required this.editable,
    required this.onSelect,
    required this.onUpgrade,
    this.onSeen,
    this.stats,
    this.sprites,
    this.sfx,
  });

  /// Stats del personaje para los números de ejemplo de la vista previa.
  final DerivedStats? stats;
  final GameSprites? sprites;
  final SfxService? sfx;

  /// Ancho desde el que la vista previa va al lado de la lista.
  static const wideFrom = 760.0;

  /// Builds de la vista (tests: la vista previa no la reconstruye).
  static int debugBuilds = 0;

  final PlayerProfile profile;
  final WeaponDef weapon;
  final ItemInstance? item;

  /// Fuera de combate (pueblo o campamento).
  final bool editable;
  final bool Function(String? id) onSelect;
  final bool Function(String id) onUpgrade;

  /// Desmarca la NUEVA de una ULT al pasar el mouse por su fila (manda
  /// `SeenItemsAction` con `ult:<id>`, ultimates_v2.md § 2.1).
  final void Function(List<String> ids)? onSeen;

  static const help = '<b>ULT</b><br>'
      'Tu repertorio: toda ULT que conseguís queda para siempre. Al '
      'conseguir un arma que enseña una ULT la aprendés en el momento. '
      'Elegí la activa fuera de combate; el arma equipada no la cambia. '
      'Sin elegir, se usa la ULT base de tu clase.<br>'
      'MEJORAR sube su nivel (1 a 5) con créditos y materiales.';

  @override
  State<UltRepertoireView> createState() => _UltRepertoireViewState();
}

class _UltRepertoireViewState extends State<UltRepertoireView> {
  String? _focus;
  String? _hover;
  bool _hoverUpgrade = false;
  bool _confirm = false;
  final _seenSent = <String>{};

  void _seen(String id) {
    if (!widget.profile.ultNew.contains(id) || !_seenSent.add(id)) return;
    widget.onSeen?.call(['${UltRules.seenPrefix}$id']);
  }

  String _name(String id) =>
      kUniques[id]?.name ??
      kAchievementsById[id]?.name ??
      kEnemies[id]?.name ??
      kClasses[id]?.name ??
      id;

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final opts = UltRules.optionsOf(p, widget.weapon, widget.item);
    final active = UltRules.validSel(p, widget.weapon, widget.item);
    final shown = active ??
        opts
            .where((o) => o.kind != UltOptionKind.learned || o.available)
            .firstOrNull
            ?.id;
    final focus = opts.where((o) => o.id == (_focus ?? shown)).firstOrNull;
    final known = {...p.ultKnown, ...UltRules.earned(p)};
    UltRepertoireView.debugBuilds++;
    // Vista previa: la del hover, si no la elegida en la lista.
    final hovered = opts.where((o) => o.id == _hover).firstOrNull;
    final catalogHover = hovered == null ? kUltV2[_hover] : null;
    final o = hovered ?? focus;
    final preview = catalogHover != null
        ? _preview(catalogHover.skill, catalogHover.source.learned)
        : o == null
            ? null
            : _preview(o.skill, o.kind == UltOptionKind.learned);
    final list = _list(p, opts, active, shown, focus, known);
    return LayoutBuilder(builder: (context, box) {
      if (preview == null) return SingleChildScrollView(child: list);
      if (box.maxWidth >= UltRepertoireView.wideFrom) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: SingleChildScrollView(child: list)),
          SizedBox(width: DsSpace.md),
          SizedBox(
              width: (box.maxWidth * 0.4).clamp(260.0, 420.0),
              child: SingleChildScrollView(child: preview)),
        ]);
      }
      // Angosta: la vista previa arriba de la lista.
      return SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [preview, SizedBox(height: DsSpace.md), list]));
    });
  }

  Widget _preview(SkillDef skill, bool learned) {
    final p = widget.profile;
    final lv = learned ? UltRules.levelOf(p, skill.id) : 1;
    final next = learned && _hoverUpgrade && lv < UltRules.maxLevel;
    final shownLv = next ? lv + 1 : lv;
    return UltPreviewPanel(
      skill: UltRules.leveled(skill, shownLv),
      level: shownLv,
      nextLevel: next,
      classId: p.classId,
      ascensionId: p.ascension.id,
      weaponType: widget.weapon.type,
      stats: widget.stats,
      sprites: widget.sprites,
      sfx: widget.sfx,
    );
  }

  Widget _list(PlayerProfile p, List<UltOption> opts, String? active,
      String? shown, UltOption? focus, Set<String> known) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsSectionHeader('ULT ACTIVA',
              trailing: Text(
                  p.ultSel == null
                      ? 'Automática'
                      : active == null
                          ? 'No disponible: se usa la ULT base'
                          : 'Elegida',
                  style: DsText.detail())),
          if (focus != null) ...[
            _detail(focus),
            SizedBox(height: DsSpace.sm),
          ],
          // La activa primero; después el resto (las grises al final).
          for (final o in [
            ...opts.where((o) => o.id == (active ?? shown)),
            ...opts.where((o) => o.id != (active ?? shown) && o.available),
            ...opts.where((o) => o.id != (active ?? shown) && !o.available),
          ])
            _row(o, active, shown),
          SizedBox(height: DsSpace.md),
          DsSectionHeader('LAS 50 ULT',
              trailing: Text(
                  '${kUltV2List.where((u) => known.contains(u.id)).length}/50',
                  style: DsText.detail())),
          for (final s in UltSource.values) ...[
            Padding(
              padding: EdgeInsets.only(top: DsSpace.sm),
              child: Row(children: [
                Expanded(
                    child: Text(s.label.toUpperCase(),
                        style: DsText.subtitle())),
                if (s == UltSource.boss)
                  Text('Jefes vencidos: ${bossUltsDefeated(p)}/10',
                      key: const ValueKey('ult-boss-progress'),
                      style: DsText.detail()),
              ]),
            ),
            for (final u in kUltV2List.where((u) => u.source == s))
              MouseRegion(
                onEnter: (_) => setState(() => _hover = u.id),
                onExit: (_) {
                  if (_hover == u.id) setState(() => _hover = null);
                },
                child: DsListRow(
                key: ValueKey('ult-all-${u.id}'),
                compact: true,
                title: known.contains(u.id)
                    ? '${u.name} · Nv ${UltRules.levelOf(p, u.id)}'
                    : u.name,
                titleColor: known.contains(u.id) ? null : DsColors.textSecondary,
                detail: '${known.contains(u.id) ? 'Obtenida' : 'Falta'} · '
                    '${u.source == UltSource.boss ? bossUltShortText(u) : ultHowText(u, name: _name)}',
                tooltip: u.source == UltSource.boss
                    ? DsTooltipCard(title: u.name, children: [
                        Text(ultHowText(u, name: _name),
                            style: DsText.detail(DsColors.text)),
                        if (!known.contains(u.id))
                          Text(bossUltStatusText(u, p),
                              style: DsText.detail()),
                      ])
                    : null,
              )),
          ],
        ],
    );
  }

  Widget _row(UltOption o, String? active, String? shown) {
    final isActive = o.id == (active ?? shown);
    final lv = o.kind == UltOptionKind.learned ? ' · Nv ${o.level}' : '';
    final kind = switch (o.kind) {
      UltOptionKind.ascension => 'Ascensión',
      UltOptionKind.weaponType => 'ULT base de la clase',
      UltOptionKind.learned => o.def?.source.label ?? 'De arma',
    };
    final fresh = widget.profile.ultNew.contains(o.id);
    final pick = isActive
        ? const DsBadge('ACTIVA')
        : DsButton('ELEGIR',
            size: DsButtonSize.compact,
            onPressed: widget.editable && o.available
                ? () => widget.onSelect(o.id)
                : null);
    return MouseRegion(
      onEnter: (_) {
        _seen(o.id);
        setState(() => _hover = o.id);
      },
      onExit: (_) {
        if (_hover == o.id) setState(() => _hover = null);
      },
      child: DsListRow(
      key: ValueKey('ult-row-${o.id}'),
      compact: true,
      title: '${o.skill.name}$lv',
      detail: o.reason == null ? kind : '$kind · ${o.reason}',
      titleColor: o.available ? null : DsColors.textSecondary,
      selected: o.id == _focus,
      onTap: () => setState(() {
        _focus = o.id;
        _confirm = false;
      }),
      trailing: fresh
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              DsBadge('NUEVA', key: ValueKey('ult-new-${o.id}')),
              SizedBox(width: DsSpace.sm),
              pick,
            ])
          : pick,
      ),
    );
  }

  Widget _detail(UltOption o) {
    final p = widget.profile;
    final learned = o.kind == UltOptionKind.learned;
    final lv = learned ? UltRules.levelOf(p, o.id) : 1;
    final cost = learned ? UltRules.upgradeCost(o.id, lv) : null;
    final affordable = cost != null &&
        p.credits >= cost.credits &&
        cost.materials.entries.every((e) => p.material(e.key) >= e.value);
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProtoText(describeSkillMarkup(UltRules.leveled(o.skill, lv), null,
              ultimate: true)),
          if (learned) ...[
            SizedBox(height: DsSpace.sm),
            Text(
                'Nivel $lv/${UltRules.maxLevel}: poder ×'
                '${UltRules.levelFactor(lv).toStringAsFixed(2)}',
                style: DsText.body()),
            if (cost != null) ...[
              Text(
                  'Próximo nivel ${lv + 1}: poder ×'
                  '${UltRules.levelFactor(lv + 1).toStringAsFixed(2)}',
                  style: DsText.body()),
              Text('Costo: ${cost.text}',
                  style: DsText.detail(
                      affordable ? DsColors.textSecondary : DsColors.danger)),
              SizedBox(height: DsSpace.sm),
              Row(children: [
                if (!_confirm)
                  // Hover de MEJORAR: la vista previa muestra el próximo
                  // nivel.
                  MouseRegion(
                    onEnter: (_) => setState(() => _hoverUpgrade = true),
                    onExit: (_) => setState(() => _hoverUpgrade = false),
                    child: DsButton('MEJORAR',
                        kind: DsButtonKind.primary,
                        onPressed: widget.editable && affordable
                            ? () => setState(() => _confirm = true)
                            : null),
                  )
                else ...[
                  DsButton('CONFIRMAR MEJORA',
                      kind: DsButtonKind.primary,
                      onPressed: () {
                        widget.onUpgrade(o.id);
                        setState(() => _confirm = false);
                      }),
                  SizedBox(width: DsSpace.sm),
                  DsButton('CANCELAR',
                      onPressed: () => setState(() => _confirm = false)),
                ],
              ]),
            ] else
              Text('Nivel máximo.', style: DsText.detail()),
          ],
        ],
      ),
    );
  }
}
