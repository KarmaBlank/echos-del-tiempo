import 'dart:io' show File;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../../../core/procedural/npc_variants.dart';
import '../../../combat/presentation/sprite_catalog.dart';
import 'sprite_editor_controller.dart' show EditorNotice;

/// Visuales → VARIANTES NPC (docs/specs/npc_variants.md § 5): elegir un
/// NPC con variante, mover semilla / paleta / partes con vista previa en
/// vivo, re-roll, guardar como fijo y crear NPCs nuevos desde un aspecto
/// generado. Escribe el `npc_variants.yaml` del override local.
class NpcVariantsController extends ChangeNotifier {
  NpcVariantsController({required this.catalog, this.store, this.repoPath})
      : doc = NpcVariantsDoc.parse(catalog.npcVariants.encode()) {
    selectedId = doc.variants.keys.firstOrNull;
    _refreshAll();
  }

  final SpriteCatalog catalog;

  /// Dónde se guarda (`null`: solo vista previa).
  final NpcVariantsOverrideSource? store;

  /// Raíz del repo: con ella, GUARDAR también publica
  /// `assets/sprites/npc_variants.yaml` (un NPC nuevo necesita su
  /// variante en el juego publicado, npc_variants.md § 5).
  final String? repoPath;

  /// Borrador editable (copia del efectivo).
  NpcVariantsDoc doc;
  String? selectedId;
  bool dirty = false;
  EditorNotice? notice;

  /// Vista previa de cada variante (se regenera al tocar perillas).
  final Map<String, ui.Image> previews = {};

  NpcVariantSpec? get selected =>
      selectedId == null ? null : doc.variants[selectedId];

  bool get canWrite => store != null;

  /// Lo que eligió la semilla (o el aspecto fijo) del elegido.
  NpcVariantPick? get pick {
    final s = selected;
    return s == null ? null : NpcVariantGenerator(doc).pick(s);
  }

  void select(String id) {
    selectedId = id;
    notifyListeners();
  }

  void clearNotice() {
    notice = null;
    notifyListeners();
  }

  void _update(NpcVariantSpec s) {
    doc.variants[s.id] = s;
    dirty = true;
    _refresh(s);
    notifyListeners();
  }

  /// Semilla nueva; suelta el aspecto fijo (se vuelve a generar).
  void setSeed(int seed) =>
      _update(selected!.copyWith(seed: seed, clearFixed: true));

  /// GENERAR / RE-ROLL: semilla al azar (determinista a partir de la
  /// actual, así dos re-rolls seguidos no repiten).
  void reroll() {
    final s = selected!;
    setSeed(SeededRng(s.seed ^ 0x5bd1e995).below(100000));
  }

  void setPalette(String p) =>
      _update(selected!.copyWith(palette: p, clearFixed: true));

  void setBase(String b) =>
      _update(selected!.copyWith(base: b, clearFixed: true));

  void togglePart(String part) {
    final s = selected!;
    final parts = [...s.parts];
    parts.contains(part) ? parts.remove(part) : parts.add(part);
    _update(s.copyWith(parts: parts, clearFixed: true));
  }

  void toggleTweak() => _update(
      selected!.copyWith(tweak: !selected!.tweak, clearFixed: true));

  /// GUARDAR COMO FIJO: congela colores, partes y retoque de la semilla
  /// actual; el juego ya no lo regenera.
  Future<void> saveFixed() async {
    final s = selected!;
    doc.variants[s.id] = s.copyWith(fixed: NpcVariantGenerator(doc).roll(s));
    dirty = true;
    await save();
  }

  /// Vuelve a generar el elegido desde la semilla (suelta lo fijo).
  void unfix() => _update(selected!.copyWith(clearFixed: true));

  /// NUEVO NPC desde el aspecto actual: id nuevo con la misma receta.
  /// Devuelve `false` si el id es inválido o ya existe.
  bool createFrom(String rawId) {
    final id = rawId.trim().toLowerCase();
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(id) ||
        doc.variants.containsKey(id)) {
      notice = const EditorNotice('Id inválido o repetido (a-z, 0-9, _).',
          error: true);
      notifyListeners();
      return false;
    }
    final base = selected ??
        NpcVariantSpec(
            id: id,
            base: doc.bases.keys.first,
            seed: 1,
            palette: doc.palettes.keys.first);
    doc.variants[id] = base.copyWith(id: id);
    selectedId = id;
    dirty = true;
    _refresh(doc.variants[id]!);
    notice = EditorNotice('NPC $id creado: usá sprite "$id" en sus datos.');
    notifyListeners();
    return true;
  }

  /// Escribe el override y recarga las variantes del juego.
  Future<void> save() async {
    final st = store;
    if (st == null) return;
    await st.putNpcVariants(doc.encode());
    if (repoPath case final r?) {
      await File('$r/${SpriteCatalog.npcVariantsPath}')
          .writeAsString(doc.encode(), flush: true);
    }
    await catalog.loadNpcVariants();
    dirty = false;
    notice = const EditorNotice('Variantes guardadas (npc_variants.yaml).',
        ok: true);
    notifyListeners();
  }

  Future<void> _refresh(NpcVariantSpec s) async {
    final img = await catalog.npcVariantImage(s, doc);
    if (_disposed) return;
    if (img != null) previews[s.id] = img;
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _refreshAll() {
    for (final s in doc.variants.values) {
      _refresh(s);
    }
  }
}
