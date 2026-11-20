import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_panel.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/class_def.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../ascension/domain/ascension_text.dart';
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

  static TextStyle get _style => TextStyle(
      fontFamily: RetroType.bodyFamily,
      letterSpacing: RetroType.letterSpacing,
      fontFamilyFallback: RetroType.bodyFallback,
      fontSize: RetroType.small,
      color: RetroPalette.ink);

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
    this.onKeyActivate,
  });

  static const width = 252.0;

  /// `Enter` sobre la tarjeta (el título: elegir o, si ya está elegida,
  /// jugar).
  final VoidCallback? onKeyActivate;

  /// Ancho con el texto actual: crece con el texto pero siempre entran 4
  /// por fila a 1280 px.
  static double widthOf(BuildContext context) =>
      RetroType.width(context, width).clamp(width, 300.0);

  final CharacterSlot slot;

  /// El perfil ya normalizado (nivel y zona válidos).
  final PlayerProfile profile;
  final String className;
  final bool selected;
  final GameSprites? sprites;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Ascendido: su sprite y su título (docs/specs/ascension.md § 5).
    final asc = ascensionFor(profile.classId, profile.ascension.id);
    final img = sprites?.heroFor(profile.classId, asc?.id);
    // Una línea por dato (se cortan con "…"): con texto grande la tarjeta
    // crece en alto sin partir palabras.
    final small = DsText.detail();
    Widget line(String t, {TextStyle? style, Key? key}) => Text(retroText(t),
        key: key, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    return MenuFocusable(
      key: ValueKey('char-slot-${slot.id}'),
      onTap: onTap,
      onKeyActivate: onKeyActivate,
      builder: (context, hot) => SizedBox(
        width: widthOf(context),
        // Tarjeta del sistema (design_system.md § 6): sin borde, elegida
        // con borde dorado, hover / foco con fondo.
        child: DsCard(
          selected: selected,
          hot: hot,
          padding: EdgeInsets.all(DsSpace.sm),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsText.subtitle(selected
                            ? DsColors.selected
                            : DsColors.textPrimary)),
                    const SizedBox(height: 4),
                    if (asc != null)
                      line(asc.name,
                          key: ValueKey('char-asc-${slot.id}'),
                          style: TextStyle(color: Color(asc.color))),
                    line('$className · Nv ${profile.level}',
                        style: DsText.body(DsColors.textPrimary)),
                    line('Zona ${profile.unlockedZone}', style: small),
                    line(lastPlayedText(slot.lastPlayed), style: small),
                  ],
                ),
              ),
            ],
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
  Widget build(BuildContext context) => MenuFocusable(
        key: const ValueKey('char-new'),
        onTap: onTap,
        builder: (context, hot) => SizedBox(
          width: CharacterSlotCard.widthOf(context),
          height: RetroType.width(context, 90),
          child: DsCard(
            hot: hot,
            padding: EdgeInsets.all(DsSpace.sm),
            child: Center(
              child: Text('+ NUEVO PERSONAJE', style: DsText.subtitle()),
            ),
          ),

        ),
      );
}

/// Tarjeta de clase del creador: sprite, nombre y arma inicial (el
/// detalle completo va al costado, `ClassDetail`). Elegida = borde
/// dorado; con el cursor del teclado (flechas) se elige sola.
class ClassCard extends StatelessWidget {
  const ClassCard({
    super.key,
    required this.def,
    required this.weaponName,
    required this.selected,
    required this.sprites,
    required this.onTap,
    this.index,
  });

  final ClassDef def;
  final String weaponName;
  final bool selected;
  final GameSprites? sprites;
  final VoidCallback onTap;

  /// Atajo de teclado (`1`..`9`) que se muestra en la esquina.
  final int? index;

  static const width = 210.0;

  @override
  Widget build(BuildContext context) {
    final img = sprites?.hero(def.id);
    return MenuFocusable(
      key: ValueKey('class-card-${def.id}'),
      onTap: onTap,
      onFocus: onTap,
      builder: (context, hot) => SizedBox(
        width: RetroType.width(context, width),
        child: RetroPanel(
          selected: selected,
          borderColor: selected || !hot ? null : ProtoColors.sky,
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: img == null
                    ? null
                    : Center(child: PixelSprite(img, scale: 3)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(retroText(def.name),
                        style: TextStyle(
                            fontFamily: RetroType.titleFamily,
                            fontSize: RetroType.label,
                            height: RetroType.titleLine,
                            color: selected
                                ? RetroPalette.gold
                                : RetroPalette.ink)),
                    Text(retroText(weaponName),
                        style: const TextStyle(color: RetroPalette.muted)),
                    if (index != null)
                      Text('[$index]',
                          style: const TextStyle(color: ProtoColors.dim)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detalle de la clase elegida en el creador: descripción entera,
/// atributos base en barras y el arma inicial con sus habilidades.
class ClassDetail extends StatelessWidget {
  const ClassDetail({
    super.key,
    required this.def,
    required this.weaponName,
    this.skills,
  });

  final ClassDef def;
  final String weaponName;

  /// Las habilidades del arma inicial (chips con su ficha).
  final Widget? skills;

  @override
  Widget build(BuildContext context) {
    final top = Attribute.values
        .map((a) => def.baseAttributes[a] ?? 0)
        .fold(1, (m, v) => v > m ? v : m);
    return Column(
      key: const ValueKey('class-detail'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(retroText(def.name.toUpperCase()),
            style: TextStyle(
                fontFamily: RetroType.titleFamily,
                fontSize: RetroType.title,
                color: RetroPalette.gold)),
        const SizedBox(height: 6),
        Text(retroText(def.description)),
        const SizedBox(height: 10),
        const Text('ATRIBUTOS BASE', style: TextStyle(color: ProtoColors.sky)),
        for (final a in Attribute.values)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                SizedBox(
                  width: RetroType.em(context, 5, size: RetroType.small),
                  child: Text(a.name.toUpperCase()),
                ),
                SizedBox(
                  width: RetroType.em(context, 4, size: RetroType.small),
                  child: Text('${def.baseAttributes[a] ?? 0}',
                      style: const TextStyle(color: ProtoColors.gold)),
                ),
                Expanded(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (def.baseAttributes[a] ?? 0) / top,
                    child: Container(height: 8, color: ProtoColors.gold),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        ProtoText('<span class="k">Arma inicial:</span> '
            '<b>${protoEsc(weaponName)}</b>'),
        if (skills != null) ...[const SizedBox(height: 4), skills!],
      ],
    );
  }
}

Future<T?> _panelDialog<T>(BuildContext context, WidgetBuilder builder) =>
    showDialog<T>(
      context: context,
      barrierColor: ProtoColors.scrim(0.6),
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
