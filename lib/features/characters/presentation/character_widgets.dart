import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_panel.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/class_def.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../combat/presentation/game_sprites.dart';
import '../../combat/presentation/pixel_sprite.dart';
import '../domain/account.dart';

/// Piezas de la selección de personaje (docs/specs/characters.md § 2).

/// `Jugado: DD/MM/AAAA` o `Nunca jugado`.
String lastPlayedText(DateTime? t) {
  if (t == null) return 'Nunca jugado';
  String two(int n) => n.toString().padLeft(2, '0');
  return 'Jugado: ${two(t.day)}/${two(t.month)}/${t.year}';
}

/// Campo de texto con la fuente pixel (nombre, confirmación).
class RetroTextField extends StatelessWidget {
  const RetroTextField({
    super.key,
    required this.controller,
    this.hint,
    this.maxLength,
    this.onSubmitted,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? hint;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  static const _style = TextStyle(
      fontFamily: RetroTheme.fontFamily, fontSize: 8, color: RetroPalette.ink);

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        autofocus: autofocus,
        maxLength: maxLength,
        maxLengthEnforcement:
            maxLength == null ? null : MaxLengthEnforcement.enforced,
        style: _style,
        cursorColor: RetroPalette.gold,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        decoration: InputDecoration(
          isDense: true,
          counterText: '',
          hintText: hint,
          hintStyle: _style.copyWith(color: RetroPalette.muted),
          contentPadding: const EdgeInsets.all(8),
        ),
      );
}

/// Tarjeta de un personaje: sprite `idle` de su clase, nombre, clase y
/// nivel, zona y última partida. Elegido = borde dorado.
class CharacterSlotCard extends StatelessWidget {
  const CharacterSlotCard({
    super.key,
    required this.slot,
    required this.profile,
    required this.className,
    required this.selected,
    required this.sprites,
    required this.onTap,
  });

  static const width = 252.0;

  final CharacterSlot slot;

  /// El perfil ya normalizado (nivel y zona válidos).
  final PlayerProfile profile;
  final String className;
  final bool selected;
  final GameSprites? sprites;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final img = sprites?.hero(profile.classId);
    const small = TextStyle(color: RetroPalette.muted, height: 1.8);
    return GestureDetector(
      key: ValueKey('char-slot-${slot.id}'),
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: width,
          child: RetroPanel(
            selected: selected,
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: img == null
                      ? null
                      : Center(child: PixelSprite(img, scale: 3)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(retroText(slot.displayName),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: selected
                                  ? RetroPalette.gold
                                  : RetroPalette.ink)),
                      const SizedBox(height: 8),
                      Text(retroText('$className · Nv ${profile.level}'),
                          style: const TextStyle(height: 1.8)),
                      Text('Zona ${profile.unlockedZone}', style: small),
                      Text(retroText(lastPlayedText(slot.lastPlayed)),
                          style: small),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `+ NUEVO PERSONAJE`: abre el creador.
class NewCharacterCard extends StatelessWidget {
  const NewCharacterCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const ValueKey('char-new'),
        onTap: onTap,
        child: const MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SizedBox(
            width: CharacterSlotCard.width,
            height: 90,
            child: RetroPanel(
              borderColor: ProtoColors.panelBorder,
              padding: EdgeInsets.all(10),
              child: Center(
                child: Text('+ NUEVO PERSONAJE',
                    style: TextStyle(color: RetroPalette.muted)),
              ),
            ),
          ),
        ),
      );
}

/// Tarjeta de clase (`.card`): sprite, nombre, descripción, atributos
/// base y arma inicial. Elegida = borde dorado.
class ClassCard extends StatelessWidget {
  const ClassCard({
    super.key,
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
                        color:
                            selected ? RetroPalette.gold : RetroPalette.ink)),
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

Future<T?> _panelDialog<T>(BuildContext context, WidgetBuilder builder) =>
    showDialog<T>(
      context: context,
      barrierColor: const Color(0x990B0E1A),
      builder: (ctx) =>
          Material(type: MaterialType.transparency, child: builder(ctx)),
    );

/// Diálogo RENOMBRAR: el nombre nuevo, o `null` si se cancela.
Future<String?> showRenameDialog(BuildContext context, CharacterSlot slot) =>
    _panelDialog<String>(context, (_) => _RenameDialog(slot));

class _RenameDialog extends StatefulWidget {
  const _RenameDialog(this.slot);
  final CharacterSlot slot;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _name = TextEditingController(text: widget.slot.profile.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _ok() => Navigator.of(context).pop(CharacterRules.cleanName(_name.text));

  @override
  Widget build(BuildContext context) => PanelFrame(
        key: const ValueKey('char-rename-dialog'),
        title: 'RENOMBRAR',
        width: 420,
        onClose: () => Navigator.of(context).pop(),
        actions: [
          PanelButton('CANCELAR',
              key: const ValueKey('char-rename-cancel'),
              onPressed: () => Navigator.of(context).pop()),
          PanelButton('GUARDAR',
              key: const ValueKey('char-rename-ok'), onPressed: _ok),
        ],
        child: Row(
          children: [
            const Text('Nombre:'),
            const SizedBox(width: 8),
            Expanded(
              child: RetroTextField(
                key: const ValueKey('char-rename-field'),
                controller: _name,
                autofocus: true,
                hint: Account.defaultName,
                maxLength: ProgressionRules.maxNameLength,
                onSubmitted: (_) => _ok(),
              ),
            ),
          ],
        ),
      );
}

/// Diálogo BORRAR PERSONAJE: `true` solo si se escribió el nombre y se
/// confirmó.
Future<bool> showDeleteDialog(
        BuildContext context, CharacterSlot slot, String className) async =>
    await _panelDialog<bool>(
        context, (_) => _DeleteDialog(slot: slot, className: className)) ??
    false;

class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({required this.slot, required this.className});
  final CharacterSlot slot;
  final String className;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  bool get _ok => CharacterRules.confirmsDelete(widget.slot, _typed.text);

  @override
  Widget build(BuildContext context) {
    final name = widget.slot.displayName;
    return PanelFrame(
      key: const ValueKey('char-delete-dialog'),
      title: 'BORRAR PERSONAJE',
      width: 560,
      onClose: () => Navigator.of(context).pop(false),
      actions: [
        PanelButton('CANCELAR',
            key: const ValueKey('char-delete-cancel'),
            onPressed: () => Navigator.of(context).pop(false)),
        PanelButton('BORRAR',
            key: const ValueKey('char-delete-ok'),
            accent: ProtoColors.red,
            onPressed: _ok ? () => Navigator.of(context).pop(true) : null),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProtoText(
              'Vas a borrar a <b>${protoEsc(retroText(name))}</b> '
              '(${protoEsc(retroText(widget.className))}, nivel '
              '${widget.slot.profile.level}). No se puede deshacer.',
              boldColor: ProtoColors.gold),
          const SizedBox(height: 8),
          const Text(
              'Sus armas, materiales, pociones y créditos se pierden. Si '
              'quieres conservar algo, pásalo antes al ALIJO.',
              style: TextStyle(color: ProtoColors.red)),
          const SizedBox(height: 12),
          Text(retroText('Escribe "$name" para confirmar:'),
              style: const TextStyle(color: ProtoColors.dim)),
          const SizedBox(height: 8),
          RetroTextField(
            key: const ValueKey('char-delete-field'),
            controller: _typed,
            autofocus: true,
            hint: retroText(name),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (_ok) Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
    );
  }
}
