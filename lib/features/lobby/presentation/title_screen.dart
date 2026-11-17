import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/feature_flags.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/retro_panel.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/class_def.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../combat/presentation/game_sprites.dart';
import '../../combat/presentation/pixel_sprite.dart';
import '../../world/presentation/session_controller.dart';
import '../../world/presentation/world_screen.dart';

/// Pantalla de título (prototipo, HTML líneas 70-83 y `title()` desde la
/// línea 1471): nombre, elección de clase y entrada al juego. Crear sala
/// / unirse por código son P2P (próxima fase) y se muestran
/// deshabilitados. Ver docs/specs/exploration.md § "Título".
class TitleScreen extends ConsumerStatefulWidget {
  const TitleScreen({super.key, this.onStart});

  /// Qué hacer al comenzar, con el perfil ya guardado (por defecto,
  /// abrir `WorldScreen`).
  final VoidCallback? onStart;

  @override
  ConsumerState<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends ConsumerState<TitleScreen> {
  final _name = TextEditingController();
  PlayerProfile? _profile;
  bool _busy = false;
  late final Future<void> _loading;

  ProgressionRules get _rules => ref.read(sessionEngineProvider).progression;

  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// `loadProfile` + `$('#iname').value = profile.name`.
  Future<void> _load() async {
    PlayerProfile? p;
    try {
      p = await ref.read(profileStoreProvider).load();
    } catch (_) {
      p = null;
    }
    if (!mounted) return;
    final profile = _rules.normalize(p ??
        PlayerProfile(classId: SessionController.defaultClass));
    setState(() {
      _profile = profile;
      _name.text = profile.name;
    });
  }

  /// Clic en una tarjeta: `profile.cls = k; profile.eq = start;
  /// resetBuild(profile)` (el árbol lo limpia `normalize` al entrar).
  void _pickClass(ClassDef c) {
    final p = _profile;
    if (p == null || p.classId == c.id) return;
    setState(() {
      _profile = _rules.resetBuild(
          p.copyWith(classId: c.id, equipped: c.startWeaponId));
    });
  }

  /// `prep()`: nombre recortado (vacío → "Héroe"), guardar y entrar.
  Future<void> _start() async {
    if (_busy) return;
    // Se puede tocar antes de que termine de cargar el perfil.
    await _loading;
    final p = _profile;
    if (p == null || !mounted) return;
    var name = _name.text.trim();
    if (name.isEmpty) name = SessionController.defaultName;
    if (name.length > ProgressionRules.maxNameLength) {
      name = name.substring(0, ProgressionRules.maxNameLength);
    }
    final next = p.copyWith(name: name);
    setState(() {
      _busy = true;
      _profile = next;
    });
    try {
      await ref.read(profileStoreProvider).save(next);
    } catch (_) {
      // Sin disco se juega igual (el controlador vuelve a intentar).
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final onStart = widget.onStart;
    if (onStart != null) {
      onStart();
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const WorldScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = _profile;
    final classes = _rules.catalog.classes.values
        .where((c) => FeatureFlags.instance.isCharacterAllowed(c.id))
        .toList();
    final sprites = ref.watch(gameSpritesProvider).valueOrNull;
    return Scaffold(
      body: Center(
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
                        Shadow(
                            color: RetroPalette.red, offset: Offset(4, 4)),
                      ],
                    )),
                const SizedBox(height: 16),
                Text(
                  retroText('Co-op JRPG táctico · 1-4 jugadores'
                      '${p != null && p.level > 1 ? ' · Tu nivel guardado: ${p.level}' : ''}'),
                  style: const TextStyle(color: RetroPalette.muted),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Nombre:'),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 200,
                      child: TextField(
                        key: const ValueKey('title-name'),
                        controller: _name,
                        maxLength: ProgressionRules.maxNameLength,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        style: const TextStyle(
                            fontFamily: RetroTheme.fontFamily,
                            fontSize: 8,
                            color: RetroPalette.ink),
                        cursorColor: RetroPalette.gold,
                        onSubmitted: (_) => _start(),
                        decoration: const InputDecoration(
                          isDense: true,
                          counterText: '',
                          hintText: 'Héroe',
                          hintStyle: TextStyle(
                              fontFamily: RetroTheme.fontFamily,
                              fontSize: 8,
                              color: RetroPalette.muted),
                          contentPadding: EdgeInsets.all(8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final c in classes)
                      _ClassCard(
                        def: c,
                        weaponName:
                            _rules.catalog.weapons[c.startWeaponId]?.name ?? '',
                        selected: p?.classId == c.id,
                        sprites: sprites,
                        onTap: () => _pickClass(c),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  key: const ValueKey('title-start'),
                  onPressed: _busy ? null : _start,
                  child: const Text('> COMENZAR'),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const PanelButton('CREAR SALA'),
                    const Text('o', style: TextStyle(color: RetroPalette.muted)),
                    const SizedBox(
                      width: 110,
                      child: TextField(
                        enabled: false,
                        style: TextStyle(
                            fontFamily: RetroTheme.fontFamily, fontSize: 8),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'CODIGO',
                          hintStyle: TextStyle(
                              fontFamily: RetroTheme.fontFamily,
                              fontSize: 8,
                              color: RetroPalette.muted),
                          contentPadding: EdgeInsets.all(8),
                        ),
                      ),
                    ),
                    const PanelButton('UNIRSE'),
                    Text(retroText('P2P: próximamente'),
                        key: const ValueKey('title-p2p'),
                        style: const TextStyle(color: RetroPalette.muted)),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Mover: WASD/Flechas · Interactuar: E/Espacio · Combate por '
                  'turnos: 1-9 o clic · Cambiar objetivo: Q o clic en enemigo · '
                  'Chat: Enter',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: RetroPalette.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de clase (`.card`): sprite, nombre, descripción, atributos
/// base y arma inicial. Elegida = borde dorado.
class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.def,
    required this.weaponName,
    required this.selected,
    required this.sprites,
    required this.onTap,
  });

  final ClassDef def;
  final String weaponName;
  final bool selected;
  final GameSprites? sprites;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final img = sprites?.hero(def.id);
    const small = TextStyle(color: RetroPalette.muted, height: 1.8);
    return GestureDetector(
      key: ValueKey('class-card-${def.id}'),
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: 200,
          child: RetroPanel(
            selected: selected,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SizedBox(
                  height: 72,
                  child: img == null
                      ? null
                      : Center(child: PixelSprite(img, scale: 4)),
                ),
                const SizedBox(height: 8),
                Text(retroText(def.name),
                    style: TextStyle(
                        fontSize: 16,
                        color: selected ? RetroPalette.gold : RetroPalette.ink)),
                const SizedBox(height: 8),
                // Alturas fijas: todas las tarjetas miden lo mismo.
                SizedBox(
                  height: 48,
                  child: Text(retroText(def.description),
                      textAlign: TextAlign.center, style: small),
                ),
                const SizedBox(height: 4),
                Text(
                  Attribute.values
                      .map((a) =>
                          '${a.name.toUpperCase()} ${def.baseAttributes[a] ?? 0}')
                      .join(' '),
                  textAlign: TextAlign.center,
                  style: small,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 32,
                  child: Text(retroText('Arma: $weaponName'),
                      textAlign: TextAlign.center, style: small),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
