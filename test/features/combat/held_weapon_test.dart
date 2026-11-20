import 'dart:convert';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/core/procedural/item_icons.dart';
import 'package:echos_del_tiempo/core/procedural/procedural_art.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/features/characters/presentation/character_widgets.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/hero_figure.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/combat/presentation/weapon_overlay.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Armas en mano (docs/specs/sprites.md § "Armas en mano").
Future<List<int>> _render(String classId, String? type) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec)..translate(16, 24);
  WeaponOverlay.draw(c, classId, type);
  final img = await rec.endRecording().toImage(32, 32);
  final data = await img.toByteData();
  img.dispose();
  return data!.buffer.asUint8List().toList();
}

void main() {
  final art = ProceduralArt.instance;
  setUp(art.reset);
  tearDown(art.reset);

  final types = {for (final w in kWeapons.values) w.type};

  test('cada tipo de arma tiene su forma y su agarre', () {
    expect(WeaponOverlay.artFor('maga', 'tomo'), WeaponArt.tome);
    expect(WeaponOverlay.artFor('tirador', 'arco'), WeaponArt.bow);
    expect(WeaponOverlay.artFor('tirador', 'rifle'), WeaponArt.gun);
    expect(WeaponOverlay.artFor('guerrero', 'hacha'), WeaponArt.axe);
    expect(WeaponOverlay.artFor('paladin', 'maza+escudo'), WeaponArt.mace);
    expect(WeaponOverlay.artFor('paladin', 'martillo+escudo'),
        WeaponArt.hammer);
    for (final t in ['espada+escudo', 'maza+escudo', 'martillo+escudo']) {
      expect(WeaponOverlay.hasShield('maga', t), isTrue, reason: t);
    }
    for (final t in types) {
      final g = WeaponOverlay.kGrips[WeaponOverlay.artFor('maga', t)]!;
      expect(kItemIconRows, contains(g.shape), reason: t);
      // La mano cae sobre una celda pintada del ícono (se ve agarrada).
      final row = kItemIconRows[g.shape]![g.gripY.floor()];
      final x = g.gripX.floor();
      expect(row[x] != '.' || row[(g.gripX + 0.5).floor().clamp(0, 7)] != '.',
          isTrue,
          reason: '$t: agarre en celda vacía');
    }
    // Sin arma conocida: la de la clase.
    expect(WeaponOverlay.artFor('maga', null), WeaponArt.staff);
    expect(WeaponOverlay.artFor('tirador', null), WeaponArt.gun);
  });

  test('cada tipo dibuja distinto y dentro de la caja del retrato',
      () async {
    final seen = <String, String>{};
    for (final t in types) {
      final px = await _render('guerrero', t);
      final key = px.join(',');
      expect(seen[key], isNull, reason: '$t repite el dibujo de ${seen[key]}');
      seen[key] = t;
      // Ningún píxel fuera de WeaponOverlay.bounds (origen en (16, 24)).
      const b = WeaponOverlay.bounds;
      for (var y = 0; y < 32; y++) {
        for (var x = 0; x < 32; x++) {
          if (px[(y * 32 + x) * 4 + 3] == 0) continue;
          final hx = x - 16 + 0.5, hy = y - 24 + 0.5;
          expect(b.inflate(0.6).contains(Offset(hx, hy)), isTrue,
              reason: '$t desborda en ($hx, $hy)');
        }
      }
    }
  });

  test('las perillas del Editor del tipo cambian el arma en mano', () async {
    final before = await _render('tirador', 'arco');
    art.setDraft('items.arco', {'handle': '#ff0000'});
    final after = await _render('tirador', 'arco');
    expect(after, isNot(before));
    // Otra entrada no toca el arco.
    art.setDraft('items.rifle', {'metal': '#ff0000'});
    expect(await _render('tirador', 'arco'), before);
  });

  test('co-op: el arma del otro jugador viaja en el snapshot', () {
    const j = SessionJson();
    for (final w in kWeapons.values) {
      final c = Combatant(
          id: 'p2',
          name: 'B',
          isPlayer: true,
          hp: 1,
          maxHp: 1,
          speed: 1,
          attack: 1,
          critChance: 0,
          classId: 'maga',
          weaponType: w.type);
      final back = j.combatantFromJson(
          asJson(jsonDecode(jsonEncode(j.combatantToJson(c)))));
      expect(back.weaponType, w.type);
      // Mapa / lobby: el perfil del otro trae el arma equipada.
      final p = PlayerProfile.fromJson(asJson(jsonDecode(jsonEncode(
          PlayerProfile(classId: 'maga', inventory: [w.id], equipped: w.id)
              .toJson()))));
      expect(kWeapons[p.equipped]?.type, w.type, reason: w.id);
    }
  });

  testWidgets('selección de personaje: retrato con el arma equipada, sin desbordes',
      (t) async {
    late GameSprites sprites;
    await t.runAsync(() async {
      sprites = await GameSprites.load(await SpriteCatalog.load());
    });
    final bow = kWeapons.values.firstWhere((w) => w.type == 'arco');
    final profile =
        PlayerProfile(classId: 'maga', inventory: [bow.id], equipped: bow.id);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: CharacterSlotCard(
            slot: CharacterSlot(id: 's1', profile: profile),
            profile: profile,
            className: 'Maga',
            selected: false,
            sprites: sprites,
            onTap: () {},
          ),
        ),
      ),
    ));
    final fig = t.widget<HeroFigure>(find.byKey(const ValueKey('char-figure-s1')));
    expect(fig.weaponType, 'arco');
    expect(fig.classId, 'maga');
    expect(t.takeException(), isNull);
  });
}
