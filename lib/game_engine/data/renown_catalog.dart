import '../models/localized_text.dart';
import '../models/renown.dart';

export '../models/renown.dart';

LocalizedText _t(String es, String en, String zh) =>
    LocalizedText.of({'es-AR': es, 'en': en, 'zh-Hans': zh});

RecognitionLine _line(String id, String who, int min, String es, String en,
        String zh) =>
    RecognitionLine(id: id, who: who, minRenown: min, text: _t(es, en, zh));

/// Code defaults of the renown catalog
/// (docs/specs/renown_town_growth.md): only the fallback when
/// `assets/data/renown/renown.json` is missing or broken. Every text is a
/// BORRADOR (draft) for the owner.
final RenownConfig kRenownDefaults = RenownConfig(
  sources: const {
    RenownSource.zone: 10,
    RenownSource.biomeBoss: 25,
    RenownSource.rift: 8,
    RenownSource.lore: 12,
    RenownSource.tourney: 15,
    RenownSource.resident: 6,
    RenownSource.building: 1,
  },
  town: const {
    TownWeight.resident: 4,
    TownWeight.building: 1,
    TownWeight.renown: 0.1,
  },
  tiers: [
    RenownTier(0, _t('Desconocidos', 'Unknown', '无名之辈')),
    RenownTier(30, _t('Conocidos en la zona', 'Known around here', '小有名气')),
    RenownTier(90, _t('Se habla de ustedes', 'People talk about you', '声名渐起')),
    RenownTier(
        180, _t('Héroes del presente', 'Heroes of the present', '当世英雄')),
    RenownTier(
        320, _t('Leyenda de los ecos', 'Legend of the echoes', '回声传奇')),
  ],
  townTiers: [
    RenownTier(0, _t('Caserío', 'Hamlet', '小村落')),
    RenownTier(15, _t('Aldea', 'Village', '村庄')),
    RenownTier(35, _t('Pueblo', 'Town', '城镇')),
    RenownTier(70, _t('Ciudad', 'City', '城市')),
  ],
  lines: [
    _line(
        'visitor_heard',
        RecognitionWho.visitor,
        30,
        '¡Ah! ¿Vos sos quien derrotó a {lastBoss}? Se habla de eso en otras partes.',
        'Oh! Are you the one who defeated {lastBoss}? People talk about it elsewhere.',
        '啊！你就是打败{lastBoss}的人吗？别的地方都在谈论这件事。'),
    _line(
        'visitor_legend',
        RecognitionWho.visitor,
        180,
        'En {townName} vive gente que pelea con ecos. Vine a verlo con mis ojos.',
        'In {townName} live people who fight echoes. I came to see it myself.',
        '{townName}住着与回声战斗的人。我是来亲眼看看的。'),
    _line(
        'wanderer_heard',
        RecognitionWho.wanderer,
        30,
        'Escuché de {lastBoss}. El eco de esa pelea llegó hasta acá.',
        'I heard about {lastBoss}. The echo of that fight reached all the way here.',
        '我听说了{lastBoss}的事。那场战斗的回声一直传到了这里。'),
    _line(
        'caravan_safe',
        RecognitionWho.caravan,
        90,
        'Nos dijeron que en {townName} se compra bien. Y que es seguro.',
        'We were told {townName} is a good place to trade. And a safe one.',
        '有人告诉我们，在{townName}做买卖很好，而且很安全。'),
    _line('ilda_heard', 'ilda', 30,
        'Dicen que venciste a {lastBoss}. Vení que te reviso esas heridas.',
        'They say you beat {lastBoss}. Come here, let me check those wounds.',
        '听说你打败了{lastBoss}。过来，我看看你的伤。'),
    _line('ilda_legend', 'ilda', 180,
        'En {townName} ya nadie tiene miedo de noche. Eso es obra tuya.',
        'Nobody in {townName} is afraid at night anymore. That is your doing.',
        '{townName}的人夜里已不再害怕。这是你的功劳。'),
    _line('velda_heard', 'velda', 30,
        'Anoté lo de {lastBoss}. Los registros del pasado no mencionan nada igual.',
        'I wrote down the {lastBoss} affair. The old records mention nothing like it.',
        '我记下了{lastBoss}的事。过去的记录里没有类似的记载。'),
    _line('velda_legend', 'velda', 180,
        'Tu nombre ya figura en mis notas al lado de los autómatas. Es un elogio.',
        'Your name is in my notes, right next to the automatons. It is a compliment.',
        '你的名字已写进我的笔记，就在自动人偶旁边。这是称赞。'),
    _line('kael_heard', 'kael', 30,
        '{lastBoss}, ¿eh? Bien. Ahora no te relajes.',
        '{lastBoss}, huh? Good. Now do not get comfortable.',
        '{lastBoss}，嗯？不错。现在可别松懈。'),
    _line('kael_legend', 'kael', 180,
        'Los ecos te esperan antes de que llegues. Eso pasa con los que importan.',
        'The echoes wait for you before you arrive. That happens to those who matter.',
        '回声在你到来之前就在等你。重要的人才会这样。'),
    _line('brann_heard', 'brann', 30,
        'El arma que venció a {lastBoss} merece un buen filo. Traémela.',
        'The weapon that beat {lastBoss} deserves a fine edge. Bring it to me.',
        '打败{lastBoss}的武器值得好好开刃。拿来给我。'),
    _line('brann_legend', 'brann', 180,
        'Vienen de lejos a pedirme lo mismo que te forjé a vos.',
        'People come from far away to ask for what I forged for you.',
        '有人从远方来，就为了求我给你打的那种东西。'),
    _line('oren_heard', 'oren', 30,
        '{lastBoss} tenía que caer. Lo vi antes de que pasara.',
        '{lastBoss} had to fall. I saw it before it happened.',
        '{lastBoss}注定会倒下。我在它发生之前就看见了。'),
    _line('oren_legend', 'oren', 180,
        'Lo que hacés ya está escrito más adelante. Seguí: tiene que pasar.',
        'What you do is already written further ahead. Go on: it has to happen.',
        '你所做的早已写在前方。继续吧：这必须发生。'),
  ],
  events: [
    TownEventDef(
      id: 'tourney_kael',
      kind: TownEventKind.tournament,
      proposer: 'kael',
      minRep: 8,
      minRenown: 30,
      delay: 2,
      cooldown: 10,
      rounds: const [
        ['esqueleto', 'esqueleto'],
        ['caballeroCaido'],
        ['caballeroHueco'],
      ],
      levelBonus: 1,
      prize: 300,
      title: _t('Torneo del pueblo', 'Town tournament', '城镇比武大会'),
      propose: _t(
          'Hay gente que quiere medirse con vos. ¿Armamos un torneo en {townName}?',
          'People want to test themselves against you. Shall we hold a tournament in {townName}?',
          '有人想和你较量一番。我们在{townName}办一场比武大会吧？'),
      accept: _t('Torneo programado: en dos días se pelea en el pueblo.',
          'Tournament scheduled: in two days there will be fights in town.',
          '比武大会已安排：两天后在镇上开打。'),
      signup: _t('Tres peleas, una detrás de otra. ¿Te anotás?',
          'Three fights, one after another. Will you sign up?',
          '三场比赛，一场接一场。你要报名吗？'),
    ),
  ],
);

/// The catalog the game reads (code defaults, or the data file once
/// `RenownLoader` installs it).
RenownConfig kRenown = kRenownDefaults;
