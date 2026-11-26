import 'package:material_ui/material_ui.dart';

import '../theme/proto_colors.dart';
import '../theme/retro_text.dart';
import '../theme/retro_theme.dart';
import 'ds_tokens.dart';

/// Boss health bar (organism, docs/specs/bosses.md § v0.50 § 3): name,
/// an optional tag (ECO), life with a tick at every phase gate, the phase
/// line and the telegraphed next move. Presentational: it gets texts and
/// numbers, never battle state.
class DsBossHealthBar extends StatelessWidget {
  const DsBossHealthBar({
    super.key,
    required this.name,
    required this.hp,
    required this.maxHp,
    required this.phaseText,
    this.gates = const [],
    this.tag,
    this.nextText,
    this.width = 360,
    this.danger = false,
  });

  final String name;
  final int hp;
  final int maxHp;

  /// Phase gates as life fractions (0..1), one tick each.
  final List<double> gates;

  /// "FASE 2/3 · División".
  final String phaseText;

  /// Short tag after the name ("ECO"), or `null`.
  final String? tag;

  /// "PRÓX: Ola Ácida" when the next move is telegraphed, or `null`.
  final String? nextText;

  /// Last phase: the fill turns crimson.
  final bool danger;
  final double width;

  @override
  Widget build(BuildContext context) {
    final f = maxHp <= 0 ? 0.0 : (hp / maxHp).clamp(0.0, 1.0);
    final w = RetroType.width(context, width);
    final fill = danger ? ProtoColors.crimson : DsColors.danger;
    return Semantics(
      label: '$name, $hp / $maxHp, $phaseText'
          '${nextText == null ? '' : ', $nextText'}',
      excludeSemantics: true,
      child: Container(
        width: w,
        padding: EdgeInsets.all(DsSpace.xs),
        decoration: BoxDecoration(
          color: DsColors.surface,
          border: Border.all(color: DsColors.border, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Flexible(
                child: Text(retroText(name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsText.subtitle(DsColors.reward)),
              ),
              if (tag != null) ...[
                SizedBox(width: DsSpace.xs),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: DsSpace.xs),
                  color: ProtoColors.violet,
                  child: Text(retroText(tag!),
                      maxLines: 1, style: DsText.meta(DsColors.text)),
                ),
              ],
              const Spacer(),
              Text(retroText('$hp/$maxHp'),
                  maxLines: 1, style: DsText.meta(DsColors.textSecondary)),
            ]),
            SizedBox(height: DsSpace.xs),
            SizedBox(
              height: 10,
              child: CustomPaint(
                painter: _BarPainter(f, gates, fill),
              ),
            ),
            SizedBox(height: DsSpace.xs),
            Row(children: [
              Flexible(
                child: Text(retroText(phaseText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsText.detail(
                        danger ? ProtoColors.crimson : ProtoColors.pink)),
              ),
              if (nextText != null) ...[
                SizedBox(width: DsSpace.sm),
                const Spacer(),
                Text(retroText(nextText!),
                    maxLines: 1, style: DsText.detail(DsColors.warning)),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.f, this.gates, this.fill);

  final double f;
  final List<double> gates;
  final Color fill;

  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    c.drawRect(r, Paint()..color = DsColors.surfaceSunken);
    c.drawRect(Rect.fromLTWH(0, 0, s.width * f, s.height),
        Paint()..color = fill);
    final tick = Paint()..color = DsColors.reward;
    for (final g in gates) {
      if (g <= 0 || g >= 1) continue;
      final x = (s.width * g).roundToDouble();
      c.drawRect(Rect.fromLTWH(x - 1, 0, 2, s.height), tick);
    }
    c.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = DsColors.borderControl);
  }

  @override
  bool shouldRepaint(_BarPainter o) =>
      o.f != f || o.fill != fill || o.gates != gates;
}
