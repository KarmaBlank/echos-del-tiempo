import '../models/attributes.dart';
import '../models/run_state.dart';
import 'json_read.dart';

/// `RunState` ⇄ JSON (clave `run` del snapshot; docs/specs/netcode.md y
/// roguelike.md). El mapa no viaja: sale de la semilla.
abstract final class RunJson {
  static Json toJson(RunState r) => {
        'seed': r.seed,
        'zones': r.zones,
        'f': r.floor,
        if (r.node != null) 'n': r.node,
        'ph': r.phase.name,
        if (r.votes.isNotEmpty) 'v': r.votes,
        if (r.offers.isNotEmpty)
          'o': {
            for (final e in r.offers.entries) e.key: offerToJson(e.value),
          },
        if (r.ready.isNotEmpty) 'ok': r.ready.toList(),
        if (r.missStreak.isNotEmpty) 'ms': r.missStreak,
        if (r.victory != null) 'win': r.victory,
        if (r.wins != 0) 'w': r.wins,
        if (r.boons.isNotEmpty) 'b': r.boons,
        if (r.loadout.isNotEmpty) 'lo': r.loadout,
        if (r.difficulty != 0) 'df': r.difficulty,
        if (r.eliteWins.isNotEmpty) 'ew': r.eliteWins,
        if (r.elitesBeaten.isNotEmpty) 'eb': r.elitesBeaten,
        if (r.bossesBeaten != 0) 'bb': r.bossesBeaten,
        if (r.grownTo != 1) 'gl': r.grownTo,
      };

  static RunState fromJson(Json j) => RunState(
        seed: j.integer('seed'),
        zones: [
          for (final z in j.list('zones'))
            z is num ? z.toInt() : throw FormatException('JSON inválido', z),
        ],
        floor: j.integer('f'),
        node: j.intOrNull('n'),
        phase: j.enumByName('ph', RunPhase.values),
        votes: _intMap(j['v']),
        offers: j['o'] == null
            ? null
            : {
                for (final e in asJson(j['o']).entries)
                  e.key: offerFromJson(asJson(e.value)),
              },
        ready: j['ok'] == null ? null : j.strings('ok').toSet(),
        missStreak: _intMap(j['ms']),
        victory: j['win'] as bool?,
        wins: j.intOrNull('w') ?? 0,
        boons: _strMap(j['b']),
        loadout: _strMap(j['lo']),
        difficulty: j.intOrNull('df') ?? 0,
        eliteWins: _intMap(j['ew']),
        elitesBeaten: j['eb'] == null ? null : j.strings('eb'),
        bossesBeaten: j.intOrNull('bb') ?? 0,
        grownTo: j.intOrNull('gl') ?? 1,
      );

  static Map<String, List<String>>? _strMap(Object? raw) => raw == null
      ? null
      : {
          for (final e in asJson(raw).entries)
            e.key: [
              for (final v in asList(e.value))
                v is String ? v : throw FormatException('JSON inválido', v),
            ],
        };

  static Json prepToJson(RunPrep p) => {
        if (p.skills.isNotEmpty) 's': p.skills,
        if (p.gold != 0) 'g': p.gold,
        if (p.potions != 0) 'p': p.potions,
        if (p.ethers != 0) 'e': p.ethers,
        if (p.attributes.isNotEmpty)
          'a': {for (final e in p.attributes.entries) e.key.name: e.value},
        if (p.boons.isNotEmpty) 'b': p.boons,
      };

  static RunPrep prepFromJson(Json j) => RunPrep(
        skills: j['s'] == null ? const [] : j.strings('s'),
        gold: j.intOrNull('g') ?? 0,
        potions: j.intOrNull('p') ?? 0,
        ethers: j.intOrNull('e') ?? 0,
        attributes: {
          for (final e in (_intMap(j['a']) ?? const <String, int>{}).entries)
            Attribute.values.firstWhere((a) => a.name == e.key,
                orElse: () => throw FormatException('JSON inválido', e.key)):
                e.value,
        },
        boons: j['b'] == null ? const [] : j.strings('b'),
      );

  static Map<String, int>? _intMap(Object? raw) => raw == null
      ? null
      : {
          for (final e in asJson(raw).entries)
            e.key: e.value is num
                ? (e.value as num).toInt()
                : throw FormatException('JSON inválido', e.value),
        };

  static Json offerToJson(RunOffer o) => {
        'n': o.nodes,
        'w': o.weapons,
        if (o.ults.isNotEmpty) 'u': o.ults,
        'x': [
          for (final x in o.extras)
            {
              'k': x.kind.name,
              'a': x.amount,
              if (x.attribute != null) 'at': x.attribute!.name,
              if (x.boon != null) 'bn': x.boon,
            },
        ],
      };

  static RunOffer offerFromJson(Json j) => RunOffer(
        nodes: j.strings('n'),
        weapons: j.strings('w'),
        ults: j['u'] == null ? const [] : j.strings('u'),
        extras: [
          for (final raw in j.list('x'))
            () {
              final x = asJson(raw);
              return RunExtra(
                x.enumByName('k', RunExtraKind.values),
                x.integer('a'),
                attribute: x.enumOrNull('at', Attribute.values),
                boon: x['bn'] as String?,
              );
            }(),
        ],
      );
}
