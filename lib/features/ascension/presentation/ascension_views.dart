import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/data/ascension_catalog.dart';
import '../../../game_engine/data/classes_catalog.dart';
import '../../../game_engine/data/skills_catalog.dart';
import '../../../game_engine/models/ascension.dart';
import '../../../game_engine/rules/ascension_rules.dart';
import '../../combat/domain/skill_text.dart';
import '../../combat/presentation/game_sprites.dart';
import '../../combat/presentation/pixel_sprite.dart';
import '../domain/ascension_text.dart';

/// Ficha de una ascensión (markup): tema, kit y nodo raíz.
String ascensionCardMarkup(AscensionDef a) {
  final hex = ascensionHex(a);
  final skills = [
    for (final id in a.skillIds)
      if (kSkills[id] case final s?) s,
  ];
  final ult = kAscensionUltimatesById[a.ultId];
  final root = a.node(a.rootId);
  return '<b style="color:$hex">${protoEsc(a.name.toUpperCase())}</b><br>'
      '${protoColor(ProtoColors.dim, protoEsc(a.theme))}<br>'
      '${protoColor(ProtoColors.cream, protoEsc(a.motto))}<br><br>'
      '<b>Despertar:</b> ${protoEsc(root?.name ?? '')}<br>'
      '${protoEsc(root?.text ?? '')}<br><br>'
      '<b>Kit</b><br>'
      '${[
    for (final s in skills)
      '· <b>${protoEsc(s.name)}</b> ${protoColor(ProtoColors.ice, '${s.mp} MP')}',
    if (ult != null)
      '· ${protoColor(ProtoColors.pink, '★ ULT ${protoEsc(ult.name)}')}',
  ].join('<br>')}';
}

/// El sprite del héroe ascendido (o el base si no hay arte) con su aura.
class AscendedHero extends StatelessWidget {
  const AscendedHero({
    super.key,
    required this.sprites,
    required this.classId,
    required this.ascensionId,
    this.scale = 4,
  });

  final GameSprites? sprites;
  final String classId;
  final String? ascensionId;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final img = sprites?.heroFor(classId, ascensionId);
    final aura = sprites?.aura(ascensionId);
    final a = ascensionFor(classId, ascensionId);
    return SizedBox(
      width: 26 * scale,
      height: 28 * scale,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (aura != null)
            Positioned(
              bottom: 0,
              child: PixelSprite(aura, scale: scale, opacity: 0.8),
            )
          else if (a != null)
            Positioned(
              bottom: 0,
              child: Container(
                width: 20 * scale,
                height: 24 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(a.color).withValues(alpha: 0.18),
                ),
              ),
            ),
          if (img != null)
            Positioned(
              bottom: scale,
              child: PixelSprite(img, scale: scale),
            ),
        ],
      ),
    );
  }
}

/// Las 2 ascensiones de una clase para elegir (§ 2): dos tarjetas con el
/// héroe ascendido, la ficha y ELEGIR.
class AscensionChoiceView extends StatelessWidget {
  const AscensionChoiceView({
    super.key,
    required this.classId,
    required this.sprites,
    required this.onChoose,
    this.blocked,
  });

  final String classId;
  final GameSprites? sprites;
  final ValueChanged<String> onChoose;

  /// Por qué no se puede elegir (botones deshabilitados).
  final String? blocked;

  @override
  Widget build(BuildContext context) {
    final options = ascensionsOf(classId);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, a) in options.indexed) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: _card(a)),
        ],
      ],
    );
  }

  Widget _card(AscensionDef a) {
    final col = Color(a.color);
    return Container(
      key: ValueKey('asc-card-${a.id}'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.06),
        border: Border.all(color: col, width: RetroTheme.thinBorderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: AscendedHero(
                sprites: sprites, classId: classId, ascensionId: a.id),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: ProtoText(ascensionCardMarkup(a)),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: PanelButton('ELEGIR ${a.name.toUpperCase()}',
                key: ValueKey('asc-choose-${a.id}'),
                accent: col,
                reason: blocked,
                onPressed: () => onChoose(a.id)),
          ),
        ],
      ),
    );
  }
}

/// El mini-árbol de 8 nodos (§ 3) con la ficha del nodo elegido.
class AscensionTreeView extends StatefulWidget {
  const AscensionTreeView({
    super.key,
    required this.def,
    required this.progress,
    this.sprites,
    this.editBlocked,
    this.onTake,
    this.onReset,
    this.onChange,
  });

  final AscensionDef def;
  final AscensionProgress progress;
  final GameSprites? sprites;
  final String? editBlocked;
  final ValueChanged<String>? onTake;
  final VoidCallback? onReset;

  /// Sacar la ascensión (volver a elegir); `null` = no se puede ahora.
  final VoidCallback? onChange;

  /// Columnas (−1..1) y filas (0..4) del lienzo.
  static const cols = 3, rows = 5;

  @override
  State<AscensionTreeView> createState() => _AscensionTreeViewState();
}

class _AscensionTreeViewState extends State<AscensionTreeView> {
  static const _rules = AscensionRules();
  String? _sel;

  AscensionProgress get p => widget.progress;
  AscensionDef get a => widget.def;

  String? _why(AscensionNode n) {
    if (_rules.has(p, n.id)) return null;
    final free = _rules.free(p);
    if (free < n.cost) return 'Faltan puntos ($free/${n.cost})';
    if (!n.links.any((l) => _rules.has(p, l))) return 'No está conectado';
    return null;
  }

  String _state(AscensionNode n) => _rules.has(p, n.id)
      ? (n.root ? 'Despertado al ascender' : 'Tomado')
      : _why(n) ?? 'Disponible';

  @override
  Widget build(BuildContext context) {
    final node = a.node(_sel ?? '') ?? a.node(a.rootId)!;
    final col = Color(a.color);
    final taken = _rules.has(p, node.id);
    final why = widget.editBlocked ?? _why(node);
    final cls = kClasses[a.classId]?.name ?? a.classId;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            // Una columna de margen para los nombres.
            final cell = (box.maxWidth / (AscensionTreeView.cols + 1))
                .clamp(0.0, box.maxHeight / AscensionTreeView.rows)
                .toDouble();
            final w = cell * AscensionTreeView.cols,
                h = cell * AscensionTreeView.rows;
            Offset at(AscensionNode n) =>
                Offset((n.x + 1.5) * cell, (n.y + 0.5) * cell);
            return Center(
              child: SizedBox(
                width: w,
                height: h,
                child: Stack(
                  // Los nombres de las ramas se salen del ancho de 3 celdas.
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                          painter: _TreeLinks(a, p, at, col)),
                    ),
                    for (final n in a.nodes) _node(n, at(n), cell, col),
                    for (final n in a.nodes) _label(n, at(n), cell),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 340,
          child: PanelDetail(
            footer: [
              if (!taken)
                PanelButton('TOMAR',
                    key: const ValueKey('asc-take'),
                    accent: ProtoColors.green,
                    reason: why,
                    onPressed: () => widget.onTake?.call(node.id)),
            ],
            children: [
              Row(
                children: [
                  AscendedHero(
                      sprites: widget.sprites,
                      classId: a.classId,
                      ascensionId: a.id,
                      scale: 2),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ProtoText(
                        '<b style="color:${ascensionHex(a)}">'
                        '${protoEsc(a.name.toUpperCase())}</b><br>'
                        '${protoColor(ProtoColors.dim, '${protoEsc(cls)} · ${protoEsc(a.theme)}')}'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ProtoText(
                  key: const ValueKey('asc-points'),
                  'Puntos libres <b>${_rules.free(p)}</b> · ganados '
                  '${p.earned}/${3 * AscensionProgress.pointsPerTrial}'),
              const SizedBox(height: 8),
              ProtoText(
                  key: const ValueKey('asc-node-detail'),
                  '<b>${protoEsc(node.name)}</b>'
                  '${node.major ? ' ${protoColor(ProtoColors.pink, '(mayor)')}' : ''}<br>'
                  '${node.root ? protoColor(ProtoColors.gold, 'Raíz') : 'costo ${node.cost}'}<br>'
                  '${protoEsc(node.text)}<br>'
                  '${protoColor(ProtoColors.dim, protoEsc(_state(node)))}'),
              if (node.root) ...[
                const SizedBox(height: 8),
                for (final id in a.skillIds)
                  if (kSkills[id] case final s?)
                    ProtoText(describeSkillMarkup(s, null)),
                if (kAscensionUltimatesById[a.ultId] case final u?)
                  ProtoText(describeSkillMarkup(u, null,
                      ultimate: true, nameColor: '#e84393')),
              ],
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                PanelButton('REINICIAR (gratis)',
                    key: const ValueKey('asc-reset'),
                    onPressed: widget.editBlocked != null || p.nodes.isEmpty
                        ? null
                        : widget.onReset),
                PanelButton('CAMBIAR ASCENSIÓN (gratis)',
                    key: const ValueKey('asc-change'),
                    onPressed: widget.onChange),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  /// Nombre del nodo debajo (los nodos tomados en blanco).
  Widget _label(AscensionNode n, Offset c, double cell) {
    final size = (n.root ? 0.62 : n.major ? 0.56 : 0.46) * cell;
    final taken = _rules.has(p, n.id);
    return Positioned(
      left: c.dx - cell * 0.9,
      top: c.dy + size / 2 + 3,
      width: cell * 1.8,
      child: IgnorePointer(
        child: Text(retroText(n.name),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 7,
                height: 1.3,
                color: taken ? ProtoColors.white : ProtoColors.dim)),
      ),
    );
  }

  Widget _node(AscensionNode n, Offset c, double cell, Color col) {
    final size = (n.root ? 0.62 : n.major ? 0.56 : 0.46) * cell;
    final taken = _rules.has(p, n.id);
    final open = !taken && _why(n) == null;
    final selected = (_sel ?? a.rootId) == n.id;
    return Positioned(
      left: c.dx - size / 2,
      top: c.dy - size / 2,
      width: size,
      height: size,
      child: RetroTooltip(
        message: '<b>${protoEsc(n.name)}</b><br>${protoEsc(n.text)}<br>'
            '${protoColor(ProtoColors.dim, protoEsc(_state(n)))}',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: ValueKey('asc-node-${n.id}'),
            onTap: () => setState(() => _sel = n.id),
            child: Container(
              decoration: BoxDecoration(
                shape: n.major ? BoxShape.rectangle : BoxShape.circle,
                color: taken ? col : ProtoColors.input,
                border: Border.all(
                  color: selected
                      ? ProtoColors.white
                      : open
                          ? col
                          : col.withValues(alpha: 0.4),
                  width: selected || open ? 3 : RetroTheme.thinBorderWidth,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                taken || n.root ? '' : '${n.cost}',
                style: TextStyle(fontSize: 10, color: col),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TreeLinks extends CustomPainter {
  _TreeLinks(this.a, this.p, this.at, this.color);

  final AscensionDef a;
  final AscensionProgress p;
  final Offset Function(AscensionNode) at;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const rules = AscensionRules();
    final paint = Paint()..strokeWidth = 3;
    for (final n in a.nodes) {
      for (final l in n.links) {
        final o = a.node(l);
        if (o == null || o.id.compareTo(n.id) < 0) continue;
        final both = rules.has(p, n.id) && rules.has(p, o.id);
        paint.color = both ? color : ProtoColors.panelBorder;
        canvas.drawLine(at(n), at(o), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_TreeLinks old) => old.p != p || old.a != a;
}

/// Texto de los títulos del panel (`retroText`).
String ascensionPanelTitle(AscensionDef? a) =>
    retroText(a == null ? 'ESTATUA DEL TIEMPO' : 'ESTATUA DEL TIEMPO · ${a.name}');
