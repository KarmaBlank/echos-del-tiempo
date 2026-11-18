import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/release_plan.dart';
import 'admin_controller.dart';
import 'admin_widgets.dart';

/// Pestaña Parche: versión, notas auto-generadas y editables, archivos y
/// pasos de publicación (docs/specs/balance_admin.md § 5).
class PatchPage extends StatefulWidget {
  const PatchPage({super.key, required this.c});
  final AdminController c;

  @override
  State<PatchPage> createState() => _PatchPageState();
}

class _PatchPageState extends State<PatchPage> {
  late final TextEditingController notes = TextEditingController(text: widget.c.notes);
  late final TextEditingController repo = TextEditingController(text: widget.c.repoPath ?? '');

  AdminController get c => widget.c;

  @override
  void didUpdateWidget(PatchPage old) {
    super.didUpdateWidget(old);
    if (!c.notesEdited && notes.text != c.notes) notes.text = c.notes;
  }

  @override
  void dispose() {
    notes.dispose();
    repo.dispose();
    super.dispose();
  }

  Future<void> _confirmRelease() async {
    final version = c.nextVersion;
    final typed = TextEditingController();
    var dryRun = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('¿Correr tool/release.ps1 para v$version?'),
          content: SizedBox(
            width: 480,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Se va a ejecutar en ${ReleasePlan.releaseWorktree}:'),
              const SizedBox(height: 4),
              SelectableText(
                  'powershell ${c.plan.scriptArgs(dryRun: dryRun).join(' ')}',
                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 12)),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: dryRun,
                onChanged: (v) => set(() => dryRun = v ?? true),
                title: const Text('-DryRun (arma todo, no commitea, no pushea, no publica)'),
              ),
              if (!dryRun)
                Text(
                    'SIN -DryRun: commitea la versión en main, hace push a origin y '
                    'crea el release v$version en GitHub. Requiere main limpio y al día '
                    'con el parche ya mergeado.',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              const SizedBox(height: 8),
              Text('Escribí la versión para confirmar: $version'),
              TextField(controller: typed, onChanged: (_) => set(() {})),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: typed.text.trim() == version ? () => Navigator.pop(ctx, true) : null,
              child: Text(dryRun ? 'Correr DryRun v$version' : 'Publicar v$version'),
            ),
          ],
        ),
      ),
    );
    typed.dispose();
    if (ok == true) {
      await c.runRelease(confirmedVersion: version, dryRun: dryRun);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = c.plan;
    final changes = c.patchChanges;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Generar parche', style: theme.textTheme.headlineSmall),
      const SizedBox(height: 8),
      SectionCard(
        title: 'Repo y versión',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: repo,
                decoration: const InputDecoration(
                    labelText: 'Carpeta del repo (echos-del-tiempo)', isDense: true),
                onSubmitted: c.setRepoPath,
              ),
            ),
            TextButton(onPressed: () => c.setRepoPath(repo.text), child: const Text('Usar')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Text(
                'pubspec ${c.currentVersion ?? '?'} · último release '
                '${c.latestReleased ?? (c.releasesLoading ? '…' : '?')}  →  ',
                style: theme.textTheme.titleMedium),
            Text('v${c.nextVersion}',
                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(width: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('PATCH')),
                ButtonSegment(value: true, label: Text('MINOR')),
              ],
              selected: {c.minorBump},
              onSelectionChanged: (s) => c.setMinor(s.first),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Notas comparadas contra ${c.releasedSource}: ${changes.length} cambios.',
              style: theme.textTheme.bodySmall),
        ]),
      ),
      SectionCard(
        title: 'Notas del parche (editables)',
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Regenerar desde el diff'),
            onPressed: () {
              c.regenerateNotes();
              notes.text = c.notes;
            },
          ),
        ],
        child: TextField(
          controller: notes,
          minLines: 10,
          maxLines: 22,
          style: const TextStyle(fontFamily: 'Consolas', fontSize: 13),
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onChanged: c.editNotes,
        ),
      ),
      SectionCard(
        title: 'Archivos',
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.save_alt),
            label: const Text('Escribir archivos'),
            onPressed: c.canSave ? c.writePatchFiles : null,
          ),
        ],
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('• ${ReleasePlan.balancePath}  (hash ${c.validDraft.hash})'),
          Text('• ${plan.notesPath}'),
          if (c.patchStatus != null) ...[
            const SizedBox(height: 6),
            Text(c.patchStatus!, style: TextStyle(color: theme.colorScheme.primary)),
          ],
        ]),
      ),
      SectionCard(
        title: 'Pasos para publicar v${plan.version}',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final (i, s) in plan.steps().indexed) _Step(index: i + 1, step: s),
          const Divider(),
          Row(children: [
            Expanded(
              child: Text(
                  c.host.supportsProcesses
                      ? 'O correr release.ps1 desde acá (con confirmación y salida en vivo).'
                      : 'Esta plataforma no puede correr procesos.',
                  style: theme.textTheme.bodySmall),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.rocket_launch_outlined),
              label: const Text('Correr release.ps1…'),
              onPressed: c.host.supportsProcesses && !c.releaseRunning ? _confirmRelease : null,
            ),
          ]),
          if (c.releaseLog.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              height: 220,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.black,
              child: ListView(reverse: true, children: [
                for (final l in c.releaseLog.reversed)
                  Text(l, style: const TextStyle(fontFamily: 'Consolas', fontSize: 12, color: Colors.white)),
              ]),
            ),
            if (c.releaseExit != null) Text('Terminó con código ${c.releaseExit}.'),
          ],
        ]),
      ),
    ]);
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.index, required this.step});
  final int index;
  final ReleaseStep step;

  @override
  Widget build(BuildContext context) {
    final text = step.commands.join('\n');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$index. ${step.title}', style: Theme.of(context).textTheme.titleSmall),
        Text(step.detail, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: SelectableText(text,
                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 12.5)),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              tooltip: 'Copiar',
              onPressed: () => Clipboard.setData(ClipboardData(text: text)),
            ),
          ]),
        ),
      ]),
    );
  }
}
