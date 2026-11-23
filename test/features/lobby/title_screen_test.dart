import 'dart:async';

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/features/characters/domain/stash.dart';
import 'package:echos_del_tiempo/features/characters/presentation/characters_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/lobby/presentation/title_screen.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../inventory/loot_fixtures.dart';
import '../../app/button_look.dart';
import '../../app/square_ui_audit.dart';
import 'title_flow.dart';

final _rules = CharacterRules(progression);

/// Cuenta con Ana (maga 12), Bo (tirador) y Cid (paladín), Bo elegido.
Account threeCharacters() {
  var a = _rules.create(Account(), 'Ana', 'maga', now: DateTime(2026, 11, 1))!;
  a = _rules.create(a, 'Bo', 'tirador')!;
  a = _rules.create(a, 'Cid', 'paladin')!;
  a = a.replace(
      'c1', progression.normalize(a.byId('c1')!.profile.copyWith(level: 12)),
      lastPlayed: DateTime(2026, 11, 16));
  return a.select('c2');
}

Future<void> _pumpTitle(
  WidgetTester tester, {
  required AccountRepository repo,
  ProfileStore? store,
  VoidCallback? onStart,
}) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionEngineProvider.overrideWithValue(sessionEngine()),
      profileStoreProvider
          .overrideWithValue(store ?? SelectedCharacterProfileStore(repo)),
      accountRepositoryProvider.overrideWithValue(repo),
      // Sin sprites (las tarjetas se dibujan igual).
      gameSpritesProvider
          .overrideWith((ref) => Completer<GameSprites>().future),
    ],
    child: MaterialApp(
      theme: RetroTheme.build(),
      home: TitleScreen(onStart: onStart ?? () {}),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String key) async {
  // El alijo scrollea: la fila de acciones arriba empuja las pilas.
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.pump();
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pump();
  await tester.pump();
}

VoidCallback? _onPressed(WidgetTester tester, String key) => tester
    .widget<ElevatedButton>(find
        .descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(ElevatedButton))
        .first)
    .onPressed;

void main() {
  testWidgets('notas del parche: NUEVO hasta abrirlas, y queda guardado',
      (tester) async {
    final repo = AccountRepository(InMemoryAccountStore(threeCharacters()));
    await _pumpTitle(tester, repo: repo);
    // El índice de notas sale del AssetManifest (IO real del bundle).
    await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 200)));
    await tester.pump();
    expect(find.text('NUEVO'), findsOneWidget);

    final ctx = tester.element(find.byType(TitleScreen));
    await tester.tap(find.text('VER NOTAS DEL PARCHE'));
    await tester.pump();
    final seen = ProviderScope.containerOf(ctx)
        .read(gameSettingsProvider)
        .seenPatchNotes;
    expect(seen, isNotEmpty);
    await tester.tapAt(const Offset(4, 4)); // cierra el panel
    await tester.pumpAndSettle();
    expect(find.text('NUEVO'), findsNothing);
  });

  testWidgets('cuenta vacía: el creador arma el primer personaje y juega',
      (tester) async {
    final mem = InMemoryAccountStore();
    final repo = AccountRepository(mem);
    final store = InMemoryProfileStore();
    var started = 0;
    await _pumpTitle(tester,
        repo: repo, store: store, onStart: () => started++);
    expect(roundedUi(tester), isEmpty, reason: 'regla pixel: sin redondeos');
    expect(find.text('ECOS DEL TIEMPO'), findsOneWidget);
    expect(find.byKey(const ValueKey('title-settings')), findsOneWidget);
    expectButtonLook(tester, find.byKey(const ValueKey('title-settings')));
    await goToSoloCharacters(tester);
    expect(roundedUi(tester), isEmpty, reason: 'regla pixel: sin redondeos');
    expect(find.text('CREÁ TU PRIMER PERSONAJE'), findsOneWidget);
    expect(find.byKey(const ValueKey('char-create-cancel')), findsNothing);
    expectButtonLook(tester, find.byKey(const ValueKey('char-create-confirm')));

    await tester.enterText(
        find.byKey(const ValueKey('title-name')), 'Anastasia Larga');
    await tester.tap(find.byKey(const ValueKey('class-card-maga')));
    await tester.pump();
    await _tap(tester, 'char-create-confirm');

    // Vuelve a la lista con el personaje creado y elegido.
    expect(find.byKey(const ValueKey('char-slot-c1')), findsOneWidget);
    expect(find.text('Anastasia'), findsOneWidget);
    expect(find.text('Maga · Nv 1'), findsOneWidget);
    expect(find.text('Nunca jugado'), findsOneWidget);
    final saved = (await mem.load()).account.selected!.profile;
    expect(saved.name, 'Anastasia');
    expect(saved.classId, 'maga');
    expect(saved.equipped, 'baculo_aprendiz');
    expect(progression.normalize(saved).classId, 'maga');

    await _tap(tester, 'char-play');
    expect(started, 1);
    // La sesión recibe el personaje elegido.
    expect((await store.load())!.name, 'Anastasia');
    expect((await mem.load()).account.selected!.lastPlayed, isNotNull);
  });

  testWidgets('lista: elegir, crear otro, renombrar y jugar con el elegido',
      (tester) async {
    final mem = InMemoryAccountStore(threeCharacters());
    final repo = AccountRepository(mem);
    var started = 0;
    await _pumpTitle(tester, repo: repo, onStart: () => started++);
    await goToSoloCharacters(tester);
    expect(find.text('PERSONAJES (3/8)'), findsOneWidget);
    for (final n in ['Ana', 'Bo', 'Cid']) {
      expect(find.text(n), findsOneWidget, reason: n);
    }
    expect(find.text('Maga · Nv 12'), findsOneWidget);
    expect(find.text('Jugado: 16/11/26'), findsOneWidget);
    expect(find.byKey(const ValueKey('char-new')), findsOneWidget);

    await _tap(tester, 'char-slot-c3');
    expect((await mem.load()).account.selectedId, 'c3');

    // Crear otro desde la lista; CANCELAR vuelve sin crear.
    await _tap(tester, 'char-create');
    expect(find.text('CREAR PERSONAJE'), findsWidgets);
    await _tap(tester, 'char-create-cancel');
    expect(find.text('PERSONAJES (3/8)'), findsOneWidget);
    await _tap(tester, 'char-new');
    await tester.enterText(find.byKey(const ValueKey('title-name')), 'Dana');
    await tester.tap(find.byKey(const ValueKey('class-card-guerrero')));
    await _tap(tester, 'char-create-confirm');
    expect(find.text('PERSONAJES (4/8)'), findsOneWidget);
    expect((await mem.load()).account.selected!.profile.name, 'Dana');

    // Renombrar al elegido (Ana quedó fuera del carrusel: flechas).
    for (var i = 0; i < 3; i++) {
      await _tap(tester, 'carousel-prev');
    }
    expect((await mem.load()).account.selectedId, 'c1');
    await _tap(tester, 'char-rename');
    expect(find.byKey(const ValueKey('char-rename-dialog')), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('char-rename-field')), 'Anita');
    await _tap(tester, 'char-rename-ok');
    await tester.pumpAndSettle();
    expect(find.text('Anita'), findsOneWidget);
    expect((await mem.load()).account.byId('c1')!.profile.name, 'Anita');
    expect((await mem.load()).account.byId('c1')!.profile.level, 12);

    // Doble clic en la tarjeta = jugar con ese.
    await tester.tap(find.byKey(const ValueKey('char-slot-c2')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const ValueKey('char-slot-c2')));
    await tester.pump();
    await tester.pump();
    expect(started, 1);
    final a = (await mem.load()).account;
    expect(a.selectedId, 'c2');
    expect(a.byId('c2')!.lastPlayed, isNotNull);
  });

  testWidgets('borrar pide escribir el nombre', (tester) async {
    final mem = InMemoryAccountStore(threeCharacters());
    final repo = AccountRepository(mem);
    await _pumpTitle(tester, repo: repo);
    await goToSoloCharacters(tester);

    await _tap(tester, 'char-delete');
    expect(find.byKey(const ValueKey('char-delete-dialog')), findsOneWidget);
    expect(find.textContaining('pásalo antes al ALIJO'), findsOneWidget);
    expect(_onPressed(tester, 'char-delete-ok'), isNull);
    await tester.enterText(
        find.byKey(const ValueKey('char-delete-field')), 'B');
    await tester.pump();
    expect(_onPressed(tester, 'char-delete-ok'), isNull);
    // Cancelar no borra.
    await _tap(tester, 'char-delete-cancel');
    await tester.pumpAndSettle();
    expect((await mem.load()).account.characters.length, 3);

    await _tap(tester, 'char-delete');
    await tester.enterText(
        find.byKey(const ValueKey('char-delete-field')), ' bo ');
    await tester.pump();
    expect(_onPressed(tester, 'char-delete-ok'), isNotNull);
    await _tap(tester, 'char-delete-ok');
    await tester.pumpAndSettle();
    final a = (await mem.load()).account;
    expect(a.characters.map((c) => c.profile.name), ['Ana', 'Cid']);
    expect(a.selectedId, 'c1');
    expect(find.text('Bo'), findsNothing);
    expect(find.textContaining('fue borrado'), findsOneWidget);
  });

  testWidgets('borrar el último abre el creador', (tester) async {
    final mem = InMemoryAccountStore(_rules.create(Account(), 'Solo', 'maga'));
    await _pumpTitle(tester, repo: AccountRepository(mem));
    await goToSoloCharacters(tester);
    await _tap(tester, 'char-delete');
    await tester.enterText(
        find.byKey(const ValueKey('char-delete-field')), 'solo');
    await tester.pump();
    await _tap(tester, 'char-delete-ok');
    await tester.pumpAndSettle();
    expect(find.text('CREÁ TU PRIMER PERSONAJE'), findsOneWidget);
    expect((await mem.load()).account.characters, isEmpty);
  });

  testWidgets('cuenta llena: CREAR PERSONAJE deshabilitado con motivo',
      (tester) async {
    var a = Account();
    for (var i = 0; i < Account.maxCharacters; i++) {
      a = _rules.create(a, 'P$i', 'guerrero')!;
    }
    await _pumpTitle(tester, repo: AccountRepository(InMemoryAccountStore(a)));
    await goToSoloCharacters(tester);
    expect(find.text('PERSONAJES (8/8)'), findsOneWidget);
    expect(find.byKey(const ValueKey('char-new')), findsNothing);
    // El motivo va al tooltip del botón (design_system.md § 2).
    expect(find.byTooltip('Máximo 8 personajes'), findsOneWidget);
    expect(
        tester
            .widget<DsButton>(find.byKey(const ValueKey('char-create')))
            .onPressed,
        isNull);
  });

  testWidgets('archivo dañado: el aviso se ve en rojo', (tester) async {
    final repo = AccountRepository(InMemoryAccountStore());
    await repo.load();
    repo.notice = 'No se pudo leer la cuenta (archivo dañado). Se guardó '
        'una copia en account.corrupt-x.json y se empezó una cuenta nueva.';
    await _pumpTitle(tester, repo: repo);
    expect(find.byKey(const ValueKey('title-account-notice')), findsOneWidget);
    expect(find.textContaining('account.corrupt-x.json'), findsOneWidget);
  });

  testWidgets('alijo: guardar y sacar con validación y persistencia',
      (tester) async {
    var a = threeCharacters();
    // Bo (tirador) con un épico y 40 cristales; el alijo con un raro y
    // 200 prismas.
    var bo = InventoryRules.addItem(a.byId('c2')!.profile, epicSword).$1;
    bo = bo.copyWith(materials: {CraftMaterial.cristal: 40});
    a = a.replace('c2', InventoryRules.relayout(bo)).withStash(Stash.empty()
        .put(0, const StashEntry.item(rareAxe))
        .put(1, const StashEntry.material(CraftMaterial.prisma, 200)));
    final mem = InMemoryAccountStore(a);
    final repo = AccountRepository(mem);
    await _pumpTitle(tester, repo: repo);
    await goToSoloCharacters(tester);

    await _tap(tester, 'char-stash');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stash-screen')), findsOneWidget);
    expect(find.text('ALIJO COMPARTIDO'), findsOneWidget);
    expect(find.text('2/144'), findsOneWidget);

    // La equipada no se puede guardar.
    await _tap(tester, 'stash-char-equipped');
    expect(find.text('Equipada'), findsOneWidget);

    // El épico (casilla 0 del personaje: no equipado) va al alijo.
    final p0 = (await mem.load()).account.byId('c2')!.profile;
    final grid = InventoryRules.layout(progression.normalize(p0)).cells;
    final epicCell = grid.indexWhere(
        (t) => t != null && p0.itemByUid(t)?.baseId == 'espada_ignea');
    final starterCell = grid.indexWhere((t) => t == 'arco_corto');
    expect(starterCell, -1, reason: 'la inicial está equipada');
    await _tap(tester, 'stash-char-$epicCell');
    await _tap(tester, 'stash-deposit');
    await tester.pump();
    var saved = (await mem.load()).account;
    expect(
        saved.byId('c2')!.profile.items.any((i) => i.baseId == 'espada_ignea'),
        isFalse);
    expect(saved.stash.cells[2]!.item!.name, 'Filo del Alba');
    expect(find.text('3/144'), findsOneWidget);

    // Las pociones no van (v0.5.1: pilas en su sección, no en la grilla).
    await _tap(tester, 'inv-stack-pot');
    expect(find.text('Las pociones no van al alijo'), findsOneWidget);

    // Los cristales se guardan con doble clic.
    await tester.tap(find.byKey(const ValueKey('inv-stack-mat:cristal')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const ValueKey('inv-stack-mat:cristal')));
    await tester.pump();
    await tester.pump();
    saved = (await mem.load()).account;
    expect(saved.byId('c2')!.profile.material(CraftMaterial.cristal), 0);
    expect(saved.stash.cells[saved.stash.cellOf(CraftMaterial.cristal)!]!.count,
        40);

    // Sacar el raro y 99 de los 200 prismas.
    await _tap(tester, 'stash-cell-0');
    await _tap(tester, 'stash-withdraw');
    await _tap(tester, 'stash-cell-1');
    await _tap(tester, 'stash-withdraw');
    await tester.pump();
    saved = (await mem.load()).account;
    final bo2 = saved.byId('c2')!.profile;
    expect(bo2.items.any((i) => i.name == 'Eco Voraz'), isTrue);
    expect(bo2.material(CraftMaterial.prisma), 99);
    expect(saved.stash.cells[0], isNull);
    expect(saved.stash.cells[1]!.count, 101);
    // Otro personaje ve el mismo alijo.
    expect(saved.byId('c1')!.profile.items.length, 1);

    // Segunda pestaña.
    await _tap(tester, 'tab-1');
    expect(find.byKey(const ValueKey('stash-cell-48')), findsOneWidget);
    expect(find.byKey(const ValueKey('stash-cell-0')), findsNothing);

    await _tap(tester, 'stash-close');
    await tester.pumpAndSettle();
    expect(find.text('PERSONAJES (3/8)'), findsOneWidget);
  });
}
