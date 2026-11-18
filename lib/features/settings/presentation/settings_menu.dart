import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../core/audio/presentation/audio_providers.dart';
import '../../../core/settings/game_settings.dart';
import '../../../core/settings/settings_providers.dart';

/// Pestañas del menú (docs/specs/settings.md § "Estructura").
enum SettingsTab {
  sound('SONIDO', 'Volumen general, de la música y de los efectos.'),
  display('PANTALLA', 'Ventana, gráficos y efectos de la batalla.'),
  game('JUEGO', 'Números de daño y avisos.'),
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
    return Material(
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
            SettingsTab.game => const _GameTab(),
            SettingsTab.controls => const _ControlsTab(),
          };
        }),
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
 fontFamilyFallback: RetroType.bodyFallback, fontSize: RetroType.small,
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
          accent: ProtoColors.red,
          onPressed: () {
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
      barrierColor: const Color(0x990B0E1A),
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
  const _SettingRow(
      {required this.label, required this.control, this.hint});

  final String label;
  final Widget control;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in options.entries)
          PanelButton(e.value,
              key: ValueKey('$keyPrefix-${e.value}'),
              selected: e.key == value,
              accent: e.key == value ? ProtoColors.gold : null,
              onPressed: () => onChanged(e.key)),
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
            child: Slider(
              key: sliderKey,
              value: value,
              divisions: 20,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ),
        SizedBox(
          // "100%" en una línea con cualquier tamaño de texto.
          width: RetroType.width(context, 48),
          child: Text('${(value * 100).round()}%',
              maxLines: 1,
              textAlign: TextAlign.right, style: TextStyle(color: color)),
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
        // Accesibilidad: primero (docs/specs/settings.md § 3).
        _SettingRow(
          label: 'TAMAÑO DEL TEXTO',
          hint: 'Letra de menús, fichas, chat y batalla. Se ajusta a la '
              'grilla de la fuente para que se vea nítida.',
          control: _Choice<TextSize>(
            keyPrefix: 'display-text',
            options: const {
              TextSize.normal: 'NORMAL',
              TextSize.large: 'GRANDE',
              TextSize.huge: 'MUY GRANDE',
            },
            value: s.textSize,
            onChanged: (v) => c.update(s.copyWith(textSize: v)),
          ),
        ),
        _SettingRow(
          label: 'FUENTE DE LECTURA',
          hint: 'Fichas, chat, menús y batalla. Títulos y botones no '
              'cambian.',
          control: _FontChoice(
            value: s.readingFont,
            onChanged: (v) => c.update(s.copyWith(readingFont: v)),
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
        _SettingRow(
          label: 'SACUDIDA',
          hint: 'La escena de batalla tiembla con los golpes fuertes.',
          control: _Choice<bool>(
            keyPrefix: 'display-shake',
            options: _yesNo,
            value: s.screenShake,
            onChanged: (v) => c.update(s.copyWith(screenShake: v)),
          ),
        ),
        _SettingRow(
          label: 'DESTELLOS',
          hint: 'Destellos de pantalla completa (rojo al recibir un golpe '
              'fuerte, blanco en golpes brutales). SUAVES o NO si molestan.',
          control: _Choice<FlashLevel>(
            keyPrefix: 'display-flashes',
            options: const {
              FlashLevel.normal: 'NORMALES',
              FlashLevel.reduced: 'SUAVES',
              FlashLevel.off: 'NO',
            },
            value: s.flashes,
            onChanged: (v) => c.update(s.copyWith(flashes: v)),
          ),
        ),
      ],
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
      ],
    );
  }
}

/// Las teclas, de solo lectura (docs/specs/exploration.md § "Teclado").
class _ControlsTab extends StatelessWidget {
  const _ControlsTab();

  static const sections = <(String, List<(String, String)>)>[
    ('MAPA', [
      ('WASD / Flechas', 'Moverse'),
      ('E / Espacio', 'Interactuar, levantar loot'),
      ('Alt (mantener)', 'Ver también el loot oculto por el filtro'),
      ('C', 'Personaje'),
      ('I', 'Inventario'),
      ('Y / N', 'Votar la misión propuesta'),
    ]),
    ('BATALLA', [
      ('1 - 9 / clic', 'Elegir la acción N del menú'),
      ('Q / Tab / clic', 'Cambiar de objetivo'),
      ('Esc', 'Volver del submenú de pociones'),
    ]),
    ('MENÚS', [
      ('Esc', 'Cerrar el panel; sin panel abre esta pausa'),
      ('Tab / Flechas', 'Mover el foco'),
      ('Enter / Espacio', 'Elegir'),
    ]),
    ('CHAT', [
      ('Enter', 'Escribir / mandar'),
      ('Esc', 'Salir sin mandar'),
    ]),
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
