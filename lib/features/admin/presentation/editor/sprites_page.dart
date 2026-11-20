import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../combat/presentation/sprite_catalog.dart';
import 'sprite_editor_controller.dart';

/// Visuales → Sprites (docs/specs/game_editor.md § 3.1 y § 6): catálogo
/// por categoría + buscador | vista previa con zoom y en contexto | ficha.
class SpritesPage extends StatelessWidget {
  const SpritesPage({super.key, required this.c});
  final SpriteEditorController c;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Stack(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: 340, child: _Browser(c: c)),
          const VerticalDivider(width: 2, thickness: 2, color: DsColors.border),
          Expanded(child: _Preview(c: c)),
          const VerticalDivider(width: 2, thickness: 2, color: DsColors.border),
          SizedBox(width: 360, child: _Properties(c: c)),
        ]),
        if (c.notice != null)
          Positioned(
            left: 356,
            right: 376,
            bottom: DsSpace.md,
            child: DsToast(c.notice!.text,
                key: const ValueKey('sprite-notice'),
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

class _Browser extends StatelessWidget {
  const _Browser({required this.c});
  final SpriteEditorController c;

  @override
  Widget build(BuildContext context) {
    final items = c.visible;
    return Padding(
      padding: EdgeInsets.all(DsSpace.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DsSearchField(
            key: const ValueKey('sprite-search'),
            hint: 'BUSCAR SPRITE',
            width: 320,
            onChanged: c.setQuery),
        SizedBox(height: DsSpace.sm),
        for (final cat in <SpriteCategory?>[null, ...SpriteCategory.values])
          DsListRow(
            key: ValueKey('sprite-cat-${cat?.name ?? 'all'}'),
            compact: true,
            title: cat?.label ?? 'TODO',
            trailing: Text('${c.countOf(cat)}', style: DsText.detail()),
            selected: c.category == cat,
            onTap: () => c.setCategory(cat),
          ),
        DsListRow(
          key: const ValueKey('sprite-only-overrides'),
          compact: true,
          title: c.onlyOverrides ? '[X] CON OVERRIDE' : '[ ] CON OVERRIDE',
          trailing: Text('${c.overrideCount}', style: DsText.detail()),
          onTap: () => c.setOnlyOverrides(!c.onlyOverrides),
        ),
        DsSectionHeader('${items.length} SPRITES'),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) {
              final e = items[i];
              final over = c.catalog.hasOverride(e.id);
              return DsListRow(
                key: ValueKey('sprite-row-${e.id}'),
                compact: true,
                leading: SizedBox(
                    width: 28,
                    height: 28,
                    child: _Pixels(image: c.imageOf(e.id), entry: e)),
                title: e.key,
                detail: e.procedural ? 'procedural' : e.animation,
                trailing: over ? const DsBadge('OVERRIDE') : null,
                selected: c.selected?.id == e.id,
                onTap: () => c.select(e),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.c});
  final SpriteEditorController c;

  @override
  Widget build(BuildContext context) {
    final e = c.selected;
    if (e == null) {
      return Center(
          child: Text('ELEGÍ UN SPRITE A LA IZQUIERDA', style: DsText.detail()));
    }
    final img = c.imageOf(e.id);
    final over = c.catalog.hasOverride(e.id);
    return Padding(
      padding: EdgeInsets.all(DsSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(e.id, style: DsText.subtitle()),
          const Spacer(),
          for (final z in const [1, 2, 4, 8]) ...[
            DsButton('×$z',
                key: ValueKey('sprite-zoom-$z'),
                size: DsButtonSize.compact,
                selected: c.zoom == z,
                onPressed: () => c.setZoom(z)),
            SizedBox(width: DsSpace.xs),
          ],
        ]),
        SizedBox(height: DsSpace.sm),
        Expanded(
          flex: 3,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (over) ...[
              Expanded(
                  child: _Zoomed(
                      label: 'ANTES', image: c.assetImage, entry: e, zoom: c.zoom)),
              SizedBox(width: DsSpace.sm),
            ],
            Expanded(
                child: _Zoomed(
                    label: over ? 'AHORA (OVERRIDE)' : 'ACTUAL',
                    image: img,
                    entry: e,
                    zoom: c.zoom)),
          ]),
        ),
        DsSectionHeader(e.category.onMap ? 'EN CONTEXTO · MAPA' : 'EN CONTEXTO · BATALLA'),
        Expanded(
          flex: 2,
          child: ClipRect(
            child: CustomPaint(
              key: const ValueKey('sprite-context'),
              painter: SpriteContextPainter(
                entry: e,
                image: img,
                hero: c.imageOf('characters.guerrero.idle'),
                enemy: c.imageOf('enemies.slime.idle'),
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ]),
    );
  }
}

/// Sprite a ×[zoom] sobre damero, con grilla de píxeles desde ×4.
class _Zoomed extends StatelessWidget {
  const _Zoomed(
      {required this.label, required this.image, required this.entry, required this.zoom});
  final String label;
  final ui.Image? image;
  final SpriteEntry entry;
  final int zoom;

  @override
  Widget build(BuildContext context) {
    final img = image;
    final w = img?.width ?? entry.expectedSize?.$1 ?? 16;
    final h = img?.height ?? entry.expectedSize?.$2 ?? 16;
    return Container(
      color: DsColors.surfaceSunken,
      padding: EdgeInsets.all(DsSpace.sm),
      child: Column(children: [
        Text(label, style: DsText.detail()),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: w * zoom.toDouble(),
                height: h * zoom.toDouble(),
                child: CustomPaint(
                    painter: _ZoomPainter(img, entry, zoom >= 4)),
              ),
            ),
          ),
        ),
        Text('${w}x$h px', style: DsText.detail()),
      ]),
    );
  }
}

class _ZoomPainter extends CustomPainter {
  _ZoomPainter(this.image, this.entry, this.grid);
  final ui.Image? image;
  final SpriteEntry entry;
  final bool grid;

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    final cols = img?.width ?? entry.expectedSize?.$1 ?? 16;
    final rows = img?.height ?? entry.expectedSize?.$2 ?? 16;
    final cw = size.width / cols;
    final ch = size.height / rows;
    // Damero (transparencia).
    final a = Paint()..color = const Color(0xFF2A2A3A);
    final b = Paint()..color = const Color(0xFF34344A);
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        canvas.drawRect(
            Rect.fromLTWH(x * cw, y * ch, cw, ch), (x + y).isEven ? a : b);
      }
    }
    if (img != null) {
      canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          Offset.zero & size,
          SpriteCatalog.pixelPaint());
    } else {
      paintProcedural(canvas, Offset.zero & size);
    }
    if (grid) {
      final g = Paint()
        ..color = const Color(0x22FFFFFF)
        ..strokeWidth = 1;
      for (var x = 0; x <= cols; x++) {
        canvas.drawLine(Offset(x * cw, 0), Offset(x * cw, size.height), g);
      }
      for (var y = 0; y <= rows; y++) {
        canvas.drawLine(Offset(0, y * ch), Offset(size.width, y * ch), g);
      }
    }
    // Ancla (pies, centro abajo).
    final anchor = Paint()..color = DsColors.focus;
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(size.width / 2, size.height), width: 6, height: 6),
        anchor);
  }

  @override
  bool shouldRepaint(_ZoomPainter old) =>
      old.image != image || old.entry != entry || old.grid != grid;
}

/// Marca de "se dibuja en código" (todavía sin PNG): rayado.
void paintProcedural(Canvas canvas, Rect r) {
  final p = Paint()
    ..color = const Color(0x55B9A6FF)
    ..strokeWidth = 2;
  canvas.save();
  canvas.clipRect(r);
  for (var x = r.left - r.height; x < r.right; x += 8) {
    canvas.drawLine(Offset(x, r.bottom), Offset(x + r.height, r.top), p);
  }
  canvas.restore();
  canvas.drawRect(
      r.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFB9A6FF));
}

/// Mini escena con el sprite en su lugar: batalla (héroe a la izquierda,
/// enemigo a la derecha, ítem en mano, efecto sobre el enemigo, ícono en
/// un panel) o mapa (tile repetido con el héroe parado encima).
class SpriteContextPainter extends CustomPainter {
  SpriteContextPainter(
      {required this.entry, required this.image, this.hero, this.enemy});
  final SpriteEntry entry;
  final ui.Image? image;
  final ui.Image? hero;
  final ui.Image? enemy;

  static const _scale = 3.0;

  void _draw(Canvas c, ui.Image? img, Offset feet, {double scale = _scale, bool flip = false}) {
    final w = (img?.width ?? entry.expectedSize?.$1 ?? 16) * scale;
    final h = (img?.height ?? entry.expectedSize?.$2 ?? 16) * scale;
    final dst = Rect.fromLTWH(feet.dx - w / 2, feet.dy - h, w, h);
    if (img == null) {
      paintProcedural(c, dst);
      return;
    }
    c.save();
    if (flip) {
      c.translate(feet.dx * 2, 0);
      c.scale(-1, 1);
    }
    c.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        dst,
        SpriteCatalog.pixelPaint());
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (entry.category.onMap) {
      _map(canvas, size);
    } else {
      _battle(canvas, size);
    }
  }

  void _map(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF101018));
    const t = 16 * _scale;
    for (var y = 0.0; y < s.height; y += t) {
      for (var x = 0.0; x < s.width; x += t) {
        _draw(c, image, Offset(x + t / 2, y + t));
      }
    }
    _draw(c, hero, Offset(s.width / 2, s.height / 2 + t / 2));
  }

  void _battle(Canvas c, Size s) {
    final ground = s.height * 0.78;
    c.drawRect(Rect.fromLTWH(0, 0, s.width, ground),
        Paint()..color = const Color(0xFF1B1830));
    c.drawRect(Rect.fromLTWH(0, ground, s.width, s.height - ground),
        Paint()..color = const Color(0xFF2B2440));
    c.drawRect(Rect.fromLTWH(0, ground, s.width, 2),
        Paint()..color = const Color(0xFF4A3F6B));
    final heroAt = Offset(s.width * 0.28, ground);
    final enemyAt = Offset(s.width * 0.72, ground);
    switch (entry.category) {
      case SpriteCategory.characters:
        _draw(c, image, heroAt);
        _draw(c, enemy, enemyAt);
      case SpriteCategory.enemies:
      case SpriteCategory.bosses:
        _draw(c, hero, heroAt);
        final big = entry.category == SpriteCategory.bosses ? 2.0 : _scale;
        _draw(c, image, enemyAt, scale: big);
      case SpriteCategory.items:
        _draw(c, hero, heroAt);
        _draw(c, enemy, enemyAt);
        _draw(c, image, heroAt + const Offset(30, -30), scale: 2);
      case SpriteCategory.fx:
        _draw(c, hero, heroAt);
        _draw(c, enemy, enemyAt);
        _draw(c, image, enemyAt + const Offset(0, -10));
      case SpriteCategory.ui:
        _draw(c, hero, heroAt);
        _draw(c, enemy, enemyAt);
        final panel = Rect.fromLTWH(s.width * 0.3, 12, s.width * 0.4, 48);
        c.drawRect(panel, Paint()..color = DsColors.surface);
        _draw(c, image, Offset(panel.left + 28, panel.bottom - 8));
      case SpriteCategory.tiles:
        break;
    }
  }

  @override
  bool shouldRepaint(SpriteContextPainter old) =>
      old.entry != entry || old.image != image || old.hero != hero || old.enemy != enemy;
}

/// Miniatura de la lista.
class _Pixels extends StatelessWidget {
  const _Pixels({required this.image, required this.entry});
  final ui.Image? image;
  final SpriteEntry entry;

  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _ThumbPainter(image));
}

class _ThumbPainter extends CustomPainter {
  _ThumbPainter(this.image);
  final ui.Image? image;

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    if (img == null) {
      paintProcedural(canvas, Offset.zero & size);
      return;
    }
    final k = (size.width / img.width).clamp(0.0, size.height / img.height);
    final w = img.width * k;
    final h = img.height * k;
    canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h),
        SpriteCatalog.pixelPaint());
  }

  @override
  bool shouldRepaint(_ThumbPainter old) => old.image != image;
}

class _Properties extends StatelessWidget {
  const _Properties({required this.c});
  final SpriteEditorController c;

  Future<void> _confirmPublish(BuildContext context) async {
    final list = c.publishable;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: const RoundedRectangleBorder(),
        backgroundColor: DsColors.surface,
        child: Padding(
          padding: EdgeInsets.all(DsSpace.lg),
          child: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PUBLICAR AL REPO', style: DsText.title()),
              SizedBox(height: DsSpace.sm),
              Text(
                  'Copia ${list.length} PNG a assets/sprites/ y actualiza '
                  'sprite_manifest.yaml en ${c.repoPath}. Los overrides '
                  'publicados se borran de la carpeta local. Después falta '
                  'el commit.',
                  style: DsText.body()),
              SizedBox(height: DsSpace.sm),
              for (final e in list.take(8)) Text('· ${e.id}', style: DsText.detail()),
              if (list.length > 8) Text('… y ${list.length - 8} más', style: DsText.detail()),
              SizedBox(height: DsSpace.md),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                DsButton('CANCELAR',
                    kind: DsButtonKind.ghost,
                    onPressed: () => Navigator.of(ctx).pop(false)),
                SizedBox(width: DsSpace.sm),
                DsButton('PUBLICAR',
                    key: const ValueKey('sprite-publish-confirm'),
                    kind: DsButtonKind.primary,
                    onPressed: () => Navigator.of(ctx).pop(true)),
              ]),
            ]),
          ),
        ),
      ),
    );
    if (ok == true) await c.publish();
  }

  @override
  Widget build(BuildContext context) {
    final e = c.selected;
    final over = e != null && c.catalog.hasOverride(e.id);
    final v = c.validation;
    final exp = c.expectedSize;
    return SingleChildScrollView(
      padding: EdgeInsets.all(DsSpace.sm),
      child: DsCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const DsSectionHeader('FICHA'),
          if (e == null)
            Text('Sin selección.', style: DsText.detail())
          else ...[
            _kv('ID', e.id),
            _kv('CATEGORÍA', e.category.label),
            _kv('RUTA', e.path ?? '(procedural) → ${e.publishPath}'),
            _kv('TAMAÑO', exp == null ? '—' : '${exp.$1}x${exp.$2}'),
            _kv('ESTADO', over ? 'OVERRIDE LOCAL' : e.procedural ? 'DIBUJO EN CÓDIGO' : 'ASSET DEL REPO'),
            SizedBox(height: DsSpace.sm),
            DsButton('REEMPLAZAR PNG',
                key: const ValueKey('sprite-replace'),
                kind: DsButtonKind.primary,
                onPressed: c.canWrite ? c.pickAndReplace : null),
            SizedBox(height: DsSpace.xs),
            DsButton('DESCARTAR OVERRIDE',
                key: const ValueKey('sprite-discard'),
                kind: DsButtonKind.ghost,
                onPressed: over ? c.discard : null),
            if (v != null) ...[
              const DsSectionHeader('VALIDACIÓN'),
              for (final m in v.errors) Text('✕ $m', style: DsText.detail(DsColors.danger)),
              for (final m in v.warnings) Text('! $m', style: DsText.detail(DsColors.warning)),
              if (v.ok && v.warnings.isEmpty) Text('✓ PNG válido', style: DsText.detail(DsColors.success)),
            ],
          ],
          const DsSectionHeader('OVERRIDES LOCALES'),
          Text(c.overrides?.root ?? 'Sin disco (solo lectura)', style: DsText.detail()),
          SizedBox(height: DsSpace.xs),
          DsButton('RECARGAR ARTE',
              key: const ValueKey('sprite-reload'), onPressed: c.reloadAll),
          const DsSectionHeader('PAQUETE DE ARTE'),
          Row(children: [
            Expanded(
              child: DsButton('EXPORTAR',
                  key: const ValueKey('sprite-export'),
                  onPressed: c.canWrite ? c.exportPack : null),
            ),
            SizedBox(width: DsSpace.xs),
            Expanded(
              child: DsButton('IMPORTAR',
                  key: const ValueKey('sprite-import'),
                  onPressed: c.canWrite ? c.importPack : null),
            ),
          ]),
          const DsSectionHeader('REPO'),
          DsButton('PUBLICAR AL REPO (${c.publishable.length})',
              key: const ValueKey('sprite-publish'),
              onPressed: c.canWrite && c.repoPath != null && c.publishable.isNotEmpty
                  ? () => _confirmPublish(context)
                  : null),
        ]),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 100, child: Text(k, style: DsText.detail())),
          Expanded(child: Text(v, style: DsText.body())),
        ]),
      );
}
