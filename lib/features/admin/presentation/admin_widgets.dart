import 'package:material_ui/material_ui.dart';

import '../../../game_engine/balance/balance_patch.dart';

/// Etiqueta corta del tipo de entidad.
class KindBadge extends StatelessWidget {
  const KindBadge(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: s.secondaryContainer,
        ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: s.onSecondaryContainer, fontWeight: FontWeight.w600)),
    );
  }
}

/// Un error o aviso de validación.
class IssueTile extends StatelessWidget {
  const IssueTile(this.issue, {super.key});
  final BalanceIssue issue;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(issue.error ? Icons.error_outline : Icons.warning_amber,
            size: 18, color: issue.error ? s.error : s.tertiary),
        const SizedBox(width: 6),
        Expanded(
          child: Text('${issue.path}: ${issue.message}',
              style: TextStyle(color: issue.error ? s.error : s.tertiary)),
        ),
      ]),
    );
  }
}

/// Tarjeta con título.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.actions = const []});
  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              ...actions,
            ]),
            const SizedBox(height: 8),
            child,
          ]),
        ),
      );
}

/// "antes → después" con color según suba o baje.
class BeforeAfter extends StatelessWidget {
  const BeforeAfter({
    super.key,
    required this.label,
    required this.before,
    required this.after,
    this.format,
    this.higherIsBetter = true,
  });

  final String label;
  final num before;
  final num after;
  final String Function(num)? format;
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final f = format ?? (n) => n is int ? '$n' : n.toStringAsFixed(1);
    final diff = after - before;
    final pct = before == 0 ? null : diff / before * 100;
    final color = diff.abs() < 1e-9
        ? s.onSurfaceVariant
        : (diff > 0) == higherIsBetter
            ? Colors.green.shade400
            : Colors.red.shade300;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(child: Text(label)),
        Text(f(before)),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('→')),
        Text(f(after), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        SizedBox(
          width: 64,
          child: Text(
            pct == null || diff.abs() < 1e-9 ? '' : '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ),
      ]),
    );
  }
}
