import '../../../core/edition/game_edition.dart';
import '../../../game_engine/models/game_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../app/design/design.dart';
import '../../../app/theme/proto_colors.dart';

import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/theme/retro_hover_card.dart';
import '../../../app/theme/ui_theme.dart';
import '../../../app/theme/vision_palette.dart';
import '../../../app/widgets/menu_widgets.dart';
import '../../../app/widgets/notice_close.dart';
import '../../combat/presentation/battle_screen.dart' show BattleLogHistory;
import '../../world/presentation/map/map_labels.dart'
    show MapLabelSamplePainter;
import '../../../core/audio/presentation/audio_providers.dart';
import '../../../core/settings/game_settings.dart';
import '../../../app/feature_flags.dart';
import '../../../core/i18n/i18n_providers.dart';
import '../../../core/settings/settings_providers.dart';
import 'settings_strings.dart';

/// Pestañas del menú (docs/specs/settings.md § "Estructura").
/// Nombre y descripción, por idioma: `ui.settings.tab.<name>.label|hint`
/// (docs/specs/i18n.md).
enum SettingsTab {
  sound,
  display,
  accessibility,
  game,
  controls;

  String label(Strings s) => s.t('ui.settings.tab.$name.label');
  String hint(Strings s) => s.t('ui.settings.tab.$name.hint');
}

/// Qué salida se está confirmando.
enum _Exit { title, quit }

/// El menú de pausa / configuración: un solo lugar para el sonido, la
/// pantalla, el juego y los controles. En el juego ([inGame]) suma
/// CONTINUAR, SALIR AL TÍTULO y SALIR DEL JUEGO (las dos últimas con
/// confirmación); en el título es solo CONFIGURACIÓN. Ver
/// docs/specs/settings.md.
class SettingsMenu extends ConsumerStatefulWidget {
  const SettingsMenu({
    super.key,
    required this.onClose,
    this.inGame = false,
    this.multiplayer = false,
    this.groupPaused = false,
    this.onGroupPause,
    this.inMission = false,
    this.onExitToTitle,
    this.onQuitGame,
    this.initialTab = SettingsTab.sound,
  });

  /// CONTINUAR / CERRAR (y `Esc`).
  final VoidCallback onClose;

  /// Abierto desde el juego (menú de pausa): título PAUSA y salidas.
  final bool inGame;

  /// Hay una sala de red: el mundo sigue corriendo (salvo pausa de grupo).
  final bool multiplayer;

  /// La sala está pausada (pausa de grupo).
  final bool groupPaused;

  /// PAUSAR AL GRUPO / REANUDAR AL GRUPO (solo con red).
  final ValueChanged<bool>? onGroupPause;

  /// En una misión (la confirmación de salir lo avisa).
  final bool inMission;
  final VoidCallback? onExitToTitle;
  final VoidCallback? onQuitGame;
  final SettingsTab initialTab;

  @override
  ConsumerState<SettingsMenu> createState() => _SettingsMenuState();
}

class _SettingsMenuState extends ConsumerState<SettingsMenu> {
  late SettingsTab _tab = widget.initialTab;
  _Exit? _confirm;

  /// Un contexto dentro del marco: para tomar el foco del teclado al
  /// abrir (sobre el mapa la pantalla tiene el foco y el `autofocus` del
  /// marco no lo saca).
  BuildContext? _inside;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _inside;
      if (mounted && ctx != null && ctx.mounted) {
        FocusScope.of(ctx).requestFocus();
      }
    });
  }

  /// `Esc` primero cancela una confirmación abierta; si no, cierra.
  void _escape() {
    if (_confirm != null) {
      setState(() => _confirm = null);
    } else {
      widget.onClose();
    }
  }

  /// Qué tiene cada pestaña (antes, una línea fija debajo de las
  /// pestañas; ahora en el "?": design_system.md § 2, principio 0).
  String get _tabsHelp {
    final s = ref.read(stringsProvider);
    return [
      for (final t in SettingsTab.values)
        '<span class="k">${t.label(s)}</span>: ${t.hint(s)}'
    ].join('<br>');
  }

  String get _help {
    final s = ref.read(stringsProvider);
    return widget.inGame
        ? s.t('ui.settings.help.pause', {
            'multiplayer': widget.multiplayer ? 'yes' : 'no',
            'dot': kDot,
            'tabs': _tabsHelp,
          })
        : s.t('ui.settings.help.settings', {'dot': kDot, 'tabs': _tabsHelp});
  }

  @override
  Widget build(BuildContext context) {
    final confirm = _confirm;
    final s = ref.watch(stringsProvider);
    // Q / E, Ctrl+Tab y 1-9 cambian de pestaña (menu_focus.dart).
    return MenuTabKeys(
      count: SettingsTab.values.length,
      index: _tab.index,
      onChanged: (i) => setState(() => _tab = SettingsTab.values[i]),
      child: Material(
        type: MaterialType.transparency,
        child: PanelFrame(
          key: const ValueKey('settings-menu'),
          title: s.t(
              widget.inGame ? 'ui.settings.pause_title' : 'ui.settings.title'),
          width: 680,
          help: _help,
          onClose: _escape,
          titleTrailing: widget.inGame ? _status() : null,
          // Pestañas del sistema de diseño (DsTabBar); qué tiene cada
          // una, en el "?".
          header: DsTabBar(
            index: _tab.index,
            onChanged: (i) => setState(() => _tab = SettingsTab.values[i]),
            tabs: [
              for (final t in SettingsTab.values)
                DsTab(t.label(s), key: ValueKey('tab-${t.index}')),
            ],
          ),
          leading: [
            if (widget.inGame && confirm == null) ...[
              DsButton(s.t('ui.settings.exit_to_title'),
                  key: const ValueKey('pause-exit-title'),
                  onPressed: widget.onExitToTitle == null
                      ? null
                      : () => setState(() => _confirm = _Exit.title)),
              DsButton(s.t('ui.settings.quit_game'),
                  key: const ValueKey('pause-quit'),
                  onPressed: widget.onQuitGame == null
                      ? null
                      : () => setState(() => _confirm = _Exit.quit)),
            ],
          ],
          actions: confirm != null
              ? _confirmRow(confirm)
              : [
                  if (widget.inGame && widget.onGroupPause != null)
                    DsButton(
                        s.t(widget.groupPaused
                            ? 'ui.settings.group_resume'
                            : 'ui.settings.group_pause'),
                        key: const ValueKey('pause-group'),
                        selected: widget.groupPaused,
                        onPressed: () =>
                            widget.onGroupPause!(!widget.groupPaused)),
                  // CONTINUAR es la acción principal.
                  DsButton(
                      s.t(widget.inGame
                          ? 'ui.settings.resume'
                          : 'ui.settings.close'),
                      key: const ValueKey('settings-close'),
                      kind: DsButtonKind.primary,
                      onPressed: widget.onClose),
                ],
          child: Builder(builder: (ctx) {
            _inside = ctx;
            return switch (_tab) {
              SettingsTab.sound => const _SoundTab(),
              SettingsTab.display => const _DisplayTab(),
              SettingsTab.accessibility => const _AccessibilityTab(),
              SettingsTab.game => const _GameTab(),
              SettingsTab.controls => const _ControlsTab(),
            };
          }),
        ),
      ),
    );
  }

  /// `El juego sigue corriendo` (multijugador sin pausa de grupo) o
  /// `Juego en pausa` / `Grupo en pausa`.
  Widget _status() {
    final running = widget.multiplayer && !widget.groupPaused;
    return Text(
      retroText(ref.t(running
          ? 'ui.settings.status.running'
          : widget.multiplayer
              ? 'ui.settings.status.group_paused'
              : 'ui.settings.status.paused')),
      key: const ValueKey('pause-status'),
      maxLines: 1,
      style: DsText.detail(running ? DsColors.warning : DsColors.success),
    );
  }

  List<Widget> _confirmRow(_Exit what) {
    final quit = what == _Exit.quit;
    final consequence = ref.t(widget.multiplayer
        ? 'ui.settings.confirm.leave_room'
        : widget.inMission
            ? 'ui.settings.confirm.abandon_mission'
            : 'ui.settings.confirm.character_saved');
    return [
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: ProtoText(
          key: const ValueKey('pause-confirm-question'),
          '<b>${ref.t(quit ? 'ui.settings.confirm.quit_question' : 'ui.settings.confirm.title_question')}</b> '
          '${protoColor(ProtoColors.orange, consequence)}',
        ),
      ),
      DsButton(ref.t('ui.settings.cancel'),
          key: const ValueKey('pause-confirm-cancel'),
          onPressed: () => setState(() => _confirm = null)),
      DsButton(
          ref.t(quit ? 'ui.settings.quit_game' : 'ui.settings.exit_to_title'),
          key: const ValueKey('pause-confirm-yes'),
          accent: DsColors.danger, onPressed: () {
        setState(() => _confirm = null);
        (quit ? widget.onQuitGame : widget.onExitToTitle)?.call();
      }),
    ];
  }
}

/// Abre la CONFIGURACIÓN (sin salidas) encima de la pantalla actual: la
/// del título.
Future<void> showSettingsDialog(BuildContext context) => showDialog<void>(
      context: context,
      barrierColor: ProtoColors.scrim(0.6),
      builder: (ctx) =>
          SettingsMenu(onClose: () => Navigator.of(ctx).maybePop()),
    );

/// Confirmación de SALIR DEL JUEGO desde el título (v0.8.2): `true` si
/// se confirma. `Esc` / CANCELAR / clic afuera = no. El foco arranca en
/// CANCELAR (Enter no cierra el juego por accidente).
Future<bool> showQuitGameDialog(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      barrierColor: ProtoColors.scrim(0.6),
      builder: (ctx) {
        final s = settingsStrings(ctx);
        return Material(
          type: MaterialType.transparency,
          child: PanelFrame(
            key: const ValueKey('quit-dialog'),
            title: s.t('ui.settings.quit_game'),
            width: 460,
            onClose: () => Navigator.of(ctx).pop(false),
            actions: [
              InitialFocus(
                child: DsButton(s.t('ui.settings.cancel'),
                    key: const ValueKey('quit-cancel'),
                    onPressed: () => Navigator.of(ctx).pop(false)),
              ),
              DsButton(s.t('ui.settings.quit_game'),
                  key: const ValueKey('quit-yes'),
                  accent: DsColors.danger,
                  onPressed: () => Navigator.of(ctx).pop(true)),
            ],
            child: ProtoText(
              key: const ValueKey('quit-question'),
              '<b>${s.t('ui.settings.confirm.quit_question')}</b> '
              '${protoColor(ProtoColors.green, s.t('ui.settings.confirm.account_saved'))}',
            ),
          ),
        );
      },
    ) ??
    false;

/// Botón `≡ MENÚ [ESC]` (HUD del mapa y batalla) que abre la pausa.
class PauseMenuButton extends StatelessWidget {
  const PauseMenuButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      DsButton(settingsStrings(context).t('ui.settings.menu_button'),
          key: const ValueKey('pause-open'),
          size: DsButtonSize.compact,
          leading: const _MenuGlyph(),
          onPressed: onPressed);
}

/// `≡` dibujado (la fuente pixel no lo tiene): tres barras de 2 px.
class _MenuGlyph extends StatelessWidget {
  const _MenuGlyph();

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color ?? ProtoColors.ink;
    Widget bar() => Container(width: 8, height: 2, color: color);
    return SizedBox(
      height: 8,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [bar(), bar(), bar()],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Filas
// ---------------------------------------------------------------------

/// Una fila de ajuste en una línea (design_system.md § 10.3): nombre a
/// la izquierda y su control a la derecha. Qué hace va al tooltip del
/// nombre, marcado con "?" (nada de textos de ayuda fijos).
class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.control, this.hint});

  final String label;
  final Widget control;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final name = Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
          child:
              Text(retroText(label), style: DsText.body(DsColors.textPrimary))),
      if (hint != null) ...[
        SizedBox(width: DsSpace.xs),
        Text('?', style: DsText.detail(DsColors.textSecondary)),
      ],
    ]);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: DsSpace.xs),
      child: Row(
        children: [
          SizedBox(
              width: RetroType.width(context, 200),
              child: hint == null
                  ? name
                  // El `#tip` del sistema (como el resto del juego), no
                  // el `Tooltip` de Material (fix v0.19.1).
                  : RetroTooltip(
                      key: ValueKey('setting-hint-$label'),
                      message: hint!,
                      child: MouseRegion(
                          cursor: SystemMouseCursors.help, child: name))),
          Expanded(child: control),
        ],
      ),
    );
  }
}

/// Opciones excluyentes como botones (la elegida en `gold`).
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.keyPrefix,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String keyPrefix;
  final Map<T, String> options;
  final T value;

  /// `null`: deshabilitado (la opción la fija otro ajuste).
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final on = onChanged;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in options.entries)
          DsButton(e.value,
              key: ValueKey('$keyPrefix-${e.value}'),
              size: DsButtonSize.compact,
              selected: e.key == value,
              onPressed: on == null ? null : () => on(e.key)),
      ],
    );
  }
}

/// FUENTE DE LECTURA: cada opción escrita en su propia fuente (vista
/// previa), en su tamaño Normal y sin agrandarse.
class _FontChoice extends StatelessWidget {
  const _FontChoice({required this.value, required this.onChanged});

  final ReadingFont value;
  final ValueChanged<ReadingFont> onChanged;

  static const _options = {
    ReadingFont.vt323: ('VT323', RetroType.vt323Family, 20.0),
    ReadingFont.classic: ('', RetroType.pixelFamily, 8.0),
    ReadingFont.atkinson: ('ATKINSON', RetroType.atkinsonFamily, 18.0),
  };

  @override
  Widget build(BuildContext context) {
    final s = settingsStrings(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in _options.entries)
          ElevatedButton(
            key: ValueKey('display-font-${e.key.name}'),
            style: RetroTheme.compactButton().copyWith(
              side: e.key == value
                  ? const WidgetStatePropertyAll(BorderSide(
                      color: ProtoColors.gold,
                      width: RetroTheme.thinBorderWidth))
                  : null,
              foregroundColor: e.key == value
                  ? const WidgetStatePropertyAll(ProtoColors.gold)
                  : null,
            ),
            onPressed: () => onChanged(e.key),
            child: Text(
                retroText(s.t('ui.settings.a11y.font.sample', {
                  'font': e.key == ReadingFont.classic
                      ? s.t('ui.settings.a11y.font.classic')
                      : e.value.$1,
                  'dot': kDot,
                })),
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                    fontFamily: e.value.$2,
                    fontFamilyFallback: RetroType.bodyFallback,
                    fontSize: e.value.$3,
                    height: 1.2)),
          ),
      ],
    );
  }
}

Map<bool, String> _yesNo(Strings s) =>
    {true: s.t('ui.settings.yes'), false: s.t('ui.settings.no')};

/// Slider de volumen en % (20 pasos). Se oye al arrastrar y se guarda al
/// soltar.
class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({
    required this.sliderKey,
    required this.value,
    required this.muted,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final Key sliderKey;
  final double value;
  final bool muted;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final color = muted ? ProtoColors.dim : ProtoColors.gold;
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: ProtoColors.barBg,
              thumbColor: color,
              overlayShape: SliderComponentShape.noOverlay,
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6, elevation: 0, pressedElevation: 0),
              trackShape: const RectangularSliderTrackShape(),
            ),
            // 28 px de alto: se agarra en toda la franja, no solo en los
            // 12 px del pulgar (objetivos ≥ 24 px; accessibility.md).
            child: SizedBox(
              height: 28,
              child: Slider(
                key: sliderKey,
                value: value,
                divisions: 20,
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
        ),
        SizedBox(
          // "100%" en una línea con cualquier tamaño de texto.
          width: RetroType.width(context, 48),
          child: Text('${(value * 100).round()}%',
              maxLines: 1,
              textAlign: TextAlign.right,
              style: TextStyle(color: color)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Pestañas
// ---------------------------------------------------------------------

class _SoundTab extends ConsumerWidget {
  const _SoundTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(audioSettingsProvider);
    final t = ref.watch(stringsProvider);
    final c = ref.read(audioSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingRow(
          label: t.t('ui.settings.sound.master.label'),
          hint: t.t('ui.settings.sound.master.hint'),
          control: _VolumeSlider(
            sliderKey: const ValueKey('audio-master'),
            value: s.masterVolume,
            muted: s.muted,
            onChanged: (v) {
              c.setMaster(v);
              c.preview();
            },
            onChangeEnd: (_) => c.commit(),
          ),
        ),
        _SettingRow(
          label: t.t('ui.settings.sound.music.label'),
          hint: t.t('ui.settings.sound.music.hint'),
          control: _VolumeSlider(
            sliderKey: const ValueKey('audio-music'),
            value: s.musicVolume,
            muted: s.muted,
            onChanged: c.setMusic,
            onChangeEnd: (_) => c.commit(),
          ),
        ),
        _SettingRow(
          label: t.t('ui.settings.sound.sfx.label'),
          hint: t.t('ui.settings.sound.sfx.hint'),
          control: _VolumeSlider(
            sliderKey: const ValueKey('audio-sfx'),
            value: s.sfxVolume,
            muted: s.muted,
            onChanged: (v) {
              c.setSfx(v);
              c.preview();
            },
            onChangeEnd: (_) => c.commit(),
          ),
        ),
        _SettingRow(
          label: t.t('ui.settings.sound.mute.label'),
          hint: s.muted
              ? t.t('ui.settings.sound.mute.hint_on')
              : t.t('ui.settings.sound.mute.hint_off'),
          control: _Choice<bool>(
            keyPrefix: 'audio-mute',
            options: _yesNo(t),
            value: s.muted,
            onChanged: (v) {
              if (v != s.muted) c.toggleMute();
            },
          ),
        ),
      ],
    );
  }
}

class _DisplayTab extends ConsumerWidget {
  const _DisplayTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameSettingsProvider);
    final c = ref.read(gameSettingsProvider.notifier);
    final t = ref.watch(stringsProvider);
    final window = ref.watch(windowModeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (window.supported)
          _SettingRow(
            label: t.t('ui.settings.display.mode.label'),
            hint: t.t('ui.settings.display.mode.hint'),
            control: _Choice<bool>(
              keyPrefix: 'display-fullscreen',
              options: {
                false: t.t('ui.settings.display.mode.window'),
                true: t.t('ui.settings.display.mode.fullscreen')
              },
              value: s.fullscreen,
              onChanged: (v) => c.update(s.copyWith(fullscreen: v)),
            ),
          ),
        _SettingRow(
          label: t.t('ui.settings.display.scale.label'),
          hint: s.scale == ScaleMode.pixelPerfect
              ? t.t('ui.settings.display.scale.hint_pixel', {'times': kTimes})
              : t.t('ui.settings.display.scale.hint_fit'),
          control: _Choice<ScaleMode>(
            keyPrefix: 'display-scale',
            options: {
              ScaleMode.pixelPerfect:
                  t.t('ui.settings.display.scale.pixel_perfect'),
              ScaleMode.fit: t.t('ui.settings.display.scale.fit'),
            },
            value: s.scale,
            onChanged: (v) => c.update(s.copyWith(scale: v)),
          ),
        ),
        _SettingRow(
          label: t.t('ui.settings.display.crt.label'),
          hint: t.t('ui.settings.display.crt.hint'),
          control: _Choice<CrtLevel>(
            keyPrefix: 'display-crt',
            options: {
              CrtLevel.off: t.t('ui.settings.display.crt.off'),
              CrtLevel.soft: t.t('ui.settings.display.crt.soft'),
              CrtLevel.normal: t.t('ui.settings.display.crt.normal'),
              CrtLevel.strong: t.t('ui.settings.display.crt.strong'),
            },
            value: s.crt,
            onChanged: (v) => c.update(s.copyWith(crt: v)),
          ),
        ),
        _SettingRow(
          label: t.t('ui.settings.display.particles.label'),
          hint: t.t('ui.settings.display.particles.hint'),
          control: _Choice<ParticleLevel>(
            keyPrefix: 'display-particles',
            options: {
              ParticleLevel.low: t.t('ui.settings.display.particles.low'),
              ParticleLevel.medium: t.t('ui.settings.display.particles.medium'),
              ParticleLevel.high: t.t('ui.settings.display.particles.high'),
            },
            value: s.particles,
            onChanged: (v) => c.update(s.copyWith(particles: v)),
          ),
        ),
        _SettingRow(
          label: t.t('ui.settings.display.fps.label'),
          hint: t.t('ui.settings.display.fps.hint'),
          control: _Choice<FpsLimit>(
            keyPrefix: 'display-fps',
            options: {
              FpsLimit.fps30: '30',
              FpsLimit.fps60: '60',
              FpsLimit.none: t.t('ui.settings.display.fps.none'),
            },
            value: s.fpsLimit,
            onChanged: (v) => c.update(s.copyWith(fpsLimit: v)),
          ),
        ),
        // FPS Y PING (settings.md § 3.9).
        _SettingRow(
          label: t.t('ui.settings.display.perf.label'),
          hint: t.t('ui.settings.display.perf.hint'),
          control: _Choice<bool>(
            keyPrefix: 'display-perf',
            options: _yesNo(t),
            value: s.perfOverlay,
            onChanged: (v) => c.update(s.copyWith(perfOverlay: v)),
          ),
        ),
        _SettingRow(
          label: t.t('ui.settings.display.corner.label'),
          hint: s.perfOverlay
              ? t.t('ui.settings.display.corner.hint_on')
              : t.t('ui.settings.display.corner.hint_off'),
          control: _Choice<OverlayCorner>(
            keyPrefix: 'display-perf-corner',
            options: {
              OverlayCorner.topRight:
                  t.t('ui.settings.display.corner.top_right'),
              OverlayCorner.topLeft: t.t('ui.settings.display.corner.top_left'),
              OverlayCorner.bottomRight:
                  t.t('ui.settings.display.corner.bottom_right'),
              OverlayCorner.bottomLeft:
                  t.t('ui.settings.display.corner.bottom_left'),
            },
            value: s.perfCorner,
            onChanged: s.perfOverlay
                ? (v) => c.update(s.copyWith(perfCorner: v))
                : null,
          ),
        ),
      ],
    );
  }
}

/// ACCESIBILIDAD (docs/specs/accessibility.md, settings.md § 3.8): texto,
/// colores para daltonismo, movimiento y destellos en un solo lugar.
class _AccessibilityTab extends ConsumerWidget {
  const _AccessibilityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameSettingsProvider);
    final c = ref.read(gameSettingsProvider.notifier);
    final still = s.reduceMotion;
    final t = ref.watch(stringsProvider);
    return Column(
      key: const ValueKey('settings-accessibility'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tema y legibilidad (accessibility.md § 8).
        _SettingRow(
          label: t.t('ui.settings.a11y.theme.label'),
          hint: switch (s.uiTheme) {
            InterfaceTheme.blue => t.t('ui.settings.a11y.theme.hint_blue'),
            InterfaceTheme.dark => t.t('ui.settings.a11y.theme.hint_dark'),
            InterfaceTheme.highContrast =>
              t.t('ui.settings.a11y.theme.hint_high_contrast'),
          },
          control: _Choice<InterfaceTheme>(
            keyPrefix: 'a11y-theme',
            options: {
              InterfaceTheme.blue: t.t('ui.settings.a11y.theme.blue'),
              InterfaceTheme.dark: t.t('ui.settings.a11y.theme.dark'),
              InterfaceTheme.highContrast:
                  t.t('ui.settings.a11y.theme.high_contrast'),
            },
            value: s.uiTheme,
            onChanged: (v) => c.update(s.copyWith(uiTheme: v)),
          ),
        ),
        _SettingRow(
          label: t.t('ui.settings.a11y.text_colors.label'),
          hint: s.uiTheme == InterfaceTheme.highContrast
              ? t.t('ui.settings.a11y.text_colors.hint_forced')
              : s.textColors == TextColorMode.reduced
                  ? t.t('ui.settings.a11y.text_colors.hint_reduced')
                  : t.t('ui.settings.a11y.text_colors.hint_full'),
          control: _Choice<TextColorMode>(
            keyPrefix: 'a11y-textcolors',
            options: {
              TextColorMode.full: t.t('ui.settings.a11y.text_colors.full'),
              TextColorMode.reduced:
                  t.t('ui.settings.a11y.text_colors.reduced'),
            },
            value: s.uiTheme == InterfaceTheme.highContrast
                ? TextColorMode.reduced
                : s.textColors,
            onChanged: s.uiTheme == InterfaceTheme.highContrast
                ? null
                : (v) => c.update(s.copyWith(textColors: v)),
          ),
        ),
        _SettingRow(
          label: t.t('ui.settings.a11y.spacing.label'),
          hint: t.t('ui.settings.a11y.spacing.hint'),
          control: _Choice<UiSpacing>(
            keyPrefix: 'a11y-spacing',
            options: {
              UiSpacing.normal: t.t('ui.settings.a11y.normal'),
              UiSpacing.wide: t.t('ui.settings.a11y.wide'),
            },
            value: s.spacing,
            onChanged: (v) => c.update(s.copyWith(spacing: v)),
          ),
        ),
        const _ThemePreview(),
        // Texto (accessibility.md § 9).
        _SectionHeader(t.t('ui.settings.a11y.section.text'),
            key: const ValueKey('a11y-section-text')),
        _SettingRow(
          label: t.t('ui.settings.a11y.text_size.label'),
          hint: s.textSize == TextSize.enormous
              ? t.t('ui.settings.a11y.text_size.hint_enormous')
              : t.t('ui.settings.a11y.text_size.hint'),
          control: _Choice<TextSize>(
            keyPrefix: 'display-text',
            options: {
              TextSize.normal: t.t('ui.settings.a11y.normal'),
              TextSize.large: t.t('ui.settings.a11y.text_size.large'),
              TextSize.huge: t.t('ui.settings.a11y.text_size.huge'),
              TextSize.enormous: t.t('ui.settings.a11y.text_size.enormous'),
            },
            value: s.textSize,
            onChanged: (v) => c.update(s.copyWith(textSize: v)),
          ),
        ),
        _SettingRow(
          label: t.t('ui.settings.a11y.font.label'),
          hint: s.readingFont == ReadingFont.atkinson
              ? t.t('ui.settings.a11y.font.hint_atkinson')
              : t.t('ui.settings.a11y.font.hint'),
          control: _FontChoice(
            value: s.readingFont,
            onChanged: (v) => c.update(s.copyWith(readingFont: v)),
          ),
        ),
        _SettingRow(
          label: t.t('ui.settings.a11y.titles.label'),
          hint: s.readingFont == ReadingFont.classic
              ? t.t('ui.settings.a11y.titles.hint_classic')
              : t.t('ui.settings.a11y.titles.hint'),
          control: _Choice<bool>(
            keyPrefix: 'a11y-titles',
            options: _yesNo(t),
            value: s.readingTitles,
            onChanged: (v) => c.update(s.copyWith(readingTitles: v)),
          ),
        ),
        _SettingRow(
          label: t.t('ui.settings.a11y.letters.label'),
          hint: t.t('ui.settings.a11y.letters.hint'),
          control: _Choice<LetterSpacing>(
            keyPrefix: 'a11y-letters',
            options: {
              LetterSpacing.normal: t.t('ui.settings.a11y.normal'),
              LetterSpacing.wide: t.t('ui.settings.a11y.wide'),
            },
            value: s.letterSpacing,
            onChanged: (v) => c.update(s.copyWith(letterSpacing: v)),
          ),
        ),
        _SettingRow(
          label: t.t('ui.settings.a11y.notices.label'),
          hint: switch (s.noticeDuration) {
            NoticeDuration.normal =>
              t.t('ui.settings.a11y.notices.hint_normal'),
            NoticeDuration.long => t.t('ui.settings.a11y.notices.hint_long'),
            NoticeDuration.untilDismissed => t.t(
                'ui.settings.a11y.notices.hint_until_dismissed',
                {'close': kTimes}),
          },
          control: _Choice<NoticeDuration>(
            keyPrefix: 'a11y-notices',
            options: {
              NoticeDuration.normal: t.t('ui.settings.a11y.normal'),
              NoticeDuration.long: t.t('ui.settings.a11y.notices.long'),
              NoticeDuration.untilDismissed:
                  t.t('ui.settings.a11y.notices.until_dismissed'),
            },
            value: s.noticeDuration,
            onChanged: (v) => c.update(s.copyWith(noticeDuration: v)),
          ),
        ),
        // Travesía: solo lo del Mundo (campo, plan de build, chat).
        if (!_travesia)
          _SettingRow(
            label: t.t('ui.settings.a11y.map_labels.label'),
            hint: t.t('ui.settings.a11y.map_labels.hint'),
            control: _Choice<MapLabelBackdrop>(
              keyPrefix: 'a11y-maplabels',
              options: {
                MapLabelBackdrop.none: t.t('ui.settings.a11y.map_labels.none'),
                MapLabelBackdrop.shaded:
                    t.t('ui.settings.a11y.map_labels.shaded'),
                MapLabelBackdrop.box: t.t('ui.settings.a11y.map_labels.box'),
              },
              value: s.mapLabelBackdrop,
              onChanged: (v) => c.update(s.copyWith(mapLabelBackdrop: v)),
            ),
          ),
        _SettingRow(
          label: t.t('ui.settings.a11y.battle_log.label'),
          hint: s.battleLog == BattleLogMode.extended
              ? t.t('ui.settings.a11y.battle_log.hint_extended')
              : t.t('ui.settings.a11y.battle_log.hint'),
          control: _Choice<BattleLogMode>(
            keyPrefix: 'a11y-battlelog',
            options: {
              BattleLogMode.normal: t.t('ui.settings.a11y.normal'),
              BattleLogMode.extended:
                  t.t('ui.settings.a11y.battle_log.extended'),
            },
            value: s.battleLog,
            onChanged: (v) => c.update(s.copyWith(battleLog: v)),
          ),
        ),
        _TextPreview(settings: s),
        // TEXTOS (ui_minimal.md § 8): descripciones cortas o completas.
        _SettingRow(
          label: t.t('ui.settings.a11y.text_detail.label'),
          hint: s.textDetail == TextDetail.full
              ? t.t('ui.settings.a11y.text_detail.hint_full')
              : t.t('ui.settings.a11y.text_detail.hint_summary'),
          control: _Choice<TextDetail>(
            keyPrefix: 'a11y-textdetail',
            options: {
              TextDetail.summary: t.t('ui.settings.a11y.text_detail.summary'),
              TextDetail.full: t.t('ui.settings.a11y.text_detail.full'),
            },
            value: s.textDetail,
            onChanged: (v) => c.update(s.copyWith(textDetail: v)),
          ),
        ),
        _TextDetailExample(mode: s.textDetail),
        _SectionHeader(t.t('ui.settings.a11y.section.color_motion')),
        _SettingRow(
          label: t.t('ui.settings.a11y.vision.label'),
          hint: _visionHint(t, s.colorVision),
          control: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Choice<ColorVision>(
                keyPrefix: 'a11y-vision',
                options: {
                  ColorVision.off: t.t('ui.settings.a11y.vision.off'),
                  ColorVision.deuteranopia:
                      t.t('ui.settings.a11y.vision.deuteranopia'),
                  ColorVision.protanopia:
                      t.t('ui.settings.a11y.vision.protanopia'),
                  ColorVision.tritanopia:
                      t.t('ui.settings.a11y.vision.tritanopia'),
                },
                value: s.colorVision,
                onChanged: (v) => c.update(s.copyWith(colorVision: v)),
              ),
              const SizedBox(height: 8),
              const _VisionPreview(),
            ],
          ),
        ),
        _SettingRow(
          label: t.t('ui.settings.a11y.motion.label'),
          hint: still
              ? t.t('ui.settings.a11y.motion.hint_on')
              : t.t('ui.settings.a11y.motion.hint_off'),
          control: _Choice<bool>(
            keyPrefix: 'a11y-motion',
            options: _yesNo(t),
            value: s.reduceMotion,
            onChanged: (v) => c.update(s.copyWith(reduceMotion: v)),
          ),
        ),
        _SettingRow(
          label: t.t('ui.settings.a11y.shake.label'),
          hint: still
              ? t.t('ui.settings.a11y.shake.hint_off')
              : t.t('ui.settings.a11y.shake.hint'),
          control: _Choice<bool>(
            keyPrefix: 'display-shake',
            options: _yesNo(t),
            value: s.shakeOn,
            onChanged:
                still ? null : (v) => c.update(s.copyWith(screenShake: v)),
          ),
        ),
        _SettingRow(
          label: t.t('ui.settings.a11y.flashes.label'),
          hint: t.t(
              'ui.settings.a11y.flashes.hint', {'still': still ? 'yes' : 'no'}),
          control: _Choice<FlashLevel>(
            keyPrefix: 'display-flashes',
            options: {
              FlashLevel.normal: t.t('ui.settings.a11y.flashes.normal'),
              FlashLevel.reduced: t.t('ui.settings.a11y.flashes.reduced'),
              FlashLevel.off: t.t('ui.settings.a11y.flashes.off'),
            },
            value: still && s.flashes == FlashLevel.normal
                ? FlashLevel.reduced
                : s.flashes,
            onChanged: (v) => c.update(s.copyWith(flashes: v)),
          ),
        ),
        _SettingRow(
          label: t.t('ui.settings.a11y.darkness.label'),
          hint: t.t('ui.settings.a11y.darkness.hint'),
          control: _Choice<DarknessLevel>(
            keyPrefix: 'display-darkness',
            options: {
              DarknessLevel.normal: t.t('ui.settings.a11y.normal'),
              DarknessLevel.soft: t.t('ui.settings.a11y.darkness.soft'),
              DarknessLevel.off: t.t('ui.settings.a11y.darkness.off'),
            },
            value: s.darkness,
            onChanged: (v) => c.update(s.copyWith(darkness: v)),
          ),
        ),
      ],
    );
  }

  static String _visionHint(Strings t, ColorVision v) => t.t(
      'ui.settings.a11y.vision.hint_${switch (v) {
        ColorVision.off => 'off',
        ColorVision.deuteranopia => 'deuteranopia',
        ColorVision.protanopia => 'protanopia',
        ColorVision.tritanopia => 'tritanopia',
      }}',
      const {'up': '\u25B2', 'down': '\u25BC'});
}

/// Encabezado de un grupo de ajustes (`TEXTO`, `COLOR Y MOVIMIENTO`): en
/// la fuente de títulos, con una línea del borde del tema debajo.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: DsSpace.sm),
        child: DsSectionHeader(retroText(text)),
      );
}

/// Vista previa en vivo de la sección TEXTO (accessibility.md § 9): un
/// tip con título y lectura (fuente, títulos, tamaño, espaciado), un
/// botón, una etiqueta del mapa sobre tiles cargados con su fondo, un
/// aviso (con su × en HASTA CERRAR) y, en EXTENDIDO, el registro de
/// batalla. Sin foco ni clics.
/// Ejemplo de una línea por modo de TEXTOS (v0.25.6): el elegido
/// resaltado, el otro en gris.
class _TextDetailExample extends StatelessWidget {
  const _TextDetailExample({required this.mode});

  final TextDetail mode;

  static const examples = {
    TextDetail.summary: 'ui.settings.a11y.text_detail.example_summary',
    TextDetail.full: 'ui.settings.a11y.text_detail.example_full',
  };

  @override
  Widget build(BuildContext context) => Padding(
        key: const ValueKey('a11y-textdetail-example'),
        padding: EdgeInsets.only(
            left: RetroType.width(context, 200), bottom: UiTheme.space(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in examples.entries)
              Text(settingsStrings(context).t(e.value),
                  style: DsText.detail(
                      e.key == mode ? DsColors.text : DsColors.textSecondary)),
          ],
        ),
      );
}

class _TextPreview extends StatelessWidget {
  const _TextPreview({required this.settings});

  final GameSettings settings;

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final t = settingsStrings(context);
    // Como un nombre del mapa a la escala de 1280×720 (16 px).
    const labelSize = 16.0;
    return Padding(
      key: const ValueKey('a11y-text-preview'),
      padding: EdgeInsets.only(
          left: RetroType.width(context, 200),
          top: UiTheme.space(4),
          bottom: UiTheme.space(8)),
      child: ExcludeFocus(
        child: IgnorePointer(
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              Container(
                padding: RetroHoverCard.padding,
                decoration: BoxDecoration(
                  color: ProtoColors.bg,
                  border: Border.all(
                      color: RetroHoverCard.borderColor,
                      width: UiTheme.buttonBorderWidth),
                ),
                constraints:
                    BoxConstraints(maxWidth: RetroType.width(context, 260)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(retroText(t.t('ui.settings.preview.item_name')),
                        key: const ValueKey('a11y-text-preview-title'),
                        style: RetroType.style(RetroType.label,
                            color: ProtoColors.title)),
                    const SizedBox(height: 4),
                    DefaultTextStyle(
                      style: RetroHoverCard.textStyle,
                      child: RetroTipText(
                          t.t('ui.settings.preview.tip', {'dot': kDot}),
                          maxWidth: RetroType.width(context, 240)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    style: RetroTheme.compactButton(),
                    onPressed: () {},
                    child: Text(t.t('ui.settings.preview.equip')),
                  ),
                  const SizedBox(height: 8),
                  // Etiqueta del mapa sobre tiles: el fondo elegido.
                  CustomPaint(
                    key: ValueKey(
                        'a11y-maplabel-preview-${s.mapLabelBackdrop.name}'),
                    size: Size(RetroType.width(context, 210), labelSize * 3),
                    painter: MapLabelSamplePainter(
                        backdrop: s.mapLabelBackdrop, size: labelSize),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    key: const ValueKey('a11y-notice-preview'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ProtoColors.bg.withValues(alpha: 0.85),
                      border:
                          Border.all(color: ProtoColors.panelBorder, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(retroText(switch (s.noticeDuration) {
                          NoticeDuration.normal => t.t(
                              'ui.settings.preview.notice_timed',
                              {'dot': kDot, 'seconds': 3}),
                          NoticeDuration.long => t.t(
                              'ui.settings.preview.notice_timed',
                              {'dot': kDot, 'seconds': 6}),
                          NoticeDuration.untilDismissed =>
                            t.t('ui.settings.preview.notice'),
                        })),
                        if (s.noticeDuration.persistent) ...[
                          const SizedBox(width: 8),
                          NoticeClose(onPressed: () {}),
                        ],
                      ],
                    ),
                  ),
                  if (s.battleLog == BattleLogMode.extended) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: RetroType.width(context, 220),
                      child: BattleLogHistory(lines: [
                        t.t('ui.settings.preview.log_hit'),
                        t.t('ui.settings.preview.log_enemy'),
                      ]),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Muestra de la paleta activa: mejora / empeora, HP / MP, las cinco
/// rarezas con su letra y la vida / quiebre de un enemigo.
class _VisionPreview extends StatelessWidget {
  const _VisionPreview();

  @override
  Widget build(BuildContext context) {
    final t = settingsStrings(context);
    Widget swatch(String text, Color color, {Color? ink}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: ink == null ? null : color,
            border: Border.all(color: color, width: 2),
          ),
          child: Text(retroText(text), style: TextStyle(color: ink ?? color)),
        );
    const rarities = [
      ('C', ProtoColors.common),
      ('M', VisionColor(VisionSlot.magic)),
      ('R', VisionColor(VisionSlot.rare)),
      ('E', VisionColor(VisionSlot.epic)),
      ('L', VisionColor(VisionSlot.legendary)),
    ];
    return Wrap(
      key: const ValueKey('a11y-vision-preview'),
      spacing: 6,
      runSpacing: 6,
      children: [
        swatch(t.t('ui.settings.a11y.vision.better', const {'up': '\u25B2'}),
            ProtoColors.green),
        swatch(t.t('ui.settings.a11y.vision.worse', const {'down': '\u25BC'}),
            ProtoColors.red),
        swatch('HP', ProtoColors.hp, ink: ProtoColors.bg),
        swatch('MP', ProtoColors.mp, ink: ProtoColors.bg),
        for (final (l, col) in rarities) swatch(l, col),
        swatch(t.t('ui.settings.a11y.vision.life'),
            const VisionColor(VisionSlot.enemyHp),
            ink: ProtoColors.bg),
        swatch(
            t.t('ui.settings.a11y.vision.break', const {'diamond': '\u25C6'}),
            const VisionColor(VisionSlot.breakBar),
            ink: ProtoColors.bg),
      ],
    );
  }
}

/// Vista previa del tema, los colores del texto y el espaciado: un tip de
/// nodo del árbol como los del juego y dos filas de menú.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview();

  @override
  Widget build(BuildContext context) {
    final t = settingsStrings(context);
    final tip = t.t(
        'ui.settings.preview.node_tip', const {'dot': kDot, 'minus': '\u2212'});
    return Padding(
      key: const ValueKey('a11y-theme-preview'),
      padding: EdgeInsets.only(
          left: RetroType.width(context, 200),
          top: UiTheme.space(4),
          bottom: UiTheme.space(8)),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: [
          Container(
            padding: RetroHoverCard.padding,
            decoration: BoxDecoration(
              color: ProtoColors.bg,
              border: Border.all(
                  color: RetroHoverCard.borderColor,
                  width: UiTheme.buttonBorderWidth),
            ),
            child: DefaultTextStyle(
              style: RetroHoverCard.textStyle,
              child: RetroTipText(tip, maxWidth: RetroType.width(context, 260)),
            ),
          ),
          // Solo de muestra: sin foco ni clics (el teclado no se detiene).
          SizedBox(
            width: RetroType.width(context, 170),
            child: ExcludeFocus(
              child: IgnorePointer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MenuRow(
                        label: t.t('ui.settings.preview.reforge'),
                        value: t.t('ui.settings.preview.reforge_cost'),
                        selected: true,
                        onTap: () {}),
                    MenuRow(
                        label: t.t('ui.settings.preview.upgrade'),
                        value: t.t('ui.settings.preview.upgrade_missing'),
                        selected: false,
                        dimmed: true,
                        onTap: () {}),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameTab extends ConsumerWidget {
  const _GameTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameSettingsProvider);
    final c = ref.read(gameSettingsProvider.notifier);
    final strings = ref.watch(stringsProvider);
    final t = strings;
    final tables = ref.watch(stringTablesProvider);
    final locales = tables.registry
        .selectable(showHidden: FeatureFlags.instance.showHiddenLocales);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // IDIOMA (docs/specs/i18n.md § 3.1): solo los idiomas publicados
        // (los ocultos, solo en la build de desarrollo).
        _SettingRow(
          label: strings.t('ui.settings.language.label'),
          hint: strings.t('ui.settings.language.hint'),
          control: _Choice<String>(
            keyPrefix: 'game-locale',
            options: {
              '': strings.t('ui.settings.language.auto'),
              for (final l in locales) l.tag: l.nativeName,
            },
            value: LocaleId.fromTag(s.locale) != null &&
                    locales.contains(LocaleId.fromTag(s.locale))
                ? s.locale
                : '',
            onChanged: (v) => c.update(s.copyWith(locale: v)),
          ),
        ),
        _SettingRow(
          label: t.t('ui.settings.game.numbers.label'),
          hint: t.t('ui.settings.game.numbers.hint'),
          control: _Choice<bool>(
            keyPrefix: 'game-numbers',
            options: _yesNo(t),
            value: s.damageNumbers,
            onChanged: (v) => c.update(s.copyWith(damageNumbers: v)),
          ),
        ),
        _SettingRow(
          label: t.t('ui.settings.game.turn.label'),
          hint: t.t('ui.settings.game.turn.hint'),
          control: _Choice<TurnTimer>(
            keyPrefix: 'game-turn',
            options: {
              TurnTimer.normal: t.t('ui.settings.game.turn.normal'),
              TurnTimer.long: t.t('ui.settings.game.turn.long'),
              TurnTimer.unlimited: t.t('ui.settings.game.turn.unlimited'),
            },
            value: s.turnTimer,
            onChanged: (v) => c.update(s.copyWith(turnTimer: v)),
          ),
        ),
        // Travesía: solo lo del Mundo (campo, plan de build, chat).
        if (!_travesia)
          _SettingRow(
            label: t.t('ui.settings.game.confirm_drop.label'),
            hint: t.t('ui.settings.game.confirm_drop.hint'),
            control: _Choice<bool>(
              keyPrefix: 'game-confirm-drop',
              options: _yesNo(t),
              value: s.confirmDrop,
              onChanged: (v) => c.update(s.copyWith(confirmDrop: v)),
            ),
          ),
        // Travesía: solo lo del Mundo (campo, plan de build, chat).
        if (!_travesia)
          _SettingRow(
            label: t.t('ui.settings.game.build_notices.label'),
            hint: t.t('ui.settings.game.build_notices.hint'),
            control: _Choice<bool>(
              keyPrefix: 'game-build-notices',
              options: _yesNo(t),
              value: s.buildNotices,
              onChanged: (v) => c.update(s.copyWith(buildNotices: v)),
            ),
          ),
        // HUD v0.8.1 (exploration.md § "Chat").
        // Travesía: solo lo del Mundo (campo, plan de build, chat).
        if (!_travesia)
          _SettingRow(
            label: t.t('ui.settings.game.chat.label'),
            hint: t.t('ui.settings.game.chat.hint'),
            control: _Choice<ChatVisibility>(
              keyPrefix: 'game-chat',
              options: {
                ChatVisibility.hidden: t.t('ui.settings.game.chat.hidden'),
                ChatVisibility.always: t.t('ui.settings.game.chat.always'),
              },
              value: s.chat,
              onChanged: (v) => c.update(s.copyWith(chat: v)),
            ),
          ),
        // Travesía: solo lo del Mundo (campo, plan de build, chat).
        if (!_travesia)
          _SettingRow(
            label: t.t('ui.settings.game.chat_notices.label'),
            hint: t.t('ui.settings.game.chat_notices.hint'),
            control: _Choice<bool>(
              keyPrefix: 'game-chat-notices',
              options: _yesNo(t),
              value: s.chatNotices,
              onChanged: s.chat == ChatVisibility.always
                  ? null
                  : (v) => c.update(s.copyWith(chatNotices: v)),
            ),
          ),
      ],
    );
  }
}

/// Las teclas, de solo lectura (docs/specs/exploration.md § "Teclado").
class _ControlsTab extends StatelessWidget {
  const _ControlsTab();

  /// Section key -> binding ids (`ui.settings.controls.<section>.<id>.keys|action`).
  static const _bindings = <String, List<String>>{
    'map': [
      'move',
      'interact',
      'hidden_loot',
      'character',
      'equipment',
      'farm_tool',
      'journal',
      'flame',
      'objectives',
      'party',
      'dismiss',
      'big_map',
      'minimap_zoom',
      'vote',
    ],
    'battle': ['action', 'target', 'pass', 'back'],
    'menus': [],
    'chat': ['open', 'close'],
  };

  static List<(String, List<(String, String)>)> sections(Strings t) => [
        for (final e in _bindings.entries)
          (
            t.t('ui.settings.controls.section.${e.key}'),
            // Mapa de teclas de los menús (lib/app/widgets/menu_focus.dart).
            e.key == 'menus'
                ? kMenuKeys
                : [
                    for (final id in e.value)
                      (
                        t.t('ui.settings.controls.${e.key}.$id.keys'),
                        t.t('ui.settings.controls.${e.key}.$id.action'),
                      ),
                  ],
          ),
      ];

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('settings-controls'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (title, keys) in sections(settingsStrings(context)))
          PanelSection(
            title,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (k, what) in keys)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 200,
                        child: Text(retroText(k),
                            style: const TextStyle(color: ProtoColors.sky)),
                      ),
                      Expanded(child: Text(retroText(what))),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Travesía (roguelike.md § 12.2): sin las opciones que solo tienen
/// sentido en el Mundo.
bool get _travesia => GameEdition.current.mode == GameModeKind.travesia;
