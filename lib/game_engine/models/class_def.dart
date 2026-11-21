import 'attributes.dart';

/// Una clase jugable (`CLASSES` en el prototipo).
class ClassDef {
  final String id;
  final String name;

  /// Texto corto de la tarjeta del título (`desc`).
  final String description;
  final List<String> allowedWeaponTypes;
  final String startWeaponId;
  final int baseDefense;
  final List<String> kitSkillIds; // habilidades fijas de la clase (ninguna la usa desde v0.5)
  final Map<Attribute, int> baseAttributes;

  /// Probabilidad de aturdir con el ataque básico (`stunAtk`, Paladín 3%).
  final double stunOnAttackChance;

  /// Escudo compartido (v0.20.5, Paladín +15%): con un aliado vivo, suma
  /// esta probabilidad a todo lo que aturde (ataque básico y habilidades).
  final double duoStunBonus;

  /// Multiplicador de daño recibido de enemigos perforantes
  /// (`weakPierce`, Paladín ×1.5). 1 = sin debilidad.
  final double pierceWeakness;

  /// Stacks extra de cada estado que recibe, salvo Regeneración
  /// (`weakStatus`, Paladín +1).
  final int statusWeakness;

  const ClassDef({
    required this.id,
    required this.name,
    this.description = '',
    required this.allowedWeaponTypes,
    required this.startWeaponId,
    this.baseDefense = 0,
    this.kitSkillIds = const [],
    this.baseAttributes = const {},
    this.stunOnAttackChance = 0,
    this.duoStunBonus = 0,
    this.pierceWeakness = 1,
    this.statusWeakness = 0,
  });
}
