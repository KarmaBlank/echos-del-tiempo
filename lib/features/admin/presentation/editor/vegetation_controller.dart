import 'dart:io' show File;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../../../core/i18n/game_text.dart';
import '../../../../game_engine/procedural/vegetation.dart';
import '../../../combat/presentation/sprite_catalog.dart';
import 'sprite_editor_controller.dart' show EditorNotice;

/// Visuales → VEGETACIÓN (docs/specs/procedural_vegetation.md § 6): pick
/// a biome and a species, move seed / size / density / trunk / outline
/// with a live preview, REGENERATE, and save the preset (the override's
/// `vegetation_presets.yaml`, plus the repo's when [repoPath] is set).
/// PNG overrides of each biome × species are the `tiles.veg_*` slots of
/// the SPRITES tab; this page only shows whether one is active.
class VegetationController extends ChangeNotifier {
  VegetationController(
      {required this.doc,
      this.store,
      this.repoPath,
      this.hasOverride,
      Future<ui.Image> Function(VegetationSprite, VegetationPalette)? toImage})
      : _toImage = toImage ?? SpriteCatalog.vegetationImage {
    biomeId = doc.biomes.keys.firstOrNull;
    species = biome?.species.keys.firstOrNull ?? VegetationSpecies.deciduous;
    refresh();
  }

  /// Editable draft.
  final VegetationDoc doc;
  final VegetationOverrideSource? store;
  final String? repoPath;

  /// `true` if a PNG override exists for a manifest id (`tiles.<key>.idle`).
  final bool Function(String id)? hasOverride;
  final Future<ui.Image> Function(VegetationSprite, VegetationPalette)
      _toImage;

  String? biomeId;
  VegetationSpecies species = VegetationSpecies.deciduous;
  bool dirty = false;
  EditorNotice? notice;

  /// Live preview: one image per variant of the current preset.
  List<ui.Image> previews = const [];
  int _generation = 0;

  VegetationBiome? get biome => doc.biomes[biomeId];
  VegetationPreset get preset =>
      biome?.species[species] ?? const VegetationPreset();

  bool get canWrite => store != null || repoPath != null;

  /// The current species of the current biome is drawn from a PNG.
  bool get overridden =>
      biomeId != null &&
      (hasOverride?.call(
              'tiles.${VegetationDoc.spriteKey(biomeId!, species)}.idle') ??
          false);

  void selectBiome(String id) {
    biomeId = id;
    if (!(biome?.species.containsKey(species) ?? false)) {
      species = biome?.species.keys.firstOrNull ?? species;
    }
    refresh();
  }

  void selectSpecies(VegetationSpecies s) {
    species = s;
    refresh();
  }

  void update(VegetationPreset p) {
    final b = biome;
    if (b == null) return;
    b.species[species] = p;
    dirty = true;
    refresh();
  }

  /// REGENERATE: a new seed, deterministic from the current one.
  void regenerate() =>
      update(preset.copyWith(seed: VegRng(preset.seed).below(100000)));

  void clearNotice() {
    notice = null;
    notifyListeners();
  }

  /// Regenerates [previews] (latest call wins).
  Future<void> refresh() async {
    final gen = ++_generation;
    final b = biome;
    notifyListeners();
    if (b == null) {
      previews = const [];
      return;
    }
    final p = preset;
    final out = <ui.Image>[];
    for (var v = 0; v < p.variants; v++) {
      out.add(await _toImage(
          VegetationGenerator.generate(p.params(species, v)), b.palette));
    }
    if (gen != _generation) return;
    previews = out;
    notifyListeners();
  }

  /// SAVE PRESET: writes the override (and the repo file, if known).
  Future<void> save() async {
    final yaml = doc.encode();
    try {
      await store?.putVegetation(yaml);
      if (repoPath case final r?) {
        await File('$r/${SpriteCatalog.vegetationPath}')
            .writeAsString(yaml, flush: true);
      }
      dirty = false;
      notice = EditorNotice(GameText.t('ui.world.veg.saved'), ok: true);
    } catch (e) {
      notice = EditorNotice('$e', error: true);
    }
    notifyListeners();
  }
}
