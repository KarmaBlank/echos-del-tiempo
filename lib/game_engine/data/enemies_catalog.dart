import '../models/enemy_def.dart';
import '../models/status.dart';

/// `EN` del prototipo, 1:1. El sprite, color y escala de cada enemigo
/// son arte y se resuelven por id en `assets/sprites/sprite_manifest.yaml`.
/// `breakMax` y `ultId`: docs/specs/break_and_enemy_ults.md.
const Map<String, EnemyDef> kEnemies = {
  'slime': EnemyDef(id: 'slime', name: 'Limo', hp: 30, attack: 7, speed: 7, xp: 6, credits: 5,
      inflicts: StatusApplication(StatusKind.poison, 1), breakMax: 25),
  'bat': EnemyDef(id: 'bat', name: 'Murciélago', hp: 22, attack: 9, speed: 13, xp: 7, credits: 6,
      pierce: true, breakMax: 20),
  'golem': EnemyDef(id: 'golem', name: 'Gólem', hp: 70, attack: 12, speed: 5, xp: 14, credits: 12,
      breakMax: 50),
  'ghost': EnemyDef(id: 'ghost', name: 'Espectro', hp: 55, attack: 15, speed: 11, xp: 16, credits: 14,
      pierce: true, inflicts: StatusApplication(StatusKind.freeze, 1), breakMax: 40),
  'reyLimo': EnemyDef(id: 'reyLimo', name: 'Rey Limo', hp: 230, attack: 13, speed: 8, xp: 60, credits: 80,
      boss: true, inflicts: StatusApplication(StatusKind.poison, 2), breakMax: 80, ultId: 'eult_diluvio',
      title: 'Soberano de la Pradera'),
  'golemReloj': EnemyDef(id: 'golemReloj', name: 'Gólem Reloj', hp: 430, attack: 18, speed: 7, xp: 120, credits: 150,
      boss: true, inflicts: StatusApplication(StatusKind.freeze, 2), breakMax: 150, ultId: 'eult_engranaje',
      title: 'Guardián de las Ruinas Cronales'),
  // Jefe final (zona 10, nivel 50; v0.3 rebalanceado y con 2 fases).
  'devorador': EnemyDef(id: 'devorador', name: 'Devorador de Eras', hp: 2600, attack: 64, speed: 10, xp: 400, credits: 500,
      boss: true, areaAttack: true, inflicts: StatusApplication(StatusKind.burn, 2), breakMax: 910, ultId: 'eult_finEras',
      title: 'El hambre al final del tiempo', mechanicId: 'fases', legendaryId: 'segadoraEras'),

  // ---- v0.2.0 (docs/specs/bosses.md § "v0.2"): stats al nivel nativo de
  // `kEnemyBaseLevel` (comunes: mínimo de su zona; jefes: máximo). ----

  // Zona 2 · Bosque Hondo (comunes nivel 6, jefe nivel 10).
  'arana': EnemyDef(id: 'arana', name: 'Araña', hp: 52, attack: 11, speed: 10, xp: 8, credits: 7,
      inflicts: StatusApplication(StatusKind.poison, 1), breakMax: 42, feminine: true),
  'lobo': EnemyDef(id: 'lobo', name: 'Lobo', hp: 50, attack: 12, speed: 14, xp: 8, credits: 7,
      pierce: true, breakMax: 40),
  'matriarca': EnemyDef(id: 'matriarca', name: 'Matriarca Araña', hp: 480, attack: 21, speed: 9, xp: 90, credits: 110,
      boss: true, inflicts: StatusApplication(StatusKind.poison, 1), breakMax: 170, ultId: 'eult_nido',
      title: 'Reina del Bosque Hondo', mechanicId: 'telarana', legendaryId: 'susurroVibora', feminine: true),

  // Zona 4 · Cavernas Heladas (comunes nivel 16, jefe nivel 20).
  'murcielagoHielo': EnemyDef(id: 'murcielagoHielo', name: 'Murciélago de Hielo', hp: 80, attack: 22, speed: 14,
      xp: 10, credits: 9, inflicts: StatusApplication(StatusKind.freeze, 1), breakMax: 64),
  'elementalEscarcha': EnemyDef(id: 'elementalEscarcha', name: 'Elemental de Escarcha', hp: 170, attack: 23, speed: 5,
      xp: 16, credits: 15, inflicts: StatusApplication(StatusKind.freeze, 1), breakMax: 136, armor: 0.15),
  // v0.7: su mordida moja (Agua) y su Aliento Glacial (Hielo) congela al
  // instante a los mojados (Congelación súbita; bestiary.md § 4).
  'sierpe': EnemyDef(id: 'sierpe', name: 'Sierpe de Escarcha', hp: 1050, attack: 33, speed: 8, xp: 150, credits: 190,
      boss: true, inflicts: StatusApplication(StatusKind.wet, 1), breakMax: 370, ultId: 'eult_aliento',
      title: 'Aliento de las Cavernas Heladas', mechanicId: 'escarcha', legendaryId: 'inviernoPerpetuo',
      feminine: true),
  // Cristal de la Sierpe (invocación, nivel 20): no actúa.
  'cristalHielo': EnemyDef(id: 'cristalHielo', name: 'Cristal de Hielo', hp: 60, attack: 0, speed: 1, xp: 0, credits: 0,
      passive: true),

  // Zona 5 · Fortaleza Caída (comunes nivel 21, jefe nivel 25).
  'esqueleto': EnemyDef(id: 'esqueleto', name: 'Esqueleto', hp: 125, attack: 27, speed: 10, xp: 12, credits: 11,
      pierce: true, breakMax: 100),
  'caballeroCaido': EnemyDef(id: 'caballeroCaido', name: 'Caballero Caído', hp: 200, attack: 28, speed: 7, xp: 18, credits: 16,
      inflicts: StatusApplication(StatusKind.stun, 1, chance: 0.25), breakMax: 160, armor: 0.2),
  'caballeroHueco': EnemyDef(id: 'caballeroHueco', name: 'Caballero Hueco', hp: 1250, attack: 38, speed: 9, xp: 200, credits: 240,
      boss: true, breakMax: 440, ultId: 'eult_juicio',
      title: 'Juramento sin alma de la Fortaleza Caída', mechanicId: 'postura', legendaryId: 'egidaPrimerRey'),

  // ---- v0.3 (docs/specs/bosses.md § "v0.3"): zonas 6–10. ----

  // Zona 6 · Laberinto Temporal (comunes nivel 26, jefa nivel 30).
  'ecoSombra': EnemyDef(id: 'ecoSombra', name: 'Eco Sombrío', hp: 120, attack: 32, speed: 15, xp: 12, credits: 13,
      breakMax: 96, evasion: 0.25),
  'guardianReloj': EnemyDef(id: 'guardianReloj', name: 'Guardián del Reloj', hp: 190, attack: 30, speed: 6, xp: 16,
      credits: 18, breakMax: 152, armor: 0.15, delayHit: 0.3),
  'hechicera': EnemyDef(id: 'hechicera', name: 'Hechicera del Eco', hp: 1350, attack: 42, speed: 10, xp: 230, credits: 280,
      boss: true, inflicts: StatusApplication(StatusKind.freeze, 1), breakMax: 470, ultId: 'eult_coro',
      title: 'Voz múltiple del Laberinto Temporal', mechanicId: 'ecos', legendaryId: 'truenoBronce', feminine: true),
  // Eco de la Hechicera (invocación que actúa, nivel 30).
  'ecoHechicera': EnemyDef(id: 'ecoHechicera', name: 'Eco de la Hechicera', hp: 140, attack: 21, speed: 10, xp: 0,
      credits: 0, feminine: true),

  // Zona 7 · Grieta Ígnea (comunes nivel 31, jefa nivel 35).
  'salamandra': EnemyDef(id: 'salamandra', name: 'Salamandra', hp: 150, attack: 37, speed: 12, xp: 12, credits: 14,
      inflicts: StatusApplication(StatusKind.burn, 2), breakMax: 120, feminine: true),
  'golemMagma': EnemyDef(id: 'golemMagma', name: 'Gólem de Magma', hp: 260, attack: 36, speed: 5, xp: 17, credits: 20,
      inflicts: StatusApplication(StatusKind.burn, 1), breakMax: 208, armor: 0.25),
  'bestiaMagma': EnemyDef(id: 'bestiaMagma', name: 'Bestia de Magma', hp: 1700, attack: 48, speed: 7, xp: 260, credits: 320,
      boss: true, inflicts: StatusApplication(StatusKind.burn, 2), breakMax: 600, ultId: 'eult_erupcion',
      title: 'Furia viva de la Grieta Ígnea', mechanicId: 'lava', legendaryId: 'fauceVolcan', feminine: true),

  // Zona 8 · Cementerio de Eras (comunes nivel 36, jefe nivel 40).
  'necrofago': EnemyDef(id: 'necrofago', name: 'Necrófago', hp: 190, attack: 41, speed: 11, xp: 13, credits: 15,
      pierce: true, inflicts: StatusApplication(StatusKind.poison, 2), breakMax: 152),
  'almaErrante': EnemyDef(id: 'almaErrante', name: 'Alma Errante', hp: 165, attack: 40, speed: 13, xp: 13, credits: 15,
      inflicts: StatusApplication(StatusKind.freeze, 1), breakMax: 132, feminine: true),
  'espectroCoronado': EnemyDef(id: 'espectroCoronado', name: 'Espectro Coronado', hp: 1800, attack: 53, speed: 11,
      xp: 290, credits: 360, boss: true, inflicts: StatusApplication(StatusKind.freeze, 1), breakMax: 630,
      ultId: 'eult_lamento', title: 'Rey sin reino del Cementerio de Eras', mechanicId: 'sequito',
      legendaryId: 'primaveraRota'),
  // Siervo del Espectro (invocación que actúa, nivel 40).
  'siervoEspectral': EnemyDef(id: 'siervoEspectral', name: 'Siervo Espectral', hp: 150, attack: 30, speed: 12, xp: 0,
      credits: 0, inflicts: StatusApplication(StatusKind.freeze, 1)),

  // Zona 9 · Abismo del Tiempo (comunes nivel 41, jefe nivel 45).
  // v0.7: el Vigilante moja (Agua) y el Ojo electrocuta (Electro).
  'vigilanteVacio': EnemyDef(id: 'vigilanteVacio', name: 'Vigilante del Vacío', hp: 210, attack: 43, speed: 10, xp: 15,
      credits: 17, breakMax: 168, markHit: 0.2, inflicts: StatusApplication(StatusKind.wet, 1)),
  'ojoAbismo': EnemyDef(id: 'ojoAbismo', name: 'Ojo del Abismo', hp: 170, attack: 44, speed: 12, xp: 14, credits: 16,
      inflicts: StatusApplication(StatusKind.stun, 1, chance: 0.3), breakMax: 136),
  // v0.7: golpes de Electro que dejan Cargado; su ULT inunda (Agua).
  'centinela': EnemyDef(id: 'centinela', name: 'Centinela del Vacío', hp: 2100, attack: 59, speed: 9, xp: 320, credits: 400,
      boss: true, pierce: true, inflicts: StatusApplication(StatusKind.charged, 1), breakMax: 735, ultId: 'eult_colapsoVacio',
      title: 'Guardián del borde del Abismo', mechanicId: 'marca', legendaryId: 'rompemundos'),

  // Zona 10 · Corazón del Tiempo (comunes nivel 46; jefe: el Devorador).
  'heraldoEras': EnemyDef(id: 'heraldoEras', name: 'Heraldo de las Eras', hp: 330, attack: 50, speed: 9, xp: 20,
      credits: 24, breakMax: 264, ultId: kEliteUltId, inflictCycle: [
        StatusApplication(StatusKind.burn, 1),
        StatusApplication(StatusKind.poison, 1),
        StatusApplication(StatusKind.freeze, 1),
      ]),
  'fragmentoTiempo': EnemyDef(id: 'fragmentoTiempo', name: 'Fragmento del Tiempo', hp: 160, attack: 45, speed: 17,
      xp: 14, credits: 16, breakMax: 128, delayHit: 0.25),

  // ---- Jefes del Abismo v0.8 (docs/specs/abyss_bosses.md § 2.2): stats
  // ya al nivel 85–90 (`kEnemyBaseLevel`). Sin título (sin lore). ----
  'golemAbismo': EnemyDef(id: 'golemAbismo', name: 'Gólem Reloj del Abismo', hp: 6400, attack: 98, speed: 8,
      xp: 700, credits: 900, boss: true, inflicts: StatusApplication(StatusKind.freeze, 1), breakMax: 2240,
      ultId: 'eult_abismoReloj', mechanicId: 'abismoReloj'),
  'hechiceraAbismo': EnemyDef(id: 'hechiceraAbismo', name: 'Hechicera del Eco del Abismo', hp: 6600, attack: 100,
      speed: 10, xp: 720, credits: 920, boss: true, inflicts: StatusApplication(StatusKind.freeze, 1),
      breakMax: 2310, ultId: 'eult_abismoEco', mechanicId: 'abismoEco', feminine: true),
  'espectroAbismo': EnemyDef(id: 'espectroAbismo', name: 'Espectro Coronado del Abismo', hp: 7200, attack: 104,
      speed: 11, xp: 760, credits: 960, boss: true, inflicts: StatusApplication(StatusKind.freeze, 1),
      breakMax: 2520, ultId: 'eult_abismoCorona', mechanicId: 'abismoCorona'),
  'devoradorAbismo': EnemyDef(id: 'devoradorAbismo', name: 'Devorador de Eras del Abismo', hp: 8400, attack: 110,
      speed: 10, xp: 800, credits: 1000, boss: true, inflicts: StatusApplication(StatusKind.burn, 2),
      breakMax: 2940, ultId: 'eult_abismoEras', mechanicId: 'abismoEras'),
  'ecoPrimordial': EnemyDef(id: 'ecoPrimordial', name: 'Eco Primordial', hp: 10000, attack: 112, speed: 11,
      xp: 1000, credits: 1300, boss: true, breakMax: 3500, ultId: 'eult_primordial', mechanicId: 'abismoPrimordial'),
  // Eco del Abismo (invocación que actúa, nivel 86): copia la última
  // habilidad del grupo y recibe ×0.5.
  'ecoAbismo': EnemyDef(id: 'ecoAbismo', name: 'Eco del Abismo', hp: 600, attack: 60, speed: 10, xp: 0,
      credits: 0),
};

/// Mecánicas propias de los jefes (docs/specs/bosses.md § "v0.2").
const Map<String, BossMechanicDef> kBossMechanics = {
  'telarana': BossMechanicDef(
    id: 'telarana',
    kind: BossMechanicKind.web,
    name: 'Telaraña',
    every: 3,
    value: 0.6,
    soloValue: 0.5,
    counter: 'Cada 3 acciones atrapa a un jugador: pierde su próximo turno. '
        '<b>Un aliado lo libera</b> usando <b>Atacar</b> sobre él (el menú '
        'muestra "Liberar"; cuesta medio turno). <span class="k">Solo: '
        'forcejea y pierde medio turno.</span>',
  ),
  'escarcha': BossMechanicDef(
    id: 'escarcha',
    kind: BossMechanicKind.frost,
    name: 'Campo Helado',
    value: 0.10,
    cap: 0.50,
    addType: 'cristalHielo',
    adds: 2,
    soloAdds: 1,
    counter: 'Mientras vivan sus <b>Cristales de Hielo</b>, cada turno de la '
        'Sierpe el grupo pierde 10% de velocidad (máx −50%). <b>Rompé los '
        'cristales</b> (o quebrá a la Sierpe: el quiebre rompe uno) para '
        'descongelar el campo. Aliento Glacial los vuelve a formar. '
        '<span class="k">Solo: 1 cristal.</span>',
  ),
  'postura': BossMechanicDef(
    id: 'postura',
    kind: BossMechanicKind.stance,
    name: 'Postura',
    every: 2,
    value: 0.70,
    soloValue: 0.50,
    counter: '<b>Escudo</b>: −70% al daño físico (ataques y habilidades '
        'físicas). <b>Espada</b>: −70% al daño mágico. Cambia cada 2 turnos '
        'suyos (avisa 1 turno antes). Pegale con lo que no bloquea; '
        '<b>quebrado</b> pierde la postura. <span class="k">Solo: −50%.</span>',
  ),

  // ---- v0.3 (docs/specs/bosses.md § "v0.3") ----
  'ecos': BossMechanicDef(
    id: 'ecos',
    kind: BossMechanicKind.echo,
    name: 'Ecos',
    every: 3,
    value: 0.5,
    addType: 'ecoHechicera',
    adds: 2,
    soloAdds: 1,
    counter: 'Los <b>Ecos de la Hechicera</b> atacan y reciben solo el 50% del '
        'daño: tienen poca vida y caen en pocos golpes. La <b>real</b> recibe '
        'daño completo: <b>concentrá los golpes en ella</b>. Quebrarla disipa '
        'un eco; si pasa 3 turnos con ecos caídos los vuelve a crear, y Coro '
        'de Ecos pega más por cada eco vivo. <span class="k">Solo: 1 eco.</span>',
  ),
  'lava': BossMechanicDef(
    id: 'lava',
    kind: BossMechanicKind.lava,
    name: 'Charcos de Lava',
    every: 3,
    turns: 2,
    value: 2,
    soloValue: 1,
    power: 0.4,
    soloPower: 0.25,
    counter: 'Cada 3 acciones la Bestia hace subir la lava 2 turnos suyos. Con '
        'lava, <b>el que se esté Defendiendo</b> al empezar su turno se quema '
        '(ATQ × 0.4, Defender no lo reduce) y recibe +2 Quemadura. <b>No te '
        'defiendas con lava</b>: atacá o curate. <span class="k">Solo: ATQ × '
        '0.25 y +1 Quemadura.</span>',
  ),
  'sequito': BossMechanicDef(
    id: 'sequito',
    kind: BossMechanicKind.summon,
    name: 'Séquito',
    every: 3,
    addType: 'siervoEspectral',
    adds: 2,
    soloAdds: 1,
    counter: 'Mientras viva algún <b>Siervo Espectral</b>, el Espectro es '
        '<b>inmune a los estados</b> (no entran Quemadura, Veneno, '
        'Congelación ni Aturdido). <b>Matá a los siervos primero</b>; si pasa '
        '3 turnos con el séquito incompleto vuelve a invocarlos, y Lamento '
        'Eterno lo completa. <span class="k">Solo: 1 siervo.</span>',
  ),
  'marca': BossMechanicDef(
    id: 'marca',
    kind: BossMechanicKind.mark,
    name: 'Marca del Vacío',
    every: 3,
    value: 2,
    soloValue: 2,
    counter: 'Cada 3 acciones el Centinela <b>marca</b> a un jugador: su '
        'próximo golpe va contra él y pega <b>×2</b>. Que <b>otro aliado lo '
        'Proteja</b> (Protección o Baluarte) para recibirlo normal. '
        '<span class="k">Solo: Defender también la contrarresta.</span>',
  ),
  'fases': BossMechanicDef(
    id: 'fases',
    kind: BossMechanicKind.phases,
    name: 'Fin del Tiempo',
    every: 2,
    value: 0.5,
    power: 1.15,
    counter: 'Jefe final en <b>2 fases</b>. Al 50% de la vida se transforma: '
        'pierde sus estados y la barra de quiebre, pega +15% y lanza '
        '<b>Colapso Temporal cada 2 acciones</b> (a todos, retrasa). Guardá '
        'curas y defensas para la fase 2; Fin de las Eras borra los buffs.',
  ),

  // ---- Jefes del Abismo v0.8 (docs/specs/abyss_bosses.md § 2): las
  // fases y movimientos viven en `kAbyssBosses`. ----
  'abismoReloj': BossMechanicDef(
    id: 'abismoReloj',
    kind: BossMechanicKind.abyss,
    name: 'Reloj del Abismo',
    counter: '<b>3 fases</b>. <b>Rebobinar</b>: se cura lo que recibió desde su '
        'acción anterior; <b>quebralo antes</b> (avisa). <b>Distorsión</b>: '
        'retrasa al grupo. Fase 2: <b>Diluvio</b> moja y <b>Descarga</b> '
        'electrocuta a los Mojados: <b>Defendé</b> para que no reaccione. '
        '<span class="k">Solo: rebobina 50% y retrasa menos.</span>',
  ),
  'abismoEco': BossMechanicDef(
    id: 'abismoEco',
    kind: BossMechanicKind.abyss,
    name: 'Ecos del Abismo',
    value: 0.5,
    addType: 'ecoAbismo',
    adds: 2,
    soloAdds: 1,
    counter: 'Sus <b>Ecos</b> copian <b>la última habilidad</b> del grupo '
        '(su elemento incluido) y reciben 50%. <b>Sello</b>: recibe 25% '
        'hasta que lo rompa la <b>reacción</b> que pide (o un quiebre). '
        '<span class="k">Solo: 1 eco y cualquier reacción rompe el sello.</span>',
  ),
  'abismoCorona': BossMechanicDef(
    id: 'abismoCorona',
    kind: BossMechanicKind.abyss,
    name: 'Corona del Abismo',
    addType: 'siervoEspectral',
    adds: 2,
    soloAdds: 1,
    counter: '<b>Las curas del grupo lo dañan</b> (60%, también las pociones). '
        'Con siervos vivos es inmune a estados y, en la <b>fase 2</b>, '
        '<b>inmune al daño</b>: matá a los siervos o curá. '
        '<span class="k">Solo: 1 siervo.</span>',
  ),
  'abismoEras': BossMechanicDef(
    id: 'abismoEras',
    kind: BossMechanicKind.abyss,
    name: 'Hambre del Abismo',
    counter: '<b>3 fases</b>. <b>Devorar</b>: se come los buffs y escudos del '
        'grupo y gana +5% ATQ por cada uno: <b>no los acumules antes del '
        'aviso</b>. Fase 3: cambia de <b>aspecto</b> cada turno (Fuego, Agua, '
        'Electro, Hielo) y resiste su propio elemento.',
  ),
  'abismoPrimordial': BossMechanicDef(
    id: 'abismoPrimordial',
    kind: BossMechanicKind.abyss,
    name: 'Primordial',
    value: 0.5,
    addType: 'ecoAbismo',
    adds: 2,
    soloAdds: 1,
    counter: 'Todos los elementos: <b>aspecto</b> en ciclo, <b>sellos</b>, '
        '<b>ecos</b> que copian, <b>devorar</b>, <b>rebobinar</b> y '
        '<b>distorsión</b>. Las curas lo dañan (40%). Fase 3: <b>inmune al '
        'daño</b> con ecos vivos. <span class="k">Solo: 1 eco, cualquier '
        'reacción rompe el sello.</span>',
  ),
};

BossMechanicDef? bossMechanicOf(EnemyDef? d) =>
    d?.mechanicId == null ? null : kBossMechanics[d!.mechanicId];

/// ULT de los élites (cualquier tipo).
const kEliteUltId = 'eult_furia';

/// ULT enemigas por id (docs/specs/break_and_enemy_ults.md § 2).
const Map<String, EnemyUltDef> kEnemyUlts = {
  'eult_diluvio': EnemyUltDef(
    id: 'eult_diluvio',
    name: 'Diluvio Ácido',
    power: 1.2,
    allTargets: true,
    status: StatusApplication(StatusKind.poison, 2),
  ),
  'eult_engranaje': EnemyUltDef(
    id: 'eult_engranaje',
    name: 'Engranaje del Fin',
    power: 1.5,
    status: StatusApplication(StatusKind.freeze, 3),
    delayAll: 0.5,
  ),
  'eult_finEras': EnemyUltDef(
    id: 'eult_finEras',
    name: 'Fin de las Eras',
    power: 1.4,
    allTargets: true,
    status: StatusApplication(StatusKind.burn, 2),
    wipeBuffs: true,
  ),
  'eult_nido': EnemyUltDef(
    id: 'eult_nido',
    name: 'Nido Venenoso',
    power: 1.1,
    allTargets: true,
    status: StatusApplication(StatusKind.poison, 3),
    extra: EnemyUltExtra.web,
  ),
  'eult_aliento': EnemyUltDef(
    id: 'eult_aliento',
    name: 'Aliento Glacial',
    power: 1.2,
    allTargets: true,
    status: StatusApplication(StatusKind.freeze, 2),
    extra: EnemyUltExtra.reformCrystals,
  ),
  'eult_juicio': EnemyUltDef(
    id: 'eult_juicio',
    name: 'Juicio Hueco',
    power: 1.9,
    status: StatusApplication(StatusKind.stun, 1),
    extra: EnemyUltExtra.stanceShift,
  ),
  // ---- v0.3 ----
  'eult_coro': EnemyUltDef(
    id: 'eult_coro',
    name: 'Coro de Ecos',
    power: 1.0,
    allTargets: true,
    delayAll: 0.3,
    perAdd: 0.3,
    extra: EnemyUltExtra.echoChorus,
  ),
  'eult_erupcion': EnemyUltDef(
    id: 'eult_erupcion',
    name: 'Erupción Total',
    power: 1.3,
    allTargets: true,
    status: StatusApplication(StatusKind.burn, 2),
    turns: 3,
    extra: EnemyUltExtra.lavaFlood,
  ),
  'eult_lamento': EnemyUltDef(
    id: 'eult_lamento',
    name: 'Lamento Eterno',
    power: 1.25,
    allTargets: true,
    status: StatusApplication(StatusKind.freeze, 2),
    extra: EnemyUltExtra.summonAll,
  ),
  'eult_colapsoVacio': EnemyUltDef(
    id: 'eult_colapsoVacio',
    name: 'Colapso del Vacío',
    power: 1.3,
    allTargets: true,
    // v0.7: inunda al grupo (Agua): Cortocircuito sobre los Cargados y
    // Mojado para que sus golpes de Electro electrocuten.
    status: StatusApplication(StatusKind.wet, 1),
    extra: EnemyUltExtra.voidMark,
  ),
  // ---- Jefes del Abismo v0.8 ----
  'eult_abismoReloj': EnemyUltDef(
    id: 'eult_abismoReloj',
    name: 'Engranaje del Fin',
    power: 1.5,
    allTargets: true,
    status: StatusApplication(StatusKind.freeze, 2),
    delayAll: 0.5,
  ),
  'eult_abismoEco': EnemyUltDef(
    id: 'eult_abismoEco',
    name: 'Coro de Ecos',
    power: 1.1,
    allTargets: true,
    delayAll: 0.3,
    perAdd: 0.3,
    extra: EnemyUltExtra.echoChorus,
  ),
  'eult_abismoCorona': EnemyUltDef(
    id: 'eult_abismoCorona',
    name: 'Lamento Eterno',
    power: 1.3,
    allTargets: true,
    status: StatusApplication(StatusKind.freeze, 2),
    extra: EnemyUltExtra.summonAll,
  ),
  'eult_abismoEras': EnemyUltDef(
    id: 'eult_abismoEras',
    name: 'Fin de las Eras',
    power: 1.5,
    allTargets: true,
    status: StatusApplication(StatusKind.burn, 2),
    wipeBuffs: true,
  ),
  'eult_primordial': EnemyUltDef(
    id: 'eult_primordial',
    name: 'Todas las Eras',
    power: 1.6,
    allTargets: true,
    status: StatusApplication(StatusKind.wet, 1),
    wipeBuffs: true,
  ),
  kEliteUltId: EnemyUltDef(
    id: kEliteUltId,
    name: 'Furia Élite',
    power: 2.0,
    guaranteedCrit: true,
  ),
};
