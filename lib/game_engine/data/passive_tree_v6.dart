import '../models/elements.dart' show ReactionKind;
import '../models/passive_mechanic.dart';
import '../models/status.dart';
import 'enemy_families.dart' show EnemyFamily;

// Árbol de pasivas v6 (v0.8, docs/specs/passive_tree_v6.md): el anillo
// exterior. Datos puros (sin geometría, que vive en
// passive_tree_catalog.dart): qué cluster va dónde, qué mecánica tiene
// cada notable y keystone, y qué efecto chico tiene cada nodo chico.
//
// Regla del dueño (v6 § 3): ningún nodo nuevo es un stat pelado. Los
// chicos tienen un efecto chico atado al kit de la clase o a un estado
// (modificadores, sin log ni proc salvo los de probabilidad); los
// notables cambian la forma de jugar; las keystones definen el build y
// traen contra.

/// Efecto de un nodo chico: plantilla de mecánica (el `id` se completa
/// con el id de cada nodo, ver [kTreeV6SmallMechanics]).
typedef V6Small = PassiveMechanic;

/// Cluster exterior de clase: id, nombre, tema, chico A (`s1`, `s2`,
/// `m1`, `m2`), chico B (`ma`, `mb`, `ma2`, `mb2`, `m3`), mecánicas de
/// los notables `n1`, `na`, `nb`, `nc`, `nd` y de la keystone `k`.
typedef V6Cluster = (
  String id,
  String name,
  String theme,
  V6Small a,
  V6Small b,
  List<String> notables,
  String keystone,
);

/// Puente elemental: id, nombre, tema, chico del eje (`i1`, `l1`, `r1`),
/// chico del brazo A (`a1`, `a2`, `h1`), chico del brazo B (`b1`, `b2`,
/// `h2`), notables `na`, `nb`, `n1`, `nl`, `nr` y keystone `k`.
typedef V6Bridge = (
  String id,
  String name,
  String theme,
  V6Small x,
  V6Small a,
  V6Small b,
  List<String> notables,
  String keystone,
);

/// Cluster de grupo exterior: id, nombre, tema, chico A (`e1`, `a1`,
/// `a2`), chico B (`b1`, `b2`), notables `n0`, `na`, `nb`, `nt`.
typedef V6Group = (
  String id,
  String name,
  String theme,
  V6Small a,
  V6Small b,
  List<String> notables,
);

const _dmg = BuffStat.damage;
const _crit = BuffStat.crit;
const _bonus = ProcEffectKind.statBonus;
const _inflict = ProcEffectKind.inflict;
const _always = ProcTrigger.always;
const _vs = ProcTrigger.vsStatus;
const _aura = ProcTrigger.partyAura;

// ---------------- Plantillas de chicos ----------------

const _sm = '';

V6Small _vsDmg(String name, StatusKind st, double v, String label) =>
    PassiveMechanic(
      id: _sm,
      name: name,
      trigger: _vs,
      status: st,
      effects: [ProcEffect(_bonus, value: v, stat: _dmg)],
      description: '+${_p(v)} de daño contra enemigos $label.',
    );

V6Small _vsCrit(String name, StatusKind st, double v, String label) =>
    PassiveMechanic(
      id: _sm,
      name: name,
      trigger: _vs,
      status: st,
      effects: [ProcEffect(_bonus, value: v, stat: _crit)],
      description: '+${_p(v)} de crítico contra enemigos $label.',
    );

V6Small _vsBreak(String name, StatusKind st, double v, String label) =>
    PassiveMechanic(
      id: _sm,
      name: name,
      trigger: _vs,
      status: st,
      effects: [ProcEffect(ProcEffectKind.breakBonus, value: v)],
      description: 'Contra enemigos $label tus golpes llenan la barra de '
          'quiebre un ${_p(v)} más.',
    );

V6Small _vsFam(String name, EnemyFamily f, double v) => PassiveMechanic(
      id: _sm,
      name: name,
      trigger: ProcTrigger.vsFamily,
      family: f,
      effects: [ProcEffect(_bonus, value: v, stat: _dmg)],
      description: '+${_p(v)} de daño contra ${f.plural}.',
    );

V6Small _always1(String name, ProcEffect fx, String text,
        {ProcFilter filter = ProcFilter.any}) =>
    PassiveMechanic(
      id: _sm,
      name: name,
      trigger: _always,
      filter: filter,
      effects: [fx],
      description: text,
    );

V6Small _auraOf(String name, BuffStat stat, double v, String text) =>
    PassiveMechanic(
      id: _sm,
      name: name,
      trigger: _aura,
      effects: [ProcEffect(_bonus, value: v, stat: stat)],
      description: text,
    );

V6Small _moreStacks(String name, StatusKind st, String label) =>
    PassiveMechanic(
      id: _sm,
      name: name,
      trigger: ProcTrigger.onStatusApplied,
      status: st,
      chance: 0.15,
      effects: const [ProcEffect(ProcEffectKind.extraStacks, value: 1)],
      description: 'Al aplicar $label: 15% de +1 stack más.',
    );

String _p(double v) {
  final p = (v * 1000).round() / 10;
  return p == p.roundToDouble() ? '${p.round()}%' : '$p%';
}

// ---------------- Clusters exteriores de clase ----------------

/// Por clase, en el orden de sus clusters v4 de los que cuelgan: el `j`
/// cuelga del `_nc` del cluster v4 `j + 1` (θ − 15°, θ, θ + 15°).
final Map<String, List<V6Cluster>> kTreeV6Clusters = {
  'guerrero': [
    (
      'verdugo', 'Verdugo', 'rematar, cazar monstruos',
      _always1('Tajo Certero',
          const ProcEffect(_bonus, value: 0.06, stat: BuffStat.critMulti),
          'Tus críticos a un solo objetivo pegan ×0.06 más.',
          filter: ProcFilter.singleTarget),
      _vsFam('Sal y Acero', EnemyFamily.aberration, 0.08),
      ['decapitar', 'quiebrahuesos', 'desguace', 'cosecha', 'ejecucionPublica'],
      'verdugo',
    ),
    (
      'tempestad', 'Tempestad', 'Agua y Electro con el arma',
      _vsDmg('Estática', StatusKind.charged, 0.06, 'Cargados'),
      _vsCrit('Oleaje', StatusKind.wet, 0.04, 'Mojados'),
      ['martilloTrueno', 'resaca', 'truenoSordo', 'galerna', 'ojoTormenta'],
      'diosTrueno',
    ),
    (
      'vanguardia', 'Vanguardia', 'proteger y empujar al grupo',
      _auraOf('Escolta', BuffStat.guard, 0.01,
          'Mientras estés en pie, todo el grupo (vos incluido) recibe −1% '
              'de daño.'),
      _always1('Grito de Ánimo',
          const ProcEffect(_bonus, value: 0.06, stat: BuffStat.buffPower),
          'Tus buffs de grupo son 6% más fuertes.'),
      ['toqueClarin', 'guardaespaldas', 'animoInquebrantable',
        'formacionCerrada', 'gritoVictoria'],
      'primeraLinea',
    ),
  ],
  'maga': [
    (
      'marea', 'Marea', 'Agua: mojar, frenar y salpicar',
      _vsDmg('Gota', StatusKind.wet, 0.06, 'Mojados'),
      _vsCrit('Bajamar', StatusKind.wet, 0.04, 'Mojados'),
      ['pleamar', 'marejada', 'ahogo', 'vortice', 'tsunami'],
      'senoraMareas',
    ),
    (
      'voltio', 'Voltio', 'Electro: cargar, rebotar y electrocutar',
      _vsBreak('Chispa Viva', StatusKind.charged, 0.08, 'Cargados'),
      _always1('Bobina', const ProcEffect(ProcEffectKind.reactionBonus, value: 0.05),
          'Los golpes con los que detonás una reacción hacen +5%.'),
      ['arcoElectrico', 'sobretension', 'campoMagnetico',
        'relampagoGlobular', 'descargaCadena'],
      'corazonTormenta',
    ),
    (
      'alquimia', 'Alquimia', 'reacciones en cadena',
      _always1('Reactivo', const ProcEffect(ProcEffectKind.reactionBonus, value: 0.05),
          'Los golpes con los que detonás una reacción hacen +5%.'),
      const PassiveMechanic(
        id: _sm,
        name: 'Destilado',
        trigger: ProcTrigger.vsElements,
        minStacks: 2,
        effects: [ProcEffect(_bonus, value: 0.05, stat: _dmg)],
        description: '+5% de daño contra enemigos con 2 o más estados '
            'elementales distintos (Quemadura, Congelación, Veneno).',
      ),
      ['solvente', 'transmutacion', 'precipitado', 'reaccionCadena',
        'piedraFilosofal'],
      'granObra',
    ),
  ],
  'tirador': [
    (
      'monzon', 'Monzón', 'Agua en área para el grupo',
      _vsCrit('Llovizna', StatusKind.wet, 0.04, 'Mojados'),
      _always1('Tromba', const ProcEffect(_bonus, value: 0.04, stat: _dmg),
          'Tus habilidades de daño a todos (no ULT) hacen +4%.',
          filter: ProcFilter.areaSkill),
      ['aguanieve', 'remojon', 'tormentaTropical', 'inundacion', 'ojoMonzon'],
      'frenteTormenta',
    ),
    (
      'centella', 'Centella', 'Electro y críticos',
      _vsCrit('Gatillo Eléctrico', StatusKind.charged, 0.04, 'Cargados'),
      _always1('Voltaje',
          const ProcEffect(_bonus, value: 0.06, stat: BuffStat.critMulti),
          'Tus críticos a un solo objetivo pegan ×0.06 más.',
          filter: ProcFilter.singleTarget),
      ['flechaImantada', 'chispaCertera', 'electroshock', 'tensionMaxima',
        'truenoFinal'],
      'tormentaPerfecta',
    ),
    (
      'monteria', 'Montería', 'trampas y presas de cada familia',
      _always1('Trampero',
          const ProcEffect(_bonus, value: 0.08, stat: BuffStat.trapPower),
          'Tus trampas hacen +8% de daño.'),
      const PassiveMechanic(
        id: _sm,
        name: 'Rastreador',
        trigger: ProcTrigger.vsMarked,
        effects: [ProcEffect(_bonus, value: 0.05, stat: _dmg)],
        description: '+5% de daño contra enemigos marcados.',
      ),
      ['lazoCaza', 'cazadorAracnidos', 'cazadorCienos', 'cepo', 'trofeo'],
      'granCazador',
    ),
  ],
  'paladin': [
    (
      'exorcismo', 'Exorcismo', 'Sagrado contra no muertos y espectros',
      _vsDmg('Agua Bendita', StatusKind.holy, 0.06, 'con Sagrado'),
      _always1('Salmo', const ProcEffect(ProcEffectKind.healHarmBonus, value: 0.10),
          'Tus curas queman +10% a las familias que las curas dañan.'),
      ['exorcizar', 'destierro', 'consagracion', 'cegar', 'juicioFinal'],
      'inquisidor',
    ),
    (
      'manantial', 'Manantial', 'curar y cuidar al grupo',
      _always1('Fuente',
          const ProcEffect(_bonus, value: 0.06, stat: BuffStat.shieldPower),
          'Los escudos que das al grupo son 6% más grandes.'),
      _auraOf('Remanso', BuffStat.guard, 0.01,
          'Mientras estés en pie, todo el grupo (vos incluido) recibe −1% '
              'de daño.'),
      ['aguaBendecida', 'mareaSanadora', 'bautismo', 'fuenteVida',
        'desborde'],
      'santoPatrono',
    ),
    (
      'pararrayos', 'Pararrayos', 'Electro defensivo',
      _always1('Toma de Tierra',
          const ProcEffect(_bonus, value: 0.04, stat: BuffStat.guard),
          'Defendiendo recibís −4% de daño.',
          filter: ProcFilter.defending),
      _always1('Descarga a Tierra',
          const ProcEffect(_bonus, value: 0.06, stat: BuffStat.shieldReflect),
          'Tus escudos devuelven al atacante el 6% de lo que absorben.'),
      ['pararrayos', 'jaulaFaraday', 'poloOpuesto', 'retornoTierra',
        'tormentaProtectora'],
      'torreTormenta',
    ),
  ],
};

// ---------------- Puentes elementales ----------------

/// Uno por par de clases vecinas (el `i` une la clase `i` con la `i + 1`,
/// detrás del puente v3 `i`).
final List<V6Bridge> kTreeV6Bridges = [
  (
    'forja', 'Forja', 'puente Guerrero–Maga: fuego y quiebre',
    _always1('Yunque', const ProcEffect(ProcEffectKind.breakBonus, value: 0.06),
        'Tus golpes llenan la barra de quiebre un 6% más.'),
    _vsBreak('Martillazo', StatusKind.burn, 0.10, 'con Quemadura'),
    _moreStacks('Brasa Viva', StatusKind.burn, 'Quemadura'),
    ['temple', 'hierroRojo', 'crisol', 'aceroFundido', 'escoria'],
    'almaForja',
  ),
  (
    'galvanica', 'Galvánica', 'puente Maga–Tirador: Agua y Electro',
    _vsCrit('Electrolito', StatusKind.wet, 0.04, 'Mojados'),
    _always1('Condensador', const ProcEffect(ProcEffectKind.reactionBonus, value: 0.04),
        'Los golpes con los que detonás una reacción hacen +4%.'),
    _vsDmg('Hilo de Cobre', StatusKind.charged, 0.05, 'Cargados'),
    ['pila', 'electrolisis', 'circuitoCerrado', 'arcoPlasma',
      'corrienteAlterna'],
    'superconductor',
  ),
  (
    'eclipse', 'Eclipse', 'puente Tirador–Paladín: Veneno y Sagrado',
    _vsDmg('Penumbra', StatusKind.poison, 0.06, 'envenenados'),
    _moreStacks('Miasma', StatusKind.poison, 'Veneno'),
    _vsCrit('Ofrenda', StatusKind.holy, 0.04, 'con Sagrado'),
    ['purga', 'sombraSagrada', 'penitencia', 'corrupcion', 'antidoto'],
    'crepusculo',
  ),
  (
    'glaciar', 'Glaciar', 'puente Paladín–Guerrero: hielo y aguante',
    _vsDmg('Permafrost', StatusKind.freeze, 0.06, 'con Congelación'),
    _always1('Escarcha Dura',
        const ProcEffect(_bonus, value: 0.04, stat: BuffStat.guard),
        'Defendiendo recibís −4% de daño.',
        filter: ProcFilter.defending),
    _moreStacks('Témpano', StatusKind.freeze, 'Congelación'),
    ['avalancha', 'escarchaViva', 'glaciacion', 'quebrarTempanos',
      'alientoGelido'],
    'corazonGlaciar',
  ),
];

// ---------------- Clusters de grupo exteriores ----------------

/// En las diagonales, detrás de cada puente elemental.
final List<V6Group> kTreeV6Groups = [
  (
    'tactica', 'Táctica', 'grupo: preparar y detonar juntos',
    const PassiveMechanic(
      id: _sm,
      name: 'Señal',
      trigger: ProcTrigger.vsMarked,
      effects: [ProcEffect(_bonus, value: 0.03, stat: _crit)],
      description: '+3% de crítico contra enemigos marcados.',
    ),
    _auraOf('Coordinación', _dmg, 0.015,
        'Mientras estés en pie, todo el grupo (vos incluido) hace +1.5% de '
            'daño.'),
    ['preparacion', 'pinza', 'fuegoCruzado', 'golpeMaestro'],
  ),
  (
    'coro', 'Coro', 'grupo: ULT y buffs compartidos',
    _always1('Compás Mayor',
        const ProcEffect(_bonus, value: 0.05, stat: BuffStat.buffPower),
        'Tus buffs de grupo son 5% más fuertes.'),
    _auraOf('Eco Coral', _dmg, 0.015,
        'Mientras estés en pie, todo el grupo (vos incluido) hace +1.5% de '
            'daño.'),
    ['himno', 'contrapunto', 'canon', 'crescendo'],
  ),
  (
    'santuario', 'Santuario', 'grupo: curas y Sagrado',
    _auraOf('Vela', BuffStat.guard, 0.015,
        'Mientras estés en pie, todo el grupo (vos incluido) recibe −1.5% '
            'de daño.'),
    _auraOf('Incienso', BuffStat.holyPower, 0.10,
        'Mientras estés en pie, el Sagrado de los enemigos hace +10% por '
            'turno.'),
    ['altar', 'oracionCompartida', 'ultimoRezo', 'santuarioGrupal'],
  ),
  (
    'fortaleza', 'Fortaleza', 'grupo: escudos y protección',
    _always1('Almena',
        const ProcEffect(_bonus, value: 0.06, stat: BuffStat.shieldPower),
        'Los escudos que das al grupo son 6% más grandes.'),
    _auraOf('Bastión Común', BuffStat.guard, 0.015,
        'Mientras estés en pie, todo el grupo (vos incluido) recibe −1.5% '
            'de daño.'),
    ['rastrillo', 'torreHomenaje', 'foso', 'ciudadela'],
  ),
];

/// Sufijos de los chicos de cada forma y qué plantilla usan.
const kV6ClusterSmall = {
  's1': 'a', 's2': 'a', 'm1': 'a', 'm2': 'a', //
  'ma': 'b', 'mb': 'b', 'ma2': 'b', 'mb2': 'b', 'm3': 'b',
};
const kV6BridgeSmall = {
  'i1': 'x', 'l1': 'x', 'r1': 'x', //
  'a1': 'a', 'a2': 'a', 'h1': 'a',
  'b1': 'b', 'b2': 'b', 'h2': 'b',
};
const kV6GroupSmall = {'e1': 'a', 'a1': 'a', 'a2': 'a', 'b1': 'b', 'b2': 'b'};

/// Sufijos de los notables, en el orden de las listas de arriba.
const kV6ClusterNotables = ['n1', 'na', 'nb', 'nc', 'nd'];
const kV6BridgeNotables = ['na', 'nb', 'n1', 'nl', 'nr'];
const kV6GroupNotables = ['n0', 'na', 'nb', 'nt'];

PassiveMechanic _withId(PassiveMechanic t, String id) => PassiveMechanic(
      id: id,
      name: t.name,
      trigger: t.trigger,
      filter: t.filter,
      chance: t.chance,
      status: t.status,
      minStacks: t.minStacks,
      threshold: t.threshold,
      reaction: t.reaction,
      family: t.family,
      effects: t.effects,
      description: t.description,
    );

/// Una mecánica por nodo chico nuevo, con el id del nodo (así dos chicos
/// iguales suman: las mecánicas de un jugador son un conjunto de ids).
final List<PassiveMechanic> kTreeV6SmallMechanics = [
  for (final list in kTreeV6Clusters.values)
    for (final c in list)
      for (final MapEntry(key: s, value: t) in kV6ClusterSmall.entries)
        _withId(t == 'a' ? c.$4 : c.$5, '${c.$1}_$s'),
  for (final b in kTreeV6Bridges)
    for (final MapEntry(key: s, value: t) in kV6BridgeSmall.entries)
      _withId(switch (t) { 'x' => b.$4, 'a' => b.$5, _ => b.$6 }, '${b.$1}_$s'),
  for (final g in kTreeV6Groups)
    for (final MapEntry(key: s, value: t) in kV6GroupSmall.entries)
      _withId(t == 'a' ? g.$4 : g.$5, '${g.$1}_$s'),
];

/// Contras fijas de las keystones v6 (las suma `PassiveTreeRules`).
const List<(String, String, double)> kTreeV6Drawbacks = [
  ('verdugo', 'ult', -0.30),
  ('diosTrueno', 'hp', -0.15),
  ('primeraLinea', 'atk', -0.20),
  ('senoraMareas', 'mag', -0.15),
  ('corazonTormenta', 'hp', -0.20),
  ('granObra', 'mag', -0.12),
  ('frenteTormenta', 'atk', -0.20),
  ('tormentaPerfecta', 'hp', -0.15),
  ('granCazador', 'spd', -1.0),
  ('inquisidor', 'heal', -0.30),
  ('santoPatrono', 'atk', -0.25),
  ('torreTormenta', 'atk', -0.15),
  ('almaForja', 'mp', -0.30),
  ('superconductor', 'crit', -0.10),
  ('crepusculo', 'heal', -0.30),
  ('corazonGlaciar', 'spd', -1.0),
];

const _wet = StatusKind.wet;
const _charged = StatusKind.charged;
const _shield = BuffStat.shield;

/// Notables y keystones del árbol v6 (passive_tree_v6.md § 4-6). Solo
/// disparadores y efectos que ya existían.
const List<PassiveMechanic> kTreeV6Mechanics = [
  // ================= Guerrero: Verdugo =================
  PassiveMechanic(
    id: 'decapitar',
    name: 'Decapitar',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.singleTarget,
    effects: [ProcEffect(ProcEffectKind.execute, value: 0.15)],
    description: 'Tus golpes a un solo objetivo rematan a enemigos (no jefes '
        'ni élites) que queden con menos de 15% de vida.',
  ),
  PassiveMechanic(
    id: 'quiebrahuesos',
    name: 'Quiebrahuesos',
    trigger: ProcTrigger.vsFamily,
    family: EnemyFamily.undead,
    effects: [
      ProcEffect(_bonus, value: 0.25, stat: _dmg),
      ProcEffect(_bonus, value: 0.10, stat: _crit),
    ],
    description: 'Contra No muertos: +25% de daño y +10% de crítico.',
  ),
  PassiveMechanic(
    id: 'desguace',
    name: 'Desguace',
    trigger: ProcTrigger.vsFamily,
    family: EnemyFamily.construct,
    effects: [
      ProcEffect(_bonus, value: 0.25, stat: _dmg),
      ProcEffect(_bonus, value: 0.10, stat: _crit),
    ],
    description: 'Contra Constructos: +25% de daño y +10% de crítico.',
  ),
  PassiveMechanic(
    id: 'cosecha',
    name: 'Cosecha',
    trigger: ProcTrigger.onKill,
    effects: [
      ProcEffect(ProcEffectKind.buffSelf,
          value: 0.20, turns: 3, stat: BuffStat.attack)
    ],
    description: 'Al matar: +20% ATQ por 3 turnos (renueva; 1 vez por '
        'acción).',
  ),
  PassiveMechanic(
    id: 'ejecucionPublica',
    name: 'Ejecución Pública',
    trigger: ProcTrigger.onKill,
    effects: [
      ProcEffect(ProcEffectKind.buffParty, value: 0.10, turns: 2, stat: _dmg)
    ],
    description: 'Al matar: todo el grupo (vos incluido) +10% de daño por 2 '
        'turnos (1 vez por acción).',
  ),
  PassiveMechanic(
    id: 'verdugo',
    name: 'Verdugo',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.singleTarget,
    effects: [ProcEffect(ProcEffectKind.execute, value: 0.25)],
    description: 'Tus golpes a un solo objetivo rematan a enemigos (no jefes '
        'ni élites) que queden con menos de 25% de vida. Pero tu ULT carga '
        '30% menos.',
  ),
  // ================= Guerrero: Tempestad =================
  PassiveMechanic(
    id: 'martilloTrueno',
    name: 'Martillo Trueno',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.singleTarget,
    chance: 0.25,
    effects: [ProcEffect(_inflict, value: 1, status: _charged)],
    description: 'Tus golpes a un solo objetivo: 25% de dejarlo Cargado (un '
        'golpe de Agua lo hace Cortocircuito).',
  ),
  PassiveMechanic(
    id: 'resaca',
    name: 'Resaca',
    trigger: ProcTrigger.onReaction,
    reaction: ReactionKind.electrocucion,
    effects: [
      ProcEffect(ProcEffectKind.buffSelf,
          value: 0.25, turns: 2, stat: BuffStat.attack)
    ],
    description: 'Al detonar una Electrocución: +25% ATQ por 2 turnos '
        '(renueva).',
  ),
  PassiveMechanic(
    id: 'truenoSordo',
    name: 'Trueno Sordo',
    trigger: _vs,
    status: _charged,
    effects: [ProcEffect(ProcEffectKind.breakBonus, value: 0.40)],
    description: 'Contra enemigos Cargados tus golpes llenan la barra de '
        'quiebre un 40% más.',
  ),
  PassiveMechanic(
    id: 'galerna',
    name: 'Galerna',
    trigger: ProcTrigger.onBreak,
    effects: [ProcEffect(_inflict, value: 1, status: _wet)],
    description: 'Cuando vos o un aliado quiebran a un enemigo: queda '
        'Mojado (un Electro lo electrocuta).',
  ),
  PassiveMechanic(
    id: 'ojoTormenta',
    name: 'Ojo de la Tormenta',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.singleTarget,
    status: _wet,
    chance: 0.30,
    effects: [ProcEffect(_inflict, value: 1, status: StatusKind.stun)],
    description: 'Tus golpes a un solo enemigo Mojado: 30% de aturdirlo.',
  ),
  PassiveMechanic(
    id: 'diosTrueno',
    name: 'Dios del Trueno',
    trigger: ProcTrigger.onHit,
    effects: [ProcEffect(_inflict, value: 1, status: _charged)],
    description: 'Cada golpe tuyo (ataque, habilidad, ULT) deja Cargado al '
        'objetivo. Pero −15% vida máx.',
  ),
  // ================= Guerrero: Vanguardia =================
  PassiveMechanic(
    id: 'toqueClarin',
    name: 'Toque de Clarín',
    trigger: ProcTrigger.onUltimate,
    effects: [ProcEffect(ProcEffectKind.advanceParty, value: 0.25)],
    description: 'Al usar tu ULT: los aliados se adelantan 25% de su espera '
        '(solo: tu próximo turno llega antes).',
  ),
  PassiveMechanic(
    id: 'guardaespaldas',
    name: 'Guardaespaldas',
    trigger: ProcTrigger.onProtectHit,
    effects: [ProcEffect(ProcEffectKind.reflect, value: 0.30)],
    description: 'Cuando recibís un golpe dirigido a un aliado bajo tu '
        'Protección: devolvés el 30% al atacante.',
  ),
  PassiveMechanic(
    id: 'animoInquebrantable',
    name: 'Ánimo Inquebrantable',
    trigger: ProcTrigger.onAllyDown,
    effects: [
      ProcEffect(ProcEffectKind.buffParty,
          value: 0.20, turns: 3, stat: BuffStat.attack)
    ],
    description: 'Cuando cae un aliado: el grupo en pie +20% ATQ por 3 '
        'turnos.',
  ),
  PassiveMechanic(
    id: 'formacionCerrada',
    name: 'Formación Cerrada',
    trigger: ProcTrigger.onHitTaken,
    filter: ProcFilter.defending,
    effects: [
      ProcEffect(ProcEffectKind.shieldLowestAlly,
          value: 0.08, turns: 2, stat: _shield)
    ],
    description: 'Al recibir un golpe defendiendo: el aliado con menor % de '
        'vida (vos incluido) gana un escudo del 8% de tu vida máx. (2 '
        'turnos).',
  ),
  PassiveMechanic(
    id: 'gritoVictoria',
    name: 'Grito de Victoria',
    trigger: ProcTrigger.onKill,
    effects: [ProcEffect(ProcEffectKind.ultChargeParty, value: 10)],
    description: 'Al matar: +10 de carga de ULT a cada aliado (1 vez por '
        'acción).',
  ),
  PassiveMechanic(
    id: 'primeraLinea',
    name: 'Primera Línea',
    trigger: _aura,
    effects: [ProcEffect(_bonus, value: 0.10, stat: BuffStat.guard)],
    description: 'Mientras estés en pie, todo el grupo (vos incluido) recibe '
        '−10% de daño (tope de defensa 60%). Pero −20% ATQ.',
  ),
  // ================= Maga: Marea =================
  PassiveMechanic(
    id: 'pleamar',
    name: 'Pleamar',
    trigger: ProcTrigger.onStatusApplied,
    status: _wet,
    effects: [ProcEffect(ProcEffectKind.delayTarget, value: 0.10)],
    description: 'Al mojar a un enemigo: se retrasa un 10% de su espera en el '
        'timeline.',
  ),
  PassiveMechanic(
    id: 'marejada',
    name: 'Marejada',
    trigger: ProcTrigger.onReaction,
    reaction: ReactionKind.congelacionSubita,
    effects: [
      ProcEffect(ProcEffectKind.ultCharge, value: 15),
      ProcEffect(ProcEffectKind.advanceTurn, value: 0.20),
    ],
    description: 'Al detonar una Congelación súbita: +15 de carga de ULT y tu '
        'próximo turno llega 20% antes.',
  ),
  PassiveMechanic(
    id: 'ahogo',
    name: 'Ahogo',
    trigger: _vs,
    status: _wet,
    effects: [ProcEffect(_bonus, value: 0.20, stat: _dmg)],
    description: '+20% de daño contra enemigos Mojados.',
  ),
  PassiveMechanic(
    id: 'vortice',
    name: 'Vórtice',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.areaSkill,
    status: _wet,
    effects: [
      ProcEffect(ProcEffectKind.debuffTarget,
          value: -0.15, turns: 2, stat: BuffStat.speed)
    ],
    description: 'Tus habilidades a todos (no ULT): los enemigos Mojados '
        'golpeados pierden 15% de velocidad por 2 turnos.',
  ),
  PassiveMechanic(
    id: 'tsunami',
    name: 'Tsunami',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.magicalSingle,
    status: _wet,
    effects: [ProcEffect(ProcEffectKind.burst, value: 0.30)],
    description: 'Tus habilidades mágicas a un solo enemigo Mojado salpican '
        'el 30% del golpe a cada otro enemigo.',
  ),
  PassiveMechanic(
    id: 'senoraMareas',
    name: 'Señora de las Mareas',
    trigger: ProcTrigger.onHit,
    effects: [ProcEffect(_inflict, value: 1, status: _wet)],
    description: 'Cada golpe tuyo (ataque, habilidad, ULT) deja Mojado al '
        'objetivo. Pero −15% MAG.',
  ),
  // ================= Maga: Voltio =================
  PassiveMechanic(
    id: 'arcoElectrico',
    name: 'Arco Eléctrico',
    trigger: ProcTrigger.onStatusApplied,
    status: _charged,
    effects: [ProcEffect(ProcEffectKind.chain, value: 0.35)],
    description: 'Al cargar a un enemigo: tu golpe rebota a otro enemigo con '
        'el 35% del daño.',
  ),
  PassiveMechanic(
    id: 'sobretension',
    name: 'Sobretensión',
    trigger: ProcTrigger.onReaction,
    reaction: ReactionKind.electrocucion,
    effects: [ProcEffect(ProcEffectKind.ultCharge, value: 15)],
    description: 'Al detonar una Electrocución: +15 de carga de ULT.',
  ),
  PassiveMechanic(
    id: 'campoMagnetico',
    name: 'Campo Magnético',
    trigger: ProcTrigger.onStatusApplied,
    status: _charged,
    effects: [
      ProcEffect(ProcEffectKind.debuffTarget,
          value: -0.15, turns: 2, stat: BuffStat.attack)
    ],
    description: 'Al cargar a un enemigo: pega −15% ATQ por 2 turnos. No '
        'acumula.',
  ),
  PassiveMechanic(
    id: 'relampagoGlobular',
    name: 'Relámpago Globular',
    trigger: ProcTrigger.onReaction,
    reaction: ReactionKind.cortocircuito,
    effects: [ProcEffect(ProcEffectKind.advanceTurn, value: 0.30)],
    description: 'Al detonar un Cortocircuito: tu próximo turno llega 30% '
        'antes.',
  ),
  PassiveMechanic(
    id: 'descargaCadena',
    name: 'Descarga en Cadena',
    trigger: ProcTrigger.onCrit,
    effects: [ProcEffect(_inflict, value: 1, status: _charged)],
    description: 'Al hacer crítico: el objetivo queda Cargado.',
  ),
  PassiveMechanic(
    id: 'corazonTormenta',
    name: 'Corazón de Tormenta',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.magicalSingle,
    effects: [
      ProcEffect(_inflict, value: 1, status: _charged),
      ProcEffect(ProcEffectKind.chain, value: 0.40),
    ],
    description: 'Tus habilidades mágicas a un solo objetivo lo dejan Cargado '
        'y rebotan a otro enemigo con el 40% del daño. Pero −20% vida máx.',
  ),
  // ================= Maga: Alquimia =================
  PassiveMechanic(
    id: 'solvente',
    name: 'Solvente',
    trigger: ProcTrigger.onReaction,
    reaction: ReactionKind.derretir,
    effects: [ProcEffect(_inflict, value: 1, status: _wet)],
    description: 'Tu Derretir deja Mojado al objetivo (el hielo se vuelve '
        'agua: un Electro lo electrocuta).',
  ),
  PassiveMechanic(
    id: 'transmutacion',
    name: 'Transmutación',
    trigger: ProcTrigger.onReaction,
    reaction: ReactionKind.electrocucion,
    effects: [ProcEffect(_inflict, value: 2, status: StatusKind.poison)],
    description: 'Tu Electrocución deja 2 Veneno al objetivo (un fuego lo '
        'hace explotar).',
  ),
  PassiveMechanic(
    id: 'precipitado',
    name: 'Precipitado',
    trigger: ProcTrigger.onReaction,
    reaction: ReactionKind.explosionToxica,
    effects: [
      ProcEffect(ProcEffectKind.reactionStatus,
          value: 0.5, status: StatusKind.freeze)
    ],
    description: 'Tu Explosión tóxica deja Congelación igual a la mitad de '
        'los Venenos consumidos (redondeo arriba).',
  ),
  PassiveMechanic(
    id: 'reaccionCadena',
    name: 'Reacción en Cadena',
    trigger: ProcTrigger.onReaction,
    effects: [ProcEffect(ProcEffectKind.spreadAll, value: 0.5)],
    description: 'Al detonar una reacción: la mitad de la Quemadura, '
        'Congelación y Veneno que le quede al objetivo pasa a los demás '
        'enemigos.',
  ),
  PassiveMechanic(
    id: 'piedraFilosofal',
    name: 'Piedra Filosofal',
    trigger: _always,
    effects: [ProcEffect(ProcEffectKind.reactionBonus, value: 0.20)],
    description: 'Los golpes con los que detonás una reacción hacen +20%.',
  ),
  PassiveMechanic(
    id: 'granObra',
    name: 'Gran Obra',
    trigger: ProcTrigger.onStatusApplied,
    effects: [ProcEffect(ProcEffectKind.addElement, value: 1)],
    description: 'Al aplicar Quemadura, Congelación o Veneno, el objetivo '
        'recibe además 1 stack del primero que no tiene. Pero −12% MAG.',
  ),
  // ================= Tirador: Monzón =================
  PassiveMechanic(
    id: 'aguanieve',
    name: 'Aguanieve',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.areaSkill,
    status: _wet,
    effects: [ProcEffect(_inflict, value: 1, status: StatusKind.freeze)],
    description: 'Tus habilidades a todos (no ULT): +1 Congelación a cada '
        'enemigo Mojado golpeado.',
  ),
  PassiveMechanic(
    id: 'remojon',
    name: 'Remojón',
    trigger: ProcTrigger.onPrimedReaction,
    effects: [ProcEffect(ProcEffectKind.ultCharge, value: 12)],
    description: 'Cuando alguien (vos incluido) detona un estado que '
        'preparaste vos: +12 de carga de ULT.',
  ),
  PassiveMechanic(
    id: 'tormentaTropical',
    name: 'Tormenta Tropical',
    trigger: ProcTrigger.onSkill,
    filter: ProcFilter.areaSkill,
    effects: [
      ProcEffect(ProcEffectKind.buffParty, value: 0.10, turns: 2, stat: _crit)
    ],
    description: 'Después de una habilidad de daño a todos (no ULT): todo el '
        'grupo +10% crítico por 2 turnos.',
  ),
  PassiveMechanic(
    id: 'inundacion',
    name: 'Inundación',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.areaSkill,
    status: _wet,
    effects: [
      ProcEffect(ProcEffectKind.markTarget,
          value: 0.12, turns: 3, stat: BuffStat.damageTaken)
    ],
    description: 'Tus habilidades a todos (no ULT) marcan a los enemigos '
        'Mojados sin marca: +12% de daño recibido de todos (3 turnos).',
  ),
  PassiveMechanic(
    id: 'ojoMonzon',
    name: 'Ojo del Monzón',
    trigger: ProcTrigger.onPartyReaction,
    effects: [ProcEffect(ProcEffectKind.healParty, value: 0.03)],
    description: 'Cuando vos o un aliado detonan una reacción: todo el grupo '
        'se cura 3% de su vida máx. (1 vez por acción).',
  ),
  PassiveMechanic(
    id: 'frenteTormenta',
    name: 'Frente de Tormenta',
    trigger: ProcTrigger.onSkill,
    filter: ProcFilter.areaSkill,
    effects: [ProcEffect(ProcEffectKind.advanceParty, value: 0.25)],
    description: 'Después de una habilidad de daño a todos (no ULT): los '
        'aliados se adelantan 25% de su espera (solo: tu próximo turno). '
        'Pero −20% ATQ.',
  ),
  // ================= Tirador: Centella =================
  PassiveMechanic(
    id: 'flechaImantada',
    name: 'Flecha Imantada',
    trigger: ProcTrigger.onCrit,
    filter: ProcFilter.singleTarget,
    effects: [ProcEffect(_inflict, value: 1, status: _charged)],
    description: 'Al hacer crítico a un solo objetivo: queda Cargado.',
  ),
  PassiveMechanic(
    id: 'chispaCertera',
    name: 'Chispa Certera',
    trigger: _vs,
    status: _charged,
    effects: [ProcEffect(_bonus, value: 0.20, stat: _crit)],
    description: '+20% crítico contra enemigos Cargados.',
  ),
  PassiveMechanic(
    id: 'electroshock',
    name: 'Electroshock',
    trigger: ProcTrigger.onReaction,
    reaction: ReactionKind.electrocucion,
    effects: [
      ProcEffect(ProcEffectKind.markTarget,
          value: 0.20, turns: 3, stat: BuffStat.damageTaken)
    ],
    description: 'Tu Electrocución marca al objetivo si no tiene marca: +20% '
        'de daño recibido de todos por 3 turnos.',
  ),
  PassiveMechanic(
    id: 'tensionMaxima',
    name: 'Tensión Máxima',
    trigger: ProcTrigger.onReaction,
    reaction: ReactionKind.electrocucion,
    effects: [ProcEffect(ProcEffectKind.advanceTurn, value: 0.30)],
    description: 'Al detonar una Electrocución: tu próximo turno llega 30% '
        'antes.',
  ),
  PassiveMechanic(
    id: 'truenoFinal',
    name: 'Trueno Final',
    trigger: ProcTrigger.onEnemyDeath,
    status: _charged,
    effects: [ProcEffect(ProcEffectKind.spreadStatus)],
    description: 'Al morir un enemigo Cargado: el Cargado pasa al enemigo '
        'vivo con más vida.',
  ),
  PassiveMechanic(
    id: 'tormentaPerfecta',
    name: 'Tormenta Perfecta',
    trigger: _vs,
    status: _charged,
    effects: [
      ProcEffect(_bonus, value: 0.25, stat: _crit),
      ProcEffect(_bonus, value: 0.15, stat: _dmg),
    ],
    description: 'Contra enemigos Cargados: +25% crítico y +15% de daño. '
        'Pero −15% vida máx.',
  ),
  // ================= Tirador: Montería =================
  PassiveMechanic(
    id: 'lazoCaza',
    name: 'Lazo de Caza',
    trigger: ProcTrigger.onTrap,
    effects: [
      ProcEffect(ProcEffectKind.markTarget,
          value: 0.20, turns: 3, stat: BuffStat.damageTaken)
    ],
    description: 'Al saltar una trampa tuya: marca al enemigo si no tiene '
        'marca (+20% de daño recibido de todos, 3 turnos).',
  ),
  PassiveMechanic(
    id: 'cazadorAracnidos',
    name: 'Cazador de Arácnidos',
    trigger: ProcTrigger.vsFamily,
    family: EnemyFamily.arachnid,
    effects: [
      ProcEffect(_bonus, value: 0.25, stat: _dmg),
      ProcEffect(_bonus, value: 0.10, stat: _crit),
    ],
    description: 'Contra Arácnidos: +25% de daño y +10% de crítico.',
  ),
  PassiveMechanic(
    id: 'cazadorCienos',
    name: 'Cazador de Cienos',
    trigger: ProcTrigger.vsFamily,
    family: EnemyFamily.ooze,
    effects: [
      ProcEffect(_bonus, value: 0.25, stat: _dmg),
      ProcEffect(_bonus, value: 0.10, stat: _crit),
    ],
    description: 'Contra Cienos: +25% de daño y +10% de crítico.',
  ),
  PassiveMechanic(
    id: 'cepo',
    name: 'Cepo',
    trigger: ProcTrigger.onTrap,
    chance: 0.30,
    effects: [ProcEffect(_inflict, value: 1, status: StatusKind.stun)],
    description: 'Al saltar una trampa tuya: 30% de aturdir al enemigo.',
  ),
  PassiveMechanic(
    id: 'trofeo',
    name: 'Trofeo',
    trigger: ProcTrigger.onKill,
    effects: [
      ProcEffect(ProcEffectKind.ultCharge, value: 10),
      ProcEffect(ProcEffectKind.healSelf, value: 0.05),
    ],
    description: 'Al matar: +10 de carga de ULT y te curás 5% de tu vida '
        'máx. (1 vez por acción).',
  ),
  PassiveMechanic(
    id: 'granCazador',
    name: 'Gran Cazador',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.singleTarget,
    effects: [
      ProcEffect(ProcEffectKind.plantTrap,
          value: 0.5, turns: 2, stat: BuffStat.trap)
    ],
    description: 'Cada golpe tuyo a un solo objetivo le deja una trampa: ATQ '
        '× 0.5 al empezar su turno (2 turnos). Pero −1 velocidad.',
  ),
  // ================= Paladín: Exorcismo =================
  PassiveMechanic(
    id: 'exorcizar',
    name: 'Exorcizar',
    trigger: ProcTrigger.vsFamily,
    family: EnemyFamily.spectre,
    effects: [
      ProcEffect(_bonus, value: 0.25, stat: _dmg),
      ProcEffect(_bonus, value: 0.10, stat: _crit),
    ],
    description: 'Contra Espectros: +25% de daño y +10% de crítico.',
  ),
  PassiveMechanic(
    id: 'destierro',
    name: 'Destierro',
    trigger: ProcTrigger.vsFamily,
    family: EnemyFamily.undead,
    effects: [ProcEffect(_bonus, value: 0.30, stat: _dmg)],
    description: 'Contra No muertos: +30% de daño.',
  ),
  PassiveMechanic(
    id: 'consagracion',
    name: 'Consagración',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.singleTarget,
    status: StatusKind.holy,
    effects: [ProcEffect(ProcEffectKind.extraStacks, value: 1)],
    description: 'Tus golpes a un solo enemigo con Sagrado le suman 1 '
        'Sagrado.',
  ),
  PassiveMechanic(
    id: 'cegar',
    name: 'Cegar',
    trigger: ProcTrigger.onHit,
    status: StatusKind.holy,
    effects: [
      ProcEffect(ProcEffectKind.debuffTarget,
          value: -0.15, turns: 2, stat: BuffStat.attack)
    ],
    description: 'Al golpear a un enemigo con Sagrado: pega −15% ATQ por 2 '
        'turnos. No acumula.',
  ),
  PassiveMechanic(
    id: 'juicioFinal',
    name: 'Juicio Final',
    trigger: ProcTrigger.onEnemyDeath,
    status: StatusKind.holy,
    effects: [ProcEffect(ProcEffectKind.spreadStatus)],
    description: 'Al morir un enemigo con Sagrado: su Sagrado pasa al '
        'enemigo vivo con más vida.',
  ),
  PassiveMechanic(
    id: 'inquisidor',
    name: 'Inquisidor',
    trigger: _vs,
    status: StatusKind.holy,
    effects: [ProcEffect(_bonus, value: 0.30, stat: _dmg)],
    description: '+30% de daño contra enemigos con Sagrado. Pero −30% '
        'curación.',
  ),
  // ================= Paladín: Manantial =================
  PassiveMechanic(
    id: 'aguaBendecida',
    name: 'Agua Bendecida',
    trigger: ProcTrigger.onHeal,
    effects: [ProcEffect(ProcEffectKind.ultCharge, value: 4)],
    description: 'Cada curación tuya a un aliado: +4 de carga de ULT (1 vez '
        'por acción).',
  ),
  PassiveMechanic(
    id: 'mareaSanadora',
    name: 'Marea Sanadora',
    trigger: ProcTrigger.onUltimate,
    effects: [ProcEffect(ProcEffectKind.healParty, value: 0.10)],
    description: 'Al usar tu ULT: todo el grupo se cura 10% de su vida máx.',
  ),
  PassiveMechanic(
    id: 'bautismo',
    name: 'Bautismo',
    trigger: ProcTrigger.onAllyDown,
    effects: [ProcEffect(ProcEffectKind.healParty, value: 0.15)],
    description: 'Cuando cae un aliado: el grupo en pie se cura 15% de su '
        'vida máx.',
  ),
  PassiveMechanic(
    id: 'fuenteVida',
    name: 'Fuente de Vida',
    trigger: ProcTrigger.onHeal,
    effects: [ProcEffect(ProcEffectKind.advanceAlly, value: 0.15)],
    description: 'Al curar: el aliado más lento se adelanta 15% de su espera '
        '(solo: tu próximo turno llega 15% antes; 1 vez por acción).',
  ),
  PassiveMechanic(
    id: 'desborde',
    name: 'Desborde',
    trigger: ProcTrigger.onHeal,
    effects: [ProcEffect(ProcEffectKind.healParty, value: 0.03)],
    description: 'Cada curación tuya también cura 3% de su vida máx. a todo '
        'el grupo (1 vez por acción).',
  ),
  PassiveMechanic(
    id: 'santoPatrono',
    name: 'Santo Patrono',
    trigger: ProcTrigger.onTurnStart,
    effects: [ProcEffect(ProcEffectKind.healParty, value: 0.05)],
    description: 'Al empezar tu turno: todo el grupo se cura 5% de su vida '
        'máx. Pero −25% ATQ.',
  ),
  // ================= Paladín: Pararrayos =================
  PassiveMechanic(
    id: 'pararrayos',
    name: 'Pararrayos',
    trigger: ProcTrigger.onHitTaken,
    effects: [ProcEffect(_inflict, value: 1, status: _charged)],
    description: 'Al recibir un golpe: el atacante queda Cargado (un golpe de '
        'Agua de tu grupo lo hace Cortocircuito).',
  ),
  PassiveMechanic(
    id: 'jaulaFaraday',
    name: 'Jaula de Faraday',
    trigger: ProcTrigger.onHitTaken,
    filter: ProcFilter.belowThreshold,
    threshold: 0.5,
    effects: [
      ProcEffect(ProcEffectKind.shieldSelf, value: 0.12, turns: 2, stat: _shield)
    ],
    description: 'Al recibir un golpe con menos de 50% de vida: escudo del 12% '
        'de tu vida máx. por 2 turnos (no acumula).',
  ),
  PassiveMechanic(
    id: 'poloOpuesto',
    name: 'Polo Opuesto',
    trigger: ProcTrigger.onProtectHit,
    effects: [
      ProcEffect(_inflict, value: 1, status: _charged),
      ProcEffect(ProcEffectKind.ultCharge, value: 4),
    ],
    description: 'Cuando recibís un golpe dirigido a un aliado bajo tu '
        'Protección: el atacante queda Cargado y ganás +4 de carga de ULT.',
  ),
  PassiveMechanic(
    id: 'retornoTierra',
    name: 'Retorno a Tierra',
    trigger: ProcTrigger.onHitTaken,
    effects: [
      ProcEffect(ProcEffectKind.debuffTarget,
          value: -0.10, turns: 2, stat: BuffStat.attack)
    ],
    description: 'Al recibir un golpe: el atacante pega −10% ATQ por 2 '
        'turnos. No acumula.',
  ),
  PassiveMechanic(
    id: 'tormentaProtectora',
    name: 'Tormenta Protectora',
    trigger: ProcTrigger.onSkill,
    filter: ProcFilter.guardSkill,
    effects: [
      ProcEffect(ProcEffectKind.shieldParty, value: 0.08, turns: 2, stat: _shield)
    ],
    description: 'Al usar Provocar, Protección o Escudo de Fe: todo el grupo '
        'gana un escudo del 8% de tu vida máx. (2 turnos).',
  ),
  PassiveMechanic(
    id: 'torreTormenta',
    name: 'Torre de Tormenta',
    trigger: ProcTrigger.onHitTaken,
    effects: [
      ProcEffect(ProcEffectKind.reflect, value: 0.40),
      ProcEffect(_inflict, value: 1, status: _charged),
    ],
    description: 'Al recibir un golpe: devolvés el 40% al atacante y queda '
        'Cargado. Pero −15% ATQ.',
  ),
  // ================= Puente Forja (Guerrero–Maga) =================
  PassiveMechanic(
    id: 'temple',
    name: 'Temple',
    trigger: ProcTrigger.onBreak,
    effects: [ProcEffect(_inflict, value: 2, status: StatusKind.burn)],
    description: 'Cuando vos o un aliado quiebran a un enemigo: +2 Quemadura '
        'al quebrado.',
  ),
  PassiveMechanic(
    id: 'hierroRojo',
    name: 'Hierro al Rojo',
    trigger: _vs,
    status: StatusKind.burn,
    effects: [ProcEffect(ProcEffectKind.breakBonus, value: 0.40)],
    description: 'Contra enemigos con Quemadura tus golpes llenan la barra de '
        'quiebre un 40% más.',
  ),
  PassiveMechanic(
    id: 'crisol',
    name: 'Crisol',
    trigger: ProcTrigger.onReaction,
    reaction: ReactionKind.derretir,
    effects: [ProcEffect(_inflict, value: 3, status: StatusKind.burn)],
    description: 'Tu Derretir deja 3 Quemadura al objetivo.',
  ),
  PassiveMechanic(
    id: 'aceroFundido',
    name: 'Acero Fundido',
    trigger: _vs,
    status: StatusKind.burn,
    effects: [ProcEffect(_bonus, value: 0.15, stat: _crit)],
    description: '+15% crítico contra enemigos con Quemadura.',
  ),
  PassiveMechanic(
    id: 'escoria',
    name: 'Escoria',
    trigger: ProcTrigger.onBreak,
    effects: [
      ProcEffect(ProcEffectKind.debuffTarget,
          value: -0.20, turns: 2, stat: BuffStat.attack)
    ],
    description: 'Cuando vos o un aliado quiebran a un enemigo: pega −20% ATQ '
        'por 2 turnos.',
  ),
  PassiveMechanic(
    id: 'almaForja',
    name: 'Alma de Forja',
    trigger: _vs,
    status: StatusKind.burn,
    effects: [
      ProcEffect(_bonus, value: 0.25, stat: _dmg),
      ProcEffect(ProcEffectKind.breakBonus, value: 0.50),
    ],
    description: 'Contra enemigos con Quemadura: +25% de daño y llenás la '
        'barra de quiebre un 50% más. Pero −30% maná máx.',
  ),
  // ================= Puente Galvánica (Maga–Tirador) =================
  PassiveMechanic(
    id: 'pila',
    name: 'Pila',
    trigger: ProcTrigger.onReaction,
    reaction: ReactionKind.cortocircuito,
    effects: [ProcEffect(ProcEffectKind.ultCharge, value: 12)],
    description: 'Al detonar un Cortocircuito: +12 de carga de ULT.',
  ),
  PassiveMechanic(
    id: 'electrolisis',
    name: 'Electrólisis',
    trigger: ProcTrigger.onReaction,
    reaction: ReactionKind.electrocucion,
    effects: [ProcEffect(_inflict, value: 1, status: _charged)],
    description: 'Tu Electrocución deja Cargado al objetivo (un golpe de Agua '
        'lo hace Cortocircuito).',
  ),
  PassiveMechanic(
    id: 'circuitoCerrado',
    name: 'Circuito Cerrado',
    trigger: ProcTrigger.onReaction,
    reaction: ReactionKind.cortocircuito,
    effects: [ProcEffect(_inflict, value: 1, status: _wet)],
    description: 'Tu Cortocircuito deja Mojado al objetivo (un Electro lo '
        'electrocuta).',
  ),
  PassiveMechanic(
    id: 'arcoPlasma',
    name: 'Arco de Plasma',
    trigger: _vs,
    status: _charged,
    effects: [
      ProcEffect(_bonus, value: 0.15, stat: _dmg),
      ProcEffect(_bonus, value: 0.05, stat: _crit),
    ],
    description: 'Contra enemigos Cargados: +15% de daño y +5% de crítico.',
  ),
  PassiveMechanic(
    id: 'corrienteAlterna',
    name: 'Corriente Alterna',
    trigger: ProcTrigger.onStatusApplied,
    status: _wet,
    chance: 0.30,
    effects: [ProcEffect(_inflict, value: 1, status: _charged)],
    description: 'Al mojar a un enemigo: 30% de dejarlo también Cargado.',
  ),
  PassiveMechanic(
    id: 'superconductor',
    name: 'Superconductor',
    trigger: _always,
    effects: [ProcEffect(ProcEffectKind.reactionBonus, value: 0.50)],
    description: 'Los golpes con los que detonás una reacción hacen +50%. '
        'Pero −10% crítico.',
  ),
  // ================= Puente Eclipse (Tirador–Paladín) =================
  PassiveMechanic(
    id: 'purga',
    name: 'Purga',
    trigger: ProcTrigger.onEnemyDeath,
    status: StatusKind.poison,
    effects: [ProcEffect(ProcEffectKind.healParty, value: 0.04)],
    description: 'Al morir un enemigo envenenado: todo el grupo se cura 4% de '
        'su vida máx.',
  ),
  PassiveMechanic(
    id: 'sombraSagrada',
    name: 'Sombra Sagrada',
    trigger: ProcTrigger.onCrit,
    effects: [ProcEffect(_inflict, value: 2, status: StatusKind.poison)],
    description: 'Al hacer crítico: +2 Veneno al objetivo.',
  ),
  PassiveMechanic(
    id: 'penitencia',
    name: 'Penitencia',
    trigger: ProcTrigger.onStatusApplied,
    status: StatusKind.poison,
    effects: [ProcEffect(_inflict, value: 1, status: StatusKind.holy)],
    description: 'Al envenenar a un enemigo: +1 Sagrado.',
  ),
  PassiveMechanic(
    id: 'corrupcion',
    name: 'Corrupción',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.singleTarget,
    status: StatusKind.poison,
    minStacks: 5,
    effects: [ProcEffect(ProcEffectKind.holyDamage, value: 0.5)],
    description: 'Tus golpes a un solo enemigo con 5+ Veneno: daño sagrado '
        'MAG × 0.5.',
  ),
  PassiveMechanic(
    id: 'antidoto',
    name: 'Antídoto',
    trigger: ProcTrigger.onKill,
    effects: [ProcEffect(ProcEffectKind.healLowestAlly, value: 0.08)],
    description: 'Al matar: el aliado con menor % de vida (vos incluido) se '
        'cura 8% de su vida máx. (1 vez por acción).',
  ),
  PassiveMechanic(
    id: 'crepusculo',
    name: 'Crepúsculo',
    trigger: _vs,
    status: StatusKind.poison,
    effects: [
      ProcEffect(_bonus, value: 0.20, stat: _dmg),
      ProcEffect(_bonus, value: 0.10, stat: _crit),
    ],
    description: 'Contra enemigos envenenados: +20% de daño y +10% de '
        'crítico. Pero −30% curación.',
  ),
  // ================= Puente Glaciar (Paladín–Guerrero) =================
  PassiveMechanic(
    id: 'avalancha',
    name: 'Avalancha',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.singleTarget,
    status: StatusKind.freeze,
    minStacks: 3,
    effects: [ProcEffect(ProcEffectKind.burst, value: 0.40)],
    description: 'Tus golpes a un solo enemigo con 3+ Congelación salpican el '
        '40% del golpe a cada otro enemigo.',
  ),
  PassiveMechanic(
    id: 'escarchaViva',
    name: 'Escarcha Viva',
    trigger: ProcTrigger.onStatusApplied,
    status: StatusKind.freeze,
    effects: [
      ProcEffect(ProcEffectKind.debuffTarget,
          value: -0.15, turns: 2, stat: BuffStat.attack)
    ],
    description: 'Al congelar a un enemigo: pega −15% ATQ por 2 turnos. No '
        'acumula.',
  ),
  PassiveMechanic(
    id: 'glaciacion',
    name: 'Glaciación',
    trigger: ProcTrigger.onReaction,
    reaction: ReactionKind.congelacionSubita,
    effects: [
      ProcEffect(ProcEffectKind.shieldSelf, value: 0.12, turns: 2, stat: _shield)
    ],
    description: 'Al detonar una Congelación súbita: escudo del 12% de tu '
        'vida máx. por 2 turnos.',
  ),
  PassiveMechanic(
    id: 'quebrarTempanos',
    name: 'Quebrar Témpanos',
    trigger: _vs,
    status: StatusKind.freeze,
    effects: [ProcEffect(_bonus, value: 0.15, stat: _crit)],
    description: '+15% crítico contra enemigos con Congelación.',
  ),
  PassiveMechanic(
    id: 'alientoGelido',
    name: 'Aliento Gélido',
    trigger: ProcTrigger.onUltimate,
    effects: [
      ProcEffect(ProcEffectKind.buffParty,
          value: 0.10, turns: 2, stat: BuffStat.guard)
    ],
    description: 'Al usar tu ULT: todo el grupo recibe −10% de daño por 2 '
        'turnos.',
  ),
  PassiveMechanic(
    id: 'corazonGlaciar',
    name: 'Corazón Glaciar',
    trigger: ProcTrigger.onHitTaken,
    effects: [ProcEffect(_inflict, value: 2, status: StatusKind.freeze)],
    description: 'Al recibir un golpe: el atacante recibe 2 Congelación. Pero '
        '−1 velocidad.',
  ),
  // ================= Grupo: Táctica =================
  PassiveMechanic(
    id: 'preparacion',
    name: 'Preparación',
    trigger: ProcTrigger.onPrimedReaction,
    effects: [
      ProcEffect(ProcEffectKind.buffSelf, value: 0.15, turns: 2, stat: _dmg)
    ],
    description: 'Cuando alguien (vos incluido) detona un estado que '
        'preparaste vos: +15% de daño por 2 turnos (renueva).',
  ),
  PassiveMechanic(
    id: 'pinza',
    name: 'Pinza',
    trigger: ProcTrigger.onPartyReaction,
    effects: [ProcEffect(ProcEffectKind.ultCharge, value: 6)],
    description: 'Cuando vos o un aliado detonan una reacción: +6 de carga de '
        'ULT para vos (1 vez por acción).',
  ),
  PassiveMechanic(
    id: 'fuegoCruzado',
    name: 'Fuego Cruzado',
    trigger: ProcTrigger.onBreak,
    effects: [
      ProcEffect(ProcEffectKind.markTarget,
          value: 0.15, turns: 3, stat: BuffStat.damageTaken)
    ],
    description: 'Cuando vos o un aliado quiebran a un enemigo: lo marca si '
        'no tiene marca (+15% de daño recibido de todos, 3 turnos).',
  ),
  PassiveMechanic(
    id: 'golpeMaestro',
    name: 'Golpe Maestro',
    trigger: ProcTrigger.onPrimedReaction,
    effects: [
      ProcEffect(ProcEffectKind.buffParty, value: 0.10, turns: 2, stat: _dmg)
    ],
    description: 'Cuando alguien (vos incluido) detona un estado que '
        'preparaste vos: todo el grupo +10% de daño por 2 turnos.',
  ),
  // ================= Grupo: Coro =================
  PassiveMechanic(
    id: 'himno',
    name: 'Himno',
    trigger: ProcTrigger.onUltimate,
    effects: [
      ProcEffect(ProcEffectKind.buffParty,
          value: 0.15, turns: 2, stat: BuffStat.speed)
    ],
    description: 'Al usar tu ULT: todo el grupo +15% velocidad por 2 turnos.',
  ),
  PassiveMechanic(
    id: 'contrapunto',
    name: 'Contrapunto',
    trigger: ProcTrigger.onBreak,
    effects: [
      ProcEffect(ProcEffectKind.buffParty, value: 0.10, turns: 2, stat: _crit)
    ],
    description: 'Cuando vos o un aliado quiebran a un enemigo: todo el grupo '
        '+10% crítico por 2 turnos.',
  ),
  PassiveMechanic(
    id: 'canon',
    name: 'Canon',
    trigger: _always,
    effects: [ProcEffect(_bonus, value: 1, stat: BuffStat.buffTurns)],
    description: 'Tus buffs de grupo duran 1 turno más.',
  ),
  PassiveMechanic(
    id: 'crescendo',
    name: 'Crescendo',
    trigger: ProcTrigger.onTurnStart,
    effects: [ProcEffect(ProcEffectKind.ultChargeParty, value: 4)],
    description: 'Al empezar tu turno: +4 de carga de ULT a cada aliado.',
  ),
  // ================= Grupo: Santuario =================
  PassiveMechanic(
    id: 'altar',
    name: 'Altar',
    trigger: _aura,
    effects: [ProcEffect(_bonus, value: 0.25, stat: BuffStat.holyPower)],
    description: 'Mientras estés en pie, el Sagrado de los enemigos hace +25% '
        'por turno.',
  ),
  PassiveMechanic(
    id: 'oracionCompartida',
    name: 'Oración Compartida',
    trigger: ProcTrigger.onHeal,
    effects: [
      ProcEffect(ProcEffectKind.shieldLowestAlly,
          value: 0.05, turns: 1, stat: _shield)
    ],
    description: 'Al curar: el aliado con menor % de vida (vos incluido) gana '
        'un escudo del 5% de tu vida máx. (1 turno; 1 vez por acción).',
  ),
  PassiveMechanic(
    id: 'ultimoRezo',
    name: 'Último Rezo',
    trigger: ProcTrigger.onAllyDown,
    effects: [
      ProcEffect(ProcEffectKind.shieldParty, value: 0.12, turns: 2, stat: _shield)
    ],
    description: 'Cuando cae un aliado: el grupo en pie gana un escudo del 12% '
        'de tu vida máx. (2 turnos).',
  ),
  PassiveMechanic(
    id: 'santuarioGrupal',
    name: 'Santuario',
    trigger: ProcTrigger.onTurnStart,
    effects: [ProcEffect(ProcEffectKind.healParty, value: 0.02)],
    description: 'Al empezar tu turno: todo el grupo se cura 2% de su vida '
        'máx.',
  ),
  // ================= Grupo: Fortaleza =================
  PassiveMechanic(
    id: 'rastrillo',
    name: 'Rastrillo',
    trigger: ProcTrigger.onProtectHit,
    effects: [
      ProcEffect(ProcEffectKind.shieldSelf, value: 0.08, turns: 1, stat: _shield)
    ],
    description: 'Cuando recibís un golpe dirigido a un aliado bajo tu '
        'Protección: escudo del 8% de tu vida máx. (1 turno).',
  ),
  PassiveMechanic(
    id: 'torreHomenaje',
    name: 'Torre del Homenaje',
    trigger: ProcTrigger.onHitTaken,
    filter: ProcFilter.defending,
    effects: [ProcEffect(ProcEffectKind.ultChargeParty, value: 4)],
    description: 'Al recibir un golpe defendiendo: +4 de carga de ULT a cada '
        'aliado.',
  ),
  PassiveMechanic(
    id: 'foso',
    name: 'Foso',
    trigger: ProcTrigger.onProtectHit,
    effects: [ProcEffect(ProcEffectKind.delayTarget, value: 0.25)],
    description: 'Cuando recibís un golpe dirigido a un aliado bajo tu '
        'Protección: el atacante se retrasa un 25% de su espera.',
  ),
  PassiveMechanic(
    id: 'ciudadela',
    name: 'Ciudadela',
    trigger: ProcTrigger.onAllyDown,
    effects: [
      ProcEffect(ProcEffectKind.buffParty,
          value: 0.20, turns: 3, stat: BuffStat.guard)
    ],
    description: 'Cuando cae un aliado: el grupo en pie recibe −20% de daño '
        'por 3 turnos.',
  ),
];
