import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../game_engine/data/zones_catalog.dart';
import '../../../game_engine/models/bestiary.dart';
import '../../../game_engine/rules/family_rules.dart';
import '../../combat/presentation/game_sprites.dart';
import '../../combat/presentation/pixel_sprite.dart';
import '../domain/bestiary_text.dart';

/// El BESTIARIO (docs/specs/bestiary.md § 4): fichas por zona a la
/// izquierda (silueta y "???" las que todavía no se mataron), detalle de
/// la elegida a la derecha, búsqueda por nombre y filtro por familia.
/// Solo lectura: lo llena ganar batallas.
class BestiaryView extends StatefulWidget {
  const BestiaryView({
    super.key,
    required this.bestiary,
    this.sprites,
  });

  final BestiaryProgress bestiary;
  final GameSprites? sprites;

  static const help = '<b>Bestiario</b><br>'
      'Cada enemigo que derrotás (solo o en grupo) se agrega acá, para '
      'toda la cuenta. La ficha dice su familia, a qué es débil, qué '
      'resiste y a qué es inmune.<br>'
      'En batalla, pasá el mouse sobre un enemigo para ver su ficha; si '
      'nunca lo derrotaste verás "???".<br>'
      'Flechas: moverse por las fichas · Tab: filtros / búsqueda.';

  /// Lado de una ficha de la grilla (Normal).
  static const card = 84.0;

  @override
  State<BestiaryView> createState() => _BestiaryViewState();
}

class _BestiaryViewState extends State<BestiaryView> {
  final _entries = bestiaryEntries();
  final _search = TextEditingController();
  EnemyFamily? _family;
  String? _sel;

  @override
  void initState() {
    super.initState();
    _sel = _entries.firstWhere((e) => widget.bestiary.knows(e.id),
            orElse: () => _entries.first)
        .id;
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  BestiaryProgress get _b => widget.bestiary;

  /// Las fichas que pasan el filtro. Familia y búsqueda solo ven las
  /// descubiertas (no revelan a las que faltan).
  List<BestiaryEntry> get _visible {
    final q = _search.text.trim().toLowerCase();
    if (_family == null && q.isEmpty) return _entries;
    return [
      for (final e in _entries)
        if (_b.knows(e.id) &&
            (_family == null || e.family == _family) &&
            (q.isEmpty ||
                e.def.name.toLowerCase().contains(q) ||
                (e.family?.label.toLowerCase().contains(q) ?? false)))
          e,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final byZone = <int, List<BestiaryEntry>>{};
    for (final e in visible) {
      (byZone[e.zone] ??= []).add(e);
    }
    final sel = _entries.where((e) => e.id == _sel).firstOrNull;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: RetroType.width(context, 170),
          child: NavSection(child: _filters()),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProtoText(
                  key: const ValueKey('bestiary-count'),
                  'Descubiertos <b>${_b.discovered}</b>/${_entries.length}'
                  '${visible.length != _entries.length ? ' · ${protoColor(ProtoColors.dim, 'mostrando ${visible.length}')}' : ''}'),
              const SizedBox(height: 6),
              Expanded(
                child: LayoutBuilder(builder: (context, box) {
                  final cell = RetroType.width(context, BestiaryView.card);
                  final cols =
                      ((box.maxWidth + 6) / (cell + 6)).floor().clamp(1, 12);
                  if (visible.isEmpty) {
                    return const Center(
                        child: Text('Nada con ese filtro todavía.',
                            style: TextStyle(color: ProtoColors.dim)));
                  }
                  return SingleChildScrollView(
                    child: NavSection(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final z in byZone.keys) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 4),
                              child: Text(
                                  z == kAbyssBestiaryZone
                                      ? 'Jefes del Abismo'
                                      : z <= 0 || z > kZones.length
                                          ? 'Otros'
                                          : 'Zona $z · ${kZones[z - 1].name}',
                                  style: const TextStyle(
                                      color: ProtoColors.sky)),
                            ),
                            _grid(byZone[z]!, cols, cell),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: RetroType.width(context, 320)
              .clamp(320.0, MediaQuery.sizeOf(context).width * 0.4),
          child: sel == null ? const SizedBox.shrink() : _detail(sel),
        ),
      ],
    );
  }

  /// Nombre del filtro (los largos, abreviados para que entren).
  static String _short(EnemyFamily f) => switch (f) {
        EnemyFamily.iceElemental => 'ELEM. ESCARCHA',
        EnemyFamily.aberration => 'ABERRACIÓN',
        _ => f.label.toUpperCase(),
      };

  /// Búsqueda y filtros por familia (columna de la izquierda).
  Widget _filters() {
    Widget chip(String label, EnemyFamily? f, Color? color) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: PanelButton(
            label,
            key: ValueKey('bestiary-filter-${f?.name ?? 'all'}'),
            accent: color,
            selected: _family == f,
            onPressed: () => setState(() => _family = f),
          ),
        );
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('bestiary-search'),
            controller: _search,
            style: RetroType.smallStyle,
            decoration: const InputDecoration(
                hintText: 'Buscar...',
                isDense: true,
                contentPadding: EdgeInsets.all(8)),
          ),
          const SizedBox(height: 6),
          chip('TODAS', null, null),
          for (final f in EnemyFamily.values)
            if (f != EnemyFamily.training) chip(_short(f), f, familyColor(f)),
        ],
      ),
    );
  }

  Widget _grid(List<BestiaryEntry> list, int cols, double cell) => FocusGrid(
        count: list.length,
        columns: cols,
        spacing: 6,
        keyPrefix: 'bestiary-cell-${list.first.zone}-',
        onFocusCell: (i) => setState(() => _sel = list[i].id),
        onActivate: (i) => setState(() => _sel = list[i].id),
        cell: (context, i, focused) => _card(list[i], cell),
      );

  Widget _sprite(BestiaryEntry e, double box, {required bool known}) {
    final img = widget.sprites?.enemy(e.id);
    if (img == null) {
      return SizedBox(
          width: box,
          height: box,
          child: Center(
              child: Text(known ? e.def.name.characters.first : '?',
                  style: TextStyle(
                      color: known ? ProtoColors.ink : ProtoColors.dim))));
    }
    final scale = (box / (img.width > img.height ? img.width : img.height))
        .floorToDouble()
        .clamp(1.0, 8.0);
    final s = PixelSprite(img, scale: scale);
    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: known
            ? s
            // Silueta: el sprite pintado de un solo color.
            : ColorFiltered(
                colorFilter: const ColorFilter.mode(
                    ProtoColors.barBg, BlendMode.srcIn),
                child: s),
      ),
    );
  }

  Widget _card(BestiaryEntry e, double cell) {
    final known = _b.knows(e.id);
    final selected = e.id == _sel;
    final f = e.family;
    return GestureDetector(
      key: ValueKey('bestiary-card-${e.id}'),
      onTap: () => setState(() => _sel = e.id),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: cell,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: ProtoColors.panel,
            border: Border.all(
                color: selected
                    ? ProtoColors.gold
                    : known && f != null
                        ? familyColor(f)
                        : ProtoColors.panelBorder,
                width: RetroTheme.thinBorderWidth),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sprite(e, cell - 16, known: known),
              const SizedBox(height: 2),
              Text(
                known ? e.def.name : '???',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: e.def.boss
                        ? ProtoColors.gold
                        : known
                            ? ProtoColors.ink
                            : ProtoColors.dim),
              ),
              Text(
                known && f != null ? f.code : (e.def.boss ? 'JEFE' : ' '),
                style: TextStyle(
                    color: known && f != null
                        ? familyColor(f)
                        : ProtoColors.dim),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(BestiaryEntry e) {
    final known = _b.knows(e.id);
    return PanelDetail(
      key: ValueKey('bestiary-detail-${e.id}'),
      children: [
        Center(child: _sprite(e, 120, known: known)),
        const SizedBox(height: 8),
        ProtoText(
            key: const ValueKey('bestiary-detail-text'),
            enemyInfoMarkup(e.def, _b, description: true)),
        const SizedBox(height: 8),
        if (known)
          ProtoText(enemyDropsMarkup(e))
        else
          ProtoText(protoColor(ProtoColors.dim,
              'Zona: ${e.zone > 0 && e.zone != kAbyssBestiaryZone ? '${e.zone} · ' : ''}${protoEsc(e.zoneName)}')),
      ],
    );
  }
}
