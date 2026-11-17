import '../models/attributes.dart';
import '../models/weapon.dart';

// `WEAPONS` del prototipo, 1:1. `wt` → weight, `def` → shieldDefense,
// `req` → requirements, `sk` → skillIds.

const _vit = Attribute.vit;
const _esp = Attribute.esp;
const _agi = Attribute.agi;
const _fue = Attribute.fue;
const _des = Attribute.des;

const Map<String, WeaponDef> kWeapons = {
  // ---- Guerrero ----
  'espada_bronce': WeaponDef(id: 'espada_bronce', name: 'Espada de Bronce', classId: 'guerrero', type: 'espada', tier: 0, price: 0,
      requirements: {_fue: 8}, atk: PowerFormula(base: 6, coefficients: {_fue: 0.6, _des: 0.2}), skillIds: ['giro', 'embestida']),
  'espada_ignea': WeaponDef(id: 'espada_ignea', name: 'Espada Ígnea', classId: 'guerrero', type: 'espada', tier: 1, price: 300, weight: 0.3,
      requirements: {_fue: 14, _des: 8}, atk: PowerFormula(base: 10, coefficients: {_fue: 0.6, _des: 0.3}), skillIds: ['ignea', 'giro']),
  'hacha_rompe': WeaponDef(id: 'hacha_rompe', name: 'Hacha Rompeturnos', classId: 'guerrero', type: 'hacha', tier: 2, price: 650, weight: 1.5,
      requirements: {_fue: 18}, atk: PowerFormula(base: 16, coefficients: {_fue: 0.85}), skillIds: ['sismo', 'hendir']),
  'mandoble_eco': WeaponDef(id: 'mandoble_eco', name: 'Mandoble del Eco', classId: 'guerrero', type: 'espada', tier: 3, price: 1400, weight: 1.0,
      requirements: {_fue: 22, _des: 12}, atk: PowerFormula(base: 22, coefficients: {_fue: 0.8, _des: 0.4}), skillIds: ['tajoT', 'giro', 'embestida']),
  'espada_carmesi': WeaponDef(id: 'espada_carmesi', name: 'Espada Carmesí', classId: 'guerrero', type: 'espada', tier: 2, price: 660,
      requirements: {_fue: 15, _des: 12}, atk: PowerFormula(base: 13, coefficients: {_fue: 0.55, _des: 0.4}), skillIds: ['tajoCarmesi', 'giro']),
  'hacha_tormenta': WeaponDef(id: 'hacha_tormenta', name: 'Hacha de la Tormenta', classId: 'guerrero', type: 'hacha', tier: 3, price: 1450, weight: 1.4,
      requirements: {_fue: 21}, atk: PowerFormula(base: 21, coefficients: {_fue: 0.85}), skillIds: ['vendaval', 'sismo']),
  'mandoble_ocaso': WeaponDef(id: 'mandoble_ocaso', name: 'Mandoble del Ocaso', classId: 'guerrero', type: 'espada', tier: 3, price: 1500, weight: 1.0,
      requirements: {_fue: 20, _des: 14}, atk: PowerFormula(base: 22, coefficients: {_fue: 0.7, _des: 0.4}), skillIds: ['tajoOcaso', 'embestida']),
  'katana_escarcha': WeaponDef(id: 'katana_escarcha', name: 'Katana de Escarcha', classId: 'guerrero', type: 'espada', tier: 1, price: 350,
      requirements: {_fue: 12, _des: 10}, atk: PowerFormula(base: 9, coefficients: {_fue: 0.5, _des: 0.4}), skillIds: ['corteGlacial', 'embestida']),
  'hacha_volcanica': WeaponDef(id: 'hacha_volcanica', name: 'Hacha Volcánica', classId: 'guerrero', type: 'hacha', tier: 2, price: 720, weight: 1.3,
      requirements: {_fue: 17, _esp: 8}, atk: PowerFormula(base: 15, coefficients: {_fue: 0.8}), skillIds: ['erupcion', 'ignea']),

  // ---- Maga ----
  'baculo_aprendiz': WeaponDef(id: 'baculo_aprendiz', name: 'Báculo de Aprendiz', classId: 'maga', type: 'báculo', tier: 0, price: 0,
      requirements: {_esp: 8}, atk: PowerFormula(base: 3, coefficients: {_fue: 0.4}), mag: PowerFormula(base: 5, coefficients: {_esp: 0.75}),
      skillIds: ['chispa', 'cura']),
  'baculo_fuego': WeaponDef(id: 'baculo_fuego', name: 'Báculo de Fuego', classId: 'maga', type: 'báculo', tier: 1, price: 300,
      requirements: {_esp: 14}, atk: PowerFormula(base: 4, coefficients: {_fue: 0.4}), mag: PowerFormula(base: 7, coefficients: {_esp: 0.8}),
      skillIds: ['bola', 'llamarada']),
  'baculo_escarcha': WeaponDef(id: 'baculo_escarcha', name: 'Báculo de Escarcha', classId: 'maga', type: 'báculo', tier: 2, price: 650,
      requirements: {_esp: 16, _agi: 9}, atk: PowerFormula(base: 4, coefficients: {_fue: 0.4}), mag: PowerFormula(base: 10, coefficients: {_esp: 0.85}),
      skillIds: ['lanzaH', 'ventisca']),
  'tomo_tiempo': WeaponDef(id: 'tomo_tiempo', name: 'Tomo del Tiempo', classId: 'maga', type: 'tomo', tier: 3, price: 1400, weight: 0.5,
      requirements: {_esp: 22}, atk: PowerFormula(base: 3, coefficients: {_fue: 0.3}), mag: PowerFormula(base: 14, coefficients: {_esp: 1.0}),
      skillIds: ['detener', 'curaM']),
  'baculo_rayo': WeaponDef(id: 'baculo_rayo', name: 'Báculo del Rayo', classId: 'maga', type: 'báculo', tier: 2, price: 680,
      requirements: {_esp: 16, _des: 10}, atk: PowerFormula(base: 3, coefficients: {_fue: 0.4}), mag: PowerFormula(base: 11, coefficients: {_esp: 0.85}),
      skillIds: ['descarga', 'prisa']),
  'tomo_plaga': WeaponDef(id: 'tomo_plaga', name: 'Tomo de la Plaga', classId: 'maga', type: 'tomo', tier: 2, price: 700, weight: 0.4,
      requirements: {_esp: 17}, atk: PowerFormula(base: 3, coefficients: {_fue: 0.3}), mag: PowerFormula(base: 10, coefficients: {_esp: 0.85}),
      skillIds: ['plaga', 'dardo']),
  'baculo_ponzona': WeaponDef(id: 'baculo_ponzona', name: 'Báculo de Ponzoña', classId: 'maga', type: 'báculo', tier: 1, price: 350,
      requirements: {_esp: 12, _des: 8}, atk: PowerFormula(base: 3, coefficients: {_fue: 0.4}), mag: PowerFormula(base: 7, coefficients: {_esp: 0.8}),
      skillIds: ['dardo', 'cura']),
  'tomo_infernal': WeaponDef(id: 'tomo_infernal', name: 'Tomo Infernal', classId: 'maga', type: 'tomo', tier: 3, price: 1500, weight: 0.5,
      requirements: {_esp: 21}, atk: PowerFormula(base: 3, coefficients: {_fue: 0.3}), mag: PowerFormula(base: 14, coefficients: {_esp: 1.0}),
      skillIds: ['infierno', 'bola']),

  // ---- Tirador ----
  'arco_corto': WeaponDef(id: 'arco_corto', name: 'Arco Corto', classId: 'tirador', type: 'arco', tier: 0, price: 0,
      requirements: {_des: 8}, atk: PowerFormula(base: 5, coefficients: {_des: 0.6, _fue: 0.2}), skillIds: ['venenosa', 'rafaga', 'certero']),
  'rifle_aturdidor': WeaponDef(id: 'rifle_aturdidor', name: 'Rifle Aturdidor', classId: 'tirador', type: 'rifle', tier: 1, price: 300, weight: 0.5,
      requirements: {_des: 12, _fue: 8}, atk: PowerFormula(base: 9, coefficients: {_des: 0.55, _fue: 0.3}), skillIds: ['aturdir', 'certero']),
  'arco_tormenta': WeaponDef(id: 'arco_tormenta', name: 'Arco Tormenta', classId: 'tirador', type: 'arco', tier: 2, price: 650,
      requirements: {_des: 16, _agi: 12}, atk: PowerFormula(base: 12, coefficients: {_des: 0.7, _agi: 0.2}), skillIds: ['rayoF', 'lluvia', 'venenosa']),
  'rifle_ocaso': WeaponDef(id: 'rifle_ocaso', name: 'Rifle del Ocaso', classId: 'tirador', type: 'rifle', tier: 3, price: 1400, weight: 0.8,
      requirements: {_des: 22}, atk: PowerFormula(base: 20, coefficients: {_des: 0.85}), skillIds: ['perfora', 'aturdir', 'rafaga']),
  'arco_sombra': WeaponDef(id: 'arco_sombra', name: 'Arco de Sombra', classId: 'tirador', type: 'arco', tier: 2, price: 680,
      requirements: {_des: 16}, atk: PowerFormula(base: 12, coefficients: {_des: 0.65}), skillIds: ['sombra', 'venenosa']),
  'rifle_glacial': WeaponDef(id: 'rifle_glacial', name: 'Rifle Glacial', classId: 'tirador', type: 'rifle', tier: 3, price: 1450, weight: 0.9,
      requirements: {_des: 21, _fue: 10}, atk: PowerFormula(base: 19, coefficients: {_des: 0.8}), skillIds: ['ceroAbs', 'aturdir']),
  'arco_solar': WeaponDef(id: 'arco_solar', name: 'Arco Solar', classId: 'tirador', type: 'arco', tier: 3, price: 1450,
      requirements: {_des: 20, _agi: 14}, atk: PowerFormula(base: 18, coefficients: {_des: 0.75}), skillIds: ['flechaSolar', 'lluvia']),
  'ballesta_glacial': WeaponDef(id: 'ballesta_glacial', name: 'Ballesta Glacial', classId: 'tirador', type: 'arco', tier: 1, price: 350,
      requirements: {_des: 12, _agi: 10}, atk: PowerFormula(base: 9, coefficients: {_des: 0.6}), skillIds: ['saeta', 'rafaga']),
  'rifle_pestilente': WeaponDef(id: 'rifle_pestilente', name: 'Rifle Pestilente', classId: 'tirador', type: 'rifle', tier: 2, price: 720, weight: 0.6,
      requirements: {_des: 15, _fue: 9}, atk: PowerFormula(base: 12, coefficients: {_des: 0.6, _fue: 0.2}), skillIds: ['metralla', 'venenosa', 'certero']),

  // ---- Paladín ----
  'espada_escudo_novato': WeaponDef(id: 'espada_escudo_novato', name: 'Espada y Escudo de Novicio', classId: 'paladin', type: 'espada+escudo', tier: 0, price: 0,
      requirements: {_fue: 5}, atk: PowerFormula(base: 2, coefficients: {_fue: 0.15}), mag: PowerFormula(base: 4, coefficients: {_esp: 0.6}),
      skillIds: ['estocada', 'golpeEscudo']),
  'maza_escudo_roble': WeaponDef(id: 'maza_escudo_roble', name: 'Maza y Escudo de Roble', classId: 'paladin', type: 'maza+escudo', tier: 1, price: 320,
      weight: 0.4, shieldDefense: 3,
      requirements: {_fue: 7, _vit: 16}, atk: PowerFormula(base: 2, coefficients: {_fue: 0.15}), mag: PowerFormula(base: 5, coefficients: {_esp: 0.65}),
      skillIds: ['golpeEscudo', 'sanar']),
  'martillo_escudo_hierro': WeaponDef(id: 'martillo_escudo_hierro', name: 'Martillo y Escudo de Hierro', classId: 'paladin', type: 'martillo+escudo', tier: 1, price: 340,
      weight: 1.0,
      requirements: {_fue: 10}, atk: PowerFormula(base: 6, coefficients: {_fue: 0.4}), mag: PowerFormula(base: 4, coefficients: {_esp: 0.5}),
      skillIds: ['aplastar', 'temblor']),
  'espada_escudo_alba': WeaponDef(id: 'espada_escudo_alba', name: 'Espada y Escudo del Alba', classId: 'paladin', type: 'espada+escudo', tier: 2, price: 680,
      shieldDefense: 1,
      requirements: {_fue: 9, _esp: 13}, atk: PowerFormula(base: 5, coefficients: {_fue: 0.3}), mag: PowerFormula(base: 8, coefficients: {_esp: 0.8}),
      skillIds: ['lanzaLuz', 'consagrar']),
  'maza_escudo_bastion': WeaponDef(id: 'maza_escudo_bastion', name: 'Maza y Escudo Bastión', classId: 'paladin', type: 'maza+escudo', tier: 2, price: 700,
      weight: 0.6, shieldDefense: 5,
      requirements: {_vit: 20, _esp: 11}, atk: PowerFormula(base: 3, coefficients: {_fue: 0.2}), mag: PowerFormula(base: 7, coefficients: {_esp: 0.75}),
      skillIds: ['provocar', 'escudoFe']),
  'martillo_escudo_juicio': WeaponDef(id: 'martillo_escudo_juicio', name: 'Martillo y Escudo del Juicio', classId: 'paladin', type: 'martillo+escudo', tier: 3, price: 1450,
      weight: 1.4,
      requirements: {_fue: 16, _vit: 18}, atk: PowerFormula(base: 12, coefficients: {_fue: 0.6}), mag: PowerFormula(base: 6, coefficients: {_esp: 0.6}),
      skillIds: ['juicio', 'sagrado', 'temblor']),
};
