import '../models/localized_text.dart';
import '../models/world_event.dart';

export '../models/world_event.dart';

LocalizedText _t(String es, String en, String zh) =>
    LocalizedText.of({'es-AR': es, 'en': en, 'zh-Hans': zh});

/// Code defaults of the world events (docs/specs/world_events.md § 4):
/// only the fallback when `assets/data/events/world_events.json` is
/// missing or broken. Every text is a BORRADOR (draft) for the owner.
const _visitor = WorldEventCategory.visitor;

// Event NPC dialogue (§ 3.6): every line is a BORRADOR draft.
final _trade = EventNpcAction(EventActionKind.trade,
    label: _t('Comerciar', 'Trade', '交易'),
    line: _t('Mirá lo que traje.', 'Have a look at what I brought.',
        '看看我带来了什么。'));

EventNpcAction _rumor(String target, LocalizedText line) =>
    EventNpcAction(EventActionKind.rumor,
        label: _t('¿Algún rumor?', 'Any rumors?', '有什么传闻吗？'),
        line: line,
        target: target);

final WorldEventsConfig kWorldEventsDefaults = WorldEventsConfig(
  interval: 5,
  minPerRoll: 1,
  maxPerRoll: 2,
  chance: 1,
  events: [
    WorldEventDef(
      id: 'visitor_clockmaker',
      category: _visitor,
      sprite: 'npc_ev_visitante',
      greeting: _t('¿Se te atrasó el reloj? A todos se nos atrasa algo.',
          'Is your clock running late? Something always is.',
          '你的钟慢了吗？总有什么会慢下来。'),
      topics: [
        EventTopic(
            id: 'trade',
            label: _t('¿Qué arreglás?', 'What do you mend?', '你修什么？'),
            line: _t(
                'Relojes, cerraduras, engranajes. Lo que el tiempo gasta.',
                'Clocks, locks, gears. Whatever time wears down.',
                '钟表、锁、齿轮。凡是被时间磨损的。')),
      ],
      actions: [
        _trade,
        _rumor(
            EventNpcAction.rift,
            _t('Mis relojes tiemblan cerca de una grieta de eco. Te la marco en el mapa.',
                'My clocks shiver near an echo rift. I marked it on your map.',
                '我的钟在回声裂隙附近会颤动。我在你的地图上标出来了。')),
      ],
      weight: 3,
      duration: 3,
      params: const {'discount': 0.1},
      title: _t('Relojera ambulante', 'Wandering clockmaker', '流浪钟表匠'),
      notice: _t(
          'Llegó una relojera ambulante al pueblo: arregla lo que el tiempo rompió.',
          'A wandering clockmaker reached town: she mends what time broke.',
          '一位流浪钟表匠来到镇上：她修补时间弄坏的东西。'),
      body: _t(
          'Mientras esté, el puesto del pueblo cobra menos.',
          'While she stays, the town stall charges less.',
          '她在镇上期间，镇上摊位的价格更低。'),
    ),
    WorldEventDef(
      id: 'visitor_chronicler',
      category: _visitor,
      sprite: 'npc_ev_cronista',
      greeting: _t('Ah, sos vos. Ya te había anotado.',
          'Ah, it is you. I already wrote you down.',
          '啊，是你。我早就把你记下了。'),
      topics: [
        EventTopic(
            id: 'book',
            label: _t('¿Qué libro?', 'Which book?', '哪本书？'),
            line: _t('Uno que todavía no se escribió. Las últimas páginas no se pueden cambiar.',
                'One not yet written. Its last pages cannot be changed.',
                '一本尚未写成的书。最后几页无法改变。')),
      ],
      actions: [
        _rumor(
            'cavernas',
            _t('En mis páginas, las Cavernas guardan una veta que nadie encontró todavía. Te la marco.',
                'In my pages, the Caverns hold a vein no one has found yet. I marked it.',
                '在我的书页里，洞窟藏着一条还没人发现的矿脉。我替你标出来了。')),
      ],
      weight: 2,
      duration: 2,
      minDay: 5,
      title: _t('Cronista de paso', 'Passing chronicler', '过路的编年史家'),
      notice: _t('Un cronista de paso anota lo que todavía no pasó.',
          'A passing chronicler writes down what has not happened yet.',
          '一位过路的编年史家记下了尚未发生的事。'),
      body: _t(
          'Dice que leyó estas páginas en un libro que todavía no se escribió.',
          'He claims he read these pages in a book not yet written.',
          '他说自己在一本尚未写成的书里读过这些内容。'),
    ),
    WorldEventDef(
      id: 'wanderer_forest',
      category: WorldEventCategory.overworldNpc,
      sprite: 'npc_ev_peregrina',
      greeting: _t('¿Lo oís? No... claro que no.',
          'Do you hear it? No... of course not.', '你听见了吗？不……当然听不见。'),
      topics: [
        EventTopic(
            id: 'echo',
            label: _t('¿Qué eco seguís?', 'What echo do you follow?',
                '你在追随什么回声？'),
            line: _t('Una voz que todavía no habló. Me dice por dónde ir.',
                'A voice that has not spoken yet. It tells me where to go.',
                '一个还没开口的声音。它告诉我该往哪走。')),
      ],
      actions: [
        EventNpcAction(EventActionKind.gift,
            label: _t('¿Tenés algo para mí?', 'Do you have something for me?',
                '你有东西给我吗？'),
            line: _t('Tomá: brillan cuando el agua recuerda. Los peces no se resisten.',
                'Here: they glow when the water remembers. Fish cannot resist.',
                '拿着：水记起往事时它们会发光。鱼抵挡不住。'),
            item: 'larva_brillante',
            params: const {'qty': 3}),
        _rumor(
            EventNpcAction.rift,
            _t('El eco viene de una grieta. Te marco dónde está.',
                'The echo comes from a rift. I marked where it is.',
                '回声来自一道裂隙。我标出了它的位置。')),
      ],
      weight: 3,
      duration: 3,
      biomes: const ['bosque'],
      title: _t('Peregrina del eco', 'Echo pilgrim', '回声朝圣者'),
      notice: _t(
          'Una peregrina camina por el bosque siguiendo un eco que nadie más oye.',
          'A pilgrim walks the forest following an echo no one else hears.',
          '一位朝圣者在森林中行走，追随着只有她听得见的回声。'),
      body: _t('Se la ve cerca del lago del bosque unos días.',
          'She can be seen near the forest lake for a few days.',
          '几天内可以在森林湖边见到她。'),
    ),
    WorldEventDef(
      id: 'wanderer_automaton',
      category: WorldEventCategory.overworldNpc,
      sprite: 'npc_ev_automata',
      greeting: _t('Clic. ¿Sos. Quien. Me. Dio. Cuerda?',
          'Click. Are. You. The. One. Who. Wound. Me?', '咔哒。是。你。给。我。上。的。发条。吗？'),
      topics: [
        EventTopic(
            id: 'mine',
            label: _t('¿De dónde venís?', 'Where do you come from?', '你从哪里来？'),
            line: _t('De abajo. La mina de las ruinas. Ahí quedó la fragua que me armó.',
                'From below. The ruins mine. The forge that built me is still there.',
                '从下面。遗迹的矿坑。造我的熔炉还在那里。')),
      ],
      actions: [
        EventNpcAction(EventActionKind.gift,
            label: _t('Te ayudo a buscarlo', 'I will help you look', '我帮你找'),
            line: _t('Gracias. Tomá. Me sobra. Un engranaje.',
                'Thanks. Take. A spare. Cog.', '谢谢。拿着。多余的。齿轮。'),
            item: 'rare_cog',
            params: const {'qty': 1}),
        EventNpcAction(EventActionKind.duel,
            label: _t('Probemos fuerzas', 'Let us test our strength', '比试一下'),
            line: _t('Protocolo. De. Prueba. Iniciado.',
                'Test. Protocol. Engaged.', '测试。协议。启动。'),
            target: 'guardianReloj',
            params: const {
              'hpMult': 1.4,
              'atkMult': 1.2,
              'levelBonus': 2,
              'rewardMult': 1.5
            }),
      ],
      weight: 2,
      duration: 3,
      minDay: 10,
      biomes: const ['ruinas'],
      title: _t('Autómata errante', 'Wandering automaton', '游荡的自动人偶'),
      notice: _t(
          'Un autómata viejo anda por las ruinas buscando a quien le dio cuerda.',
          'An old automaton roams the ruins looking for whoever wound it.',
          '一具古老的自动人偶在废墟中游荡，寻找为它上发条的人。'),
      body: _t('Sus engranajes todavía recuerdan el pasado magitec.',
          'Its gears still remember the magitech past.',
          '它的齿轮仍记得魔导科技的过去。'),
    ),
    WorldEventDef(
      id: 'echo_rift',
      category: WorldEventCategory.echoPortal,
      weight: 3,
      duration: 3,
      minDay: 5,
      params: const {
        'hpMult': 1.6,
        'atkMult': 1.3,
        'levelBonus': 3,
        'rewardMult': 1.75,
      },
      title: _t('Grieta de eco', 'Echo rift', '回声裂隙'),
      notice: _t(
          'Se abrió una grieta de eco: del otro lado espera un jefe que ya ganó una vez.',
          'An echo rift opened: on the other side waits a boss that already won once.',
          '一道回声裂隙打开了：另一侧等待着一个曾经赢过的首领。'),
      body: _t(
          'El jefe del bioma, más fuerte. Mejor recompensa mientras dure.',
          'The biome boss, stronger. Better reward while it lasts.',
          '更强的本区域首领。持续期间奖励更丰厚。'),
    ),
    WorldEventDef(
      id: 'lore_ilda_roots',
      category: WorldEventCategory.lore,
      weight: 2,
      duration: 6,
      resident: 'ilda',
      objective: LoreObjective.defeat,
      target: 'arana',
      n: 3,
      params: const {'gold': 120, 'rep': 2},
      title: _t('Las moras que recuerdan', 'The berries that remember',
          '记得一切的莓果'),
      notice: _t(
          'Las moras de Ilda recuerdan un invierno que todavía no llegó.',
          "Ilda's berries remember a winter that has not come yet.",
          '伊尔达的莓果记得一个尚未到来的冬天。'),
      body: _t(
          'Algo vino del futuro a buscarlas: arañas que tejen con hilo de mañana. Vencé a tres.',
          "Something came from the future for them: spiders weaving with tomorrow's thread. Defeat three.",
          '有东西从未来来寻找它们：用明日之丝织网的蜘蛛。击败三只。'),
    ),
    WorldEventDef(
      id: 'lore_velda_order',
      category: WorldEventCategory.lore,
      weight: 2,
      duration: 6,
      resident: 'velda',
      objective: LoreObjective.defeat,
      target: 'guardianReloj',
      params: const {'gold': 150, 'rep': 2},
      title: _t('El orden de los autómatas', 'The order of the automatons',
          '自动人偶的顺序'),
      notice: _t('Velda encontró el orden que esperan los autómatas.',
          'Velda found the order the automatons are waiting for.',
          '维尔达找到了自动人偶等待的顺序。'),
      body: _t(
          'Un Guardián de Reloj no respeta el orden: vencelo y Velda podrá leer su mecanismo.',
          'A Clock Guardian breaks the order: defeat it so Velda can read its mechanism.',
          '一具时钟守卫打乱了顺序：击败它，让维尔达读出它的机关。'),
    ),
    WorldEventDef(
      id: 'lore_kael_guardian',
      category: WorldEventCategory.lore,
      weight: 2,
      duration: 6,
      resident: 'kael',
      objective: LoreObjective.defeat,
      target: 'elementalEscarcha',
      n: 2,
      params: const {'gold': 180, 'rep': 2},
      title: _t('El guardián adelantado', 'The guardian ahead of time',
          '超前的守护者'),
      notice: _t(
          'El guardián que pelea antes de que llegues dejó un mensaje: aguantá.',
          'The guardian who fights before you arrive left a message: hold on.',
          '那位在你到来前就开战的守护者留下了讯息：撑住。'),
      body: _t('Dos elementales de escarcha llegaron antes que vos. Aguantá y vencelos.',
          'Two frost elementals arrived before you did. Hold on and defeat them.',
          '两个霜之元素比你先到。坚持住，击败它们。'),
    ),
    WorldEventDef(
      id: 'lore_brann_forge',
      category: WorldEventCategory.lore,
      weight: 2,
      duration: 6,
      resident: 'brann',
      objective: LoreObjective.explore,
      target: 'grieta',
      params: const {'gold': 200, 'rep': 2},
      title: _t('La fragua que sigue andando', 'The forge that keeps running',
          '仍在运转的熔炉'),
      notice: _t(
          'Un autómata salió de la Grieta caminando hacia la fragua de Brann.',
          "An automaton left the Rift, walking toward Brann's forge.",
          '一具自动人偶走出裂谷，朝布兰的熔炉走去。'),
      body: _t('Andá a la Grieta a ver de dónde salió: la fragua vieja sigue encendida.',
          'Go to the Rift to see where it came from: the old forge is still lit.',
          '去裂谷看看它从哪里来：古老的熔炉仍在燃烧。'),
    ),
    WorldEventDef(
      id: 'lore_oren_future',
      category: WorldEventCategory.lore,
      weight: 1,
      duration: 6,
      minDay: 15,
      resident: 'oren',
      objective: LoreObjective.explore,
      target: 'abismo',
      params: const {'gold': 250, 'rep': 3},
      title: _t('Lo que tiene que pasar', 'What has to happen', '必须发生的事'),
      notice: _t('Oren vio el final. No se puede cambiar.',
          'Oren saw the ending. It cannot be changed.',
          '奥伦看见了结局。它无法改变。'),
      body: _t(
          'Hay que llegar hasta ahí: andá al Abismo, donde llegan los ecos del futuro.',
          'Someone has to get there: go to the Abyss, where the echoes of the future arrive.',
          '总得有人到达那里：前往深渊，未来的回声在那里抵达。'),
    ),
    WorldEventDef(
      id: 'caravan_relics',
      category: WorldEventCategory.caravan,
      sprite: 'npc_ev_caravana',
      greeting: _t('¡Restos del pasado, recién desenterrados!',
          'Relics of the past, freshly dug up!', '刚出土的往昔遗物！'),
      topics: [
        EventTopic(
            id: 'relics',
            label: _t('¿De dónde sacan esto?', 'Where do you find these?',
                '这些是从哪找到的？'),
            line: _t('De la época magitec. Cada pieza todavía recuerda para qué servía.',
                'From the magitec age. Every piece still remembers its purpose.',
                '来自魔导时代。每一件都还记得自己的用途。')),
      ],
      actions: [
        _trade,
        _rumor(
            'ruinas',
            _t('En la mina de las Ruinas hay una reliquia magitec enterrada. Te la marco.',
                'There is a magitec relic buried in the Ruins mine. I marked it.',
                '遗迹的矿坑里埋着一件魔导遗物。我替你标出来了。')),
      ],

      weight: 2,
      duration: 3,
      minDay: 10,
      params: const {'discount': 0.15},
      title: _t('Caravana de restos', 'Relic caravan', '遗物商队'),
      notice: _t('Llegó una caravana con restos del pasado magitec.',
          'A caravan arrived with relics of the magitech past.',
          '一支商队带着魔导科技过去的遗物抵达。'),
      body: _t('Mercaderes de paso: precios más bajos unos días.',
          'Passing merchants: lower prices for a few days.',
          '过路商人：几天内价格更低。'),
    ),
  ],
);

/// The catalog the game reads (code defaults, or the data file once
/// `WorldEventsLoader` installs it).
WorldEventsConfig kWorldEvents = kWorldEventsDefaults;
