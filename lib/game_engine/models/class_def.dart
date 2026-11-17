class ClassDef {
  final String id;
  final String name;
  final List<String> allowedWeaponTypes;
  final String startWeaponId;
  final int baseDefense;
  final List<String> kitSkillIds; // habilidades propias de la clase (ej. kit de Paladín)

  const ClassDef({
    required this.id,
    required this.name,
    required this.allowedWeaponTypes,
    required this.startWeaponId,
    this.baseDefense = 0,
    this.kitSkillIds = const [],
  });
}
