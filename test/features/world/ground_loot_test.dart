import 'dart:ui' as ui;

import 'package:echos_del_tiempo/core/audio/sfx_catalog.dart';
import 'package:echos_del_tiempo/core/audio/sfx_service.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/loot_feed.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/minimap.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/loot_painter.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/map_game.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_sfx.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/loot_filter.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_filter_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';

/// Filtro de prueba: oculta lo Común; los Raros con todos los estilos.
const _filterText = '''
Ocultar
  Rareza Común
Mostrar
  Rareza Raro
  Color 10 20 30
  Borde 40 50 60
  Fondo 1 2 3 200
  Tamaño 45
  Sonido alerta
  Icono estrella rojo
''';

final _rules = LootFilterRules(catalog: progression.catalog);
final _filter = _rules.parse(_filterText).filter;

FilterVerdict _verdict(LootDrop d) => _rules.evaluate(_filter, d,
    FilterContext(level: 10, attributes: newProfile('A', 'guerrero').attributes));

LootDrop _item(String uid, Rarity r, {String base = 'lanza_hierro', String? name}) =>
    LootDrop.item(ItemInstance(uid: uid, baseId: base, rarity: r, name: name));

GameSession _session(List<GroundLoot> ground) =>
    sessionEngine().create()..ground.addAll(ground);

class _Recorder extends SfxService {
  final played = <String>[];
  @override
  void play(String id, {int delayMs = 0}) => played.add(id);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('qué se dibuja del piso', () {
    final common = GroundLoot(id: 1, drop: _item('c', Rarity.comun), x: 10, y: 10, ownerId: 'me');
    final rare = GroundLoot(
        id: 2, drop: _item('r', Rarity.raro, name: 'Punta Feroz'), x: 30, y: 10, ownerId: 'me');
    final theirs = GroundLoot(id: 3, drop: _item('t', Rarity.raro), x: 50, y: 10, ownerId: 'otro');
    const shared = GroundLoot(id: 4, drop: LootDrop.stack(StackKind.prisma, 1), x: 70, y: 10);
    final s = _session([common, rare, theirs, shared]);

    test('lo oculto por el filtro no se dibuja; lo de otro jugador nunca', () {
      final l = visibleLoot(s, 'me', _verdict);
      expect(l.map((x) => x.ground.id), [2, 4]);
      expect(l.every((x) => !x.hidden), isTrue);
    });

    test('con Alt se ve también lo oculto, marcado como oculto', () {
      final l = visibleLoot(s, 'me', _verdict, showAll: true);
      expect(l.map((x) => x.ground.id), [1, 2, 4]);
      expect(l.firstWhere((x) => x.ground.id == 1).hidden, isTrue);
      expect(l.firstWhere((x) => x.ground.id == 2).hidden, isFalse);
    });

    test('la etiqueta usa los colores y el tamaño del filtro', () {
      final r = visibleLoot(s, 'me', _verdict).firstWhere((x) => x.ground.id == 2);
      final c = labelColors(r);
      expect(c.text, const Color.fromARGB(255, 10, 20, 30));
      expect(c.border, const Color.fromARGB(255, 40, 50, 60));
      expect(c.background, const Color.fromARGB(200, 1, 2, 3));
      expect(labelPx(r.style.size), 7);
      expect(r.style.icon, const MapIcon(MapIconShape.estrella, MapIconColor.rojo));
    });

    test('sin estilo propio: color de la rareza sobre negro, sin borde; '
        'lo oculto a media opacidad', () {
      final d = _item('m', Rarity.magico);
      final g = GroundLoot(id: 9, drop: d, x: 0, y: 0);
      final plain = LootOnFloor(g, FilterVerdict(true, LootFilterRules.defaultStyle(d)),
          hidden: false);
      final c = labelColors(plain);
      expect(c.text, rarityColor(Rarity.magico));
      expect(c.text, const Color.fromARGB(255, 120, 150, 255));
      expect(c.border, isNull);
      expect(c.background, const Color(0xB3000000));
      final hidden = LootOnFloor(g, plain.verdict, hidden: true);
      expect(labelColors(hidden).text.a, closeTo(0.5, 0.01));
      expect(labelPx(18), 5);
      expect(labelPx(null), 6);
    });

    test('las etiquetas apiladas no se pisan', () {
      final p = LootPainter(nameOf: (d) => 'Objeto ${d.item?.uid}', weaponTypeOf: (_) => 'lanza');
      final many = [
        for (var i = 0; i < 6; i++)
          LootOnFloor(GroundLoot(id: i, drop: _item('$i', Rarity.raro), x: 100 + i * 2.0, y: 100),
              const FilterVerdict(true, FilterStyle()), hidden: false),
      ];
      final placed = p.placeLabels(many);
      for (var i = 0; i < placed.length; i++) {
        for (var j = i + 1; j < placed.length; j++) {
          expect(placed[i].rect.overlaps(placed[j].rect), isFalse);
        }
      }
    });

    test('íconos, brillo, haz y etiquetas se dibujan sin errores', () {
      final p = LootPainter(nameOf: (d) => 'X', weaponTypeOf: (id) => progression.catalog.weapons[id]?.type);
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      final types = {for (final w in progression.catalog.weapons.values) w.type: w.id};
      var id = 0;
      for (final base in types.values) {
        for (final r in Rarity.values) {
          p.drawItem(c, LootOnFloor(GroundLoot(id: id++, drop: _item('$id', r, base: base), x: 5, y: 5),
              const FilterVerdict(true, FilterStyle()), hidden: r == Rarity.comun), 100);
        }
      }
      for (final k in StackKind.values) {
        p.drawItem(c, LootOnFloor(GroundLoot(id: id++, drop: LootDrop.stack(k, 2), x: 5, y: 5),
            const FilterVerdict(true, FilterStyle()), hidden: false), 100);
      }
      p.drawBeam(c, 20, 20, 100, boost: 1);
      p.drawBeam(c, 20, 20, 900);
      rec.endRecording().dispose();
    });

    test('al cambiar de piso no queda ninguna etiqueta del piso anterior '
        '(ni ícono del minimapa, ni objetivo de E); al volver, sí', () {
      final e = sessionEngine(zones: true);
      final f = inField(e, 'm1');
      final p = f.players['p0']!;
      f.ground.addAll([
        GroundLoot(id: 1, drop: _item('a', Rarity.raro, name: 'Mandoble del Eco Veloz'),
            x: p.x, y: p.y, ownerId: 'p0'),
        GroundLoot(id: 2, drop: _item('b', Rarity.raro), x: p.x, y: p.y, floor: 1),
      ]);
      final painter = LootPainter(nameOf: (d) => d.item?.name ?? '?', weaponTypeOf: (_) => 'lanza');
      List<int> drawn() => [
            for (final l in painter.placeLabels(visibleLoot(f, 'p0', _verdict))) l.loot.ground.id
          ];
      expect(drawn(), [1]);
      f.mission!.floor = 1;
      expect(drawn(), [2]);
      expect(visibleLoot(f, 'p0', _verdict, showAll: true).map((l) => l.ground.id), [2]);
      // Parado sobre las coordenadas viejas: E no apunta a lo del piso 1.
      expect(nearestPickable(visibleLoot(f, 'p0', _verdict), p.x, p.y)!.ground.id, 2);
      f.mission!.floor = 0;
      expect(drawn(), [1]);
    });

    test('minimapa: un ícono por objeto que el filtro marca', () {
      final icons = [
        for (final l in visibleLoot(s, 'me', _verdict))
          if (l.style.icon case final i?) MinimapLoot(l.ground.x, l.ground.y, i),
      ];
      expect(icons, hasLength(1));
      expect(mapIconColor(icons.single.icon.color), const Color(0xFFFF4757));
    });
  });

  group('levantar', () {
    test('E elige lo dibujado más cercano a ≤ 24 px', () {
      LootOnFloor at(int id, double x) => LootOnFloor(
          GroundLoot(id: id, drop: _item('$id', Rarity.raro), x: x, y: 0),
          const FilterVerdict(true, FilterStyle()), hidden: false);
      final loot = [at(1, 20), at(2, 8), at(3, 30)];
      expect(nearestPickable(loot, 0, 0)!.ground.id, 2);
      expect(nearestPickable(loot, 100, 0), isNull);
      expect(nearestPickable([at(4, 24)], 0, 0)!.ground.id, 4);
      expect(nearestPickable([at(5, 24.5)], 0, 0), isNull);
    });

    test('E / Espacio: solo el flanco de bajada', () {
      final k = KeyEdge();
      expect([k.poll(true), k.poll(true), k.poll(false), k.poll(true)],
          [true, false, false, true]);
    });

    test('MapGame: E sin otra interacción levanta lo compartido (y lo oculto '
        'con Alt) con PickUpAction', () async {
      final sprites = await GameSprites.load(await SpriteCatalog.load());
      final c = SessionController(
          engine: sessionEngine(),
          store: InMemoryProfileStore(),
          clock: const SessionClock(autoStart: false));
      addTearDown(c.dispose);
      await c.start();
      // Lejos del mostrador y la armería.
      final me = c.session!.players[c.localId]!;
      c.teleport(me.x, me.y + 40);
      expect(c.view!.prompt, isNull);
      var pressed = false, alt = false;
      final game = MapGame(
          controller: c,
          sprites: sprites,
          input: () => (0.0, 0.0),
          showAllLoot: () => alt,
          pickupKey: () => pressed);
      final x = c.local.x, y = c.local.y;
      c.session!.ground.add(GroundLoot(id: 500, drop: _item('z', Rarity.raro), x: x + 5, y: y));
      final before = c.session!.players[c.localId]!.profile.items.length;
      pressed = true;
      game.update(0.016);
      expect(c.session!.ground.where((g) => g.id == 500), isEmpty);
      expect(c.session!.players[c.localId]!.profile.items.length, before + 1);
      // Mantenerla apretada no levanta otra vez.
      c.session!.ground.add(GroundLoot(id: 501, drop: _item('y', Rarity.raro), x: x, y: y));
      game.update(0.016);
      expect(c.session!.ground.where((g) => g.id == 501), hasLength(1));
      pressed = false;
      game.update(0.016);
      pressed = true;
      game.update(0.016);
      expect(c.session!.ground.where((g) => g.id == 501), isEmpty);
      // Oculto por el filtro (Común): sin Alt no se ve ni se levanta.
      expect(c.setLootFilter('Ocultar\n  Rareza Común\n'), isTrue);
      c.session!.ground.add(GroundLoot(id: 502, drop: _item('w', Rarity.comun), x: x, y: y));
      pressed = false;
      game.update(0.016);
      pressed = true;
      game.update(0.016);
      expect(c.session!.ground.where((g) => g.id == 502), hasLength(1));
      alt = true;
      pressed = false;
      game.update(0.016);
      pressed = true;
      expect(game.tryPickUp(), 502);
      expect(c.session!.ground.where((g) => g.id == 502), isEmpty);
      game.onRemove();
    });
  });

  group('avisos y registro', () {
    late double now;
    late LootFeed feed;
    final names = {'me': 'Ana', 'bo': 'Bruno'};
    setUp(() {
      now = 0;
      feed = LootFeed(
        localId: 'me',
        playerName: (id) => names[id] ?? id,
        itemName: (d) => d.item?.name ?? d.stack!.label,
        verdictFor: (_, d) => _verdict(d),
        clock: () => now,
      );
    });

    test('"Ana encontró: <objeto>" en el color de la rareza + aviso si fue '
        'directo al inventario', () {
      feed.onEvent(LootDropEvent('me', _item('r', Rarity.raro, name: 'Punta Feroz'),
          LootSource.battle));
      expect(feed.lines.single.text, 'Ana encontró: Punta Feroz');
      expect(feed.lines.single.color, rarityColor(Rarity.raro));
      final t = feed.toasts.single;
      expect(t.name, 'Punta Feroz');
      expect(t.style.textColor, const FilterColor(10, 20, 30));
      expect(t.legendary, isFalse);
      // Vence a los 3 s.
      now = LootFeed.toastS + 0.1;
      expect(feed.toasts, isEmpty);
      expect(feed.lines, hasLength(1));
    });

    test('lo oculto por el filtro no aparece; lo de otro sí (sin aviso)', () {
      feed.onEvent(LootDropEvent('me', _item('c', Rarity.comun), LootSource.battle));
      expect(feed.lines, isEmpty);
      feed.onEvent(LootDropEvent('bo', _item('r', Rarity.raro, name: 'Hoja'),
          LootSource.chest, groundId: 3));
      expect(feed.lines.single.text, 'Bruno encontró: Hoja');
      expect(feed.toasts, isEmpty);
    });

    test('al piso no avisa hasta levantarlo; el Legendario avisa siempre', () {
      feed.onEvent(LootDropEvent('me', _item('r', Rarity.raro, name: 'Hoja'),
          LootSource.battle, groundId: 7));
      expect(feed.toasts, isEmpty);
      feed.onEvent(LootPickedEvent('me', 7, _item('r', Rarity.raro, name: 'Hoja')));
      expect(feed.toasts.single.title, '+');
      feed.onEvent(LootDropEvent('me', _item('l', Rarity.legendario, name: 'Lanza del Horizonte'),
          LootSource.boss, groundId: 8));
      final leg = feed.toasts.last;
      expect(leg.legendary, isTrue);
      expect(leg.title, '¡LEGENDARIO!');
      expect(leg.durationS, LootFeed.legendaryToastS);
    });

    testWidgets('el aviso usa fondo, borde y color del filtro', (tester) async {
      feed.onEvent(LootDropEvent('me', _item('r', Rarity.raro, name: 'Punta Feroz'),
          LootSource.battle));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: Column(children: [LootToasts(feed: feed), LootLog(feed: feed)]))));
      final box = tester.widget<Container>(find.byKey(const ValueKey('loot-toast-Punta Feroz')));
      final deco = box.decoration! as BoxDecoration;
      expect(deco.color, const Color.fromARGB(200, 1, 2, 3));
      expect((deco.border! as Border).top.color, const Color.fromARGB(255, 40, 50, 60));
      final text = tester.widget<Text>(find.textContaining('Punta Feroz').first);
      expect(text.style!.color, const Color.fromARGB(255, 10, 20, 30));
      expect(text.style!.fontSize, toastFontSize(45));
      expect(find.byKey(const ValueKey('loot-log')), findsOneWidget);
      now = 20;
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('loot-log')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('sonido del loot', () {
    test('el sonido del filtro al caer, el haz del Legendario y levantar', () {
      final rec = _Recorder();
      final sfx = SessionSfx(rec, localId: 'me', lootVerdict: _verdict);
      expect(sfx.lootSounds(LootDropEvent('me', _item('r', Rarity.raro), LootSource.battle)),
          [cue(Sfx.loot('alerta'))]);
      expect(sfx.lootSounds(LootDropEvent('me', _item('c', Rarity.comun), LootSource.battle)),
          isEmpty);
      expect(sfx.lootSounds(LootDropEvent('bo', _item('r', Rarity.raro), LootSource.battle)),
          isEmpty);
      final leg = sfx.lootSounds(
          LootDropEvent('me', _item('l', Rarity.legendario), LootSource.boss, groundId: 2));
      expect(leg, contains(cue(Sfx.lootBeam, SessionSfx.lootBeamDelayMs)));
      expect(sfx.lootSounds(LootPickedEvent('me', 2, _item('l', Rarity.legendario))),
          [cue(Sfx.lootPickup)]);
      sfx.onEvent(LootPickedEvent('me', 2, _item('l', Rarity.legendario)));
      expect(rec.played, [Sfx.lootPickup]);
    });

    test('con el filtro por defecto el Legendario suena "legendario" + haz', () {
      final sfx = SessionSfx(_Recorder(), localId: 'me', lootVerdict: (d) =>
          _rules.evaluate(LootFilterRules.defaultFilter, d,
              FilterContext(level: 1, attributes: newProfile('A', 'guerrero').attributes)));
      expect(
          sfx.lootSounds(LootDropEvent('me', _item('l', Rarity.legendario), LootSource.boss)),
          [cue(Sfx.loot('legendario')), cue(Sfx.lootBeam, SessionSfx.lootBeamDelayMs)]);
    });
  });
}
