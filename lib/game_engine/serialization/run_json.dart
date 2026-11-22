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
              );
            }(),
        ],
      );
}
