import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../../game_engine/data/build_templates_catalog.dart';
import '../../../game_engine/data/passive_tree_catalog.dart';
import '../../../game_engine/rules/build_template_rules.dart';
import '../../../game_engine/rules/passive_tree_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../../game_engine/rules/stats_calculator.dart';
import '../domain/admin_index.dart';
import 'admin_controller.dart';
import 'admin_widgets.dart';

/// Balance → Plantillas (docs/specs/build_planner_v2.md § 2.2): una
/// plantilla de BUILD como datos (el mismo mapa del YAML), validada con
/// las reglas del juego. GUARDAR escribe el archivo del dueño
/// `assets/data/build_templates_custom.yaml` (gana su id sobre la del
/// juego) en el repo; nunca la carpeta de datos del juego.
class TemplateEditor extends StatefulWidget {
  const TemplateEditor({super.key, required this.c, required this.entry});
  final AdminController c;
  final AdminEntry entry;

  @override
  State<TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<TemplateEditor> {
  late final TextEditingController _text;
  List<String> _issues = const [];
  String? _status;

  BuildTemplate? get _original => BuildTemplates.byId(widget.entry.id);

  BuildTemplateRules get _rules => BuildTemplateRules(ProgressionRules(
      stats: StatsCalculator(
          classes: widget.c.base.catalog.classes,
          treeRules: PassiveTreeRules(kPassiveTree)),
      catalog: widget.c.base.catalog));

  @override
  void initState() {
    super.initState();
    final t = _original;
    _text = TextEditingController(
        text: t == null
            ? ''
            : const JsonEncoder.withIndent('  ').convert(t.toJson()));
    _validate();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  BuildTemplate? _parse() {
    final issues = <String>[];
    Object? raw;
    try {
      raw = jsonDecode(_text.text);
    } on Object catch (e) {
      setState(() => _issues = ['JSON inválido: $e']);
      return null;
    }
    final t = BuildTemplateYaml.template(raw, issues, widget.entry.id);
    setState(() => _issues = [...issues, if (t != null) ..._rules.validate(t)]);
    return t;
  }

  void _validate() {
    final t = _parse();
    if (t == null) return;
    final tl = _rules.timeline(t);
    setState(() => _status = _issues.isEmpty
        ? 'Válida · ${tl.points} puntos de árbol · último nodo al nivel '
            '${tl.steps.isEmpty ? '-' : tl.steps.last.level}'
        : null);
  }

  Future<void> _save() async {
    final c = widget.c;
    final t = _parse();
    if (t == null || _issues.isNotEmpty) return;
    if (!c.hasRepo) {
      setState(() => _status = 'Sin repo: no se puede guardar');
      return;
    }
    final path = c.host.join(c.repoPath!, BuildTemplateYaml.customAssetPath);
    try {
      final old = await c.host.readFile(path);
      final list = old == null
          ? <BuildTemplate>[]
          : [...BuildTemplateYaml.parse(old).templates];
      list.removeWhere((x) => x.id == t.id);
      list.add(t);
      await c.host.writeFile(path, BuildTemplateYaml.write(list));
      // Se ve al toque en el juego de esta sesión (gana su id).
      BuildTemplates.install(
          [for (final x in BuildTemplates.all) if (!x.imported) x],
          custom: [t]);
      setState(() => _status = 'Guardada en ${BuildTemplateYaml.customAssetPath}');
    } on Object catch (e) {
      setState(() => _status = 'No se pudo guardar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        const KindBadge('Plantilla'),
        const SizedBox(width: 8),
        Expanded(
            child: Text(widget.entry.name,
                style: theme.textTheme.headlineSmall)),
      ]),
      Text(widget.entry.detail, style: theme.textTheme.bodySmall),
      const SizedBox(height: 8),
      const Text('Mismo formato que assets/data/build_templates.yaml (en '
          'JSON). GUARDAR la escribe en build_templates_custom.yaml, que '
          'gana sobre la del juego con el mismo id.'),
      const SizedBox(height: 8),
      TextField(
        key: const ValueKey('tpl-editor-text'),
        controller: _text,
        maxLines: 24,
        minLines: 12,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        OutlinedButton(
            key: const ValueKey('tpl-editor-validate'),
            onPressed: _validate,
            child: const Text('VALIDAR')),
        FilledButton(
            key: const ValueKey('tpl-editor-save'),
            onPressed: widget.c.hasRepo ? _save : null,
            child: const Text('GUARDAR EN EL REPO')),
      ]),
      if (_status != null) ...[
        const SizedBox(height: 8),
        Text(_status!, key: const ValueKey('tpl-editor-status')),
      ],
      for (final i in _issues)
        Text('× $i',
            key: const ValueKey('tpl-editor-issue'),
            style: TextStyle(color: theme.colorScheme.error)),
    ]);
  }
}
