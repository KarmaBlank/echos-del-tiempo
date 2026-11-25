import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../core/i18n/game_text.dart';
import '../../../../game_engine/procedural/vegetation.dart';
import '../../../combat/presentation/sprite_catalog.dart';
import 'vegetation_controller.dart';

/// Visuales → VEGETACIÓN (docs/specs/procedural_vegetation.md § 6): biome
/// subtabs | species grid | live preview of every variant | knobs.
class VegetationPage extends StatelessWidget {
  const VegetationPage({super.key, required this.c});
  final VegetationController c;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final biomes = c.doc.biomes.keys.toList();
        return Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (biomes.isNotEmpty)
              DsTabBar(
                key: const ValueKey('veg-biomes'),
                index: biomes.indexOf(c.biomeId ?? '').clamp(0, biomes.length - 1),
                onChanged: (i) => c.selectBiome(biomes[i]),
                tabs: [
                  for (final b in biomes) DsTab(GameText.t('ui.world.veg.biome.$b')),
                ],
              ),
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(width: 220, child: _Species(c: c)),
                const VerticalDivider(width: 2, thickness: 2, color: DsColors.border),
                Expanded(
                  child: Center(
                    child: Wrap(spacing: DsSpace.sm, runSpacing: DsSpace.sm, children: [
                      for (final (i, im) in c.previews.indexed)
                        VegetationPixel(
                            key: ValueKey('veg-preview-$i'), image: im, size: 160),
                    ]),
                  ),
                ),
                const VerticalDivider(width: 2, thickness: 2, color: DsColors.border),
                SizedBox(width: 340, child: _Knobs(c: c)),
              ]),
            ),
          ]),
          if (c.notice != null)
            Positioned(
              left: 236,
              right: 356,
              bottom: DsSpace.md,
              child: DsToast(c.notice!.text,
                  key: const ValueKey('veg-notice'),
                  kind: c.notice!.error ? DsToastKind.danger : DsToastKind.success,
                  onClose: c.clearNotice),
            ),
        ]);
      },
    );
  }
}

class _Species extends StatelessWidget {
  const _Species({required this.c});
  final VegetationController c;

  @override
  Widget build(BuildContext context) {
    final grown = c.biome?.species.keys.toSet() ?? const <VegetationSpecies>{};
    return Padding(
      padding: EdgeInsets.all(DsSpace.sm),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: DsSpace.xs,
        crossAxisSpacing: DsSpace.xs,
        children: [
          for (final s in VegetationSpecies.values)
            if (grown.contains(s))
              GestureDetector(
                key: ValueKey('veg-species-${s.name}'),
                onTap: () => c.selectSpecies(s),
                child: Container(
                  decoration: BoxDecoration(
                      color: DsColors.surface,
                      border: Border.all(
                          width: 2,
                          color: s == c.species ? DsColors.focus : DsColors.border)),
                  child: Center(
                      child: Text(GameText.t('ui.world.veg.species.${s.name}'),
                          style: DsText.detail(), textAlign: TextAlign.center)),
                ),
              ),
        ],
      ),
    );
  }
}

class _Knobs extends StatelessWidget {
  const _Knobs({required this.c});
  final VegetationController c;

  @override
  Widget build(BuildContext context) {
    final p = c.preset;
    Widget slider(String key, int value, int min, int max, ValueChanged<int> on) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(GameText.t('ui.world.veg.$key', {'n': value}), style: DsText.detail()),
          DsSlider(
              key: ValueKey('veg-$key'),
              value: value.clamp(min, max),
              min: min,
              max: max,
              semanticLabel: GameText.t('ui.world.veg.$key', {'n': value}),
              onChanged: on),
        ]);
    return ListView(padding: EdgeInsets.all(DsSpace.sm), children: [
      DsSectionHeader(GameText.t('ui.world.veg.species.${c.species.name}')),
      if (c.overridden)
        Text(GameText.t('ui.world.veg.png_override'),
            key: const ValueKey('veg-png-override'), style: DsText.detail()),
      slider('seed', p.seed, 0, 99999, (v) => c.update(p.copyWith(seed: v))),
      DsButton(GameText.t('ui.world.veg.regenerate'),
          key: const ValueKey('veg-regenerate'),
          tooltip: GameText.t('ui.world.veg.regenerate_tip'),
          size: DsButtonSize.compact,
          onPressed: c.regenerate),
      slider('width', p.width, 8, 16, (v) => c.update(p.copyWith(width: v))),
      slider('height', p.height, 8, 16, (v) => c.update(p.copyWith(height: v))),
      slider('density', (p.density * 100).round(), 0, 100,
          (v) => c.update(p.copyWith(density: v / 100))),
      slider('trunk', (p.trunk * 100).round(), 0, 100,
          (v) => c.update(p.copyWith(trunk: v / 100))),
      slider('variants', p.variants, 1, 8, (v) => c.update(p.copyWith(variants: v))),
      slider('weight', p.weight, 0, 20, (v) => c.update(p.copyWith(weight: v))),
      SizedBox(height: DsSpace.xs),
      DsButton(GameText.t('ui.world.veg.outline'),
          key: const ValueKey('veg-outline'),
          size: DsButtonSize.compact,
          selected: p.outline,
          onPressed: () => c.update(p.copyWith(outline: !p.outline))),
      DsSectionHeader(GameText.t('ui.world.veg.palette')),
      Wrap(spacing: 2, children: [
        for (final col in c.biome?.palette.colors ?? const <int>[])
          Container(width: 18, height: 18, color: Color(col).withAlpha(255))
              .tip(VegetationDoc.hex(col)),
      ]),
      SizedBox(height: DsSpace.sm),
      DsButton(GameText.t('ui.world.veg.save'),
          key: const ValueKey('veg-save'),
          tooltip: GameText.t('ui.world.veg.save_tip'),
          kind: DsButtonKind.primary,
          onPressed: c.canWrite && c.dirty ? c.save : null),
    ]);
  }
}

/// Pixel-art image scaled by an integer, no smoothing, bottom-aligned.
class VegetationPixel extends StatelessWidget {
  const VegetationPixel({super.key, required this.image, required this.size});
  final ui.Image? image;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
      width: size, height: size, child: CustomPaint(painter: _PixelPainter(image)));
}

class _PixelPainter extends CustomPainter {
  _PixelPainter(this.image);
  final ui.Image? image;

  @override
  void paint(Canvas canvas, Size size) {
    final im = image;
    if (im == null) return;
    final k = (size.shortestSide / 16).floorToDouble().clamp(1.0, 64.0);
    final w = im.width * k, h = im.height * k;
    canvas.drawImageRect(
        im,
        Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()),
        Rect.fromLTWH(((size.width - w) / 2).roundToDouble(),
            (size.height - h).roundToDouble(), w, h),
        SpriteCatalog.pixelPaint());
  }

  @override
  bool shouldRepaint(_PixelPainter old) => old.image != image;
}
