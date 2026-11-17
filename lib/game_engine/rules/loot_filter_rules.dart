import '../data/affixes_catalog.dart';
import '../data/game_catalog.dart';
import '../models/attributes.dart';
import '../models/item.dart';
import '../models/loot.dart';
import '../models/loot_filter.dart';

/// Quién mira el loot (para `Utilizable` y `NivelRelativo`).
class FilterContext {
  const FilterContext({
    required this.level,
    required this.attributes,
    this.classId = '',
  });
  final int level;
  final PlayerAttributes attributes;
  final String classId;
}

/// Resultado de leer un filtro de texto: el filtro (con las líneas que
/// se entendieron) y los errores por línea.
class FilterParseResult {
  const FilterParseResult(this.filter, this.errors);
  final LootFilter filter;
  final List<String> errors;
  bool get ok => errors.isEmpty;
}

/// Parser, serializador y evaluador de filtros de loot (loot.md § 13).
class LootFilterRules {
  const LootFilterRules({this.catalog = GameCatalog.standard});

  final GameCatalog catalog;

  // ------------------------------------------------------------------
  // Filtro por defecto
  // ------------------------------------------------------------------

  /// Oculta Comunes y Mágicos de nivel bajo, resalta raros, épicos,
  /// legendarios y materiales.
  static const defaultText = '''
# Filtro por defecto de Ecos del Tiempo
Mostrar # Legendarios
  Rareza Legendario
  Color 255 140 40
  Borde 255 140 40
  Fondo 40 20 0 220
  Tamaño 42
  Sonido legendario
  Icono estrella naranja
Mostrar # Épicos
  Rareza Épico
  Color 190 110 255
  Borde 190 110 255
  Tamaño 38
  Sonido gema
  Icono diamante violeta
Mostrar # Raros
  Rareza Raro
  Color 255 210 60
  Tamaño 34
  Sonido alerta
  Icono circulo amarillo
Mostrar # Materiales de crafteo
  Objeto Material
  Color 120 230 220
  Borde 120 230 220
  Sonido material
  Icono triangulo celeste
Ocultar # Comunes de nivel bajo
  Rareza Común
  NivelRelativo <= -6
Ocultar # Mágicos de nivel bajo
  Rareza Mágico
  NivelRelativo <= -10
''';

  static final LootFilter defaultFilter =
      const LootFilterRules().parse(defaultText).filter;

  /// El filtro guardado en el perfil (texto) o el por defecto.
  LootFilter fromProfileText(String? text) =>
      text == null ? defaultFilter : parse(text).filter;

  // ------------------------------------------------------------------
  // Estilo por defecto (sin regla que coincida)
  // ------------------------------------------------------------------

  static FilterColor rarityColor(Rarity r) => switch (r) {
        Rarity.comun => const FilterColor(220, 220, 220),
        Rarity.magico => const FilterColor(120, 150, 255),
        Rarity.raro => const FilterColor(255, 210, 60),
        Rarity.epico => const FilterColor(190, 110, 255),
        Rarity.legendario => const FilterColor(255, 140, 40),
      };

  static FilterStyle defaultStyle(LootDrop d) => FilterStyle(
        textColor: d.item != null
            ? rarityColor(d.item!.rarity)
            : const FilterColor(120, 230, 220),
        size: FilterStyle.defaultSize,
      );

  // ------------------------------------------------------------------
  // Evaluación
  // ------------------------------------------------------------------

  /// Gana la primera regla que coincide; sin ninguna, se muestra con el
  /// estilo por defecto.
  FilterVerdict evaluate(LootFilter f, LootDrop d, FilterContext ctx) {
    final base = defaultStyle(d);
    for (var i = 0; i < f.rules.length; i++) {
      final r = f.rules[i];
      if (r.conditions.every((c) => matches(c, d, ctx))) {
        return FilterVerdict(r.show, r.style.over(base), i);
      }
    }
    return FilterVerdict(true, base);
  }

  bool matches(FilterCondition c, LootDrop d, FilterContext ctx) {
    final it = d.item;
    final w = it == null ? null : catalog.weapons[it.baseId];
    switch (c) {
      case KindCondition(:final kinds):
        final k = it != null
            ? LootKind.arma
            : d.stack!.material != null
                ? LootKind.material
                : LootKind.pocion;
        return kinds.contains(k);
      case MaterialCondition(:final materials):
        final m = d.stack?.material;
        return m != null && materials.contains(m);
      default:
        break;
    }
    if (it == null || w == null) return false;
    return switch (c) {
      RarityCondition(:final op, :final rarity) =>
        op.test(it.rarity.index, rarity.index),
      TypeCondition(:final types) =>
        types.any((t) => _fold(t) == _fold(w.type)),
      BaseCondition(:final baseIds) => baseIds.contains(w.id),
      FamilyCondition(:final families) =>
        families.any((f) => _fold(f) == _fold(w.family)),
      ItemLevelCondition(:final op, :final level) =>
        op.test(it.itemLevel, level),
      RelativeLevelCondition(:final op, :final delta) =>
        op.test(it.itemLevel - ctx.level, delta),
      ModCountCondition(:final op, :final count) =>
        op.test(it.affixes.length, count),
      HasModCondition(:final affixId, :final op, :final tier) => it.affixes.any(
          (a) =>
              a.affixId == affixId &&
              (op == null || tier == null || op.test(a.fixed ? 1 : a.tier, tier))),
      PassiveCondition(:final has) =>
        (it.passiveId != null && it.rarity.hasPassive) == has,
      UsableCondition(:final usable) =>
        (ctx.level >= w.level && w.meetsRequirements(ctx.attributes)) ==
            usable,
      KindCondition() || MaterialCondition() => false,
    };
  }

  // ------------------------------------------------------------------
  // Texto
  // ------------------------------------------------------------------

  /// Minúsculas y sin tildes (para comparar palabras clave).
  static String _fold(String s) {
    const from = 'áéíóúüñÁÉÍÓÚÜÑ';
    const to = 'aeiouunAEIOUUN';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final k = from.indexOf(ch);
      b.write(k < 0 ? ch : to[k]);
    }
    return b.toString().toLowerCase();
  }

  static Rarity? _rarity(String s) => switch (_fold(s)) {
        'comun' || 'normal' => Rarity.comun,
        'magico' || 'magica' => Rarity.magico,
        'raro' || 'rara' => Rarity.raro,
        'epico' || 'epica' => Rarity.epico,
        'legendario' || 'legendaria' || 'unico' || 'unica' => Rarity.legendario,
        _ => null,
      };

  static bool? _yesNo(List<String> a) {
    if (a.isEmpty) return true;
    return switch (_fold(a.first)) {
      'si' || 'verdadero' => true,
      'no' || 'falso' => false,
      _ => null,
    };
  }

  /// `[op] valor` → (op, valor). Sin operador, `=`.
  static (FilterOp, String)? _opValue(List<String> a) {
    if (a.isEmpty) return null;
    final op = FilterOp.bySymbol(a.first);
    if (op != null) return a.length == 2 ? (op, a[1]) : null;
    return a.length == 1 ? (FilterOp.eq, a.first) : null;
  }

  static int? _byte(String s) {
    final v = int.tryParse(s);
    return v == null || v < 0 || v > 255 ? null : v;
  }

  static FilterColor? _color(List<String> a) {
    if (a.length != 3 && a.length != 4) return null;
    final v = [for (final x in a) _byte(x)];
    if (v.any((x) => x == null)) return null;
    return FilterColor(v[0]!, v[1]!, v[2]!, a.length == 4 ? v[3]! : 255);
  }

  /// Lee un filtro. Las líneas que no se entienden se ignoran y se
  /// reportan en [FilterParseResult.errors] ("línea N: ...").
  FilterParseResult parse(String text) {
    final rules = <FilterRule>[];
    final errors = <String>[];
    bool? show;
    String? name;
    var conds = <FilterCondition>[];
    FilterColor? text0, border, bg;
    int? size;
    String? sound;
    MapIcon? icon;

    void close() {
      if (show == null) return;
      rules.add(FilterRule(
        show: show!,
        name: name,
        conditions: List.unmodifiable(conds),
        style: FilterStyle(
          textColor: text0,
          borderColor: border,
          backgroundColor: bg,
          size: size,
          sound: sound,
          icon: icon,
        ),
      ));
      show = null;
      name = null;
      conds = [];
      text0 = border = bg = null;
      size = null;
      sound = null;
      icon = null;
    }

    final lines = text.split(RegExp(r'\r?\n'));
    for (var n = 0; n < lines.length; n++) {
      var line = lines[n];
      String? comment;
      final hash = line.indexOf('#');
      if (hash >= 0) {
        comment = line.substring(hash + 1).trim();
        line = line.substring(0, hash);
      }
      final words = line.trim().split(RegExp(r'\s+'))
        ..removeWhere((w) => w.isEmpty);
      if (words.isEmpty) continue;
      void err(String msg) => errors.add('línea ${n + 1}: $msg');
      final key = _fold(words.first);
      final a = words.sublist(1);

      if (key == 'mostrar' || key == 'ocultar') {
        close();
        show = key == 'mostrar';
        name = comment == null || comment.isEmpty ? null : comment;
        if (a.isNotEmpty) err('"${words.first}" va solo en su línea');
        continue;
      }
      if (show == null) {
        err('"${words.first}" fuera de una regla (falta Mostrar u Ocultar)');
        continue;
      }
      switch (key) {
        case 'rareza':
          final ov = _opValue(a);
          final r = ov == null ? null : _rarity(ov.$2);
          if (r == null) {
            err('rareza inválida');
          } else {
            conds.add(RarityCondition(ov!.$1, r));
          }
        case 'tipo':
          if (a.isEmpty) {
            err('falta el tipo de arma');
          } else {
            conds.add(TypeCondition(a));
          }
        case 'base':
          final bad = [for (final b in a) if (!catalog.weapons.containsKey(b)) b];
          if (a.isEmpty || bad.isNotEmpty) {
            err('base desconocida: ${bad.join(' ')}');
          } else {
            conds.add(BaseCondition(a));
          }
        case 'clase':
          final fams = [for (final f in a) _fold(f)];
          final bad = [
            for (final f in fams)
              if (!catalog.classes.keys.map(_fold).contains(f)) f
          ];
          if (a.isEmpty || bad.isNotEmpty) {
            err('clase desconocida: ${bad.join(' ')}');
          } else {
            conds.add(FamilyCondition([
              for (final f in fams)
                catalog.classes.keys.firstWhere((k) => _fold(k) == f),
            ]));
          }
        case 'nivelobjeto' || 'nivelrelativo' || 'mods':
          final ov = _opValue(a);
          final v = ov == null ? null : int.tryParse(ov.$2);
          if (v == null) {
            err('se esperaba "${words.first} <op> número"');
          } else if (key == 'nivelobjeto') {
            conds.add(ItemLevelCondition(ov!.$1, v));
          } else if (key == 'nivelrelativo') {
            conds.add(RelativeLevelCondition(ov!.$1, v));
          } else {
            conds.add(ModCountCondition(ov!.$1, v));
          }
        case 'tienemod':
          if (a.isEmpty || !kAffixes.containsKey(a.first)) {
            err('afijo desconocido: ${a.isEmpty ? '' : a.first}');
          } else if (a.length == 1) {
            conds.add(HasModCondition(a.first));
          } else {
            final op = a.length == 3 ? FilterOp.bySymbol(a[1]) : null;
            final t = a.length == 3 ? int.tryParse(a[2]) : null;
            if (op == null || t == null) {
              err('se esperaba "TieneMod <afijo> [<op> tier]"');
            } else {
              conds.add(HasModCondition(a.first, op: op, tier: t));
            }
          }
        case 'pasiva' || 'utilizable':
          final yes = _yesNo(a);
          if (yes == null) {
            err('se esperaba Si o No');
          } else {
            conds.add(
                key == 'pasiva' ? PassiveCondition(yes) : UsableCondition(yes));
          }
        case 'material':
          final mats = [for (final m in a) CraftMaterial.byName(_fold(m))];
          if (a.isEmpty || mats.any((m) => m == null)) {
            err('material desconocido');
          } else {
            conds.add(MaterialCondition([for (final m in mats) m!]));
          }
        case 'objeto':
          final ks = [
            for (final k in a)
              LootKind.values
                  .where((x) => _fold(x.word) == _fold(k))
                  .firstOrNull,
          ];
          if (a.isEmpty || ks.any((k) => k == null)) {
            err('se esperaba Arma, Material o Pocion');
          } else {
            conds.add(KindCondition([for (final k in ks) k!]));
          }
        case 'color' || 'borde' || 'fondo':
          final c = _color(a);
          if (c == null) {
            err('color inválido (R G B [A], 0–255)');
          } else if (key == 'color') {
            text0 = c;
          } else if (key == 'borde') {
            border = c;
          } else {
            bg = c;
          }
        case 'tamano':
          final v = a.length == 1 ? int.tryParse(a.first) : null;
          if (v == null) {
            err('tamaño inválido');
          } else {
            size = v.clamp(FilterStyle.minSize, FilterStyle.maxSize);
          }
        case 'sonido':
          if (a.length != 1 || !kLootFilterSounds.contains(_fold(a.first))) {
            err('sonido desconocido (${kLootFilterSounds.join(', ')})');
          } else {
            sound = _fold(a.first);
          }
        case 'icono':
          final shape = a.isEmpty
              ? null
              : MapIconShape.values
                  .where((s) => s.name == _fold(a.first))
                  .firstOrNull;
          final color = a.length < 2
              ? MapIconColor.blanco
              : MapIconColor.values
                  .where((c) => c.name == _fold(a[1]))
                  .firstOrNull;
          if (shape == null || color == null || a.length > 2) {
            err('ícono inválido (forma [color])');
          } else {
            icon = MapIcon(shape, color);
          }
        default:
          err('no entiendo "${words.first}"');
      }
    }
    close();
    return FilterParseResult(LootFilter(List.unmodifiable(rules)), errors);
  }

  /// Texto canónico del filtro (lo que se exporta y se guarda).
  String serialize(LootFilter f) {
    final b = StringBuffer();
    for (final r in f.rules) {
      b.writeln('${r.show ? 'Mostrar' : 'Ocultar'}'
          '${r.name == null ? '' : ' # ${r.name}'}');
      for (final c in r.conditions) {
        b.writeln('  ${c.text}');
      }
      final s = r.style;
      if (s.textColor != null) b.writeln('  Color ${s.textColor!.text}');
      if (s.borderColor != null) b.writeln('  Borde ${s.borderColor!.text}');
      if (s.backgroundColor != null) {
        b.writeln('  Fondo ${s.backgroundColor!.text}');
      }
      if (s.size != null) b.writeln('  Tamaño ${s.size}');
      if (s.sound != null) b.writeln('  Sonido ${s.sound}');
      if (s.icon != null) {
        b.writeln('  Icono ${s.icon!.shape.name} ${s.icon!.color.name}');
      }
    }
    return b.toString();
  }
}
