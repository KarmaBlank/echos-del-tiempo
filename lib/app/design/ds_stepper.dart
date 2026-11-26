import 'package:material_ui/material_ui.dart';

import 'ds_button.dart';
import 'ds_tokens.dart';

/// One step of a [DsStepper]: its label and, once chosen, a small icon of
/// the choice.
class DsStep {
  const DsStep(this.label, {this.icon});

  final String label;

  /// Icon of what was chosen in this step (`null` = not chosen yet).
  final Widget? icon;
}

/// Numbered steps in one row: `1 Tipo › 2 Base › …` (smithing UI,
/// mining_smithing.md § 3.1). The current step is highlighted, a chosen
/// step shows its icon; any step can be clicked. Keys:
/// `<keyPrefix>-step-<i>`.
class DsStepper extends StatelessWidget {
  const DsStepper({
    super.key,
    required this.keyPrefix,
    required this.steps,
    required this.index,
    required this.onChanged,
  });

  final String keyPrefix;
  final List<DsStep> steps;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: DsSpace.xs,
    runSpacing: DsSpace.xs,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      for (var i = 0; i < steps.length; i++) ...[
        if (i > 0) Text('›', style: DsText.detail()),
        DsButton(
          '${i + 1} ${steps[i].label}',
          key: ValueKey('$keyPrefix-step-$i'),
          size: DsButtonSize.compact,
          selected: i == index,
          leading: steps[i].icon == null
              ? null
              : SizedBox.square(
                  dimension: 16,
                  child: FittedBox(child: steps[i].icon),
                ),
          onPressed: () => onChanged(i),
        ),
      ],
    ],
  );
}
