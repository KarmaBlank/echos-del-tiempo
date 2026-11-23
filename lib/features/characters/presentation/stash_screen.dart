import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../core/i18n/i18n_providers.dart';
import '../../../game_engine/data/achievements_catalog.dart';
import '../../../game_engine/models/achievement.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/inventory_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../world/presentation/session_controller.dart';
import '../domain/stash.dart';
import 'characters_providers.dart';
import 'stash_board.dart';
import 'unclaimed_box.dart';

/// Pantalla `ALIJO COMPARTIDO` (fuera de la sesión): el tablero del alijo
/// ([StashBoard]) sobre la cuenta directa, con el personaje
/// [characterId]. Ver docs/specs/characters.md § 3.
class StashScreen extends ConsumerStatefulWidget {
  const StashScreen({super.key, required this.characterId});

  final String characterId;

  @override
  ConsumerState<StashScreen> createState() => _StashScreenState();
}

class _StashScreenState extends ConsumerState<StashScreen>
    implements StashBoardHost {
  PlayerProfile? _raw;
  PlayerProfile? _p;
  Stash? _stash;
  bool _saving = false;
  String? _notice;

  @override
  ProgressionRules get rules => ref.read(sessionEngineProvider).progression;
  StashRules get _stashRules => StashRules(inventory: rules.inventory);

  @override
  PlayerProfile get profile => _p!;
  @override
  Stash get stash => _stash!;
  @override
  bool get busy => _saving;
  @override
  String? get notice => _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await ref.read(accountRepositoryProvider).load();
    if (!mounted) return;
    final slot = a.byId(widget.characterId);
    setState(() {
      _raw = slot?.profile;
      _p = slot == null ? null : rules.normalize(slot.profile);
      _stash = a.stash;
    });
  }

  /// El perfil a guardar, conservando el aviso de árbol reiniciado que
  /// `normalize` borra (lo muestra la sala al entrar).
  PlayerProfile _keepRefund(PlayerProfile next) {
    final refunded = _raw?.treeRefunded ?? 0;
    if (refunded <= 0) return next;
    return PlayerProfile.fromJson({...next.toJson(), 'tvRef': refunded});
  }

  Future<void> _commit(PlayerProfile p, Stash s) async {
    setState(() {
      _p = p;
      _stash = s;
      _saving = true;
    });
    final save = _keepRefund(p);
    try {
      await ref
          .read(accountRepositoryProvider)
          .update((a) => a.replace(widget.characterId, save).withStash(s));
    } catch (e) {
      if (mounted) {
        setState(() => _notice = ref
            .read(stringsProvider)
            .t('ui.characters.stash.save_failed', {'error': '$e'}));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  String? _batch(StashBatch b) {
    if (b.moved.isEmpty) {
      return b.reason ??
          ref.read(stringsProvider).t('ui.characters.stash.nothing_to_move');
    }
    _notice = b.summary();
    _commit(b.profile, b.stash);
    return null;
  }

  @override
  String? put(List<String> tokens, int tab) {
    final why = _batch(_stashRules.depositMany(_p!, _stash!, tokens, tab: tab));
    if (why == null) achievement('stash_store');
    return why;
  }

  /// Fuera de la sesión las hazañas del alijo se pagan en local, sobre la
  /// cuenta (achievements.md § 5.2), después de lo que ya se esté
  /// guardando.
  @override
  void achievement(String id) {
    final repo = ref.read(accountRepositoryProvider);
    final cur = repo.current;
    if (cur == null || cur.achievements.isDone(id)) return;
    var got = const <AchievementUnlock>[];
    repo.update((a) {
      final (next, u) = a.grantAchievements(widget.characterId, [id],
          repo.now().millisecondsSinceEpoch ~/ 1000);
      got = u;
      return next;
    }).then((a) {
      if (!mounted || got.isEmpty) return;
      final slot = a.byId(widget.characterId);
      setState(() {
        if (slot != null) _p = rules.normalize(slot.profile);
        final s = ref.read(stringsProvider);
        _notice = [
          for (final u in got)
            s.t('ui.characters.stash.achievement', {
              'name': kAchievementsById[u.id]?.name ?? u.id,
              'reward': u.reward.text,
            })
        ].join('  ');
      });
    }).catchError((Object _) {});
  }

  @override
  String? take(List<int> cells) =>
      _batch(_stashRules.withdrawMany(_p!, _stash!, cells));

  /// TOMAR de Objetos sin recoger al personaje (loot.md § 4b).
  void _takeUnclaimed(int i) {
    final m = _stashRules.claim(_p!, _stash!, i);
    if (!m.ok) {
      setState(() => _notice = m.error);
      return;
    }
    _notice = ref.read(stringsProvider).t('ui.characters.stash.taken');
    _commit(m.profile!, m.stash!);
  }

  void _discardUnclaimed(int i) {
    final next = StashRules.dropUnclaimed(_stash!, i);
    if (next == null) return;
    _notice = ref.read(stringsProvider).t('ui.characters.stash.discarded');
    _commit(_p!, next);
  }

  @override
  bool moveStash(int from, int to) {
    final next = StashRules.move(_stash!, from, to);
    if (next == null) return false;
    _commit(_p!, next);
    return true;
  }

  @override
  bool moveCharacter(int from, int to) {
    final next = InventoryRules.move(_p!, from, to);
    if (next == null) return false;
    _commit(next, _stash!);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final p = _p, s = _stash;
    final cls = p == null ? '' : rules.catalog.classes[p.classId]?.name ?? p.classId;
    final st = ref.strings;
    return Scaffold(
      body: PanelFrame(
        key: const ValueKey('stash-screen'),
        title: st.t('ui.characters.stash.screen_title'),
        width: 1000,
        onClose: () => Navigator.of(context).maybePop(),
        help: stashHelp(st),
        actions: [
          PanelButton(st.t('ui.characters.stash.back'),
              key: const ValueKey('stash-close'),
              onPressed: () => Navigator.of(context).maybePop()),
        ],
        child: p == null || s == null
            ? Text(st.t('ui.characters.stash.loading'), style: DsText.detail())
            : Column(mainAxisSize: MainAxisSize.min, children: [
                StashBoard(
                    host: this,
                    title: st.t('ui.characters.common.name_class_level',
                        {'name': p.name, 'cls': cls, 'level': p.level})),
                UnclaimedBox(
                  entries: s.unclaimed,
                  nameOf: (e) =>
                      stashEntryName(e, rules.items.displayName, strings: st),
                  busy: _saving,
                  onTake: _takeUnclaimed,
                  onDiscard: _discardUnclaimed,
                ),
              ]),
      ),
    );
  }
}

/// Ayuda ("?") del alijo, dentro y fuera de la sesión.
String stashHelp(Strings s) =>
    s.t('ui.characters.stash.help', {'max': Stash.maxMaterialStack});