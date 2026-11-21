// Capturas de v0.20.0: identidad de las armas (aura por elemento,
// legendaria con destello, ULT, variantes e inventario). NO es parte de
// la suite. Correr con
//   flutter test tool/shots/v0200_identidad_armas_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/app.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/procedural/item_icons.dart';
import 'package:echos_del_tiempo/core/procedural/weapon_look.dart';
import 'package:echos_del_tiempo/core/settings/crt_filter.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/item_widgets.dart';
import 'package:echos_del_tiempo/game_engine/data/uniques_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/elements.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/hero_figure.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/game_engine/session_test_helpers.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.20.0';
const _size = Size(1920, 1080);
const _classes = ['guerrero', 'maga', 'tirador', 'paladin'];

Future<void> _shot(WidgetTester tester, String name) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img = await layer.toImage(Offset.zero & _size);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

const _elements = [
  GameElement.fuego,
  GameElement.hielo,
  GameElement.veneno,
  GameElement.sagrado,
  GameElement.agua,
  GameElement.electro,
];
const _clsType = {
  'guerrero': 'espada',
  'maga': 'báculo',
  'tirador': 'arco',
  'paladin': 'espada+escudo',
};

ItemInstance _item(int i, GameElement? el,
    {Rarity r = Rarity.epico, String? ult}) {
  final cls = _classes[i % 4];
  final w = kWeapons.values.firstWhere((w) => w.type == _clsType[cls]);
  return ItemInstance(
      uid: 'shot-$i',
      baseId: w.id,
      rarity: r,
      itemLevel: 20,
      element: el,
      ultId: ult);
}

PlayerProfile _withItem(int i, ItemInstance it) {
  final p = newProfile(
      it.element?.label.toUpperCase() ?? 'SIN', _classes[i % 4]);
  return progression.normalize(p.copyWith(items: [it], equipped: it.uid));
}

Future<void> _boundaryShot(
    WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage();
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(png!.buffer.asUint8List());
    img.dispose();
  });
}

Widget _label(String s) =>
    Text(s, style: const TextStyle(
        color: Color(0xFFE8ECFF), fontSize: 14, fontFamily: RetroTheme.fontFamily));

void main() {
  testWidgets('identidad: galería de auras', (tester) async {
    await loadRealFonts(tester);
    const size = Size(1500, 760);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late GameSprites sprites;
    await tester.runAsync(() async {
      sprites = await GameSprites.load(await SpriteCatalog.load());
    });
    final u = kUniques['corazonAscua']!;
    final leg = ItemInstance(
        uid: 'leg',
        baseId: u.baseId,
        rarity: Rarity.legendario,
        uniqueId: u.id);
    final figs = <(String, String, ItemInstance)>[
      for (final (i, e) in _elements.indexed)
        (e.label, _classes[i % 4], _item(i, e)),
      ('LEGENDARIA', 'maga', leg),
      ('SIN ELEMENTO', 'guerrero', _item(0, null, r: Rarity.raro)),
      ('ULT (pomo)', 'guerrero', _item(4, GameElement.electro, ult: 'x')),
      for (final uid in ['a', 'b', 'e'])
        ('variante', 'guerrero',
            ItemInstance(uid: uid, baseId: 'espada_bronce', rarity: Rarity.raro)),
    ];
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: RetroTheme.build(),
      home: RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: const Color(0xFF1B1D2E),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (name, cls, it) in figs)
              Column(mainAxisSize: MainAxisSize.min, children: [
                HeroFigure(sprites.heroFor(cls, null)!,
                    classId: cls,
                    weaponType: kWeapons[it.baseId]!.type,
                    look: WeaponLook.of(it),
                    size: const Size(230, 200)),
                _label('$name · v${WeaponLook.variantOf(it.uid)}'),
              ]),
          ]),
        ),
      ),
    ));
    await tester.pump();
    await _boundaryShot(tester, key, '00_galeria_auras');
  });

  testWidgets('identidad: inventario', (tester) async {
    await loadRealFonts(tester);
    const size = Size(1000, 260);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final u = kUniques['inviernoPerpetuo']!;
    final items = [
      for (final (i, e) in _elements.indexed) _item(i, e),
      ItemInstance(
          uid: 'leg',
          baseId: u.baseId,
          rarity: Rarity.legendario,
          uniqueId: u.id),
      _item(1, null, r: Rarity.magico),
    ];
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: RetroTheme.build(),
      home: RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: const Color(0xFF1B1D2E),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(spacing: 12, runSpacing: 12, children: [
              for (final it in items)
                Column(mainAxisSize: MainAxisSize.min, children: [
                  PixelIcon(iconKeyForType(kWeapons[it.baseId]!.type),
                      accent: RarityColors.of(it.rarity),
                      size: 80,
                      procKey: procKeyForType(kWeapons[it.baseId]!.type),
                      look: WeaponLook.of(it)),
                  _label(WeaponLook.of(it).element?.label ?? it.rarity.label),
                ]),
            ]),
          ),
        ),
      ),
    ));
    await tester.pump();
    await _boundaryShot(tester, key, '01_inventario');
  });

  testWidgets('identidad: co-op en mapa y batalla', (tester) async {
      await loadRealFonts(tester);
      tester.view.physicalSize = _size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late GameSprites sprites;
      final hub = LoopbackHub();
      final hostNet = LoopbackNetSession(hub);
      final ps = [
        for (var i = 0; i < 4; i++)
          _withItem(i, _item(i, _elements[i], ult: i == 1 ? 'x' : null)),
      ];
      final hp = ps[0];
      await tester.runAsync(() async {
        sprites = await GameSprites.load(await SpriteCatalog.load());
        await CrtShaders.load();
        await hostNet.connect(SessionConfig(profile: hp));
      });
      await tester.pumpWidget(EcosApp(
        overrides: [
          gameSettingsProvider.overrideWith((ref) => GameSettingsController(
              store: InMemoryGameSettingsStore(),
              initial: const GameSettings())),
          sessionEngineProvider.overrideWithValue(sessionEngine()),
          profileStoreProvider.overrideWithValue(InMemoryProfileStore(hp)),
          sessionClockProvider
              .overrideWithValue(const SessionClock(autoStart: false)),
          gameSpritesProvider.overrideWith((ref) => sprites),
          activeNetSessionProvider.overrideWith((ref) => hostNet),
        ],
        home: const WorldScreen(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final host =
          ProviderScope.containerOf(tester.element(find.byType(WorldScreen)))
              .read(sessionControllerProvider.notifier);
      final clients = <SessionController>[];
      await tester.runAsync(() async {
        for (var i = 1; i < ps.length; i++) {
          final n = LoopbackNetSession(hub);
          final p = ps[i];
          await n.connect(SessionConfig(profile: p, roomCode: hostNet.roomCode));
          final c = SessionController(
            engine: sessionEngine(),
            store: InMemoryProfileStore(p),
            clock: const SessionClock(autoStart: false),
            net: n,
          );
          await c.start();
          clients.add(c);
        }
      });
      Future<void> net([double s = 0.05]) async {
        await tester.runAsync(() async {
          for (final c in clients) {
            c.advance(0.05);
          }
          await Future<void>.delayed(const Duration(milliseconds: 5));
          host.advance(s);
          await Future<void>.delayed(const Duration(milliseconds: 5));
        });
        await tester.pump(const Duration(milliseconds: 50));
      }
  
      await net();
      host.proposeMission('m1');
      await net();
      for (final c in [host, ...clients]) {
        c.vote(true);
      }
      await net(0.1);
      for (final c in [host, ...clients]) {
        c.setReady(true);
      }
      await net(0.1);
      expect(host.view!.mode, SessionMode.field);
      for (var i = 0; i < 6; i++) {
        await net();
      }
      await _shot(tester, '02_mapa_coop');
  
      await net(host.session!.graceLeft + 0.1);
      final en = host.session!.mission!.enemies
          .firstWhere((e) => e.alive && !e.boss && !e.elite);
      // ignore: invalid_use_of_visible_for_testing_member
      host.teleport(en.x, en.y);
      for (var i = 0; i < 4; i++) {
        await net();
      }
      expect(host.view!.mode, SessionMode.battle);
      for (var i = 0; i < 12; i++) {
        await net();
      }
      await _shot(tester, '03_batalla_coop');
      for (final c in clients) {
        c.dispose();
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
