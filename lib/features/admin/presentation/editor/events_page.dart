import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/data/world_events_catalog.dart';
import '../field_editors.dart' show NumberStepper;
import 'events_editor_controller.dart';

String _catLabel(WorldEventCategory c) => switch (c) {
      WorldEventCategory.visitor => 'VISITANTE',
      WorldEventCategory.overworldNpc => 'CAMPO',
      WorldEventCategory.echoPortal => 'GRIETA',
      WorldEventCategory.lore => 'HISTORIA',
      WorldEventCategory.caravan => 'CARAVANA',
    };

Color _catColor(WorldEventCategory c) => switch (c) {
      WorldEventCategory.echoPortal => DsColors.danger,
      WorldEventCategory.lore => DsColors.reward,
      WorldEventCategory.overworldNpc => DsColors.mp,
      _ => DsColors.success,
    };

WorldEventCategory _cat(Map e) {
  try {
    return WorldEventCategory.fromName(e['category']);
  } on FormatException {
    return WorldEventCategory.visitor;
  }
}

/// Parameters per category (world_events.md § 1).
List<(String, String)> _paramsOf(WorldEventCategory c) => switch (c) {
      WorldEventCategory.echoPortal => const [
          ('hpMult', 'Vida ×'),
          ('atkMult', 'Ataque ×'),
          ('levelBonus', 'Nivel +'),
          ('rewardMult', 'Premio ×'),
        ],
      WorldEventCategory.lore => const [('gold', 'Oro'), ('rep', 'Relación')],
      WorldEventCategory.visitor ||
      WorldEventCategory.caravan =>
        const [('discount', 'Descuento (0–0.9)')],
      WorldEventCategory.overworldNpc => const [],
    };

/// Editor → EVENTOS (docs/specs/world_events.md § 7): event grid with a
/// category filter | GENERAL or the chosen event's detail.
class EventsPage extends StatelessWidget {
  const EventsPage({super.key, required this.c});
  final EventsEditorController c;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: c,
        builder: (context, _) => Stack(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(width: 296, child: _EventGrid(c: c)),
            const VerticalDivider(
                width: 2, thickness: 2, color: DsColors.border),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Toolbar(c: c),
                    Expanded(
                      child: c.selected == null
                          ? _General(c: c)
                          : _EventDetail(
                              key: ValueKey('event-detail-${c.selectedId}'),
                              c: c,
                              e: c.selected!),
                    ),
                  ]),
            ),
          ]),
          if (c.message != null)
            Positioned(
              left: 312,
              right: DsSpace.md,
              bottom: DsSpace.md,
              child: DsToast(c.message!,
                  key: const ValueKey('events-notice'),
                  kind: c.message!.startsWith('Guardado')
                      ? DsToastKind.success
                      : DsToastKind.danger,
                  onClose: () => c.edit(() {})),
            ),
        ]),
      );
}

/// Organism: save bar and the first blocking problem.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.c});
  final EventsEditorController c;

  @override
  Widget build(BuildContext context) {
    final p = c.problems;
    return Padding(
      padding: EdgeInsets.all(DsSpace.md),
      child: Row(children: [
        Expanded(
          child: Text(
              p.isEmpty ? 'Listo para guardar.' : 'No se puede guardar: ${p.first}',
              key: const ValueKey('events-problems'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DsText.detail(p.isEmpty ? null : DsColors.danger)),
        ),
        DsButton('RECARGAR',
            key: const ValueKey('events-reload'),
            tooltip: 'Descarta lo no guardado.',
            onPressed: c.dirty ? c.reload : null),
        SizedBox(width: DsSpace.sm),
        DsButton('GUARDAR EVENTOS',
            key: const ValueKey('events-save'),
            kind: DsButtonKind.primary,
            tooltip: 'Escribe ${WorldEventsConfig.assetPath} y lo aplica.',
            onPressed: c.dirty && p.isEmpty ? c.save : null),
      ]),
    );
  }
}

/// Organism: filter tabs + grid of events.
class _EventGrid extends StatelessWidget {
  const _EventGrid({required this.c});
  final EventsEditorController c;

  @override
  Widget build(BuildContext context) {
    final list = c.visible;
    return SingleChildScrollView(
      padding: EdgeInsets.all(DsSpace.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DsSectionHeader('${c.events.length} EVENTOS',
            trailing: c.dirty ? const DsBadge('SIN GUARDAR') : null),
        DsButton('GENERAL',
            key: const ValueKey('events-general'),
            size: DsButtonSize.compact,
            kind: DsButtonKind.ghost,
            selected: c.selectedId == null,
            tooltip: 'Intervalo, cantidad por tirada y probabilidad.',
            onPressed: () => c.select(null)),
        SizedBox(height: DsSpace.sm),
        Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          DsButton('TODOS',
              key: const ValueKey('events-filter-all'),
              size: DsButtonSize.compact,
              kind: DsButtonKind.ghost,
              selected: c.filter == null,
              onPressed: () => c.setFilter(null)),
          for (final cat in WorldEventCategory.values)
            DsButton(_catLabel(cat),
                key: ValueKey('events-filter-${cat.name}'),
                size: DsButtonSize.compact,
                kind: DsButtonKind.ghost,
                selected: c.filter == cat,
                onPressed: () => c.setFilter(cat)),
        ]),
        SizedBox(height: DsSpace.sm),
        Wrap(spacing: DsSpace.sm, runSpacing: DsSpace.sm, children: [
          for (final e in list)
            SizedBox(
              width: 84,
              child: Column(children: [
                DsItemCell(
                  key: ValueKey('event-cell-${e['id']}'),
                  icon: Text(_catLabel(_cat(e)).substring(0, 1),
                      style: DsText.title(_catColor(_cat(e)))),
                  border: e['enabled'] == false
                      ? DsColors.border
                      : _catColor(_cat(e)),
                  selected: c.selectedId == e['id'],
                  onTap: () => c.select('${e['id']}'),
                ).tip('${e['id']} · ${_catLabel(_cat(e))}'),
                SizedBox(height: DsSpace.xs),
                Text('${e['id']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsText.detail(
                        c.selectedId == e['id'] ? DsColors.selected : null)),
              ]),
            ),
        ]),
        SizedBox(height: DsSpace.md),
        DsButton('+ ${_catLabel(c.filter ?? WorldEventCategory.visitor)}',
            key: const ValueKey('events-add'),
            size: DsButtonSize.compact,
            tooltip: 'Agrega un evento de la categoría del filtro.',
            onPressed: () => c.add(c.filter ?? WorldEventCategory.visitor)),
      ]),
    );
  }
}

/// Molecule: an integer or decimal with a label.
class _Num extends StatelessWidget {
  const _Num(this.label, this.value, this.onChanged,
      {this.integer = true, this.min = 0, this.max = double.infinity});
  final String label;
  final num value;
  final ValueChanged<num> onChanged;
  final bool integer;
  final double min, max;

  @override
  Widget build(BuildContext context) => DsListRow(
        compact: true,
        title: label,
        trailing: NumberStepper(
            value: value,
            min: min,
            max: max,
            integer: integer,
            step: integer ? 1 : 0.05,
            width: 80,
            onChanged: onChanged),
      );
}

/// GENERAL: interval, per-roll counts and chance.
class _General extends StatelessWidget {
  const _General({required this.c});
  final EventsEditorController c;

  @override
  Widget build(BuildContext context) {
    final d = c.doc;
    num n(String k, num def) => d[k] is num ? d[k] as num : def;
    return SingleChildScrollView(
      padding: EdgeInsets.all(DsSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const DsSectionHeader('GENERAL'),
        _Num('Cada cuántos días se tira', n('interval', 5),
            (v) => c.edit(() => d['interval'] = v.round()),
            min: 1),
        _Num('Mínimo por tirada', n('minPerRoll', 1),
            (v) => c.edit(() => d['minPerRoll'] = v.round())),
        _Num('Máximo por tirada', n('maxPerRoll', 2),
            (v) => c.edit(() => d['maxPerRoll'] = v.round())),
        _Num('Probabilidad de que salga algo', n('chance', 1),
            (v) => c.edit(() => d['chance'] = v.toDouble()),
            integer: false,
            max: 1),
      ]),
    );
  }
}

class _EventDetail extends StatefulWidget {
  const _EventDetail({super.key, required this.c, required this.e});
  final EventsEditorController c;
  final Map<String, dynamic> e;

  @override
  State<_EventDetail> createState() => _EventDetailState();
}

class _EventDetailState extends State<_EventDetail> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.c, e = widget.e;
    final cat = _cat(e);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: DsSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('${e['id']}', style: DsText.title())),
          DsBadge(_catLabel(cat)),
          SizedBox(width: DsSpace.sm),
          DsButton('BORRAR',
              key: const ValueKey('event-delete'),
              size: DsButtonSize.compact,
              tooltip: 'Saca el evento del catálogo.',
              onPressed: () => c.remove('${e['id']}')),
        ]),
        DsTabBar(
          key: const ValueKey('event-tabs'),
          index: tab,
          onChanged: (i) => setState(() => tab = i),
          tabs: const [
            DsTab('FICHA', key: ValueKey('event-tab-ficha')),
            DsTab('TEXTOS', key: ValueKey('event-tab-textos')),
            DsTab('PARÁMETROS', key: ValueKey('event-tab-params')),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(top: DsSpace.sm, right: DsSpace.sm),
            child: switch (tab) {
              0 => _Sheet(c: c, e: e, cat: cat),
              1 => _Texts(c: c, e: e),
              _ => _Params(c: c, e: e, cat: cat),
            },
          ),
        ),
      ]),
    );
  }
}

/// FICHA: enable, weight, duration and conditions.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.c, required this.e, required this.cat});
  final EventsEditorController c;
  final Map<String, dynamic> e;
  final WorldEventCategory cat;

  @override
  Widget build(BuildContext context) {
    num n(String k, num def) => e[k] is num ? e[k] as num : def;
    final biomes = [for (final b in (e['biomes'] as List? ?? const [])) '$b'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DsListRow(
        compact: true,
        title: 'Habilitado',
        trailing: Switch(
            key: const ValueKey('event-enabled'),
            value: e['enabled'] != false,
            onChanged: (v) => c.edit(() {
                  if (v) {
                    e.remove('enabled');
                  } else {
                    e['enabled'] = false;
                  }
                })),
      ),
      _Num('Peso', n('weight', 1), (v) => c.edit(() => e['weight'] = v.round())),
      _Num('Duración (días)', n('duration', 3),
          (v) => c.edit(() => e['duration'] = v.round()),
          min: 1),
      _Num('Día mínimo del mundo', n('minDay', 0),
          (v) => c.edit(() => e['minDay'] = v.round())),
      _Num('Renombre mínimo', n('minRenown', 0), (v) => c.edit(() {
            if (v.round() == 0) {
              e.remove('minRenown');
            } else {
              e['minRenown'] = v.round();
            }
          })),
      if (!cat.inTown && cat != WorldEventCategory.lore) ...[
        const DsSectionHeader('BIOMAS (NINGUNO = CUALQUIERA)'),
        Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          for (final b in kBiomes)
            if (b.id != kPueblo)
              DsButton(b.name,
                  key: ValueKey('event-biome-${b.id}'),
                  size: DsButtonSize.compact,
                  kind: DsButtonKind.ghost,
                  selected: biomes.contains(b.id),
                  onPressed: () => c.edit(() {
                        final next = [...biomes];
                        if (!next.remove(b.id)) next.add(b.id);
                        if (next.isEmpty) {
                          e.remove('biomes');
                        } else {
                          e['biomes'] = next;
                        }
                      })),
        ]),
      ],
      const DsSectionHeader('HABITANTE QUE TIENE QUE VIVIR EN EL PUEBLO'),
      Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
        if (cat != WorldEventCategory.lore)
          DsButton('NINGUNO',
              key: const ValueKey('event-resident-none'),
              size: DsButtonSize.compact,
              kind: DsButtonKind.ghost,
              selected: e['resident'] == null,
              onPressed: () => c.edit(() => e.remove('resident'))),
        for (final r in kBiomeNpcs)
          DsButton(r.name,
              key: ValueKey('event-resident-${r.id}'),
              size: DsButtonSize.compact,
              kind: DsButtonKind.ghost,
              selected: e['resident'] == r.id,
              onPressed: () => c.edit(() => e['resident'] = r.id)),
      ]),
      if (cat == WorldEventCategory.lore) ...[
        const DsSectionHeader('OBJETIVO (NUNCA TRAER COSAS)'),
        Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          for (final o in LoreObjective.values)
            DsButton(o.name.toUpperCase(),
                key: ValueKey('event-objective-${o.name}'),
                size: DsButtonSize.compact,
                kind: DsButtonKind.ghost,
                selected: e['objective'] == o.name,
                onPressed: () => c.edit(() => e['objective'] = o.name)),
        ]),
        DsListRow(
          compact: true,
          title: 'Objetivo (id de enemigo o de bioma)',
          trailing: SizedBox(
            width: 200,
            child: _TextBox(
                key: const ValueKey('event-target'),
                value: '${e['target'] ?? ''}',
                onChanged: (v) => c.edit(() => e['target'] = v)),
          ),
        ),
        _Num('Cantidad', n('n', 1), (v) => c.edit(() => e['n'] = v.round()),
            min: 1),
      ],
    ]);
  }
}

/// TEXTOS: one sub-tab per field (title, notice, body), each in every
/// language.
class _Texts extends StatefulWidget {
  const _Texts({required this.c, required this.e});
  final EventsEditorController c;
  final Map<String, dynamic> e;

  @override
  State<_Texts> createState() => _TextsState();
}

class _TextsState extends State<_Texts> {
  int field = 0;

  static const _fields = [
    ('title', 'TÍTULO'),
    ('notice', 'AVISO (CHAT)'),
    ('body', 'DETALLE'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = widget.c, e = widget.e;
    final (k, _) = _fields[field];
    final m = (e[k] ??= <String, dynamic>{}) as Map;
    bool missing(String key) => c.locales.any(
        (t) => '${((e[key] as Map?) ?? const {})[t] ?? ''}'.trim().isEmpty);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DsTabBar(
        key: const ValueKey('event-text-tabs'),
        index: field,
        onChanged: (i) => setState(() => field = i),
        tabs: [
          for (final (key, label) in _fields)
            DsTab(label,
                badge: missing(key) ? '!' : null,
                key: ValueKey('event-text-tab-$key')),
        ],
      ),
      SizedBox(height: DsSpace.sm),
      for (final tag in c.locales)
        () {
          final v = '${m[tag] ?? ''}';
          return Padding(
            padding: EdgeInsets.only(bottom: DsSpace.xs),
            child: Row(children: [
              SizedBox(
                width: 64,
                child: Text(tag,
                    style: DsText.detail(
                        v.trim().isEmpty ? DsColors.danger : null)),
              ).tip(v.trim().isEmpty
                  ? 'Falta este idioma: no se puede guardar.'
                  : 'Idioma $tag.'),
              Expanded(
                child: _TextBox(
                    key: ValueKey('event-$k-$tag'),
                    value: v,
                    missing: v.trim().isEmpty,
                    onChanged: (s) => c.edit(() => m[tag] = s)),
              ),
            ]),
          );
        }(),
    ]);
  }
}

/// PARÁMETROS: the numbers of its category.
class _Params extends StatelessWidget {
  const _Params({required this.c, required this.e, required this.cat});
  final EventsEditorController c;
  final Map<String, dynamic> e;
  final WorldEventCategory cat;

  @override
  Widget build(BuildContext context) {
    final fields = _paramsOf(cat);
    if (fields.isEmpty) {
      return Text('Esta categoría no tiene parámetros.',
          style: DsText.detail());
    }
    final p = (e['params'] ??= <String, dynamic>{}) as Map;
    final def = WorldEventDef(id: '', category: cat);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (k, label) in fields)
        _Num(label, p[k] is num ? p[k] as num : def.param(k),
            (v) => c.edit(() => p[k] = v),
            integer: k == 'gold' || k == 'rep' || k == 'levelBonus'),
    ]);
  }
}

/// Atom: square text field that follows [value].
class _TextBox extends StatefulWidget {
  const _TextBox(
      {super.key,
      required this.value,
      required this.onChanged,
      this.missing = false});
  final String value;
  final ValueChanged<String> onChanged;
  final bool missing;

  @override
  State<_TextBox> createState() => _TextBoxState();
}

class _TextBoxState extends State<_TextBox> {
  late final _t = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_TextBox old) {
    super.didUpdateWidget(old);
    if (widget.value != _t.text) _t.text = widget.value;
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _t,
        style: DsText.body(),
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
          enabledBorder: widget.missing
              ? const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: DsColors.danger))
              : null,
          contentPadding: EdgeInsets.all(DsSpace.sm),
        ),
        onChanged: widget.onChanged,
      );
}
