import '../../../../core/text/plain_text.dart';
import '../../../../core/text/text_detail.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/fishing_catalog.dart' show kRods;
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/rules/farming_rules.dart';
import '../../../../game_engine/rules/fishing_rules.dart';
import '../../../../game_engine/rules/life_tree_rules.dart';

/// Texto de un nodo con sus números del Balance (`{v}`, `{v2}`).
String lifeNodeText(LifeTreeNode n) {
  var out = n.text;
  var i = 0;
  for (final e in n.effects.entries) {
    final v = LifeTreeRules.t.d(e.value);
    final raw = e.key == LifeFx.quality || e.key == LifeFx.auto;
    final s = raw
        ? (v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(2))
        : '${(v * 100).round()}';
    out = out.replaceAll(i == 0 ? '{v}' : '{v2}', s);
    i++;
  }
  return out;
}

/// Pestaña OFICIOS de PERSONAJE (life_skill_trees.md § 5): un bloque por
/// oficio con nivel, barra de XP y su árbol de talentos.
class LifeSkillsView extends StatefulWidget {
  const LifeSkillsView(
      {super.key,
      required this.profile,
      this.editBlocked,
      required this.onTake,
      required this.onReset});

  final PlayerProfile profile;

  /// Por qué no se puede tocar ahora (p. ej. en batalla); `null` = se puede.
  final String? editBlocked;
  final void Function(LifeSkillKind k, String node) onTake;
  final void Function(LifeSkillKind k) onReset;

  @override
  State<LifeSkillsView> createState() => _LifeSkillsViewState();
}

class _LifeSkillsViewState extends State<LifeSkillsView> {
  LifeSkillKind _kind = LifeSkillKind.pesca;
  String? _sel;

  PlayerProfile get p => widget.profile;

  @override
  Widget build(BuildContext context) {
    // Tres columnas (v0.24.4): oficios | árbol | detalle del nodo, cada
    // una con su ancho, sin cortar nada.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 240,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final k in LifeSkillKind.values) ...[
                  _skillRow(k),
                  SizedBox(height: DsSpace.xs),
                ],
              ],
            ),
          ),
        ),
        SizedBox(width: DsSpace.md),
        Expanded(child: _tree()),
        SizedBox(width: DsSpace.md),
        SizedBox(width: 260, child: SingleChildScrollView(child: _detail())),
      ],
    );
  }

  Widget _skillRow(LifeSkillKind k) {
    final lvl = LifeTreeRules.level(p, k);
    final (cur, need) = switch (k) {
      LifeSkillKind.pesca => FishingRules.progress(p.life.fishXp),
      LifeSkillKind.cultivo => FarmingRules.progress(p.life.farm.xp),
      LifeSkillKind.herreria => SmithRules.progress(p.life.smithXp),
    };
    final free = LifeTreeRules.free(p, k);
    final tool = switch (k) {
      LifeSkillKind.pesca => kRods[p.life.rod]?.name ?? '',
      LifeSkillKind.cultivo =>
        '${kFarmTools[p.life.farm.hoe]?.name} · ${kFarmTools[p.life.farm.can]?.name}',
      LifeSkillKind.herreria => 'Forjar, encargos de forja y condensar',
    };
    // Tarjeta del oficio (v0.24.4): nombre y puntos libres arriba, el
    // nivel grande, la XP con lo que falta y la barra; todo entero.
    return DsCard(
      key: ValueKey('life-row-${k.name}'),
      selected: _kind == k,
      onTap: () => setState(() {
        _kind = k;
        _sel = null;
      }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(
                child: Text(k.label.toUpperCase(), style: DsText.subtitle())),
            if (free > 0)
              DsBadge('$free libre${free == 1 ? '' : 's'}',
                  key: ValueKey('life-free-${k.name}')),
          ]),
          SizedBox(height: DsSpace.xs),
          Text('Nivel $lvl',
              key: ValueKey('life-level-${k.name}'),
              style: DsText.title(DsColors.reward)),
          SizedBox(height: DsSpace.xs),
          Text(
              need > 0
                  ? '$cur / $need XP · faltan ${need - cur}'
                  : 'Nivel máximo',
              style: DsText.body()),
          SizedBox(height: DsSpace.xs),
          DsPercent(need > 0 ? (cur * 100 ~/ need) : 100,
              key: ValueKey('life-xp-${k.name}'),
              label: 'XP de ${k.label}',
              barWidth: 160),
          SizedBox(height: DsSpace.xs),
          Text(tool, style: DsText.detail()),
        ],
      ),
    );
  }

  Widget _detail() {
    final k = _kind;
    final nodes = kLifeTrees[k]!;
    final n = lifeTreeNode(k, _sel ?? '') ?? nodes.first;
    final has = LifeTreeRules.has(p, k, n.id);
    final why = widget.editBlocked ?? LifeTreeRules.cannotTake(p, k, n.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionHeader(n.name.toUpperCase(),
            trailing: Text(n.root ? 'Raíz' : 'costo ${n.cost}',
                style: DsText.detail())),
        Text(lifeNodeText(n),
            key: const ValueKey('life-node-text'), style: DsText.body()),
        if (n.exclusive != null)
          Text('Excluyente: elegí uno de su par.', style: DsText.detail()),
        Text(has ? 'Tomado' : why ?? 'Disponible', style: DsText.detail()),
        SizedBox(height: DsSpace.sm),
        Text(
            'Puntos libres ${LifeTreeRules.free(p, k)} · ganados '
            '${LifeTreeRules.earned(p, k)}',
            key: const ValueKey('life-points'),
            style: DsText.detail()),
        SizedBox(height: DsSpace.md),
        Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          DsButton('REINICIAR (GRATIS)',
              key: const ValueKey('life-reset'),
              size: DsButtonSize.compact,
              onPressed: widget.editBlocked != null ||
                      LifeTreeRules.taken(p, k).isEmpty
                  ? null
                  : () => widget.onReset(k)),
          if (!has)
            DsButton('TOMAR',
                key: const ValueKey('life-take'),
                kind: DsButtonKind.primary,
                size: DsButtonSize.compact,
                onPressed: why == null ? () => widget.onTake(k, n.id) : null),
        ]),
      ],
    );
  }

  Widget _tree() {
    final k = _kind;
    final nodes = kLifeTrees[k]!;
    return LayoutBuilder(builder: (context, box) {
      const cols = 5, rows = 6;
      final cell =
          (box.maxWidth / cols).clamp(0.0, box.maxHeight / rows).toDouble();
      Offset at(LifeTreeNode n) =>
          Offset((n.x + 2.5) * cell, (n.y + 0.5) * cell);
      return Center(
        child: SizedBox(
          width: cell * cols,
          height: cell * rows,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
                child: CustomPaint(painter: _Links(k, p, nodes, at))),
            for (final n in nodes) _node(k, n, at(n), cell),
          ]),
        ),
      );
    });
  }

  Widget _node(LifeSkillKind k, LifeTreeNode n, Offset c, double cell) {
    final size = (n.major || n.root ? 0.5 : 0.4) * cell;
    final has = LifeTreeRules.has(p, k, n.id);
    final open = !has && LifeTreeRules.cannotTake(p, k, n.id) == null;
    final sel = (_sel ?? nodes(k).first.id) == n.id;
    final accent = has ? DsColors.reward : DsColors.border;
    return Positioned(
      left: c.dx - cell * 0.5,
      top: c.dy - size / 2,
      width: cell,
      child: DsTooltip(
        // TEXTOS (ui_minimal.md § 8): corto en RESUMIDO, con el texto
        // completo en MÁS DETALLE.
        card: DsTooltipCard(title: n.name, detail: lifeNodeText(n), children: [
          Text(
              TextDetail.isSummary
                  ? plainShort(lifeNodeText(n))
                  : lifeNodeText(n),
              style: DsText.detail())
        ]),
        child: GestureDetector(
          key: ValueKey('life-node-${n.id}'),
          onTap: () => setState(() => _sel = n.id),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: has ? DsColors.reward : DsColors.surfaceSunken,
                border: Border.all(
                    color: sel
                        ? DsColors.focus
                        : open
                            ? DsColors.success
                            : accent,
                    width: sel || open ? 3 : 1),
              ),
              alignment: Alignment.center,
              child: Text(has || n.root ? '' : '${n.cost}',
                  style: DsText.detail(open ? DsColors.success : null)),
            ),
            SizedBox(height: DsSpace.xs),
            Text(n.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DsText.detail(has ? DsColors.textPrimary : null)),
          ]),
        ),
      ),
    );
  }

  static List<LifeTreeNode> nodes(LifeSkillKind k) => kLifeTrees[k]!;
}

class _Links extends CustomPainter {
  _Links(this.k, this.p, this.nodes, this.at);
  final LifeSkillKind k;
  final PlayerProfile p;
  final List<LifeTreeNode> nodes;
  final Offset Function(LifeTreeNode) at;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 2;
    for (final n in nodes) {
      for (final l in n.links) {
        final o = lifeTreeNode(k, l);
        if (o == null || o.id.compareTo(n.id) < 0) continue;
        final both =
            LifeTreeRules.has(p, k, n.id) && LifeTreeRules.has(p, k, o.id);
        paint.color = both ? DsColors.reward : DsColors.border;
        canvas.drawLine(at(n), at(o), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Links old) => old.p != p || old.k != k;
}
