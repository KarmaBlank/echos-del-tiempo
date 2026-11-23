import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../achievements/presentation/achievements_screen.dart';
import '../../bestiary/presentation/bestiary_screen.dart';
import '../../build_planner/presentation/build_planner_screen.dart';
import '../../../app/design/design.dart';
import '../../../app/design/gallery/ds_gallery_screen.dart';
import '../../../app/design/registry/ds_screen_view.dart';
import '../../../core/screen_layout/screen_bindings.dart';
import '../../../core/screen_layout/screen_layout_catalog.dart';
import '../../../app/feature_flags.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../app/widgets/section_panel.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../game_engine/models/item.dart';
import '../../inventory/presentation/skill_chip.dart';
import '../../../core/edition/game_edition.dart';
import '../../../game_engine/models/game_mode.dart';
import '../../../core/audio/music/music_catalog.dart';
import '../../../core/audio/presentation/audio_providers.dart';
import '../../../core/i18n/i18n_providers.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../core/update/presentation/update_banner.dart';
import '../../../game_engine/models/class_def.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/abyss_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../../netcode/contracts/net_session.dart';
import '../../../netcode/contracts/net_session_factory.dart';
import '../../characters/domain/account.dart';
import '../../characters/presentation/character_widgets.dart';
import '../../characters/presentation/characters_providers.dart';
import '../../characters/presentation/party_picker.dart';
import '../../characters/presentation/stash_screen.dart';
import '../../combat/presentation/game_sprites.dart';
import '../../combat/presentation/sprite_catalog.dart';
import '../../world/presentation/session_controller.dart';
import '../../settings/presentation/settings_menu.dart';
import '../../world/presentation/world_loading.dart';
import '../domain/patch_notes.dart';
import 'patch_notes_panel.dart';
import 'world_picker.dart';
import 'worlds_providers.dart';

/// Pantalla de título (prototipo, HTML líneas 70-83 y `title()` desde la
/// línea 1471) con la **selección de personaje** de la cuenta: lista de
/// personajes, crear (nombre + clase, el editor de antes), renombrar,
/// borrar con confirmación escrita y el alijo compartido; después, la
/// entrada al juego con el elegido, solo o en una sala de red (`CREAR
/// SALA` / código + `UNIRSE`). Ver docs/specs/characters.md § 2,
/// docs/specs/exploration.md § "Título" y docs/specs/netcode.md.
class TitleScreen extends ConsumerStatefulWidget {
  const TitleScreen({super.key, this.onStart});

  /// Qué hacer al comenzar, con el personaje ya guardado (por defecto,
  /// abrir `WorldScreen`).
  final VoidCallback? onStart;

  @override
  ConsumerState<TitleScreen> createState() => _TitleScreenState();
}

bool get _travesia => GameEdition.current.mode == GameModeKind.travesia;

class _TitleScreenState extends ConsumerState<TitleScreen> {
  /// Title shortcuts (the "?"). Travesía: no field or chat; character
  /// and inventory with C / I.
  String get _keysHelp => ref.t(
      _travesia ? 'ui.lobby.keys_help.travesia' : 'ui.lobby.keys_help.world');

  final _name = TextEditingController();
  final _code = TextEditingController();
  Account? _account;
  bool _busy = false;

  /// Paso del flujo y camino elegido (title_screen.md § 1.1).
  _Step _step = _Step.menu;
  _Path _path = _Path.solo;
  late final Future<void> _loading;
  StreamSubscription<Account>? _changes;

  /// Perfiles normalizados por `id` (con el crudo del que salieron, para
  /// no normalizar de nuevo si no cambió).
  final _normalized = <String, (PlayerProfile, PlayerProfile)>{};

  /// Creador abierto y clase elegida en él.
  bool _creating = false;
  String _newClass = SessionController.defaultClass;

  /// Aviso de la cuenta (archivo dañado) en rojo.
  String? _notice;

  /// El último guardado de la cuenta falló (se reintenta solo).
  String? _saveError;
  StreamSubscription<String?>? _saveStatus;

  /// Línea de estado (`setErr` del prototipo: red, errores de guardado) y
  /// si es un error.
  String? _netStatus;
  bool _netError = false;

  /// Versión de las notas del parche más nuevas empaquetadas (`null`:
  /// todavía no se leyó o no hay).
  String? _newestNotes;

  /// Doble clic en una tarjeta = jugar.
  DateTime? _lastTap;
  String? _lastTapId;

  Future<void> _loadNotesIndex() async {
    try {
      final list = await loadPatchNoteIndex(rootBundle);
      if (mounted && list.isNotEmpty) {
        setState(() => _newestNotes = list.first.version);
      }
    } catch (_) {
      // Sin índice: sin insignia.
    }
  }

  /// Insignia `NUEVO` del botón de notas (title_screen.md § 4.1).
  String? get _notesBadge {
    final newest = _newestNotes;
    if (newest == null) return null;
    final seen = ref.watch(gameSettingsProvider).seenPatchNotes;
    return hasUnseenPatchNotes([PatchNoteEntry(newest, '')], seen)
        ? ref.t('ui.lobby.badge_new')
        : null;
  }

  /// Abre las notas y las marca como vistas.
  void _openPatchNotes() {
    final newest = _newestNotes;
    if (newest != null) {
      final c = ref.read(gameSettingsProvider.notifier);
      final s = ref.read(gameSettingsProvider);
      if (s.seenPatchNotes != newest) {
        unawaited(c.update(s.copyWith(seenPatchNotes: newest)));
      }
    }
    unawaited(showPatchNotes(context));
  }

  ProgressionRules get _rules => ref.read(sessionEngineProvider).progression;

  @override
  void initState() {
    super.initState();
    _loading = _load();
    // Ajustes de audio (cargan del disco) y la música del título; en
    // segundo plano se preparan las piezas que suenan enseguida al jugar
    // (docs/specs/music.md § 6).
    ref.read(audioSettingsProvider);
    // Ajustes de pantalla y de juego (cargan de `game.json`; si quedó en
    // pantalla completa, la ventana vuelve a ella).
    ref.read(gameSettingsProvider);
    unawaited(_loadNotesIndex());
    final music = ref.read(musicServiceProvider)..playTrack(Music.title);
    unawaited(music.preload(const [
      Music.town,
      Music.overworld,
      Music.battle,
      Music.victory,
      Music.levelUp,
      Music.boss,
      Music.zone1,
    ]));
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    unawaited(_saveStatus?.cancel());
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(accountRepositoryProvider);
    // La sesión guarda el personaje elegido mientras se juega: la lista
    // se refresca sola (nivel, zona, fecha).
    _changes = repo.changes.listen((a) {
      if (mounted) setState(() => _setAccount(a));
    });
    // Un guardado que falla no pasa en silencio (characters.md § 1.4).
    _saveError = repo.saveError;
    _saveStatus = repo.saveStatus.listen((e) {
      if (mounted) setState(() => _saveError = e);
    });
    final a = await repo.load();
    if (!mounted) return;
    setState(() {
      _notice = repo.notice;
      _setAccount(a);
      if (a.characters.isEmpty) _openCreator();
    });
  }

  void _setAccount(Account a) {
    _account = a;
    _normalized.removeWhere((id, _) => a.byId(id) == null);
  }

  /// Perfil normalizado de [c] (nivel, zona y clase válidos).
  PlayerProfile _norm(CharacterSlot c) {
    final cached = _normalized[c.id];
    if (cached != null && identical(cached.$1, c.profile)) return cached.$2;
    final n = _rules.normalize(c.profile);
    _normalized[c.id] = (c.profile, n);
    return n;
  }

  String _className(String id) => _rules.catalog.classes[id]?.name ?? id;

  List<ClassDef> get _classes => _rules.catalog.classes.values
      .where((c) => FeatureFlags.instance.isCharacterAllowed(c.id))
      .toList();

  void _openCreator() {
    _creating = true;
    _name.clear();
    final allowed = _classes;
    if (allowed.isNotEmpty && !allowed.any((c) => c.id == _newClass)) {
      _newClass = allowed.first.id;
    }
  }

  /// Aplica un cambio a la cuenta; un error de disco queda en la línea de
  /// estado (la cuenta en memoria cambió igual).
  Future<Account?> _update(Account Function(Account) change) async {
    try {
      return await ref.read(accountRepositoryProvider).update(change);
    } catch (e) {
      if (mounted) {
        setState(() {
          _netStatus = ref.t('ui.lobby.status.save_failed', {'error': e});
          _netError = true;
        });
      }
      return ref.read(accountRepositoryProvider).current;
    }
  }

  // ------------------------------------------------------------------
  // Personajes
  // ------------------------------------------------------------------

  Future<void> _create() async {
    await _loading;
    final a = _account;
    if (a == null || _busy) return;
    if (a.isFull) {
      setState(() {
        _netStatus = ref.t(
            'ui.lobby.status.max_characters', {'max': Account.maxCharacters});
        _netError = true;
      });
      return;
    }
    final now = ref.read(accountRepositoryProvider).now();
    await _update((a) =>
        CharacterRules(_rules).create(a, _name.text, _newClass, now: now) ?? a);
    if (!mounted) return;
    setState(() {
      _creating = false;
      _netStatus = null;
    });
  }

  void _tapSlot(String id) {
    final now = DateTime.now();
    final dbl = _lastTapId == id &&
        _lastTap != null &&
        now.difference(_lastTap!) < const Duration(milliseconds: 400);
    _lastTap = dbl ? null : now;
    _lastTapId = dbl ? null : id;
    if (_account?.selectedId != id) unawaited(_update((a) => a.select(id)));
    if (dbl) unawaited(_play());
  }

  Future<void> _rename() async {
    final c = _account?.selected;
    if (c == null || _busy) return;
    final name = await showRenameDialog(context, c);
    if (name == null || !mounted) return;
    await _update((a) => CharacterRules(_rules).rename(a, c.id, name));
  }

  Future<void> _delete() async {
    final c = _account?.selected;
    if (c == null || _busy) return;
    final ok = await showDeleteDialog(context, c, _className(_norm(c).classId));
    if (!ok || !mounted) return;
    final a = await _update((a) => a.remove(c.id));
    if (!mounted) return;
    setState(() {
      _netStatus = ref.t('ui.lobby.status.deleted', {'name': c.displayName});
      _netError = false;
      if (a != null && a.characters.isEmpty) _openCreator();
    });
  }

  /// SALIR DEL JUEGO (v0.8.2): confirma y cierra con la salida segura
  /// (`appExitProvider`: guarda todo con `ExitGuard` y cierra la ventana).
  Future<void> _quitGame() async {
    final ok = await showQuitGameDialog(context);
    if (!ok || !mounted) return;
    await ref.read(appExitProvider)();
  }

  /// Plan de build del elegido (build_planner.md § 4).
  Future<void> _openBuild() async {
    final c = _account?.selected;
    if (c == null || _busy) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => BuildPlannerScreen(characterId: c.id)));
  }

  Future<void> _openBestiary() async {
    if (_busy) return;
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const BestiaryScreen()));
  }

  Future<void> _openAchievements() async {
    if (_busy) return;
    await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AchievementsScreen()));
  }

  Future<void> _openStash() async {
    final c = _account?.selected;
    if (c == null || _busy) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => StashScreen(characterId: c.id)));
  }

  // ------------------------------------------------------------------
  // Entrar al juego
  // ------------------------------------------------------------------

  /// Anota la partida en el elegido y lo pasa al `ProfileStore` de la
  /// sesión. `null` si la pantalla ya no está o no hay personaje.
  Future<PlayerProfile?> _prepare() async {
    // Se puede tocar antes de que termine de cargar la cuenta.
    await _loading;
    // Y antes de los mundos: la sesión lee el elegido al arrancar.
    if (!_travesia) await ref.read(worldBookProvider.notifier).loading;
    final c = _account?.selected;
    if (c == null || !mounted) return null;
    setState(() => _busy = true);
    final now = ref.read(accountRepositoryProvider).now();
    await _update((a) => a.touch(c.id, now));
    // Siempre el de la cuenta en memoria, nunca la copia de esta pantalla
    // (si hubiera quedado vieja, la sala — también como cliente — y el
    // guardado pisarían lo jugado). docs/specs/characters.md § 1.4.
    final slot = ref.read(accountRepositoryProvider).current?.byId(c.id) ?? c;
    try {
      // En la app es el mismo personaje de la cuenta (no cambia nada);
      // con otro `ProfileStore` (tests, flavors) la sesión lo recibe igual.
      await ref.read(profileStoreProvider).save(slot.profile);
    } catch (_) {
      // Sin disco se juega igual (el controlador vuelve a intentar).
    }
    // Jefes del Abismo vencidos por la cuenta: el personaje los lleva al
    // `hello` (el host valida el secreto con el perfil; abyss_bosses.md
    // § 1.3).
    final atlas = ref.read(accountRepositoryProvider).current?.atlas;
    return mounted
        ? (atlas == null
            ? _norm(slot)
            : AbyssRules.withAccount(_norm(slot), atlas))
        : null;
  }

  /// `> JUGAR`: un jugador, sin red.
  Future<void> _start() async {
    if (_busy) return;
    final p = await _prepare();
    if (p == null) return;
    setState(() => _busy = false);
    final onStart = widget.onStart;
    if (onStart != null) {
      onStart();
    } else {
      await _enter(null);
    }
  }

  /// `CREAR SALA` (`startHost`) o `UNIRSE` (`startJoin`).
  Future<void> _connect(NetSessionFactory factory, {String? code}) async {
    if (_busy) return;
    if (code != null && code.trim().length < 4) {
      setState(() {
        _netStatus = ref.t('ui.lobby.status.enter_code');
        _netError = true;
      });
      return;
    }
    final p = await _prepare();
    if (p == null) return;
    setState(() {
      _netStatus = code == null
          ? ref.t('ui.lobby.status.creating_room')
          : ref.t('ui.lobby.status.connecting', {'code': code.trim()});
      _netError = false;
    });
    final net = factory.create();
    try {
      var tutV = 0;
      try {
        tutV = await ref.read(tutorialStoreProvider).load();
      } catch (_) {}
      await net.connect(SessionConfig(
          profile: p, roomCode: code?.trim(), tutorialVersion: tutV));
    } on Object catch (e) {
      await net.disconnect();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _netStatus = e is NetException
            ? e.message
            : ref.t('ui.lobby.status.net_error', {'error': e});
        _netError = true;
      });
      return;
    }
    if (!mounted) {
      await net.disconnect();
      return;
    }
    setState(() {
      _busy = false;
      _netStatus = null;
    });
    await _enter(net);
  }

  /// Abre el juego con [net] (`null` = solo). Si vuelve por una
  /// desconexión, muestra el motivo.
  Future<void> _enter(NetSession? net) async {
    ref.read(activeNetSessionProvider.notifier).state = net;
    final reason = await Navigator.of(context).push(
      MaterialPageRoute<String>(builder: (_) => const WorldLoadingScreen()),
    );
    // El controlador la cierra al descartarse; por las dudas (idempotente).
    if (net != null) await net.disconnect();
    if (!mounted) return;
    ref.read(musicServiceProvider).playTrack(Music.title);
    ref.read(activeNetSessionProvider.notifier).state = null;
    // De vuelta de la partida: el menú principal (title_screen.md § 1.1).
    setState(() => _step = _Step.menu);
    if (reason != null) {
      setState(() {
        _netStatus = reason;
        _netError = true;
      });
    }
  }

  // ------------------------------------------------------------------
  // Flujo de JUGAR (title_screen.md § 1.1)
  // ------------------------------------------------------------------

  void _go(_Step s) => setState(() {
        _step = s;
        _netStatus = null;
        _netError = false;
      });

  /// El paso después de elegir el camino [p].
  void _choose(_Path p) {
    _path = p;
    _go(p == _Path.join
        ? _Step.join
        : (_travesia ? _Step.characters : _Step.worlds));
  }

  /// VOLVER (o Esc): el paso anterior; en el creador, cierra el creador.
  void _back() {
    if (_busy) return;
    switch (_step) {
      case _Step.menu:
        return;
      case _Step.mode:
        _go(_Step.menu);
      case _Step.coop:
        _go(_Step.mode);
      case _Step.join:
        _go(_Step.coop);
      case _Step.worlds:
        _go(_path == _Path.solo ? _Step.mode : _Step.coop);
      case _Step.characters:
        final a = _account;
        if (_creating && a != null && a.characters.isNotEmpty) {
          setState(() => _creating = false);
          return;
        }
        _go(switch (_path) {
          _Path.join => _Step.join,
          _ when !_travesia => _Step.worlds,
          _Path.solo => _Step.mode,
          _Path.host => _Step.coop,
        });
    }
  }

  void _joinNext() {
    if (_code.text.trim().length < 4) {
      setState(() {
        _netStatus = ref.t('ui.lobby.status.enter_code');
        _netError = true;
      });
      return;
    }
    _go(_Step.characters);
  }

  /// La acción principal del paso Personaje según el camino.
  Future<void> _play() async {
    final factory = ref.read(netSessionFactoryProvider);
    switch (_path) {
      case _Path.solo:
        await _start();
      case _Path.host:
        if (factory != null && factory.available) await _connect(factory);
      case _Path.join:
        if (factory != null && factory.available) {
          await _connect(factory, code: _code.text);
        }
    }
  }

  // ------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------

  /// Carrusel de personajes + acciones del elegido.
  Widget _selector(Account a, GameSprites? sprites) {
    final sel = a.selected;
    final has = sel != null && !_busy;
    final chars = a.characters;
    final index = chars.indexWhere((c) => c.id == a.selectedId);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
            ref.t('ui.lobby.characters.header',
                {'count': chars.length, 'max': Account.maxCharacters}),
            textAlign: TextAlign.center,
            style: DsText.subtitle()),
        SizedBox(height: DsSpace.md),
        DsCarousel(
          itemCount: chars.length + (a.isFull ? 0 : 1),
          selectableCount: chars.length,
          index: index < 0 ? 0 : index,
          itemExtent: CharacterSlotCard.widthOf(context),
          onChanged: _busy
              ? null
              : (i) => unawaited(_update((a) => a.select(chars[i].id))),
          itemBuilder: (context, i) => i < chars.length
              ? CharacterSlotCard(
                  slot: chars[i],
                  profile: _norm(chars[i]),
                  className: _className(_norm(chars[i]).classId),
                  selected: chars[i].id == a.selectedId,
                  sprites: sprites,
                  onTap: () => _tapSlot(chars[i].id),
                  // Enter: elige; sobre la ya elegida, sigue.
                  onKeyActivate: () => chars[i].id == a.selectedId
                      ? unawaited(_play())
                      : _tapSlot(chars[i].id),
                )
              : NewCharacterCard(onTap: () => setState(_openCreator)),
        ),
        SizedBox(height: DsSpace.lg),
        Wrap(
          spacing: DsSpace.sm,
          runSpacing: DsSpace.sm,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DsButton(ref.t('ui.lobby.characters.new'),
                key: const ValueKey('char-create'),
                tooltip: a.isFull
                    ? ref.t('ui.lobby.characters.max_tooltip',
                        {'max': Account.maxCharacters})
                    : null,
                onPressed:
                    _busy || a.isFull ? null : () => setState(_openCreator)),
            DsButton(ref.t('ui.lobby.characters.rename'),
                key: const ValueKey('char-rename'),
                onPressed: has ? _rename : null),
            DsButton(ref.t('ui.lobby.characters.delete'),
                key: const ValueKey('char-delete'),
                accent: DsColors.danger,
                onPressed: has ? _delete : null),
            // Travesía (roguelike.md § 12.2): sin alijo, plan de build,
            // bestiario ni hazañas (son del Mundo).
            if (!_travesia) ...[
              DsButton(ref.t('ui.lobby.characters.stash'),
                  key: const ValueKey('char-stash'),
                  onPressed: has ? _openStash : null),
              DsButton(ref.t('ui.lobby.characters.build'),
                  key: const ValueKey('char-build'),
                  onPressed: has ? _openBuild : null),
              // Bestiario de la cuenta, solo lectura (bestiary.md § 4).
              DsButton(ref.t('ui.lobby.characters.bestiary'),
                  key: const ValueKey('title-bestiary'),
                  onPressed: _busy ? null : _openBestiary),
              // Hazañas de la cuenta, solo lectura (achievements.md § 7).
              DsButton(ref.t('ui.lobby.characters.achievements'),
                  key: const ValueKey('title-achievements'),
                  onPressed: _busy ? null : _openAchievements),
            ],
            // Galería del sistema de diseño, solo en la versión de
            // desarrollo (design_system.md § 8).
            if (FeatureFlags.instance.devTools)
              DsButton(ref.t('ui.lobby.characters.gallery'),
                  key: const ValueKey('title-gallery'),
                  kind: DsButtonKind.ghost,
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const DsGalleryScreen()))),
            // Recarga en caliente del arte de prueba del Editor
            // (game_editor.md § 3.1): relee overrides/ y los sprites.
            if (FeatureFlags.instance.useLocalOverrides)
              DsButton(ref.t('ui.lobby.characters.reload_art'),
                  key: const ValueKey('title-reload-art'),
                  kind: DsButtonKind.ghost,
                  onPressed: _busy
                      ? null
                      : () async {
                          await SpriteCatalog.defaultOverrides?.refresh();
                          ref.invalidate(gameSpritesProvider);
                        }),
          ],
        ),
        // Party solo jugando solo y si este build la ofrece
        // (FeatureFlags.soloParty).
        if (sel != null &&
            _path == _Path.solo &&
            FeatureFlags.instance.soloParty) ...[
          SizedBox(height: DsSpace.md),
          _party(a, sel),
        ],
      ],
    );
  }

  /// Party jugando solo (docs/specs/solo_party.md § 2.2): los demás
  /// personajes de la cuenta; se guarda en la cuenta al tocar.
  Widget _party(Account a, CharacterSlot leader) {
    final party = a.companions;
    return PartyPicker(
      candidates: [
        for (final c in a.characters)
          if (c.id != leader.id)
            PartyCandidate(
              id: c.id,
              name: c.displayName,
              className: _className(_norm(c).classId),
              level: _norm(c).level,
            ),
      ],
      selected: party,
      enabled: !_busy,
      onChanged: (ids) => unawaited(_update((a) => a.withParty(ids))),
    );
  }

  /// Creador: tarjetas de clase (flechas / `1`..`9` eligen) │ detalle de
  /// la elegida con el arma inicial y sus habilidades, el nombre y CREAR.
  Widget _creator(Account? a, GameSprites? sprites) {
    final first = a == null || a.characters.isEmpty;
    final classes = _classes;
    final sel = classes.where((c) => c.id == _newClass).firstOrNull ??
        classes.firstOrNull;
    final weapon =
        sel == null ? null : _rules.catalog.weapons[sel.startWeaponId];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
            ref.t(first
                ? 'ui.lobby.creator.title_first'
                : 'ui.lobby.creator.title'),
            key: const ValueKey('char-creator'),
            textAlign: TextAlign.center,
            style: DsText.subtitle()),
        SizedBox(height: DsSpace.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: SectionPanel(
                icon: PixelIconKind.sword,
                title: ref.t('ui.lobby.creator.class_title'),
                subtitle: ref.t('ui.lobby.creator.class_subtitle'),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < classes.length; i++)
                        ClassCard(
                          def: classes[i],
                          index: i < 9 ? i + 1 : null,
                          weaponName: _rules.catalog
                                  .weapons[classes[i].startWeaponId]?.name ??
                              '',
                          selected: sel?.id == classes[i].id,
                          sprites: sprites,
                          onTap: () =>
                              setState(() => _newClass = classes[i].id),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (sel != null)
                    SectionPanel(
                      icon: PixelIconKind.star,
                      title: ref.t('ui.lobby.creator.detail'),
                      children: [
                        ClassDetail(
                          def: sel,
                          weaponName: weapon?.name ?? '',
                          skills: weapon == null
                              ? null
                              : SkillChips(
                                  rules: _rules,
                                  item: ItemInstance.common('_new', weapon.id,
                                      itemLevel: weapon.level)),
                        ),
                      ],
                    ),
                  SectionPanel(
                    icon: PixelIconKind.check,
                    title: ref.t('ui.lobby.creator.name_title'),
                    children: [
                      RetroTextField(
                        key: const ValueKey('title-name'),
                        controller: _name,
                        maxLength: ProgressionRules.maxNameLength,
                        hint: Account.defaultName,
                        onSubmitted: (_) => _create(),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (!first)
                            DsButton(ref.t('ui.lobby.creator.cancel'),
                                key: const ValueKey('char-create-cancel'),
                                onPressed: () =>
                                    setState(() => _creating = false)),
                          DsButton(ref.t('ui.lobby.creator.create'),
                              key: const ValueKey('char-create-confirm'),
                              kind: DsButtonKind.primary,
                              onPressed: _busy ? null : _create),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// `1`..`9` en el paso Personaje: en el creador, la clase N; si no, el
  /// personaje N.
  bool _digit(int n) {
    final a = _account;
    if (a == null || _step != _Step.characters) return false;
    if (_creating || a.characters.isEmpty) {
      final cs = _classes;
      if (n > cs.length) return false;
      setState(() => _newClass = cs[n - 1].id);
      return true;
    }
    if (n > a.characters.length) return false;
    _tapSlot(a.characters[n - 1].id);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Teclado (menu_focus.dart): flechas / Tab / Enter, Esc vuelve un
    // paso y 1-9 eligen personaje o clase.
    return Scaffold(
      body: MenuKeyScope(
        onBack: _step == _Step.menu ? null : _back,
        onDigit: _digit,
        child: DefaultTextStyle.merge(
          style: text.bodySmall,
          child: KeyedSubtree(
            key: ValueKey('title-step-${_step.name}'),
            child: _step == _Step.menu ? _menu() : _stepView(),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Menú principal
  // ------------------------------------------------------------------

  void _openModes() => _go(_Step.mode);

  /// Menú principal: el layout de datos (Editor → PANTALLAS,
  /// screen_editor.md § 3) o, sin archivo, el armado en código.
  Widget _menu() {
    final layout = ScreenLayoutCatalog.instance.get('title');
    if (layout == null) return _codeMenu();
    return DsScreenView(
      key: const ValueKey('title-screen-layout'),
      layout: layout,
      spec: titleBindings,
      bindings: _bindings(),
    );
  }

  /// Lo que el layout de datos puede usar del título, por nombre.
  ScreenRuntimeBindings _bindings() {
    final a = _account;
    final has = a?.selected != null && !_busy;
    final notice = _noticeText(), status = _netStatusText();
    final strings = ref.watch(stringsProvider);
    return ScreenRuntimeBindings(
      // es-AR: el texto del layout (lo edita el Editor); otro idioma, el
      // de la clave del elemento (docs/specs/i18n.md § 3).
      translate: strings.isSource ? null : strings.lookup,
      actions: {
        'nuevaPartida': ScreenAction(_busy ? null : _openModes),
        'crearPersonaje': ScreenAction(_busy || a == null || a.isFull
            ? null
            : () {
                _path = _Path.solo;
                _openCreator();
                _go(_Step.characters);
              }),
        'configuracion': ScreenAction(() => showSettingsDialog(context)),
        'salirDelJuego': ScreenAction(_quitGame),
        'ayudaTeclas': ScreenAction(() {}, tooltip: _keysHelp),
        'abrirAlijo': ScreenAction(has && !_travesia ? _openStash : null),
        'abrirBestiario':
            ScreenAction(_busy || _travesia ? null : _openBestiary),
        'abrirHazanas':
            ScreenAction(_busy || _travesia ? null : _openAchievements),
        'verNotasParche': ScreenAction(_openPatchNotes, badge: _notesBadge),
      },
      data: {
        'personajes': [
          for (final c in a?.characters ?? const <CharacterSlot>[])
            ScreenDataEntry(c.displayName, _className(_norm(c).classId)),
        ],
      },
      slots: {
        if (notice != null) 'avisos': SingleChildScrollView(child: notice),
        // Versión + BUSCAR o ACTUALIZAR, chico en la esquina
        // (title_screen.md § 1).
        'version': const Align(
          alignment: Alignment.bottomLeft,
          child: SingleChildScrollView(child: UpdateBanner(compact: true)),
        ),
        if (status != null)
          'estadoRed': Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(child: status)),
      },
    );
  }

  Widget? _noticeText() {
    final n = [_notice, _saveError].nonNulls.join('\n');
    if (n.isEmpty) return null;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Text(retroText(n),
          key: const ValueKey('title-account-notice'),
          textAlign: TextAlign.center,
          style: DsText.body(DsColors.danger)),
    );
  }

  Widget? _netStatusText() {
    final status = _netStatus;
    if (status == null) return null;
    return Text(retroText(status),
        key: const ValueKey('title-net-status'),
        textAlign: TextAlign.end,
        style: DsText.detail(
            _netError ? DsColors.danger : DsColors.textSecondary));
  }

  /// El menú principal armado en código (fallback sin layout de datos):
  /// la misma disposición que el layout por defecto.
  Widget _codeMenu() {
    final notice = _noticeText(), status = _netStatusText();
    final gap = DsSpace.lg;
    Widget item(Widget b) => Padding(
          padding: EdgeInsets.only(bottom: DsSpace.sm + DsSpace.xs),
          child: SizedBox(width: RetroType.width(context, 288), child: b),
        );
    return Padding(
      padding: EdgeInsets.all(gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notice != null) Center(child: notice),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(ref.t('ui.lobby.game_title'),
                        textAlign: TextAlign.center, style: DsText.display()),
                    SizedBox(height: DsSpace.xl * 2),
                    // JUGAR es la acción principal (borde y texto dorados).
                    item(DsButton(ref.t('ui.title.play'),
                        key: const ValueKey('title-start'),
                        kind: DsButtonKind.primary,
                        autofocus: true,
                        onPressed: _busy ? null : _openModes)),
                    item(DsButton(ref.t('ui.title.patch_notes'),
                        key: const ValueKey('title-patch-notes'),
                        trailing: _notesBadge == null
                            ? null
                            : DsBadge(_notesBadge!,
                                key: const ValueKey('title-patch-notes-badge')),
                        onPressed: _openPatchNotes)),
                    item(DsButton(ref.t('ui.title.options'),
                        key: const ValueKey('title-settings'),
                        onPressed: () => showSettingsDialog(context))),
                    // Salida segura (v0.8.2): confirma y guarda todo
                    // (ExitGuard) antes de cerrar, como la pausa.
                    item(DsButton(ref.t('ui.title.quit'),
                        key: const ValueKey('title-quit'),
                        accent: DsColors.danger,
                        onPressed: _quitGame)),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: DsSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Versión y actualización (docs/specs/distribution.md).
              const Flexible(
                  child: Align(
                      alignment: Alignment.bottomLeft,
                      child: UpdateBanner(compact: true))),
              SizedBox(width: gap),
              Expanded(
                child: Align(
                    alignment: Alignment.bottomRight,
                    child: status ?? const SizedBox.shrink()),
              ),
              SizedBox(width: DsSpace.sm),
              // Atajos de teclado al "?" (design_system.md § 2,
              // principio 0: nada de textos de ayuda fijos).
              DsButton.icon(const Text('?'),
                  key: const ValueKey('title-help'),
                  tooltip: _keysHelp,
                  onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Pasos
  // ------------------------------------------------------------------

  /// Un paso del flujo: título arriba, contenido centrado (se desplaza si
  /// no entra), VOLVER abajo a la izquierda y la acción para seguir abajo
  /// a la derecha.
  Widget _frame({required String title, required Widget body, Widget? action}) {
    final notice = _noticeText(), status = _netStatusText();
    final gap = DsSpace.lg;
    return Padding(
      padding: EdgeInsets.all(gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              key: const ValueKey('title-step-title'),
              textAlign: TextAlign.center,
              style: DsText.title()),
          if (notice != null) ...[
            SizedBox(height: DsSpace.sm),
            Center(child: notice),
          ],
          SizedBox(height: DsSpace.lg),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: RetroType.width(context, 1232)),
                  child: body,
                ),
              ),
            ),
          ),
          SizedBox(height: DsSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              DsButton(ref.t('ui.title.back'),
                  key: const ValueKey('title-back'),
                  onPressed: _busy ? null : _back),
              SizedBox(width: gap),
              Expanded(
                child: Align(
                    alignment: Alignment.bottomRight,
                    child: status ?? const SizedBox.shrink()),
              ),
              if (action != null) ...[SizedBox(width: gap), action],
            ],
          ),
        ],
      ),
    );
  }

  /// Opción grande de un paso (nombre + qué hace).
  Widget _option(String key, String label, String detail, VoidCallback? on,
          {bool autofocus = false}) =>
      Padding(
        padding: EdgeInsets.only(bottom: DsSpace.md),
        child: SizedBox(
          width: RetroType.width(context, 420),
          child: DsButton(label,
              key: ValueKey(key),
              details: [detail],
              autofocus: autofocus,
              onPressed: _busy ? null : on),
        ),
      );

  Widget _stepView() {
    final factory = ref.watch(netSessionFactoryProvider);
    final netOk = factory != null && factory.available && !_busy;
    switch (_step) {
      case _Step.menu:
        return _menu();
      case _Step.mode:
        return _frame(
          title: ref.t('ui.title.step.mode'),
          body: Column(mainAxisSize: MainAxisSize.min, children: [
            _option('title-solo', ref.t('ui.title.solo.label'),
                ref.t('ui.title.solo.detail'), () => _choose(_Path.solo),
                autofocus: true),
            _option('title-coop', ref.t('ui.title.coop.label'),
                ref.t('ui.title.coop.detail'), () => _go(_Step.coop)),
          ]),
        );
      case _Step.coop:
        return _frame(
          title: ref.t('ui.title.step.coop'),
          body: Column(mainAxisSize: MainAxisSize.min, children: [
            _option(
                'title-host',
                ref.t('ui.title.host.label'),
                ref.t('ui.title.host.detail'),
                netOk ? () => _choose(_Path.host) : null,
                autofocus: true),
            _option(
                'title-join-step',
                ref.t('ui.title.join.label'),
                ref.t('ui.title.join.detail'),
                netOk ? () => _choose(_Path.join) : null),
            Text(
                retroText(factory == null
                    ? ref.t('ui.lobby.net.p2p_soon')
                    : factory.unavailableReason ??
                        ref.t('ui.lobby.net.label', {'label': factory.label})),
                key: const ValueKey('title-p2p'),
                textAlign: TextAlign.center,
                style: DsText.detail()),
          ]),
        );
      case _Step.join:
        return _frame(
          title: ref.t('ui.title.step.join'),
          body: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(ref.t('ui.title.room_code'), style: DsText.detail()),
            SizedBox(height: DsSpace.sm),
            SizedBox(
              // Crece con el texto (el hint nunca se corta).
              width: RetroType.em(context, 12) + 2 * DsSpace.sm,
              child: TextField(
                key: const ValueKey('title-code'),
                controller: _code,
                autofocus: true,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: RetroType.titleFamily,
                    fontSize: RetroType.label,
                    color: DsColors.textPrimary),
                cursorColor: DsColors.focus,
                onSubmitted: (_) => _joinNext(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText:
                      factory?.codeHint ?? ref.t('ui.lobby.net.code_hint'),
                  hintStyle: TextStyle(
                      fontFamily: RetroType.titleFamily,
                      fontSize: RetroType.label,
                      color: DsColors.textSecondary),
                  contentPadding: EdgeInsets.all(DsSpace.sm),
                ),
              ),
            ),
          ]),
          action: DsButton(ref.t('ui.title.continue'),
              key: const ValueKey('title-join-next'),
              kind: DsButtonKind.primary,
              onPressed: _busy ? null : _joinNext),
        );
      case _Step.worlds:
        final book = ref.watch(worldBookProvider);
        return _frame(
          title: ref.t('ui.title.step.world'),
          body: WorldPicker(busy: _busy),
          action: DsButton(ref.t('ui.title.continue'),
              key: const ValueKey('title-worlds-next'),
              kind: DsButtonKind.primary,
              onPressed: _busy || book?.selected == null
                  ? null
                  : () => _go(_Step.characters)),
        );
      case _Step.characters:
        final a = _account;
        final sprites = ref.watch(gameSpritesProvider).valueOrNull;
        final creating = _creating || (a != null && a.characters.isEmpty);
        final canPlay =
            a?.selected != null && !_busy && (_path == _Path.solo || netOk);
        return _frame(
          title: ref.t('ui.title.step.character'),
          body: a == null
              ? Text(ref.t('ui.title.loading'), style: DsText.detail())
              : creating
                  ? _creator(a, sprites)
                  : _selector(a, sprites),
          action: creating
              ? null
              : DsButton(
                  switch (_path) {
                    _Path.solo => ref.t('ui.title.start_play'),
                    _Path.host => ref.t('ui.title.start_host'),
                    _Path.join => ref.t('ui.title.start_join'),
                  },
                  key: const ValueKey('char-play'),
                  kind: DsButtonKind.primary,
                  onPressed: canPlay ? _play : null),
        );
    }
  }
}

/// Pasos del título (title_screen.md § 1.1).
enum _Step { menu, mode, coop, join, worlds, characters }

/// Camino elegido en el flujo de JUGAR.
enum _Path { solo, host, join }
