import '../models/weapon.dart';

/// Categoría de peso de un arma (docs/specs/loot.md § 1.1 "Peso"). El
/// peso (`WeaponDef.weight`) resta velocidad 1:1 (`VEL = 6 + AGI×0.5 +
/// DES×0.1 − peso`); la categoría es solo una etiqueta derivada de ese
/// número para la UI (nunca se guarda ni viaja por red), así que un
/// cambio de peso en el balance la mueve sola.
enum WeightClass {
  /// Peso 0: sin penalización de velocidad.
  ligera('Ligera'),

  /// 0 < peso < [kHeavyWeightFrom].
  media('Media'),

  /// Peso ≥ [kHeavyWeightFrom].
  pesada('Pesada');

  const WeightClass(this.label);

  /// `Ligera` / `Media` / `Pesada` (también la palabra del filtro `Peso`).
  final String label;
}

/// Desde este peso un arma es [WeightClass.pesada] (loot.md § 1.1: el
/// catálogo no tiene bases entre 0.6 y 0.8).
const kHeavyWeightFrom = 0.8;

/// Categoría de un peso (tolerancia para decimales del balance).
WeightClass weightClassFor(double weight) {
  if (weight <= 1e-9) return WeightClass.ligera;
  if (weight < kHeavyWeightFrom - 1e-9) return WeightClass.media;
  return WeightClass.pesada;
}

/// Categoría de peso de [w].
WeightClass weightClassOf(WeaponDef w) => weightClassFor(w.weight);
