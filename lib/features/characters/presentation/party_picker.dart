import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_text.dart';
import '../domain/account.dart';

/// Un personaje que puede ir de compañero (docs/specs/solo_party.md § 2).
class PartyCandidate {
  const PartyCandidate({
    required this.id,
    required this.name,
    required this.className,
    required this.level,
  });

  /// Id de la ranura de la cuenta (`c2`).
  final String id;
  final String name;
  final String className;
  final int level;

  /// `Leo · Mago · Nv 12`.
  String get label => '$name · $className · Nv $level';
}

/// Selector de la party jugando solo: `PARTY: tú + N` y un botón por cada
/// otro personaje de la cuenta (marcado = va). Con [onAuto], los que van
/// muestran además su AUTO. Lo usan el título y el panel PARTY del pueblo
/// (solo_party.md § 2.2 y § 2.3). Teclado: los botones son focusables
/// (Tab / flechas, Enter).
class PartyPicker extends StatelessWidget {
  const PartyPicker({
    super.key,
    required this.candidates,
    required this.selected,
    required this.onChanged,
    this.auto = const {},
    this.onAuto,
    this.enabled = true,
  });

  final List<PartyCandidate> candidates;

  /// Ids de ranura que van, en orden.
  final List<String> selected;
  final ValueChanged<List<String>>? onChanged;

  /// Ids de ranura con AUTO prendido.
  final Set<String> auto;

  /// Cambia el AUTO de una ranura; `null` = no se muestra.
  final void Function(String slotId, bool on)? onAuto;
  final bool enabled;

  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final full = selected.length >= Account.maxCompanions;
    final byId = {for (final c in candidates) c.id: c};
    const muted = TextStyle(color: ProtoColors.dim);
    return Column(
      key: const ValueKey('party-picker'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('PARTY: tú + ${selected.length}',
            key: const ValueKey('party-count'),
            style: const TextStyle(color: ProtoColors.gold)),
        const SizedBox(height: 4),
        Text(
            retroText(candidates.isEmpty
                ? 'Crea otro personaje para llevarlo de compañero.'
                : 'Hasta ${Account.maxCompanions} compañeros. En batalla '
                    'eliges su acción en su turno; con AUTO actúan solos.'),
            textAlign: TextAlign.center,
            style: muted),
        if (candidates.isNotEmpty) ...[
          const SizedBox(height: _gap),
          Wrap(
            spacing: _gap,
            runSpacing: _gap,
            alignment: WrapAlignment.center,
            children: [
              for (final c in candidates)
                PanelButton(
                  '${selected.contains(c.id) ? '[x] ' : '[ ] '}${c.label}',
                  key: ValueKey('party-pick-${c.id}'),
                  selected: selected.contains(c.id),
                  onPressed: !enabled ||
                          onChanged == null ||
                          (full && !selected.contains(c.id))
                      ? null
                      : () => onChanged!(selected.contains(c.id)
                          ? [
                              for (final s in selected)
                                if (s != c.id) s
                            ]
                          : [...selected, c.id]),
                ),
            ],
          ),
          if (full) ...[
            const SizedBox(height: 4),
            const Text('Máximo ${Account.maxCompanions} compañeros.',
                key: ValueKey('party-full'), style: muted),
          ],
        ],
        if (onAuto != null && selected.isNotEmpty) ...[
          const SizedBox(height: _gap),
          Wrap(
            spacing: _gap,
            runSpacing: _gap,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final id in selected)
                if (byId[id] case final c?)
                  PanelButton(
                    'AUTO ${c.name}: ${auto.contains(id) ? 'SÍ' : 'NO'}',
                    key: ValueKey('party-auto-$id'),
                    selected: auto.contains(id),
                    onPressed: enabled
                        ? () => onAuto!(id, !auto.contains(id))
                        : null,
                  ),
            ],
          ),
        ],
      ],
    );
  }
}
