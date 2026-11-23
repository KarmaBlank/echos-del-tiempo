import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter/services.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../game_engine/data/zones_catalog.dart';
import '../../../game_engine/models/bestiary.dart';
import '../../../game_engine/rules/family_rules.dart';
import '../../combat/presentation/game_sprites.dart';
import '../../combat/presentation/pixel_sprite.dart';
import '../domain/bestiary_text.dart';
import '../../../core/i18n/i18n_providers.dart';

/// El BESTIARIO (docs/specs/bestiary.md § 4): búsqueda arriba, filtro por
/// familia a la izquierda, lista por zona (una fila por enemigo; silueta y
/// "???" los que todavía no se mataron) y la ficha del elegido a la
/// derecha.
/// Solo lectura: lo llena ganar batallas.
class BestiaryView extends ConsumerStatefulWidget {
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
      'La búsqueda y los filtros solo ven lo descubierto.<br>'
      'Flechas arriba / abajo: moverse por la lista · Tab: filtros / '
      'búsqueda.';

  @override
  ConsumerState<BestiaryView> createState() => _BestiaryViewState();
}

class _BestiaryViewState extends ConsumerState<BestiaryView> {
  final _entries = bestiaryEntries();
  final _search = TextEditingController();
  final _nodes = <String, FocusNode>{};
  EnemyFamily? _family;
  String? _sel;

  FocusNode _node(String id) =>
      _nodes[id] ??= FocusNode(debugLabel: 'bestiary-$id');

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
    for (final n in _nodes.values) {
      n.dispose();
    }
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

  /// Flechas arriba / abajo: elige el anterior / siguiente de la lista.
  KeyEventResult _onKey(List<BestiaryEntry> visible, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final d = switch (e.logicalKey) {
      LogicalKeyboardKey.arrowDown => 1,
      LogicalKeyboardKey.arrowUp => -1,
      _ => 0,
    };
    if (d == 0 || visible.isEmpty) return KeyEventResult.ignored;
    final i = visible.indexWhere((x) => x.id == _sel);
    final to = (i + d).clamp(0, visible.length - 1);
    final id = visible[to].id;
    setState(() => _sel = id);
    _node(id).requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final byZone = <int, List<BestiaryEntry>>{};
    for (final e in visible) {
      (byZone[e.zone] ??= []).add(e);
    }
    // En el orden en que se ven (por zona), para las flechas.
    final ordered = [for (final l in byZone.values) ...l];
    final sel = _entries.where((e) => e.id == _sel).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsToolbar(
          title: '',
          center: Text.rich(
            key: const ValueKey('bestiary-count'),
            TextSpan(children: [
              TextSpan(
                  text: ref.t('ui.bestiary.discovered'), style: DsText.detail()),
              TextSpan(
                  text: '${_b.discovered}',
                  style: DsText.body(DsColors.reward)),
              TextSpan(
                  text: '/${_entries.length}',
                  style: DsText.body(DsColors.textPrimary)),
              if (visible.length != _entries.length)
                TextSpan(
                    text: ref.t('ui.bestiary.showing',
                        {'n': visible.length}),
                    style: DsText.detail()),
            ]),
          ),
          actions: [
            DsSearchField(
                key: const ValueKey('bestiary-search'),
                hint: ref.t('ui.bestiary.search'),
                width: 200,
                controller: _search),
          ],
        ),
        SizedBox(height: DsSpace.sm),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: RetroType.width(context, 170),
                child: NavSection(child: _filters()),
              ),
              SizedBox(width: DsSpace.md),
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Text(retroText(ref.t('ui.bestiary.empty')),
                            style: DsText.detail()))
                    : Focus(
                        canRequestFocus: false,
                        skipTraversal: true,
                        onKeyEvent: (_, e) => _onKey(ordered, e),
                        child: SingleChildScrollView(
                          child: NavSection(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final z in byZone.keys) ...[
                                  DsSectionHeader(z == kAbyssBestiaryZone
                                      ? ref.t('ui.bestiary.section.abyss')
                                      : z <= 0 || z > kZones.length
                                          ? ref.t('ui.bestiary.section.other')
                                          : ref.t('ui.bestiary.section.zone', {
                                              'zone': z,
                                              'name': kZones[z - 1].name
                                            })),
                                  for (final e in byZone[z]!) _row(e),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
              SizedBox(width: DsSpace.md),
              SizedBox(
                width: RetroType.width(context, 320)
                    .clamp(320.0, MediaQuery.sizeOf(context).width * 0.4),
                child: sel == null ? const SizedBox.shrink() : _detail(sel),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Nombre del filtro (los largos, abreviados para que entren).
  String _short(EnemyFamily f) => switch (f) {
        EnemyFamily.iceElemental => ref.t('ui.bestiary.family.ice_short'),
        EnemyFamily.aberration => ref.t('ui.bestiary.family.aberration_short'),
        _ => f.label.toUpperCase(),
      };

  /// Filtros por familia (columna de la izquierda): botones fantasma, el
  /// elegido con borde dorado.
  Widget _filters() {
    Widget chip(String label, EnemyFamily? f, Color? color) => Padding(
          padding: EdgeInsets.only(bottom: DsSpace.xs),
          child: DsButton(
            label,
            key: ValueKey('bestiary-filter-${f?.name ?? 'all'}'),
            kind: DsButtonKind.ghost,
            size: DsButtonSize.compact,
            accent: color,
            selected: _family == f,
            onPressed: () => setState(() => _family = f),
          ),
        );
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          chip(ref.t('ui.bestiary.filter.all'), null, null),
          for (final f in EnemyFamily.values)
            if (f != EnemyFamily.training) chip(_short(f), f, familyColor(f)),
        ],
      ),
    );
  }

  Widget _sprite(BestiaryEntry e, double box, {required bool known}) {
    final img = widget.sprites?.enemy(e.id);
    if (img == null) {
      return SizedBox(
          width: box,
          height: box,
          child: Center(
              child: Text(known ? e.def.name.characters.first : '?',
                  style: DsText.body(
                      known ? DsColors.textPrimary : DsColors.textSecondary))));
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

  /// Una fila: sprite chico, nombre (o "???") y la familia a la derecha.
  Widget _row(BestiaryEntry e) {
    final known = _b.knows(e.id);
    final f = e.family;
    return DsListRow(
      key: ValueKey('bestiary-card-${e.id}'),
      focusNode: _node(e.id),
      leading: _sprite(e, RetroType.width(context, 20), known: known),
      title: retroText(known ? e.def.name : '???'),
      titleColor: e.def.boss
          ? DsColors.reward
          : known
              ? null
              : DsColors.textSecondary,
      selected: e.id == _sel,
      trailing: Text(
          known && f != null ? f.code : (e.def.boss ? ref.t('ui.bestiary.boss') : ''),
          style: DsText.detail(
              known && f != null ? familyColor(f) : DsColors.textSecondary)),
      onTap: () {
        setState(() => _sel = e.id);
        _node(e.id).requestFocus();
      },
    );
  }

  /// Ficha: sprite, FICHA (familia, debilidades, mecánica, derrotados) y,
  /// plegado, zona y botín.
  Widget _detail(BestiaryEntry e) {
    final known = _b.knows(e.id);
    return SingleChildScrollView(
      key: ValueKey('bestiary-detail-${e.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _sprite(e, 120, known: known)),
          DsSectionHeader(ref.t('ui.bestiary.card')),
          ProtoText(
              key: const ValueKey('bestiary-detail-text'),
              enemyInfoMarkup(e.def, _b, description: true)),
          if (known) ...[
            SizedBox(height: DsSpace.sm),
            DsFold(
                key: ValueKey('bestiary-drops-${e.id}'),
                label: ref.t('ui.bestiary.zone_and_loot'),
                openLabel: ref.t('ui.bestiary.zone_and_loot'),
                child: ProtoText(enemyDropsMarkup(e))),
          ] else ...[
            SizedBox(height: DsSpace.sm),
            Text(
                retroText(ref.t('ui.bestiary.zone', {
                  'zone': e.zone > 0 && e.zone != kAbyssBestiaryZone
                      ? '${e.zone} · '
                      : '',
                  'name': e.zoneName
                })),
                style: DsText.detail()),
          ],
        ],
      ),
    );
  }
}
