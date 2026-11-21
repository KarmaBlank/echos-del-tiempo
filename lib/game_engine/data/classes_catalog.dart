import '../models/attributes.dart';
import '../models/class_def.dart';

/// `CLASSES` del prototipo, 1:1. La paleta de colores de cada clase es
/// arte y vive en `assets/sprites`, no acá.
const Map<String, ClassDef> kClasses = {
  'guerrero': ClassDef(
    id: 'guerrero',
    name: 'Guerrero',
    description: 'Espadas y hachas',
    allowedWeaponTypes: ['espada', 'hacha'],
    startWeaponId: 'espada_bronce',
    baseDefense: 3,
    baseAttributes: {
      Attribute.vit: 10, Attribute.esp: 4, Attribute.agi: 6,
      Attribute.fue: 12, Attribute.des: 6,
    },
  ),
  'maga': ClassDef(
    id: 'maga',
    name: 'Maga',
    description: 'Báculos y tomos · cada uno se especializa',
    allowedWeaponTypes: ['báculo', 'tomo'],
    startWeaponId: 'baculo_aprendiz',
    baseAttributes: {
      Attribute.vit: 6, Attribute.esp: 13, Attribute.agi: 7,
      Attribute.fue: 4, Attribute.des: 6,
    },
  ),
  'paladin': ClassDef(
    id: 'paladin',
    name: 'Paladín',
    description: 'Escudo · vida y defensa altas, daño bajo, lento',
    allowedWeaponTypes: ['espada+escudo', 'maza+escudo', 'martillo+escudo'],
    startWeaponId: 'espada_escudo_novato',
    baseDefense: 6,
    // Sin kit de clase desde v0.5: Aura Restauradora, Fortaleza y
    // Protección son el kit del Guardián (docs/specs/ascension.md § 4).
    stunOnAttackChance: 0.03,
    duoStunBonus: 0.15,
    pierceWeakness: 1.5,
    statusWeakness: 1,
    baseAttributes: {
      Attribute.vit: 15, Attribute.esp: 9, Attribute.agi: 4,
      Attribute.fue: 7, Attribute.des: 3,
    },
  ),
  'tirador': ClassDef(
    id: 'tirador',
    name: 'Tirador',
    description: 'Arcos y rifles',
    allowedWeaponTypes: ['arco', 'rifle'],
    startWeaponId: 'arco_corto',
    baseDefense: 1,
    baseAttributes: {
      Attribute.vit: 8, Attribute.esp: 6, Attribute.agi: 11,
      Attribute.fue: 7, Attribute.des: 11,
    },
  ),
};
