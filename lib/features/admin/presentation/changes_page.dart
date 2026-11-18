import 'package:material_ui/material_ui.dart';

import '../domain/balance_diff.dart';
import 'admin_controller.dart';
import 'admin_widgets.dart';

/// Pestaña Cambios: diff de lo pendiente (balance.json guardado →
/// borrador) y guardar (docs/specs/balance_admin.md § 5).
class ChangesPage extends StatelessWidget {
  const ChangesPage({super.key, required this.c});
  final AdminController c;

  @override
  Widget build(BuildContext context) {
    final changes = c.pendingChanges;
    final theme = Theme.of(context);
    final errors = c.draftIssues.where((i) => i.error).toList();
    final warnings = c.draftIssues.where((i) => !i.error).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(
          child: Text('Cambios pendientes (${changes.length})', style: theme.textTheme.headlineSmall),
        ),
        TextButton.icon(
          icon: const Icon(Icons.delete_sweep_outlined),
          label: const Text('Descartar todo'),
          onPressed: changes.isEmpty ? null : c.discardAll,
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          icon: const Icon(Icons.save),
          label: const Text('Guardar balance.json'),
          onPressed: c.canSave && changes.isNotEmpty ? c.save : null,
        ),
      ]),
      if (c.fileStatus != null) Text(c.fileStatus!, style: theme.textTheme.bodySmall),
      Text('Hash: guardado ${c.saved.hash} · borrador ${c.validDraft.hash}',
          style: theme.textTheme.bodySmall),
      const SizedBox(height: 12),
      for (final i in errors) IssueTile(i),
      for (final i in warnings) IssueTile(i),
      for (final i in c.savedIssues) IssueTile(i),
      if (changes.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Sin cambios respecto del balance.json guardado.')),
        ),
      ..._grouped(context, changes),
    ]);
  }

  List<Widget> _grouped(BuildContext context, List<BalanceChange> changes) {
    final out = <Widget>[];
    String? last;
    for (final ch in changes) {
      final key = '${ch.kind.jsonKey}.${ch.id}';
      if (key != last) {
        last = key;
        out.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: InkWell(
            onTap: () => c.selectRef(ch.kind, ch.id),
            child: Row(children: [
              KindBadge(ch.kind.singular),
              const SizedBox(width: 8),
              Text(ch.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 8),
              Text(ch.id, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ));
      }
      final up = ch.increased;
      out.add(Card(
        margin: const EdgeInsets.only(bottom: 4),
        child: ListTile(
          dense: true,
          leading: Icon(
            up == null
                ? Icons.swap_horiz
                : up
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
            color: up == null
                ? null
                : up
                    ? Colors.green.shade400
                    : Colors.orange.shade300,
          ),
          title: Text(ch.field.label),
          subtitle: Text('${ch.beforeText}  →  ${ch.afterText}'),
          trailing: IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Descartar este cambio',
            onPressed: () => c.revertField(ch.kind, ch.id, ch.field.key),
          ),
        ),
      ));
    }
    return out;
  }
}
