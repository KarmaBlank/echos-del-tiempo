/// Conversaciones de los habitantes (overworld_biomes.md § 12): saludos,
/// temas de HABLAR que se abren con el tiempo y, para los arraigados, lo
/// que dicen al invitarlos. Datos puros; el lore sale solo de docs/lore.md.
library;

import 'biomes_catalog.dart';

/// Dónde se puede tocar un tema.
enum TalkWhere { any, biome, town }

/// Un tema de HABLAR: 1 o 2 frases cortas y, a veces, sub-temas.
/// Se abre con [talks] charlas, [orders] pedidos / encargos cumplidos y
/// [rep] de relación o amistad.
class TalkTopic {
  const TalkTopic(this.id, this.label, this.lines,
      {this.talks = 0,
      this.orders = 0,
      this.rep = 0,
      this.where = TalkWhere.any,
      this.sub = const []});

  final String id;
  final String label;
  final List<String> lines;
  final int talks;
  final int orders;
  final int rep;
  final TalkWhere where;
  final List<TalkTopic> sub;
}

/// La charla de un habitante. [rooted]: no se muda al pueblo nunca; a
/// cambio, al invitarlo responde con [decline] y da su regalo único.
class NpcTalkDef {
  const NpcTalkDef(
      {required this.greet,
      required this.topics,
      this.rooted = false,
      this.decline = const [],
      this.gift = ''});

  /// Saludos (uno al azar al abrir).
  final List<String> greet;
  final List<TalkTopic> topics;
  final bool rooted;
  final List<String> decline;

  /// Nombre del regalo único del arraigado.
  final String gift;
}

/// Id del arraigado de [biome] (el pescador nativo).
String nativeId(String biome) => 'pesc_$biome';

const _vivis = 'vivis';

/// Por habitante: los cinco que se mudan (por id) y los cinco arraigados
/// (`pesc_<bioma>`).
const kNpcTalks = <String, NpcTalkDef>{
  // ---------------- se mudan ----------------
  'ilda': NpcTalkDef(greet: [
    'Llegaste justo. Estaba separando hojas.',
    '¿Venís a charlar o a buscar remedios?',
    'El bosque está tranquilo hoy.',
  ], topics: [
    TalkTopic('oficio', '¿Qué hacés?', [
      'Curo con lo que da el bosque. Hojas, raíces, rocío.',
    ]),
    TalkTopic(
        _vivis,
        '¿Vivís acá?',
        [
          'Por ahora. Si tu pueblo necesita quien cure, me mudo.',
        ],
        talks: 1,
        where: TalkWhere.biome),
    TalkTopic(
        'pueblo',
        '¿Cómo te trata el pueblo?',
        [
          'Bien. Extraño el bosque, pero acá alguien siempre se lastima.',
        ],
        where: TalkWhere.town),
    TalkTopic(
        'ecos',
        'Los ecos',
        [
          'Bajan por el río, como hojas. Algunos vienen de mañana.',
        ],
        talks: 2,
        sub: [
          TalkTopic('miedo', '¿Te dan miedo?', [
            'No. Lo que tiene que pasar, pasa. Yo curo lo que quede.',
          ]),
        ]),
    TalkTopic(
        'sombra',
        'Algo raro en el bosque',
        [
          'Hay rincones donde la luz no entra. No es el follaje.',
        ],
        talks: 4,
        rep: 3),
  ]),
  'velda': NpcTalkDef(greet: [
    'Cuidado dónde pisás: esa placa es un mapa.',
    'Ah, sos vos. Anoto y te escucho.',
    'Las ruinas hablan si sabés leer.',
  ], topics: [
    TalkTopic('oficio', '¿Qué anotás?', [
      'Todo lo que dejó el pasado. Era más avanzado que nosotros.',
    ]),
    TalkTopic(
        _vivis,
        '¿Vivís acá?',
        [
          'Vivo donde están los papeles. Si me das un techo, los llevo.',
        ],
        talks: 1,
        where: TalkWhere.biome),
    TalkTopic(
        'pueblo',
        '¿Y el pueblo?',
        [
          'Tranquilo. Ya armé un archivo en mi casa.',
        ],
        where: TalkWhere.town),
    TalkTopic(
        'automatas',
        'Los autómatas',
        [
          'Se movían con magia, no con vapor. Esperan una orden.',
        ],
        talks: 2,
        sub: [
          TalkTopic('orden', '¿Qué orden?', [
            'Nadie la recuerda. Por eso sigo leyendo.',
          ]),
        ]),
    TalkTopic(
        'caida',
        '¿Qué pasó con el pasado?',
        [
          'Algo hizo que todo volviera a ser medieval. No sé qué. Todavía.',
        ],
        talks: 4,
        rep: 3),
  ]),
  'kael': NpcTalkDef(greet: [
    'Hombros abajo. Respirá.',
    'Otra vez por acá. Bien.',
    'El frío enseña paciencia.',
  ], topics: [
    TalkTopic('oficio', '¿Qué enseñás?', [
      'A moverse sin miedo. Lo demás viene solo.',
    ]),
    TalkTopic(
        _vivis,
        '¿Vivís acá?',
        [
          'Acá entreno. Si tu pueblo tiene lugar, entreno allá.',
        ],
        talks: 1,
        where: TalkWhere.biome),
    TalkTopic(
        'pueblo',
        '¿Te gusta el pueblo?',
        [
          'Hay sol. Me cuesta acostumbrarme.',
        ],
        where: TalkWhere.town),
    TalkTopic(
        'eco',
        'El eco de las cavernas',
        [
          'A veces oigo mis pasos antes de darlos. Vienen del futuro.',
        ],
        talks: 2),
  ]),
  'brann': NpcTalkDef(greet: [
    'Cuidado, que quema.',
    '¿Traés metal? No, ya sé, traés preguntas.',
    'El fuego de abajo no se apaga nunca.',
  ], topics: [
    TalkTopic('oficio', '¿Qué forjás?', [
      'Lo que deja el pasado, rehecho. Nada se pierde del todo.',
    ]),
    TalkTopic(
        _vivis,
        '¿Vivís acá?',
        [
          'Vivo al lado del fuego. Si en tu pueblo hay fuego, voy.',
        ],
        talks: 1,
        where: TalkWhere.biome),
    TalkTopic(
        'pueblo',
        '¿Cómo va la forja?',
        [
          'Más fría que la grieta. Igual sale buen acero.',
        ],
        where: TalkWhere.town),
    TalkTopic(
        'mecanismo',
        'El calor de la grieta',
        [
          'Viene de un mecanismo viejo, más abajo. Sigue andando solo.',
        ],
        talks: 2,
        sub: [
          TalkTopic('quien', '¿Quién lo hizo?', [
            'Los de antes. Sabían mezclar magia y engranaje.',
          ]),
        ]),
  ]),
  'oren': NpcTalkDef(greet: [
    'Ya sabía que venías.',
    'Sentate. O no. Ya te vi hacer las dos cosas.',
    'Llegás a tiempo. Siempre.',
  ], topics: [
    TalkTopic('oficio', '¿Qué ves?', [
      'Lo que va a pasar. No lo puedo cambiar; solo mirar.',
    ]),
    TalkTopic(
        _vivis,
        '¿Vivís acá?',
        [
          'Vivo donde el futuro se oye mejor. Tu pueblo también sirve.',
        ],
        talks: 1,
        where: TalkWhere.biome),
    TalkTopic(
        'pueblo',
        '¿Qué ves desde el pueblo?',
        [
          'Gente que vuelve sana. Eso ya pasó, aunque no pasó.',
        ],
        where: TalkWhere.town),
    TalkTopic(
        'futuro',
        'El futuro',
        [
          'Hay algo muy malo allá. Y aun así, tiene que llegar.',
        ],
        talks: 2,
        sub: [
          TalkTopic('bueno', '¿Termina bien?', [
            'Creo que sí. Pero porque pasa todo lo que tiene que pasar.',
          ]),
        ]),
  ]),

  // ---------------- arraigados ----------------
  'pesc_bosque': NpcTalkDef(rooted: true, gift: 'Anzuelo de raíz', greet: [
    'Shh, que pican.',
    'Sentate en la orilla, hay lugar.',
    'Hoy el agua está clara.',
  ], decline: [
    'Gracias, de verdad. Pero acá me siento bien, no me voy a mover.',
    'Llevate esto. Lo hice con una raíz más vieja que el lago.',
  ], topics: [
    TalkTopic('oficio', '¿Qué pescás?', [
      'Lo que el lago quiera dar. Hay peces de antes de los árboles.',
    ]),
    TalkTopic(
        _vivis,
        '¿Vivís acá?',
        [
          'Desde siempre. Esta orilla es mi casa.',
        ],
        talks: 1),
    TalkTopic(
        'brillo',
        'El agua que brilla',
        [
          'Ahí pasa un eco. Los peces lo siguen.',
        ],
        talks: 2,
        orders: 1),
    TalkTopic(
        'lago',
        'Este lago',
        [
          'Tiene más años que el bosque. Lo sé por los peces.',
        ],
        talks: 4,
        orders: 2),
  ]),
  'pesc_ruinas': NpcTalkDef(rooted: true, gift: 'Carrete de engranaje', greet: [
    'Cuidado con los engranajes del fondo.',
    'El estanque giró un poco hoy.',
    '¿Venís a pescar o a mirar?',
  ], decline: [
    'No, no. Acá me siento bien, no me voy a mover.',
    'Pero tomá: un carrete de los de antes. Todavía gira.',
  ], topics: [
    TalkTopic('oficio', '¿Qué pescás?', [
      'Peces que muerden metal viejo. No me preguntes cómo.',
    ]),
    TalkTopic(
        _vivis,
        '¿Vivís acá?',
        [
          'Entre las ruinas. Me hacen compañía.',
        ],
        talks: 1),
    TalkTopic(
        'estanque',
        'El estanque que gira',
        [
          'Lo mueve un mecanismo del pasado. Nadie le da cuerda.',
        ],
        talks: 2,
        orders: 1),
    TalkTopic(
        'nombre',
        '¿Por qué Engranaje?',
        [
          'Arreglo lo que encuentro. Y encuentro mucho.',
        ],
        talks: 4,
        orders: 2),
  ]),
  'pesc_cavernas': NpcTalkDef(rooted: true, gift: 'Línea de escarcha', greet: [
    'Hablá bajo. El eco asusta a los peces.',
    'Hace frío, ¿no? Ya te acostumbrás.',
    'El hielo cruje. Buena señal.',
  ], decline: [
    'Qué lindo que me invites. Pero acá me siento bien, no me voy a mover.',
    'Tomá esta línea: no se corta ni con el peor frío.',
  ], topics: [
    TalkTopic('oficio', '¿Qué pescás?', [
      'Lo que nada bajo el hielo. Hay que tener paciencia.',
    ]),
    TalkTopic(
        _vivis,
        '¿Vivís acá?',
        [
          'Sí. Acá no hay día ni noche, y me gusta así.',
        ],
        talks: 1),
    TalkTopic(
        'eco',
        'Los ecos bajo el hielo',
        [
          'A veces suenan antes de que tire la línea.',
        ],
        talks: 2,
        orders: 1),
  ]),
  'pesc_grieta': NpcTalkDef(rooted: true, gift: 'Caña templada', greet: [
    'No te acerques mucho al borde.',
    'Hoy el lago hierve tranquilo.',
    'Manos firmes, ¿eh?',
  ], decline: [
    'Ja. Acá me siento bien, no me voy a mover.',
    'Pero esto es tuyo: una caña templada en este mismo lago.',
  ], topics: [
    TalkTopic('oficio', '¿Qué pescás?', [
      'Lo que aguanta este calor. Pocos peces, pero duros.',
    ]),
    TalkTopic(
        _vivis,
        '¿Vivís acá?',
        [
          'Al lado del fuego. Me crié acá.',
        ],
        talks: 1),
    TalkTopic(
        'tiempo',
        'Peces de otro tiempo',
        [
          'Algunos ya estuvieron en otra época. Se les nota en las escamas.',
        ],
        talks: 2,
        orders: 1),
  ]),
  'pesc_abismo': NpcTalkDef(rooted: true, gift: 'Señuelo del mañana', greet: [
    'Ya pescaste conmigo. Mañana.',
    'El agua devuelve lo que cae del futuro.',
    'Sentate. Esto lleva tiempo, y el tiempo sobra.',
  ], decline: [
    'Ya sabía que me ibas a invitar. Acá me siento bien, no me voy a mover.',
    'Este señuelo lo vas a usar. Ya lo usaste.',
  ], topics: [
    TalkTopic('oficio', '¿Qué pescás?', [
      'Lo que el futuro deja caer al agua.',
    ]),
    TalkTopic(
        _vivis,
        '¿Vivís acá?',
        [
          'Vivo acá ahora, y antes, y después.',
        ],
        talks: 1),
    TalkTopic(
        'nombre',
        '¿Por qué Eco Viejo?',
        [
          'Porque llegué antes de llegar. Como todos los ecos.',
        ],
        talks: 2,
        orders: 1,
        sub: [
          TalkTopic('de_donde', '¿De cuándo venís?', [
            'De un mañana que no se puede cambiar. Tranquilo: termina bien.',
          ]),
        ]),
  ]),
};

/// La charla de [npc] (o `null`).
NpcTalkDef? npcTalk(String npc) => kNpcTalks[npc];

/// ¿[npc] es arraigado?
bool npcRooted(String npc) => kNpcTalks[npc]?.rooted ?? false;

/// Todos los arraigados tienen su bioma en el catálogo.
Iterable<String> get kRootedBiomes => [
      for (final b in kBiomeLayouts.keys)
        if (npcRooted(nativeId(b))) b
    ];
