import '../../../game_engine/data/game_catalog.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/loot_filter.dart';
import '../../../game_engine/rules/loot_filter_rules.dart';
import '../../../game_engine/rules/weapon_weight.dart';

/// Editor por casillas del filtro de loot (docs/specs/panels.md § "Filtro
/// de loot" y loot.md § 13.1). Puro: todo trabaja sobre el **texto** del
/// filtro, que sigue siendo lo único que se guarda.
///
/// - Una regla del texto es un bloque: su línea `Mostrar`/`Ocultar` y las
///   que siguen hasta la próxima regla ([FilterBlock]).
/// - Apagar una regla le antepone `#OFF ` a cada línea: queda en el texto
///   como comentario (el parser la ignora) y se vuelve a prender sacando
///   ese prefijo.
/// - Las casillas de OCULTAR RÁPIDO generan reglas con nombre
///   `# rápido: …` con un texto fijo ([QuickOption.rule]). Al leer el
///   texto, una casilla está marcada si su regla está tal cual y prendida;
///   si el jugador la editó a mano, la casilla queda desmarcada y la regla
///   sigue como una regla suya.

/// Grupo de casillas (una fila en la UI).
enum QuickGroup {
  excepcion('Excepción'),
  rareza('Armas por rareza'),
  peso('Armas por peso'),
  tipo('Armas por tipo'),
  otras('Otras armas'),
  materiales('Materiales y pociones');

  const QuickGroup(this.label);
  final String label;
}

/// Una casilla: [rule] es el texto exacto de la regla que agrega.
class QuickOption {
  const QuickOption(this.id, this.group, this.label, this.rule);
  final String id;
  final QuickGroup group;
  final String label;
  final String rule;
}

/// Prefijo de las líneas de una regla apagada.
const kRuleOffPrefix = '#OFF ';

/// Una regla del texto: líneas `[start, end)`.
class FilterBlock {
  const FilterBlock({
    required this.start,
    required this.end,
    required this.enabled,
    required this.text,
    this.rule,
    this.errors = const [],
    this.quickId,
  });

  final int start;
  final int end;

  /// `false` = apagada (`#OFF`): está en el texto pero no aplica.
  final bool enabled;

  /// Su texto sin los `#OFF`.
  final String text;

  /// La regla leída de [text] (`null` si no se entiende la cabecera).
  final FilterRule? rule;

  /// Errores del parser dentro de esta regla.
  final List<String> errors;

  /// La casilla de OCULTAR RÁPIDO a la que corresponde (texto idéntico).
  final String? quickId;

  bool get show => rule?.show ?? true;
}

/// El texto del filtro partido en reglas, con las operaciones de las
/// casillas y de la lista de reglas. Cada operación devuelve el texto
/// nuevo; lo que no toca queda igual, carácter por carácter.
class FilterDoc {
  FilterDoc._(this.text, this.options, this._lines, this.blocks);

  factory FilterDoc.parse(String text, List<QuickOption> options,
      {GameCatalog catalog = GameCatalog.standard}) {
    final lines = text.split('\n');
    final limit = _limit(lines);
    final heads = [
      for (var i = 0; i < limit; i++)
        if (_isHeader(_unOff(lines[i]) ?? lines[i])) i
    ];
    final fr = LootFilterRules(catalog: catalog);
    final canon = {for (final o in options) _norm(o.rule): o.id};
    final blocks = <FilterBlock>[];
    for (var k = 0; k < heads.length; k++) {
      final start = heads[k];
      final end = k + 1 < heads.length ? heads[k + 1] : limit;
      final raw = lines.sublist(start, end);
      final enabled = _unOff(raw.first) == null;
      final body = [for (final l in raw) _unOff(l) ?? l].join('\n');
      final parsed = fr.parse(body);
      blocks.add(FilterBlock(
        start: start,
        end: end,
        enabled: enabled,
        text: body,
        rule: parsed.filter.rules.firstOrNull,
        errors: parsed.errors,
        quickId: canon[_norm(body)],
      ));
    }
    return FilterDoc._(text, options, lines, blocks);
  }

  final String text;
  final List<QuickOption> options;
  final List<String> _lines;
  final List<FilterBlock> blocks;

  /// Casillas marcadas: su regla está tal cual y prendida.
  Set<String> get checked => {
        for (final b in blocks)
          if (b.enabled && b.quickId != null) b.quickId!
      };

  /// Prende o apaga la regla [i] (apagada = comentada con `#OFF`).
  String setEnabled(int i, bool on) {
    final b = blocks[i];
    if (b.enabled == on) return text;
    final out = [..._lines];
    for (var n = b.start; n < b.end; n++) {
      final l = out[n];
      if (on) {
        out[n] = _unOff(l) ?? l;
      } else if (l.trim().isNotEmpty && _unOff(l) == null) {
        out[n] = '$kRuleOffPrefix$l';
      }
    }
    return out.join('\n');
  }

  /// Borra la regla [i] (sus líneas).
  String remove(int i) {
    final b = blocks[i];
    return ([..._lines]..removeRange(b.start, b.end)).join('\n');
  }

  /// Marca o desmarca la casilla [id]. Las reglas rápidas prendidas se
  /// vuelven a escribir juntas, en el orden de [options] (la excepción ★
  /// primero), antes de la primera de las demás reglas; las reglas del
  /// jugador (y las rápidas apagadas de otras casillas) no se tocan.
  String setQuick(String id, bool on) {
    final want = {...checked};
    if (on ? !want.add(id) : !want.remove(id)) return text;
    final drop = [
      for (final b in blocks)
        if (b.quickId != null && (b.enabled || b.quickId == id)) b
    ];
    final out = [..._lines];
    for (final b in drop.reversed) {
      out.removeRange(b.start, b.end);
    }
    final firstKept = blocks.where((b) => !drop.contains(b)).firstOrNull;
    final at = firstKept == null
        ? _limit(out)
        : firstKept.start -
            drop
                .where((b) => b.start < firstKept.start)
                .fold<int>(0, (n, b) => n + b.end - b.start);
    final add = [
      for (final o in options)
        if (want.contains(o.id)) ...o.rule.trimRight().split('\n'),
    ];
    out.insertAll(at, add);
    return out.join('\n');
  }

  /// Resumen legible de una regla para la lista: nombre o condiciones.
  static String summary(FilterBlock b) {
    final r = b.rule;
    if (r == null) return b.text.split('\n').first.trim();
    return r.name ?? conditionsText(b);
  }

  /// Las condiciones de la regla (`Rareza Común · Tipo hacha`); `todo`
  /// si no tiene ninguna.
  static String conditionsText(FilterBlock b) {
    final cs = b.rule?.conditions ?? const [];
    return cs.isEmpty ? 'todo' : [for (final c in cs) c.text].join(' · ');
  }

  // ---- texto ----

  /// Líneas útiles: sin la vacía final que deja un `\n` al final.
  static int _limit(List<String> lines) =>
      lines.isNotEmpty && lines.last.isEmpty ? lines.length - 1 : lines.length;

  /// La línea sin el `#OFF ` de una regla apagada (`null` si no lo tiene).
  static String? _unOff(String l) {
    if (l.startsWith(kRuleOffPrefix)) {
      return l.substring(kRuleOffPrefix.length);
    }
    return l.trimRight() == '#OFF' ? '' : null;
  }

  static bool _isHeader(String l) {
    final words = l.split('#').first.trim().split(RegExp(r'\s+'));
    final w = words.first.toLowerCase();
    return w == 'mostrar' || w == 'ocultar';
  }

  /// Para comparar con el texto de una casilla: sin líneas vacías y con
  /// los espacios colapsados.
  static String _norm(String s) => [
        for (final l in s.split('\n'))
          if (l.trim().isNotEmpty) l.trim().replaceAll(RegExp(r'\s+'), ' ')
      ].join('\n');
}

/// Las casillas de OCULTAR RÁPIDO para [catalog] (tipos de arma del
/// catálogo). Las de tipo, peso, "no podés usar" y "nivel bajo" nunca
/// ocultan Épicos ni Legendarios (`Rareza <= Raro`); las de rareza solo
/// tocan armas (`Objeto Arma`: un Eco también tiene rareza).
List<QuickOption> quickOptions([GameCatalog catalog = GameCatalog.standard]) {
  String hide(String name, List<String> conds) =>
      'Ocultar # rápido: $name\n${[for (final c in conds) '  $c\n'].join()}';
  const upToRare = 'Rareza <= Raro';
  final types = <String>[];
  for (final w in catalog.weapons.values) {
    if (!types.contains(w.type)) types.add(w.type);
  }
  String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  return [
    const QuickOption(
        'build',
        QuickGroup.excepcion,
        'Mostrar siempre lo de mi build (★)',
        'Mostrar # rápido: lo de mi build\n'
            '  Build\n'
            '  Rareza <= Épico\n'
            '  Borde 195 155 255\n'
            '  Fondo 30 12 50 220\n'
            '  Tamaño 36\n'
            '  Sonido campana\n'
            '  Icono estrella violeta\n'),
    for (final (r, l) in const [
      (Rarity.comun, 'Comunes'),
      (Rarity.magico, 'Mágicas'),
      (Rarity.raro, 'Raras'),
      (Rarity.epico, 'Épicas'),
    ])
      QuickOption(
          'rareza-${r.name}',
          QuickGroup.rareza,
          l,
          hide('armas ${l.toLowerCase()}',
              ['Objeto Arma', 'Rareza ${r.label}'])),
    for (final (c, l) in const [
      (WeightClass.ligera, 'Ligeras'),
      (WeightClass.media, 'Medias'),
      (WeightClass.pesada, 'Pesadas'),
    ])
      QuickOption('peso-${c.name}', QuickGroup.peso, l,
          hide('armas ${l.toLowerCase()}', ['Peso ${c.label}', upToRare])),
    for (final t in types)
      QuickOption('tipo-$t', QuickGroup.tipo, cap(t),
          hide('tipo $t', ['Tipo $t', upToRare])),
    QuickOption('no-utilizable', QuickGroup.otras, 'Que no podés usar',
        hide('armas que no podés usar', ['Utilizable No', upToRare])),
    QuickOption(
        'nivel-bajo',
        QuickGroup.otras,
        'De nivel bajo (6 o más debajo del tuyo)',
        hide('armas de nivel bajo', ['NivelRelativo <= -6', upToRare])),
    for (final m in const [
      CraftMaterial.esquirla,
      CraftMaterial.cristal,
      CraftMaterial.prisma,
      CraftMaterial.ancla,
    ])
      QuickOption('mat-${m.name}', QuickGroup.materiales, m.label,
          hide(m.label, ['Material ${m.name}'])),
    QuickOption(
        'mat-fragmentos',
        QuickGroup.materiales,
        'Fragmentos',
        hide('fragmentos', [
          'Material ${[
            CraftMaterial.fragReloj,
            CraftMaterial.fragEco,
            CraftMaterial.fragCorona,
            CraftMaterial.fragEras,
          ].map((m) => m.name).join(' ')}'
        ])),
    QuickOption('pociones', QuickGroup.materiales, 'Pociones y éter',
        hide('pociones', ['Objeto Pocion'])),
  ];
}
