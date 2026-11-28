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
  ConstructionDef(kCasaId, BuildKind.casa, 'CASA', 3, 3,
      detail: 'Hogar para un habitante invitado'),
  // Farm animals (animals.md § 3): a house and a fenced yard.
  ConstructionDef('gallinero', BuildKind.gallinero, 'GALLINERO', 5, 4,
      detail: 'Casa y patio para gallinas y patos'),
  ConstructionDef('establo', BuildKind.establo, 'ESTABLO', 7, 5,
      detail: 'Casa y patio para vacas, cabras y ovejas'),
  // The town kitchen (farming.md § 17): its own 3 × 3 brick house.
  ConstructionDef(kKitchenId, BuildKind.cocina, 'COCINA', 3, 3,
      detail: 'Cocina del pueblo: recetas, comidas y colección'),
  // The players' own house (player_house.md § 1).
  ConstructionDef(kPlayerHouseId, BuildKind.home, 'CASA PROPIA', 4, 3,
      detail: 'Entrá y dormí hasta la mañana o hasta la noche'),
];

/// The town kitchen (farming.md § 17): gold (`TownRules.kitchenCost`),
/// one per town.
const kKitchenId = 'cocina';

/// The players' own house (player_house.md § 1): costs gold
/// (`playerHouseGold`).
const kPlayerHouseId = 'player_house';

/// La casa de un habitante (town_editor.md § 3.4): cuesta oro y tablas
/// (`ResidentRules.placeCost`).
const kCasaId = 'casa';

ConstructionDef? construction(String id) =>
    kConstructions.where((c) => c.id == id).firstOrNull;

/// El faro de EDITAR PUEBLO (day_night_weather.md § 5): no es una
/// construcción con huella grande; se compra con oro y va en
/// `TownState.lights`.
const kFaroId = 'faro';
