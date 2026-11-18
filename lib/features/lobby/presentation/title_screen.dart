import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../build_planner/presentation/build_planner_screen.dart';
import '../../../app/feature_flags.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../app/widgets/menu_widgets.dart';
import '../../../app/widgets/section_panel.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../game_engine/models/item.dart';
import '../../inventory/presentation/skill_chip.dart';
import '../../../core/audio/music/music_catalog.dart';
import '../../../core/audio/presentation/audio_providers.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../core/update/presentation/update_banner.dart';
import '../../../game_engine/models/class_def.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../../netcode/contracts/net_session.dart';
import '../../../netcode/contracts/net_session_factory.dart';
import '../../characters/domain/account.dart';
import '../../characters/presentation/character_widgets.dart';
import '../../characters/presentation/characters_providers.dart';
import '../../characters/presentation/stash_screen.dart';
import '../../combat/presentation/game_sprites.dart';
import '../../world/presentation/session_controller.dart';
import '../../settings/presentation/settings_menu.dart';
import '../../world/presentation/world_screen.dart';

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

class _TitleScreenState extends ConsumerState<TitleScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  Account? _account;
  bool _busy = false;
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

  /// Doble clic en una tarjeta = jugar.
  DateTime? _lastTap;
  String? _lastTapId;

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
          _netStatus = 'No se pudo guardar la cuenta: $e';
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
        _netStatus = 'Máximo ${Account.maxCharacters} personajes.';
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
    if (dbl) unawaited(_start());
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
      _netStatus = '${c.displayName} fue borrado.';
      _netError = false;
      if (a != null && a.characters.isEmpty) _openCreator();
    });
  }

  /// Plan de build del elegido (build_planner.md § 4).
  Future<void> _openBuild() async {
    final c = _account?.selected;
    if (c == null || _busy) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => BuildPlannerScreen(characterId: c.id)));
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
    return mounted ? _norm(slot) : null;
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
        _netStatus = 'Escribe el código de la sala.';
        _netError = true;
      });
      return;
    }
    final p = await _prepare();
    if (p == null) return;
    setState(() {
      _netStatus =
          code == null ? 'Creando sala...' : 'Conectando a ${code.trim()}...';
      _netError = false;
    });
    final net = factory.create();
    try {
      await net.connect(SessionConfig(profile: p, roomCode: code?.trim()));
    } on Object catch (e) {
      await net.disconnect();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _netStatus = e is NetException ? e.message : 'Error de red: $e';
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
      MaterialPageRoute<String>(builder: (_) => const WorldScreen()),
    );
    // El controlador la cierra al descartarse; por las dudas (idempotente).
    if (net != null) await net.disconnect();
    if (!mounted) return;
    ref.read(musicServiceProvider).playTrack(Music.title);
    ref.read(activeNetSessionProvider.notifier).state = null;
    if (reason != null) {
      setState(() {
        _netStatus = reason;
        _netError = true;
      });
    }
  }

  // ------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------

  Widget _selector(Account a, GameSprites? sprites) {
    final sel = a.selected;
    final has = sel != null && !_busy;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('PERSONAJES (${a.characters.length}/${Account.maxCharacters})',
            style: const TextStyle(color: RetroPalette.muted)),
        const SizedBox(height: 12),
        SizedBox(
          width: 4 * CharacterSlotCard.widthOf(context) + 3 * 12,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              for (final c in a.characters)
                CharacterSlotCard(
                  slot: c,
                  profile: _norm(c),
                  className: _className(_norm(c).classId),
                  selected: c.id == a.selectedId,
                  sprites: sprites,
                  onTap: () => _tapSlot(c.id),
                  // Enter: elige; sobre la ya elegida, juega.
                  onKeyActivate: () => c.id == a.selectedId
                      ? unawaited(_start())
                      : _tapSlot(c.id),
                ),
              if (!a.isFull)
                NewCharacterCard(onTap: () => setState(_openCreator)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ElevatedButton(
              key: const ValueKey('title-start'),
              onPressed: has ? _start : null,
              child: const Text('> JUGAR'),
            ),
            PanelButton('CREAR PERSONAJE',
                key: const ValueKey('char-create'),
                reason: a.isFull
                    ? 'Máximo ${Account.maxCharacters} personajes'
                    : null,
                onPressed: _busy ? null : () => setState(_openCreator)),
            PanelButton('RENOMBRAR',
                key: const ValueKey('char-rename'),
                onPressed: has ? _rename : null),
            PanelButton('BORRAR',
                key: const ValueKey('char-delete'),
                onPressed: has ? _delete : null),
            PanelButton('ALIJO',
                key: const ValueKey('char-stash'),
                onPressed: has ? _openStash : null),
            PanelButton('BUILD',
                key: const ValueKey('char-build'),
                onPressed: has ? _openBuild : null),
          ],
        ),
      ],
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
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: RetroType.width(context, 1100)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(first ? 'CREA TU PRIMER PERSONAJE' : 'CREAR PERSONAJE',
              key: const ValueKey('char-creator'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: RetroType.pixelFamily,
                  fontSize: RetroType.title,
                  color: RetroPalette.gold)),
          const SizedBox(height: 4),
          Text(
              retroText(
                  'Elige la clase (flechas o 1-9), escribe el nombre y CREA.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: RetroPalette.muted)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: SectionPanel(
                  icon: PixelIconKind.sword,
                  title: '1 · CLASE',
                  subtitle: 'cualquier clase equipa cualquier arma',
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
                        title: 'DETALLE',
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
                      title: '2 · NOMBRE',
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
                            KeyHints(
                                confirm: 'Crear',
                                back: first ? null : 'Cancelar'),
                            if (!first)
                              PanelButton('CANCELAR',
                                  key: const ValueKey('char-create-cancel'),
                                  onPressed: () =>
                                      setState(() => _creating = false)),
                            ElevatedButton(
                              key: const ValueKey('char-create-confirm'),
                              onPressed: _busy ? null : _create,
                              child: const Text('> CREAR'),
                            ),
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
      ),
    );
  }

  /// `1`..`9`: en el creador, la clase N; en la selección, el personaje N.
  bool _digit(int n) {
    final a = _account;
    if (a == null) return false;
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

  Widget _netRow(NetSessionFactory? factory) {
    final netOk = factory != null &&
        factory.available &&
        !_busy &&
        _account?.selected != null;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        PanelButton('CREAR SALA',
            key: const ValueKey('title-host'),
            onPressed: netOk ? () => _connect(factory) : null),
        const Text('o', style: TextStyle(color: RetroPalette.muted)),
        SizedBox(
          width: 170,
          child: TextField(
            key: const ValueKey('title-code'),
            controller: _code,
            enabled: netOk,
            style: const TextStyle(
                fontFamily: RetroType.pixelFamily,
                fontSize: RetroType.label,
                color: RetroPalette.ink),
            cursorColor: RetroPalette.gold,
            onSubmitted: (_) {
              if (netOk) _connect(factory, code: _code.text);
            },
            decoration: InputDecoration(
              isDense: true,
              hintText: factory?.codeHint ?? 'CODIGO',
              hintStyle: const TextStyle(
                  fontFamily: RetroType.pixelFamily,
                  fontSize: RetroType.label,
                  color: RetroPalette.muted),
              contentPadding: const EdgeInsets.all(8),
            ),
          ),
        ),
        PanelButton('UNIRSE',
            key: const ValueKey('title-join'),
            onPressed:
                netOk ? () => _connect(factory, code: _code.text) : null),
        Text(
            retroText(factory == null
                ? 'P2P: próximamente'
                : factory.unavailableReason ?? 'Red: ${factory.label}'),
            key: const ValueKey('title-p2p'),
            style: const TextStyle(color: RetroPalette.muted)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final a = _account;
    final sprites = ref.watch(gameSpritesProvider).valueOrNull;
    final factory = ref.watch(netSessionFactoryProvider);
    final creating = _creating || (a != null && a.characters.isEmpty);
    // Teclado (menu_focus.dart): flechas / Tab / Enter, Esc cancela el
    // creador y 1-9 eligen personaje o clase.
    return Scaffold(
      body: MenuKeyScope(
        onBack: creating && a != null && a.characters.isNotEmpty
            ? () => setState(() => _creating = false)
            : null,
        onDigit: _digit,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: DefaultTextStyle.merge(
              style: text.bodySmall,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ECOS DEL TIEMPO',
                      textAlign: TextAlign.center,
                      style: text.displayLarge?.copyWith(
                        color: RetroPalette.gold,
                        shadows: const [
                          Shadow(color: RetroPalette.red, offset: Offset(4, 4)),
                        ],
                      )),
                  const SizedBox(height: 16),
                  Text(retroText('Co-op JRPG táctico · 1-4 jugadores'),
                      style: const TextStyle(color: RetroPalette.muted)),
                  const SizedBox(height: 12),
                  // Aviso de versión nueva (docs/specs/distribution.md).
                  const UpdateBanner(),
                  if ([_notice, _saveError].nonNulls.join('\n') case final n
                      when n.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Text(retroText(n),
                          key: const ValueKey('title-account-notice'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: RetroPalette.red)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (a == null)
                    const Text('Cargando...',
                        style: TextStyle(color: RetroPalette.muted))
                  else if (creating)
                    _creator(a, sprites)
                  else ...[
                    _selector(a, sprites),
                    const SizedBox(height: 16),
                    _netRow(factory),
                  ],
                  const SizedBox(height: 16),
                  PanelButton('CONFIGURACIÓN',
                      key: const ValueKey('title-settings'),
                      onPressed: () => showSettingsDialog(context)),
                  if (_netStatus case final status?) ...[
                    const SizedBox(height: 8),
                    Text(retroText(status),
                        key: const ValueKey('title-net-status'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: _netError
                                ? RetroPalette.red
                                : RetroPalette.muted)),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Mover: WASD/Flechas · Interactuar: E/Espacio · Combate por '
                    'turnos: 1-9 o clic · Cambiar objetivo: Q o clic en enemigo · '
                    'Chat: Enter',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: RetroPalette.muted),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Menús: flechas mueven · Enter elige (otra vez sobre tu '
                    'personaje: jugar) · 1-9 eligen · Esc vuelve',
                    key: ValueKey('title-menu-keys'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: RetroPalette.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
