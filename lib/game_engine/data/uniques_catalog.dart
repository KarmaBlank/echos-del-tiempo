import '../models/item.dart';

// Legendarios diseñados a mano (docs/specs/loot.md § 11): base, mods
// fijos (afijos del pool con rango propio), 1–2 mods aleatorios y una
// pasiva única de weapon_passives.dart. Nombres propios de Ecos del
// Tiempo.

final Map<String, UniqueDef> kUniques = {for (final u in _list) u.id: u};

const List<UniqueDef> _list = [
  // ---------------- Guerrero ----------------
  UniqueDef(
    id: 'juramentoAlba',
    name: 'Juramento del Alba',
    baseId: 'espada_templada',
    fixed: [UniqueMod('feroz', 20, 30), UniqueMod('certero', 5, 8)],
    passiveId: 'albaImplacable',
    flavor: 'La juró un caballero que nunca vio el mediodía.',
  ),
  UniqueDef(
    id: 'segadoraEras',
    name: 'Segadora de Eras',
    baseId: 'mandoble_eras',
    fixed: [UniqueMod('feroz', 35, 45), UniqueMod('del_vampiro', 3, 5)],
    passiveId: 'cosecha',
    flavor: 'Cada era que cae alimenta la siguiente.',
  ),
  UniqueDef(
    id: 'fauceVolcan',
    name: 'Fauce del Volcán',
    baseId: 'hacha_volcanica',
    fixed: [UniqueMod('afilado', 4, 7), UniqueMod('abrasador', 1, 1)],
    passiveId: 'erupcionInterna',
    flavor: 'Todavía está caliente por dentro.',
  ),
  UniqueDef(
    id: 'rompemundos',
    name: 'Rompemundos',
    baseId: 'hacha_cataclismo',
    fixed: [
      UniqueMod('feroz', 30, 40),
      UniqueMod('del_toro', 10, 15),
      UniqueMod('de_la_vida', 40, 60),
    ],
    passiveId: 'grieta',
    flavor: 'No corta: separa.',
  ),
  UniqueDef(
    id: 'lanzaHorizonte',
    name: 'Lanza del Horizonte',
    baseId: 'lanza_tormenta',
    fixed: [UniqueMod('veloz', 5, 8), UniqueMod('certero', 6, 10)],
    passiveId: 'horizonte',
    flavor: 'Apunta a donde el cielo toca la tierra.',
  ),
  // ---------------- Maga ----------------
  UniqueDef(
    id: 'corazonAscua',
    name: 'Corazón de Ascua',
    baseId: 'baculo_fuego',
    fixed: [UniqueMod('arcano', 15, 25), UniqueMod('abrasador', 1, 1)],
    passiveId: 'ascuaEterna',
    flavor: 'Late. Despacio, pero late.',
  ),
  UniqueDef(
    id: 'inviernoPerpetuo',
    name: 'Invierno Perpetuo',
    baseId: 'baculo_ambar',
    fixed: [
      UniqueMod('arcano', 25, 35),
      UniqueMod('gelido', 1, 1),
      UniqueMod('del_eter', 12, 18),
    ],
    passiveId: 'escarchaPerpetua',
    flavor: 'Una estación que se negó a terminar.',
  ),
  UniqueDef(
    id: 'codiceUltimoDia',
    name: 'Códice del Último Día',
    baseId: 'tomo_eternidad',
    fixed: [UniqueMod('arcano', 35, 45), UniqueMod('impetuoso', 15, 22)],
    passiveId: 'paradojaViva',
    flavor: 'Sus páginas ya fueron leídas mañana.',
  ),
  UniqueDef(
    id: 'relampagoDormido',
    name: 'Relámpago Dormido',
    baseId: 'varita_rayo',
    fixed: [UniqueMod('arcano', 20, 30), UniqueMod('letal', 20, 30)],
    passiveId: 'arcoDormido',
    flavor: 'Si la despertás, no la vuelvas a dormir.',
  ),
  // ---------------- Tirador ----------------
  UniqueDef(
    id: 'susurroVibora',
    name: 'Susurro de la Víbora',
    baseId: 'dagas_vibora',
    fixed: [UniqueMod('ponzonoso', 1, 2), UniqueMod('certero', 6, 10)],
    passiveId: 'mordida',
    flavor: 'Primero el susurro. Después, nada.',
  ),
  UniqueDef(
    id: 'ojoHalconSolar',
    name: 'Ojo del Halcón Solar',
    baseId: 'arco_solar',
    fixed: [UniqueMod('feroz', 20, 30), UniqueMod('letal', 20, 30)],
    passiveId: 'solCenital',
    flavor: 'A mediodía no hay sombra donde esconderse.',
  ),
  UniqueDef(
    id: 'truenoBronce',
    name: 'Trueno de Bronce',
    baseId: 'rifle_precision',
    fixed: [UniqueMod('feroz', 25, 35), UniqueMod('afilado', 6, 10)],
    passiveId: 'estampido',
    flavor: 'El eco llega antes que la bala.',
  ),
  UniqueDef(
    id: 'ballestaJuicio',
    name: 'Ballesta del Juicio Final',
    baseId: 'ballesta_asedio',
    fixed: [UniqueMod('feroz', 35, 40), UniqueMod('letal', 26, 40)],
    passiveId: 'viroteFinal',
    flavor: 'Cada virote lleva un nombre escrito.',
  ),
  UniqueDef(
    id: 'primaveraRota',
    name: 'Arco de la Primavera Rota',
    baseId: 'arco_eterno',
    fixed: [
      UniqueMod('feroz', 35, 40),
      UniqueMod('del_halcon', 12, 18),
      UniqueMod('del_renacer', 2, 3),
    ],
    passiveId: 'florecer',
    flavor: 'Florece cada vez que alguien cae.',
  ),
  // ---------------- Paladín ----------------
  UniqueDef(
    id: 'egidaPrimerRey',
    name: 'Égida del Primer Rey',
    baseId: 'espada_escudo_cruzado',
    fixed: [UniqueMod('del_baluarte', 3, 5), UniqueMod('de_la_vida', 30, 50)],
    passiveId: 'coronaEscudos',
    flavor: 'El primer rey no tuvo corona: tuvo este escudo.',
  ),
  UniqueDef(
    id: 'martilloOcasoSagrado',
    name: 'Martillo del Ocaso Sagrado',
    baseId: 'martillo_escudo_titan',
    fixed: [UniqueMod('feroz', 25, 35), UniqueMod('runico', 7, 12)],
    passiveId: 'juicioFinal',
    flavor: 'Cae como el sol: tarde, pero siempre.',
  ),
  UniqueDef(
    id: 'relicarioMisericordia',
    name: 'Relicario de la Misericordia',
    baseId: 'maza_escudo_sagrada',
    fixed: [UniqueMod('de_la_fe', 15, 25), UniqueMod('del_sabio', 8, 12)],
    passiveId: 'misericordia',
    flavor: 'Guarda un rezo por cada herida que curó.',
  ),
  UniqueDef(
    id: 'bastionMilEras',
    name: 'Bastión de las Mil Eras',
    baseId: 'maza_escudo_eterna',
    fixed: [
      UniqueMod('del_baluarte', 6, 7),
      UniqueMod('de_la_pureza', 1, 1),
      UniqueMod('de_la_vida', 60, 90),
    ],
    passiveId: 'milEras',
    flavor: 'Mil eras lo golpearon. Mil eras perdieron.',
  ),
];
