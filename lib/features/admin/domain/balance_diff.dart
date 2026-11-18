import '../../../game_engine/balance/balance_codecs.dart';
import '../../../game_engine/balance/balance_fields.dart';
import '../../../game_engine/balance/balance_patch.dart';
import '../../../game_engine/balance/balance_registries.dart';
import '../../../game_engine/models/passive_mechanic.dart';
import '../../../game_engine/models/status.dart';

/// Un campo que cambia entre dos parches (docs/specs/balance_admin.md
/// § 5, pestaña Cambios).
class BalanceChange {
  const BalanceChange({
    required this.kind,
    required this.id,
    required this.name,
    required this.field,
    required this.before,
    required this.after,
    required this.beforeText,
    required this.afterText,
  });

  final BalanceKind kind;
  final String id;
  final String name;
  final BalanceField field;
  final Object? before;
  final Object? after;
  final String beforeText;
  final String afterText;

  /// Para números: subió (true), bajó (false) o no es número (null).
  bool? get increased => before is num && after is num
      ? (after as num) > (before as num)
      : null;
}

/// Los cambios de valores **efectivos** de [from] a [to], en el orden de
/// los tipos y de los campos de cada codec.
List<BalanceChange> diffBalance(
    BalanceBase base, BalancePatch from, BalancePatch to) {
  final names = skillNamesOf(base);
  final out = <BalanceChange>[];
  for (final kind in BalanceKind.values) {
    final ids = {
      ...?from.overrides[kind]?.keys,
      ...?to.overrides[kind]?.keys,
    };
    final codec = codecOf(kind);
    final entities = base.entities(kind);
    final sorted = [
      for (final id in ids)
        if (entities.containsKey(id)) id,
    ]..sort((a, b) =>
        codec.nameOf(entities[a]!).compareTo(codec.nameOf(entities[b]!)));
    for (final id in sorted) {
      final a = from.effectiveFields(base, kind, id);
      final b = to.effectiveFields(base, kind, id);
      for (final f in codec.fields) {
        if (balanceJsonEquals(a[f.key], b[f.key])) continue;
        out.add(BalanceChange(
          kind: kind,
          id: id,
          name: codec.nameOf(entities[id]!),
          field: f,
          before: a[f.key],
          after: b[f.key],
          beforeText: formatBalanceValue(f, a[f.key], skillNames: names),
          afterText: formatBalanceValue(f, b[f.key], skillNames: names),
        ));
      }
    }
  }
  return out;
}

/// Id → nombre de cada habilidad (para mostrar `skillIds`).
Map<String, String> skillNamesOf(BalanceBase base) =>
    {for (final s in base.catalog.skills.values) s.id: s.name};

String trimNum(num v, {int decimals = 3}) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  var s = v.toStringAsFixed(decimals);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
}

String _pct(num v) => '${trimNum(v * 100, decimals: 1)}%';
String _signedPct(num v) => '${v >= 0 ? '+' : '−'}${_pct(v.abs())}';

String _statusLabel(String name) =>
    StatusKind.values.where((s) => s.name == name).firstOrNull?.label ?? name;
String _buffLabel(String name) =>
    BuffStat.values.where((s) => s.name == name).firstOrNull?.label ?? name;

String _status(Object? v) {
  if (v is! Map) return 'ninguno';
  final chance = v['chance'];
  return '${_statusLabel(v['kind'] as String)} ×${v['stacks']}'
      '${chance is num ? ' (${_pct(chance)})' : ''}';
}

String _buff(Object? v) {
  if (v is! Map) return 'ninguno';
  return '${_buffLabel(v['stat'] as String)} ${_signedPct(v['value'] as num)}'
      ' · ${v['turns']} t';
}

/// Un valor de campo en texto para la UI y las notas de parche.
String formatBalanceValue(BalanceField f, Object? v,
    {Map<String, String> skillNames = const {}}) {
  switch (f.type) {
    case BalanceFieldType.integer:
    case BalanceFieldType.decimal:
      return v is num ? trimNum(v) : '—';
    case BalanceFieldType.fraction:
      return v is num ? _pct(v) : '—';
    case BalanceFieldType.flag:
      return v == true ? 'sí' : 'no';
    case BalanceFieldType.status:
      return _status(v);
    case BalanceFieldType.statusList:
      final l = v as List? ?? const [];
      return l.isEmpty ? 'ninguno' : l.map(_status).join(', ');
    case BalanceFieldType.buff:
      return _buff(v);
    case BalanceFieldType.buffList:
      final l = v as List? ?? const [];
      return l.isEmpty ? 'ninguno' : l.map(_buff).join(', ');
    case BalanceFieldType.attributes:
      final m = v as Map? ?? const {};
      return m.isEmpty
          ? 'ninguno'
          : m.entries
              .map((e) => '${'${e.key}'.toUpperCase()} ${e.value}')
              .join(' · ');
    case BalanceFieldType.formula:
      if (v is! Map) return 'ninguna';
      return [
        trimNum(v['base'] as num),
        for (final e in v.entries)
          if (e.key != 'base')
            '${trimNum(e.value as num)}·${'${e.key}'.toUpperCase()}',
      ].join(' + ');
    case BalanceFieldType.idList:
      final l = v as List? ?? const [];
      return l.isEmpty ? 'ninguna' : l.map((id) => skillNames[id] ?? '$id').join(', ');
    case BalanceFieldType.tiers:
      final l = v as List? ?? const [];
      return l
          .map((t) => 'T${t['tier']} ${t['min']}–${t['max']} '
              '(nv ${t['minLevel']}, peso ${t['weight']})')
          .join(' · ');
    case BalanceFieldType.numberMap:
      final m = v as Map? ?? const {};
      return m.isEmpty
          ? 'nada'
          : m.entries.map((e) => '${e.key} ${trimNum(e.value as num)}').join(' · ');
    case BalanceFieldType.procEffects:
      final l = v as List? ?? const [];
      if (l.isEmpty) return 'ninguno';
      return l.map((e) {
        final parts = <String>[
          '${e['kind']} ${trimNum(e['value'] as num? ?? 0)}',
          if (e['stat'] != null) _buffLabel(e['stat'] as String),
          if (e['status'] != null) _statusLabel(e['status'] as String),
          if ((e['turns'] as num? ?? 0) > 0) '${e['turns']} t',
        ];
        return parts.join(' ');
      }).join(', ');
    case BalanceFieldType.statusKind:
      return v is String ? _statusLabel(v) : 'ninguno';
    case BalanceFieldType.text:
      final s = '${v ?? ''}';
      return s.length > 70 ? '"${s.substring(0, 67)}…"' : '"$s"';
  }
}

String _lowerFirst(String s) => s.length > 1 &&
        s[1].toLowerCase() == s[1] &&
        s[0].toUpperCase() == s[0]
    ? '${s[0].toLowerCase()}${s.substring(1)}'
    : s;

bool _feminine(BalanceKind k) =>
    k == BalanceKind.skill || k == BalanceKind.mechanic || k == BalanceKind.classDef;

String _changeText(BalanceChange c) {
  if (c.field.key == 'disabled') {
    final a = _feminine(c.kind) ? 'a' : 'o';
    if (c.after == true) {
      return switch (c.kind) {
        BalanceKind.skill => 'desactivada (ya no la otorgan las armas)',
        BalanceKind.affix => 'desactivado (ya no sale en drops ni crafteo)',
        BalanceKind.passiveNode => 'desactivado (ya no da bonificaciones)',
        BalanceKind.mechanic => 'desactivada (sin efecto)',
        _ => 'desactivad$a',
      };
    }
    return 'reactivad$a';
  }
  if (c.field.type == BalanceFieldType.text) {
    return '${_lowerFirst(c.field.label)} actualizada';
  }
  return '${_lowerFirst(c.field.label)} ${c.beforeText} → ${c.afterText}';
}

/// Notas de parche en castellano a partir del diff (§ 5.1), listas para
/// editar.
String buildPatchNotes({
  required String version,
  required List<BalanceChange> changes,
  String intro = 'Parche de balance.',
}) {
  final b = StringBuffer()
    ..writeln('# Ecos del Tiempo v$version — Parche de balance')
    ..writeln()
    ..writeln(intro)
    ..writeln();
  if (changes.isEmpty) {
    b.writeln('Sin cambios de balance.');
    return b.toString();
  }
  for (final kind in BalanceKind.values) {
    final ofKind = changes.where((c) => c.kind == kind).toList();
    if (ofKind.isEmpty) continue;
    b
      ..writeln('## ${kind.plural}')
      ..writeln();
    final ids = <String>[];
    for (final c in ofKind) {
      if (!ids.contains(c.id)) ids.add(c.id);
    }
    for (final id in ids) {
      final cs = ofKind.where((c) => c.id == id).toList();
      b.writeln('- **${cs.first.name}**: ${cs.map(_changeText).join('; ')}.');
    }
    b.writeln();
  }
  b.writeln('> Parche de balance: para jugar en grupo, todos necesitan '
      'esta versión (el juego avisa al unirse).');
  return b.toString();
}
