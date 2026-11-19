import '../../../game_engine/data/elements_catalog.dart';
import '../../../game_engine/data/enemy_families.dart' show ComboRulesDef;
import '../../../game_engine/models/status.dart';
import '../../../game_engine/rules/js_math.dart';
import 'skill_text.dart' show statusHex;

/// Textos de elementos y reacciones (docs/specs/elemental_reactions.md
/// § 3): color de cada elemento, la línea "Elemento: Agua · reacciona
/// con ..." de las fichas de habilidad, los textos de Mojado / Cargado /
/// Congelación v0.7 y el cartel de cada reacción. Dart puro, en el
/// markup de `ProtoMarkup` como `skill_text.dart`. Los números salen del
/// catálogo (`kReactions`, `kElementStatuses`; el admin de balance los
/// edita): se pueden pasar los del catálogo activo.

/// Color del elemento (`#rrggbb`): el de su estado (`statusHex`, única
/// fuente); Físico, gris claro.
String elementHex(GameElement e) {
  final st = e.status;
  return st == null ? '#dfe6e9' : statusHex(st);
}

/// Cartel sobre el objetivo (`¡ELECTROCUCIÓN!`).
String reactionBanner(ReactionKind k) => '¡${k.label.toUpperCase()}!';

/// Color de la reacción.
String reactionHex(ReactionKind k) => switch (k) {
      ReactionKind.electrocucion ||
      ReactionKind.cortocircuito =>
        statusHex(StatusKind.charged),
      ReactionKind.explosionToxica => '#badc58',
      ReactionKind.congelacionSubita => '#81ecec',
      ReactionKind.derretir => '#ff9f43',
      ReactionKind.combustion => '#e17055',
    };

const kComboRulesDefault = ComboRulesDef();

String _pct(double v) => '${jsRound(v * 100)}%';
String _x(double v) => '×${fm(v)}';

ReactionDef _def(ReactionKind k, Map<String, ReactionDef>? defs) =>
    defs?[k.name] ?? kReactions[k.name]!;

ElementStatusDef _st(StatusKind k, Map<String, ElementStatusDef>? defs) =>
    defs?[k.name] ?? kElementStatuses[k.name]!;

/// Qué hace la reacción (una frase, sin lore), con los números de [defs]
/// (por defecto los del catálogo).
String reactionDescription(ReactionKind k, {Map<String, ReactionDef>? defs}) {
  final d = _def(k, defs);
  return switch (k) {
    ReactionKind.electrocucion =>
      'Electro sobre Mojado: el golpe hace ${_x(d.damageMult)}'
          '${d.stunTurns > 0 ? ' y aturde ${d.stunTurns} '
              '${d.stunTurns == 1 ? 'turno' : 'turnos'}' : ''}. Consume Mojado.',
    ReactionKind.explosionToxica =>
      'Convergencia. Fuego sobre Veneno: ${_convergence(d, StatusKind.poison)}',
    ReactionKind.combustion =>
      'Convergencia. Veneno sobre Quemadura: ${_convergence(d, StatusKind.burn)}',
    ReactionKind.congelacionSubita =>
      'Hielo sobre Mojado: Congelación completa al instante (pierde el '
          'turno). Consume Mojado.',
    ReactionKind.derretir =>
      'Fuego sobre Congelación: el golpe hace ${_x(d.damageMult)} y quita '
          'la Congelación.',
    ReactionKind.cortocircuito =>
      'Agua sobre Cargado: el golpe salta a 1 enemigo más con '
          '${_pct(d.splash)}. Consume Cargado.',
  };
}

/// Texto común de las Convergencias (combo_balance.md § 4).
String _convergence(ReactionDef d, StatusKind primer) =>
    'consume los stacks de ${primer.label}; ${fm(d.perStack * 100)}% de la vida '
    'máx. por stack (tope ${_pct(d.commonCap)} común, ${_pct(d.eliteCap)} '
    'élite, ${_pct(d.bossCap)} jefe), ${_x(kComboRulesDefault.weakMult)} si '
    'es débil al elemento que detona y ${_x(kComboRulesDefault.resistMult)} si '
    'lo resiste${d.splash > 0 ? '; ${_pct(d.splash)} a los demás' : ''}. '
    'Ignora el tope por golpe y tiene Quebrar.';

/// Elementos con los que [e] reacciona, con sus reacciones (en cualquier
/// orden: dejar el estado o detonarlo), en el orden de la tabla.
Map<GameElement, List<ReactionKind>> elementPartners(GameElement e) {
  final out = <GameElement, List<ReactionKind>>{};
  for (final r in kReactionTable) {
    final first = statusElement(r.primer);
    final other = first == e
        ? r.detonator
        : r.detonator == e
            ? first
            : null;
    if (other == null) continue;
    (out[other] ??= []).add(r.kind);
  }
  return out;
}

String _joinY(List<String> parts) => parts.length <= 1
    ? parts.join()
    : '${parts.sublist(0, parts.length - 1).join(', ')} y ${parts.last}';

/// `Elemento: Agua · reacciona con Electro (Electrocución, Cortocircuito)
/// y Hielo (Congelación súbita)`, en texto plano.
String elementReactionLine(GameElement e) {
  final p = elementPartners(e);
  final head = 'Elemento: ${e.label}';
  if (p.isEmpty) return '$head · sin reacciones';
  return '$head · reacciona con ${_joinY([
        for (final x in p.entries)
          '${x.key.label} (${x.value.map((k) => k.label).join(', ')})'
      ])}';
}

String _span(String hex, String text) =>
    '<span style="color:$hex">$text</span>';

/// [elementReactionLine] en markup: cada elemento en su color, el resto
/// en `k` (gris), como la línea de tipo de `skillTipMarkup`.
String elementReactionMarkup(GameElement e) {
  final p = elementPartners(e);
  final head =
      '<span class="k">Elemento:</span> ${_span(elementHex(e), e.label)}';
  if (p.isEmpty) return '$head <span class="k">· sin reacciones</span>';
  return '$head <span class="k">· reacciona con</span> ${_joinY([
        for (final x in p.entries)
          '${_span(elementHex(x.key), x.key.label)} '
              '<span class="k">(${x.value.map((k) => k.label).join(', ')})</span>'
      ])}';
}

// ---------------------------------------------------------------- estados

/// `STATUS[k].desc` de Mojado, Cargado y la Congelación v0.7, con los
/// números del catálogo. `null` para los demás estados.
String? elementalStatusDescription(StatusKind k,
    {Map<String, ReactionDef>? reactions,
    Map<String, ElementStatusDef>? statuses}) {
  String turns(int n) => '$n ${n == 1 ? 'turno' : 'turnos'}';
  return switch (k) {
    StatusKind.wet => 'No hace daño (${turns(_st(k, statuses).turns)}). '
        'Electro lo detona: Electrocución '
        '(${_x(_def(ReactionKind.electrocucion, reactions).damageMult)} y '
        'aturde). Hielo lo detona: Congelación súbita (pierde el turno).',
    StatusKind.charged => 'No hace daño (${turns(_st(k, statuses).turns)}). '
        'Agua lo detona: Cortocircuito (el golpe salta a otro enemigo con '
        '${_pct(_def(ReactionKind.cortocircuito, reactions).splash)}).',
    StatusKind.freeze => freezeDescription(
        def: _st(k, statuses),
        melt: _def(ReactionKind.derretir, reactions).damageMult),
    _ => null,
  };
}

/// Congelación v0.7 (elemental_reactions.md § 7): ralentiza, prepara el
/// quiebre y a 5 stacks congela y deja Quebradizo.
String freezeDescription({ElementStatusDef? def, double? melt}) {
  final d = def ?? kElementStatuses['freeze']!;
  final m = melt ?? kReactions['derretir']!.damageMult;
  return '−${_pct(d.slowPerStack)} velocidad y +${_pct(d.breakPerStack)} de '
      'quiebre recibido por stack. Con ${StatusKind.freeze.maxStacks} '
      'stacks: CONGELADO (pierde su turno) y Quebradizo (el próximo golpe '
      'físico hace ${_x(d.brittleMult)}). Después, ${d.turns} turnos sin '
      'poder congelarse. Fuego lo detona: Derretir (${_x(m)}). Pierde 1 '
      'stack por turno.';
}

/// Tooltip (markup) del chip `▼VEL` de la Congelación.
String freezeSlowTip(int stacks, {ElementStatusDef? def}) {
  final d = def ?? kElementStatuses['freeze']!;
  final slow = jsRound(d.slowPerStack * stacks * 100);
  final brk = jsRound(d.breakPerStack * stacks * 100);
  return '<b style="color:#74b9ff">▼ Velocidad −$slow%</b> '
      '<span class="k">(Congelación ×$stacks)</span><br>'
      '−${_pct(d.slowPerStack)} velocidad por stack: su turno llega más '
      'tarde. +$brk% de quiebre recibido.';
}

/// Tooltip (markup) del chip Quebradizo.
String brittleTip({ElementStatusDef? def}) {
  final d = def ?? kElementStatuses['freeze']!;
  return '<b style="color:#81ecec">Quebradizo</b><br>Congelado: el próximo '
      'golpe físico hace ${_x(d.brittleMult)} y lo descongela.';
}

/// Tooltip (markup) del chip de resistencia al hielo.
String freezeResistTip(int turns) =>
    '<b style="color:#74b9ff">Resiste el hielo</b> '
    '<span class="k">· $turns ${turns == 1 ? 'turno' : 'turnos'}</span><br>'
    'Recién descongelado: no se le puede volver a congelar (tampoco con '
    'Congelación súbita).';

// ---------------------------------------------------------------- familias

/// Reacciones que la inmunidad [immune] de una familia corta (§ 2: un
/// Elemental ígneo no se quema...), con el estado que lo impide: la que
/// necesita ese estado puesto, y la Congelación súbita si no se congela.
List<(ReactionKind, StatusKind)> blockedReactions(Set<StatusKind> immune) => [
      for (final r in kReactionTable)
        if (immune.contains(r.primer))
          (r.kind, r.primer)
        else if (r.kind == ReactionKind.congelacionSubita &&
            immune.contains(StatusKind.freeze))
          (r.kind, StatusKind.freeze),
    ];

/// `Explosión tóxica (inmune a Veneno), Derretir (inmune a Congelación)`,
/// o vacío.
String blockedReactionsLine(Set<StatusKind> immune) => [
      for (final (k, st) in blockedReactions(immune))
        '${k.label} (inmune a ${st.label})'
    ].join(', ');
