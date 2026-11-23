import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../game_engine/data/biomes_catalog.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/eco_portal_rules.dart';

/// Los 16 tiers de un portal de Ecos en grilla (ecos_zone.md § 3):
/// `T<n>` con cuántos Ecos de ese tier hay; los cerrados en gris con el
/// motivo en el tooltip. Molécula compartida por el portal de la zona y
/// el centro de viaje.
class EcoTierGrid extends StatelessWidget {
  const EcoTierGrid({
    super.key,
    required this.profile,
    required this.zone,
    required this.selected,
    required this.onSelect,
    this.zoneName,
    this.keyPrefix = 'eco-tier',
  });

  final PlayerProfile profile;
  final int zone;
  final String? zoneName;
  final int selected;
  final ValueChanged<int> onSelect;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final counts = EcoPortalRules.countByTier(profile, zone);
    return Wrap(
      spacing: DsSpace.xs,
      runSpacing: DsSpace.xs,
      children: [
        for (var t = 1; t <= EcoPortalRules.maxTier; t++)
          SizedBox(
            width: 64,
            child: _cell(t, counts[t] ?? 0),
          ),
      ],
    );
  }

  Widget _cell(int t, int n) {
    final why =
        EcoPortalRules.lockReason(profile, zone, t, zoneName: zoneName);
    return DsButton(
      n > 0 ? 'T$t ·$n' : 'T$t',
      key: ValueKey('$keyPrefix-$t'),
      size: DsButtonSize.compact,
      selected: t == selected,
      tooltip: why ??
          (n == 0
              ? 'Portal T$t abierto. No tenés Ecos de este tier y zona.'
              : 'Portal T$t abierto: tenés $n Eco${n == 1 ? '' : 's'}.'),
      onPressed: why == null ? () => onSelect(t) : null,
    );
  }
}

/// Centro de viaje de los Ecos (ecos_zone.md § 5): grilla de zonas y, a
/// la derecha, los portales de la elegida (abiertos / cerrados y cuántos
/// Ecos tenés de cada tier) con IR, que viaja al exterior de esa zona y
/// te deja frente a su portal. Organismo único: lo usan el Portal del Eco
/// del pueblo y el mapa de viaje.
class EcoZoneHub extends StatefulWidget {
  const EcoZoneHub({
    super.key,
    required this.profile,
    required this.zoneName,
    required this.goBlocked,
    required this.onGo,
    this.here,
  });

  final PlayerProfile profile;

  /// Nombre de la zona 1..10.
  final String Function(int zone) zoneName;

  /// Por qué no se puede ir al portal de esa zona, o `null`.
  final String? Function(int zone) goBlocked;
  /// IR: viaja al portal de la zona con ese tier elegido.
  final void Function(int zone, int tier) onGo;

  /// La zona cuyo portal está al lado (no hace falta viajar), si hay.
  final int? here;

  @override
  State<EcoZoneHub> createState() => _EcoZoneHubState();
}

class _EcoZoneHubState extends State<EcoZoneHub> {
  int? _zone;
  final _tier = <int, int>{};

  PlayerProfile get p => widget.profile;

  int get _sel {
    if (_zone case final z?) return z;
    // La primera zona con Ecos para abrir; si no, la 1.
    for (final s in EcoPortalRules.all) {
      if (_ready(s.zone) > 0) return s.zone;
    }
    return 1;
  }

  /// Ecos de [zone] que se pueden abrir ya (tier abierto).
  int _ready(int zone) => p.ecos
      .where((e) =>
          e.zone == zone && EcoPortalRules.isUnlocked(p, e.zone, e.tier))
      .length;

  @override
  Widget build(BuildContext context) {
    final zone = _sel;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: DsSpace.xs,
              runSpacing: DsSpace.xs,
              children: [
                for (final s in EcoPortalRules.all)
                  SizedBox(width: 146, child: _zoneCell(s.zone, zone)),
              ],
            ),
          ),
        ),
        SizedBox(width: DsSpace.md),
        Expanded(child: SingleChildScrollView(child: _detail(zone))),
      ],
    );
  }

  Widget _zoneCell(int zone, int sel) {
    final open = EcoPortalRules.unlockedTier(p, zone);
    final total = p.ecos.where((e) => e.zone == zone).length;
    return DsButton(
      'ZONA $zone',
      key: ValueKey('eco-hub-zone-$zone'),
      size: DsButtonSize.compact,
      selected: zone == sel,
      details: [
        widget.zoneName(zone),
        open == 0 ? 'Cerrado' : 'T1–T$open · $total Eco${total == 1 ? '' : 's'}',
      ],
      onPressed: () => setState(() => _zone = zone),
    );
  }

  Widget _detail(int zone) {
    final spot = EcoPortalRules.of(zone)!;
    final name = widget.zoneName(zone);
    final open = EcoPortalRules.unlockedTier(p, zone);
    final tier = (_tier[zone] ?? open).clamp(1, EcoPortalRules.maxTier);
    final why = widget.here == zone ? 'Ya estás frente a este portal' :
        widget.goBlocked(zone);
    final lock = EcoPortalRules.lockReason(p, zone, 1, zoneName: name);
    return Column(
      key: ValueKey('eco-hub-detail-$zone'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Zona $zone · $name', style: DsText.subtitle()),
        Text('Portal en: ${biomeDef(spot.biome)?.name ?? spot.biome}',
            style: DsText.detail()),
        SizedBox(height: DsSpace.sm),
        Text(
            lock ??
                'Abiertos: T1–T$open. Completá un Eco del tier más alto para '
                    'abrir el siguiente.',
            softWrap: true,
            style: DsText.detail(lock == null ? null : DsColors.warning)),
        SizedBox(height: DsSpace.sm),
        EcoTierGrid(
          keyPrefix: 'eco-hub-tier',
          profile: p,
          zone: zone,
          zoneName: name,
          selected: tier,
          onSelect: (t) => setState(() => _tier[zone] = t),
        ),
        SizedBox(height: DsSpace.md),
        Align(
          alignment: Alignment.centerLeft,
          child: DsButton('IR AL PORTAL',
              key: ValueKey('eco-hub-go-$zone'),
              kind: DsButtonKind.primary,
              tooltip: why,
              onPressed: why == null ? () => widget.onGo(zone, tier) : null),
        ),
      ],
    );
  }
}
