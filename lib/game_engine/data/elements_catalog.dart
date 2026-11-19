import '../models/elements.dart';
import '../models/enemy_def.dart';
import '../models/skill.dart';
import '../models/status.dart';
import 'branch_ults_catalog.dart' show kBranchUltElement;
import 'summoner_catalog.dart';

export '../models/elements.dart';

// Elementos y reacciones v0.7: qué elemento tiene cada habilidad, ULT y
// ataque enemigo, y los números de las reacciones y de los estados
// elementales (docs/specs/elemental_reactions.md § 8; tabla en
// docs/specs/combat.md § "Elementos"). Los números son catálogo: el admin
// de balance los edita (`BalanceKind.reaction` / `elementStatus`).

const _fisico = GameElement.fisico;
const _fuego = GameElement.fuego;
const _hielo = GameElement.hielo;
const _veneno = GameElement.veneno;
const _sagrado = GameElement.sagrado;
const _agua = GameElement.agua;
const _electro = GameElement.electro;

/// Elemento de cada habilidad, ULT (por tipo de arma y de ascensión),
/// variante y kit, por `SkillDef.id`. Explícito, como `kSkillDelivery`
/// (test: cubre todo `kSkills` y todas las ULT). Criterio: el estado que
/// aplica la habilidad (Quemadura = fuego...), Sagrado para las curas y
/// la luz del paladín, y [GameElement.fisico] (neutro) para el resto; Flecha
/// Rayo y Descarga son Electro, Marea Vital es Agua.
const Map<String, GameElement> kSkillElement = {
  // ---- Quebrar base (combo_balance.md § 5.1) ----
  'quebrar': _fisico,
  'quebrarArcano': _fisico,
  // ---- Combo de clase (combo_balance.md § 5.2) ----
  'brasaEco': _fuego, // Brasa Fugaz (prepara Quemadura)
  'selloInstante': _fisico, // Sello del Instante (Marca)
  'ascuaEco': _fuego, // Ascua Fugaz (prepara Quemadura)
  'puaEco': _veneno, // Púa Fugaz (prepara Veneno)
  'ignicionEco': _fuego, // Ignición Convergente (detona Veneno)
  'ponzonaEco': _veneno, // Ponzoña Convergente (detona Quemadura)
  // ---- Habilidades de arma y ULT por tipo de arma ----
  'giro': _fisico, // Corte Giratorio
  'embestida': _fisico, // Embestida
  'ignea': _fuego, // Golpe Ígneo
  'sismo': _fisico, // Golpe Sísmico
  'hendir': _veneno, // Hendidura Tóxica
  'tajoT': _hielo, // Tajo Temporal
  'chispa': _fuego, // Chispa
  'cura': _sagrado, // Cura
  'bola': _fuego, // Bola de Fuego
  'llamarada': _fuego, // Llamarada
  'lanzaH': _hielo, // Lanza de Hielo
  'ventisca': _hielo, // Ventisca
  'prisa': _fisico, // Prisa (aliados)
  'detener': _fisico, // Detener
  'curaM': _sagrado, // Cura Mayor
  'rafaga': _fisico, // Ráfaga
  'venenosa': _veneno, // Flecha Venenosa
  'certero': _fisico, // Disparo Certero
  'aturdir': _fisico, // Disparo Aturdidor
  'rayoF': _electro, // Flecha Rayo
  'lluvia': _fisico, // Lluvia de Flechas
  'sagrado': _sagrado, // Golpe Sagrado
  'provocar': _fisico, // Provocar
  'escudoFe': _fisico, // Escudo de Fe
  'bendicion': _sagrado, // Bendición
  'lanzaLuz': _sagrado, // Lanza de Luz
  'consagrar': _sagrado, // Consagrar
  'juicio': _sagrado, // Martillo del Juicio
  'corteGlacial': _hielo, // Corte Glacial
  'erupcion': _fuego, // Erupción
  'dardo': _veneno, // Dardo Tóxico
  'niebla': _veneno, // Niebla Tóxica
  'infierno': _fuego, // Infierno
  'saeta': _hielo, // Saeta Glacial
  'metralla': _veneno, // Metralla Tóxica
  'estocada': _fisico, // Estocada Firme
  'temblor': _fisico, // Temblor
  'sanar': _sagrado, // Sanación
  'golpeEscudo': _fisico, // Golpe de Escudo
  'aplastar': _fisico, // Aplastar
  'tajoCarmesi': _fuego, // Tajo Carmesí
  'vendaval': _hielo, // Vendaval Helado
  'tajoOcaso': _veneno, // Tajo del Ocaso
  'descarga': _electro, // Descarga
  'plaga': _veneno, // Plaga
  'sombra': _veneno, // Flecha Sombría
  'ceroAbs': _hielo, // Cero Absoluto
  'flechaSolar': _fuego, // Flecha Solar
  'perfora': _fisico, // Tiro Perforante
  'perforar': _fisico, // Lanza Perforante
  'barrido': _fisico, // Barrido de Lanza
  'empalar': _fisico, // Empalar
  'misil': _fisico, // Misil Arcano
  'escarchaFugaz': _hielo, // Escarcha Fugaz
  'rayoArcano': _fisico, // Rayo Arcano
  'virote': _fisico, // Virote Pesado
  'viroteIgneo': _fuego, // Virote Ígneo
  'tajoGemelo': _fisico, // Tajo Gemelo
  'abanico': _veneno, // Abanico de Dagas
  'ult_espada': _fisico, // Tajo Final
  'ult_hacha': _fisico, // Cataclismo
  'ult_baculo': _fuego, // Meteoro
  'ult_tomo': _hielo, // Paradoja
  'ult_arco': _veneno, // Tormenta de Flechas
  'ult_rifle': _fisico, // Disparo Letal
  'ult_espada_escudo': _fisico, // Baluarte
  'ult_maza_escudo': _sagrado, // Juicio Divino
  'ult_martillo_escudo': _sagrado, // Martillo Celestial
  'ult_lanza': _fisico, // Lluvia de Lanzas
  'ult_varita': _fisico, // Tormenta Arcana
  'ult_ballesta': _fisico, // Andanada
  'ult_dagas': _fisico, // Danza de Mil Cortes
  // ---- Variantes v0.5 ----
  'curaFocal': _sagrado, // Cura Focalizada
  'rocio': _sagrado, // Rocío Sanador
  'brotes': _sagrado, // Brotes de Vida
  'semilla': _sagrado, // Semilla Vital
  'purificar': _sagrado, // Purificación
  'resurreccion': _sagrado, // Resurrección
  'fenix': _sagrado, // Llama Fénix
  'graciaDesbordante': _sagrado, // Gracia Desbordante
  'marea': _agua, // Marea Vital
  'flechaSanadora': _fisico, // Flecha Sanadora
  'drenar': _fisico, // Drenar Vida
  'sifon': _fisico, // Sifón Vital
  'escudoArcano': _fisico, // Escudo Arcano
  'barrera': _fisico, // Barrera
  'egidaEspinosa': _fisico, // Égida Espinosa
  'escudoVolatil': _fisico, // Escudo Volátil
  'bastionCreciente': _fisico, // Bastión Creciente
  'retoEscudado': _fisico, // Reto Escudado
  'murallaFe': _fisico, // Muralla de Fe
  'cupula': _fisico, // Cúpula Arcana
  'flechaPerforante': _fisico, // Flecha Perforante
  'balaTraspasante': _fisico, // Bala Traspasante
  'tiroRebote': _fisico, // Tiro de Rebote
  'dagaSaltarina': _veneno, // Daga Saltarina
  'disparoCargado': _fisico, // Disparo Cargado
  'viroteAsedio': _fisico, // Virote de Asedio
  'rafagaTriple': _fisico, // Ráfaga Triple
  'cadencia': _fisico, // Cadencia Letal
  'flechaMarcadora': _fisico, // Flecha Marcadora
  'senalar': _fisico, // Señalar Presa
  'flechaIncendiaria': _fuego, // Flecha Incendiaria
  'flechaEscarcha': _hielo, // Flecha de Escarcha
  'balaCorrosiva': _veneno, // Bala Corrosiva
  'tiroQuebrantador': _fisico, // Tiro Quebrantador
  'rompearmaduras': _fisico, // Rompearmaduras
  'rugidoIntimidante': _fisico, // Rugido Intimidante
  'golpeDebilitante': _fisico, // Golpe Debilitante
  'lentitud': _fisico, // Lentitud
  'maldicion': _fisico, // Maldición
  'pesoTiempo': _fisico, // Peso del Tiempo
  'golpeConmocion': _fisico, // Conmoción
  'silencio': _fisico, // Silencio
  'selloSagrado': _sagrado, // Sello Sagrado
  'retroceso': _fisico, // Ola de Retroceso
  'inspirar': _fisico, // Inspirar
  'vientoPrisa': _fisico, // Viento de Prisa
  'impulso': _fisico, // Impulso Temporal
  'ojoAguila': _fisico, // Ojo de Águila
  // ---- Kit y ULT de las ascensiones (Elementalista v0.7: Prisma y Detonar
  // neutros; Detonar y Trinidad son catalizadores, ascension.md § 4.1) ----
  'sangria': _fisico, // Sangría
  'torbellino': _fisico, // Torbellino Rojo
  'gritoGuerra': _fisico, // Grito de Guerra
  'estandarte': _fisico, // Estandarte
  'aceleron': _fisico, // Acelerón
  'grietaTemporal': _fisico, // Grieta Temporal
  'prismaElemental': _fisico, // Prisma Elemental (prepara: no detona)
  'detonar': _fisico, // Detonar (catalizador)
  'tiroCabeza': _fisico, // Tiro a la Cabeza
  'apuntar': _fisico, // Apuntar
  'trampaPuas': _fisico, // Trampa de Púas
  'redCaza': _veneno, // Red de Caza
  'castigo': _sagrado, // Castigo Sagrado
  'luzCegadora': _sagrado, // Luz Cegadora
  'proteccion': _fisico, // Protección
  'fortaleza': _fisico, // Fortaleza
  'aura': _sagrado, // Aura Restauradora
  'ult_berserker': _fisico, // Frenesí Carmesí
  'ult_senorGuerra': _fisico, // Llamado a las Armas
  'ult_cronomante': _fisico, // Detener el Tiempo
  'ult_elementalista': _agua, // Trinidad (catalizador; deja Mojado)
  'ult_francotirador': _fisico, // Bala del Juicio
  'ult_trampero': _fisico, // Campo Minado
  'ult_templario': _sagrado, // Juicio Final
  'ult_guardian': _fisico, // Fortaleza Inquebrantable
  // ---- Agua y Electro (v0.7) ----
  'chorro': _agua, // Chorro de Agua
  'oleada': _agua, // Oleada
  'geiser': _agua, // Géiser
  'torrente': _agua, // Torrente
  'bruma': _agua, // Bruma Densa
  'escudoAgua': _agua, // Escudo de Agua
  'tajoMarea': _agua, // Tajo de Marea
  'remolino': _agua, // Remolino
  'lanzaMareas': _agua, // Lanza de las Mareas
  'flechaAcuatica': _agua, // Flecha Acuática
  'chispazo': _electro, // Chispazo
  'cadenaRayos': _electro, // Cadena de Rayos
  'tormentaElectrica': _electro, // Tormenta Eléctrica
  'descargaEstatica': _electro, // Descarga Estática
  'campoEstatico': _electro, // Campo Estático
  'corriente': _electro, // Corriente
  'golpeTrueno': _electro, // Golpe de Trueno
  'dagaElectrica': _electro, // Puñalada Eléctrica
  'flechaVoltaica': _electro, // Flecha Voltaica
  'relampago': _electro, // Relámpago
  // Invocador v0.8.1 (docs/specs/summoner.md).
  ...kSummonerSkillElement,
};

/// Habilidades que solo PREPARAN: sus estados no cuentan como elemento
/// del golpe (elemental_reactions.md § 9; Prisma Elemental es "golpe
/// neutro: no detona", ascension.md § 4.1).
const Set<String> kPrimeOnlySkills = {'prismaElemental'};

/// Elemento de la habilidad o ULT [skillId] (`fisico` si no tiene).
/// Las ULT de camino (branch_ults.md) llevan el suyo en `kBranchUltElement`.
GameElement elementOf(String? skillId) => skillId == null
    ? GameElement.fisico
    : kSkillElement[skillId] ?? kBranchUltElement[skillId] ?? GameElement.fisico;

/// Elemento de un ataque combinado: el de su estado.
GameElement elementOfDual(DualDef d) => statusElement(d.status.kind) ?? GameElement.fisico;

/// Elemento de los ataques de cada tipo de enemigo cuando no sale de su
/// estado (docs/specs/bestiary.md § 4). Los demás: el elemento del estado
/// que aplica ese golpe (Quemadura = fuego...) o físico.
const Map<String, GameElement> kEnemyElement = {
  // Zona 4: la Sierpe moja con su mordida y congela con su Aliento.
  'sierpe': _agua,
  // Zona 9: el Vigilante moja, el Ojo y el Centinela electrocutan.
  'vigilanteVacio': _agua,
  'ojoAbismo': _electro,
  'centinela': _electro,
};

/// Elemento de las ULT enemigas que no sale de su estado.
const Map<String, GameElement> kEnemyUltElement = {
  // El Centinela inunda el campo (Mojado) para electrocutar después.
  'eult_colapsoVacio': _agua,
};

/// Elemento del ataque normal de [d] que aplica [inflicted].
GameElement enemyAttackElement(EnemyDef? d, StatusApplication? inflicted) =>
    kEnemyElement[d?.id] ??
    (inflicted == null ? null : statusElement(inflicted.kind)) ??
    GameElement.fisico;

/// Elemento de la ULT enemiga [u].
GameElement enemyUltElement(EnemyUltDef u) =>
    kEnemyUltElement[u.id] ??
    (u.status == null ? null : statusElement(u.status!.kind)) ??
    GameElement.fisico;

/// Números de las reacciones (§ 2 y § 6).
const Map<String, ReactionDef> kReactions = {
  'electrocucion': ReactionDef(kind: ReactionKind.electrocucion, damageMult: 1.5, stunTurns: 1),
  // Convergencias v0.9 (combo_balance.md § 4): % de vida máx. por stack.
  'explosionToxica': ReactionDef(kind: ReactionKind.explosionToxica, perStack: 0.025, splash: 0.3, commonCap: 0.70, eliteCap: 0.55, bossCap: 0.40),
  'combustion': ReactionDef(kind: ReactionKind.combustion, perStack: 0.025, splash: 0.3, commonCap: 0.70, eliteCap: 0.55, bossCap: 0.40),
  'congelacionSubita': ReactionDef(kind: ReactionKind.congelacionSubita),
  'derretir': ReactionDef(kind: ReactionKind.derretir, damageMult: 1.5),
  'cortocircuito': ReactionDef(kind: ReactionKind.cortocircuito, splash: 0.5),
};

/// Reglas de los estados elementales (§ 1 y § 7).
const Map<String, ElementStatusDef> kElementStatuses = {
  'wet': ElementStatusDef(kind: StatusKind.wet, turns: 2),
  'charged': ElementStatusDef(kind: StatusKind.charged, turns: 1),
  'freeze': ElementStatusDef(kind: StatusKind.freeze, turns: 2, slowPerStack: 0.06, breakPerStack: 0.10, brittleMult: 1.5),
};
