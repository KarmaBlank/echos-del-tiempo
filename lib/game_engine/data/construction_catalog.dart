import '../models/town_build.dart';

/// Una construcción que se puede poner en el pueblo (town_editor.md § 3):
/// tipo, nombre del menú y huella en tiles. Para sumar un tipo nuevo de
/// edificio alcanza con un valor en `BuildKind`, su entrada acá y cómo se
/// dibuja en `TownPlan`.
class ConstructionDef {
  const ConstructionDef(this.id, this.kind, this.name, this.w, this.h,
      {required this.detail});

  final String id;
  final BuildKind kind;
  final String name;
  final int w, h;
  final String detail;
}

const kConstructions = <ConstructionDef>[
  ConstructionDef('huerta', BuildKind.huerta, 'HUERTA', 6, 4,
      detail: '24 parcelas de tierra para arar'),
  ConstructionDef('huerta_chica', BuildKind.huerta, 'HUERTA CHICA', 4, 3,
      detail: '12 parcelas'),
  ConstructionDef('lago', BuildKind.lago, 'LAGO', 6, 6,
      detail: 'Agua para pescar y soltar peces'),
  ConstructionDef('lago_chico', BuildKind.lago, 'LAGO CHICO', 4, 4,
      detail: 'Pegalo a otro lago para agrandarlo'),
];

ConstructionDef? construction(String id) =>
    kConstructions.where((c) => c.id == id).firstOrNull;

/// El faro de EDITAR PUEBLO (day_night_weather.md § 5): no es una
/// construcción con huella grande; se compra con oro y va en
/// `TownState.lights`.
const kFaroId = 'faro';
