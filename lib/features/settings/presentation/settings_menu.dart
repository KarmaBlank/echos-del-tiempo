import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../app/theme/panel_widgets.dart';
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
import '../../../core/settings/settings_providers.dart';

/// Pestañas del menú (docs/specs/settings.md § "Estructura").
enum SettingsTab {
  sound('SONIDO', 'Volumen general, de la música y de los efectos.'),
  display('PANTALLA', 'Ventana, gráficos y rendimiento.'),
  accessibility('ACCESIBILIDAD',
      'Tema, texto, colores para daltonismo, movimiento y destellos.'),
  game('JUEGO', 'Números de daño, tiempo de turno y avisos.'),
  controls('CONTROLES', 'Todas las teclas del juego.');

  const SettingsTab(this.label, this.hint);

  final String label;
  final String hint;
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

  String get _help => widget.inGame
      ? '<b>Pausa</b><br>Ajustes del juego y salidas. '
          '${widget.multiplayer ? 'En multijugador el juego <b>no se detiene</b> solo: <b>PAUSAR AL GRUPO</b> lo pausa para todos y cualquiera puede reanudar.' : 'Jugando solo, la partida se detiene mientras el menú está abierto.'}'
          '<br><span class="k">Esc</span> cierra · <span class="k">Tab</span> / flechas mueven · <span class="k">Enter</span> elige.<br>'
          'Los ajustes se guardan solos.'
      : '<b>Configuración</b><br>Sonido, pantalla, juego y controles. '
          'Los cambios se aplican y se guardan al momento.<br>'
          '<span class="k">Esc</span> cierra · <span class="k">Tab</span> / flechas mueven · <span class="k">Enter</span> elige.';

  @override
  Widget build(BuildContext context) {
    final confirm = _confirm;
    // Q / E, Ctrl+Tab y 1-9 cambian de pestaña (menu_focus.dart).
    return MenuTabKeys(
      count: SettingsTab.values.length,
      index: _tab.index,
      onChanged: (i) => setState(() => _tab = SettingsTab.values[i]),
      child: Material(
        type: MaterialType.transparency,
        child: PanelFrame(
          key: const ValueKey('settings-menu'),
          title: widget.inGame ? 'PAUSA' : 'CONFIGURACIÓN',
          width: 680,
          help: _help,
          onClose: _escape,
          titleTrailing: widget.inGame ? _status() : null,
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PanelTabs(
                labels: [for (final t in SettingsTab.values) t.label],
                index: _tab.index,
                onChanged: (i) => setState(() => _tab = SettingsTab.values[i]),
              ),
              PanelHint(_tab.hint),
            ],
          ),
          leading: [
            if (widget.inGame && confirm == null) ...[
              PanelButton('SALIR AL TÍTULO',
                  key: const ValueKey('pause-exit-title'),
                  onPressed: widget.onExitToTitle == null
                      ? null
                      : () => setState(() => _confirm = _Exit.title)),
              PanelButton('SALIR DEL JUEGO',
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
                    PanelButton(
                        widget.groupPaused
                            ? 'REANUDAR AL GRUPO'
                            : 'PAUSAR AL GRUPO',
                        key: const ValueKey('pause-group'),
                        selected: widget.groupPaused,
                        onPressed: () =>
                            widget.onGroupPause!(!widget.groupPaused)),
                  PanelButton(
                      widget.inGame ? 'CONTINUAR [ESC]' : 'CERRAR [ESC]',
                      key: const ValueKey('settings-close'),
                      accent: ProtoColors.green,
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
      retroText(running
          ? 'El juego sigue corriendo en multijugador'
          : widget.multiplayer
              ? 'Grupo en pausa'
              : 'Juego en pausa'),
      key: const ValueKey('pause-status'),
      style: TextStyle(
          fontFamily: RetroType.bodyFamily,
          letterSpacing: RetroType.letterSpacing,
          fontFamilyFallback: RetroType.bodyFallback,
          fontSize: RetroType.small,
          color: running ? ProtoColors.orange : ProtoColors.green),
    );
  }

  List<Widget> _confirmRow(_Exit what) {
    final quit = what == _Exit.quit;
    final consequence = widget.multiplayer
        ? 'Dejas la sala; tus compañeros siguen sin ti.'
        : widget.inMission
            ? 'La misión en curso se abandona.'
            : 'Tu personaje queda guardado.';
    return [
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: ProtoText(
          key: const ValueKey('pause-confirm-question'),
          '<b>${quit ? '¿Salir del juego?' : '¿Volver al título?'}</b> '
          '${protoColor(ProtoColors.orange, consequence)}',
        ),
      ),
      PanelButton('CANCELAR',
          key: const ValueKey('pause-confirm-cancel'),
          onPressed: () => setState(() => _confirm = null)),
      PanelButton(quit ? 'SALIR DEL JUEGO' : 'SALIR AL TÍTULO',
          key: const ValueKey('pause-confirm-yes'),
          accent: ProtoColors.red, onPressed: () {
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

/// Botón `≡ MENÚ [ESC]` (HUD del mapa y batalla) que abre la pausa.
class PauseMenuButton extends StatelessWidget {
  const PauseMenuButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ElevatedButton(
        key: const ValueKey('pause-open'),
        style: RetroTheme.compactButton(),
        onPressed: onPressed,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuGlyph(),
            SizedBox(width: 8),
            Text('MENU [ESC]'),
          ],
        ),
      );
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

/// Una fila de ajuste: nombre a la izquierda, control a la derecha y una
/// línea `dim` debajo que dice qué hace.
class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.control, this.hint});

  final String label;
  final Widget control;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: UiTheme.space(6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                  width: RetroType.width(context, 200),
                  child: Text(retroText(label))),
              Expanded(child: control),
            ],
          ),
          if (hint != null)
            Padding(
              padding: EdgeInsets.only(left: RetroType.width(context, 200)),
              child: Text(retroText(hint!),
                  style: const TextStyle(color: ProtoColors.dim)),
            ),
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
          PanelButton(e.value,
              key: ValueKey('$keyPrefix-${e.value}'),
              selected: e.key == value,
              accent: e.key == value ? ProtoColors.gold : null,
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
    ReadingFont.classic: ('CLÁSICA', RetroType.pixelFamily, 8.0),
    ReadingFont.atkinson: ('ATKINSON', RetroType.atkinsonFamily, 18.0),
  };

  @override
  Widget build(BuildContext context) {
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
            child: Text(retroText('${e.value.$1} · Ñandú ¿áé?'),
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

const _yesNo = {true: 'SÍ', false: 'NO'};

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
    final c = ref.read(audioSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingRow(
          label: 'VOLUMEN GENERAL',
          hint: 'Sube o baja todo a la vez.',
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
          label: 'MÚSICA',
          hint: 'La música de fondo y los jingles.',
          control: _VolumeSlider(
            sliderKey: const ValueKey('audio-music'),
            value: s.musicVolume,
            muted: s.muted,
            onChanged: c.setMusic,
            onChangeEnd: (_) => c.commit(),
          ),
        ),
        _SettingRow(
          label: 'EFECTOS (FX)',
          hint: 'Golpes, habilidades y loot. Suena una muestra al moverlo.',
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
          label: 'SILENCIAR TODO',
          hint: s.muted
              ? 'Todo el sonido está silenciado.'
              : 'Apaga música y efectos sin perder los volúmenes.',
          control: _Choice<bool>(
            keyPrefix: 'audio-mute',
            options: _yesNo,
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
    final window = ref.watch(windowModeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (window.supported)
          _SettingRow(
            label: 'MODO',
            hint: 'Pantalla completa sin bordes en el monitor de la ventana.',
            control: _Choice<bool>(
              keyPrefix: 'display-fullscreen',
              options: const {false: 'VENTANA', true: 'PANTALLA COMPLETA'},
              value: s.fullscreen,
              onChanged: (v) => c.update(s.copyWith(fullscreen: v)),
            ),
          ),
        _SettingRow(
          label: 'ESCALADO',
          hint: s.scale == ScaleMode.pixelPerfect
              ? 'Píxeles exactos (×2, ×3...) con barras negras.'
              : 'Llena la ventana; algunos píxeles salen más anchos.',
          control: _Choice<ScaleMode>(
            keyPrefix: 'display-scale',
            options: const {
              ScaleMode.pixelPerfect: 'PIXEL PERFECT',
              ScaleMode.fit: 'AJUSTAR',
            },
            value: s.scale,
            onChanged: (v) => c.update(s.copyWith(scale: v)),
          ),
        ),
        _SettingRow(
          label: 'FILTRO CRT',
          hint: 'Líneas, brillo y bordes de un televisor viejo.',
          control: _Choice<CrtLevel>(
            keyPrefix: 'display-crt',
            options: const {
              CrtLevel.off: 'APAGADO',
              CrtLevel.soft: 'SUAVE',
              CrtLevel.normal: 'NORMAL',
              CrtLevel.strong: 'FUERTE',
            },
            value: s.crt,
            onChanged: (v) => c.update(s.copyWith(crt: v)),
          ),
        ),
        _SettingRow(
          label: 'PARTÍCULAS',
          hint: 'Chispas, nieve y destellos. BAJA si la PC sufre.',
          control: _Choice<ParticleLevel>(
            keyPrefix: 'display-particles',
            options: const {
              ParticleLevel.low: 'BAJA',
              ParticleLevel.medium: 'MEDIA',
              ParticleLevel.high: 'ALTA',
            },
            value: s.particles,
            onChanged: (v) => c.update(s.copyWith(particles: v)),
          ),
        ),
        _SettingRow(
          label: 'LÍMITE DE FPS',
          hint: 'Cuadros por segundo. Sin límite = lo que dé el monitor.',
          control: _Choice<FpsLimit>(
            keyPrefix: 'display-fps',
            options: const {
              FpsLimit.fps30: '30',
              FpsLimit.fps60: '60',
              FpsLimit.none: 'SIN LÍMITE',
            },
            value: s.fpsLimit,
            onChanged: (v) => c.update(s.copyWith(fpsLimit: v)),
          ),
        ),
        // FPS Y PING (settings.md § 3.9).
        _SettingRow(
          label: 'FPS Y PING',
          hint: 'Muestra en una esquina los cuadros por segundo y, en una '
              'sala, el ping.',
          control: _Choice<bool>(
            keyPrefix: 'display-perf',
            options: _yesNo,
            value: s.perfOverlay,
            onChanged: (v) => c.update(s.copyWith(perfOverlay: v)),
          ),
        ),
        _SettingRow(
          label: 'ESQUINA',
          hint: s.perfOverlay
              ? 'Dónde va el indicador de FPS y ping.'
              : 'Activá FPS Y PING para elegir la esquina.',
          control: _Choice<OverlayCorner>(
            keyPrefix: 'display-perf-corner',
            options: const {
              OverlayCorner.topRight: 'ARRIBA DER.',
              OverlayCorner.topLeft: 'ARRIBA IZQ.',
              OverlayCorner.bottomRight: 'ABAJO DER.',
              OverlayCorner.bottomLeft: 'ABAJO IZQ.',
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
    return Column(
      key: const ValueKey('settings-accessibility'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tema y legibilidad (accessibility.md § 8).
        _SettingRow(
          label: 'TEMA DE INTERFAZ',
          hint: switch (s.uiTheme) {
            InterfaceTheme.blue =>
              'El de siempre: paneles azul marino y texto de colores.',
            InterfaceTheme.dark => 'Paneles casi negros y neutros; el '
                'dorado solo marca la selección y el foco.',
            InterfaceTheme.highContrast => 'Fondo negro, texto blanco, foco '
                'amarillo y bordes gruesos. Color solo donde significa algo.',
          },
          control: _Choice<InterfaceTheme>(
            keyPrefix: 'a11y-theme',
            options: const {
              InterfaceTheme.blue: 'AZUL',
              InterfaceTheme.dark: 'OSCURO',
              InterfaceTheme.highContrast: 'ALTO CONTRASTE',
            },
            value: s.uiTheme,
            onChanged: (v) => c.update(s.copyWith(uiTheme: v)),
          ),
        ),
        _SettingRow(
          label: 'COLORES DEL TEXTO',
          hint: s.uiTheme == InterfaceTheme.highContrast
              ? 'ALTO CONTRASTE usa siempre los colores por función.'
              : s.textColors == TextColorMode.reduced
                  ? 'Por función: nombres en blanco, descripción gris clara, '
                      'datos atenuados, un acento para valores; verde / rojo, '
                      'rarezas y estados siguen igual.'
                  : 'Cada texto con sus colores (como en v0.8.0).',
          control: _Choice<TextColorMode>(
            keyPrefix: 'a11y-textcolors',
            options: const {
              TextColorMode.full: 'COMPLETO',
              TextColorMode.reduced: 'REDUCIDO',
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
          label: 'ESPACIADO',
          hint: 'AMPLIO: más interlineado, aire entre líneas y filas y '
              'separadores entre las secciones de las fichas.',
          control: _Choice<UiSpacing>(
            keyPrefix: 'a11y-spacing',
            options: const {
              UiSpacing.normal: 'NORMAL',
              UiSpacing.wide: 'AMPLIO',
            },
            value: s.spacing,
            onChanged: (v) => c.update(s.copyWith(spacing: v)),
          ),
        ),
        const _ThemePreview(),
        // Texto (accessibility.md § 9).
        const _SectionHeader('TEXTO', key: ValueKey('a11y-section-text')),
        _SettingRow(
          label: 'TAMAÑO DEL TEXTO',
          hint: s.textSize == TextSize.enormous
              ? 'ENORME: el doble que NORMAL. Los paneles scrollean y las '
                  'fichas largas pasan a columnas.'
              : 'Letra de menús, fichas, chat y batalla. Se ajusta a la '
                  'grilla de la fuente para que se vea nítida.',
          control: _Choice<TextSize>(
            keyPrefix: 'display-text',
            options: const {
              TextSize.normal: 'NORMAL',
              TextSize.large: 'GRANDE',
              TextSize.huge: 'MUY GRANDE',
              TextSize.enormous: 'ENORME',
            },
            value: s.textSize,
            onChanged: (v) => c.update(s.copyWith(textSize: v)),
          ),
        ),
        _SettingRow(
          label: 'FUENTE DE LECTURA',
          hint: s.readingFont == ReadingFont.atkinson
              ? 'Atkinson Hyperlegible: diseñada para baja visión, letras '
                  'que no se confunden (I l 1, O 0). No es pixel.'
              : 'Fichas, chat, menús y batalla. Los títulos y botones '
                  'cambian solo con la opción de abajo.',
          control: _FontChoice(
            value: s.readingFont,
            onChanged: (v) => c.update(s.copyWith(readingFont: v)),
          ),
        ),
        _SettingRow(
          label: 'TÍTULOS CON LA FUENTE DE LECTURA',
          hint: s.readingFont == ReadingFont.classic
              ? 'Con CLÁSICA los títulos ya usan la misma fuente.'
              : 'Títulos, botones y pestañas en la fuente de lectura en vez '
                  'de las mayúsculas pixel.',
          control: _Choice<bool>(
            keyPrefix: 'a11y-titles',
            options: _yesNo,
            value: s.readingTitles,
            onChanged: (v) => c.update(s.copyWith(readingTitles: v)),
          ),
        ),
        _SettingRow(
          label: 'ESPACIADO ENTRE LETRAS',
          hint: 'AMPLIO: un poco más de aire entre las letras del texto de '
              'lectura.',
          control: _Choice<LetterSpacing>(
            keyPrefix: 'a11y-letters',
            options: const {
              LetterSpacing.normal: 'NORMAL',
              LetterSpacing.wide: 'AMPLIO',
            },
            value: s.letterSpacing,
            onChanged: (v) => c.update(s.copyWith(letterSpacing: v)),
          ),
        ),
        _SettingRow(
          label: 'DURACIÓN DE LOS AVISOS',
          hint: switch (s.noticeDuration) {
            NoticeDuration.normal =>
              'Avisos de loot, build, chat, puntos y misiones: unos segundos.',
            NoticeDuration.long => 'Los avisos se ven el doble de tiempo.',
            NoticeDuration.untilDismissed => 'Quedan hasta cerrarlos con su × '
                'o con Retroceso (cierra todos).',
          },
          control: _Choice<NoticeDuration>(
            keyPrefix: 'a11y-notices',
            options: const {
              NoticeDuration.normal: 'NORMAL',
              NoticeDuration.long: 'LARGA',
              NoticeDuration.untilDismissed: 'HASTA CERRAR',
            },
            value: s.noticeDuration,
            onChanged: (v) => c.update(s.copyWith(noticeDuration: v)),
          ),
        ),
        _SettingRow(
          label: 'FONDO DEL TEXTO EN EL MAPA',
          hint: 'Detrás de nombres, carteles, avisos y loot del piso, para '
              'leerlos sobre tiles cargados.',
          control: _Choice<MapLabelBackdrop>(
            keyPrefix: 'a11y-maplabels',
            options: const {
              MapLabelBackdrop.none: 'NINGUNO',
              MapLabelBackdrop.shaded: 'SOMBREADO',
              MapLabelBackdrop.box: 'CAJA OPACA',
            },
            value: s.mapLabelBackdrop,
            onChanged: (v) => c.update(s.copyWith(mapLabelBackdrop: v)),
          ),
        ),
        _SettingRow(
          label: 'REGISTRO DE BATALLA',
          hint: s.battleLog == BattleLogMode.extended
              ? 'EXTENDIDO: las 3 últimas líneas arriba de la escena; cada '
                  'una queda más tiempo.'
              : 'Una línea arriba de la escena que se reemplaza con cada '
                  'acción.',
          control: _Choice<BattleLogMode>(
            keyPrefix: 'a11y-battlelog',
            options: const {
              BattleLogMode.normal: 'NORMAL',
              BattleLogMode.extended: 'EXTENDIDO',
            },
            value: s.battleLog,
            onChanged: (v) => c.update(s.copyWith(battleLog: v)),
          ),
        ),
        _TextPreview(settings: s),
        const _SectionHeader('COLOR Y MOVIMIENTO'),
        _SettingRow(
          label: 'MODO DALTÓNICO',
          hint: _visionHint(s.colorVision),
          control: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Choice<ColorVision>(
                keyPrefix: 'a11y-vision',
                options: const {
                  ColorVision.off: 'NO',
                  ColorVision.deuteranopia: 'DEUTERANOPÍA',
                  ColorVision.protanopia: 'PROTANOPÍA',
                  ColorVision.tritanopia: 'TRITANOPÍA',
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
          label: 'REDUCIR MOVIMIENTO',
          hint: still
              ? 'Sin sacudida, sin parpadeos, sin zoom de cámara en las '
                  'ULT, arena quieta y fundido corto al entrar y salir de '
                  'la batalla. Destellos a lo sumo SUAVES.'
              : 'Apaga la sacudida, los parpadeos y el zoom de las ULT, '
                  'y suaviza los destellos y las transiciones.',
          control: _Choice<bool>(
            keyPrefix: 'a11y-motion',
            options: _yesNo,
            value: s.reduceMotion,
            onChanged: (v) => c.update(s.copyWith(reduceMotion: v)),
          ),
        ),
        _SettingRow(
          label: 'SACUDIDA',
          hint: still
              ? 'Apagada por REDUCIR MOVIMIENTO.'
              : 'La escena de batalla tiembla con los golpes fuertes.',
          control: _Choice<bool>(
            keyPrefix: 'display-shake',
            options: _yesNo,
            value: s.shakeOn,
            onChanged:
                still ? null : (v) => c.update(s.copyWith(screenShake: v)),
          ),
        ),
        _SettingRow(
          label: 'DESTELLOS',
          hint: 'Destellos de pantalla completa (rojo al recibir un golpe '
              'fuerte, blanco en golpes brutales, ULT y ascensión). '
              '${still ? 'Con REDUCIR MOVIMIENTO, a lo sumo SUAVES.' : 'SUAVES o NO si molestan.'}',
          control: _Choice<FlashLevel>(
            keyPrefix: 'display-flashes',
            options: const {
              FlashLevel.normal: 'NORMALES',
              FlashLevel.reduced: 'SUAVES',
              FlashLevel.off: 'NO',
            },
            value: still && s.flashes == FlashLevel.normal
                ? FlashLevel.reduced
                : s.flashes,
            onChanged: (v) => c.update(s.copyWith(flashes: v)),
          ),
        ),
      ],
    );
  }

  static String _visionHint(ColorVision v) => switch (v) {
        ColorVision.off => 'Colores para verde / rojo (deuteranopía, '
            'protanopía) o azul / amarillo (tritanopía). Las flechas ▲ ▼ y '
            'las letras de rareza siguen siempre.',
        ColorVision.deuteranopia => 'Verde / rojo: mejora en azul y '
            'empeora en ámbar; HP azul y MP amarillo; quiebre celeste.',
        ColorVision.protanopia => 'Rojo: como deuteranopía, sin rojos '
            '(se ven oscuros): lo malo en ámbar claro.',
        ColorVision.tritanopia => 'Azul / amarillo: mejora en turquesa y '
            'empeora en rojo; HP turquesa y MP magenta; Raro rosado.',
      };
}

/// Encabezado de un grupo de ajustes (`TEXTO`, `COLOR Y MOVIMIENTO`): en
/// la fuente de títulos, con una línea del borde del tema debajo.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: UiTheme.space(10), bottom: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(retroText(text),
                style: RetroType.titleStyle(RetroType.label,
                    color: ProtoColors.title)),
            const SizedBox(height: 4),
            Container(height: 1, color: ProtoColors.panelBorder),
          ],
        ),
      );
}

/// Vista previa en vivo de la sección TEXTO (accessibility.md § 9): un
/// tip con título y lectura (fuente, títulos, tamaño, espaciado), un
/// botón, una etiqueta del mapa sobre tiles cargados con su fondo, un
/// aviso (con su × en HASTA CERRAR) y, en EXTENDIDO, el registro de
/// batalla. Sin foco ni clics.
class _TextPreview extends StatelessWidget {
  const _TextPreview({required this.settings});

  final GameSettings settings;

  @override
  Widget build(BuildContext context) {
    final s = settings;
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
                    Text(retroText('ESPADA DEL ALBA'),
                        key: const ValueKey('a11y-text-preview-title'),
                        style: RetroType.style(RetroType.label,
                            color: ProtoColors.title)),
                    const SizedBox(height: 4),
                    DefaultTextStyle(
                      style: RetroHoverCard.textStyle,
                      child: RetroTipText(
                          'Tus curas otorgan <b>Sagrado</b> 2 turnos.<br>'
                          '<span class="k">Il1 · O0 · rn m</span>',
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
                    child: const Text('EQUIPAR'),
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
                          NoticeDuration.normal => '+ Poción · 3 s',
                          NoticeDuration.long => '+ Poción · 6 s',
                          NoticeDuration.untilDismissed => '+ Poción',
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
                      child: const BattleLogHistory(lines: [
                        'Ana usa Corte: 24 de daño',
                        'Slime ataca a Ana: 6',
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
        swatch('▲ mejora', ProtoColors.green),
        swatch('▼ empeora', ProtoColors.red),
        swatch('HP', ProtoColors.hp, ink: ProtoColors.bg),
        swatch('MP', ProtoColors.mp, ink: ProtoColors.bg),
        for (final (l, col) in rarities) swatch(l, col),
        swatch('VIDA', const VisionColor(VisionSlot.enemyHp),
            ink: ProtoColors.bg),
        swatch('◆ QUIEBRE', const VisionColor(VisionSlot.breakBar),
            ink: ProtoColors.bg),
      ],
    );
  }
}

/// Vista previa del tema, los colores del texto y el espaciado: un tip de
/// nodo del árbol como los del juego y dos filas de menú.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview();

  static const tip = '<b>Paladín Creyente</b><br>'
      '<span class="k">KEYSTONE · Cluster Fe: curación y regeneración</span><br>'
      'Tus curas también otorgan <span style="color:#fff3b0">Sagrado</span> '
      '2 turnos; −15% de daño físico.<br>'
      '<span class="k">Costo:</span> <b>9 puntos</b><br>'
      '<span style="color:#ff6b81">Necesita un nodo conectado</span>';

  @override
  Widget build(BuildContext context) {
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
                        label: '<b>Reforjar</b>',
                        value: '<span style="color:#7bed9f">1 Esquirla</span>',
                        selected: true,
                        onTap: () {}),
                    MenuRow(
                        label: 'Subir rareza',
                        value:
                            '<span style="color:#ff6b81">Falta Prisma</span>',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingRow(
          label: 'NÚMEROS FLOTANTES',
          hint: 'Daño y curas flotando sobre cada personaje.',
          control: _Choice<bool>(
            keyPrefix: 'game-numbers',
            options: _yesNo,
            value: s.damageNumbers,
            onChanged: (v) => c.update(s.copyWith(damageNumbers: v)),
          ),
        ),
        _SettingRow(
          label: 'TIEMPO DE TURNO',
          hint: 'Cuánto espera la batalla a que elijas. En multijugador '
              'vale el del anfitrión de la sala.',
          control: _Choice<TurnTimer>(
            keyPrefix: 'game-turn',
            options: const {
              TurnTimer.normal: 'NORMAL (30 S)',
              TurnTimer.long: 'LARGO (60 S)',
              TurnTimer.unlimited: 'SIN LÍMITE',
            },
            value: s.turnTimer,
            onChanged: (v) => c.update(s.copyWith(turnTimer: v)),
          ),
        ),
        _SettingRow(
          label: 'CONFIRMAR AL TIRAR',
          hint: 'Pregunta antes de tirar un objeto al piso. Vender y '
              'desarmar siempre preguntan.',
          control: _Choice<bool>(
            keyPrefix: 'game-confirm-drop',
            options: _yesNo,
            value: s.confirmDrop,
            onChanged: (v) => c.update(s.copyWith(confirmDrop: v)),
          ),
        ),
        _SettingRow(
          label: 'AVISOS DE BUILD',
          hint: 'Cartel y línea en el chat cuando avanza una meta de tu '
              'plan de build (pestaña BUILD del personaje).',
          control: _Choice<bool>(
            keyPrefix: 'game-build-notices',
            options: _yesNo,
            value: s.buildNotices,
            onChanged: (v) => c.update(s.copyWith(buildNotices: v)),
          ),
        ),
        // HUD v0.8.1 (exploration.md § "Chat").
        _SettingRow(
          label: 'CHAT',
          hint: 'OCULTO: una píldora CHAT [ENTER] con los mensajes nuevos; '
              'Enter o clic lo abre.',
          control: _Choice<ChatVisibility>(
            keyPrefix: 'game-chat',
            options: const {
              ChatVisibility.hidden: 'OCULTO',
              ChatVisibility.always: 'SIEMPRE VISIBLE',
            },
            value: s.chat,
            onChanged: (v) => c.update(s.copyWith(chat: v)),
          ),
        ),
        _SettingRow(
          label: 'AVISOS DEL CHAT',
          hint: 'Con el chat oculto, los avisos importantes (misión '
              'aceptada, piso despejado, subida de nivel) aparecen 4 s.',
          control: _Choice<bool>(
            keyPrefix: 'game-chat-notices',
            options: _yesNo,
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

  static const sections = <(String, List<(String, String)>)>[
    (
      'MAPA',
      [
        ('WASD / Flechas', 'Moverse'),
        ('E / Espacio', 'Interactuar, levantar loot'),
        ('Alt (mantener)', 'Ver también el loot oculto por el filtro'),
        ('C', 'Personaje'),
        ('I', 'Inventario'),
        ('J', 'Plegar / desplegar los objetivos'),
        ('Retroceso', 'Cerrar todos los avisos del HUD'),
        ('M', 'Mapa en grande (flechas / arrastrar: mover; + - / rueda: zoom)'),
        ('Rueda sobre el minimapa', 'Zoom del minimapa'),
        ('Y / N', 'Votar la misión propuesta'),
      ]
    ),
    (
      'BATALLA',
      [
        ('1 - 9 / clic', 'Elegir la acción N del menú'),
        ('Q / Tab / clic', 'Cambiar de objetivo'),
        ('Esc', 'Volver del submenú de pociones'),
      ]
    ),
    (
      'MENÚS',
      // Mapa de teclas de los menús (lib/app/widgets/menu_focus.dart).
      kMenuKeys
    ),
    (
      'CHAT',
      [
        ('Enter', 'Abrir el chat / mandar (vacío: cerrar)'),
        ('Esc', 'Cerrar el chat sin mandar'),
      ]
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('settings-controls'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (title, keys) in sections)
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
