import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../combat/presentation/game_sprites.dart';

/// Categoría de un ítem de oficio: elige el ícono genérico si el id no
/// tiene sprite propio (`items.vida_cat_<categoría>` del manifest).
enum LifeIconKind { herramienta, pescado, semilla, cosecha, basura }

/// Ícono de un ítem de oficio (caña, azada, regadera, abono, pescado,
/// semilla, cosecha, basura del agua). El sprite sale de
/// `items.vida_<id>` vía [GameSprites]; si falta, el de su categoría; si
/// todavía no cargaron los sprites, la casilla vacía del átomo.
class LifeIcon extends ConsumerWidget {
  const LifeIcon(this.id, this.kind, {super.key, this.size = 32});

  /// Id del sprite: el del ítem, `semilla_<cultivo>` o `cosecha_<cultivo>`.
  final String id;
  final LifeIconKind kind;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameSpritesProvider).valueOrNull;
    return DsSpriteIcon(s?.lifeIcon(id, kind.name),
        key: ValueKey('life-icon-$id'), size: size);
  }
}
