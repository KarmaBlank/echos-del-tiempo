import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../game_engine/balance/balance_codecs.dart';
import '../../../game_engine/data/enemies_catalog.dart';
import '../../../game_engine/data/game_catalog.dart';
import '../../../game_engine/data/passive_tree_catalog.dart';
import '../../../game_engine/data/zones_catalog.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_state.dart';
import '../../../game_engine/rules/js_math.dart';
import '../../../game_engine/rules/zone_rules.dart';
import '../domain/admin_index.dart';
import '../domain/impact_preview.dart';
import '../../../game_engine/data/ults_v2_catalog.dart';
import 'admin_controller.dart';
import 'admin_widgets.dart';

/// Qué simular para una entidad (docs/specs/balance_admin.md § 5).
class _Plan {
  const _Plan({
    this.loadout,
    this.skillId,
    this.ultimate = false,
    this.attack = false,
    this.enemies = const [],
    this.elite = false,
    this.stats = false,
    this.note,
  });

  final SimLoadout? loadout;
  final String? skillId;
  final bool ultimate;

  /// Mostrar también el ataque básico.
  final bool attack;
  final List<String> enemies;
  final bool elite;

  /// Mostrar la hoja de stats (clases, armas, nodos).
  final bool stats;
  final String? note;
}

/// Vista previa de impacto con el motor real: daño de un uso al nivel X y
/// batallas simuladas, guardado (balance.json) vs borrador.
class ImpactPanel extends StatefulWidget {
  const ImpactPanel({super.key, required this.c, required this.entry});
  final AdminController c;
  final AdminEntry entry;

  @override
  State<ImpactPanel> createState() => _ImpactPanelState();
}

class _ImpactPanelState extends State<ImpactPanel> {
  (BattleSimResult, BattleSimResult)? sim;
  String? simHash;
  String? simError;

  AdminController get c => widget.c;

  _Plan _plan(GameCatalog cat) {
    final e = widget.entry;
    final kind = e.kind!;
    final sim = ImpactSimulator(cat);
    final level = c.previewLevel;
    final foes = List.filled(c.previewEnemyCount, c.previewEnemy);
    String family(String weaponId, String fallback) {
      final f = cat.weapons[weaponId]?.classId;
      return f != null && cat.classes.containsKey(f) ? f : fallback;
    }

    SimLoadout start(String cls, {List<String> nodes = const []}) => SimLoadout(
          classId: cls,
          level: level,
          weaponId: cat.classes[cls]!.startWeaponId,
          skillId: cat.weapons[cat.classes[cls]!.startWeaponId]!.skillIds.firstOrNull,
          takenNodes: nodes,
        );

    switch (kind) {
      case BalanceKind.skill:
        final w = sim.weaponFor(e.id);
        final cls = w != null
            ? family(w, c.previewClass)
            : sim.ascensionClassOf(e.id) ?? c.previewClass;
        final weaponId = w ?? cat.classes[cls]!.startWeaponId;
        return _Plan(
          loadout: SimLoadout(
              classId: cls,
              level: level,
              weaponId: weaponId,
              skillId: e.id,
              fusedSkillId: w == null ? e.id : null),
          skillId: e.id,
          enemies: foes,
          note: w == null
              ? 'No la otorga ningún arma: se prueba fusionada a ${cat.weapons[weaponId]!.name}.'
              : 'Con ${cat.weapons[weaponId]!.name} (${cat.classes[cls]!.name}).',
        );
      case BalanceKind.ultimate:
        // ULT v2 (ultimates_v2.md § 5.3): un arma y clase compatibles.
        if (kUltV2[e.id] case final u?) {
          final cls = u.classes.isNotEmpty ? u.classes.first : c.previewClass;
          final w = u.weapons.isNotEmpty
              ? sim.weaponOfType(u.weapons.first)
              : cat.classes[cls]?.startWeaponId;
          if (w == null) return const _Plan(note: 'Ningún arma compatible.');
          return _Plan(
            loadout: SimLoadout(
                classId: u.classes.isNotEmpty ? cls : family(w, cls),
                level: level,
                weaponId: w,
                ultSel: u.id),
            ultimate: true,
            enemies: foes,
            note: '${u.name} (${u.source.label}, costo ${u.cost}); la '
                'simulación la usa con la carga llena.',
          );
        }
        final w = sim.weaponOfType(e.id);
        if (w == null) return const _Plan(note: 'Ningún arma de este tipo.');
        return _Plan(
          loadout: SimLoadout(classId: family(w, c.previewClass), level: level, weaponId: w),
          ultimate: true,
          enemies: foes,
          note: 'ULT de ${cat.weapons[w]!.name}; la simulación la usa con la carga llena.',
        );
      case BalanceKind.weapon:
        final w = cat.weapons[e.id]!;
        return _Plan(
          loadout: SimLoadout(
              classId: family(e.id, c.previewClass),
              level: level,
              weaponId: e.id,
              skillId: w.skillIds.firstOrNull),
          skillId: w.skillIds.firstOrNull,
          attack: true,
          stats: true,
          enemies: foes,
        );
      case BalanceKind.enemy:
        return _Plan(
          loadout: start(c.previewClass),
          enemies: List.filled(c.previewEnemyCount, e.id),
          note: 'Nivel nativo del catálogo: ${kEnemyBaseLevel[e.id] ?? 1}. '
              'Se escala al nivel elegido.',
        );
      case BalanceKind.enemyUlt:
        // Furia Élite (respaldo) o la ULT de élite propia de un tipo
        // (ultimates_v2.md § 4.3).
        final eliteOwner = cat.enemies.values
            .where((x) => x.eliteUltId == e.id)
            .firstOrNull
            ?.id;
        final elite = e.id == kEliteUltId || eliteOwner != null;
        final owner = e.id == kEliteUltId
            ? c.previewEnemy
            : eliteOwner ??
                cat.enemies.values.where((x) => x.ultId == e.id).firstOrNull?.id;
        if (owner == null) return const _Plan(note: 'Ningún enemigo usa esta ULT.');
        return _Plan(
          loadout: start(c.previewClass),
          enemies: [owner],
          elite: elite,
          note: e.id == kEliteUltId
              ? 'Furia Élite: élite de ${cat.enemies[owner]!.name}.'
              : elite
                  ? 'La usa ${cat.enemies[owner]!.name} Élite.'
                  : 'La usa ${cat.enemies[owner]!.name}.',
        );
      case BalanceKind.classDef:
        return _Plan(loadout: start(e.id), attack: true, stats: true, enemies: foes);
      case BalanceKind.passiveNode:
        return _Plan(
          loadout: start(c.previewClass, nodes: [e.id]),
          stats: true,
          enemies: foes,
          note: 'Con el nodo tomado (sin camino) por ${cat.classes[c.previewClass]!.name}.',
        );
      case BalanceKind.mechanic:
        final node = kPassiveTree.nodes.values
            .where((n) => n.mechanicId == e.id)
            .firstOrNull;
        if (node == null) {
          return const _Plan(
              note: 'Mecánica de ascensión o de arma: sin vista previa automática.');
        }
        return _Plan(
          loadout: start(c.previewClass, nodes: [node.id]),
          enemies: foes,
          note: 'Con el nodo "${node.name}" tomado.',
        );
      case BalanceKind.affix:
      case BalanceKind.dual:
      case BalanceKind.reaction:
      case BalanceKind.elementStatus:
      case BalanceKind.abyssBoss:
      case BalanceKind.fragmentDrop:
      case BalanceKind.hitCap:
      case BalanceKind.combo:
      case BalanceKind.curve:
      // Ajustes de economía, mejora / carga de ULT y hazañas: sin
      // simulación de combate.
      case BalanceKind.ultLevel:
      case BalanceKind.ultUpgrade:
      case BalanceKind.ultCharge:
      case BalanceKind.condense:
      case BalanceKind.materials:
      case BalanceKind.ecoTier:
      case BalanceKind.featReward:
      case BalanceKind.consumables:
      case BalanceKind.travesia:
      case BalanceKind.exploration:
        return const _Plan();
    }
  }

  void _simulate() {
    setState(() => simError = null);
    try {
      final r = c.beforeAfter((cat) {
        final p = _plan(cat);
        return ImpactSimulator(cat).simulate(p.loadout!,
            enemies: p.enemies, enemyLevel: c.previewLevel, elite: p.elite);
      });
      setState(() {
        sim = r;
        simHash = c.validDraft.hash;
      });
    } on Object catch (e) {
      setState(() => simError = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.entry.kind!;
    final theme = Theme.of(context);
    final plan = _plan(c.draftCatalog);
    final enemies = [
      for (final e in c.base.catalog.enemies.values)
        if (!e.passive) e,
    ];
    return ListView(padding: const EdgeInsets.all(12), children: [
      Text('Impacto', style: theme.textTheme.titleLarge),
      Text('balance.json guardado → borrador, con el motor real',
          style: theme.textTheme.bodySmall),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        const Text('Nivel'),
        _MiniStepper(value: c.previewLevel, onChanged: (v) => c.setPreview(level: v)),
        SizedBox(
          width: 110,
          child: DropdownButton<String>(
            value: c.previewClass,
            isDense: true,
            isExpanded: true,
            items: [
              for (final cl in c.base.catalog.classes.values)
                DropdownMenuItem(
                    value: cl.id, child: Text(cl.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => c.setPreview(classId: v),
          ),
        ),
        SizedBox(
          width: 170,
          child: DropdownButton<String>(
            value: c.previewEnemy,
            isDense: true,
            isExpanded: true,
            items: [
              for (final e in enemies)
                DropdownMenuItem(
                    value: e.id, child: Text(e.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => c.setPreview(enemy: v),
          ),
        ),
        const Text('×'),
        _MiniStepper(value: c.previewEnemyCount, onChanged: (v) => c.setPreview(count: v)),
      ]),
      if (plan.note != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(plan.note!, style: theme.textTheme.bodySmall),
        ),
      const SizedBox(height: 8),
      if (kind == BalanceKind.affix) _affixPreview(),
      if (kind == BalanceKind.enemy) _enemyScaled(),
      if (kind == BalanceKind.dual)
        const Text('Los duales necesitan dos jugadores: sin vista previa automática.'),
      if (plan.loadout != null) ..._hits(plan),
      if (plan.loadout != null && plan.stats) _stats(plan),
      if (plan.loadout != null && plan.enemies.isNotEmpty) _simCard(plan),
    ]);
  }

  List<Widget> _hits(_Plan plan) {
    final rows = <Widget>[];
    void add(String label, {String? skill, bool ult = false}) {
      final (a, b) = c.beforeAfter((cat) => ImpactSimulator(cat).hit(
            _plan(cat).loadout!,
            enemyId: c.previewEnemy,
            skillId: skill,
            ultimate: ult,
          ));
      if (a == null || b == null) {
        rows.add(Text('$label: no se pudo usar (¿MP, carga o arma?)'));
        return;
      }
      rows
        ..add(BeforeAfter(label: '$label (sin crítico)', before: a.normal, after: b.normal))
        ..add(BeforeAfter(label: '$label (crítico)', before: a.crit, after: b.crit));
      if (skill != null && a.mp != b.mp) {
        rows.add(BeforeAfter(label: 'MP', before: a.mp, after: b.mp, higherIsBetter: false));
      }
    }

    if (plan.attack) add('Ataque');
    if (plan.skillId != null) {
      add(c.draftCatalog.skills[plan.skillId]?.name ?? plan.skillId!, skill: plan.skillId);
    }
    if (plan.ultimate) add('ULT', ult: true);
    if (rows.isEmpty) return const [];
    return [
      SectionCard(
        title: 'Daño de un uso · nivel ${c.previewLevel} vs '
            '${c.base.catalog.enemies[c.previewEnemy]?.name}',
        child: Column(children: [
          ...rows,
          const SizedBox(height: 4),
          Text('Por objetivo, contra un muñeco con la armadura del enemigo. '
              'Personaje típico: ⅔ de los puntos al atributo del arma, ⅓ a VIT.',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    ];
  }

  Widget _stats(_Plan plan) {
    final (a, b) = c.beforeAfter((cat) => ImpactSimulator(cat).statSheet(_plan(cat).loadout!));
    Widget row(String l, num Function(DerivedStats) f, {bool higher = true}) =>
        BeforeAfter(label: l, before: f(a), after: f(b), higherIsBetter: higher);
    return SectionCard(
      title: 'Stats del personaje típico',
      child: Column(children: [
        row('Vida', (s) => s.maxHp),
        row('MP', (s) => s.maxMp),
        row('ATQ', (s) => s.attack),
        row('MAG', (s) => s.magic),
        row('DEF', (s) => s.defense),
        row('Velocidad', (s) => s.speed),
        row('Crítico %', (s) => s.critChance * 100),
      ]),
    );
  }

  Widget _simCard(_Plan plan) {
    final r = sim;
    final stale = r != null && simHash != c.validDraft.hash;
    final enemyName = plan.enemies.isEmpty
        ? ''
        : '${plan.elite ? 'élite ' : ''}${c.base.catalog.enemies[plan.enemies.first]?.name}'
            '${plan.enemies.length > 1 ? ' ×${plan.enemies.length}' : ''}';
    return SectionCard(
      title: 'Batalla rápida (40 simuladas)',
      actions: [
        FilledButton.tonalIcon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Simular'),
          onPressed: _simulate,
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${c.base.catalog.classes[plan.loadout!.classId]?.name} nivel ${c.previewLevel} vs $enemyName '
            '(nivel ${c.previewLevel}). IA: ULT con carga, habilidad con MP, si no ataca.',
            style: Theme.of(context).textTheme.bodySmall),
        if (simError != null) Text(simError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (r != null) ...[
          if (stale)
            Text('El borrador cambió: volvé a simular.',
                style: TextStyle(color: Theme.of(context).colorScheme.tertiary)),
          BeforeAfter(
              label: 'Victorias',
              before: r.$1.winRate * 100,
              after: r.$2.winRate * 100,
              format: (n) => '${n.toStringAsFixed(0)}%'),
          BeforeAfter(
              label: 'Acciones para ganar (TTK)',
              before: r.$1.avgActions,
              after: r.$2.avgActions,
              higherIsBetter: false),
          BeforeAfter(
              label: 'Vida restante',
              before: r.$1.avgHpLeft * 100,
              after: r.$2.avgHpLeft * 100,
              format: (n) => '${n.toStringAsFixed(0)}%'),
          BeforeAfter(
              label: 'Daño por acción',
              before: r.$1.avgDamagePerAction,
              after: r.$2.avgDamagePerAction),
        ],
      ]),
    );
  }

  /// Vida y ATQ escalados al nivel elegido (1 jugador, sin élite).
  Widget _enemyScaled() {
    final id = widget.entry.id;
    final a = c.savedCatalog.enemies[id]!;
    final b = c.draftCatalog.enemies[id]!;
    final lv = c.previewLevel;
    final base = ZoneRules.baseLevel(id);
    final cv = c.draftCatalog.curve;
    final solo = cv.groupHp(1);
    final hf = solo *
        math.max(1.0, ZoneRules.hpScale(lv, cv) / ZoneRules.hpScale(base, cv));
    final af = math.max(1.0, ZoneRules.atkScale(lv, cv) / ZoneRules.atkScale(base, cv));
    return SectionCard(
      title: 'A nivel $lv (1 jugador)',
      child: Column(children: [
        BeforeAfter(
            label: 'Vida', before: jsRound(a.hp * 1.0 * hf), after: jsRound(b.hp * 1.0 * hf),
            higherIsBetter: false),
        BeforeAfter(
            label: 'ATQ',
            before: jsRound(a.attack * af),
            after: jsRound(b.attack * af),
            higherIsBetter: false),
        BeforeAfter(label: 'Velocidad', before: a.speed, after: b.speed, higherIsBetter: false),
        BeforeAfter(label: 'XP base', before: a.xp, after: b.xp),
      ]),
    );
  }

  Widget _affixPreview() {
    final id = widget.entry.id;
    final a = c.savedFields(BalanceKind.affix, id);
    final b = c.draftFields(BalanceKind.affix, id);
    double avg(Map<String, Object?> f) {
      final tiers = f['tiers'] as List;
      var w = 0.0, sum = 0.0;
      for (final t in tiers) {
        final m = t as Map;
        final tw = (m['weight'] as num).toDouble();
        w += tw;
        sum += tw * ((m['min'] as num) + (m['max'] as num)) / 2;
      }
      return w == 0 ? 0 : sum / w;
    }

    final def = c.base.affixes[id]!;
    return SectionCard(
      title: 'Afijo · ${def.slot == AffixSlot.prefix ? 'prefijo' : 'sufijo'} ${def.stat.name}',
      child: Column(children: [
        BeforeAfter(
            label: 'Peso de aparición',
            before: a['disabled'] == true ? 0 : a['weight'] as num,
            after: b['disabled'] == true ? 0 : b['weight'] as num),
        BeforeAfter(label: 'Valor medio (ponderado por tier)', before: avg(a), after: avg(b)),
        const SizedBox(height: 4),
        Text('Cambia los objetos que se tiren de ahora en más; los ya tirados conservan su valor.',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

class _MiniStepper extends StatelessWidget {
  const _MiniStepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove, size: 16),
            onPressed: () => onChanged(value - 1)),
        Text('$value'),
        IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add, size: 16),
            onPressed: () => onChanged(value + 1)),
      ]);
}
