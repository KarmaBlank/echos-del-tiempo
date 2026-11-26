import 'package:material_ui/material_ui.dart';

import '../../theme/proto_colors.dart';
import '../../theme/retro_theme.dart';
import '../../theme/ui_theme.dart';
import '../../../core/procedural/weapon_look.dart' show elementColor;
import '../../../core/settings/game_settings.dart' show TextSize;
import '../../../game_engine/models/elements.dart';
import '../../../game_engine/models/item.dart' show Rarity;
import '../../../game_engine/models/loot_filter.dart' show FilterColor;
import '../../../game_engine/rules/loot_filter_rules.dart';
import '../design.dart';
import 'ds_examples.dart';

/// Páginas de la galería (design_system.md § 8).
enum DsGalleryPage {
  palette('PALETA'),
  buttons('BOTONES'),
  navigation('BARRA'),
  surfaces('TARJETAS'),
  character('PERSONAJE'),
  inventory('INVENTARIO'),
  transfer('TRASPASO'),
  grids('GRILLAS'),
  quests('ENCARGOS'),
  battle('BATALLA');

  const DsGalleryPage(this.label);
  final String label;
}

/// Galería del sistema de diseño: cada componente en sus estados, la
/// paleta, la escala tipográfica y los ejemplos. Solo flavor dev
/// (`lib/app/flavors/main_gallery.dart`).
class DsGalleryScreen extends StatefulWidget {
  const DsGalleryScreen({
    super.key,
    this.initialPage = DsGalleryPage.palette,
    this.initialTextSize = TextSize.normal,
    this.initialTheme,
  });

  final DsGalleryPage initialPage;
  final TextSize initialTextSize;

  /// Tema de arranque (null: el que haya puesto la app).
  final InterfaceTheme? initialTheme;

  @override
  State<DsGalleryScreen> createState() => _DsGalleryScreenState();
}

class _DsGalleryScreenState extends State<DsGalleryScreen> {
  late DsGalleryPage _page = widget.initialPage;
  late TextSize _size = widget.initialTextSize;
  late InterfaceTheme _theme = widget.initialTheme ?? UiTheme.kind;
  late UiSpacing _spacing = UiTheme.spacing;

  T _next<T>(List<T> all, T v) => all[(all.indexOf(v) + 1) % all.length];

  static const _sizeNames = {
    TextSize.normal: 'NORMAL',
    TextSize.large: 'GRANDE',
    TextSize.huge: 'MUY GRANDE',
    TextSize.enormous: 'ENORME',
  };
  static const _themeNames = {
    InterfaceTheme.blue: 'AZUL',
    InterfaceTheme.dark: 'OSCURO',
    InterfaceTheme.highContrast: 'ALTO CONTRASTE',
  };

  @override
  Widget build(BuildContext context) {
    return UiThemeScope(
      theme: _theme,
      textColors: UiTheme.textColors,
      spacing: _spacing,
      child: RetroTextScale(
        factor: _size.factor,
        font: RetroType.font,
        readingTitles: RetroType.readingTitles,
        wideLetters: RetroType.wideLetters,
        child: Builder(builder: (context) {
          return Theme(
            data: DsTheme.apply(Theme.of(context)),
            child: Scaffold(
              backgroundColor: DsColors.background,
              body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DsToolbar(
                      title: 'GALERÍA',
                      center: DsTabBar(
                        tabs: [
                          for (final p in DsGalleryPage.values) DsTab(p.label)
                        ],
                        index: _page.index,
                        onChanged: (i) =>
                            setState(() => _page = DsGalleryPage.values[i]),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: DsSpace.xl, vertical: DsSpace.sm),
                      child: Wrap(
                          spacing: DsSpace.sm,
                          runSpacing: DsSpace.xs,
                          children: [
                            DsButton('TEXTO ${_sizeNames[_size]}',
                                size: DsButtonSize.compact,
                                tooltip: 'Tamaño del texto',
                                onPressed: () => setState(() =>
                                    _size = _next(TextSize.values, _size))),
                            DsButton(_themeNames[_theme]!,
                                size: DsButtonSize.compact,
                                tooltip: 'Tema de interfaz',
                                onPressed: () => setState(() => _theme =
                                    _next(InterfaceTheme.values, _theme))),
                            DsButton(
                                _spacing == UiSpacing.wide
                                    ? 'AMPLIO'
                                    : 'COMPACTO',
                                size: DsButtonSize.compact,
                                tooltip: 'Espaciado',
                                onPressed: () => setState(() => _spacing =
                                    _next(UiSpacing.values, _spacing))),
                          ]),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(DsSpace.xl),
                        child: KeyedSubtree(
                            key: ValueKey(_page),
                            child: Align(
                                alignment: Alignment.topLeft,
                                child: pageFor(_page))),
                      ),
                    ),
                  ]),
            ),
          );
        }),
      ),
    );
  }

  static Widget pageFor(DsGalleryPage p) => switch (p) {
        DsGalleryPage.palette => const PalettePage(),
        DsGalleryPage.buttons => const ButtonsPage(),
        DsGalleryPage.navigation => const NavigationPage(),
        DsGalleryPage.surfaces => const SurfacesPage(),
        DsGalleryPage.character => const CharacterMockup(),
        DsGalleryPage.inventory => const InventoryMockup(),
        DsGalleryPage.transfer => const TransferMockup(),
        DsGalleryPage.grids => const GridTemplatesMockup(),
        DsGalleryPage.quests => const QuestTemplateMockup(),
        DsGalleryPage.battle => const BattleMockup(),
      };
}

/// DsSlider + DsTimeline juntos (vista de plantilla de BUILD).
class _SliderSample extends StatefulWidget {
  const _SliderSample();

  @override
  State<_SliderSample> createState() => _SliderSampleState();
}

class _SliderSampleState extends State<_SliderSample> {
  int _v = 24;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DsSlider(
              value: _v,
              min: 1,
              max: 50,
              marks: const {
                10: DsColors.warning,
                20: DsColors.warning,
                30: DsColors.instant,
                40: DsColors.instant,
                50: DsColors.instant,
              },
              onChanged: (v) => setState(() => _v = v)),
          Text('Nv $_v', style: DsText.detail()),
          DsTimeline(
              selected: _v,
              onSelect: (v) => setState(() => _v = v),
              marks: const [
                DsTimelineMark(10, '10 HITO', color: DsColors.warning),
                DsTimelineMark(20, '20 HITO', color: DsColors.warning),
                DsTimelineMark(30, '30 PRUEBA', color: DsColors.instant),
              ]),
        ],
      );
}

/// Una muestra con su nombre arriba.
class _Sample extends StatelessWidget {
  const _Sample(this.name, this.child);
  final String name;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: DsText.detail()),
          SizedBox(height: DsSpace.xs),
          child,
        ],
      );
}

Widget _wrap(List<Widget> c) =>
    Wrap(spacing: DsSpace.lg, runSpacing: DsSpace.md, children: c);

/// Paleta de roles y escala tipográfica.
class PalettePage extends StatelessWidget {
  const PalettePage({super.key});

  @override
  Widget build(BuildContext context) {
    final sw = RetroType.width(context, 28);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const DsSectionHeader('Roles de color'),
      SizedBox(height: DsSpace.sm),
      Wrap(spacing: DsSpace.lg, runSpacing: DsSpace.sm, children: [
        for (final e in DsColors.roles.entries)
          SizedBox(
            width: RetroType.width(context, 270),
            child: Row(children: [
              Container(
                  width: sw,
                  height: sw,
                  decoration: BoxDecoration(
                      color: e.value,
                      border: Border.all(color: DsColors.border, width: 2))),
              SizedBox(width: DsSpace.sm),
              Expanded(child: Text(e.key, style: DsText.body())),
            ]),
          ),
      ]),
      SizedBox(height: DsSpace.lg),
      const DsSectionHeader('Tipografía'),
      SizedBox(height: DsSpace.sm),
      _typeRow(context, 'Título', DsText.title(), 'PERSONAJE'),
      _typeRow(
          context, 'Título compacto', DsText.heading(), 'GRANJERO 1 · NV 3'),
      _typeRow(context, 'Subtítulo', DsText.subtitle(), 'ATRIBUTOS · EQUIPO'),
      _typeRow(
          context,
          'Subtítulo (lectura)',
          DsText.body(DsColors.textSubtitle),
          'Arma de una mano · nivel de objeto 12'),
      _typeRow(context, 'Cuerpo / Descripción', DsText.body(),
          'Espada del Alba: golpe de luz que ignora la guardia.'),
      _typeRow(context, 'Apagado / stats', DsText.muted(),
          'ATQ 14 · MAG 3 (con tus atributos)'),
      _typeRow(context, 'Meta', DsText.meta(), 'Pide: Ilda · día 4'),
      _typeRow(context, 'CLAVE', DsText.key(), 'Solo atiende 12 parcelas'),
      _typeRow(
          context, 'Acento (oro)', DsText.accent(), '+120 de oro · +5 rep'),
      _richRow(context, 'CLAVE en línea (**…**)',
          'Solo atiende **12 parcelas**, marcadas en verde.'),
      SizedBox(height: DsSpace.lg),
      const DsSectionHeader('Paletas reservadas (nunca para texto)'),
      SizedBox(height: DsSpace.sm),
      Text('Elementos', style: DsText.subtitle()),
      SizedBox(height: DsSpace.xs),
      Wrap(spacing: DsSpace.md, runSpacing: DsSpace.sm, children: [
        for (final e in GameElement.values)
          _swatch(context, e.name.toUpperCase(), elementColor(e)),
      ]),
      SizedBox(height: DsSpace.sm),
      Text('Rarezas', style: DsText.subtitle()),
      SizedBox(height: DsSpace.xs),
      Wrap(spacing: DsSpace.md, runSpacing: DsSpace.sm, children: [
        for (final r in Rarity.values)
          _swatch(context, r.name.toUpperCase(),
              _rgb(LootFilterRules.rarityColor(r))),
      ]),
      SizedBox(height: DsSpace.sm),
      Text('Roles de texto', style: DsText.subtitle()),
      SizedBox(height: DsSpace.xs),
      Wrap(spacing: DsSpace.md, runSpacing: DsSpace.sm, children: [
        for (final r in DsTextRole.values)
          _swatch(context, r.name.toUpperCase(), DsTextColor(r)),
      ]),
      SizedBox(height: DsSpace.lg),
      const DsSectionHeader('Espaciado'),
      SizedBox(height: DsSpace.sm),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final e in DsSpace.base.entries) ...[
          Column(children: [
            Container(
                width: UiTheme.space(e.value) * 2,
                height: UiTheme.space(e.value) * 2,
                color: DsColors.borderControl),
            SizedBox(height: DsSpace.xs),
            Text('${e.key} ${UiTheme.space(e.value).round()}',
                style: DsText.detail()),
          ]),
          SizedBox(width: DsSpace.lg),
        ],
      ]),
    ]);
  }

  /// A loot-filter colour as a Flutter colour.
  static Color _rgb(FilterColor f) => ProtoColors.parse('#${[
        f.r,
        f.g,
        f.b
      ].map((v) => v.toRadixString(16).padLeft(2, '0')).join()}')!;

  /// A colour square with its name in the body role.
  Widget _swatch(BuildContext context, String name, Color c) {
    final sw = RetroType.width(context, 22);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: sw,
          height: sw,
          decoration: BoxDecoration(
              color: c, border: Border.all(color: DsColors.border, width: 2))),
      SizedBox(width: DsSpace.xs),
      Text(name, style: DsText.detail()),
    ]);
  }

  Widget _richRow(BuildContext context, String name, String markup) => Padding(
        padding: EdgeInsets.only(bottom: DsSpace.md),
        child: Row(children: [
          SizedBox(
              width: RetroType.width(context, 260),
              child: Text(name, style: DsText.detail())),
          Expanded(child: DsRichText(markup)),
        ]),
      );

  Widget _typeRow(BuildContext context, String name, TextStyle s, String text) {
    final px = MediaQuery.textScalerOf(context).scale(s.fontSize!).round();
    return Padding(
      padding: EdgeInsets.only(bottom: DsSpace.md),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(
            width: RetroType.width(context, 260),
            child:
                Text('$name · ${s.fontFamily} $px px', style: DsText.detail())),
        Expanded(child: Text(text, style: s)),
      ]),
    );
  }
}

/// Botones en todas sus variantes y estados.
class ButtonsPage extends StatelessWidget {
  const ButtonsPage({super.key});

  static const _states = <String, Set<WidgetState>?>{
    'normal': <WidgetState>{},
    'hover': {WidgetState.hovered},
    'foco': {WidgetState.focused},
    'presionado': {WidgetState.pressed},
    'desactivado': {WidgetState.disabled},
  };

  @override
  Widget build(BuildContext context) {
    void noop() {}
    Widget row(String title, DsButtonKind kind, String label) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DsSectionHeader(title),
            SizedBox(height: DsSpace.sm),
            _wrap([
              for (final e in _states.entries)
                _Sample(
                    e.key,
                    DsButton(label,
                        kind: kind,
                        previewStates: e.value,
                        onPressed: e.value!.contains(WidgetState.disabled)
                            ? null
                            : noop)),
              if (kind == DsButtonKind.secondary)
                _Sample('elegido',
                    DsButton(label, selected: true, onPressed: noop)),
            ]),
          ],
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      row('Principal', DsButtonKind.primary, 'EQUIPAR'),
      row('Secundario', DsButtonKind.secondary, 'COMPARAR'),
      row('Fantasma', DsButtonKind.ghost, '> MÁS'),
      const DsSectionHeader('Ícono y compacto'),
      SizedBox(height: DsSpace.sm),
      _wrap([
        _Sample('ícono',
            DsButton.icon(const Text('?'), tooltip: 'Ayuda', onPressed: noop)),
        _Sample(
            'ícono foco',
            DsButton.icon(const Text('×'),
                tooltip: 'Cerrar',
                onPressed: noop,
                previewStates: const {WidgetState.focused})),
        _Sample('compacto',
            DsButton('+3 VIT', size: DsButtonSize.compact, onPressed: noop)),
        _Sample(
            'compacto ícono',
            DsButton.icon(const Text('-'),
                tooltip: 'Quitar',
                size: DsButtonSize.compact,
                onPressed: noop)),
        _Sample(
            'compacto principal',
            DsButton('LISTO',
                kind: DsButtonKind.primary,
                size: DsButtonSize.compact,
                onPressed: noop)),
        _Sample(
            'con aviso',
            DsButton('+3 → +1.5',
                accent: DsColors.warning,
                size: DsButtonSize.compact,
                onPressed: noop)),
      ]),
    ]);
  }
}

/// Pestañas con insignia, barra superior, búsqueda e insignias sueltas.
class NavigationPage extends StatefulWidget {
  const NavigationPage({super.key});

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  int _tab = 1;

  @override
  Widget build(BuildContext context) {
    void noop() {}
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const DsSectionHeader('Barra superior'),
      SizedBox(height: DsSpace.sm),
      ColoredBox(
        color: DsColors.surface,
        child: DsToolbar(
          title: 'EQUIPO',
          center: DsTabBar(
            tabs: const [
              DsTab('ARMAS', badge: '2'),
              DsTab('ARMADURAS'),
              DsTab('OBJETOS', badge: 'NUEVO'),
            ],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          actions: [
            const DsSearchField(width: 200),
            DsButton.icon(const Text('?'),
                tooltip: 'Ayuda', size: DsButtonSize.compact, onPressed: noop),
          ],
        ),
      ),
      SizedBox(height: DsSpace.lg),
      const DsSectionHeader('Insignias'),
      SizedBox(height: DsSpace.sm),
      _wrap(const [
        _Sample('número', DsBadge('3')),
        _Sample('palabra', DsBadge('NUEVO')),
        _Sample('neutra', DsBadge('12', neutral: true)),
      ]),
      SizedBox(height: DsSpace.lg),
      const DsSectionHeader('Búsqueda'),
      SizedBox(height: DsSpace.sm),
      _wrap([
        const _Sample('vacía', DsSearchField()),
        _Sample('con texto',
            DsSearchField(controller: TextEditingController(text: 'espada'))),
      ]),
      SizedBox(height: DsSpace.lg),
      const DsSectionHeader('Etiquetas'),
      SizedBox(height: DsSpace.sm),
      _wrap(const [DsTag.instant(), DsTag.canBreak(), DsTag.isNew()]),
    ]);
  }
}

/// Tarjeta, aviso, tooltip, filas, valores y plegable.
class SurfacesPage extends StatelessWidget {
  const SurfacesPage({super.key});

  @override
  Widget build(BuildContext context) {
    void noop() {}
    final col = RetroType.width(context, 420);
    return Wrap(spacing: DsSpace.xl, runSpacing: DsSpace.lg, children: [
      SizedBox(
        width: col,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const DsSectionHeader('Filas'),
          DsListRow(title: 'Espada del Alba', detail: 'Nv 12', onTap: noop),
          DsListRow(
              title: 'Arco de Ceniza',
              detail: 'Nv 9',
              selected: true,
              onTap: noop),
          const DsListRow(title: 'Báculo roto', detail: 'Nv 3', enabled: false),
          const DsSectionHeader('Valores'),
          const DsStatLine('ATQ', 15, 50),
          const DsStatLine('DEF', 30, 22),
          SizedBox(height: DsSpace.xs),
          Row(children: [
            const DsCost.mp(8),
            SizedBox(width: DsSpace.md),
            const DsCost.pulse(2),
            SizedBox(width: DsSpace.md),
            const DsCost.mp(20, affordable: false),
          ]),
          const DsSectionHeader('Oro'),
          Wrap(spacing: DsSpace.md, runSpacing: DsSpace.xs, children: [
            const DsGold(4),
            const DsGold(1250),
            const DsGold(30, affordable: false),
            const DsGoldText('Precio: ₵4'),
            DsButton('COMPRAR · ₵4', onPressed: noop),
            DsButton('COMPRAR ×3 · ₵12', onPressed: noop),
            DsButton('VENDER · ₵9', onPressed: noop),
          ]),
          const DsSectionHeader('Plegable'),
          const DsFold(
              initiallyOpen: true,
              child: Text('Daño de luz: +20 % contra sombras.')),
          const DsSectionHeader('Nivel y porcentaje'),
          const _SliderSample(),
          SizedBox(height: DsSpace.xs),
          const Wrap(spacing: 16, children: [
            DsPercent(0, label: 'Sin candidata'),
            DsPercent(72, label: 'Hacha Tronante'),
            DsPercent(100, label: 'Completa'),
          ]),
        ]),
      ),
      SizedBox(
        width: col,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const DsSectionHeader('Tarjeta'),
          SizedBox(height: DsSpace.sm),
          DsCard(
              onTap: noop,
              child: Text('Misión: Cripta de Hielo',
                  style: DsText.body(DsColors.textPrimary))),
          SizedBox(height: DsSpace.sm),
          DsCard(
              selected: true,
              onTap: noop,
              child: Text('Misión: Bosque Antiguo',
                  style: DsText.body(DsColors.selected))),
          const DsSectionHeader('Avisos'),
          SizedBox(height: DsSpace.sm),
          DsToast('Equipaste Espada del Alba',
              kind: DsToastKind.success, onClose: noop),
          SizedBox(height: DsSpace.sm),
          const DsToast('+120 créditos', kind: DsToastKind.reward),
          SizedBox(height: DsSpace.sm),
          const DsToast('Inventario lleno', kind: DsToastKind.danger),
        ]),
      ),
      SizedBox(
        width: col,
        child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsSectionHeader('Tooltip'),
              SizedBox(height: 8),
              WeaponTooltip(),
            ]),
      ),
    ]);
  }
}
