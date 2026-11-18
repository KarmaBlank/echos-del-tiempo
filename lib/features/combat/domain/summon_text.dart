import '../../../game_engine/data/game_catalog.dart';
import '../../../game_engine/data/summoner_catalog.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/player_state.dart';
import '../../../game_engine/models/skill.dart';
import '../../../game_engine/models/weapon.dart';
import '../../../game_engine/rules/js_math.dart';
import '../../../game_engine/rules/summon_rules.dart';
import 'skill_text.dart';

// Textos del Invocador (docs/specs/summoner.md § 8): qué hace cada
// habilidad, los stats de la invocación con tu equipo y de dónde sale.

/// Qué hace en su turno cada tipo (IA).
String summonRoleText(SummonDef d) => switch (d.role) {
      SummonRole.elemental => 'pega a un enemigo con su elemento (prefiere '
          'al que reacciona) y deja su estado',
      SummonRole.golem => 'atrae golpes enemigos (50%), escuda al aliado '
          'más herido y pega flojo',
      SummonRole.espiritu => 'cura al aliado más herido (debajo del 80%) o '
          'marca a un enemigo (+12% daño recibido, 2 turnos)',
    };

/// Stats de [d] invocada por [p] (`null`: solo la fórmula).
SummonStats? summonStatsFor(SummonDef d, Combatant? p, {PlayerBuild? build}) {
  if (p == null) return null;
  final b = build ?? p.build;
  return SummonRules.stats(d,
      magic: p.magic,
      maxHp: p.maxHp,
      speed: p.speed,
      crit: p.critChance,
      level: b?.level ?? 1,
      build: b,
      ids: {...p.mechanics, ...p.keystones});
}

/// "Vida 120 · poder 34 · crítico 5% · 4 turnos" (o la fórmula).
String summonStatsText(SummonDef d, Combatant? p, {PlayerBuild? build}) {
  final st = summonStatsFor(d, p, build: build);
  if (st == null) {
    return 'Vida (MAG × 1.5 + nivel × 6 + 15% de tu vida) × ${fm(d.hp)} · '
        'poder MAG × ${fm(d.atk)} · dura $kSummonTurns turnos';
  }
  return 'Vida <b>${st.hp}</b> · poder <b>${st.attack}</b> · crítico '
      '${jsRound(st.crit * 100)}% · '
      '${st.turns >= kSummonForever ? 'dura hasta caer' : 'dura ${st.turns} turnos'}';
}

/// De dónde sale cada habilidad del Invocador: los tomos que la traen.
List<WeaponDef> summonSourcesOf(String skillId,
    [GameCatalog catalog = GameCatalog.standard]) {
  final out = [
    for (final w in catalog.weapons.values)
      if (w.skillIds.contains(skillId)) w,
  ]..sort((a, b) => a.level.compareTo(b.level));
  return out;
}

/// "Se obtiene con: Tomo del Invocador (Nv 6), Códice… (Nv 30)".
String summonSourcesText(String skillId,
    [GameCatalog catalog = GameCatalog.standard]) {
  final ws = summonSourcesOf(skillId, catalog);
  if (ws.isEmpty) return '';
  return 'Se obtiene con: ${ws.map((w) => '${w.name} (Nv ${w.level})').join(', ')}';
}

/// Líneas de una habilidad o ULT del Invocador para `describeSkillMarkup`
/// (vacío si no es una).
List<String> summonSkillLines(SkillDef tk, Combatant? p) {
  final kind = kSummonSkillKind[tk.id];
  if (kind != null) {
    final d = kSummons[kind]!;
    final st = d.status;
    return [
      'Invoca un <b>${d.name}</b> (${d.element.label}): en su turno '
          '${summonRoleText(d)}',
      summonStatsText(d, p),
      if (st != null) 'Sus golpes: ${statusApplicationMarkup(st)}',
      '<span class="k">Máx. $kSummonMax invocaciones a la vez (la más '
          'vieja se va) · no cuentan para ganar ni perder</span>',
    ];
  }
  final mag = p?.magic;
  return switch (tk.id) {
    'sacrificio' => [
        'Sacrifica tu invocación más vieja: detona su elemento a TODOS '
            'los enemigos, MAG × ${fm(kSacrificePower)}'
            '${mag == null ? '' : ' = <b>${jsRound(mag * kSacrificePower)}</b>'} '
            '(puede detonar reacciones)',
      ],
    'enjambre' => ['Invoca 2 elementales al azar (Fuego, Agua, Electro o Hielo)'],
    'comandar' => ['Todas tus invocaciones actúan ya (no gastan sus turnos)'],
    'ult_portal' => [
        'Invoca a los 4 elementales a la vez (reemplazan a los más viejos); '
            'atacan ya × ${fm(kPortalStrike)} y al terminar cada uno detona '
            'su elemento en todos (MAG × ${fm(kPortalBurst)})',
      ],
    'ult_avatar' => [
        'Te fundís con tus invocaciones por $kAvatarTurns turnos: cada una '
            'te da +${jsRound(kAvatarPower * 100)}% de daño y su estado en '
            'cada golpe; después se consumen',
      ],
    'ult_marea' => [
        'Invoca un Gólem y 2 Espíritus, escudo de '
            '${jsRound(kMareaShield * 100)}% de tu vida máx. a todo el grupo '
            'y tus invocaciones provocan los próximos $kMareaTaunt golpes',
      ],
    _ => const [],
  };
}

/// Líneas de un tomo del Invocador para su tooltip: bonos a las
/// invocaciones (implícito, rareza y forja).
List<String> summonWeaponLines(WeaponDef w) {
  final summons = w.skillIds.any((id) => kSummonerSkills.containsKey(id)) ||
      kWeaponUltOf.containsKey(w.id);
  if (!summons) return const [];
  final imp = [
    for (final m in w.implicit)
      if (kSummonModStats.contains(m.stat)) m.stat.format(m.value),
  ];
  return [
    '<span class="k">INVOCACIONES</span>',
    if (imp.isNotEmpty) 'Implícito: ${imp.join(', ')}',
    'Rareza del tomo: +5% Mágico, +10% Raro, +15% Épico, +25% Legendario '
        'de vida y daño de tus invocaciones; forja Poder +'
        '${jsRound(kSummonForgePerPow * 100)}% por nivel',
  ];
}
