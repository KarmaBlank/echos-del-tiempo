import 'package:material_ui/material_ui.dart';

import '../../../game_engine/balance/balance_fields.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/passive_mechanic.dart';
import '../../../game_engine/models/status.dart';
import '../domain/balance_diff.dart';

/// Editores tipados de un campo de balance (formularios, no JSON crudo;
/// docs/specs/balance_admin.md § 5). Cada editor recibe el valor del
/// borrador (JSON canónico) y devuelve el nuevo por [onChanged].
typedef ValueChanged2 = void Function(Object? value);

double _round(double v) => (v * 10000).roundToDouble() / 10000;

/// Número con ± y campo de texto. [percent] muestra fracciones como %.
class NumberStepper extends StatefulWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.step = 1,
    this.min = double.negativeInfinity,
    this.max = double.infinity,
    this.integer = false,
    this.percent = false,
    this.width = 74,
  });

  final num value;
  final ValueChanged<num> onChanged;
  final double step;
  final double min, max;
  final bool integer;
  final bool percent;
  final double width;

  @override
  State<NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<NumberStepper> {
  late final TextEditingController _text = TextEditingController(text: _show());
  final _focus = FocusNode();

  String _show() => trimNum(widget.percent ? widget.value * 100 : widget.value,
      decimals: widget.percent ? 1 : 3);

  @override
  void didUpdateWidget(NumberStepper old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _text.text != _show()) _text.text = _show();
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _emit(num v) {
    var x = v.toDouble().clamp(widget.min, widget.max);
    x = _round(x);
    widget.onChanged(widget.integer ? x.round() : x);
  }

  void _submit(String s) {
    final parsed = double.tryParse(s.replaceAll(',', '.').replaceAll('%', '').trim());
    if (parsed == null) {
      _text.text = _show();
      return;
    }
    _emit(widget.percent ? parsed / 100 : parsed);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _IconBtn(Icons.remove, 'Bajar', () => _emit(widget.value - step)),
      SizedBox(
        width: widget.width,
        child: TextField(
          controller: _text,
          focusNode: _focus,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            isDense: true,
            suffixText: widget.percent ? '%' : null,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          ),
          onSubmitted: _submit,
          onTapOutside: (_) {
            if (_focus.hasFocus) {
              _submit(_text.text);
              _focus.unfocus();
            }
          },
        ),
      ),
      _IconBtn(Icons.add, 'Subir', () => _emit(widget.value + step)),
    ]);
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn(this.icon, this.tooltip, this.onTap);
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(icon, size: 18),
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
      );
}

Widget _dropdown<T>({
  required T? value,
  required List<T?> options,
  required String Function(T?) label,
  required ValueChanged<T?> onChanged,
  double width = 150,
}) =>
    SizedBox(
      width: width,
      child: DropdownButton<T?>(
        value: value,
        isDense: true,
        isExpanded: true,
        items: [
          for (final o in options)
            DropdownMenuItem<T?>(value: o, child: Text(label(o), overflow: TextOverflow.ellipsis)),
        ],
        onChanged: onChanged,
      ),
    );

String _statusName(String? n) => n == null
    ? 'ninguno'
    : StatusKind.values.firstWhere((s) => s.name == n).label;
String _buffName(String? n) =>
    n == null ? 'ninguno' : BuffStat.values.firstWhere((s) => s.name == n).label;

/// El editor de un campo según su tipo.
Widget balanceFieldEditor(
  BalanceField f,
  Object? value,
  ValueChanged2 onChanged, {
  required BalanceContext context,
  required Map<String, String> skillNames,
}) {
  switch (f.type) {
    case BalanceFieldType.integer:
    case BalanceFieldType.decimal:
    case BalanceFieldType.fraction:
      return NumberStepper(
        value: value is num ? value : 0,
        step: f.type == BalanceFieldType.fraction ? f.step : f.step,
        min: f.min,
        max: f.max,
        integer: f.type == BalanceFieldType.integer,
        percent: f.type == BalanceFieldType.fraction,
        onChanged: onChanged,
      );
    case BalanceFieldType.flag:
      return Align(
        alignment: Alignment.centerLeft,
        child: Switch(value: value == true, onChanged: onChanged),
      );
    case BalanceFieldType.status:
      return StatusEditor(
          value: value as Map?, nullable: f.nullable, onChanged: onChanged);
    case BalanceFieldType.statusList:
      return _ListEditor(
        items: value as List? ?? const [],
        addLabel: 'Agregar estado',
        create: () => {'kind': 'burn', 'stacks': 1},
        item: (v, set) => StatusEditor(value: v as Map?, nullable: false, onChanged: set),
        onChanged: onChanged,
      );
    case BalanceFieldType.buff:
      return BuffEditor(value: value as Map?, nullable: f.nullable, onChanged: onChanged);
    case BalanceFieldType.buffList:
      return _ListEditor(
        items: value as List? ?? const [],
        addLabel: 'Agregar buff/debuff',
        create: () => {'stat': 'attack', 'value': -0.2, 'turns': 2},
        item: (v, set) => BuffEditor(value: v as Map?, nullable: false, onChanged: set),
        onChanged: onChanged,
      );
    case BalanceFieldType.attributes:
      return _AttributesEditor(value: value as Map? ?? const {}, onChanged: onChanged);
    case BalanceFieldType.formula:
      return _FormulaEditor(value: value as Map?, nullable: f.nullable, onChanged: onChanged);
    case BalanceFieldType.idList:
      return _IdListEditor(
          ids: List<String>.from(value as List? ?? const []),
          names: skillNames,
          onChanged: onChanged);
    case BalanceFieldType.tiers:
      return _TiersEditor(tiers: value as List? ?? const [], onChanged: onChanged);
    case BalanceFieldType.numberMap:
      return _NumberMapEditor(
          value: value as Map? ?? const {},
          keys: context.nodeEffectKeys.toList()..sort(),
          onChanged: onChanged);
    case BalanceFieldType.procEffects:
      return _ListEditor(
        items: value as List? ?? const [],
        addLabel: 'Agregar efecto',
        create: () => {
          'kind': 'buffSelf',
          'value': 0.1,
          'turns': 2,
          'stat': 'attack',
          'status': null,
        },
        item: (v, set) => _ProcEffectEditor(value: v as Map, onChanged: set),
        onChanged: onChanged,
      );
    case BalanceFieldType.statusKind:
      return _dropdown<String>(
        value: value as String?,
        options: [null, for (final s in StatusKind.values) s.name],
        label: _statusName,
        onChanged: onChanged,
      );
    case BalanceFieldType.text:
      return _TextEditor(value: '${value ?? ''}', onChanged: onChanged);
  }
}

/// Estado alterado: tipo, stacks y probabilidad opcional.
class StatusEditor extends StatelessWidget {
  const StatusEditor(
      {super.key, required this.value, required this.nullable, required this.onChanged});

  final Map? value;
  final bool nullable;
  final ValueChanged2 onChanged;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final kind = v?['kind'] as String?;
    final oldChance = v == null ? null : v['chance'];
    Map<String, Object?> next({String? k, int? stacks, Object? chance = _keep}) {
      final ch = identical(chance, _keep) ? oldChance : chance;
      return {
        'kind': k ?? kind ?? 'burn',
        'stacks': stacks ?? (v?['stacks'] as num?)?.toInt() ?? 1,
        if (ch != null) 'chance': ch,
      };
    }
    return Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
      _dropdown<String>(
        value: kind,
        options: [if (nullable) null, for (final s in StatusKind.values) s.name],
        label: _statusName,
        onChanged: (k) => onChanged(k == null ? null : next(k: k)),
        width: 140,
      ),
      if (v != null) ...[
        const Text('×'),
        NumberStepper(
            value: (v['stacks'] as num?) ?? 1,
            integer: true,
            min: 1,
            max: 99,
            width: 44,
            onChanged: (s) => onChanged(next(stacks: s.toInt()))),
        FilterChip(
          label: const Text('Probabilidad'),
          selected: v['chance'] != null,
          onSelected: (on) => onChanged(next(chance: on ? 0.5 : null)),
        ),
        if (v['chance'] != null)
          NumberStepper(
              value: v['chance'] as num,
              percent: true,
              step: 0.05,
              min: 0,
              max: 1,
              width: 56,
              onChanged: (c) => onChanged(next(chance: c))),
      ],
    ]);
  }
}

const _keep = Object();

/// Buff / debuff: stat, valor (%) y turnos.
class BuffEditor extends StatelessWidget {
  const BuffEditor(
      {super.key, required this.value, required this.nullable, required this.onChanged});

  final Map? value;
  final bool nullable;
  final ValueChanged2 onChanged;

  @override
  Widget build(BuildContext context) {
    final v = value;
    Map<String, Object?> next({String? stat, num? val, int? turns}) => {
          'stat': stat ?? v?['stat'] ?? 'attack',
          'value': val ?? v?['value'] ?? 0.1,
          'turns': turns ?? v?['turns'] ?? 2,
        };
    return Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
      _dropdown<String>(
        value: v?['stat'] as String?,
        options: [if (nullable) null, for (final s in BuffStat.values) s.name],
        label: _buffName,
        onChanged: (s) => onChanged(s == null ? null : next(stat: s)),
        width: 170,
      ),
      if (v != null) ...[
        NumberStepper(
            value: v['value'] as num,
            percent: true,
            step: 0.05,
            min: -5,
            max: 5,
            width: 60,
            onChanged: (x) => onChanged(next(val: x))),
        NumberStepper(
            value: v['turns'] as num,
            integer: true,
            min: 0,
            max: 20,
            width: 40,
            onChanged: (t) => onChanged(next(turns: t.toInt()))),
        const Text('turnos'),
      ],
    ]);
  }
}

/// Lista con agregar / quitar.
class _ListEditor extends StatelessWidget {
  const _ListEditor({
    required this.items,
    required this.addLabel,
    required this.create,
    required this.item,
    required this.onChanged,
  });

  final List items;
  final String addLabel;
  final Object? Function() create;
  final Widget Function(Object? value, ValueChanged2 set) item;
  final ValueChanged2 onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Expanded(
              child: item(items[i], (v) {
                final next = [...items];
                next[i] = v;
                onChanged(next);
              }),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Quitar',
              onPressed: () => onChanged([...items]..removeAt(i)),
            ),
          ]),
        ),
      TextButton.icon(
        icon: const Icon(Icons.add, size: 18),
        label: Text(addLabel),
        onPressed: () => onChanged([...items, create()]),
      ),
    ]);
  }
}

class _AttributesEditor extends StatelessWidget {
  const _AttributesEditor({required this.value, required this.onChanged});
  final Map value;
  final ValueChanged2 onChanged;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 10, runSpacing: 4, children: [
        for (final a in Attribute.values)
          Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 32, child: Text(a.name.toUpperCase())),
            NumberStepper(
              value: (value[a.name] as num?) ?? 0,
              integer: true,
              min: 0,
              max: 300,
              width: 44,
              onChanged: (x) {
                final next = {
                  for (final b in Attribute.values)
                    if (b == a ? x != 0 : value.containsKey(b.name))
                      b.name: b == a ? x.toInt() : value[b.name],
                };
                onChanged(next);
              },
            ),
          ]),
      ]);
}

class _FormulaEditor extends StatelessWidget {
  const _FormulaEditor({required this.value, required this.nullable, required this.onChanged});
  final Map? value;
  final bool nullable;
  final ValueChanged2 onChanged;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Agregar fórmula'),
          onPressed: () => onChanged({'base': 5, 'esp': 0.5}),
        ),
      );
    }
    void set(String k, num x) {
      final next = Map<String, Object?>.from(v);
      if (k != 'base' && x == 0) {
        next.remove(k);
      } else {
        next[k] = x;
      }
      onChanged({
        'base': next['base'],
        for (final a in Attribute.values)
          if (next.containsKey(a.name)) a.name: next[a.name],
      });
    }

    return Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('base'),
        NumberStepper(value: v['base'] as num, min: 0, max: 500, width: 50, onChanged: (x) => set('base', x)),
      ]),
      for (final a in Attribute.values)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${a.name.toUpperCase()}×'),
          NumberStepper(
              value: (v[a.name] as num?) ?? 0,
              step: 0.05,
              min: 0,
              max: 10,
              width: 50,
              onChanged: (x) => set(a.name, x)),
        ]),
      if (nullable)
        TextButton(onPressed: () => onChanged(null), child: const Text('Quitar fórmula')),
    ]);
  }
}

class _IdListEditor extends StatelessWidget {
  const _IdListEditor({required this.ids, required this.names, required this.onChanged});
  final List<String> ids;
  final Map<String, String> names;
  final ValueChanged2 onChanged;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 6, runSpacing: 4, children: [
        for (final id in ids)
          InputChip(
            label: Text(names[id] ?? id),
            onDeleted: () => onChanged([...ids]..remove(id)),
            deleteButtonTooltipMessage: 'Quitar',
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 18),
          label: const Text('Agregar habilidad'),
          onPressed: () async {
            final picked = await showDialog<String>(
              context: context,
              builder: (_) => _SkillPicker(names: names, exclude: ids.toSet()),
            );
            if (picked != null) onChanged([...ids, picked]);
          },
        ),
      ]);
}

class _SkillPicker extends StatefulWidget {
  const _SkillPicker({required this.names, required this.exclude});
  final Map<String, String> names;
  final Set<String> exclude;

  @override
  State<_SkillPicker> createState() => _SkillPickerState();
}

class _SkillPickerState extends State<_SkillPicker> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final list = [
      for (final e in widget.names.entries)
        if (!widget.exclude.contains(e.key) &&
            (q.isEmpty ||
                e.value.toLowerCase().contains(q.toLowerCase()) ||
                e.key.toLowerCase().contains(q.toLowerCase())))
          e,
    ]..sort((a, b) => a.value.compareTo(b.value));
    return AlertDialog(
      title: const Text('Agregar habilidad'),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(children: [
          TextField(
            autofocus: true,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar'),
            onChanged: (v) => setState(() => q = v),
          ),
          Expanded(
            child: ListView(children: [
              for (final e in list)
                ListTile(
                  dense: true,
                  title: Text(e.value),
                  subtitle: Text(e.key),
                  onTap: () => Navigator.pop(context, e.key),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TiersEditor extends StatelessWidget {
  const _TiersEditor({required this.tiers, required this.onChanged});
  final List tiers;
  final ValueChanged2 onChanged;

  @override
  Widget build(BuildContext context) {
    void set(int i, String k, num x) {
      final next = [for (final t in tiers) Map<String, Object?>.from(t as Map)];
      next[i][k] = x.toInt();
      onChanged(next);
    }

    Widget cell(int i, String k, {double min = 0, double max = 10000, double step = 1}) =>
        NumberStepper(
            value: (tiers[i] as Map)[k] as num,
            integer: true,
            min: min,
            max: max,
            step: step,
            width: 46,
            onChanged: (x) => set(i, k, x));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < tiers.length; i++)
        Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: 26, child: Text('T${(tiers[i] as Map)['tier']}')),
          const Text('mín'),
          cell(i, 'min', min: -1000),
          const Text('máx'),
          cell(i, 'max', min: -1000),
          const Text('nivel'),
          cell(i, 'minLevel', min: 1, max: 100),
          const Text('peso'),
          cell(i, 'weight', step: 10, max: 100000),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: 'Quitar tier',
            onPressed: tiers.length <= 1 ? null : () => onChanged([...tiers]..removeAt(i)),
          ),
        ]),
      TextButton.icon(
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Agregar tier'),
        onPressed: () {
          final used = {for (final t in tiers) ((t as Map)['tier'] as num).toInt()};
          var n = 1;
          while (used.contains(n)) {
            n++;
          }
          onChanged([
            ...tiers,
            {'tier': n, 'minLevel': 1, 'min': 1, 'max': 2, 'weight': 100},
          ]);
        },
      ),
    ]);
  }
}

class _NumberMapEditor extends StatelessWidget {
  const _NumberMapEditor({required this.value, required this.keys, required this.onChanged});
  final Map value;
  final List<String> keys;
  final ValueChanged2 onChanged;

  @override
  Widget build(BuildContext context) {
    final free = [for (final k in keys) if (!value.containsKey(k)) k];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final e in value.entries)
        // Wrap, no Row: en columnas angostas el control baja de línea en
        // vez de desbordar (el nombre del efecto puede ser largo).
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 60),
              child: Text('${e.key}')),
          NumberStepper(
            value: e.value as num,
            step: (e.value as num).abs() < 1 ? 0.01 : 1,
            min: -1000,
            max: 1000,
            onChanged: (x) => onChanged({...value, e.key: x}),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: 'Quitar',
            onPressed: () => onChanged({...value}..remove(e.key)),
          ),
        ]),
      if (free.isNotEmpty)
        PopupMenuButton<String>(
          tooltip: 'Agregar efecto',
          itemBuilder: (_) => [for (final k in free) PopupMenuItem(value: k, child: Text(k))],
          onSelected: (k) => onChanged({...value, k: 0.01}),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add, size: 18),
              SizedBox(width: 4),
              Text('Agregar efecto'),
            ]),
          ),
        ),
    ]);
  }
}

class _ProcEffectEditor extends StatelessWidget {
  const _ProcEffectEditor({required this.value, required this.onChanged});
  final Map value;
  final ValueChanged2 onChanged;

  @override
  Widget build(BuildContext context) {
    void set(String k, Object? x) => onChanged({...value, k: x});
    return Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
      _dropdown<String>(
        value: value['kind'] as String,
        options: [for (final k in ProcEffectKind.values) k.name],
        label: (k) => k ?? '',
        onChanged: (k) => set('kind', k),
        width: 150,
      ),
      const Text('valor'),
      NumberStepper(
          value: (value['value'] as num?) ?? 0,
          step: 0.05,
          min: -100,
          max: 1000,
          width: 56,
          onChanged: (x) => set('value', x)),
      const Text('turnos'),
      NumberStepper(
          value: (value['turns'] as num?) ?? 0,
          integer: true,
          min: 0,
          max: 20,
          width: 36,
          onChanged: (x) => set('turns', x.toInt())),
      _dropdown<String>(
        value: value['stat'] as String?,
        options: [null, for (final s in BuffStat.values) s.name],
        label: (s) => s == null ? 'sin stat' : _buffName(s),
        onChanged: (s) => set('stat', s),
        width: 140,
      ),
      _dropdown<String>(
        value: value['status'] as String?,
        options: [null, for (final s in StatusKind.values) s.name],
        label: (s) => s == null ? 'sin estado' : _statusName(s),
        onChanged: (s) => set('status', s),
        width: 130,
      ),
    ]);
  }
}

class _TextEditor extends StatefulWidget {
  const _TextEditor({required this.value, required this.onChanged});
  final String value;
  final ValueChanged2 onChanged;

  @override
  State<_TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<_TextEditor> {
  late final TextEditingController _c = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_TextEditor old) {
    super.didUpdateWidget(old);
    if (widget.value != _c.text && widget.value != old.value) _c.text = widget.value;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        minLines: 2,
        maxLines: 5,
        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
        onChanged: widget.onChanged,
      );
}
