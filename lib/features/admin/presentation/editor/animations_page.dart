import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../core/audio/sfx_catalog.dart' show Sfx;
import '../../../../core/fx/fx_catalog.dart';
import '../field_editors.dart' show NumberStepper;
import 'fx_editor_controller.dart';
import 'fx_preview.dart';

/// Visuales → Animaciones (docs/specs/game_editor.md § 3.2 y § 6):
/// lista por categoría + buscador | mini escena de batalla con
/// reproducción | ficha con parámetros de keyframes; la línea de tiempo
/// ocupa la franja inferior.
class AnimationsPage extends StatefulWidget {
  const AnimationsPage({super.key, required this.c, this.ticking = true});
  final FxEditorController c;

  /// `false` en capturas: el reloj no avanza solo.
  final bool ticking;

  @override
  State<AnimationsPage> createState() => _AnimationsPageState();
}

class _AnimationsPageState extends State<AnimationsPage>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  Duration _last = Duration.zero;
  final sim = FxPreviewSim();

  @override
  void initState() {
    super.initState();
    if (widget.ticking) {
      _ticker = createTicker((now) {
        final dt = (now - _last).inMicroseconds / 1000;
        _last = now;
        widget.c.advance(dt.clamp(0, 50));
      });
      widget.c.addListener(_syncTicker);
      _syncTicker();
    }
  }

  /// El reloj corre solo mientras se reproduce (game_editor.md § 7.5).
  void _syncTicker() {
    final t = _ticker;
    if (t == null) return;
    if (widget.c.playing && !t.isActive) {
      _last = Duration.zero;
      t.start();
    } else if (!widget.c.playing && t.isActive) {
      t.stop();
    }
  }

  @override
  void dispose() {
    if (_ticker != null) widget.c.removeListener(_syncTicker);
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): c.undo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): c.redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): c.redo,
        const SingleActivator(LogicalKeyboardKey.delete): () {
          if (c.selectedKey case final k?) c.removeKey(k);
        },
      },
      child: Focus(
        autofocus: true,
        child: ListenableBuilder(
      listenable: c,
      builder: (context, _) => Stack(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: 320, child: _Browser(c: c)),
          const VerticalDivider(width: 2, thickness: 2, color: DsColors.border),
          Expanded(child: _Stage(c: c, sim: sim)),
          const VerticalDivider(width: 2, thickness: 2, color: DsColors.border),
          SizedBox(width: 360, child: _Properties(c: c)),
        ]),
        if (c.notice != null)
          Positioned(
            left: 336,
            right: 376,
            bottom: DsSpace.md,
            child: DsToast(c.notice!.text,
                key: const ValueKey('fx-notice'),
                kind: c.notice!.error
                    ? DsToastKind.danger
                    : c.notice!.ok
                        ? DsToastKind.success
                        : DsToastKind.info,
                onClose: c.clearNotice),
          ),
      ]),
        ),
      ),
    );
  }
}

class _Browser extends StatelessWidget {
  const _Browser({required this.c});
  final FxEditorController c;

  @override
  Widget build(BuildContext context) {
    final items = c.visible;
    final cats = [
      for (final k in kFxCategories)
        if (c.countOf(k) > 0) k
    ];
    return Padding(
      padding: EdgeInsets.all(DsSpace.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DsSearchField(
            key: const ValueKey('fx-search'),
            hint: 'BUSCAR ANIMACIÓN',
            width: 300,
            onChanged: c.setQuery)
            .tip('Filtra la lista por id, nombre o etiqueta.'),
        SizedBox(height: DsSpace.sm),
        for (final cat in <String?>[null, ...cats])
          DsListRow(
            key: ValueKey('fx-cat-${cat ?? 'all'}'),
            compact: true,
            title: cat == null ? 'TODO' : kFxCategoryLabels[cat] ?? cat,
            trailing: Text('${c.countOf(cat)}', style: DsText.detail()),
            selected: c.category == cat,
            onTap: () => c.setCategory(cat),
            tooltip: DsTooltipCard(
                title: cat == null
                    ? 'Muestra todas las animaciones.'
                    : 'Muestra solo esta categoría.'),
          ),
        DsSectionHeader('${items.length} ANIMACIONES'),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) {
              final id = items[i];
              final t = c.timelineOf(id)!;
              final src = c.catalog.sourceOf(id);
              return DsListRow(
                key: ValueKey('fx-row-$id'),
                compact: true,
                title: t.name,
                detail: '${t.duration} ms',
                trailing: switch (src) {
                  FxSource.override => const DsBadge('OVERRIDE'),
                  FxSource.legacy => const DsBadge('LEGACY'),
                  _ => const DsBadge('DATOS'),
                },
                selected: c.selectedId == id,
                onTap: () => c.select(id),
                tooltip: const DsTooltipCard(
                    title: 'Abre esta animación en la vista previa '
                        '(arranca en pausa).'),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.c, required this.sim});
  final FxEditorController c;
  final FxPreviewSim sim;

  @override
  Widget build(BuildContext context) {
    final t = c.edit;
    if (t == null) {
      return Center(
          child: Text('ELEGÍ UNA ANIMACIÓN A LA IZQUIERDA', style: DsText.detail()));
    }
    final cls = previewClassOf(t);
    final img = c.spriteImage;
    final rows = t.tracks.length;
    return Padding(
      padding: EdgeInsets.all(DsSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('${t.name} · ${t.id}', style: DsText.subtitle())),
          if (c.dirty) const DsBadge('SIN GUARDAR'),
        ]),
        SizedBox(height: DsSpace.sm),
        Expanded(
          // Solo el lienzo escucha el reloj (game_editor.md § 7.5).
          child: RepaintBoundary(
            child: ClipRect(
              child: ValueListenableBuilder<double>(
                valueListenable: c.clock,
                builder: (context, time, _) => CustomPaint(
                  key: const ValueKey('fx-preview'),
                  painter: FxPreviewPainter(
                    timeline: t,
                    time: time,
                    sim: sim,
                    enemies: c.enemies,
                    camera: c.camera,
                    hero: img?.call('characters.$cls.idle'),
                    partner: img?.call('characters.maga.idle'),
                    enemyImages: [
                      for (final e in const ['slime', 'bat', 'golem', 'ghost'])
                        img?.call('enemies.$e.idle'),
                    ],
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: DsSpace.sm),
        // Transporte: reproducir/pausa, velocidad, loop, cámara, enemigos.
        Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
          DsButton(c.playing ? 'PAUSA' : 'REPRODUCIR',
              key: const ValueKey('fx-play'),
              tooltip: 'Reproduce o pausa la vista previa (con sus sonidos).',
              kind: DsButtonKind.primary,
              size: DsButtonSize.compact,
              onPressed: c.togglePlay),
          for (final s in const [0.25, 0.5, 1.0])
            DsButton('×${s == 1 ? '1' : s}',
                key: ValueKey('fx-speed-$s'),
                tooltip: 'Velocidad de la vista previa: ×$s del tiempo real. '
                    'Los sonidos salen en su momento, sin cambiar el tono.',
                size: DsButtonSize.compact,
                selected: c.speed == s,
                onPressed: () => c.setSpeed(s)),
          DsButton('LOOP',
              key: const ValueKey('fx-loop'),
              tooltip: 'Al terminar vuelve a empezar (si no, se detiene al final).',
              size: DsButtonSize.compact,
              selected: c.loop,
              onPressed: () => c.setLoop(!c.loop)),
          DsButton('CÁMARA',
              key: const ValueKey('fx-camera'),
              tooltip: 'Aplica la pista de cámara (zoom y foco). Apagada se ve '
                  'la escena entera.',
              size: DsButtonSize.compact,
              selected: c.camera,
              onPressed: () => c.setCamera(!c.camera)),
          for (final n in const [1, 2, 3, 4])
            DsButton('$n ENEM.',
                key: ValueKey('fx-enemies-$n'),
                tooltip: 'Cantidad de enemigos de la escena de prueba ($n).',
                size: DsButtonSize.compact,
                selected: c.enemies == n,
                onPressed: () => c.setEnemies(n)),
          DsButton(c.muted ? 'SIN SONIDO' : 'SONIDO',
              key: const ValueKey('fx-mute'),
              tooltip: 'Silencia o activa los sonidos de la vista previa. '
                  'ESCUCHAR suena igual.',
              size: DsButtonSize.compact,
              selected: !c.muted,
              onPressed: () => c.setMuted(!c.muted)),
          ValueListenableBuilder<double>(
              valueListenable: c.clock,
              builder: (context, time, _) => Text(
                  '${time.round()} / ${t.duration} ms',
                  key: const ValueKey('fx-time'),
                  style: DsText.detail())),
        ]),
        SizedBox(height: DsSpace.sm),
        // Edición de la línea de tiempo (paso 3, game_editor.md § 7.3).
        Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
          DsButton('DESHACER',
              key: const ValueKey('fx-undo'),
              tooltip: 'Deshace el último cambio (Ctrl+Z).',
              size: DsButtonSize.compact,
              onPressed: c.canUndo && !c.readOnly ? c.undo : null),
          DsButton('REHACER',
              key: const ValueKey('fx-redo'),
              tooltip: 'Rehace lo deshecho (Ctrl+Y).',
              size: DsButtonSize.compact,
              onPressed: c.canRedo && !c.readOnly ? c.redo : null),
          DsButton('IMÁN',
              key: const ValueKey('fx-snap'),
              tooltip: 'Al arrastrar, pega el key a otro key cercano (25 ms) '
                  'o redondea a 10 ms.',
              size: DsButtonSize.compact,
              selected: c.snap,
              onPressed: () => c.setSnap(!c.snap)),
          DsButton('+ KEY',
              key: const ValueKey('fx-add-key'),
              tooltip: 'Agrega un key en el cabezal de la pista elegida '
                  '(copia los valores del anterior).',
              size: DsButtonSize.compact,
              onPressed: c.readOnly || c.selectedTrack == null
                  ? null
                  : () => c.addKey(c.selectedTrack!, c.time)),
          DsButton('BORRAR KEY',
              key: const ValueKey('fx-del-key'),
              tooltip: 'Borra el key elegido (Supr).',
              size: DsButtonSize.compact,
              onPressed: c.readOnly || c.selectedKey == null
                  ? null
                  : () => c.removeKey(c.selectedKey!)),
          DsButton('DUPLICAR PISTA',
              key: const ValueKey('fx-dup-track'),
              tooltip: 'Copia la pista elegida justo debajo, con todos sus keys.',
              size: DsButtonSize.compact,
              onPressed: c.readOnly || c.selectedTrack == null
                  ? null
                  : () => c.duplicateTrack(c.selectedTrack!)),
          DsButton('BORRAR PISTA',
              key: const ValueKey('fx-del-track'),
              tooltip: 'Borra la pista elegida y sus keys.',
              size: DsButtonSize.compact,
              onPressed: c.readOnly || c.selectedTrack == null
                  ? null
                  : () => c.removeTrack(c.selectedTrack!)),
          DsButton('CAPA DE ECOS',
              key: const ValueKey('fx-echo-layer'),
              tooltip: 'Agrega una pista de ecos: 3 copias del lanzador que '
                  'llegan al objetivo justo antes del primer impacto.',
              size: DsButtonSize.compact,
              onPressed: c.readOnly ? null : c.addEchoLayer),
          if (t.legacy)
            DsButton('CONVERTIR A DATOS',
                key: const ValueKey('fx-convert'),
                tooltip: 'Copia esta animación del código a datos editables '
                    '(ecos, anillo y partículas en el impacto). GUARDAR crea el '
                    'override.',
                kind: DsButtonKind.primary,
                size: DsButtonSize.compact,
                onPressed: c.convertToData),
          Text('DOBLE CLIC: KEY NUEVO · ARRASTRAR: MOVER', style: DsText.detail()),
        ]),
        SizedBox(height: DsSpace.xs),
        // Línea de tiempo (scrub con clic/arrastre; clic en un rombo lo elige).
        SizedBox(
          height: FxTimelinePainter.rulerH + rows * FxTimelinePainter.rowH + 4,
          child: LayoutBuilder(builder: (context, box) => DsTooltip(
            card: const DsTooltipCard(
                title: 'Línea de tiempo: clic elige un key o mueve el cabezal; '
                    'arrastrar mueve el key o hace scrub (sin sonido); doble '
                    'clic agrega un key.'),
            child: Builder(builder: (context) {
            void scrub(Offset p) {
              final x = p.dx - FxTimelinePainter.labelW;
              final w = box.maxWidth - FxTimelinePainter.labelW - 8;
              c.seek(x / w * t.duration);
            }

            double msAt(Offset p) {
              final x = p.dx - FxTimelinePainter.labelW;
              final w = box.maxWidth - FxTimelinePainter.labelW - 8;
              return x / w * t.duration;
            }

            int? rowAt(Offset p) {
              final row = ((p.dy - FxTimelinePainter.rulerH) / FxTimelinePainter.rowH).floor();
              return p.dy < FxTimelinePainter.rulerH || row < 0 || row >= rows ? null : row;
            }

            FxKeyRef? keyAt(Offset p) {
              final row = rowAt(p);
              if (row == null) return null;
              final tr = t.tracks[row];
              FxKeyRef? best;
              var bestD = 7.0;
              for (final (fire, list) in [(false, tr.keys), (true, tr.fires)]) {
                for (var k = 0; k < list.length; k++) {
                  final x = FxTimelinePainter.xOf(
                      list[k].t.toDouble(), t.duration.toDouble(), box.maxWidth);
                  final d = (x - p.dx).abs();
                  if (d < bestD) {
                    bestD = d;
                    best = (track: row, fire: fire, index: k);
                  }
                }
              }
              return best;
            }

            void pick(Offset p) {
              final row = rowAt(p);
              if (row == null) {
                scrub(p);
                return;
              }
              final best = keyAt(p);
              if (best != null) {
                c.selectKey(best);
              } else {
                c.selectTrack(row);
                scrub(p);
              }
            }

            // Arrastrar un rombo lo mueve (con imán); arrastrar en vacío
            // hace scrub. Doble clic en una fila agrega un key ahí.
            return GestureDetector(
              key: const ValueKey('fx-timeline'),
              onTapDown: (d) => pick(d.localPosition),
              onDoubleTapDown: (d) {
                final row = rowAt(d.localPosition);
                if (row != null && keyAt(d.localPosition) == null) {
                  c.addKey(row, msAt(d.localPosition));
                }
              },
              onDoubleTap: () {},
              onHorizontalDragStart: (d) {
                final k = keyAt(d.localPosition);
                if (k != null && !c.readOnly) c.beginDrag(k);
              },
              onHorizontalDragUpdate: (d) => c.dragging
                  ? c.dragTo(msAt(d.localPosition))
                  : scrub(d.localPosition),
              onHorizontalDragEnd: (_) => c.endDrag(),
              child: RepaintBoundary(
                child: ValueListenableBuilder<double>(
                  valueListenable: c.clock,
                  builder: (context, time, _) => CustomPaint(
                    painter: FxTimelinePainter(
                        timeline: t,
                        time: time,
                        selectedTrack: c.selectedTrack,
                        selectedKey: c.selectedKey),
                    size: Size.infinite,
                  ),
                ),
              ),
            );
          }))),
        ),
      ]),
    );
  }
}

class _Properties extends StatelessWidget {
  const _Properties({required this.c});
  final FxEditorController c;

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
                  'Copia ${list.length} animaciones a assets/fx/ y '
                  '${c.publishableSounds} sonidos a assets/sfx/, y actualiza '
                  'los manifests en ${c.repoPath}. Los overrides publicados '
                  'se borran de la carpeta local. Después falta el commit.',
                  style: DsText.body()),
              SizedBox(height: DsSpace.sm),
              for (final e in list.entries.take(8))
                Text('· ${e.key} → ${e.value}', style: DsText.detail()),
              SizedBox(height: DsSpace.md),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                DsButton('CANCELAR',
                    tooltip: 'Cierra sin publicar.',
                    kind: DsButtonKind.ghost,
                    onPressed: () => Navigator.of(ctx).pop(false)),
                SizedBox(width: DsSpace.sm),
                DsButton('PUBLICAR',
                    key: const ValueKey('fx-publish-confirm'),
                    tooltip: 'Copia los overrides al repo y los borra de la '
                        'carpeta local.',
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
    final t = c.edit;
    final id = c.selectedId;
    final src = id == null ? null : c.catalog.sourceOf(id);
    final key = c.selectedKey == null ? null : c.keyOf(c.selectedKey!);
    final warn = c.validation;
    return SingleChildScrollView(
      padding: EdgeInsets.all(DsSpace.sm),
      child: DsCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const DsSectionHeader('FICHA'),
          if (t == null)
            Text('Sin selección.', style: DsText.detail())
          else ...[
            _kv('ID', t.id),
            _kv('CATEGORÍA', kFxCategoryLabels[t.category] ?? t.category),
            _kv('OBJETIVOS', t.targets),
            _kv('ETIQUETAS', t.tags.join(', ')),
            _kv('ESTADO', switch (src) {
              FxSource.override => 'OVERRIDE LOCAL',
              FxSource.legacy => 'CÓDIGO (SOLO LECTURA)',
              _ => 'ASSET DEL REPO',
            }),
            _kv('FASES', '${t.phases.build} / ${t.phases.release} / ${t.phases.recover} ms'),
            Row(children: [
              SizedBox(width: 100, child: Text('DURACIÓN', style: DsText.detail())),
              NumberStepper(
                  key: const ValueKey('fx-duration'),
                  value: t.duration,
                  step: 50,
                  min: 100,
                  max: kFxMaxDurationMs.toDouble(),
                  integer: true,
                  onChanged: c.readOnly ? (_) {} : (v) => c.setDuration(v.toInt()))
                  .tip('Duración total en ms (las fases se recortan si no entran).'),
            ]),
            if (key != null) ...[
              DsSectionHeader(
                  '${t.tracks[c.selectedKey!.track].type.toUpperCase()} · '
                  '${c.selectedKey!.fire ? 'DISPARO' : 'KEY'} ${c.selectedKey!.index + 1}'),
              _num('T (MS)', key.t, 10, (v) => c.setKeyTime(c.selectedKey!, v.toInt()),
                  integer: true,
                  tip: 'Momento del key en ms desde el inicio (también se '
                      'arrastra en la línea de tiempo).'),
              if (t.tracks[c.selectedKey!.track].type == 'sound')
                ..._sound(key),
              for (final e in key.data.entries)
                if (t.tracks[c.selectedKey!.track].type == 'sound' &&
                    const {'cue', 'vol', 'pitch'}.contains(e.key))
                  const SizedBox.shrink()
                else if (e.value is num)
                  _num(e.key.toUpperCase(), e.value! as num,
                      _stepFor(e.key), (v) => c.setKeyField(c.selectedKey!, e.key, v))
                else if (e.value is String && kFxFieldOptions[e.key] != null)
                  _choice(e.key, e.value! as String)
                else
                  _kv(e.key.toUpperCase(), '${e.value}'),
              if (!c.selectedKey!.fire) ...[
                SizedBox(height: DsSpace.xs),
                Text('CURVA DE LLEGADA', style: DsText.detail()),
                SizedBox(height: DsSpace.xs),
                Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
                  for (final e in FxEase.values)
                    DsButton(_easeLabel(e),
                        key: ValueKey('fx-ease-${e.name}'),
                        tooltip: _easeTip(e),
                        size: DsButtonSize.compact,
                        selected: key.ease == e,
                        onPressed: c.readOnly
                            ? null
                            : () => c.setKeyEase(c.selectedKey!, e)),
                ]),
              ],
            ] else if (c.selectedTrack != null && c.selectedTrack! < t.tracks.length) ...[
              DsSectionHeader('PISTA ${t.tracks[c.selectedTrack!].type.toUpperCase()}'),
              for (final e in t.tracks[c.selectedTrack!].props.entries)
                _kv(e.key.toUpperCase(), '${e.value}'),
              Text('Clic en un rombo o marca para editarlo; doble clic agrega.',
                  style: DsText.detail()),
            ] else
              Text('Clic en la línea de tiempo para elegir un key.',
                  style: DsText.detail()),
            if (!c.readOnly)
              DsFold(
                label: 'NUEVA PISTA', openLabel: 'NUEVA PISTA',
                tooltip: 'Muestra los tipos de pista que se pueden agregar.',
                child: Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
                  for (final type in FxEditorController.newTrackTypes)
                    DsButton(type.toUpperCase(),
                        key: ValueKey('fx-new-track-$type'),
                        tooltip: 'Agrega una pista ${type.toUpperCase()} con un '
                            'key de ejemplo.',
                        size: DsButtonSize.compact,
                        onPressed: () => c.addTrack(type)),
                ]),
              ),
            if (warn.isNotEmpty) ...[
              const DsSectionHeader('VALIDACIÓN'),
              for (final w in warn) Text('! $w', style: DsText.detail(DsColors.warning)),
            ],
            SizedBox(height: DsSpace.sm),
            DsButton('GUARDAR',
                key: const ValueKey('fx-save'),
                tooltip: 'Guarda la edición como override local (la usa el juego '
                    'de prueba y se recarga en caliente).',
                kind: DsButtonKind.primary,
                onPressed: c.canWrite && c.dirty && !c.readOnly ? c.save : null),
            SizedBox(height: DsSpace.xs),
            DsButton('DESHACER CAMBIOS',
                key: const ValueKey('fx-revert'),
                tooltip: 'Vuelve a lo último guardado sin escribir nada.',
                kind: DsButtonKind.ghost,
                onPressed: c.dirty ? c.revert : null),
            SizedBox(height: DsSpace.xs),
            DsButton('DESCARTAR OVERRIDE',
                key: const ValueKey('fx-discard'),
                tooltip: 'Borra el override local: vuelve la animación del repo.',
                kind: DsButtonKind.ghost,
                onPressed: src == FxSource.override ? c.discardOverride : null),
          ],
          const DsSectionHeader('OVERRIDES LOCALES'),
          Text(c.overrides?.root ?? 'Sin disco (solo lectura)', style: DsText.detail()),
          SizedBox(height: DsSpace.xs),
          DsButton('RECARGAR ANIMACIONES',
              key: const ValueKey('fx-reload'),
              tooltip: 'Relee los overrides del disco y descarta la edición en vivo.',
              onPressed: c.reloadAll),
          const DsSectionHeader('PAQUETE DE ARTE'),
          Row(children: [
            Expanded(
              child: DsButton('EXPORTAR',
                  key: const ValueKey('fx-export'),
                  tooltip: 'Guarda un zip con todos los overrides (sprites, '
                      'animaciones y sonidos) para pasarlo sin publicar.',
                  onPressed: c.canWrite ? c.exportPack : null),
            ),
            SizedBox(width: DsSpace.xs),
            Expanded(
              child: DsButton('IMPORTAR',
                  key: const ValueKey('fx-import'),
                  tooltip: 'Instala un paquete de arte (pisa overrides con el '
                      'mismo id).',
                  onPressed: c.canWrite ? c.importPack : null),
            ),
          ]),
          const DsSectionHeader('REPO'),
          DsButton('PUBLICAR AL REPO (${c.publishable.length + c.publishableSounds})',
              key: const ValueKey('fx-publish'),
              tooltip: 'Copia los overrides de animaciones y sonidos al repo '
                  '(después falta el commit).',
              onPressed: c.canWrite &&
                      c.repoPath != null &&
                      (c.publishable.isNotEmpty || c.publishableSounds > 0)
                  ? () => _confirmPublish(context)
                  : null),
        ]),
      ),
    );
  }

  static String _easeLabel(FxEase e) => switch (e) {
        FxEase.linear => 'LINEAL',
        FxEase.smooth => 'SUAVE',
        FxEase.easeIn => 'ENTRA',
        FxEase.easeOut => 'SALE',
        FxEase.snap => 'CORTE',
        FxEase.back => 'REBOTE',
      };

  /// Campo de texto con opciones conocidas (ancla, color, forma…): un
  /// botón por opción.
  Widget _choice(String field, String value) {
    final opts = {...kFxFieldOptions[field]!, value}.toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text(field.toUpperCase(), style: DsText.detail())),
        Expanded(
          child: Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
            for (final o in opts)
              DsButton(o.toUpperCase(),
                  key: ValueKey('fx-opt-$field-$o'),
                  tooltip: '${field.toUpperCase()}: usa $o.',
                  size: DsButtonSize.compact,
                  selected: o == value,
                  onPressed: c.readOnly
                      ? null
                      : () => c.setKeyText(c.selectedKey!, field, o)),
          ]),
        ),
      ]),
    );
  }

  static double _stepFor(String field) => switch (field) {
        'alpha' || 'v' || 'scale' || 'count' => 0.05,
        'angle' => 5,
        _ => 1,
      };

  static String _easeTip(FxEase e) => switch (e) {
        FxEase.linear => 'Curva de llegada: velocidad constante.',
        FxEase.smooth => 'Curva de llegada: arranca y frena suave.',
        FxEase.easeIn => 'Curva de llegada: arranca lento y acelera.',
        FxEase.easeOut => 'Curva de llegada: arranca rápido y frena.',
        FxEase.snap => 'Curva de llegada: salta de golpe al llegar.',
        FxEase.back => 'Curva de llegada: se pasa un poco y vuelve.',
      };

  /// Disparo de sonido (§ 7.6): sonido con buscador y ESCUCHAR, volumen,
  /// tono y reemplazo por archivo.
  List<Widget> _sound(FxKey key) {
    final r = c.selectedKey!;
    final cue = key.s('cue') ?? '';
    final real = c.soundIdFor(cue);
    final vol = key.d('vol', 1), pitch = key.d('pitch', 1);
    final choices = c.soundChoices;
    return [
      _kv('SONIDO', real == null ? '$cue (no suena)' : cue == real ? cue : '$cue → $real'),
      Row(children: [
        Expanded(
          child: DsButton('ESCUCHAR',
              key: const ValueKey('fx-sound-listen'),
              tooltip: 'Toca este sonido ya, con su volumen y tono.',
              size: DsButtonSize.compact,
              onPressed: real == null ? null : () => c.listen(cue, vol: vol, pitch: pitch)),
        ),
      ]),
      _num('VOLUMEN', vol, 0.05, (v) => c.setSoundLevel(r, 'vol', v.toDouble()),
          tip: 'Volumen del disparo (0 a 1) sobre el volumen de efectos.'),
      _num('TONO', pitch, 0.05, (v) => c.setSoundLevel(r, 'pitch', v.toDouble()),
          tip: 'Tono (0.5 a 2): más alto = más agudo y más corto. Solo WAV '
              'y sonidos sintetizados.'),
      SizedBox(height: DsSpace.xs),
      DsSearchField(
              key: const ValueKey('fx-sound-search'),
              hint: 'BUSCAR SONIDO',
              width: 320,
              onChanged: c.setSoundQuery)
          .tip('Filtra los sonidos por id (p. ej. hit, ult, ach.unlock).'),
      SizedBox(height: DsSpace.xs),
      SizedBox(
        height: 180,
        child: ListView.builder(
          itemCount: choices.length,
          itemBuilder: (_, i) {
            final id = choices[i];
            return DsListRow(
              key: ValueKey('fx-sound-opt-$id'),
              compact: true,
              title: id,
              trailing: c.soundOverridden(id) ? const DsBadge('ARCHIVO') : null,
              selected: id == cue,
              onTap: c.readOnly ? null : () => c.setSoundCue(r, id),
              tooltip: DsTooltipCard(
                  title: Sfx.ultParts.contains(id)
                      ? 'Usa el sonido propio de la ULT ($id).'
                      : 'Usa el sonido $id en este disparo.'),
            );
          },
        ),
      ),
      SizedBox(height: DsSpace.xs),
      Row(children: [
        Expanded(
          child: DsButton('REEMPLAZAR POR ARCHIVO',
              key: const ValueKey('fx-sound-replace'),
              tooltip: 'Elige un WAV u OGG que suena en lugar de este sonido '
                  '(override local, también en el juego de prueba).',
              size: DsButtonSize.compact,
              onPressed: c.canWrite && real != null ? () => c.replaceSound(real) : null),
        ),
        SizedBox(width: DsSpace.xs),
        Expanded(
          child: DsButton('SONIDO ORIGINAL',
              key: const ValueKey('fx-sound-revert'),
              tooltip: 'Borra el archivo de override: vuelve el sonido del repo.',
              size: DsButtonSize.compact,
              onPressed: real != null && c.soundOverridden(real)
                  ? () => c.revertSound(real)
                  : null),
        ),
      ]),
    ];
  }

  Widget _num(String k, num v, double step, ValueChanged<num> on,
          {bool integer = false, String? tip}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(children: [
          SizedBox(width: 100, child: Text(k, style: DsText.detail())),
          NumberStepper(
              key: ValueKey('fx-num-$k-${c.selectedId}-${c.selectedKey}'),
              value: v,
              step: step,
              integer: integer,
              onChanged: c.readOnly ? (_) {} : on)
              .tip(tip ?? 'Valor de ${k.toLowerCase()} del key (clic en las '
                  'flechas o escribí el número).'),
        ]),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 100, child: Text(k, style: DsText.detail())),
          Expanded(child: Text(v, style: DsText.body())),
        ]),
      );
}
