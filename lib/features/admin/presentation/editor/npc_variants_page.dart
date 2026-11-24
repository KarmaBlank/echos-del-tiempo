import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../core/i18n/game_text.dart';
import '../../../../core/procedural/npc_variants.dart';
import '../../../combat/presentation/sprite_catalog.dart';
import 'npc_variants_controller.dart';

/// Visuales → VARIANTES NPC (docs/specs/npc_variants.md § 5): grilla de
/// NPCs con variante | vista previa grande | receta (semilla, paleta,
/// partes) y acciones GENERAR / RE-ROLL / GUARDAR COMO FIJO / NUEVO NPC.
class NpcVariantsPage extends StatelessWidget {
  const NpcVariantsPage({super.key, required this.c, this.onUseInNpc});
  final NpcVariantsController c;

  /// USAR EN NPC / NUEVO NPC: abre (o crea) el NPC de datos con esa
  /// variante en el editor NPC (npc_editor.md § 6.1).
  final ValueChanged<String>? onUseInNpc;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Stack(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: 340, child: _Grid(c: c)),
          const VerticalDivider(width: 2, thickness: 2, color: DsColors.border),
          Expanded(
              child: Center(
                  child: _Pixel(
                      key: const ValueKey('npcv-preview'),
                      image: c.previews[c.selectedId],
                      size: 256))),
          const VerticalDivider(width: 2, thickness: 2, color: DsColors.border),
          SizedBox(width: 360, child: _Recipe(c: c, onUseInNpc: onUseInNpc)),
        ]),
        if (c.notice != null)
          Positioned(
            left: 356,
            right: 376,
            bottom: DsSpace.md,
            child: DsToast(c.notice!.text,
                key: const ValueKey('npcv-notice'),
                kind: c.notice!.error
                    ? DsToastKind.danger
                    : c.notice!.ok
                        ? DsToastKind.success
                        : DsToastKind.info,
                onClose: c.clearNotice),
          ),
      ]),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.c});
  final NpcVariantsController c;

  @override
  Widget build(BuildContext context) {
    final ids = c.doc.variants.keys.toList();
    return Padding(
      padding: EdgeInsets.all(DsSpace.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DsSectionHeader(GameText.t('ui.world.npcv.count', {'n': ids.length})),
        Expanded(
          child: GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: DsSpace.xs,
            crossAxisSpacing: DsSpace.xs,
            children: [
              for (final id in ids)
                GestureDetector(
                  key: ValueKey('npcv-cell-$id'),
                  onTap: () => c.select(id),
                  child: Container(
                    decoration: BoxDecoration(
                        color: DsColors.surface,
                        border: Border.all(
                            width: 2,
                            color: id == c.selectedId
                                ? DsColors.focus
                                : DsColors.border)),
                    child: _Pixel(image: c.previews[id], size: 56),
                  ),
                ).tip(id),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Recipe extends StatefulWidget {
  const _Recipe({required this.c, this.onUseInNpc});
  final NpcVariantsController c;
  final ValueChanged<String>? onUseInNpc;

  @override
  State<_Recipe> createState() => _RecipeState();
}

class _RecipeState extends State<_Recipe> {
  final _newId = TextEditingController();

  @override
  void dispose() {
    _newId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final s = c.selected;
    final pick = c.pick;
    return ListView(padding: EdgeInsets.all(DsSpace.sm), children: [
      DsSectionHeader(s?.id.toUpperCase() ?? GameText.t('ui.world.npcv.none')),
      if (s != null) ...[
        Text(GameText.t(s.fixed != null ? 'ui.world.npcv.fixed' : 'ui.world.npcv.seeded'),
            style: DsText.detail()),
        SizedBox(height: DsSpace.xs),
        Text(GameText.t('ui.world.npcv.seed', {'n': s.seed}), style: DsText.detail()),
        DsSlider(
            key: const ValueKey('npcv-seed'),
            value: s.seed.clamp(0, 9999),
            min: 0,
            max: 9999,
            semanticLabel: 'Semilla',
            onChanged: c.setSeed),
        SizedBox(height: DsSpace.xs),
        Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          DsButton(GameText.t('ui.world.npcv.generate'),
              key: const ValueKey('npcv-generate'),
              tooltip: GameText.t('ui.world.npcv.generate_tip'),
              size: DsButtonSize.compact,
              onPressed: c.unfix),
          DsButton(GameText.t('ui.world.npcv.reroll'),
              key: const ValueKey('npcv-reroll'),
              tooltip: GameText.t('ui.world.npcv.reroll_tip'),
              size: DsButtonSize.compact,
              onPressed: c.reroll),
          DsButton(GameText.t('ui.world.npcv.tweak'),
              key: const ValueKey('npcv-tweak'),
              tooltip: GameText.t('ui.world.npcv.tweak_tip'),
              size: DsButtonSize.compact,
              selected: s.tweak,
              onPressed: c.toggleTweak),
        ]),
        DsSectionHeader(GameText.t('ui.world.npcv.body')),
        Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          for (final b in c.doc.bases.keys)
            DsButton(b.toUpperCase(),
                key: ValueKey('npcv-base-$b'),
                tooltip: GameText.t('ui.world.npcv.body_tip', {'id': b}),
                size: DsButtonSize.compact,
                selected: s.base == b,
                onPressed: () => c.setBase(b)),
        ]),
        DsSectionHeader(GameText.t('ui.world.npcv.palette')),
        Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          for (final p in c.doc.palettes.keys)
            DsButton(p.toUpperCase(),
                key: ValueKey('npcv-pal-$p'),
                tooltip: GameText.t('ui.world.npcv.palette_tip', {'id': p}),
                size: DsButtonSize.compact,
                selected: s.palette == p,
                onPressed: () => c.setPalette(p)),
        ]),
        if (pick != null)
          Padding(
            padding: EdgeInsets.only(top: DsSpace.xs),
            child: Wrap(spacing: 2, children: [
              for (final r in kNpcRegions)
                if (pick.colors[r] case final col?)
                  Container(
                          width: 18,
                          height: 18,
                          color: Color(col).withAlpha(255))
                      .tip('$r: ${NpcVariantsDoc.hex(col)}'),
            ]),
          ),
        DsSectionHeader(GameText.t('ui.world.npcv.parts')),
        Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          for (final p in c.doc.parts.values)
            DsButton(p.id.toUpperCase(),
                key: ValueKey('npcv-part-${p.id}'),
                tooltip: GameText.t(
                    pick?.parts.contains(p.id) == true
                        ? 'ui.world.npcv.part_used_tip'
                        : 'ui.world.npcv.part_tip',
                    {'slot': p.slot}),
                size: DsButtonSize.compact,
                selected: s.parts.contains(p.id),
                onPressed: () => c.togglePart(p.id)),
        ]),
        SizedBox(height: DsSpace.sm),
        DsButton(GameText.t('ui.world.npcv.save_fixed'),
            key: const ValueKey('npcv-save-fixed'),
            tooltip: GameText.t('ui.world.npcv.save_fixed_tip'),
            kind: DsButtonKind.primary,
            onPressed: c.canWrite ? c.saveFixed : null),
        SizedBox(height: DsSpace.xs),
        DsButton(GameText.t('ui.world.npcv.use_in_npc'),
            key: const ValueKey('npcv-use-in-npc'),
            tooltip: GameText.t('ui.world.npcv.use_in_npc_tip'),
            kind: DsButtonKind.ghost,
            onPressed: widget.onUseInNpc == null
                ? null
                : () => widget.onUseInNpc!(s.id)),
        SizedBox(height: DsSpace.xs),
        DsButton(GameText.t('ui.world.npcv.save'),
            key: const ValueKey('npcv-save'),
            tooltip: GameText.t('ui.world.npcv.save_tip'),
            kind: DsButtonKind.ghost,
            onPressed: c.canWrite && c.dirty ? c.save : null),
      ],
      DsSectionHeader(GameText.t('ui.world.npcv.new')),
      DsSearchField(
          key: const ValueKey('npcv-new-id'),
          hint: GameText.t('ui.world.npcv.new_id'),
          width: 320,
          controller: _newId),
      SizedBox(height: DsSpace.xs),
      DsButton(GameText.t('ui.world.npcv.create'),
          key: const ValueKey('npcv-create'),
          tooltip: GameText.t('ui.world.npcv.create_tip'),
          size: DsButtonSize.compact,
          onPressed: () {
            if (c.createFrom(_newId.text)) {
              _newId.clear();
              // NUEVO NPC: también el NPC de datos (con su evento).
              widget.onUseInNpc?.call(c.selectedId!);
            }
          }),
    ]);
  }
}

/// Imagen pixel art escalada a entero, sin suavizado.
class _Pixel extends StatelessWidget {
  const _Pixel({super.key, required this.image, required this.size});
  final ui.Image? image;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PixelPainter(image)));
}

class _PixelPainter extends CustomPainter {
  _PixelPainter(this.image);
  final ui.Image? image;

  @override
  void paint(Canvas canvas, Size size) {
    final im = image;
    if (im == null) return;
    final k = (size.shortestSide / (im.width > im.height ? im.width : im.height))
        .floorToDouble()
        .clamp(1.0, 64.0);
    final w = im.width * k, h = im.height * k;
    canvas.drawImageRect(
        im,
        Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()),
        Rect.fromLTWH(((size.width - w) / 2).roundToDouble(),
            ((size.height - h) / 2).roundToDouble(), w, h),
        SpriteCatalog.pixelPaint());
  }

  @override
  bool shouldRepaint(_PixelPainter old) => old.image != image;
}
