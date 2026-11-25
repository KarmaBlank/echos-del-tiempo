/// Conversaciones de los habitantes (overworld_biomes.md § 12): saludos,
/// temas de HABLAR que se abren con el tiempo y, para los arraigados, lo
/// que dicen al invitarlos. Datos puros; el lore sale solo de docs/lore.md.
library;

import '../models/localized_text.dart';
import 'biomes_catalog.dart';

export '../models/localized_text.dart';

/// Dónde se puede tocar un tema.
enum TalkWhere { any, biome, town }

/// When a topic can be raised (npc_editor.md § 3.2), by the world clock
/// (`SkyRules.isNight`).
enum TalkTime { any, day, night }

/// What choosing a topic does besides showing its lines
/// (npc_editor.md § 3.3). A fixed whitelist: the behaviour lives in
/// code, the editor only places, labels and conditions the option. No
/// action ever opens a quest.
enum TalkAction {
  none,

  /// Rooted NPC: the invite (they decline and give their gift).
  invite,

  /// Opens the shop (resident: BUY; rooted fisher: their stall).
  trade,

  /// Resident in town without a house: pick their house.
  house;

  static TalkAction fromName(Object? v) =>
      values.where((a) => a.name == v).firstOrNull ?? none;
}

/// Un tema de HABLAR: 1 o 2 frases cortas y, a veces, sub-temas.
/// Se abre con [talks] charlas, [orders] pedidos / encargos cumplidos,
/// [rep] de relación o amistad, [where] y [time]. Con [action] la opción
/// además dispara un comportamiento fijo del código.
class TalkTopic {
  const TalkTopic(this.id, this.label, this.lines,
      {this.talks = 0,
      this.orders = 0,
      this.rep = 0,
      this.renown = 0,
      this.where = TalkWhere.any,
      this.time = TalkTime.any,
      this.action = TalkAction.none,
      this.sub = const []});

  final String id;
  final LocalizedText label;
  final List<LocalizedText> lines;
  final int talks;
  final int orders;
  final int rep;

  /// Minimum world renown (renown_town_growth.md § 4.1).
  final int renown;
  final TalkWhere where;
  final TalkTime time;
  final TalkAction action;
  final List<TalkTopic> sub;
}

/// La charla de un habitante. [rooted]: no se muda al pueblo nunca; a
/// cambio, al invitarlo responde con [decline] y da su regalo único.
/// Every text is per language ([LocalizedText], npc_editor.md § 1.1).
class NpcTalkDef {
  const NpcTalkDef(
      {required this.greet,
      required this.topics,
      this.rooted = false,
      this.decline = const [],
      this.gift = '',
      this.ambient = const [],
      this.homeAmbient = const [],
      this.night = const {},
      this.inviteAccept = LocalizedText.empty,
      this.thanksDay = LocalizedText.empty,
      this.thanksNight = LocalizedText.empty});

  /// Saludos (uno al azar al abrir).
  final List<LocalizedText> greet;
  final List<TalkTopic> topics;
  final bool rooted;
  final List<LocalizedText> decline;

  /// Nombre del regalo único del arraigado.
  final String gift;

  /// Loose lines: the resident's line of the day (one per world day, in
  /// order) or the rooted fisher's shore lines.
  final List<LocalizedText> ambient;

  /// Loose lines of a resident once they live in town (invited). When
  /// non-empty they replace [ambient] there, so the recruit pitch
  /// ("take me to your town") never plays after moving
  /// (overworld_biomes.md § 12.1).
  final List<LocalizedText> homeAmbient;

  /// Night outing reasons by outing id (`BiomeNpcDef.nightOutings`).
  final Map<String, LocalizedText> night;

  /// What a resident says when accepting the invite.
  final LocalizedText inviteAccept;

  /// What a resident says after getting a house (by day / by night).
  final LocalizedText thanksDay;
  final LocalizedText thanksNight;
}

typedef _L = LocalizedText;

/// Id del arraigado de [biome] (el pescador nativo).
String nativeId(String biome) => 'pesc_$biome';

const _vivis = 'vivis';

/// Por habitante: los cinco que se mudan (por id) y los cinco arraigados
/// (`pesc_<bioma>`).
/// Valores del código (respaldo de `assets/data/npcs/npcs.json`,
/// npc_editor.md § 1).
const kNpcTalksDefaults = <String, NpcTalkDef>{
  // ---------------- se mudan ----------------
  'ilda': NpcTalkDef(
      ambient: [
        _L('Las moras de acá saben distinto cada mañana. Como si el bosque se '
            'acordara de algo.'),
        _L('Hay ecos que bajan por el río. Yo no los pesco: los dejo pasar.'),
        _L('Si un día tu pueblo necesita quien cure, avisame.'),
      ],
      // BORRADOR (draft) for the owner.
      homeAmbient: [
        _L('Las moras de acá saben distinto cada mañana. Como si el bosque se '
            'acordara de algo.'),
        _L('Hay ecos que bajan por el río. Yo no los pesco: los dejo pasar.'),
        _L('Si alguien del pueblo se lastima, que venga. Para eso me mudé.'),
      ],
      night: {
        'ilda_garden': _L(
            'De noche la huerta se queda sola y las plagas lo saben. Vengo a espantarlas y a ver si los brotes aguantan el rocío.'),
        'ilda_dew': _L(
            'El rocío de la fuente cura mejor si lo junto antes de que amanezca. Así lo hacían los de antes, con frascos que brillaban.'),
      },
      inviteAccept: _L('Sí, acepto. Me gustaría ir a tu pueblo.'),
      thanksDay: _L(
          'Muchas gracias por darme un nuevo hogar, voy a estar aquí en el pueblo, voy a intentar ayudarte…'),
      thanksNight: _L(
          'Muchas gracias por darme un nuevo hogar. Esta noche ya duermo bajo mi techo; mañana voy a intentar ayudarte…'),
      greet: [
        _L('Llegaste justo. Estaba separando hojas.'),
        _L('¿Venís a charlar o a buscar remedios?'),
        _L('El bosque está tranquilo hoy.'),
      ],
      topics: [
        TalkTopic('oficio', _L('¿Qué hacés?'), [
          _L('Curo con lo que da el bosque. Hojas, raíces, rocío.'),
        ]),
        TalkTopic(
            _vivis,
            _L('¿Vivís acá?'),
            [
              _L('Por ahora. Si tu pueblo necesita quien cure, me mudo.'),
            ],
            talks: 1,
            where: TalkWhere.biome),
        TalkTopic(
            'pueblo',
            _L('¿Cómo te trata el pueblo?'),
            [
              _L('Bien. Extraño el bosque, pero acá alguien siempre se lastima.'),
            ],
            where: TalkWhere.town),
        TalkTopic(
            'ecos',
            _L('Los ecos'),
            [
              _L('Bajan por el río, como hojas. Algunos vienen de mañana.'),
            ],
            talks: 2,
            sub: [
              TalkTopic('miedo', _L('¿Te dan miedo?'), [
                _L('No. Lo que tiene que pasar, pasa. Yo curo lo que quede.'),
              ]),
            ]),
        TalkTopic(
            'sombra',
            _L('Algo raro en el bosque'),
            [
              _L('Hay rincones donde la luz no entra. No es el follaje.'),
            ],
            talks: 4,
            rep: 3),
      ]),
  'velda': NpcTalkDef(
      ambient: [
        _L('Estas placas son mapas. Del pasado, cuando todo era más avanzado.'),
        _L('Los autómatas no están rotos: esperan una orden que nadie recuerda.'),
        _L('Algo hizo que el mundo se volviera medieval. Lo estoy anotando.'),
      ],
      night: {
        'velda_lamp': _L(
            'Bajo la lámpara del tablero se leen mejor mis notas. De día el pueblo hace demasiado ruido para pensar.'),
        'velda_statue': _L(
            'De noche las runas de la estatua se encienden apenas. Son del pasado, cuando las máquinas hablaban. Las estoy copiando.'),
      },
      inviteAccept: _L('Sí, acepto. Me gustaría ir a tu pueblo.'),
      thanksDay: _L(
          'Muchas gracias por darme un nuevo hogar, voy a estar aquí en el pueblo, voy a intentar ayudarte…'),
      thanksNight: _L(
          'Muchas gracias por darme un nuevo hogar. Esta noche ya duermo bajo mi techo; mañana voy a intentar ayudarte…'),
      greet: [
        _L('Cuidado dónde pisás: esa placa es un mapa.'),
        _L('Ah, sos vos. Anoto y te escucho.'),
        _L('Las ruinas hablan si sabés leer.'),
      ],
      topics: [
        TalkTopic('oficio', _L('¿Qué anotás?'), [
          _L('Todo lo que dejó el pasado. Era más avanzado que nosotros.'),
        ]),
        TalkTopic(
            _vivis,
            _L('¿Vivís acá?'),
            [
              _L('Vivo donde están los papeles. Si me das un techo, los llevo.'),
            ],
            talks: 1,
            where: TalkWhere.biome),
        TalkTopic(
            'pueblo',
            _L('¿Y el pueblo?'),
            [
              _L('Tranquilo. Ya armé un archivo en mi casa.'),
            ],
            where: TalkWhere.town),
        TalkTopic(
            'automatas',
            _L('Los autómatas'),
            [
              _L('Se movían con magia, no con vapor. Esperan una orden.'),
            ],
            talks: 2,
            sub: [
              TalkTopic('orden', _L('¿Qué orden?'), [
                _L('Nadie la recuerda. Por eso sigo leyendo.'),
              ]),
            ]),
        TalkTopic(
            'caida',
            _L('¿Qué pasó con el pasado?'),
            [
              _L('Algo hizo que todo volviera a ser medieval. No sé qué. Todavía.'),
            ],
            talks: 4,
            rep: 3),
      ]),
  'kael': NpcTalkDef(
      ambient: [
        _L('Acá abajo no hay día ni noche. Solo el frío y el eco de tus pasos.'),
        _L('El eco que oís a veces llega antes que tu voz. Es del futuro.'),
        _L('Entrená conmigo y vas a aprender más rápido allá afuera.'),
      ],
      night: {
        'kael_watch': _L(
            'Alguien tiene que mirar el portal de noche. Los ecos no avisan cuándo vuelven.'),
        'kael_drill': _L(
            'Entreno cuando no me ve nadie. El cuerpo aprende mejor en el silencio.'),
      },
      inviteAccept: _L('Sí, acepto. Me gustaría ir a tu pueblo.'),
      thanksDay: _L(
          'Muchas gracias por darme un nuevo hogar, voy a estar aquí en el pueblo, voy a intentar ayudarte…'),
      thanksNight: _L(
          'Muchas gracias por darme un nuevo hogar. Esta noche ya duermo bajo mi techo; mañana voy a intentar ayudarte…'),
      greet: [
        _L('Hombros abajo. Respirá.'),
        _L('Otra vez por acá. Bien.'),
        _L('El frío enseña paciencia.'),
      ],
      topics: [
        TalkTopic('oficio', _L('¿Qué enseñás?'), [
          _L('A moverse sin miedo. Lo demás viene solo.'),
        ]),
        TalkTopic(
            _vivis,
            _L('¿Vivís acá?'),
            [
              _L('Acá entreno. Si tu pueblo tiene lugar, entreno allá.'),
            ],
            talks: 1,
            where: TalkWhere.biome),
        TalkTopic(
            'pueblo',
            _L('¿Te gusta el pueblo?'),
            [
              _L('Hay sol. Me cuesta acostumbrarme.'),
            ],
            where: TalkWhere.town),
        TalkTopic(
            'eco',
            _L('El eco de las cavernas'),
            [
              _L('A veces oigo mis pasos antes de darlos. Vienen del futuro.'),
            ],
            talks: 2),
      ]),
  'brann': NpcTalkDef(
      ambient: [
        _L('Este calor viene de abajo, de un mecanismo viejo que sigue andando.'),
        _L('Forjo con lo que deja el pasado. Nada se pierde del todo.'),
        _L('Llevame a tu pueblo y tus mejoras van a salir más baratas.'),
      ],
      // BORRADOR (draft) for the owner.
      homeAmbient: [
        _L('Este calor viene de abajo, de un mecanismo viejo que sigue andando.'),
        _L('Forjo con lo que deja el pasado. Nada se pierde del todo.'),
        _L('La forja del pueblo ya agarró temperatura. Traeme lingotes y te hago algo.'),
        _L('Acá el fuego es más chico, pero es mío. Me gusta despertarme al lado.'),
      ],
      night: {
        'brann_embers': _L(
            'Una forja no se deja morir. Si las brasas se apagan, el mecanismo de abajo se enfría y cuesta una semana despertarlo.'),
        'brann_stock': _L(
            'Cuento lo que queda bajo el farol. Si mañana falta una pieza, prefiero saberlo hoy.'),
      },
      inviteAccept: _L('Sí, acepto. Me gustaría ir a tu pueblo.'),
      thanksDay: _L(
          'Muchas gracias por darme un nuevo hogar, voy a estar aquí en el pueblo, voy a intentar ayudarte…'),
      thanksNight: _L(
          'Muchas gracias por darme un nuevo hogar. Esta noche ya duermo bajo mi techo; mañana voy a intentar ayudarte…'),
      greet: [
        _L('Cuidado, que quema.'),
        _L('¿Traés metal? No, ya sé, traés preguntas.'),
        _L('El fuego de abajo no se apaga nunca.'),
      ],
      topics: [
        TalkTopic('oficio', _L('¿Qué forjás?'), [
          _L('Lo que deja el pasado, rehecho. Nada se pierde del todo.'),
        ]),
        TalkTopic(
            _vivis,
            _L('¿Vivís acá?'),
            [
              _L('Vivo al lado del fuego. Si en tu pueblo hay fuego, voy.'),
            ],
            talks: 1,
            where: TalkWhere.biome),
        TalkTopic(
            'pueblo',
            _L('¿Cómo va la forja?'),
            [
              _L('Más fría que la grieta. Igual sale buen acero.'),
            ],
            where: TalkWhere.town),
        TalkTopic(
            'mecanismo',
            _L('El calor de la grieta'),
            [
              _L('Viene de un mecanismo viejo, más abajo. Sigue andando solo.'),
            ],
            talks: 2,
            sub: [
              TalkTopic('quien', _L('¿Quién lo hizo?'), [
                _L('Los de antes. Sabían mezclar magia y engranaje.'),
              ]),
            ]),
      ]),
  'oren': NpcTalkDef(
      ambient: [
        _L('El futuro no se cambia. Se cumple. Yo solo miro cómo llega.'),
        _L('Ya te vi volver de esa mazmorra. Todavía no fuiste.'),
        _L('Lo que tiene que pasar, pasa. Mejor llegar sanos.'),
      ],
      night: {
        'oren_stars': _L(
            'Las estrellas ya están donde van a estar. Yo solo las leo; el futuro no se mueve, pero se puede ver venir.'),
        'oren_fountain': _L(
            'El agua de la fuente refleja lo que todavía no pasó. Esta noche está tranquila. Eso es bueno.'),
      },
      inviteAccept: _L('Sí, acepto. Me gustaría ir a tu pueblo.'),
      thanksDay: _L(
          'Muchas gracias por darme un nuevo hogar, voy a estar aquí en el pueblo, voy a intentar ayudarte…'),
      thanksNight: _L(
          'Muchas gracias por darme un nuevo hogar. Esta noche ya duermo bajo mi techo; mañana voy a intentar ayudarte…'),
      greet: [
        _L('Ya sabía que venías.'),
        _L('Sentate. O no. Ya te vi hacer las dos cosas.'),
        _L('Llegás a tiempo. Siempre.'),
      ],
      topics: [
        TalkTopic('oficio', _L('¿Qué ves?'), [
          _L('Lo que va a pasar. No lo puedo cambiar; solo mirar.'),
        ]),
        TalkTopic(
            _vivis,
            _L('¿Vivís acá?'),
            [
              _L('Vivo donde el futuro se oye mejor. Tu pueblo también sirve.'),
            ],
            talks: 1,
            where: TalkWhere.biome),
        TalkTopic(
            'pueblo',
            _L('¿Qué ves desde el pueblo?'),
            [
              _L('Gente que vuelve sana. Eso ya pasó, aunque no pasó.'),
            ],
            where: TalkWhere.town),
        TalkTopic(
            'futuro',
            _L('El futuro'),
            [
              _L('Hay algo muy malo allá. Y aun así, tiene que llegar.'),
            ],
            talks: 2,
            sub: [
              TalkTopic('bueno', _L('¿Termina bien?'), [
                _L('Creo que sí. Pero porque pasa todo lo que tiene que pasar.'),
              ]),
            ]),
      ]),

  // ---------------- arraigados ----------------
  'pesc_bosque': NpcTalkDef(
      ambient: [
        _L('Este lago guarda peces que ya nadaban antes de los árboles.'),
        _L('Si ves el agua brillar, tirá ahí. No me preguntes por qué.'),
      ],
      rooted: true,
      gift: 'Anzuelo de raíz',
      greet: [
        _L('Shh, que pican.'),
        _L('Sentate en la orilla, hay lugar.'),
        _L('Hoy el agua está clara.'),
      ],
      decline: [
        _L('Gracias, de verdad. Pero acá me siento bien, no me voy a mover.'),
        _L('Llevate esto. Lo hice con una raíz más vieja que el lago.'),
      ],
      topics: [
        TalkTopic('oficio', _L('¿Qué pescás?'), [
          _L('Lo que el lago quiera dar. Hay peces de antes de los árboles.'),
        ]),
        TalkTopic(
            _vivis,
            _L('¿Vivís acá?'),
            [
              _L('Desde siempre. Esta orilla es mi casa.'),
            ],
            talks: 1),
        TalkTopic(
            'brillo',
            _L('El agua que brilla'),
            [
              _L('Ahí pasa un eco. Los peces lo siguen.'),
            ],
            talks: 2,
            orders: 1),
        TalkTopic(
            'lago',
            _L('Este lago'),
            [
              _L('Tiene más años que el bosque. Lo sé por los peces.'),
            ],
            talks: 4,
            orders: 2),
      ]),
  'pesc_ruinas': NpcTalkDef(
      ambient: [
        _L('Los peces de acá muerden metal viejo. Raro, ¿no?'),
        _L('El estanque gira despacio, como un reloj que nadie da cuerda.'),
      ],
      rooted: true,
      gift: 'Carrete de engranaje',
      greet: [
        _L('Cuidado con los engranajes del fondo.'),
        _L('El estanque giró un poco hoy.'),
        _L('¿Venís a pescar o a mirar?'),
      ],
      decline: [
        _L('No, no. Acá me siento bien, no me voy a mover.'),
        _L('Pero tomá: un carrete de los de antes. Todavía gira.'),
      ],
      topics: [
        TalkTopic('oficio', _L('¿Qué pescás?'), [
          _L('Peces que muerden metal viejo. No me preguntes cómo.'),
        ]),
        TalkTopic(
            _vivis,
            _L('¿Vivís acá?'),
            [
              _L('Entre las ruinas. Me hacen compañía.'),
            ],
            talks: 1),
        TalkTopic(
            'estanque',
            _L('El estanque que gira'),
            [
              _L('Lo mueve un mecanismo del pasado. Nadie le da cuerda.'),
            ],
            talks: 2,
            orders: 1),
        TalkTopic(
            'nombre',
            _L('¿Por qué Engranaje?'),
            [
              _L('Arreglo lo que encuentro. Y encuentro mucho.'),
            ],
            talks: 4,
            orders: 2),
      ]),
  'pesc_cavernas': NpcTalkDef(
      ambient: [
        _L('Bajo el hielo se oyen ecos. A veces son peces.'),
        _L('Paciencia: acá el agua tarda en contestar.'),
      ],
      rooted: true,
      gift: 'Línea de escarcha',
      greet: [
        _L('Hablá bajo. El eco asusta a los peces.'),
        _L('Hace frío, ¿no? Ya te acostumbrás.'),
        _L('El hielo cruje. Buena señal.'),
      ],
      decline: [
        _L('Qué lindo que me invites. Pero acá me siento bien, no me voy a mover.'),
        _L('Tomá esta línea: no se corta ni con el peor frío.'),
      ],
      topics: [
        TalkTopic('oficio', _L('¿Qué pescás?'), [
          _L('Lo que nada bajo el hielo. Hay que tener paciencia.'),
        ]),
        TalkTopic(
            _vivis,
            _L('¿Vivís acá?'),
            [
              _L('Sí. Acá no hay día ni noche, y me gusta así.'),
            ],
            talks: 1),
        TalkTopic(
            'eco',
            _L('Los ecos bajo el hielo'),
            [
              _L('A veces suenan antes de que tire la línea.'),
            ],
            talks: 2,
            orders: 1),
      ]),
  'pesc_grieta': NpcTalkDef(
      ambient: [
        _L('Pescar en brasas pide manos duras y caña firme.'),
        _L('Lo que sale de este lago ya estuvo en otro tiempo.'),
      ],
      rooted: true,
      gift: 'Caña templada',
      greet: [
        _L('No te acerques mucho al borde.'),
        _L('Hoy el lago hierve tranquilo.'),
        _L('Manos firmes, ¿eh?'),
      ],
      decline: [
        _L('Ja. Acá me siento bien, no me voy a mover.'),
        _L('Pero esto es tuyo: una caña templada en este mismo lago.'),
      ],
      topics: [
        TalkTopic('oficio', _L('¿Qué pescás?'), [
          _L('Lo que aguanta este calor. Pocos peces, pero duros.'),
        ]),
        TalkTopic(
            _vivis,
            _L('¿Vivís acá?'),
            [
              _L('Al lado del fuego. Me crié acá.'),
            ],
            talks: 1),
        TalkTopic(
            'tiempo',
            _L('Peces de otro tiempo'),
            [
              _L('Algunos ya estuvieron en otra época. Se les nota en las escamas.'),
            ],
            talks: 2,
            orders: 1),
      ]),
  'pesc_abismo': NpcTalkDef(
      ambient: [
        _L('Pesco lo que el futuro deja caer al agua.'),
        _L('Todo lo que saques de acá ya lo sacaste antes.'),
      ],
      rooted: true,
      gift: 'Señuelo del mañana',
      greet: [
        _L('Ya pescaste conmigo. Mañana.'),
        _L('El agua devuelve lo que cae del futuro.'),
        _L('Sentate. Esto lleva tiempo, y el tiempo sobra.'),
      ],
      decline: [
        _L('Ya sabía que me ibas a invitar. Acá me siento bien, no me voy a mover.'),
        _L('Este señuelo lo vas a usar. Ya lo usaste.'),
      ],
      topics: [
        TalkTopic('oficio', _L('¿Qué pescás?'), [
          _L('Lo que el futuro deja caer al agua.'),
        ]),
        TalkTopic(
            _vivis,
            _L('¿Vivís acá?'),
            [
              _L('Vivo acá ahora, y antes, y después.'),
            ],
            talks: 1),
        TalkTopic(
            'nombre',
            _L('¿Por qué Eco Viejo?'),
            [
              _L('Porque llegué antes de llegar. Como todos los ecos.'),
            ],
            talks: 2,
            orders: 1,
            sub: [
              TalkTopic('de_donde', _L('¿De cuándo venís?'), [
                _L('De un mañana que no se puede cambiar. Tranquilo: termina bien.'),
              ]),
            ]),
      ]),
};

/// Lo que lee el juego: el código, con el archivo de datos encima
/// (`NpcData.install`).
final Map<String, NpcTalkDef> kNpcTalks = Map.of(kNpcTalksDefaults);

/// La charla de [npc] (o `null`).
NpcTalkDef? npcTalk(String npc) => kNpcTalks[npc];

/// ¿[npc] es arraigado?
bool npcRooted(String npc) => kNpcTalks[npc]?.rooted ?? false;

/// Todos los arraigados tienen su bioma en el catálogo.
Iterable<String> get kRootedBiomes => [
      for (final b in kBiomeLayouts.keys)
        if (npcRooted(nativeId(b))) b
    ];
