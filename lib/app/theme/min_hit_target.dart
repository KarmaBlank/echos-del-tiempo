import 'package:material_ui/material_ui.dart';

/// Agranda el área de clic de [child] a por lo menos [size] × [size] px
/// (centrado) sin cambiar cómo se ve. Para íconos y glifos sueltos
/// (`×`, `+5`) que a texto Normal quedan por debajo del mínimo
/// (docs/specs/accessibility.md § "Objetivos clicables").
class MinHitTarget extends StatelessWidget {
  const MinHitTarget({super.key, required this.child, this.size = minSize});

  /// Mínimo a texto Normal (px lógicos).
  static const minSize = 24.0;

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(minWidth: size, minHeight: size),
        child: Center(widthFactor: 1, heightFactor: 1, child: child),
      );
}
