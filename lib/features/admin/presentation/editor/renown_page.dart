import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/data/renown_catalog.dart';
import '../field_editors.dart' show NumberStepper;
import 'renown_editor_controller.dart';

const _sourceLabels = {
  RenownSource.zone: 'Zona vencida',
  RenownSource.biomeBoss: 'Jefe de bioma (extra)',
  RenownSource.rift: 'Grieta cerrada',
  RenownSource.lore: 'Historia cumplida',
  RenownSource.tourney: 'Torneo ganado',
  RenownSource.resident: 'Habitante en el pueblo',
  RenownSource.building: 'Edificio del pueblo',
};

const _townLabels = {
  TownWeight.resident: 'Puntos por habitante',
  TownWeight.building: 'Puntos por edificio',
  TownWeight.renown: 'Puntos por punto de renombre',
};

const _tokensHelp = 'Fichas: {lastBoss} {lastBiome} {townName} {renownTier} '
    '{townTier}';

String _whoLabel(String who) => switch (who) {
      RecognitionWho.visitor => 'VISITANTE',
      RecognitionWho.wanderer => 'VIAJERO',
      RecognitionWho.caravan => 'CARAVANA',
      _ => biomeNpcName(who).toUpperCase(),
    };

String _es(Object? m) => '${(m as Map?)?['es-AR'] ?? ''}';

/// Editor → RENOMBRE (docs/specs/renown_town_growth.md § 8): sub-tabs
/// FUENTES · NIVELES · FRASES · EVENTOS DEL PUEBLO, each a grid with the
/// detail on the right.
class RenownPage extends StatelessWidget {
  const RenownPage({super.key, required this.c});
  final RenownEditorController c;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: c,
        builder: (context, _) => Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Toolbar(c: c),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: DsSpace.md),
              child: DsTabBar(
                key: const ValueKey('renown-tabs'),
                index: c.tab.index,
                onChanged: (i) => c.setTab(RenownTab.values[i]),
                tabs: const [
                  DsTab('FUENTES', key: ValueKey('renown-tab-sources')),
                  DsTab('NIVELES', key: ValueKey('renown-tab-tiers')),
                  DsTab('FRASES', key: ValueKey('renown-tab-lines')),
                  DsTab('EVENTOS DEL PUEBLO',
                      key: ValueKey('renown-tab-events')),
                ],
              ),
            ),
            Expanded(
              child: switch (c.tab) {
                RenownTab.sources => _Sources(c: c),
                RenownTab.tiers => _Tiers(c: c),
                RenownTab.lines => _Lines(c: c),
                RenownTab.events => _Events(c: c),
              },
            ),
          ]),
          if (c.message != null)
            Positioned(
              left: DsSpace.md,
              right: DsSpace.md,
              bottom: DsSpace.md,
              child: DsToast(c.message!,
                  key: const ValueKey('renown-notice'),
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
  final RenownEditorController c;

  @override
  Widget build(BuildContext context) {
    final p = c.problems;
    return Padding(
      padding: EdgeInsets.all(DsSpace.md),
      child: Row(children: [
        Expanded(
          child: Text(
              p.isEmpty
                  ? 'Listo para guardar.'
                  : 'No se puede guardar: ${p.first}',
              key: const ValueKey('renown-problems'),
              softWrap: true,
              style: DsText.detail(p.isEmpty ? null : DsColors.danger)),
        ),
        if (c.dirty) ...[
          const DsBadge('SIN GUARDAR'),
          SizedBox(width: DsSpace.sm),
        ],
        DsButton('RECARGAR',
            key: const ValueKey('renown-reload'),
            tooltip: 'Descarta lo no guardado.',
            onPressed: c.dirty ? c.reload : null),
        SizedBox(width: DsSpace.sm),
        DsButton('GUARDAR RENOMBRE',
            key: const ValueKey('renown-save'),
            kind: DsButtonKind.primary,
            tooltip: 'Escribe ${RenownConfig.assetPath} y lo aplica.',
            onPressed: c.dirty && p.isEmpty ? c.save : null),
      ]),
    );
  }
}

/// Template: grid on the left (filters, cells, add) | detail on the right.
class _GridDetail extends StatelessWidget {
  const _GridDetail(
      {required this.header,
      required this.filters,
      required this.cells,
      required this.add,
      required this.detail});
  final String header;
  final List<Widget> filters, cells;
  final Widget add;
  final Widget? detail;

  @override
  Widget build(BuildContext context) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 296,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(DsSpace.sm),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DsSectionHeader(header),
                      Wrap(
                          spacing: DsSpace.xs,
                          runSpacing: DsSpace.xs,
                          children: filters),
                      SizedBox(height: DsSpace.sm),
                      Wrap(
                          spacing: DsSpace.sm,
                          runSpacing: DsSpace.sm,
                          children: cells),
                      SizedBox(height: DsSpace.md),
                      add,
                    ]),
              ),
            ),
            const VerticalDivider(
                width: 2, thickness: 2, color: DsColors.border),
            Expanded(
              child: detail ??
                  Center(
                      child: Text('Elegí un elemento de la grilla.',
                          style: DsText.detail())),
            ),
          ]);
}

/// Molecule: a grid cell with its caption under it (no truncation).
class _Cell extends StatelessWidget {
  const _Cell(
      {super.key,
      required this.mark,
      required this.caption,
      required this.color,
      required this.selected,
      required this.onTap});
  final String mark, caption;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 84,
        child: Column(children: [
          DsItemCell(
            icon: Text(mark, style: DsText.title(color)),
            border: color,
            selected: selected,
            onTap: onTap,
          ),
          SizedBox(height: DsSpace.xs),
          Text(caption,
              softWrap: true,
              textAlign: TextAlign.center,
              style: DsText.detail(selected ? DsColors.selected : null)),
        ]),
      );
}

DsButton _filter(String label, Key key, bool on, VoidCallback go) => DsButton(
    label,
    key: key,
    size: DsButtonSize.compact,
    kind: DsButtonKind.ghost,
    selected: on,
    onPressed: go);

/// Molecule: an integer or decimal with a label.
class _Num extends StatelessWidget {
  const _Num(this.label, this.value, this.onChanged,
      {super.key, this.integer = true, this.min = 0});
  final String label;
  final num value;
  final ValueChanged<num> onChanged;
  final bool integer;
  final double min;

  @override
  Widget build(BuildContext context) => DsListRow(
        compact: true,
        title: label,
        trailing: NumberStepper(
            value: value,
            min: min,
            max: double.infinity,
            integer: integer,
            step: integer ? 1 : 0.05,
            width: 80,
            onChanged: onChanged),
      );
}

/// FUENTES: the weight of each renown source and of the town tier.
class _Sources extends StatelessWidget {
  const _Sources({required this.c});
  final RenownEditorController c;

  @override
  Widget build(BuildContext context) {
    final src = (c.doc['sources'] ??= <String, dynamic>{}) as Map;
    final town = (c.doc['town'] ??= <String, dynamic>{}) as Map;
    num n(Map m, String k) => m[k] is num ? m[k] as num : 0;
    return SingleChildScrollView(
      padding: EdgeInsets.all(DsSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const DsSectionHeader('RENOMBRE POR HITO'),
        for (final k in RenownSource.all)
          _Num(_sourceLabels[k] ?? k, n(src, k),
              (v) => c.edit(() => src[k] = v),
              key: ValueKey('renown-source-$k')),
        const DsSectionHeader('NIVEL DEL PUEBLO'),
        for (final k in TownWeight.all)
          _Num(_townLabels[k] ?? k, n(town, k),
              (v) => c.edit(() => town[k] = v),
              key: ValueKey('renown-town-$k'),
              integer: k != TownWeight.renown),
      ]),
    );
  }
}

/// NIVELES: renown tiers and town tiers.
class _Tiers extends StatelessWidget {
  const _Tiers({required this.c});
  final RenownEditorController c;

  @override
  Widget build(BuildContext context) {
    final list = c.tiers;
    final sel = c.selectedTier;
    return _GridDetail(
      header: '${list.length} NIVELES',
      filters: [
        _filter('RENOMBRE', const ValueKey('renown-ladder-tiers'),
            c.ladder == 'tiers', () => c.setLadder('tiers')),
        _filter('PUEBLO', const ValueKey('renown-ladder-town'),
            c.ladder == 'townTiers', () => c.setLadder('townTiers')),
      ],
      cells: [
        for (final (i, t) in list.indexed)
          _Cell(
              key: ValueKey('renown-tier-$i'),
              mark: '${t['min']}',
              caption: _es(t['name']),
              color: DsColors.reward,
              selected: c.tierIndex == i,
              onTap: () => c.selectTier(i)),
      ],
      add: DsButton('+ NIVEL',
          key: const ValueKey('renown-tier-add'),
          size: DsButtonSize.compact,
          onPressed: c.addTier),
      detail: sel == null
          ? null
          : SingleChildScrollView(
              key: ValueKey('renown-tier-detail-${c.ladder}-${c.tierIndex}'),
              padding: EdgeInsets.all(DsSpace.md),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(_es(sel['name']),
                              softWrap: true, style: DsText.title())),
                      DsButton('BORRAR',
                          key: const ValueKey('renown-tier-delete'),
                          size: DsButtonSize.compact,
                          onPressed: () => c.removeTier(c.tierIndex!)),
                    ]),
                    _Num('Desde (umbral)', sel['min'] as num? ?? 0,
                        (v) => c.edit(() => sel['min'] = v.round())),
                    const DsSectionHeader('NOMBRE'),
                    _Locales(c: c, m: sel['name'] as Map, id: 'tier-name'),
                  ]),
            ),
    );
  }
}

/// FRASES: recognition lines by who says them.
class _Lines extends StatelessWidget {
  const _Lines({required this.c});
  final RenownEditorController c;

  @override
  Widget build(BuildContext context) {
    final list = c.visibleLines;
    final sel = c.selectedLine;
    return _GridDetail(
      header: '${c.lines.length} FRASES',
      filters: [
        _filter('TODAS', const ValueKey('renown-who-all'), c.whoFilter == null,
            () => c.setWho(null)),
        for (final w in RenownEditorController.whoOptions)
          _filter(_whoLabel(w), ValueKey('renown-who-$w'), c.whoFilter == w,
              () => c.setWho(w)),
      ],
      cells: [
        for (final l in list)
          _Cell(
              key: ValueKey('renown-line-${l['id']}'),
              mark: '${l['minRenown'] ?? 0}',
              caption: '${l['id']}',
              color: RecognitionWho.actors.contains(l['who'])
                  ? DsColors.success
                  : DsColors.mp,
              selected: c.lineId == l['id'],
              onTap: () => c.selectLine('${l['id']}')),
      ],
      add: DsButton('+ FRASE',
          key: const ValueKey('renown-line-add'),
          size: DsButtonSize.compact,
          onPressed: c.addLine),
      detail: sel == null
          ? null
          : SingleChildScrollView(
              key: ValueKey('renown-line-detail-${sel['id']}'),
              padding: EdgeInsets.all(DsSpace.md),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text('${sel['id']}',
                              softWrap: true, style: DsText.title())),
                      DsButton('BORRAR',
                          key: const ValueKey('renown-line-delete'),
                          size: DsButtonSize.compact,
                          onPressed: () => c.removeLine('${sel['id']}')),
                    ]),
                    const DsSectionHeader('QUIÉN LA DICE'),
                    Wrap(
                        spacing: DsSpace.xs,
                        runSpacing: DsSpace.xs,
                        children: [
                          for (final w in RenownEditorController.whoOptions)
                            _filter(_whoLabel(w), ValueKey('renown-line-who-$w'),
                                sel['who'] == w,
                                () => c.edit(() => sel['who'] = w)),
                        ]),
                    _Num('Renombre mínimo', sel['minRenown'] as num? ?? 0,
                        (v) => c.edit(() => sel['minRenown'] = v.round())),
                    const DsSectionHeader('TEXTO'),
                    Text(_tokensHelp,
                        softWrap: true,
                        style: DsText.detail(DsColors.textSecondary)),
                    SizedBox(height: DsSpace.xs),
                    _Locales(c: c, m: sel['text'] as Map, id: 'line-text'),
                  ]),
            ),
    );
  }
}

/// EVENTOS DEL PUEBLO: tournaments and festivals proposed by residents.
class _Events extends StatelessWidget {
  const _Events({required this.c});
  final RenownEditorController c;

  @override
  Widget build(BuildContext context) {
    final sel = c.selectedEvent;
    return _GridDetail(
      header: '${c.events.length} EVENTOS',
      filters: const [],
      cells: [
        for (final e in c.events)
          _Cell(
              key: ValueKey('renown-event-${e['id']}'),
              mark: e['kind'] == TownEventKind.festival.name ? 'F' : 'T',
              caption: '${e['id']}',
              color: DsColors.danger,
              selected: c.eventId == e['id'],
              onTap: () => c.selectEvent('${e['id']}')),
      ],
      add: DsButton('+ TORNEO',
          key: const ValueKey('renown-event-add'),
          size: DsButtonSize.compact,
          onPressed: c.addEvent),
      detail: sel == null
          ? null
          : _EventDetail(
              key: ValueKey('renown-event-detail-${sel['id']}'), c: c, e: sel),
    );
  }
}

class _EventDetail extends StatefulWidget {
  const _EventDetail({super.key, required this.c, required this.e});
  final RenownEditorController c;
  final Map<String, dynamic> e;

  @override
  State<_EventDetail> createState() => _EventDetailState();
}

class _EventDetailState extends State<_EventDetail> {
  int tab = 0;
  int field = 0;

  static const _fields = [
    ('title', 'TÍTULO'),
    ('propose', 'PROPUESTA'),
    ('accept', 'AL ACEPTAR'),
    ('signup', 'INSCRIPCIÓN'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = widget.c, e = widget.e;
    num n(String k, num d) => e[k] is num ? e[k] as num : d;
    bool missing(String k) => c.locales
        .any((t) => '${((e[k] as Map?) ?? const {})[t] ?? ''}'.trim().isEmpty);
    final rounds = [
      for (final r in (e['rounds'] as List? ?? const []))
        [for (final x in r as List) '$x']
    ];
    while (rounds.length < 3) {
      rounds.add(<String>[]);
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: DsSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text('${e['id']}', softWrap: true, style: DsText.title())),
          DsButton('BORRAR',
              key: const ValueKey('renown-event-delete'),
              size: DsButtonSize.compact,
              onPressed: () => c.removeEvent('${e['id']}')),
        ]),
        DsTabBar(
          key: const ValueKey('renown-event-tabs'),
          index: tab,
          onChanged: (i) => setState(() => tab = i),
          tabs: [
            const DsTab('FICHA', key: ValueKey('renown-event-tab-sheet')),
            const DsTab('LUCHADORES',
                key: ValueKey('renown-event-tab-rounds')),
            DsTab('TEXTOS',
                badge: _fields.any((f) => missing(f.$1)) ? '!' : null,
                key: const ValueKey('renown-event-tab-texts')),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(top: DsSpace.sm, right: DsSpace.sm),
            child: switch (tab) {
              0 => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DsSectionHeader('TIPO'),
                      Wrap(spacing: DsSpace.xs, children: [
                        for (final k in TownEventKind.values)
                          _filter(
                              k == TownEventKind.tournament
                                  ? 'TORNEO'
                                  : 'FESTIVAL (PENDIENTE)',
                              ValueKey('renown-event-kind-${k.name}'),
                              e['kind'] == k.name,
                              () => c.edit(() => e['kind'] = k.name)),
                      ]),
                      const DsSectionHeader('LO PROPONE'),
                      Wrap(
                          spacing: DsSpace.xs,
                          runSpacing: DsSpace.xs,
                          children: [
                            for (final r in kBiomeNpcs)
                              _filter(
                                  r.name,
                                  ValueKey('renown-event-proposer-${r.id}'),
                                  e['proposer'] == r.id,
                                  () => c.edit(() => e['proposer'] = r.id)),
                          ]),
                      _Num('Amistad mínima', n('minRep', 0),
                          (v) => c.edit(() => e['minRep'] = v.round())),
                      _Num('Renombre mínimo', n('minRenown', 0),
                          (v) => c.edit(() => e['minRenown'] = v.round())),
                      _Num('Días hasta el evento', n('delay', 2),
                          (v) => c.edit(() => e['delay'] = v.round()),
                          min: 1),
                      _Num('Días antes de repetirlo', n('cooldown', 10),
                          (v) => c.edit(() => e['cooldown'] = v.round())),
                      _Num('Nivel extra', n('levelBonus', 0),
                          (v) => c.edit(() => e['levelBonus'] = v.round())),
                      _Num('Premio (oro por jugador)', n('prize', 0),
                          (v) => c.edit(() => e['prize'] = v.round())),
                    ]),
              1 => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                          'Ids de enemigo separados por coma. La ronda 3 es '
                          'el campeón.',
                          softWrap: true,
                          style: DsText.detail(DsColors.textSecondary)),
                      for (var k = 0; k < 3; k++)
                        DsListRow(
                          compact: true,
                          title: 'Ronda ${k + 1}',
                          trailing: SizedBox(
                            width: 320,
                            child: _TextBox(
                                key: ValueKey('renown-event-round-$k'),
                                value: rounds[k].join(', '),
                                missing: rounds[k].isEmpty,
                                onChanged: (v) => c.edit(() {
                                      rounds[k] = [
                                        for (final x in v.split(','))
                                          if (x.trim().isNotEmpty) x.trim()
                                      ];
                                      e['rounds'] = rounds;
                                    })),
                          ),
                        ),
                    ]),
              _ => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DsTabBar(
                        key: const ValueKey('renown-event-text-tabs'),
                        index: field,
                        onChanged: (i) => setState(() => field = i),
                        tabs: [
                          for (final (k, label) in _fields)
                            DsTab(label,
                                badge: missing(k) ? '!' : null,
                                key: ValueKey('renown-event-text-$k')),
                        ],
                      ),
                      SizedBox(height: DsSpace.sm),
                      Text(_tokensHelp,
                          softWrap: true,
                          style: DsText.detail(DsColors.textSecondary)),
                      SizedBox(height: DsSpace.xs),
                      _Locales(
                          c: c,
                          m: (e[_fields[field].$1] ??= <String, dynamic>{})
                              as Map,
                          id: 'event-${_fields[field].$1}'),
                    ]),
            },
          ),
        ),
      ]),
    );
  }
}

/// Molecule: one field per language; empty ones in red (cannot save).
class _Locales extends StatelessWidget {
  const _Locales({required this.c, required this.m, required this.id});
  final RenownEditorController c;
  final Map m;
  final String id;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                        key: ValueKey('renown-$id-$tag'),
                        value: v,
                        missing: v.trim().isEmpty,
                        onChanged: (s) => c.edit(() => m[tag] = s)),
                  ),
                ]),
              );
            }(),
        ],
      );
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
        maxLines: null,
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
