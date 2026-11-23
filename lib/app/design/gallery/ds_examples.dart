import 'package:material_ui/material_ui.dart';

import '../../theme/retro_theme.dart';
import '../design.dart';

// Ejemplos (mockups) con los componentes nuevos; las pantallas reales no
// se tocan (docs/specs/design_system.md § 8).

void _noop() {}

/// Panel de ejemplo: superficie con barra superior y contenido.
class _MockPanel extends StatelessWidget {
  const _MockPanel({required this.toolbar, required this.child, this.note});

  final Widget toolbar;
  final Widget child;
  final String? note;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note != null) ...[
            Text(note!, style: DsText.detail()),
            SizedBox(height: DsSpace.sm),
          ],
          ColoredBox(
            color: DsColors.surface,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              toolbar,
              Padding(padding: EdgeInsets.all(DsSpace.md), child: child),
            ]),
          ),
        ],
      );
}

/// Tooltip de un arma (una columna, pie de atajos).
class WeaponTooltip extends StatelessWidget {
  const WeaponTooltip({super.key});

  @override
  Widget build(BuildContext context) => DsTooltipCard(
        title: 'Espada del Alba',
        titleColor: DsColors.reward,
        tags: const [DsTag.isNew()],
        shortcuts: const [
          DsShortcut('E', 'equipar'),
          DsShortcut('C', 'comparar'),
          DsShortcut('Supr', 'tirar'),
        ],
        children: [
          Text('Una mano · Nv 12', style: DsText.detail()),
          SizedBox(height: DsSpace.xs),
          const DsStatLine('ATQ', 15, 50),
          const DsStatLine('VEL', 12, 10),
          SizedBox(height: DsSpace.xs),
          Text('Golpe de luz: ignora la guardia.', style: DsText.body()),
        ],
      );
}

/// PERSONAJE: barra superior + pestañas con insignias + ATRIBUTOS.
class CharacterMockup extends StatefulWidget {
  const CharacterMockup({super.key});

  @override
  State<CharacterMockup> createState() => _CharacterMockupState();
}

class _CharacterMockupState extends State<CharacterMockup> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final col = RetroType.width(context, 520);
    return _MockPanel(
      toolbar: DsToolbar(
        title: 'PERSONAJE',
        center: DsTabBar(
          tabs: const [
            DsTab('ESTADO', badge: '4'),
            DsTab('EQUIPO'),
            DsTab('HABILIDADES', badge: '1'),
            DsTab('PASIVAS', badge: '3'),
          ],
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        actions: const [
          DsButton('PLAN', size: DsButtonSize.compact, onPressed: _noop),
          DsButton.icon(Text('?'),
              tooltip: 'Ayuda', size: DsButtonSize.compact, onPressed: _noop),
        ],
      ),
      child: Wrap(spacing: DsSpace.xl, runSpacing: DsSpace.lg, children: [
        SizedBox(
          width: col,
          child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DsSectionHeader('Atributos', trailing: DsBadge('4')),
                DsAttributeRow(
                    name: 'Fuerza',
                    code: 'FUE',
                    value: 42,
                    planned: true,
                    onAdd: _noop,
                    onRemove: _noop),
                DsAttributeRow(
                    name: 'Vitalidad',
                    code: 'VIT',
                    value: 30,
                    onAdd: _noop,
                    onRemove: _noop),
                DsAttributeRow(
                    name: 'Agilidad',
                    code: 'AGI',
                    value: 61,
                    planned: true,
                    cappedStep: 1.5,
                    onAdd: _noop,
                    onRemove: _noop),
                DsAttributeRow(
                    name: 'Magia', code: 'MAG', value: 12, onAdd: _noop),
              ]),
        ),
        SizedBox(
          width: RetroType.width(context, 300),
          child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DsSectionHeader('Estadísticas'),
                DsStatLine('ATQ', 15, 50),
                DsStatLine('DEF', 30, 30),
                DsStatLine('VEL', 18, 22),
                DsStatLine('HP', 220, 240),
              ]),
        ),
      ]),
    );
  }
}

/// INVENTARIO: filas de una línea y el tooltip de la elegida.
class InventoryMockup extends StatelessWidget {
  const InventoryMockup({super.key});

  @override
  Widget build(BuildContext context) {
    final list = RetroType.width(context, 560);
    return _MockPanel(
      note:
          'El tooltip aparece al pasar el mouse o con foco; acá se muestra fijo.',
      toolbar: DsToolbar(
        title: 'INVENTARIO',
        center: DsTabBar(
          tabs: const [
            DsTab('ARMAS', badge: '1'),
            DsTab('ARMADURAS'),
            DsTab('OBJETOS'),
          ],
          index: 0,
          onChanged: (_) {},
        ),
        actions: const [
          DsSearchField(width: 200),
          DsButton.icon(Text('?'),
              tooltip: 'Ayuda', size: DsButtonSize.compact, onPressed: _noop),
        ],
      ),
      child: Wrap(spacing: DsSpace.lg, runSpacing: DsSpace.md, children: [
        SizedBox(
          width: list,
          child: Column(children: [
            const DsListRow(
                title: 'Espada del Alba',
                titleColor: DsColors.reward,
                detail: 'Nv 12',
                selected: true,
                trailing: DsTag.isNew(),
                onTap: _noop),
            DsListRow(
                title: 'Hoja Gemela',
                detail: 'Nv 10',
                trailing: Text('E', style: DsText.subtitle(DsColors.success)),
                onTap: _noop),
            const DsListRow(
                title: 'Lanza de Ceniza', detail: 'Nv 9', onTap: _noop),
            const DsListRow(title: 'Daga Simple', detail: 'Nv 2', onTap: _noop),
          ]),
        ),
        SizedBox(width: DsSpace.lg),
        const WeaponTooltip(),
      ]),
    );
  }
}

/// Menú de habilidades de batalla: Instante, costos y desactivada con
/// motivo en rojo.
class BattleMockup extends StatelessWidget {
  const BattleMockup({super.key});

  @override
  Widget build(BuildContext context) {
    final list = RetroType.width(context, 600);
    return _MockPanel(
      toolbar: DsToolbar(
        title: 'TURNO DE ARIA',
        actions: [
          const DsCost.mp(34),
          SizedBox(width: DsSpace.md),
          const DsCost.pulse(3),
          SizedBox(width: DsSpace.md),
          const DsButton.icon(Text('?'),
              tooltip: 'Ayuda', size: DsButtonSize.compact, onPressed: _noop),
        ],
      ),
      child: Wrap(spacing: DsSpace.lg, runSpacing: DsSpace.md, children: [
        SizedBox(
          width: list,
          child: Column(children: [
            DsListRow(
                title: 'Corte Rápido',
                selected: true,
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  const DsTag.instant(),
                  SizedBox(width: DsSpace.sm),
                  const DsCost.mp(8),
                ]),
                onTap: _noop),
            DsListRow(
                title: 'Golpe Sísmico',
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  const DsTag.canBreak(),
                  SizedBox(width: DsSpace.sm),
                  const DsCost.mp(14),
                ]),
                onTap: _noop),
            const DsListRow(
                title: 'Filo del Alba',
                trailing: DsCost.pulse(2),
                onTap: _noop),
            const DsListRow(
                title: 'Tormenta de Acero',
                detail: 'Falta MP',
                detailColor: DsColors.danger,
                enabled: false,
                trailing: DsCost.mp(40, affordable: false)),
            const DsListRow(
                title: 'Guardia',
                detail: 'En espera 1 turno',
                detailColor: DsColors.danger,
                enabled: false),
          ]),
        ),
        SizedBox(width: DsSpace.lg),
        const DsTooltipCard(
          title: 'Corte Rápido',
          tags: [DsTag.instant()],
          shortcuts: [DsShortcut('1', 'usar'), DsShortcut('Tab', 'objetivo')],
          children: [
            DsStatLine('DAÑO', 0, 38),
            Text('No gasta el turno.'),
          ],
        ),
      ]),
    );
  }
}

/// Plantilla TRASPASO (ui_minimal.md § 9) con datos de ejemplo.
class TransferMockup extends StatefulWidget {
  const TransferMockup({super.key});

  @override
  State<TransferMockup> createState() => _TransferMockupState();
}

class _TransferMockupState extends State<TransferMockup> {
  final _mine = {'trigo': 12, 'zanahoria': 4, 'calabaza': 1};
  final _there = <String, int>{'trigo': 3};

  List<DsTransferItem> _items(Map<String, int> m) => [
        for (final e in m.entries)
          DsTransferItem(
            id: e.key,
            icon: SizedBox.square(
                dimension: 24, child: ColoredBox(color: DsColors.border)),
            name: e.key.toUpperCase(),
            border: e.key == 'calabaza' ? DsColors.reward : DsColors.border,
            tag: e.key == 'calabaza' ? 'rara' : 'comun',
            count: e.value,
            info: 'ejemplo',
          ),
      ];

  void _move(Map<String, int> from, Map<String, int> to, String id, int q) {
    final have = from[id] ?? 0;
    final n = q == 0 || q > have ? have : q;
    setState(() {
      from[id] = have - n;
      to[id] = (to[id] ?? 0) + n;
    });
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 780,
        child: DsTransferTemplate(
          keyPrefix: 'gallery-transfer',
          leftTitle: 'TUS ÍTEMS',
          rightTitle: 'CONTENEDOR',
          left: _items(_mine),
          right: _items(_there),
          filters: const [
            DsTransferFilter('TODAS', null),
            DsTransferFilter('COMÚN', 'comun'),
            DsTransferFilter('RARA', 'rara'),
          ],
          onMove: (from, id, q) => from == DsTransferSide.left
              ? _move(_mine, _there, id, q)
              : _move(_there, _mine, id, q),
        ),
      );
}
