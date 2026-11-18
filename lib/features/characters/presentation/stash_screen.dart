import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/loot.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/inventory_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../inventory/domain/item_text.dart';
import '../../inventory/presentation/item_widgets.dart';
import '../../world/presentation/session_controller.dart';
import '../domain/stash.dart';
import 'characters_providers.dart';

/// Pantalla `ALIJO COMPARTIDO` (fuera de la sesión): el inventario del
/// personaje [characterId] a la izquierda y el alijo de la cuenta a la
/// derecha. Clic elige, el botón (o doble clic) mueve al otro lado. Ver
/// docs/specs/characters.md § 3.
class StashScreen extends ConsumerStatefulWidget {
  const StashScreen({super.key, required this.characterId});

  final String characterId;

  static const cell = 44.0;
  static const gap = 4.0;

  @override
  ConsumerState<StashScreen> createState() => _StashScreenState();
}

/// Lado de la casilla elegida.
enum _Side { character, stash }

class _StashScreenState extends ConsumerState<StashScreen> {
  PlayerProfile? _raw;
  PlayerProfile? _p;
  Stash? _stash;
  int _tab = 0;

  _Side? _side;

  /// Token del personaje (uid o pila) o casilla del alijo.
  String? _selToken;
  int? _selCell;

  String? _error;
  bool _saving = false;

  /// Doble clic hecho a mano (sin esperar el timeout de `onDoubleTap`).
  DateTime? _lastTap;
  String? _lastTapKey;

  ProgressionRules get _rules => ref.read(sessionEngineProvider).progression;
  StashRules get _stashRules => StashRules(inventory: _rules.inventory);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await ref.read(accountRepositoryProvider).load();
    if (!mounted) return;
    final slot = a.byId(widget.characterId);
    setState(() {
      _raw = slot?.profile;
      _p = slot == null ? null : _rules.normalize(slot.profile);
      _stash = a.stash;
    });
  }

  /// El perfil a guardar, conservando el aviso de árbol reiniciado que
  /// `normalize` borra (lo muestra la sala al entrar).
  PlayerProfile _keepRefund(PlayerProfile next) {
    final refunded = _raw?.treeRefunded ?? 0;
    if (refunded <= 0) return next;
    return PlayerProfile.fromJson({...next.toJson(), 'tvRef': refunded});
  }

  void _clearSel() {
    _side = null;
    _selToken = null;
    _selCell = null;
  }

  Future<void> _commit(PlayerProfile p, Stash s) async {
    setState(() {
      _p = p;
      _stash = s;
      _error = null;
      _saving = true;
    });
    final save = _keepRefund(p);
    try {
      await ref
          .read(accountRepositoryProvider)
          .update((a) => a.replace(widget.characterId, save).withStash(s));
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo guardar: $e');
    }
    if (mounted) setState(() => _saving = false);
  }

  StashMove? _dryRun() {
    final p = _p, s = _stash;
    if (p == null || s == null || _side == null) return null;
    return _side == _Side.character
        ? _stashRules.deposit(p, s, _selToken!, tab: _tab)
        : _stashRules.withdraw(p, s, _selCell!);
  }

  Future<void> _move() async {
    final m = _dryRun();
    if (m == null) return;
    if (!m.ok) {
      setState(() => _error = m.error);
      return;
    }
    setState(_clearSel);
    await _commit(m.profile!, m.stash!);
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
    final p = _p;
    if (p == null) return;
    if (token == null) {
      // Casilla vacía: reordenar la grilla del personaje.
      if (_side == _Side.character && _selCell != null && cell != null) {
        final next = InventoryRules.move(p, _selCell!, cell);
        if (next != null) {
          setState(_clearSel);
          _commit(next, _stash!);
        }
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
    final s = _stash;
    if (s == null) return;
    if (s.cells[i] == null) {
      if (_side == _Side.stash && _selCell != null) {
        final next = StashRules.move(s, _selCell!, i);
        if (next != null) {
          setState(_clearSel);
          _commit(_p!, next);
        }
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

  // ------------------------------------------------------------------
  // Contenido de las casillas
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

  String _tooltip(PlayerProfile p, CellContent c, {bool equipped = false}) {
    final it = c.item;
    if (it != null) {
      return itemTooltipMarkup(_rules, it,
          level: p.level, attributes: p.attributes, equipped: equipped);
    }
    if (c.eco case final eco?) return ecoTooltipMarkup(_rules, eco);
    return stackTooltipMarkup(c.stack!, c.count);
  }

  static String _stashStackTooltip(CraftMaterial m, int n) =>
      '<b style="color:#78e6dc">${protoEsc(m.label)}</b> x$n<br>'
      '<span class="k">Material de fusión · en el alijo hasta '
      '${Stash.maxMaterialStack}</span><br>${protoEsc(m.description)}';

  Widget _cell({
    required Key key,
    required CellContent? content,
    required bool selected,
    required String? tooltip,
    required VoidCallback onTap,
  }) {
    Widget w = ItemCell(
        rules: _rules,
        content: content,
        selected: selected,
        // El borde dorado se confunde con el de un Raro: también el fondo.
        highlight: selected,
        size: StashScreen.cell);
    if (tooltip != null) w = RetroTooltip(message: tooltip, child: w);
    return GestureDetector(key: key, onTap: onTap, child: w);
  }

  static double _gridWidth(int columns) =>
      columns * StashScreen.cell + (columns - 1) * StashScreen.gap;

  Widget _grid(int columns, int count, Widget Function(int) build) => SizedBox(
        width: _gridWidth(columns),
        child: Wrap(
          spacing: StashScreen.gap,
          runSpacing: StashScreen.gap,
          children: [for (var i = 0; i < count; i++) build(i)],
        ),
      );

  Widget _characterSide(PlayerProfile p) {
    final cls = _rules.catalog.classes[p.classId]?.name ?? p.classId;
    final cells = InventoryRules.layout(p).cells;
    final eq = p.equippedItem;
    final eqContent = eq == null ? null : CellContent.item(eq);
    return SizedBox(
      width: _gridWidth(InventoryRules.columns),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(retroText('${p.name} · $cls · Nv ${p.level}'),
              style: const TextStyle(fontSize: 12, color: ProtoColors.ink)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Equipada:', style: TextStyle(color: ProtoColors.dim)),
              const SizedBox(width: 8),
              _cell(
                key: const ValueKey('stash-char-equipped'),
                content: eqContent,
                selected: _side == _Side.character &&
                    eq != null &&
                    _selToken == eq.uid,
                tooltip: eqContent == null
                    ? null
                    : _tooltip(p, eqContent, equipped: true),
                onTap: () => _tapCharacter(eq?.uid, null),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(retroText('Créditos: ₵${p.credits}'),
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: ProtoColors.gold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              'INVENTARIO (${InventoryRules.cellsUsed(p)}/${InventoryRules.cells})',
              style: const TextStyle(color: ProtoColors.dim)),
          const SizedBox(height: 8),
          _grid(InventoryRules.columns, InventoryRules.cells, (i) {
            final t = cells[i];
            final c = _charContent(p, t);
            return _cell(
              key: ValueKey('stash-char-$i'),
              content: c,
              selected: _side == _Side.character && t != null && _selToken == t,
              tooltip: c == null ? null : _tooltip(p, c),
              onTap: () => _tapCharacter(t, i),
            );
          }),
        ],
      ),
    );
  }

  Widget _stashSide(Stash s) {
    final base = _tab * Stash.perTab;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('ALIJO',
                style: TextStyle(fontSize: 12, color: ProtoColors.ink)),
            const SizedBox(width: 12),
            Text('${s.used}/${Stash.size}',
                key: const ValueKey('stash-used'),
                style: const TextStyle(color: ProtoColors.dim)),
          ],
        ),
        const SizedBox(height: 8),
        PanelTabs(
          labels: [for (var t = 0; t < Stash.tabs; t++) 'PESTAÑA ${t + 1}'],
          index: _tab,
          onChanged: (t) => setState(() => _tab = t),
        ),
        const SizedBox(height: 8),
        _grid(Stash.columns, Stash.perTab, (k) {
          final i = base + k;
          final e = s.cells[i];
          final c = _stashContent(e);
          return _cell(
            key: ValueKey('stash-cell-$i'),
            content: c,
            selected: _side == _Side.stash && _selCell == i,
            tooltip: e == null
                ? null
                : e.material != null
                    ? _stashStackTooltip(e.material!, e.count)
                    : _tooltip(_p!, c!),
            onTap: () => _tapStash(i),
          );
        }),
      ],
    );
  }

  /// Nombre de lo elegido (markup) para la línea de estado.
  String? _selectionMarkup() {
    final p = _p, s = _stash;
    if (p == null || s == null || _side == null) return null;
    final CellContent? c = _side == _Side.character
        ? _charContent(p, _selToken)
        : _stashContent(s.cells[_selCell!]);
    if (c == null) return null;
    final it = c.item;
    if (it != null) return itemNameMarkup(_rules, it);
    if (c.eco case final eco?) return ecoNameMarkup(_rules, eco);
    return '<b style="color:#78e6dc">${protoEsc(c.stack!.label)}</b> x${c.count}';
  }

  @override
  Widget build(BuildContext context) {
    final p = _p, s = _stash;
    Widget body;
    List<Widget> actions = [
      PanelButton('VOLVER',
          key: const ValueKey('stash-close'),
          onPressed: () => Navigator.of(context).maybePop()),
    ];
    if (p == null || s == null) {
      body =
          const Text('Cargando...', style: TextStyle(color: ProtoColors.dim));
    } else {
      final dry = _dryRun();
      final reason = dry == null
          ? 'Elige un objeto'
          : _saving
              ? 'Guardando...'
              : dry.error;
      actions = [
        ...actions,
        if (_side == _Side.stash)
          PanelButton('< AL PERSONAJE',
              key: const ValueKey('stash-withdraw'),
              reason: reason,
              onPressed: _move)
        else
          PanelButton('AL ALIJO >',
              key: const ValueKey('stash-deposit'),
              reason: reason,
              onPressed: _move),
      ];
      final sel = _selectionMarkup();
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _characterSide(p),
              const SizedBox(width: 40),
              _stashSide(s),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 20,
            child: _error != null
                ? Text(retroText(_error!),
                    key: const ValueKey('stash-error'),
                    style: const TextStyle(color: ProtoColors.red))
                : sel != null
                    ? ProtoText(sel)
                    : const Text(
                        'Armas y materiales se comparten entre tus '
                        'personajes. Créditos y pociones no.',
                        style: TextStyle(color: ProtoColors.dim)),
          ),
        ],
      );
    }
    return Scaffold(
      body: PanelFrame(
        key: const ValueKey('stash-screen'),
        title: 'ALIJO COMPARTIDO',
        width: 960,
        onClose: () => Navigator.of(context).maybePop(),
        help: 'Clic en una casilla para elegirla y el botón de abajo (o '
            'doble clic) para pasarla al otro lado. Con algo elegido, clic '
            'en una casilla vacía de su lado lo cambia de lugar.<br>'
            'No se guardan la <b>equipada</b>, la última <b>arma inicial</b> '
            'ni las pociones. Los materiales se apilan hasta '
            '${Stash.maxMaterialStack} en el alijo.',
        actions: actions,
        child: body,
      ),
    );
  }
}
