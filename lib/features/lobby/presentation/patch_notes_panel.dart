import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_type.dart';
import '../../../core/edition/game_edition.dart';
import '../../../game_engine/models/game_mode.dart';
import '../domain/patch_notes.dart';

/// VER NOTAS DEL PARCHE (docs/specs/title_screen.md § 4).
Future<void> showPatchNotes(BuildContext context, {AssetBundle? bundle}) =>
    showDialog<void>(
      context: context,
      barrierColor: ProtoColors.scrim(0.6),
      builder: (ctx) => Material(
        type: MaterialType.transparency,
        child: PatchNotesPanel(
            bundle: bundle, onClose: () => Navigator.of(ctx).maybePop()),
      ),
    );

/// Las notas de la edición actual empaquetadas en [bundle], la más nueva
/// primero.
Future<List<PatchNoteEntry>> loadPatchNoteIndex(AssetBundle bundle) async {
  final manifest = await AssetManifest.loadFromAssetBundle(bundle);
  final travesia = GameEdition.current.mode == GameModeKind.travesia;
  return patchNotesFrom(manifest.listAssets(),
      prefix: travesia ? 'travesia-' : '');
}

/// Versiones a la izquierda (la más nueva arriba), notas a la derecha con
/// ancho de lectura fijo y scroll con rueda, barra y teclado.
class PatchNotesPanel extends StatefulWidget {
  const PatchNotesPanel({super.key, this.bundle, this.onClose});

  final AssetBundle? bundle;
  final VoidCallback? onClose;

  /// Ancho de lectura de las notas (px nominales; crece con el texto).
  static const readingWidth = 600.0;

  @override
  State<PatchNotesPanel> createState() => _PatchNotesPanelState();
}

class _PatchNotesPanelState extends State<PatchNotesPanel> {
  final _scroll = ScrollController();
  final _notesFocus = FocusNode(debugLabel: 'patch-notes');
  List<PatchNoteEntry>? _entries;
  int _sel = 0;
  List<NoteBlock>? _blocks;
  String? _error;

  AssetBundle get _bundle => widget.bundle ?? rootBundle;

  @override
  void initState() {
    super.initState();
    unawaited(_loadIndex());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  Future<void> _loadIndex() async {
    try {
      final list = await loadPatchNoteIndex(_bundle);
      if (!mounted) return;
      setState(() => _entries = list);
      if (list.isNotEmpty) await _open(0);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudieron leer las notas.');
    }
  }

  Future<void> _open(int i) async {
    final list = _entries;
    if (list == null || i < 0 || i >= list.length) return;
    setState(() {
      _sel = i;
      _blocks = null;
    });
    try {
      final md = await _bundle.loadString(list[i].asset, cache: false);
      if (!mounted || _sel != i) return;
      setState(() => _blocks = parsePatchNotes(md));
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } catch (_) {
      if (mounted) setState(() => _blocks = const []);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent || !_scroll.hasClients) return KeyEventResult.ignored;
    final p = _scroll.position;
    final line = RetroType.em(context, 2, size: RetroType.body);
    final page = p.viewportDimension * 0.9;
    final k = e.logicalKey;
    double? to;
    if (k == LogicalKeyboardKey.arrowDown) to = p.pixels + line;
    if (k == LogicalKeyboardKey.arrowUp) to = p.pixels - line;
    if (k == LogicalKeyboardKey.pageDown || k == LogicalKeyboardKey.space) {
      to = p.pixels + page;
    }
    if (k == LogicalKeyboardKey.pageUp) to = p.pixels - page;
    if (k == LogicalKeyboardKey.home) to = 0;
    if (k == LogicalKeyboardKey.end) to = p.maxScrollExtent;
    if (k == LogicalKeyboardKey.arrowRight) {
      unawaited(_open(_sel + 1));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft) {
      unawaited(_open(_sel - 1));
      return KeyEventResult.handled;
    }
    if (to == null) return KeyEventResult.ignored;
    p.jumpTo(to.clamp(0, p.maxScrollExtent).toDouble());
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => PanelFrame(
        key: const ValueKey('patch-notes'),
        title: 'NOTAS DEL PARCHE',
        width: 980,
        fill: true,
        onClose: widget.onClose,
        actions: [
          DsButton('CERRAR',
              key: const ValueKey('patch-notes-close'),
              onPressed: widget.onClose),
        ],
        child: _body(),
      );

  Widget _body() {
    final entries = _entries;
    if (_error != null) return Text(retroText(_error!), style: DsText.body());
    if (entries == null) return Text('Cargando...', style: DsText.detail());
    if (entries.isEmpty) {
      return Text(retroText('No hay notas en esta versión.'),
          style: DsText.body());
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: RetroType.width(context, 168),
          child: ListView.builder(
            key: const ValueKey('patch-notes-versions'),
            itemCount: entries.length,
            itemBuilder: (context, i) => DsListRow(
              key: ValueKey('patch-notes-v${entries[i].version}'),
              title: 'v${entries[i].version}',
              detail: i == 0 ? 'última' : null,
              selected: i == _sel,
              compact: true,
              onTap: () => unawaited(_open(i)),
            ),
          ),
        ),
        SizedBox(width: DsSpace.md),
        Expanded(
          child: Focus(
            focusNode: _notesFocus,
            autofocus: true,
            onKeyEvent: _onKey,
            child: GestureDetector(
              onTap: _notesFocus.requestFocus,
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  key: const ValueKey('patch-notes-body'),
                  controller: _scroll,
                  padding: EdgeInsets.only(right: DsSpace.md),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: RetroType.width(
                              context, PatchNotesPanel.readingWidth)),
                      child: _notes(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _notes() {
    final blocks = _blocks;
    if (blocks == null) return Text('Cargando...', style: DsText.detail());
    final children = <Widget>[];
    for (final b in blocks) {
      switch (b.kind) {
        case NoteBlockKind.heading:
          if (children.isNotEmpty) children.add(SizedBox(height: DsSpace.md));
          children.add(Text(retroText(b.text),
              style: b.level <= 1 ? DsText.title() : DsText.subtitle()));
          children.add(SizedBox(height: DsSpace.sm));
        case NoteBlockKind.bullet:
          children.add(Padding(
            padding: EdgeInsets.only(
                left: DsSpace.md * b.level, bottom: DsSpace.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('·', style: DsText.body(DsColors.actionPrimary)),
                SizedBox(width: DsSpace.sm),
                Expanded(
                    child: Text(retroText(b.text), style: DsText.body())),
              ],
            ),
          ));
        case NoteBlockKind.paragraph:
          children.add(Padding(
            padding: EdgeInsets.only(bottom: DsSpace.sm),
            child: Text(retroText(b.text), style: DsText.body()),
          ));
      }
    }
    return Column(
      key: ValueKey('patch-notes-text-$_sel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
