import 'package:material_ui/material_ui.dart';

import '../../../game_engine/balance/balance_codecs.dart';
import '../../../game_engine/balance/balance_fields.dart';
import '../domain/admin_index.dart';
import '../domain/balance_diff.dart';
import 'admin_controller.dart';
import 'admin_widgets.dart';
import 'field_editors.dart';
import 'impact_panel.dart';

/// Pestaña Balance: navegador + editor + impacto (balance_admin.md § 5).
class BalancePage extends StatelessWidget {
  const BalancePage({super.key, required this.c});
  final AdminController c;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(width: 320, child: EntityBrowser(c: c)),
      const VerticalDivider(width: 1),
      Expanded(
        child: c.selected == null
            ? const Center(child: Text('Elegí una entidad a la izquierda.'))
            : EntityEditor(c: c, entry: c.selected!),
      ),
      if (c.selected?.kind != null) ...[
        const VerticalDivider(width: 1),
        SizedBox(width: 380, child: ImpactPanel(key: ValueKey(c.selected!.id), c: c, entry: c.selected!)),
      ],
    ]);
  }
}

/// Búsqueda + filtro por tipo + lista.
class EntityBrowser extends StatelessWidget {
  const EntityBrowser({super.key, required this.c});
  final AdminController c;

  @override
  Widget build(BuildContext context) {
    final items = c.visible;
    final scheme = Theme.of(context).colorScheme;
    final categories = <(String?, String)>[
      (null, 'Todo'),
      for (final k in BalanceKind.values) (k.jsonKey, k.plural),
      (AdminEntry.ascensionCategory, 'Ascensiones'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar (nombre, id, detalle)',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: c.setQuery,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Wrap(spacing: 4, runSpacing: 4, children: [
          for (final (key, label) in categories)
            ChoiceChip(
              label: Text(label, style: const TextStyle(fontSize: 12)),
              selected: c.category == key,
              showCheckmark: false,
              onSelected: (_) => c.setCategory(key),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
        child: Text('${items.length} entidades', style: Theme.of(context).textTheme.labelSmall),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final e = items[i];
            final touched = e.kind != null && c.isTouched(e.kind!, e.id);
            return ListTile(
              dense: true,
              selected: c.selected == e,
              leading: KindBadge(e.categoryLabel),
              title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(e.detail, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: touched
                  ? Tooltip(
                      message: 'Tiene cambios de balance',
                      child: Icon(Icons.edit_note, color: scheme.tertiary, size: 20))
                  : null,
              onTap: () => c.select(e),
            );
          },
        ),
      ),
    ]);
  }
}

bool _emptyish(Object? v) =>
    v == null || v == false || (v is num && v == 0) || (v is List && v.isEmpty) || (v is Map && v.isEmpty);

/// Editor tipado de una entidad: código / archivo / nuevo por campo.
class EntityEditor extends StatefulWidget {
  const EntityEditor({super.key, required this.c, required this.entry});
  final AdminController c;
  final AdminEntry entry;

  @override
  State<EntityEditor> createState() => _EntityEditorState();
}

class _EntityEditorState extends State<EntityEditor> {
  bool showAll = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final e = widget.entry;
    final theme = Theme.of(context);
    if (e.kind == null) return _AscensionView(c: c, entry: e);
    final kind = e.kind!;
    final codec = codecOf(kind);
    final base = c.baseFields(kind, e.id);
    final saved = c.savedFields(kind, e.id);
    final draft = c.draftFields(kind, e.id);
    final names = skillNamesOf(c.base);
    final issues = c.issuesOf(kind, e.id);
    final core = {'power', 'mp', 'status', 'hp', 'attack', 'speed', 'weight', 'tiers', 'effects'};
    final fields = [
      for (final f in codec.fields)
        if (showAll ||
            core.contains(f.key) ||
            !_emptyish(base[f.key]) ||
            !balanceJsonEquals(draft[f.key], base[f.key]) ||
            !balanceJsonEquals(saved[f.key], base[f.key]))
          f,
    ];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        KindBadge(kind.singular),
        const SizedBox(width: 8),
        Expanded(child: Text(e.name, style: theme.textTheme.headlineSmall)),
        TextButton.icon(
          icon: const Icon(Icons.restart_alt),
          label: const Text('Volver al código'),
          onPressed: c.draft.fieldsOf(kind, e.id).isEmpty ? null : () => c.resetEntity(kind, e.id),
        ),
      ]),
      Text('${kind.jsonKey}.${e.id} · ${e.detail}',
          style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 8),
      for (final i in issues) IssueTile(i),
      Row(children: [
        const Spacer(),
        FilterChip(
          label: Text('Mostrar todos los campos (${codec.fields.length})'),
          selected: showAll,
          onSelected: (v) => setState(() => showAll = v),
        ),
      ]),
      const SizedBox(height: 4),
      for (final f in fields)
        _FieldRow(
          field: f,
          base: base[f.key],
          saved: saved[f.key],
          draft: draft[f.key],
          names: names,
          editor: balanceFieldEditor(f, draft[f.key], (v) => c.setField(kind, e.id, f.key, v),
              context: c.base.context, skillNames: names),
          onRevert: () => c.revertField(kind, e.id, f.key),
        ),
    ]);
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.field,
    required this.base,
    required this.saved,
    required this.draft,
    required this.names,
    required this.editor,
    required this.onRevert,
  });

  final BalanceField field;
  final Object? base, saved, draft;
  final Map<String, String> names;
  final Widget editor;
  final VoidCallback onRevert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = !balanceJsonEquals(draft, saved);
    final patched = !balanceJsonEquals(saved, base);
    final small = theme.textTheme.bodySmall;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: pending
            ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.35)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 210,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(field.label, style: theme.textTheme.titleSmall),
            Text('código: ${formatBalanceValue(field, base, skillNames: names)}',
                style: small, maxLines: 3, overflow: TextOverflow.ellipsis),
            if (patched)
              Text('balance.json: ${formatBalanceValue(field, saved, skillNames: names)}',
                  style: small?.copyWith(color: theme.colorScheme.primary),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            if (pending)
              Text('nuevo: ${formatBalanceValue(field, draft, skillNames: names)}',
                  style: small?.copyWith(color: theme.colorScheme.tertiary, fontWeight: FontWeight.bold),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(child: editor),
        IconButton(
          icon: const Icon(Icons.undo, size: 18),
          tooltip: 'Deshacer (volver a balance.json)',
          onPressed: pending ? onRevert : null,
        ),
      ]),
    );
  }
}

class _AscensionView extends StatelessWidget {
  const _AscensionView({required this.c, required this.entry});
  final AdminController c;
  final AdminEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        const KindBadge('Ascensión'),
        const SizedBox(width: 8),
        Text(entry.name, style: theme.textTheme.headlineSmall),
      ]),
      Text(entry.detail, style: theme.textTheme.bodySmall),
      const SizedBox(height: 12),
      const Text('Las ascensiones se balancean por su kit (habilidades) y sus '
          'mecánicas. La ULT de ascensión todavía no es editable '
          '(docs/specs/balance_admin.md § 3).'),
      const SizedBox(height: 12),
      for (final (kind, id) in entry.links)
        Card(
          child: ListTile(
            leading: KindBadge(kind.singular),
            title: Text(codecOf(kind).nameOf(c.base.entities(kind)[id]!)),
            subtitle: Text(id),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => c.selectRef(kind, id),
          ),
        ),
    ]);
  }
}
