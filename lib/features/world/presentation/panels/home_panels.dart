import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../core/procedural/item_icons.dart' show ItemIconImages;
import '../../../../game_engine/data/weapons_catalog.dart' show kWeapons;
import '../../../../game_engine/models/player_profile.dart';
import '../session_controller.dart';
import '../world_strings.dart';
import 'life_item_grid.dart';

/// A weapon rack of the player house (player_house.md § 8.2): pick up to
/// three weapons of the owner to show on it. INVENTARIO grid with the
/// detail on the right.
class HomeRackPanel extends StatefulWidget {
  const HomeRackPanel(
      {super.key, required this.controller, required this.profile});

  final SessionController controller;
  final PlayerProfile profile;

  @override
  State<HomeRackPanel> createState() => _HomeRackPanelState();
}

class _HomeRackPanelState extends State<HomeRackPanel> {
  late final Set<String> _on = {
    ...?widget.controller.homeLayout
        .piece(widget.controller.homeRackUid ?? -1)
        ?.weapons
  };
  String? _sel;

  static String? _shape(String baseId) {
    final type = kWeapons[baseId]?.type;
    return type == null ? null : ItemIconImages.keyOf(type.split('+').first);
  }

  @override
  Widget build(BuildContext context) {
    final weapons = [
      for (final i in widget.profile.items)
        if (kWeapons.containsKey(i.baseId)) i
    ];
    final sel = weapons.where((w) => w.uid == _sel).firstOrNull ??
        weapons.firstOrNull;
    String nameOf(dynamic w) => w.name ?? kWeapons[w.baseId]?.name ?? w.baseId;
    final full = _on.length >= 3;
    final detail = sel == null
        ? null
        : DsDetailPane(
            key: const ValueKey('home-rack-detail'),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(nameOf(sel), softWrap: true, style: DsText.subtitle()),
                Text(context.t('ui.town.home.rack.help'),
                    softWrap: true,
                    style: DsText.detail(DsColors.textSecondary)),
              ],
            ),
            actions: DsButton(
                _on.contains(sel.uid)
                    ? context.t('ui.town.home.rack.take_off')
                    : context.t('ui.town.home.rack.hang'),
                key: const ValueKey('home-rack-toggle'),
                kind: DsButtonKind.primary,
                tooltip: !_on.contains(sel.uid) && full
                    ? context.t('ui.town.home.rack.full')
                    : null,
                onPressed: !_on.contains(sel.uid) && full
                    ? null
                    : () => setState(() => _on.contains(sel.uid)
                        ? _on.remove(sel.uid)
                        : _on.add(sel.uid))),
          );
    return PanelFrame(
      key: const ValueKey('panel-home-rack'),
      title: context.t('ui.town.home.rack.title'),
      width: 900,
      onClose: widget.controller.closePanel,
      actions: [
        PanelButton(context.t('ui.town.home.rack.save'),
            key: const ValueKey('home-rack-save'), onPressed: () {
          widget.controller.setHomeRack([..._on]);
          widget.controller.closePanel();
        }),
      ],
      child: SizedBox(
        height: 380,
        child: weapons.isEmpty
            ? Center(
                child: Text(context.t('ui.town.home.rack.empty'),
                    style: DsText.body(DsColors.textSecondary)))
            : DsGridDetailLayout(
                keyPrefix: 'home-rack',
                count: weapons.length,
                detail: detail,
                cell: (context, i, size) {
                  final w = weapons[i];
                  final im = _shape(w.baseId) == null
                      ? null
                      : ItemIconImages.base(_shape(w.baseId)!);
                  return KeyedSubtree(
                    key: ValueKey('home-rack-cell-${w.uid}'),
                    child: LifeItemCell(
                      size: size,
                      selected: w.uid == sel?.uid,
                      onTap: () => setState(() => _sel = w.uid),
                      data: LifeItemCellData(
                        id: 'home-rack-item-${w.uid}',
                        icon: im == null
                            ? const SizedBox.shrink()
                            : RawImage(
                                image: im,
                                width: size * 0.6,
                                height: size * 0.6,
                                filterQuality: FilterQuality.none),
                        border: _on.contains(w.uid)
                            ? DsColors.reward
                            : DsColors.border,
                        search: nameOf(w),
                        detail: LifeItemDetail(
                            name: nameOf(w),
                            nameColor: DsColors.textTitle,
                            lines: [
                              if (_on.contains(w.uid))
                                context.t('ui.town.home.rack.on_rack')
                            ]),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
