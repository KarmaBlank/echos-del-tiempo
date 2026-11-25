import 'package:material_ui/material_ui.dart';
import '../../inventory/domain/item_names.dart';

import '../../../app/design/design.dart';
import '../../../app/design/ds_layout_host.dart';
import '../../../core/layout/layout_catalog.dart';
import '../../../core/layout/layout_doc.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_hover_card.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/loot.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/inventory_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../inventory/domain/item_text.dart';
import '../../inventory/presentation/consumables_bar.dart';
import '../../inventory/presentation/inventory_action_menu.dart';
import '../../inventory/presentation/item_grid.dart';
import '../../inventory/presentation/item_hover_tip.dart';
import '../../inventory/presentation/item_widgets.dart';
import '../domain/stash.dart';
import 'character_strings.dart';
import 'stash_layout.dart';
import '../../inventory/domain/eco_text.dart';

/// Lo que el tablero del alijo necesita de quien lo abre: fuera de la
/// sesión, la cuenta directa ([StashScreen]); en partida, el
/// `SessionController` (que pasa por el anfitrión). Ver
/// docs/specs/characters.md § 3.
abstract class StashBoardHost {
  ProgressionRules get rules;
  PlayerProfile get profile;
  Stash get stash;

  /// Hay una operación en curso (guardando / esperando al anfitrión).
  bool get busy;

  /// Última línea de resultado del host (`Movidos N · ...`), si la hay.
  String? get notice;

  /// Guarda [tokens] (una operación). Devuelve el motivo si no se pudo.
  String? put(List<String> tokens, int tab);

  /// Saca las casillas [cells] (una operación).
  String? take(List<int> cells);

  bool moveStash(int from, int to);
  bool moveCharacter(int from, int to);

  /// Una hazaña que detecta el tablero (buscador con resultados, MOVER
  /// TODO; achievements.md § 5.2).
  void achievement(String id);
}

enum _Side { character, stash }

/// Tablero del alijo: el inventario a la izquierda, el alijo con sus 3
/// pestañas (2 generales + ECOS) a la derecha, cada lado con su
/// buscador. Clic elige, doble clic o el botón mueve, clic derecho abre
/// "Guardar en alijo" / "Sacar al inventario". MOVER TODO AL ALIJO y el
/// modo ELEGIR (varias casillas, una sola operación).
class StashBoard extends StatefulWidget {
  const StashBoard(
      {super.key,
      required this.host,
      this.title,
      this.layout,
      this.layoutCatalog,
      this.layoutHooks});

  final StashBoardHost host;

  /// Layout fijo (Editor → LAYOUT); si es `null`, el de [layoutCatalog]
  /// (por defecto `LayoutCatalog.instance`). editor_layout.md § 2.
  final LayoutDoc? layout;
  final LayoutCatalog? layoutCatalog;

  /// Ganchos del Editor (selección, arrastre); `null` en el juego.
  final DsLayoutHooks? layoutHooks;

  /// Encabezado del lado del personaje (nombre · clase · nivel).
  final String? title;

  static const cell = 44.0;
  static const gap = 4.0;

  /// String keys of the stash tabs.
  static const tabLabels = [
    'ui.characters.stash.tab_general_1',
    'ui.characters.stash.tab_general_2',
    'ui.characters.stash.tab_ecos',
  ];

  /// Ancho de una grilla de 8 columnas a escala 1.
  static const gridWidth = 8 * cell + 7 * gap;

  /// Separación entre los dos lados cuando van lado a lado.
  static const sideGap = 24.0;

  @override
  State<StashBoard> createState() => StashBoardState();
}

/// Disposición del alijo para un ancho [w] (characters.md § 3,
/// "Responsivo"): lado a lado si entran las dos grillas a escala 1 y
/// cada lado mide al menos [sideMin]; si no, apilado (inventario arriba,
/// alijo abajo). La escala de la casilla (44 × k) es la mayor que entra:
/// en cuartos hasta ×2 y, si ni ×1 entra, la que entre. Nunca más ancho
/// que [w] (sin scroll horizontal).
({bool wide, double scale}) stashLayout(double w, {double sideMin = 0}) {
  const base = StashBoard.gridWidth, sep = StashBoard.sideGap;
  final width = w.isFinite ? w : 2 * base + sep;
  double snap(double k) {
    if (k >= 2) return 2;
    if (k >= 1) return (k * 4).floorToDouble() / 4;
    return k > 0.3 ? k : 0.3;
  }

  final side = base > sideMin ? base : sideMin;
  if (width >= 2 * side + sep) {
    return (wide: true, scale: snap((width - sep) / 2 / base));
  }
  return (wide: false, scale: snap(width / base));
}

class StashBoardState extends State<StashBoard> {
  int _tab = 0;
  _Side? _side;
  String? _selToken;
  int? _selCell;

  bool _picking = false;
  final _pickedTokens = <String>[];
  final _pickedCells = <int>[];

  String _qChar = '';
  String _qStash = '';
  final _searchChar = TextEditingController();
  final _searchStash = TextEditingController();

  String? _error;

  /// Disposición y escala que elige [stashLayout] en el `LayoutBuilder`.
  bool _wide = true;
  double _scale = 1;
  double get _cellSize => StashBoard.cell * _scale;
  double get _gap => StashBoard.gap * _scale;

  DateTime? _lastTap;
  String? _lastTapKey;

  StashBoardHost get host => widget.host;
  Strings get _s => charStrings(context);
  ProgressionRules get _rules => host.rules;
  StashRules get _stashRules => StashRules(inventory: _rules.inventory);

  int get tab => _tab;
  set tab(int t) => setState(() => _tab = t);

  @override
  void dispose() {
    _searchChar.dispose();
    _searchStash.dispose();
    super.dispose();
  }

  void _clearSel() {
    _side = null;
    _selToken = null;
    _selCell = null;
  }

  StashMove? _dryRun() {
    if (_side == null) return null;
    return _side == _Side.character
        ? _stashRules.deposit(host.profile, host.stash, _selToken!, tab: _tab)
        : _stashRules.withdraw(host.profile, host.stash, _selCell!);
  }

  void _result(String? why) => setState(() => _error = why);

  void _move() {
    final m = _dryRun();
    if (m == null) return;
    if (!m.ok) return _result(m.error);
    final side = _side;
    final token = _selToken, cell = _selCell;
    setState(_clearSel);
    _result(side == _Side.character
        ? host.put([token!], _tab)
        : host.take([cell!]));
  }

  void _moveAll() {
    setState(_clearSel);
    final toks = _stashRules.movableTokens(host.profile);
    final why = host.put(toks, _tab);
    _result(why);
    if (why == null && toks.isNotEmpty) host.achievement('stash_move_all');
  }

  void _movePicked() {
    final toks = [..._pickedTokens], cells = [..._pickedCells];
    setState(_cancelPick);
    _result(toks.isNotEmpty ? host.put(toks, _tab) : host.take(cells));
  }

  void _cancelPick() {
    _picking = false;
    _pickedTokens.clear();
    _pickedCells.clear();
  }

  bool _isDouble(String key) {
    final now = DateTime.now();
    final dbl = _lastTapKey == key &&
        _lastTap != null &&
        now.difference(_lastTap!) < const Duration(milliseconds: 400);
    _lastTap = dbl ? null : now;
    _lastTapKey = dbl ? null : key;
    return dbl;
  }

  void _tapCharacter(String? token, int? cell) {
    if (_picking) {
      if (token == null) return;
      setState(() {
        _pickedCells.clear();
        if (!_pickedTokens.remove(token)) _pickedTokens.add(token);
        _error = null;
      });
      return;
    }
    if (token == null) {
      if (_side == _Side.character && _selCell != null && cell != null) {
        final from = _selCell!;
        setState(_clearSel);
        host.moveCharacter(from, cell);
      }
      return;
    }
    final dbl = _isDouble('c:$token');
    setState(() {
      _side = _Side.character;
      _selToken = token;
      _selCell = cell;
      _error = null;
    });
    if (dbl) _move();
  }

  void _tapStash(int i) {
    if (_picking) {
      if (host.stash.cells[i] == null) return;
      setState(() {
        _pickedTokens.clear();
        if (!_pickedCells.remove(i)) _pickedCells.add(i);
        _error = null;
      });
      return;
    }
    if (host.stash.cells[i] == null) {
      if (_side == _Side.stash && _selCell != null) {
        final from = _selCell!;
        setState(_clearSel);
        if (!host.moveStash(from, i)) _result(StashRules.ecoTabOnly);
      }
      return;
    }
    final dbl = _isDouble('s:$i');
    setState(() {
      _side = _Side.stash;
      _selCell = i;
      _selToken = null;
      _error = null;
    });
    if (dbl) _move();
  }

  void _menuCharacter(String token, int? cell, Offset at) {
    _tapCharacter(token, cell);
    final why = _stashRules
        .deposit(host.profile, host.stash, token, tab: _tab)
        .error;
    InventoryContextMenu.show(context, at, entries: [
      InventoryMenuEntry(
          id: 'stash-put',
          label: _s.t('ui.characters.stash.menu_put'),
          color: ProtoColors.sky,
          reason: why,
          onTap: _move),
    ]);
  }

  void _menuStash(int i, Offset at) {
    _tapStash(i);
    final why = _stashRules.withdraw(host.profile, host.stash, i).error;
    InventoryContextMenu.show(context, at, entries: [
      InventoryMenuEntry(
          id: 'stash-take',
          label: _s.t('ui.characters.stash.menu_take'),
          color: ProtoColors.sky,
          reason: why,
          onTap: _move),
    ]);
  }

  // ------------------------------------------------------------------
  // Contenido
  // ------------------------------------------------------------------

  CellContent? _charContent(PlayerProfile p, String? token) {
    if (token == null) return null;
    final st = StackKind.byToken(token);
    if (st != null) {
      return CellContent.stack(st, InventoryRules.stackCount(p, st));
    }
    final eco = p.ecoByUid(token);
    if (eco != null) return CellContent.eco(eco);
    final it = p.itemByUid(token);
    return it == null ? null : CellContent.item(it);
  }

  static CellContent? _stashContent(StashEntry? e) {
    if (e == null) return null;
    final it = e.item;
    if (it != null) return CellContent.item(it);
    if (e.eco case final eco?) return CellContent.eco(eco);
    return CellContent.stack(StackKind.of(e.material!), e.count);
  }

  String _name(CellContent c) {
    if (c.item case final it?) return localItemName(_rules.items, it);
    if (c.eco case final eco?) return ecoFullText(_rules.ecos, eco);
    return c.stack!.label;
  }

  static String _fold(String s) => s.toLowerCase().trim();

  bool _matches(CellContent? c, String q) {
    final hit =
        q.trim().isEmpty || (c != null && _fold(_name(c)).contains(_fold(q)));
    if (hit && c != null && q.trim().isNotEmpty) _searchFound();
    return hit;
  }

  bool _searchClaimed = false;
  void _searchFound() {
    if (_searchClaimed) return;
    _searchClaimed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) host.achievement('inv_search');
    });
  }

  String _tooltip(PlayerProfile p, CellContent c,
      {bool equipped = false, String? blocked}) {
    final it = c.item;
    String base;
    if (it != null) {
      base = itemTooltipMarkup(_rules, it,
          skillDetails: true,
          level: p.level,
          attributes: p.attributes,
          equipped: equipped);
    } else if (c.eco case final eco?) {
      base = ecoTooltipMarkup(_rules, eco);
    } else {
      base = stackTooltipMarkup(c.stack!, c.count);
    }
    if (blocked == null) return base;
    return '$base<br>${_blockedNote(blocked)}';
  }

  String _blockedNote(String blocked) => '<b style="color:#ff6b6b">'
      '${_s.t('ui.characters.stash.blocked', {'why': protoEsc(blocked)})}</b>';

  /// Zona de los tooltips de cada lado (ui_style.md § "Tooltips cortos"):
  /// desde el borde de arriba de su grilla hasta el pie de las dos
  /// grillas, y de ancho todo lo que hay de su lado sin llegar a la otra
  /// grilla; nunca tapa la otra grilla ni los botones.
  final _charGridKey = GlobalKey(debugLabel: 'stash-char-grid');
  final _stashGridKey = GlobalKey(debugLabel: 'stash-stash-grid');
  final _sidesKey = GlobalKey(debugLabel: 'stash-sides');

  /// Alto mínimo de la zona (si no, todo el alto de la pantalla).
  static const minTipAreaHeight = 200.0;

  Rect? _rectOf(GlobalKey k) {
    final b = k.currentContext?.findRenderObject();
    if (b is! RenderBox || !b.hasSize) return null;
    return b.localToGlobal(Offset.zero) & b.size;
  }

  Rect? _tipBounds({required bool character}) {
    final c = _rectOf(_charGridKey), s = _rectOf(_stashGridKey);
    final rr = _rectOf(_sidesKey);
    if (c == null || s == null || rr == null) return null;
    final own = character ? c : s;
    var top = own.top;
    var bottom = rr.bottom;
    if (bottom - top < minTipAreaHeight) {
      top = -double.maxFinite;
      bottom = double.maxFinite;
    }
    const gap = 4.0;
    if (!_wide) {
      // Apilado: el inventario va de su grilla hasta antes de la del
      // alijo; el alijo, de su grilla al pie. Todo el ancho.
      return character
          ? Rect.fromLTRB(-double.maxFinite, c.top, double.maxFinite,
              s.top - gap)
          : Rect.fromLTRB(
              -double.maxFinite, s.top, double.maxFinite, rr.bottom);
    }
    return character
        ? Rect.fromLTRB(-double.maxFinite, top, s.left - gap, bottom)
        : Rect.fromLTRB(c.right + gap, top, double.maxFinite, bottom);
  }

  String _stashStackTooltip(CraftMaterial m, int n) =>
      '<b style="color:#78e6dc">${protoEsc(m.label)}</b> x$n<br>'
      '<span class="k">${_s.t('ui.characters.stash.material_note', {
            'max': Stash.maxMaterialStack
          })}</span><br>${protoEsc(m.description)}';

  /// Ficha de una casilla: la misma del inventario para armas
  /// (characters.md § 3); markup simple para pilas y Ecos.
  Widget _tip(CellContent? content, Widget child,
      {String? tooltip,
      PlayerProfile? viewer,
      bool equipped = false,
      bool focused = false,
      String? blocked}) {
    final it = content?.item;
    if (it != null && viewer != null) {
      return itemHoverTip(
          rules: _rules,
          viewer: viewer,
          item: it,
          attributes: viewer.attributes,
          equipped: equipped,
          focused: focused,
          note: blocked == null ? null : _blockedNote(blocked),
          child: child);
    }
    if (tooltip != null) {
      return RetroTooltip(
          message: tooltip, keyboardFocus: focused, child: child);
    }
    return child;
  }

  /// Casilla suelta (la EQUIPADA): la misma molécula de la grilla.
  Widget _cell({
    required Key key,
    required CellContent? content,
    required bool selected,
    required VoidCallback onTap,
    PlayerProfile? viewer,
    bool equipped = false,
    String? blocked,
  }) =>
      GestureDetector(
          key: key,
          onTap: onTap,
          child: _tip(
              content,
              ItemSlot(
                  rules: _rules,
                  size: _cellSize,
                  data: ItemSlotData(
                      content: content,
                      selected: selected,
                      highlight: selected)),
              viewer: viewer,
              equipped: equipped,
              blocked: blocked));

  double _gridWidth(int columns) =>
      columns * _cellSize + (columns - 1) * _gap;

  bool _charSelected(String? t) =>
      t != null &&
      (_picking
          ? _pickedTokens.contains(t)
          : _side == _Side.character && _selToken == t);

  /// Slots del lado del personaje (StashLayout.spec).
  Widget? _title() => widget.title == null
      ? null
      : Text(retroText(widget.title!), style: DsText.title());

  Widget _equipped(PlayerProfile p) {
    final eq = p.equippedItem;
    final eqContent = eq == null ? null : CellContent.item(eq);
    return Wrap(
        spacing: DsSpace.sm,
        runSpacing: DsSpace.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(retroText(_s.t('ui.characters.stash.equipped')),
              style: DsText.subtitle()),
          _cell(
            key: const ValueKey('stash-char-equipped'),
            content: eqContent,
            selected: _charSelected(eq?.uid),
            viewer: p,
            equipped: true,
            blocked: eq == null ? null : _stashRules.blocked(p, eq.uid),
            onTap: () => _tapCharacter(eq?.uid, null),
          ),
          Text(
              retroText(_s.t('ui.characters.stash.credits',
                  {'amount': '₵${p.credits}'})),
              style: DsText.body(DsColors.reward)),
        ]);
  }

  Widget _inventoryLabel(PlayerProfile p) => Text(
      _s.t('ui.characters.stash.inventory', {
        'used': InventoryRules.cellsUsed(p),
        'total': InventoryRules.cells,
      }),
      style: DsText.detail());

  Widget _searchCharField() => KeyedSubtree(
        key: const ValueKey('stash-search-char'),
        child: DsSearchField(
          hint: _s.t('ui.characters.stash.search_inventory'),
          width: 260,
          controller: _searchChar,
          onChanged: (v) => setState(() => _qChar = v),
        ),
      );

  Widget _inventoryGrid(PlayerProfile p) {
    final cells = InventoryRules.layout(p).cells;
    return RetroTipArea(
        bounds: () => _tipBounds(character: true),
        child: KeyedSubtree(
            key: _charGridKey,
            child: DsItemGrid(
              rules: _rules,
              count: InventoryRules.cells,
              columns: InventoryRules.columns,
              cellSize: _cellSize,
              gap: _gap,
              width: _gridWidth(InventoryRules.columns),
              cellKey: (i) => ValueKey('stash-char-$i'),
              slot: (i) {
                final t = cells[i];
                final c = _charContent(p, t);
                final sel = _charSelected(t);
                return ItemSlotData(
                    content: c,
                    selected: sel,
                    highlight: sel,
                    dimmed: c != null && !_matches(c, _qChar));
              },
              tip: (i, child, focused) {
                final t = cells[i]!;
                final c = _charContent(p, t)!;
                final blocked = _stashRules.blocked(p, t);
                return _tip(c, child,
                    tooltip: _tooltip(p, c, blocked: blocked),
                    viewer: p,
                    focused: focused,
                    blocked: blocked);
              },
              onTap: (i) => _tapCharacter(cells[i], i),
              onMenu: (i, at) => _menuCharacter(cells[i]!, i, at),
            )));
  }

  // Los materiales no ocupan casilla (loot.md § 17.1); las pociones se ven
  // pero no van al alijo.
  Widget _stacks(PlayerProfile p) => InventoryStacksBar(
        rules: _rules,
        profile: p,
        cell: _cellSize,
        gap: _gap,
        selected: _picking
            ? (_pickedTokens.isEmpty ? null : _pickedTokens.last)
            : _side == _Side.character
                ? _selToken
                : null,
        onSelect: (t) => _tapCharacter(t, null),
      );

  int _tabUsed(Stash s, int t) {
    var n = 0;
    for (var i = t * Stash.perTab; i < (t + 1) * Stash.perTab; i++) {
      if (s.cells[i] != null) n++;
    }
    return n;
  }

  /// Una pestaña del alijo con el estilo de `DsTabBar` (texto dorado y
  /// subrayado la elegida).
  Widget _tabButton(Stash s, int t) {
    final on = t == _tab;
    return MouseRegion(
      key: ValueKey('tab-$t'),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _tab = t),
        child: Container(
          constraints: BoxConstraints(
              minHeight: RetroType.width(context, DsMetrics.minHeight)),
          padding: EdgeInsets.symmetric(horizontal: DsSpace.md),
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: on ? DsColors.selected : Colors.transparent,
                      width: 3))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(retroText(_s.t(StashBoard.tabLabels[t])),
                style: DsText.subtitle(on ? DsColors.selected : DsColors.text)),
            SizedBox(width: DsSpace.sm),
            DsBadge('${_tabUsed(s, t)}/${Stash.perTab}'),
          ]),
        ),
      ),
    );
  }

  /// Slots del lado del alijo (StashLayout.spec).
  Widget _stashHeader(Stash s) => Wrap(
          spacing: DsSpace.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(_s.t('ui.characters.stash.title'), style: DsText.title()),
            Text('${s.used}/${Stash.size}',
                key: const ValueKey('stash-used'), style: DsText.detail()),
          ]);

  // Pestañas en un Wrap (no el TabBar desplazable): con texto grande bajan
  // de línea en vez de salirse del panel.
  Widget _stashTabs(Stash s) => Wrap(
        spacing: DsSpace.xs,
        runSpacing: DsSpace.xs,
        children: [
          for (var t = 0; t < Stash.tabs; t++) _tabButton(s, t),
        ],
      );

  Widget _searchStashField() => KeyedSubtree(
        key: const ValueKey('stash-search-stash'),
        child: DsSearchField(
          hint: _s.t('ui.characters.stash.search_stash'),
          width: 260,
          controller: _searchStash,
          onChanged: (v) => setState(() => _qStash = v),
        ),
      );

  Widget _stashGrid(PlayerProfile p, Stash s) {
    final base = _tab * Stash.perTab;
    return RetroTipArea(
        bounds: () => _tipBounds(character: false),
        child: KeyedSubtree(
            key: _stashGridKey,
            child: DsItemGrid(
              rules: _rules,
              count: Stash.perTab,
              columns: Stash.columns,
              cellSize: _cellSize,
              gap: _gap,
              width: _gridWidth(Stash.columns),
              cellKey: (k) => ValueKey('stash-cell-${base + k}'),
              slot: (k) {
                final i = base + k;
                final c = _stashContent(s.cells[i]);
                final sel = _picking
                    ? _pickedCells.contains(i)
                    : _side == _Side.stash && _selCell == i;
                return ItemSlotData(
                    content: c,
                    selected: sel,
                    highlight: sel,
                    dimmed: c != null && !_matches(c, _qStash));
              },
              tip: (k, child, focused) {
                final e = s.cells[base + k]!;
                final c = _stashContent(e)!;
                return _tip(c, child,
                    tooltip: e.material != null
                        ? _stashStackTooltip(e.material!, e.count)
                        : _tooltip(p, c),
                    viewer: p,
                    focused: focused);
              },
              onTap: (k) => _tapStash(base + k),
              onMenu: (k, at) => _menuStash(base + k, at),
            )));
  }

  Widget? _ecoNote() => _tab == Stash.ecoTab
      ? Text(_s.t('ui.characters.stash.eco_note'),
          style: DsText.detail())
      : null;

  String? _selectionMarkup(PlayerProfile p, Stash s) {
    if (_side == null) return null;
    final CellContent? c = _side == _Side.character
        ? _charContent(p, _selToken)
        : _stashContent(s.cells[_selCell!]);
    if (c == null) return null;
    final it = c.item;
    if (it != null) return itemNameMarkup(_rules, it);
    if (c.eco case final eco?) return ecoNameMarkup(_rules, eco);
    return '<b style="color:#78e6dc">${protoEsc(c.stack!.label)}</b> x${c.count}';
  }

  /// Slots de la fila de acciones (grupo `stash.actions`). En el modo
  /// ELEGIR: cuenta + MOVER ELEGIDOS en el lugar de la transferencia y
  /// CANCELAR en el de MOVER TODO.
  Widget _transfer() {
    final busy = host.busy;
    final wait = busy ? _s.t('ui.characters.stash.waiting') : null;
    if (_picking) {
      final n = _pickedTokens.length + _pickedCells.length;
      final toStash = _pickedCells.isEmpty;
      return Wrap(
          spacing: DsSpace.sm,
          runSpacing: DsSpace.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(_s.t('ui.characters.stash.picked', {'n': n}),
                key: const ValueKey('stash-picked'), style: DsText.body()),
            DsButton(
                _s.t(toStash
                    ? 'ui.characters.stash.move_picked'
                    : 'ui.characters.stash.take_picked'),
                key: const ValueKey('stash-move-picked'),
                kind: DsButtonKind.primary,
                tooltip: wait ??
                    (n == 0 ? _s.t('ui.characters.stash.pick_cells') : null),
                onPressed: n == 0 || busy ? null : _movePicked),
          ]);
    }
    final dry = _dryRun();
    final reason =
        wait ?? (dry == null ? _s.t('ui.characters.stash.pick_item') : dry.error);
    return _side == _Side.stash
        ? DsButton(_s.t('ui.characters.stash.to_inventory'),
            key: const ValueKey('stash-withdraw'),
            kind: DsButtonKind.primary,
            tooltip: reason,
            onPressed: reason == null ? _move : null)
        : DsButton(_s.t('ui.characters.stash.to_stash'),
            key: const ValueKey('stash-deposit'),
            kind: DsButtonKind.primary,
            tooltip: reason,
            onPressed: reason == null ? _move : null);
  }

  Widget _moveAllButton(PlayerProfile p) {
    if (_picking) {
      return DsButton(_s.t('ui.characters.common.cancel'),
          key: const ValueKey('stash-pick-cancel'),
          onPressed: () => setState(_cancelPick));
    }
    final busy = host.busy;
    final all = _stashRules.movableTokens(p);
    return DsButton(_s.t('ui.characters.stash.move_all'),
        key: const ValueKey('stash-move-all'),
        tooltip: _s.t(busy
            ? 'ui.characters.stash.waiting'
            : all.isEmpty
                ? 'ui.characters.stash.move_all_none'
                : 'ui.characters.stash.move_all_hint'),
        onPressed: all.isEmpty || busy ? null : _moveAll);
  }

  Widget? _pickButton() => _picking
      ? null
      : DsButton(_s.t('ui.characters.stash.pick'),
          key: const ValueKey('stash-pick'),
          tooltip: _s.t('ui.characters.stash.pick_tooltip'),
          onPressed: () => setState(() {
                _clearSel();
                _picking = true;
                _error = null;
              }));

  Widget _status(PlayerProfile p, Stash s) {
    final sel = _selectionMarkup(p, s);
    final dry = _dryRun();
    final line = _error ?? (dry != null && !dry.ok ? dry.error : null);
    final notice = host.notice;
    return SizedBox(
      height: RetroType.line *
          MediaQuery.textScalerOf(context).scale(RetroType.small),
      child: line != null
          ? Text(retroText(line),
              key: const ValueKey('stash-error'),
              style: DsText.body(DsColors.danger))
          : notice != null
              ? Text(retroText(notice),
                  key: const ValueKey('stash-notice'),
                  style: DsText.body(DsColors.success))
              : sel != null
                  ? ProtoText(sel)
                  : Text(_s.t('ui.characters.stash.shared_note'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsText.detail()),
    );
  }

  Map<String, DsSlotBuilder> _slots(PlayerProfile p, Stash s) => {
        StashLayout.title: (_) => _title(),
        StashLayout.equipped: (_) => _equipped(p),
        StashLayout.inventoryLabel: (_) => _inventoryLabel(p),
        StashLayout.searchChar: (_) => _searchCharField(),
        StashLayout.inventoryGrid: (_) => _inventoryGrid(p),
        StashLayout.stacks: (_) => _stacks(p),
        StashLayout.stashHeader: (_) => _stashHeader(s),
        StashLayout.stashTabs: (_) => _stashTabs(s),
        StashLayout.searchStash: (_) => _searchStashField(),
        StashLayout.stashGrid: (_) => _stashGrid(p, s),
        StashLayout.ecoNote: (_) => _ecoNote(),
        StashLayout.transfer: (_) => _transfer(),
        StashLayout.moveAll: (_) => _moveAllButton(p),
        StashLayout.pick: (_) => _pickButton(),
        StashLayout.status: (_) => _status(p, s),
      };

  /// El template del alijo: encabezado opcional, los dos lados (lado a
  /// lado o apilados según [stashLayout]) y el pie.
  Widget _frame(BuildContext context, BoxConstraints box, DsRegions r) {
    // Cada lado pide, además de la grilla, lugar para su texto (buscador,
    // encabezados) según el tamaño de letra.
    final l = stashLayout(box.maxWidth, sideMin: RetroType.width(context, 300));
    _wide = l.wide;
    _scale = l.scale;
    final left = SizedBox(
        width: _gridWidth(InventoryRules.columns), child: r.region('left'));
    final right =
        SizedBox(width: _gridWidth(Stash.columns), child: r.region('right'));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!r.isEmpty('header')) ...[
          r.region('header'),
          SizedBox(height: DsSpace.md),
        ],
        _wide
            ? Row(
                key: _sidesKey,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  left,
                  const SizedBox(width: StashBoard.sideGap),
                  right,
                ],
              )
            : Column(
                key: _sidesKey,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [left, SizedBox(height: DsSpace.lg), right],
              ),
        if (!r.isEmpty('footer')) ...[
          SizedBox(height: DsSpace.md),
          r.region('footer'),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = host.profile, s = host.stash;
    return MenuTabKeys(
      count: Stash.tabs,
      index: _tab,
      onChanged: (t) => setState(() => _tab = t),
      child: DsLayoutHost(
        spec: StashLayout.spec,
        doc: widget.layout,
        catalog: widget.layoutCatalog,
        hooks: widget.layoutHooks,
        slots: _slots(p, s),
        frame: _frame,
      ),
    );
  }
}
