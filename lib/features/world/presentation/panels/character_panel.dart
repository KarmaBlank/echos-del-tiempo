import 'package:material_ui/material_ui.dart';

import '../../../../app/feature_flags.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../app/theme/proto_colors.dart';
import '../../../../app/theme/proto_markup.dart';
import '../../../../app/theme/retro_text.dart';
import '../../../../game_engine/models/attributes.dart';
import '../../../../game_engine/models/game_session.dart';
import '../../../../game_engine/rules/progression_rules.dart';
import '../../../inventory/presentation/shop_sections.dart';
import '../../../passive_tree/presentation/passive_tree_view.dart';
import '../session_controller.dart';
import '../session_view.dart';

/// Nombre y efecto de cada atributo (`STATN`, `STATD` del prototipo).
const kAttributeInfo = {
  Attribute.vit: ('VIT', 'Vitalidad', '+4 vida máx.'),
  Attribute.esp: ('ESP', 'Espíritu', '+1.5 maná y poder mágico'),
  Attribute.agi: ('AGI', 'Agilidad', '+0.5 velocidad: turnos más seguidos'),
  Attribute.fue: ('FUE', 'Fuerza', 'daño de armas pesadas'),
  Attribute.des: (
    'DES',
    'Destreza',
    '+1.2% crítico, +0.1 velocidad, armas de precisión'
  ),
};

/// Pestañas del panel de personaje.
enum CharacterTab {
  attributes('ATRIBUTOS'),
  weapons('ARMAS'),
  tree('ÁRBOL');

  const CharacterTab(this.label);
  final String label;
}

/// Panel de personaje (`char` del prototipo, líneas 1298-1335): atributos
/// con vista previa del reparto, cambio de clase, armas y árbol de
/// pasivas. Se abre solo y no se puede cerrar mientras `mustAllocate`.
/// Ver docs/specs/panels.md § "Personaje".
class CharacterPanel extends StatefulWidget {
  const CharacterPanel({
    super.key,
    required this.view,
    required this.controller,
    this.initialTab = CharacterTab.attributes,
  });

  final SessionView view;
  final SessionController controller;
  final CharacterTab initialTab;

  @override
  State<CharacterPanel> createState() => _CharacterPanelState();
}

class _CharacterPanelState extends State<CharacterPanel> {
  final _alloc = <Attribute, int>{};
  late var _tab = widget.initialTab;

  int get _allocSum => _alloc.values.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final prof = view.me!.profile;
    final rules = widget.controller.engine.progression;
    final must = view.mustAllocate;
    final left = prof.points - _allocSum;
    final cls = rules.catalog.classes[prof.classId]?.name ?? prof.classId;
    // Durante la subida de nivel se reparte primero.
    final tab = must ? CharacterTab.attributes : _tab;

    final Widget body = switch (tab) {
      CharacterTab.attributes => _attributes(),
      CharacterTab.weapons => _weapons(),
      CharacterTab.tree => _tree(),
    };

    return PanelFrame(
      title: must
          ? '¡SUBISTE A NIVEL ${prof.level}! Reparte tus puntos'
          : 'PERSONAJE',
      width: 1000,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProtoText('${protoEsc(prof.name)} · $cls Lv${prof.level} · Puntos: '
              '<b>$left</b>'),
          const SizedBox(height: 8),
          if (!must)
            PanelTabs(
              labels: [for (final t in CharacterTab.values) t.label],
              index: tab.index,
              onChanged: (i) =>
                  setState(() => _tab = CharacterTab.values[i]),
            ),
        ],
      ),
      actions: [
        if (view.mode == SessionMode.prep)
          PanelButton('< VOLVER A PREPARACIÓN',
              onPressed: widget.controller.closePanel)
        else
          PanelButton('CERRAR [ESC]',
              onPressed: must ? null : widget.controller.closePanel),
      ],
      child: body,
    );
  }

  // ---------------- atributos ----------------

  Widget _attributes() {
    final view = widget.view;
    final prof = view.me!.profile;
    final c = widget.controller;
    final rules = c.engine.progression;
    final guards = ShopContext(view, c).guards;
    final left = prof.points - _allocSum;
    final now = rules.derivedStats(prof);
    final next = _allocSum == 0 ? now : rules.previewAllocation(prof, _alloc);
    final w = rules.equippedWeapon(prof);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final a in Attribute.values)
          _attrRow(a, prof.attributes[a], left),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _stat('HP', now.maxHp, next.maxHp),
            _stat('MP', now.maxMp, next.maxMp),
            _stat('VEL', now.speed, next.speed, (x) => x.toStringAsFixed(1)),
            Text(retroText('(6 + AGI×0.5 + DES×0.1 − peso arma '
                '${w.weight.toStringAsFixed(1)})'),
                style: const TextStyle(color: ProtoColors.dim)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _stat('ATQ', now.attack, next.attack),
            _stat('MAG', now.magic, next.magic),
            _stat('DEF', now.defense, next.defense),
            Text('(-${(now.defensePercent * 100).round()}% daño)',
                style: const TextStyle(color: ProtoColors.dim)),
            _stat('CRÍT', now.critChance, next.critChance,
                (x) => '${(x * 100).round()}%'),
            Text(
                retroText('(daño crítico ×'
                    '${now.critMultiplier == 2 ? '2' : '1.5'})'),
                style: const TextStyle(color: ProtoColors.dim)),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            PanelButton('CONFIRMAR PUNTOS',
                key: const ValueKey('confirm-points'),
                accent: ProtoColors.green,
                onPressed: _allocSum == 0 ? null : _confirm),
            if (guards.showRespec)
              PanelButton(
                  ProgressionRules.freeRespec
                      ? 'REINICIAR PUNTOS (GRATIS)'
                      : 'REINICIAR PUNTOS',
                  key: const ValueKey('respec'),
                  reason: guards.respec(),
                  onPressed: () {
                    if (c.respec()) setState(_alloc.clear);
                  }),
          ],
        ),
        if (view.mustAllocate) ...[
          const SizedBox(height: 8),
          const Text(
              'El equipo sigue cuando todos los que subieron de nivel '
              'confirmen sus puntos.',
              style: TextStyle(color: ProtoColors.dim)),
        ],
        PanelSection(
          'Clase',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final cl in rules.catalog.classes.values)
                if (FeatureFlags.instance.isCharacterAllowed(cl.id))
                  PanelButton(cl.name,
                      key: ValueKey('class-${cl.id}'),
                      selected: cl.id == prof.classId,
                      onPressed: cl.id == prof.classId ||
                              guards.changeClass(prof, cl.id) != null
                          ? null
                          : () {
                              if (c.changeClass(cl.id)) setState(_alloc.clear);
                            }),
              Text(
                retroText(view.mode == SessionMode.lobby
                    ? 'Cambiar de clase reinicia tus atributos y tu árbol.'
                    : 'Solo en el lobby'),
                style: const TextStyle(color: ProtoColors.dim),
              ),
            ],
          ),
        ),
        if (prof.classId == 'paladin')
          const PanelSection(
            'Kit de Paladín',
            child: Text(
              'Básico: 3% aturdir · Aura Restauradora (cura + regen 5% '
              'vida/maná × 3 turnos) · Fortaleza (+2 DEF por uso) · '
              'Protección (absorbes el daño de tus aliados)\n'
              'Débil a daño perforante (×1.5) y a estados (+1 stack)',
            ),
          ),
      ],
    );
  }

  Widget _stat(String label, num a, num b, [String Function(num)? fmt]) {
    final f = fmt ?? (num x) => '$x';
    final changed = (a - b).abs() > 1e-6;
    return Text.rich(
      key: ValueKey('stat-$label'),
      TextSpan(children: [
        TextSpan(text: retroText('$label ${f(a)}')),
        if (changed)
          TextSpan(
              text: ' → ${f(b)}',
              style: const TextStyle(
                  color: ProtoColors.green, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _attrRow(Attribute a, int value, int left) {
    final (short, name, desc) = kAttributeInfo[a]!;
    final add = _alloc[a] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 160, child: Text(retroText('$short $name'))),
          SizedBox(
            width: 72,
            child: ProtoText('$value'
                '${add > 0 ? ' ${protoColor(ProtoColors.green, '+$add')}' : ''}'),
          ),
          PanelButton('-',
              key: ValueKey('dec-${a.name}'),
              onPressed:
                  add > 0 ? () => setState(() => _alloc[a] = add - 1) : null),
          const SizedBox(width: 8),
          PanelButton('+',
              key: ValueKey('inc-${a.name}'),
              onPressed: left > 0
                  ? () => setState(() => _alloc[a] = add + 1)
                  : null),
          const SizedBox(width: 16),
          Expanded(
            child: Text(retroText(desc),
                style: const TextStyle(color: ProtoColors.dim)),
          ),
        ],
      ),
    );
  }

  void _confirm() {
    final add = {
      for (final e in _alloc.entries)
        if (e.value > 0) e.key: e.value,
    };
    if (widget.controller.allocate(add)) setState(_alloc.clear);
  }

  // ---------------- armas ----------------

  Widget _weapons() {
    final shop = ShopContext(widget.view, widget.controller);
    final p = shop.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OwnedWeaponsSection(shop: shop, pending: Map.of(_alloc)),
        PanelSection(
          'Consumibles',
          child: ProtoText('Poción de vida x${p.potions} · '
              'Poción de maná x${p.ethers} · Créditos: <b>₵${p.credits}</b>'),
        ),
        const SizedBox(height: 8),
        const Text(
            'Las armas se compran, mejoran y fusionan en la Armería del lobby '
            'o en la preparación.',
            style: TextStyle(color: ProtoColors.dim)),
      ],
    );
  }

  // ---------------- árbol ----------------

  Widget _tree() {
    final view = widget.view;
    final c = widget.controller;
    final p = view.me!.profile;
    final guards = ShopContext(view, c).guards;
    return PassiveTreeView(
      rules: c.engine.progression.treeRules,
      profile: p,
      inBattle: view.mode == SessionMode.battle,
      onTake: c.takeNode,
      showReset: guards.showRespec,
      resetLabel: ProgressionRules.freeRespec
          ? 'REINICIAR ÁRBOL (GRATIS)'
          : 'REINICIAR ÁRBOL',
      resetReason: guards.resetTree(p),
      onReset: c.resetTree,
    );
  }
}
