import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/balance/balance_codecs.dart';
import '../../../../game_engine/data/climate_catalog.dart';
import '../../../../game_engine/data/farming_catalog.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/data/bait_catalog.dart';
import '../field_editors.dart' show NumberStepper;
import 'climate_editor_controller.dart';

/// Editor labels (a Spanish-only tool, like the rest of the Editor).
abstract final class _L {
  static const tabs = [
    'BIOMAS',
    'ESTACIONES',
    'PECES',
    'CULTIVOS',
    'CEBOS',
    'TEXTOS',
  ];
  static const save = 'GUARDAR CLIMA';
  static const exposure = 'EXPOSICIÓN';
  static const weathers = 'CLIMAS PERMITIDOS';
  static const melt = 'LA NIEVE SE VUELVE';
  static const ground = 'MARCAS EN EL SUELO';
  static const seasons = 'ESTACIONES';
  static const numbers = 'NÚMEROS';
  static const seasonDays = 'Días por estación';
  static const issues = 'PROBLEMAS (no se puede guardar)';
  static const missing = 'Falta este idioma: no se puede guardar.';
  static const exposures = {
    Exposure.outdoor: 'Exterior',
    Exposure.sheltered: 'Bajo techo',
    Exposure.volcanic: 'Volcánico',
  };
  static const marks = {
    GroundMarkId.snow: 'Nieve / escarcha',
    GroundMarkId.puddles: 'Charcos',
    GroundMarkId.leaves: 'Hojas',
    GroundMarkId.flowers: 'Flores',
  };
}

/// CLIMA area of the Editor (weather_seasons.md § 8): subtabs, a grid of
/// entries on the left and the detail on the right.
class ClimatePage extends StatefulWidget {
  const ClimatePage({super.key, required this.c});
  final ClimateEditorController c;

  @override
  State<ClimatePage> createState() => _ClimatePageState();
}

class _ClimatePageState extends State<ClimatePage> {
  int tab = 0;
  String? sel;

  ClimateEditorController get c => widget.c;

  List<(String, String)> get _items => switch (tab) {
        0 => [for (final id in ClimateEditorController.biomeIds) (id, id)],
        1 => [for (final s in Season.values) (s.name, s.label)],
        2 => [
            for (final id in ClimateEditorController.fishIds)
              (id, kFish[id]!.name)
          ],
        3 => [
            for (final id in ClimateEditorController.cropIds)
              (id, kCrops[id]!.name)
          ],
        4 => [
            for (final id in ClimateEditorController.baitIds)
              (id, kBaits[id]!.name)
          ],
        _ => [
            for (final k in c.draft.names.keys.isEmpty
                ? kClimateNames.keys
                : c.draft.names.keys)
              (k, k)
          ],
      };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([c, c.balance]),
        builder: (context, _) {
          final items = _items;
          final id = items.any((e) => e.$1 == sel)
              ? sel!
              : (items.isEmpty ? null : items.first.$1);
          final issues = c.issues;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                    child: DsTabBar(
                      key: const ValueKey('climate-tabs'),
                      index: tab,
                      onChanged: (i) => setState(() {
                        tab = i;
                        sel = null;
                      }),
                      tabs: [for (final t in _L.tabs) DsTab(t)],
                    ),
                  ),
                  if (c.message != null)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: DsSpace.sm),
                      child: Text(c.message!, style: DsText.detail()),
                    ),
                  DsButton(_L.save,
                      key: const ValueKey('climate-save'),
                      kind: DsButtonKind.primary,
                      onPressed: c.dirty && issues.isEmpty ? c.save : null),
                ]),
                Expanded(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(DsSpace.sm),
                            child: Wrap(
                              spacing: DsSpace.xs,
                              runSpacing: DsSpace.xs,
                              children: [
                                for (final (k, name) in items)
                                  SizedBox(
                                    width: 150,
                                    child: DsCard(
                                      key: ValueKey('climate-cell-$k'),
                                      selected: k == id,
                                      onTap: () => setState(() => sel = k),
                                      child: Text(name,
                                          style: DsText.body(),
                                          softWrap: true),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 380,
                          child: DsDetailPane(
                            key: const ValueKey('climate-detail'),
                            body: id == null
                                ? const SizedBox.shrink()
                                : _detail(id, issues),
                          ),
                        ),
                      ]),
                ),
              ]);
        },
      );

  Widget _head(String t) => Padding(
        padding: EdgeInsets.only(top: DsSpace.sm, bottom: DsSpace.xs),
        child: Text(t, style: DsText.subtitle(DsColors.textSecondary)),
      );

  Widget _chip(String key, String label, bool on, VoidCallback onTap) =>
      DsCard(
        key: ValueKey(key),
        selected: on,
        onTap: onTap,
        padding: EdgeInsets.symmetric(
            horizontal: DsSpace.sm, vertical: DsSpace.xs),
        child: Text(label,
            style: DsText.body(on ? DsColors.text : DsColors.textSecondary)),
      );

  Widget _wrap(List<Widget> w) =>
      Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: w);

  Widget _number(BalanceKind k, String key, String label) =>
      Padding(
        padding: EdgeInsets.only(bottom: DsSpace.xs),
        child: Row(children: [
          Expanded(child: Text(label, style: DsText.body())),
          NumberStepper(
              key: ValueKey('climate-num-$key'),
              value: c.value(k, key),
              min: 0,
              integer: c.value(k, key) is int,
              step: c.value(k, key) is int ? 1 : 0.05,
              onChanged: (v) => c.setValue(k, key, v)),
        ]),
      );

  Widget _seasonToggles(
          String prefix, Set<Season> on, void Function(Season) toggle) =>
      _wrap([
        for (final s in Season.values)
          _chip('$prefix-${s.name}', s.label, on.contains(s), () => toggle(s)),
      ]);

  Widget _detail(String id, List<String> issues) {
    final body = <Widget>[
      Text(_items.firstWhere((e) => e.$1 == id).$2, style: DsText.title()),
    ];
    switch (tab) {
      case 0:
        final b = c.biome(id);
        body.addAll([
          _head(_L.exposure),
          _wrap([
            for (final e in Exposure.values)
              _chip('climate-exp-${e.name}', _L.exposures[e]!,
                  b.exposure == e, () => c.setExposure(id, e)),
          ]),
          _head(_L.weathers),
          _wrap([
            for (final w in Weather.values)
              if (w != Weather.despejado)
                _chip('climate-w-${w.name}', w.label, b.allowed.contains(w),
                    () => c.toggleWeather(id, w)),
          ]),
          _head(_L.melt),
          _wrap([
            for (final w in Weather.values)
              if (w != Weather.snow)
                _chip('climate-melt-${w.name}', w.label, b.snowMelt == w,
                    () => c.setSnowMelt(id, w)),
          ]),
          _head(_L.ground),
          _wrap([
            for (final m in GroundMarkId.values)
              _chip(
                  'climate-g-${m.name}',
                  _L.marks[m]!,
                  switch (m) {
                    GroundMarkId.snow => b.ground.snow,
                    GroundMarkId.puddles => b.ground.puddles,
                    GroundMarkId.leaves => b.ground.leaves,
                    GroundMarkId.flowers => b.ground.flowers,
                  },
                  () => c.toggleGround(id, m)),
          ]),
          _head(_L.numbers),
          for (final k in c.biomeKeys(id)) _number(BalanceKind.town, k, k),
        ]);
      case 1:
        final s = Season.fromName(id);
        body.addAll([
          _head(_L.numbers),
          _number(BalanceKind.town, 'seasonDays', _L.seasonDays),
          for (final k in ClimateEditorController.seasonKeys(s))
            _number(BalanceKind.town, k, k),
        ]);
      case 2:
        body.addAll([
          _head(_L.seasons),
          _seasonToggles('climate-fish', c.fishSeasons(id),
              (s) => c.toggleFishSeason(id, s)),
        ]);
      case 3:
        body.addAll([
          _head(_L.seasons),
          _seasonToggles('climate-crop', c.cropSeasons(id),
              (s) => c.toggleCropSeason(id, s)),
        ]);
      case 4:
        body.addAll([
          _head(_L.numbers),
          _number(BalanceKind.fishing, 'baitAffinity', 'baitAffinity'),
          for (final k in ClimateEditorController.baitKeys(id))
            _number(BalanceKind.fishing, k, k),
        ]);
      default:
        for (final tag in c.locales) {
          final v = c.text(id, tag);
          body.add(Padding(
            padding: EdgeInsets.only(top: DsSpace.xs),
            child: Row(children: [
              SizedBox(
                width: 64,
                child: Text(tag,
                    style: DsText.detail(
                        v.trim().isEmpty ? DsColors.danger : null)),
              ).tip(v.trim().isEmpty ? _L.missing : tag),
              Expanded(
                child: _TextBox(
                    key: ValueKey('climate-text-$id-$tag'),
                    value: v,
                    missing: v.trim().isEmpty,
                    onChanged: (t) => c.setText(id, tag, t)),
              ),
            ]),
          ));
        }
    }
    if (issues.isNotEmpty) {
      body.addAll([
        _head(_L.issues),
        for (final i in issues.take(6))
          Text(i, style: DsText.detail(DsColors.danger)),
      ]);
    }
    return SingleChildScrollView(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
    );
  }
}

/// Atom: a one-line text box (marked red when empty).
class _TextBox extends StatefulWidget {
  const _TextBox(
      {super.key,
      required this.value,
      required this.missing,
      required this.onChanged});
  final String value;
  final bool missing;
  final ValueChanged<String> onChanged;

  @override
  State<_TextBox> createState() => _TextBoxState();
}

class _TextBoxState extends State<_TextBox> {
  late final _t = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_TextBox old) {
    super.didUpdateWidget(old);
    if (widget.value != _t.text) _t.text = widget.value;
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _t,
        style: DsText.body(),
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
          enabledBorder: widget.missing
              ? const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: DsColors.danger))
              : null,
          contentPadding: EdgeInsets.all(DsSpace.sm),
        ),
        onChanged: widget.onChanged,
      );
}
