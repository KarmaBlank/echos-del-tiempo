import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/data/npc_talk_catalog.dart';
import '../../../../game_engine/rules/npc_talk_rules.dart';
import '../../../../game_engine/rules/resident_rules.dart';
import '../field_editors.dart' show NumberStepper;
import '../../../world/presentation/world_strings.dart';
import 'npc_editor_controller.dart';

/// Editor → NPC (docs/specs/npc_editor.md): grilla de habitantes | ficha,
/// DIÁLOGO y PEDIDOS del elegido.
class NpcsPage extends StatelessWidget {
  const NpcsPage({super.key, required this.c});
  final NpcEditorController c;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([c, c.balance]),
        builder: (context, _) => Stack(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(width: 296, child: _NpcGrid(c: c)),
            const VerticalDivider(
                width: 2, thickness: 2, color: DsColors.border),
            Expanded(
                child: c.selected == null
                    ? Center(
                        child: Text('ELEGÍ UN HABITANTE A LA IZQUIERDA',
                            style: DsText.detail()))
                    : _NpcDetail(
                        key: ValueKey('npc-detail-${c.selectedId}'), c: c)),
          ]),
          if (c.message != null)
            Positioned(
              left: 312,
              right: DsSpace.md,
              bottom: DsSpace.md,
              child: DsToast(c.message!,
                  key: const ValueKey('npc-notice'),
                  kind: c.message!.startsWith('Guardado')
                      ? DsToastKind.success
                      : DsToastKind.danger,
                  onClose: () => c.edit(() {})),
            ),
        ]),
      );
}

// ---------------------------------------------------------------------
// Átomos y moléculas
// ---------------------------------------------------------------------

/// Átomo: celda de la grilla con el sprite y el nombre.
class _NpcCell extends StatelessWidget {
  const _NpcCell({required this.c, required this.e});
  final NpcEditorController c;
  final NpcEntry e;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 84,
        child: Column(children: [
          DsItemCell(
            key: ValueKey('npc-cell-${e.id}'),
            icon: DsSpriteIcon(c.imageOf(e.sprite), size: 36),
            border: e.rooted ? DsColors.mp : DsColors.border,
            selected: c.selectedId == e.id,
            onTap: () => c.select(e.id),
          ).tip('${e.name} · ${e.role} · '
              '${e.rooted ? 'arraigado' : 'se muda'}'),
          SizedBox(height: DsSpace.xs),
          Text(e.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsText.detail(
                  c.selectedId == e.id ? DsColors.selected : null)),
        ]),
      );
}

/// Organismo: la grilla de todos los habitantes.
class _NpcGrid extends StatelessWidget {
  const _NpcGrid({required this.c});
  final NpcEditorController c;

  @override
  Widget build(BuildContext context) {
    final all = c.entries;
    return SingleChildScrollView(
      padding: EdgeInsets.all(DsSpace.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DsSectionHeader('${all.length} HABITANTES',
            trailing: c.dirty ? const DsBadge('SIN GUARDAR') : null),
        Wrap(spacing: DsSpace.sm, runSpacing: DsSpace.sm, children: [
          for (final e in all) _NpcCell(c: c, e: e),
        ]),
        SizedBox(height: DsSpace.md),
        Text('Borde azul: arraigado (no se muda).', style: DsText.detail()),
      ]),
    );
  }
}

/// Molécula: campo de texto cuadrado que sigue a [value]. [missing]
/// marks it with the danger border (a language without text).
class _Field extends StatefulWidget {
  const _Field(
      {super.key,
      required this.value,
      required this.onChanged,
      this.counter = false,
      this.missing = false,
      this.width,
      this.hint});
  final String value;
  final ValueChanged<String> onChanged;

  /// Contador de caracteres con el límite blando (npc_editor.md § 3).
  final bool counter;
  final bool missing;
  final double? width;
  final String? hint;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late final _t = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_Field old) {
    super.didUpdateWidget(old);
    if (widget.value != _t.text) _t.text = widget.value;
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const square = BorderRadius.zero;
    final field = TextField(
      controller: _t,
      style: DsText.body(),
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        border: const OutlineInputBorder(borderRadius: square),
        enabledBorder: widget.missing
            ? const OutlineInputBorder(
                borderRadius: square,
                borderSide: BorderSide(color: DsColors.danger))
            : null,
        contentPadding: EdgeInsets.all(DsSpace.sm),
      ),
      onChanged: (v) {
        widget.onChanged(v);
        if (widget.counter) setState(() {});
      },
    );
    final over = _t.text.length > kNpcLineSoftLimit;
    final box = widget.width == null
        ? Expanded(child: field)
        : SizedBox(width: widget.width, child: field);
    if (!widget.counter) {
      return widget.width == null ? field : box;
    }
    return Row(children: [
      box,
      SizedBox(width: DsSpace.sm),
      SizedBox(
        width: 64,
        child: Text('${_t.text.length}/$kNpcLineSoftLimit',
            style: DsText.detail(over ? DsColors.warning : null)),
      ).tip(over
          ? 'Más largo que el límite blando: pinceladas, no historia.'
          : 'Caracteres de la línea.'),
    ]);
  }
}

/// Molécula: one text in every language (npc_editor.md § 3.1): a row per
/// locale of the game, the empty ones marked. Edits [m] in place.
class _TextField extends StatelessWidget {
  const _TextField(
      {required this.c, required this.m, required this.id, this.hint});
  final NpcEditorController c;
  final Map m;
  final String id;
  final String? hint;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final tag in c.locales)
          Padding(
            padding: EdgeInsets.only(bottom: DsSpace.xs),
            child: Row(children: [
              SizedBox(
                width: 64,
                child: Text(tag,
                    style: DsText.detail('${m[tag] ?? ''}'.trim().isEmpty
                        ? DsColors.danger
                        : null)),
              ).tip('${m[tag] ?? ''}'.trim().isEmpty
                  ? 'Falta este idioma: no se puede guardar.'
                  : 'Idioma $tag.'),
              Expanded(
                child: _Field(
                    key: ValueKey('$id-$tag'),
                    value: '${m[tag] ?? ''}',
                    counter: true,
                    hint: hint,
                    missing: '${m[tag] ?? ''}'.trim().isEmpty,
                    onChanged: (v) => c.edit(() => m[tag] = v)),
              ),
            ]),
          ),
      ]);
}

/// The text map at [key] of [m] (created, and an old plain string
/// upgraded to es-AR, if needed).
Map<String, dynamic> _textOf(
    NpcEditorController c, Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v is Map<String, dynamic>) return v;
  final t = c.text(v is String ? v : '');
  m[key] = t;
  return t;
}

/// Molécula: subir, bajar y borrar el ítem [i] de [list].
class _ListActions extends StatelessWidget {
  const _ListActions(
      {required this.c, required this.list, required this.i, required this.id});
  final NpcEditorController c;
  final List list;
  final int i;
  final String id;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        DsButton('▲',
            key: ValueKey('$id-up'),
            size: DsButtonSize.compact,
            kind: DsButtonKind.ghost,
            tooltip: 'Subir',
            onPressed: i > 0 ? () => c.move(list, i, -1) : null),
        DsButton('▼',
            key: ValueKey('$id-down'),
            size: DsButtonSize.compact,
            kind: DsButtonKind.ghost,
            tooltip: 'Bajar',
            onPressed: i < list.length - 1 ? () => c.move(list, i, 1) : null),
        DsButton('✕',
            key: ValueKey('$id-del'),
            size: DsButtonSize.compact,
            kind: DsButtonKind.ghost,
            tooltip: 'Borrar',
            onPressed: () => c.removeAt(list, i)),
      ]);
}

/// Organismo: una lista de frases editable (saludos, líneas, invitar),
/// each in every language.
class _Lines extends StatelessWidget {
  const _Lines(
      {required this.c,
      required this.list,
      required this.id,
      this.addLabel = '+ LÍNEA'});
  final NpcEditorController c;
  final List list;
  final String id;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    for (var i = 0; i < list.length; i++) {
      if (list[i] is! Map) list[i] = c.text('${list[i]}');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < list.length; i++)
        Container(
          margin: EdgeInsets.only(bottom: DsSpace.sm),
          padding: EdgeInsets.only(left: DsSpace.sm),
          decoration: const BoxDecoration(
              border:
                  Border(left: BorderSide(color: DsColors.border, width: 2))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _TextField(c: c, m: list[i] as Map, id: '$id-$i')),
            _ListActions(c: c, list: list, i: i, id: '$id-$i'),
          ]),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: DsButton(addLabel,
            key: ValueKey('$id-add'),
            size: DsButtonSize.compact,
            tooltip: 'Agrega una línea al final.',
            onPressed: () => c.add(list, c.text())),
      ),
    ]);
  }
}

/// Molécula: un número entero con etiqueta.
class _Num extends StatelessWidget {
  const _Num(this.label, this.value, this.onChanged, {this.tip});
  final String label;
  final num value;
  final ValueChanged<num> onChanged;
  final String? tip;

  @override
  Widget build(BuildContext context) {
    final w = Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: DsText.detail()),
      SizedBox(width: DsSpace.xs),
      NumberStepper(
          value: value,
          min: 0,
          integer: value is int,
          step: value is int ? 1 : 0.1,
          width: 64,
          onChanged: onChanged),
    ]);
    return tip == null ? w : w.tip(tip!);
  }
}

/// Molécula: one choice among [values] as compact ghost buttons.
class _Pick<T> extends StatelessWidget {
  const _Pick(
      {required this.id,
      required this.values,
      required this.selected,
      required this.label,
      required this.onPick,
      required this.tip});
  final String id;
  final List<T> values;
  final T selected;
  final String Function(T v) label;
  final ValueChanged<T> onPick;
  final String tip;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        for (final v in values)
          DsButton(label(v),
              key: ValueKey('$id-${v is Enum ? v.name : v}'),
              size: DsButtonSize.compact,
              kind: DsButtonKind.ghost,
              selected: selected == v,
              tooltip: tip,
              onPressed: () => onPick(v)),
      ]);
}

String _whereLabel(TalkWhere w) => switch (w) {
      TalkWhere.any => 'EN TODOS LADOS',
      TalkWhere.biome => 'EN SU BIOMA',
      TalkWhere.town => 'EN EL PUEBLO',
    };

String _timeLabel(TalkTime t) => switch (t) {
      TalkTime.any => 'DÍA Y NOCHE',
      TalkTime.day => 'DE DÍA',
      TalkTime.night => 'DE NOCHE',
    };

String _actionLabel(TalkAction a) => switch (a) {
      TalkAction.none => 'SOLO CHARLA',
      TalkAction.invite => 'INVITAR',
      TalkAction.trade => 'COMERCIAR',
      TalkAction.house => 'ASIGNAR CASA',
    };

// ---------------------------------------------------------------------
// Detalle
// ---------------------------------------------------------------------

class _NpcDetail extends StatefulWidget {
  const _NpcDetail({super.key, required this.c});
  final NpcEditorController c;

  @override
  State<_NpcDetail> createState() => _NpcDetailState();
}

class _NpcDetailState extends State<_NpcDetail> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final e = c.selected!;
    final (_, err) = c.draft;
    final missing = c.missing;
    return Padding(
      padding: EdgeInsets.all(DsSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          DsSpriteIcon(c.imageOf(e.sprite), size: 48),
          SizedBox(width: DsSpace.md),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.name, style: DsText.title()),
              Text(
                  '${e.role} · ${e.biome} · ${e.rooted ? 'arraigado' : 'se muda'}',
                  style: DsText.detail()),
            ]),
          ),
          DsButton('PROBAR',
              key: const ValueKey('npc-preview'),
              tooltip: 'Abre la charla en el cuadro de diálogo del juego.',
              onPressed: err == null ? () => _preview(context, c, e) : null),
          SizedBox(width: DsSpace.sm),
          DsButton('RECARGAR',
              key: const ValueKey('npc-reload'),
              tooltip: 'Descarta lo no guardado.',
              onPressed: c.dirty ? c.reload : null),
          SizedBox(width: DsSpace.sm),
          DsButton('GUARDAR NPC',
              key: const ValueKey('npc-save'),
              kind: DsButtonKind.primary,
              tooltip: missing.isEmpty
                  ? 'Escribe assets/data/npcs/npcs.json y lo aplica.'
                  : 'Faltan idiomas en ${missing.length} textos.',
              onPressed:
                  c.dirty && err == null && missing.isEmpty ? c.save : null),
        ]),
        if (err != null)
          Padding(
            padding: EdgeInsets.only(top: DsSpace.sm),
            child: Text(err, style: DsText.detail(DsColors.danger)),
          )
        else if (missing.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: DsSpace.sm),
            child: Text(
                key: const ValueKey('npc-missing'),
                'No se puede guardar: faltan idiomas en ${missing.length} '
                'textos. Primero: ${missing.first}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DsText.detail(DsColors.danger)),
          ),
        SizedBox(height: DsSpace.sm),
        DsTabBar(
          key: const ValueKey('npc-tabs'),
          index: tab,
          onChanged: (i) => setState(() => tab = i),
          tabs: const [
            DsTab('FICHA', key: ValueKey('npc-tab-ficha')),
            DsTab('DIÁLOGO', key: ValueKey('npc-tab-dialogo')),
            DsTab('PEDIDOS', key: ValueKey('npc-tab-pedidos')),
          ],
        ),
        Expanded(
          child: tab == 1
              ? _Dialogue(c: c, e: e)
              : SingleChildScrollView(
                  padding: EdgeInsets.only(top: DsSpace.sm, right: DsSpace.sm),
                  child: tab == 0 ? _Sheet(c: c, e: e) : _Quests(c: c, e: e),
                ),
        ),
      ]),
    );
  }
}

/// FICHA (npc_editor.md § 2).
class _Sheet extends StatelessWidget {
  const _Sheet({required this.c, required this.e});
  final NpcEditorController c;
  final NpcEntry e;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _kv('Id', e.id),
        _kv('Rol', e.role),
        _kv('Hogar', e.biome),
        _kv('Se muda', e.rooted ? 'No (arraigado)' : 'Sí'),
        _kv('Sprite', NpcEditorController.manifestId(e.sprite)),
        if (e.portrait != e.sprite)
          _kv('Retrato', NpcEditorController.manifestId(e.portrait)),
        const DsSectionHeader('UMBRALES DE AMISTAD'),
        for (final (k, v) in c.thresholds(e)) _kv(k, v),
      ]);
}

/// DIÁLOGO (npc_editor.md § 3): one sub-tab per kind of text (no stacked
/// sections).
class _Dialogue extends StatefulWidget {
  const _Dialogue({required this.c, required this.e});
  final NpcEditorController c;
  final NpcEntry e;

  @override
  State<_Dialogue> createState() => _DialogueState();
}

class _DialogueState extends State<_Dialogue> {
  int sub = 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final e = widget.e;
    final m = c.npc(e.id);
    final tabs = <(String, String, Widget Function())>[
      (
        'SALUDOS',
        'greet',
        () => _Lines(
            c: c,
            list: NpcEditorController.listOf(m, 'greet'),
            id: 'npc-greet',
            addLabel: '+ SALUDO'),
      ),
      (
        'TEMAS',
        'topics',
        () => _TopicTree(
            c: c,
            list: NpcEditorController.listOf(m, 'topics'),
            id: 'npc-topic',
            depth: 0),
      ),
      (
        e.rooted ? 'ORILLA' : 'FRASE DEL DÍA',
        'ambient',
        () => _Lines(
            c: c,
            list: NpcEditorController.listOf(m, 'ambient'),
            id: 'npc-ambient'),
      ),
      if (e.rooted)
        (
          'AL INVITARLO',
          'decline',
          () => _Decline(c: c, m: m),
        )
      else ...[
        ('NOCHE', 'night', () => _Night(c: c, m: m, npc: e.id)),
        ('INVITAR Y CASA', 'house', () => _Resident(c: c, m: m)),
      ],
    ];
    final i = sub.clamp(0, tabs.length - 1);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(height: DsSpace.sm),
      DsTabBar(
        key: const ValueKey('npc-dialogue-tabs'),
        index: i,
        onChanged: (j) => setState(() => sub = j),
        tabs: [
          for (final (label, key, _) in tabs)
            DsTab(label, key: ValueKey('npc-sub-$key')),
        ],
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(top: DsSpace.sm, right: DsSpace.sm),
          child: tabs[i].$3(),
        ),
      ),
    ]);
  }
}

/// Rooted: what they say when invited (they decline) and their gift.
class _Decline extends StatelessWidget {
  const _Decline({required this.c, required this.m});
  final NpcEditorController c;
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Lines(
            c: c,
            list: NpcEditorController.listOf(m, 'decline'),
            id: 'npc-decline'),
        Padding(
          padding: EdgeInsets.only(top: DsSpace.sm),
          child: Row(children: [
            Text('Regalo único', style: DsText.detail()),
            SizedBox(width: DsSpace.sm),
            _Field(
                key: const ValueKey('npc-gift'),
                value: '${m['gift'] ?? ''}',
                width: 280,
                onChanged: (v) => m['gift'] = v),
          ]),
        ),
      ]);
}

/// Resident: the reason for each night outing (the places stay in code).
class _Night extends StatelessWidget {
  const _Night({required this.c, required this.m, required this.npc});
  final NpcEditorController c;
  final Map<String, dynamic> m;
  final String npc;

  @override
  Widget build(BuildContext context) {
    final night = (m['night'] ??= <String, dynamic>{}) as Map<String, dynamic>;
    final outings = biomeNpc(npc)?.nightOutings ?? const <NightOuting>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final o in outings)
        Padding(
          padding: EdgeInsets.only(bottom: DsSpace.md),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${o.id} → ${o.spot?.name ?? o.build?.name ?? 'fuente'}',
                style: DsText.subtitle()),
            SizedBox(height: DsSpace.xs),
            _TextField(
                c: c, m: _textOf(c, night, o.id), id: 'npc-night-${o.id}'),
          ]),
        ),
    ]);
  }
}

/// Resident: accepting the invite and thanking for the house.
class _Resident extends StatelessWidget {
  const _Resident({required this.c, required this.m});
  final NpcEditorController c;
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    final thanks =
        (m['house_thanks'] ??= <String, dynamic>{}) as Map<String, dynamic>;
    Widget block(String title, String id, Map t) => Padding(
          padding: EdgeInsets.only(bottom: DsSpace.md),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: DsText.subtitle()),
            SizedBox(height: DsSpace.xs),
            _TextField(c: c, m: t, id: id),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      block('Acepta la invitación', 'npc-invite-accept',
          _textOf(c, m, 'invite_accept')),
      block('Gracias por la casa (de día)', 'npc-thanks-day',
          _textOf(c, thanks, 'day')),
      block('Gracias por la casa (de noche)', 'npc-thanks-night',
          _textOf(c, thanks, 'night')),
    ]);
  }
}

/// Organismo: árbol de temas con sus caminos (líneas que unen padre e
/// hijo) y condiciones.
class _TopicTree extends StatelessWidget {
  const _TopicTree(
      {required this.c,
      required this.list,
      required this.id,
      required this.depth});
  final NpcEditorController c;
  final List list;
  final String id;
  final int depth;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < list.length; i++)
          Container(
            margin: EdgeInsets.only(bottom: DsSpace.sm),
            padding: EdgeInsets.only(left: DsSpace.sm),
            decoration: BoxDecoration(
                border: Border(
                    left: BorderSide(
                        color: depth == 0 ? DsColors.selected : DsColors.mp,
                        width: 2))),
            child:
                _TopicNode(c: c, list: list, i: i, id: '$id-$i', depth: depth),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: DsButton(depth == 0 ? '+ TEMA' : '+ SUB-TEMA',
              key: ValueKey('$id-add'),
              size: DsButtonSize.compact,
              tooltip: depth == 0
                  ? 'Agrega un tema de HABLAR.'
                  : 'Agrega una pregunta que sale de este tema.',
              onPressed: () => c.add(list, c.newTopicFor(list))),
        ),
      ]);
}

class _TopicNode extends StatelessWidget {
  const _TopicNode(
      {required this.c,
      required this.list,
      required this.i,
      required this.id,
      required this.depth});
  final NpcEditorController c;
  final List list;
  final int i;
  final String id;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final t = list[i] as Map<String, dynamic>;
    num n(String k) => (t[k] as num?) ?? 0;
    void set(String k, num v) => c.edit(() {
          if (v <= 0) {
            t.remove(k);
          } else {
            t[k] = v.toInt();
          }
        });
    void setName(String k, Enum v, Enum none) => c.edit(() {
          if (v == none) {
            t.remove(k);
          } else {
            t[k] = v.name;
          }
        });
    final where =
        TalkWhere.values.where((w) => w.name == t['where']).firstOrNull ??
            TalkWhere.any;
    final time =
        TalkTime.values.where((w) => w.name == t['time']).firstOrNull ??
            TalkTime.any;
    final action = TalkAction.fromName(t['action']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(depth == 0 ? '◆' : '└', style: DsText.detail()),
        SizedBox(width: DsSpace.sm),
        Expanded(
          child: _TextField(
              c: c,
              m: _textOf(c, t, 'label'),
              id: '$id-label',
              hint: 'Lo que pregunta el jugador'),
        ),
        SizedBox(width: DsSpace.sm),
        _Field(
            key: ValueKey('$id-id'),
            value: '${t['id']}',
            width: 96,
            hint: 'id',
            onChanged: (v) => t['id'] = v),
        _ListActions(c: c, list: list, i: i, id: id),
      ]),
      SizedBox(height: DsSpace.xs),
      Wrap(spacing: DsSpace.md, runSpacing: DsSpace.xs, children: [
        _Num('Charlas', n('talks'), (v) => set('talks', v),
            tip: 'Charlas (una por día) para que aparezca.'),
        _Num('Pedidos', n('orders'), (v) => set('orders', v),
            tip: 'Pedidos o encargos cumplidos para que aparezca.'),
        _Num('Amistad', n('rep'), (v) => set('rep', v),
            tip: 'Relación o amistad para que aparezca.'),
        _Pick<TalkWhere>(
            id: '$id-where',
            values: TalkWhere.values,
            selected: where,
            label: _whereLabel,
            tip: 'Dónde se puede tocar este tema.',
            onPick: (w) => setName('where', w, TalkWhere.any)),
        _Pick<TalkTime>(
            id: '$id-time',
            values: TalkTime.values,
            selected: time,
            label: _timeLabel,
            tip: 'A qué hora del reloj del mundo aparece.',
            onPick: (w) => setName('time', w, TalkTime.any)),
        _Pick<TalkAction>(
            id: '$id-action',
            values: TalkAction.values,
            selected: action,
            label: _actionLabel,
            tip: 'Qué hace la opción: el comportamiento vive en el código.',
            onPick: (w) => setName('action', w, TalkAction.none)),
      ]),
      SizedBox(height: DsSpace.xs),
      if (action == TalkAction.none)
        _Lines(
            c: c, list: NpcEditorController.listOf(t, 'lines'), id: '$id-line')
      else
        Text(
            'Opción de acción: dispara ${_actionLabel(action)} y no muestra '
            'líneas.',
            style: DsText.detail()),
      if (depth < 2 && action == TalkAction.none) ...[
        SizedBox(height: DsSpace.xs),
        Padding(
          padding: EdgeInsets.only(left: DsSpace.md),
          child: _TopicTree(
              c: c,
              list: NpcEditorController.listOf(t, 'sub'),
              id: '$id-sub',
              depth: depth + 1),
        ),
      ],
    ]);
  }
}

/// PEDIDOS (npc_editor.md § 4).
class _Quests extends StatelessWidget {
  const _Quests({required this.c, required this.e});
  final NpcEditorController c;
  final NpcEntry e;

  @override
  Widget build(BuildContext context) {
    final m = c.npc(e.id);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (e.mover) ...[
        const DsSectionHeader('CADENA DE ENCARGOS (A MANO)'),
        _Steps(c: c, list: NpcEditorController.listOf(m, 'quests')),
      ],
      for (final g in c.generators(e)) ...[
        DsSectionHeader('GENERADOR: ${g.title}',
            trailing: const DsBadge('BALANCE', neutral: true)),
        Wrap(spacing: DsSpace.md, runSpacing: DsSpace.xs, children: [
          for (final (k, label) in g.fields)
            SizedBox(
              width: 360,
              child: Row(children: [
                Expanded(child: Text(label, style: DsText.detail())),
                NumberStepper(
                    key: ValueKey('npc-gen-$k'),
                    value: c.value(g.kind, k),
                    min: 0,
                    integer: c.value(g.kind, k) is int,
                    step: c.value(g.kind, k) is int ? 1 : 0.1,
                    width: 80,
                    onChanged: (v) => c.setValue(g.kind, k, v)),
              ]),
            ).tip('$k: se guarda con GUARDAR del Balance.'),
        ]),
      ],
      const DsSectionHeader('EJEMPLOS'),
      Row(children: [
        _Num('Nivel', c.sampleLevel, (v) => c.setSampleLevel(v.toInt()),
            tip: 'Nivel de oficio y de personaje para los ejemplos.'),
        SizedBox(width: DsSpace.md),
        DsButton('GENERAR EJEMPLOS',
            key: const ValueKey('npc-samples'),
            tooltip: 'Siete días con las reglas del borrador.',
            onPressed: c.generateSamples),
      ]),
      SizedBox(height: DsSpace.sm),
      for (final s in c.samples)
        DsListRow(
          compact: true,
          title: s.day == 0 ? s.text : 'Día ${s.day}: ${s.text}',
          detail: s.reward,
        ),
    ]);
  }
}

/// Organismo: pasos de la cadena (el orden es la cadena).
class _Steps extends StatelessWidget {
  const _Steps({required this.c, required this.list});
  final NpcEditorController c;
  final List list;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < list.length; i++)
          Container(
            margin: EdgeInsets.only(bottom: DsSpace.sm),
            padding: EdgeInsets.only(left: DsSpace.sm),
            decoration: const BoxDecoration(
                border: Border(
                    left: BorderSide(color: DsColors.selected, width: 2))),
            child: _Step(c: c, list: list, i: i),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: DsButton('+ PASO',
              key: const ValueKey('npc-step-add'),
              size: DsButtonSize.compact,
              tooltip: 'Agrega un paso al final de la cadena.',
              onPressed: () => c.add(list, NpcEditorController.newStep())),
        ),
      ]);
}

class _Step extends StatelessWidget {
  const _Step({required this.c, required this.list, required this.i});
  final NpcEditorController c;
  final List list;
  final int i;

  @override
  Widget build(BuildContext context) {
    final s = list[i] as Map<String, dynamic>;
    final id = 'npc-step-$i';
    num n(String k, num d) => (s[k] as num?) ?? d;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text('${i + 1}.', style: DsText.subtitle()),
        SizedBox(width: DsSpace.sm),
        for (final k in QuestKind.values)
          DsButton(k.label.toUpperCase(),
              key: ValueKey('$id-kind-${k.name}'),
              size: DsButtonSize.compact,
              kind: DsButtonKind.ghost,
              selected: s['kind'] == k.name,
              tooltip: k.delivered
                  ? 'Se entrega con cosas de la bolsa.'
                  : 'Lo cuenta el anfitrión al ganar.',
              onPressed: () => c.edit(() => s['kind'] = k.name)),
        const Spacer(),
        _ListActions(c: c, list: list, i: i, id: id),
      ]),
      SizedBox(height: DsSpace.xs),
      Row(children: [
        Text('Objetivo', style: DsText.detail()),
        SizedBox(width: DsSpace.xs),
        _Field(
            key: ValueKey('$id-target'),
            value: '${s['target']}',
            width: 160,
            hint: 'ítem, pez, cultivo o zona',
            onChanged: (v) => s['target'] = v),
        SizedBox(width: DsSpace.md),
        _Num('Cantidad', n('n', 1), (v) => c.edit(() => s['n'] = v.toInt())),
        SizedBox(width: DsSpace.md),
        _Num('Oro', n('gold', 0), (v) => c.edit(() => s['gold'] = v.toInt())),
        SizedBox(width: DsSpace.md),
        _Num(
            'Relación', n('rep', 1), (v) => c.edit(() => s['rep'] = v.toInt())),
      ]),
      SizedBox(height: DsSpace.xs),
      Row(children: [
        Text('Objeto único', style: DsText.detail()),
        SizedBox(width: DsSpace.xs),
        _Field(
            key: ValueKey('$id-reward'),
            value: '${s['reward'] ?? ''}',
            width: 160,
            hint: 'vacío = ninguno',
            onChanged: (v) {
              if (v.isEmpty) {
                s.remove('reward');
              } else {
                s['reward'] = v;
              }
            }),
        SizedBox(width: DsSpace.sm),
        if (s['reward'] case final String r)
          Text(kResidentRelics[r]?.name ?? 'No existe ese objeto',
              style: DsText.detail(
                  kResidentRelics.containsKey(r) ? null : DsColors.warning)),
      ]),
      SizedBox(height: DsSpace.xs),
      _Field(
          key: ValueKey('$id-text'),
          value: '${s['text']}',
          counter: true,
          hint: 'Lo que pide',
          onChanged: (v) => s['text'] = v),
    ]);
  }
}

// ---------------------------------------------------------------------
// PROBAR
// ---------------------------------------------------------------------

void _preview(BuildContext context, NpcEditorController c, NpcEntry e) {
  final (d, _) = c.draft;
  final talk = d?.talks[e.id];
  if (talk == null) return;
  showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      shape: const RoundedRectangleBorder(),
      backgroundColor: DsColors.background,
      child: SizedBox(
          width: 900,
          child: _PreviewBox(
              c: c, e: e, talk: talk, onClose: () => Navigator.pop(context))),
    ),
  );
}

/// La charla en el `DsDialogueBox` real, con el avance, el idioma y la
/// hora elegidos (npc_editor.md § 3.4). Same navigation as the game's
/// HABLAR: VOLVER pops one level, and at the root goes back to the
/// greeting.
class _PreviewBox extends StatefulWidget {
  const _PreviewBox(
      {required this.c,
      required this.e,
      required this.talk,
      required this.onClose});
  final NpcEditorController c;
  final NpcEntry e;
  final NpcTalkDef talk;
  final VoidCallback onClose;

  @override
  State<_PreviewBox> createState() => _PreviewBoxState();
}

class _PreviewBoxState extends State<_PreviewBox> {
  int talks = 0, orders = 0, rep = 0, greet = 0;
  bool inTown = false, night = false, talking = false;
  late String locale = widget.c.locales.first;
  String? text;

  /// Sub-temas abiertos (pila: tema actual).
  final List<TalkTopic> path = [];

  void _reset() {
    path.clear();
    text = null;
    talking = false;
  }

  @override
  Widget build(BuildContext context) {
    final s = worldStrings(context);
    final t = widget.talk;
    final g = (talks: talks, orders: orders, rep: rep);
    final list = path.isEmpty ? t.topics : path.last.sub;
    final open = [
      for (final x in list)
        if (NpcTalkRules.open(x, g, inTown: inTown, night: night)) x
    ];
    final greetText =
        t.greet.isEmpty ? '…' : t.greet[greet % t.greet.length].resolve(locale);
    return Padding(
      padding: EdgeInsets.all(DsSpace.md),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
                spacing: DsSpace.md,
                runSpacing: DsSpace.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Num('Charlas', talks,
                      (v) => setState(() => talks = v.toInt())),
                  _Num('Pedidos', orders,
                      (v) => setState(() => orders = v.toInt())),
                  _Num('Amistad', rep, (v) => setState(() => rep = v.toInt())),
                  DsButton(inTown ? 'EN EL PUEBLO' : 'EN SU BIOMA',
                      key: const ValueKey('npc-preview-where'),
                      size: DsButtonSize.compact,
                      tooltip: 'Cambia dónde se charla.',
                      onPressed: widget.e.rooted
                          ? null
                          : () => setState(() {
                                inTown = !inTown;
                                _reset();
                              })),
                  DsButton(night ? 'DE NOCHE' : 'DE DÍA',
                      key: const ValueKey('npc-preview-time'),
                      size: DsButtonSize.compact,
                      tooltip: 'Cambia la hora del reloj del mundo.',
                      onPressed: () => setState(() {
                            night = !night;
                            _reset();
                          })),
                  _Pick<String>(
                      id: 'npc-preview-locale',
                      values: widget.c.locales,
                      selected: locale,
                      label: (l) => l,
                      tip: 'Idioma de la charla (vacío = es-AR).',
                      onPick: (l) => setState(() {
                            locale = l;
                            _reset();
                          })),
                  DsButton('OTRO SALUDO',
                      key: const ValueKey('npc-preview-greet'),
                      size: DsButtonSize.compact,
                      tooltip: 'Vuelve a empezar con otro saludo.',
                      onPressed: () => setState(() {
                            greet++;
                            _reset();
                          })),
                ]),
            SizedBox(height: DsSpace.md),
            DsDialogueBox(
              key: ValueKey('npc-preview-box-$greet-$locale-${text.hashCode}'),
              portrait: DsSpriteIcon(widget.c.imageOf(widget.e.portrait),
                  size: DsDialogueBox.portraitSize),
              name: widget.e.name,
              role: widget.e.role,
              text: text ?? greetText,
              skipLabel: s.t('ui.town.npc.skip'),
              onCancel: widget.onClose,
              choices: talking
                  ? [
                      for (final x in open)
                        DsChoice(x.label.resolve(locale),
                            key: ValueKey('npc-preview-topic-${x.id}'),
                            onSelected: () => setState(() {
                                  if (x.action != TalkAction.none) {
                                    _reset();
                                    text = '[${_actionLabel(x.action)}]';
                                    return;
                                  }
                                  text = x.lines
                                      .map((l) => l.resolve(locale))
                                      .join(' ');
                                  path.add(x);
                                })),
                      DsChoice(s.t('ui.town.npc.talk_back'),
                          key: const ValueKey('npc-preview-back'),
                          onSelected: () => setState(() {
                                if (path.isEmpty) {
                                  _reset();
                                } else {
                                  path.removeLast();
                                  text = s.t('ui.town.npc.talk_again');
                                }
                              })),
                    ]
                  : [
                      DsChoice(s.t('ui.town.npc.talk'),
                          key: const ValueKey('npc-preview-talk'),
                          onSelected: () => setState(() {
                                talking = true;
                                text = s.t('ui.town.npc.talk_prompt');
                              })),
                      if (widget.e.rooted && t.decline.isNotEmpty)
                        DsChoice(s.t('ui.town.npc.invite'),
                            onSelected: () => setState(() => text = t.decline
                                .map((l) => l.resolve(locale))
                                .join(' '))),
                      if (!widget.e.rooted)
                        DsChoice(s.t('ui.town.npc.invite'),
                            onSelected: () => setState(
                                () => text = t.inviteAccept.resolve(locale))),
                      DsChoice(s.t('ui.town.npc.bye'),
                          key: const ValueKey('npc-preview-bye'),
                          onSelected: widget.onClose),
                    ],
            ),
          ]),
    );
  }
}

/// Molécula: dato de la ficha (nombre | valor).
Widget _kv(String k, String v) =>
    DsListRow(compact: true, title: k, trailing: Text(v, style: DsText.body()));
