import '../models/elements.dart';
import '../models/item.dart';
import 'uniques_catalog.dart';

// Elemento de base de las armas (docs/specs/weapon_identity.md § 4,
// aprobado). Puro Dart: lo leen la generación de botín, el motor de
// combate y la presentación (aura).

/// Probabilidad de que un Épico / Raro traiga elemento (los Legendarios
/// siempre; Común y Mágico nunca). Pendiente: hacerlos editables en Editor → Balance.
const double kWeaponElementChanceEpic = 0.40;
const double kWeaponElementChanceRare = 0.15;

/// Bonus de daño de las habilidades del mismo elemento que el arma.
const double kWeaponElementSynergy = 0.08;

/// El ataque básico elemental aplica 1 pila cada [kWeaponElementHitsPerStack]
/// golpes.
const int kWeaponElementHitsPerStack = 2;

/// Bases cuyo nombre ya trae el elemento: desde Raro, siempre ese.
const Map<String, GameElement> kBaseWeaponElement = {
  'espada_ignea': GameElement.fuego,
  'hacha_tormenta': GameElement.electro,
  'katana_escarcha': GameElement.hielo,
  'hacha_volcanica': GameElement.fuego,
  'baculo_fuego': GameElement.fuego,
  'baculo_escarcha': GameElement.hielo,
  'baculo_rayo': GameElement.electro,
  'tomo_plaga': GameElement.veneno,
  'baculo_ponzona': GameElement.veneno,
  'tomo_infernal': GameElement.fuego,
  'arco_tormenta': GameElement.electro,
  'rifle_glacial': GameElement.hielo,
  'arco_solar': GameElement.sagrado,
  'ballesta_glacial': GameElement.hielo,
  'rifle_pestilente': GameElement.veneno,
  'espada_escudo_alba': GameElement.sagrado,
  'martillo_escudo_juicio': GameElement.sagrado,
  'lanza_escarcha': GameElement.hielo,
  'lanza_dragon': GameElement.fuego,
  'hacha_glaciar': GameElement.hielo,
  'lanza_tormenta': GameElement.electro,
  'varita_hielo': GameElement.hielo,
  'tomo_escarcha': GameElement.hielo,
  'varita_rayo': GameElement.electro,
  'tomo_cienaga': GameElement.veneno,
  'ballesta_ignea': GameElement.fuego,
  'dagas_vibora': GameElement.veneno,
  'maza_escudo_sagrada': GameElement.sagrado,
  'martillo_escudo_trueno': GameElement.electro,
  'espada_escudo_aurora': GameElement.sagrado,
  'maza_escudo_bendita': GameElement.sagrado,
};

/// Elemento de cada legendario, coherente con su tema (también es la
/// migración de los legendarios ya guardados).
const Map<String, GameElement> kUniqueWeaponElement = {
  'juramentoAlba': GameElement.sagrado,
  'segadoraEras': GameElement.veneno,
  'fauceVolcan': GameElement.fuego,
  'rompemundos': GameElement.electro,
  'lanzaHorizonte': GameElement.electro,
  'corazonAscua': GameElement.fuego,
  'inviernoPerpetuo': GameElement.hielo,
  'codiceUltimoDia': GameElement.agua,
  'relampagoDormido': GameElement.electro,
  'susurroVibora': GameElement.veneno,
  'ojoHalconSolar': GameElement.sagrado,
  'truenoBronce': GameElement.electro,
  'ballestaJuicio': GameElement.sagrado,
  'primaveraRota': GameElement.agua,
  'pulsoAutomata': GameElement.electro,
  'yunqueEras': GameElement.fuego,
  'egidaPrimerRey': GameElement.sagrado,
  'martilloOcasoSagrado': GameElement.sagrado,
  'relicarioMisericordia': GameElement.sagrado,
  'bastionMilEras': GameElement.hielo,
  'manecillaAbismo': GameElement.agua,
  'espejoSinFondo': GameElement.hielo,
  'coronaInvertida': GameElement.sagrado,
  'fauceEras': GameElement.veneno,
  'prismaPrimordial': GameElement.agua,
  'filoPrimordial': GameElement.fuego,
};

/// Pool de elementos por tipo de arma (Raro / Épico sin elemento en el
/// nombre).
const Map<String, List<GameElement>> kWeaponTypeElements = {
  'espada': [GameElement.fuego, GameElement.hielo, GameElement.electro, GameElement.sagrado],
  'hacha': [GameElement.fuego, GameElement.electro, GameElement.hielo],
  'lanza': [GameElement.electro, GameElement.hielo, GameElement.agua],
  'báculo': [GameElement.fuego, GameElement.hielo, GameElement.electro, GameElement.agua],
  'tomo': [GameElement.veneno, GameElement.fuego, GameElement.sagrado, GameElement.agua],
  'varita': [GameElement.electro, GameElement.hielo, GameElement.agua],
  'arco': [GameElement.electro, GameElement.sagrado, GameElement.agua, GameElement.veneno],
  'rifle': [GameElement.electro, GameElement.hielo, GameElement.fuego],
  'ballesta': [GameElement.fuego, GameElement.hielo, GameElement.veneno],
  'dagas': [GameElement.veneno, GameElement.electro, GameElement.agua],
  'espada+escudo': [GameElement.sagrado, GameElement.agua, GameElement.electro],
  'maza+escudo': [GameElement.sagrado, GameElement.agua, GameElement.hielo],
  'martillo+escudo': [GameElement.sagrado, GameElement.electro, GameElement.fuego],
};

/// Pool del tipo [type] (todos los no físicos si no está listado).
List<GameElement> weaponElementPool(String type) =>
    kWeaponTypeElements[type] ??
    [for (final e in GameElement.values) if (e != GameElement.fisico) e];

/// Elemento de un legendario: el de su tema, si no el de su base, si no
/// Sagrado (todo legendario tiene elemento).
GameElement uniqueWeaponElement(String uniqueId) =>
    kUniqueWeaponElement[uniqueId] ??
    kBaseWeaponElement[kUniques[uniqueId]?.baseId] ??
    GameElement.sagrado;

/// Puede traer elemento de base (Raro, Épico, Legendario).
bool rarityAllowsElement(Rarity r) => r.index >= Rarity.raro.index;

/// Elemento efectivo del arma [i] (`null` = sin elemento). Lee los
/// legendarios del catálogo aunque el guardado sea anterior al campo.
GameElement? weaponElementOf(ItemInstance? i) {
  if (i == null) return null;
  if (i.rarity == Rarity.legendario && i.uniqueId != null) {
    return uniqueWeaponElement(i.uniqueId!);
  }
  if (!rarityAllowsElement(i.rarity)) return null;
  final e = i.element;
  return e == GameElement.fisico ? null : e;
}
