import 'package:yaml/yaml.dart';

/// Layout como datos (docs/specs/editor_layout.md § 2). Dart puro.
///
/// Una pantalla declara en código sus **regiones** (template) y su
/// catálogo de **slots** ([LayoutScreenSpec]); el [LayoutDoc] solo dice
/// en qué región y en qué orden va cada slot, y reglas por corte de
/// ancho. Nunca píxeles (§ 5, P1).

/// Cuatro cortes de ancho globales, medidos en anchos de texto (§ 5,
/// P6). Ver [LayoutBreakpoints].
enum LayoutBreakpoint { narrow, medium, wide, ultra }

/// Umbrales globales de los cortes, en anchos de texto (`tx`): un `tx`
/// son [txBase] píxeles lógicos al 100 % de texto y crece con el tamaño
/// de letra (`RetroType.width`). El ancho que se mide es el de la
/// región raíz de la pantalla (no la ventana).
abstract final class LayoutBreakpoints {
  static const txBase = 10.0;

  /// `narrow` < 60 tx ≤ `medium` < 90 tx ≤ `wide` < 140 tx ≤ `ultra`.
  static const medium = 60.0, wide = 90.0, ultra = 140.0;

  static LayoutBreakpoint of(double widthTx) {
    if (!widthTx.isFinite) return LayoutBreakpoint.wide;
    if (widthTx < medium) return LayoutBreakpoint.narrow;
    if (widthTx < wide) return LayoutBreakpoint.medium;
    if (widthTx < ultra) return LayoutBreakpoint.wide;
    return LayoutBreakpoint.ultra;
  }
}

/// Eje de una región o de un grupo.
enum LayoutAxis { row, column, wrap }

/// Alineación de los hijos sobre el eje cruzado / del grupo.
enum LayoutAlign { start, center, end }

T? _enum<T extends Enum>(List<T> values, Object? v) {
  if (v is! String) return null;
  for (final e in values) {
    if (e.name == v) return e;
  }
  return null;
}

/// Reglas de un slot (o grupo) para un corte. `null` = hereda de la base.
class SlotRule {
  const SlotRule(
      {this.region,
      this.order,
      this.axis,
      this.hide,
      this.stretch,
      this.align,
      this.minWidth});

  /// Otra región (o grupo) en este corte.
  final String? region;

  /// Posición (índice) dentro de la región en este corte.
  final int? order;

  /// Eje de un grupo.
  final LayoutAxis? axis;

  /// Ocultar (solo si el slot es `hideable`).
  final bool? hide;

  /// Ocupar todo el ancho de la región.
  final bool? stretch;
  final LayoutAlign? align;

  /// Ancho mínimo en anchos de texto.
  final double? minWidth;

  bool get isEmpty =>
      region == null &&
      order == null &&
      axis == null &&
      hide == null &&
      stretch == null &&
      align == null &&
      minWidth == null;

  /// [other] pisa lo que define.
  SlotRule merged(SlotRule other) => SlotRule(
        region: other.region ?? region,
        order: other.order ?? order,
        axis: other.axis ?? axis,
        hide: other.hide ?? hide,
        stretch: other.stretch ?? stretch,
        align: other.align ?? align,
        minWidth: other.minWidth ?? minWidth,
      );

  SlotRule copyWith({
    Object? region = _keep,
    Object? order = _keep,
    Object? axis = _keep,
    Object? hide = _keep,
    Object? stretch = _keep,
    Object? align = _keep,
    Object? minWidth = _keep,
  }) =>
      SlotRule(
        region: region == _keep ? this.region : region as String?,
        order: order == _keep ? this.order : order as int?,
        axis: axis == _keep ? this.axis : axis as LayoutAxis?,
        hide: hide == _keep ? this.hide : hide as bool?,
        stretch: stretch == _keep ? this.stretch : stretch as bool?,
        align: align == _keep ? this.align : align as LayoutAlign?,
        minWidth: minWidth == _keep ? this.minWidth : minWidth as double?,
      );

  static SlotRule parse(Object? m) {
    if (m is! Map) return const SlotRule();
    final mw = m['minWidth'];
    return SlotRule(
      region: m['region'] as String?,
      order: (m['order'] as num?)?.toInt(),
      axis: _enum(LayoutAxis.values, m['axis']),
      hide: m['hide'] as bool?,
      stretch: m['stretch'] as bool?,
      align: _enum(LayoutAlign.values, m['align']),
      minWidth: mw is num ? mw.toDouble() : null,
    );
  }

  /// `{region: x, order: 0, ...}` en una línea (YAML de flujo).
  String encode() {
    final parts = <String>[
      if (region != null) 'region: $region',
      if (order != null) 'order: $order',
      if (axis != null) 'axis: ${axis!.name}',
      if (hide != null) 'hide: $hide',
      if (stretch != null) 'stretch: $stretch',
      if (align != null) 'align: ${align!.name}',
      if (minWidth != null) 'minWidth: ${_num(minWidth!)}',
    ];
    return '{${parts.join(', ')}}';
  }

  @override
  bool operator ==(Object other) =>
      other is SlotRule &&
      other.region == region &&
      other.order == order &&
      other.axis == axis &&
      other.hide == hide &&
      other.stretch == stretch &&
      other.align == align &&
      other.minWidth == minWidth;

  @override
  int get hashCode =>
      Object.hash(region, order, axis, hide, stretch, align, minWidth);
}

const _keep = Object();

String _num(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Dónde va un slot en la base: su región (o el id del grupo que lo
/// contiene) y su orden ahí.
class SlotPlacement {
  const SlotPlacement(this.id, this.region, this.order,
      {this.rule = const SlotRule()});
  final String id;

  /// Región de la pantalla o id de un grupo (slot contenedor).
  final String region;
  final int order;

  /// Reglas de la base (eje, ocultar, ...) además de región y orden.
  final SlotRule rule;

  SlotPlacement copyWith({String? region, int? order, SlotRule? rule}) =>
      SlotPlacement(id, region ?? this.region, order ?? this.order,
          rule: rule ?? this.rule);

  @override
  bool operator ==(Object other) =>
      other is SlotPlacement &&
      other.id == id &&
      other.region == region &&
      other.order == order &&
      other.rule == rule;

  @override
  int get hashCode => Object.hash(id, region, order, rule);
}

/// Disposición resuelta para un corte: por región (o grupo), los ids en
/// orden, más las reglas efectivas de cada slot.
class ResolvedLayout {
  ResolvedLayout(this.children, this.rules);

  /// Región o grupo → ids en orden (sin los ocultos).
  final Map<String, List<String>> children;

  /// Regla efectiva (base + corte) de cada slot.
  final Map<String, SlotRule> rules;

  List<String> of(String region) => children[region] ?? const [];
  SlotRule ruleOf(String id) => rules[id] ?? const SlotRule();

  /// Región o grupo donde quedó [id] (o `null` si está oculto).
  String? containerOf(String id) {
    for (final MapEntry(:key, :value) in children.entries) {
      if (value.contains(id)) return key;
    }
    return null;
  }
}

/// Un archivo `<screen>.layout.yaml` (§ 2.2), inmutable.
class LayoutDoc {
  LayoutDoc({
    required this.screen,
    this.version = 1,
    required List<SlotPlacement> slots,
    Map<LayoutBreakpoint, Map<String, SlotRule>> breakpoints = const {},
  })  : slots = List.unmodifiable(slots),
        breakpoints = Map.unmodifiable({
          for (final MapEntry(:key, :value) in breakpoints.entries)
            if (value.isNotEmpty) key: Map<String, SlotRule>.unmodifiable(value),
        });

  final String screen;
  final int version;
  final List<SlotPlacement> slots;
  final Map<LayoutBreakpoint, Map<String, SlotRule>> breakpoints;

  static const schema = 1;

  SlotPlacement? placementOf(String id) {
    for (final s in slots) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// La base: región → ids en orden.
  Map<String, List<String>> get baseChildren {
    final out = <String, List<SlotPlacement>>{};
    for (final s in slots) {
      (out[s.region] ??= []).add(s);
    }
    return {
      for (final MapEntry(:key, :value) in out.entries)
        key: [for (final s in value..sort((a, b) => a.order.compareTo(b.order))) s.id],
    };
  }

  /// Cache de [resolve] (el doc es inmutable): por build solo se elige el
  /// corte (§ 4, "Rendimiento").
  late final _resolved = <LayoutBreakpoint?, ResolvedLayout>{};

  /// Disposición para [bp] (`null` = la base): parte de la base y aplica
  /// las reglas del corte (región/orden mueven; `hide` saca).
  ResolvedLayout resolve(LayoutBreakpoint? bp) =>
      _resolved[bp] ??= _resolve(bp);

  ResolvedLayout _resolve(LayoutBreakpoint? bp) {
    final over = bp == null ? const <String, SlotRule>{} : breakpoints[bp] ?? const {};
    final rules = <String, SlotRule>{
      for (final s in slots) s.id: s.rule.merged(over[s.id] ?? const SlotRule()),
    };
    final children = baseChildren;
    // Movidos en este corte: se sacan y se insertan en su índice.
    final moved = [
      for (final s in slots)
        if (over[s.id] case final r?
            when r.region != null || r.order != null)
          (s.id, r.region ?? s.region, r.order),
    ]..sort((a, b) => (a.$3 ?? 1 << 30).compareTo(b.$3 ?? 1 << 30));
    for (final (id, _, _) in moved) {
      for (final l in children.values) {
        l.remove(id);
      }
    }
    for (final (id, region, order) in moved) {
      final l = children[region] ??= [];
      final at = order == null ? l.length : order.clamp(0, l.length);
      l.insert(at, id);
    }
    for (final MapEntry(key: id, value: r) in rules.entries) {
      if (r.hide == true) {
        for (final l in children.values) {
          l.remove(id);
        }
      }
    }
    return ResolvedLayout(children, rules);
  }

  // ---------------------------------------------------------- edición

  /// Mueve [id] a [region] en la posición [index] (de la base o de [bp]).
  LayoutDoc move(String id, String region, int index, {LayoutBreakpoint? bp}) {
    if (bp != null) {
      return withRule(bp, id, (r) => r.copyWith(region: region, order: index));
    }
    final kids = baseChildren;
    for (final l in kids.values) {
      l.remove(id);
    }
    final l = kids[region] ??= [];
    l.insert(index.clamp(0, l.length), id);
    final pos = <String, (String, int)>{
      for (final MapEntry(key: r, value: ids) in kids.entries)
        for (var i = 0; i < ids.length; i++) ids[i]: (r, i),
    };
    return LayoutDoc(
      screen: screen,
      version: version,
      slots: [
        for (final s in slots)
          s.copyWith(region: pos[s.id]!.$1, order: pos[s.id]!.$2),
      ],
      breakpoints: breakpoints,
    );
  }

  /// Cambia las reglas de [id] en [bp] (`null` = base, sin región/orden).
  LayoutDoc withRule(
      LayoutBreakpoint? bp, String id, SlotRule Function(SlotRule) f) {
    if (bp == null) {
      return LayoutDoc(
        screen: screen,
        version: version,
        slots: [
          for (final s in slots)
            s.id == id
                ? s.copyWith(
                    rule: f(s.rule).copyWith(region: null, order: null))
                : s,
        ],
        breakpoints: breakpoints,
      );
    }
    final m = {...?breakpoints[bp]};
    final r = f(m[id] ?? const SlotRule());
    if (r.isEmpty) {
      m.remove(id);
    } else {
      m[id] = r;
    }
    return LayoutDoc(
      screen: screen,
      version: version,
      slots: slots,
      breakpoints: {...breakpoints, bp: m},
    );
  }

  // ------------------------------------------------------------ YAML

  /// Lanza [FormatException] si no es un layout.
  static LayoutDoc parse(String yaml) {
    final Object? doc;
    try {
      doc = loadYaml(yaml);
    } on YamlException catch (e) {
      throw FormatException('YAML inválido: ${e.message}');
    }
    if (doc is! YamlMap || doc['screen'] is! String) {
      throw const FormatException('Falta screen:');
    }
    final version = (doc['version'] as num?)?.toInt() ?? 1;
    if (version > schema) {
      throw FormatException('Versión $version no soportada');
    }
    final slots = <SlotPlacement>[];
    final orders = <String, int>{};
    void add(String id, String region, int? order, SlotRule rule) {
      final o = order ?? orders[region] ?? 0;
      orders[region] = o + 1;
      slots.add(SlotPlacement(id, region, o,
          rule: rule.copyWith(region: null, order: null)));
    }

    final raw = doc['slots'];
    if (raw is! YamlList) throw const FormatException('Falta slots:');
    for (final s in raw) {
      if (s is! YamlMap || s['id'] is! String || s['region'] is! String) {
        throw const FormatException('Slot sin id o sin region');
      }
      final id = s['id'] as String;
      add(id, s['region'] as String, (s['order'] as num?)?.toInt(),
          SlotRule.parse(s));
      final kids = s['children'];
      if (kids is YamlList) {
        for (final k in kids) {
          if (k is String) {
            add(k, id, null, const SlotRule());
          } else if (k is YamlMap && k['id'] is String) {
            add(k['id'] as String, id, (k['order'] as num?)?.toInt(),
                SlotRule.parse(k));
          }
        }
      }
    }
    final bps = <LayoutBreakpoint, Map<String, SlotRule>>{};
    final b = doc['breakpoints'];
    if (b is YamlMap) {
      for (final MapEntry(:key, :value) in b.entries) {
        final bp = _enum(LayoutBreakpoint.values, key);
        if (bp == null) throw FormatException('Corte desconocido: $key');
        if (value is YamlMap) {
          bps[bp] = {
            for (final MapEntry(:key, :value) in value.entries)
              key as String: SlotRule.parse(value),
          };
        }
      }
    }
    return LayoutDoc(
        screen: doc['screen'] as String,
        version: version,
        slots: slots,
        breakpoints: bps);
  }

  /// Texto YAML estable (mismo doc → mismo texto). Los hijos de un grupo
  /// van en `children:` del grupo.
  String encode({String? header}) {
    final b = StringBuffer();
    if (header != null) {
      for (final l in header.split('\n')) {
        b.writeln('# $l');
      }
    }
    b
      ..writeln('screen: $screen')
      ..writeln('version: $version')
      ..writeln('slots:');
    final kids = baseChildren;
    final ids = {for (final s in slots) s.id};
    final groupIds = {for (final k in kids.keys) if (ids.contains(k)) k};
    void slot(SlotPlacement s, String indent, {required bool child}) {
      final extra = s.rule.encode();
      final ruleText = extra == '{}' ? '' : extra.substring(1, extra.length - 1);
      final g = kids[s.id];
      if (child && g == null) {
        b.writeln(ruleText.isEmpty
            ? '$indent- ${s.id}'
            : '$indent- {id: ${s.id}, $ruleText}');
        return;
      }
      final head = '{id: ${s.id}'
          '${child ? '' : ', region: ${s.region}, order: ${s.order}'}'
          '${ruleText.isEmpty ? '' : ', $ruleText'}}';
      if (g == null) {
        b.writeln('$indent- $head');
        return;
      }
      b.writeln('$indent- id: ${s.id}');
      if (!child) {
        b
          ..writeln('$indent  region: ${s.region}')
          ..writeln('$indent  order: ${s.order}');
      }
      for (final MapEntry(:key, :value) in _ruleMap(s.rule).entries) {
        b.writeln('$indent  $key: $value');
      }
      b.writeln('$indent  children:');
      for (final k in g) {
        slot(placementOf(k)!, '$indent    ', child: true);
      }
    }

    final top = [
      for (final s in slots)
        if (!groupIds.contains(s.region)) s,
    ]..sort((a, c) {
        final r = a.region.compareTo(c.region);
        return r != 0 ? r : a.order.compareTo(c.order);
      });
    for (final s in top) {
      slot(s, '  ', child: false);
    }
    if (breakpoints.isNotEmpty) {
      b.writeln('breakpoints:');
      for (final bp in LayoutBreakpoint.values) {
        final m = breakpoints[bp];
        if (m == null) continue;
        b.writeln('  ${bp.name}:');
        for (final id in m.keys.toList()..sort()) {
          b.writeln('    $id: ${m[id]!.encode()}');
        }
      }
    }
    return b.toString();
  }

  static Map<String, String> _ruleMap(SlotRule r) => {
        if (r.axis != null) 'axis': r.axis!.name,
        if (r.hide != null) 'hide': '${r.hide}',
        if (r.stretch != null) 'stretch': '${r.stretch}',
        if (r.align != null) 'align': r.align!.name,
        if (r.minWidth != null) 'minWidth': _num(r.minWidth!),
      };

  /// Igualdad de contenido (sin importar el orden de la lista de slots).
  bool sameAs(LayoutDoc o) => encode() == o.encode();

  @override
  bool operator ==(Object other) => other is LayoutDoc && sameAs(other);

  @override
  int get hashCode => encode().hashCode;
}
