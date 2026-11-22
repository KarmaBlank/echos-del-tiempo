import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../game_engine/models/item.dart';
import '../domain/stash.dart';

/// Organismo "Objetos sin recoger" (loot.md § 4b): lo propio que no
/// entró en el inventario ni en el alijo. Cada fila: TOMAR (al
/// inventario) o DESCARTAR. Sin nada, no se muestra.
class UnclaimedBox extends StatelessWidget {
  const UnclaimedBox({
    super.key,
    required this.entries,
    required this.nameOf,
    required this.onTake,
    required this.onDiscard,
    this.busy = false,
  });

  final List<StashEntry> entries;
  final String Function(StashEntry) nameOf;
  final ValueChanged<int> onTake;
  final ValueChanged<int> onDiscard;

  /// Hay una operación en curso: los botones quedan deshabilitados.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('unclaimed-box'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Text('OBJETOS SIN RECOGER', style: DsText.subtitle()),
          const SizedBox(width: 8),
          DsBadge('${entries.length}', key: const ValueKey('unclaimed-count')),
        ]),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 140),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (var i = 0; i < entries.length; i++)
                DsListRow(
                  key: ValueKey('unclaimed-row-$i'),
                  compact: true,
                  title: nameOf(entries[i]),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    DsButton('TOMAR',
                        key: ValueKey('unclaimed-take-$i'),
                        size: DsButtonSize.compact,
                        onPressed: busy ? null : () => onTake(i)),
                    const SizedBox(width: 4),
                    DsButton('DESCARTAR',
                        key: ValueKey('unclaimed-discard-$i'),
                        size: DsButtonSize.compact,
                        kind: DsButtonKind.ghost,
                        onPressed: busy ? null : () => onDiscard(i)),
                  ]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Nombre corto de una entrada del alijo para listas.
String stashEntryName(StashEntry e, String Function(ItemInstance) itemName) {
  if (e.item != null) return itemName(e.item!);
  if (e.eco != null) return 'Eco (${e.eco!.rarity.label})';
  return '${e.count} ${e.material!.label}';
}
