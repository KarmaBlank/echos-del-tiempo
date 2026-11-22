import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_text.dart';
import '../../../game_engine/models/world_save.dart';
import '../../characters/presentation/character_widgets.dart';
import 'worlds_providers.dart';

/// Elegir mundo en el título (town_loop.md § 11c): la lista agrupada por
/// etiqueta (Solitario / Cooperativo) y CREAR MUNDO / RENOMBRAR / BORRAR
/// (con confirmación). La etiqueta no bloquea nada: con cualquier mundo
/// se puede JUGAR SOLO o ABRIR SALA.
class WorldPicker extends ConsumerWidget {
  const WorldPicker({super.key, this.busy = false});

  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(worldBookProvider);
    final ctl = ref.read(worldBookProvider.notifier);
    if (book == null) return Text('Cargando mundos...', style: DsText.detail());
    final sel = book.selected;
    final groups = book.grouped;
    return Column(
      key: const ValueKey('world-picker'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('MUNDO (${book.worlds.length})', style: DsText.subtitle()),
        const SizedBox(height: 8),
        for (final l in WorldLabel.values)
          if (groups[l]!.isNotEmpty) ...[
            Text(l.text.toUpperCase(),
                key: ValueKey('world-group-${l.name}'),
                style: DsText.detail(ProtoColors.dim)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final w in groups[l]!)
                  DsButton(retroText(w.name),
                      key: ValueKey('world-${w.id}'),
                      selected: w.id == book.selectedId,
                      onPressed:
                          busy ? null : () => unawaited(ctl.select(w.id))),
              ],
            ),
            const SizedBox(height: 8),
          ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            DsButton('CREAR MUNDO',
                key: const ValueKey('world-create'),
                onPressed: busy
                    ? null
                    : () async {
                        final r = await _dialog<(String, WorldLabel)>(
                            context, (_) => const _CreateWorldDialog());
                        if (r != null) await ctl.create(r.$1, r.$2);
                      }),
            DsButton('RENOMBRAR MUNDO',
                key: const ValueKey('world-rename'),
                onPressed: busy || sel == null
                    ? null
                    : () async {
                        final n = await _dialog<String>(
                            context, (_) => _RenameWorldDialog(sel));
                        if (n != null) await ctl.rename(sel.id, n);
                      }),
            DsButton('BORRAR MUNDO',
                key: const ValueKey('world-delete'),
                accent: DsColors.danger,
                onPressed: busy || sel == null
                    ? null
                    : () async {
                        final ok = await _dialog<bool>(
                            context, (_) => _DeleteWorldDialog(sel));
                        if (ok ?? false) await ctl.remove(sel.id);
                      }),
          ],
        ),
      ],
    );
  }
}

Future<T?> _dialog<T>(BuildContext context, WidgetBuilder builder) =>
    showDialog<T>(
      context: context,
      barrierColor: ProtoColors.scrim(0.6),
      builder: (ctx) =>
          Material(type: MaterialType.transparency, child: builder(ctx)),
    );

class _CreateWorldDialog extends StatefulWidget {
  const _CreateWorldDialog();

  @override
  State<_CreateWorldDialog> createState() => _CreateWorldDialogState();
}

class _CreateWorldDialogState extends State<_CreateWorldDialog> {
  final _name = TextEditingController();
  var _label = WorldLabel.cooperativo;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _ok() => Navigator.of(context).pop((_name.text, _label));

  @override
  Widget build(BuildContext context) => PanelFrame(
        key: const ValueKey('world-create-dialog'),
        title: 'CREAR MUNDO',
        width: 480,
        onClose: () => Navigator.of(context).pop(),
        actions: [
          PanelButton('CANCELAR',
              key: const ValueKey('world-create-cancel'),
              onPressed: () => Navigator.of(context).pop()),
          PanelButton('CREAR',
              key: const ValueKey('world-create-ok'), onPressed: _ok),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('Nombre:'),
              const SizedBox(width: 8),
              Expanded(
                child: RetroTextField(
                  key: const ValueKey('world-create-name'),
                  controller: _name,
                  autofocus: true,
                  hint: 'Mundo nuevo',
                  maxLength: WorldSave.maxName,
                  onSubmitted: (_) => _ok(),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final l in WorldLabel.values)
                PanelButton(l.text.toUpperCase(),
                    key: ValueKey('world-label-${l.name}'),
                    selected: _label == l,
                    onPressed: () => setState(() => _label = l)),
            ]),
            const SizedBox(height: 8),
            Text(
                retroText('La etiqueta solo agrupa la lista: cualquier mundo '
                    'se juega solo o se abre como sala.'),
                style: DsText.detail(ProtoColors.dim)),
          ],
        ),
      );
}

class _RenameWorldDialog extends StatefulWidget {
  const _RenameWorldDialog(this.world);
  final WorldSave world;

  @override
  State<_RenameWorldDialog> createState() => _RenameWorldDialogState();
}

class _RenameWorldDialogState extends State<_RenameWorldDialog> {
  late final _name = TextEditingController(text: widget.world.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _ok() => Navigator.of(context).pop(_name.text);

  @override
  Widget build(BuildContext context) => PanelFrame(
        key: const ValueKey('world-rename-dialog'),
        title: 'RENOMBRAR MUNDO',
        width: 420,
        onClose: () => Navigator.of(context).pop(),
        actions: [
          PanelButton('CANCELAR', onPressed: () => Navigator.of(context).pop()),
          PanelButton('GUARDAR',
              key: const ValueKey('world-rename-ok'), onPressed: _ok),
        ],
        child: RetroTextField(
          key: const ValueKey('world-rename-field'),
          controller: _name,
          autofocus: true,
          maxLength: WorldSave.maxName,
          onSubmitted: (_) => _ok(),
        ),
      );
}

class _DeleteWorldDialog extends StatelessWidget {
  const _DeleteWorldDialog(this.world);
  final WorldSave world;

  @override
  Widget build(BuildContext context) => PanelFrame(
        key: const ValueKey('world-delete-dialog'),
        title: 'BORRAR MUNDO',
        width: 520,
        onClose: () => Navigator.of(context).pop(false),
        actions: [
          PanelButton('CANCELAR',
              key: const ValueKey('world-delete-cancel'),
              onPressed: () => Navigator.of(context).pop(false)),
          PanelButton('BORRAR',
              key: const ValueKey('world-delete-ok'),
              accent: ProtoColors.red,
              onPressed: () => Navigator.of(context).pop(true)),
        ],
        child: Text(
            retroText('Vas a borrar el mundo "${world.name}" con su pueblo. '
                'Los personajes no se tocan. No se puede deshacer.'),
            style: const TextStyle(color: ProtoColors.red)),
      );
}
