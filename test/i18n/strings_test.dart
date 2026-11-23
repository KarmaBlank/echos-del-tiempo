import 'package:echos_del_tiempo/core/i18n/icu_formatter.dart';
import 'package:echos_del_tiempo/core/i18n/locale_id.dart';
import 'package:echos_del_tiempo/core/i18n/locale_registry.dart';
import 'package:echos_del_tiempo/core/i18n/string_tables.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// docs/specs/i18n.md § 3 (servicio Strings, ICU, fallback, idiomas ocultos).
void main() {
  group('ICU subset', () {
    String f(String m, [Map<String, Object?> a = const {}, LocaleId l = LocaleId.esAR]) =>
        IcuFormatter.format(m, l, a);

    test('argumentos simples y faltantes', () {
      expect(f('Nivel {lvl}', {'lvl': 3}), 'Nivel 3');
      expect(f('Hola {name}'), 'Hola {name}');
    });

    test('plural con # y casos exactos', () {
      const m = '{n, plural, =0{sin ecos} one{# eco} other{# ecos}}';
      expect(f(m, {'n': 0}), 'sin ecos');
      expect(f(m, {'n': 1}), '1 eco');
      expect(f(m, {'n': 1500}), '1.500 ecos');
      expect(f(m, {'n': 1500}, LocaleId.en), '1,500 ecos');
      // Chino: siempre `other`.
      expect(f('{n, plural, one{A} other{B}}', {'n': 1}, LocaleId.zhHans), 'B');
    });

    test('select y anidado', () {
      const m = '{g, select, f{Ella tiene {n, plural, one{# poción} other{# pociones}}} other{Él}}';
      expect(f(m, {'g': 'f', 'n': 2}), 'Ella tiene 2 pociones');
      expect(f(m, {'g': 'x', 'n': 2}), 'Él');
    });

    test('number y comillas', () {
      expect(f('{x, number}', {'x': 1234.5}), '1.234,5');
      expect(f('{x, number}', {'x': 1234.5}, LocaleId.en), '1,234.5');
      expect(f("it''s '{'literal'}'"), "it's {literal}");
    });

    test('argumentNames y validate', () {
      expect(IcuFormatter.argumentNames('{a} {b, plural, one{{c}} other{#}}'),
          {'a', 'b', 'c'});
      expect(() => IcuFormatter.validate('{n, plural, one{x}}'),
          throwsFormatException);
      expect(() => IcuFormatter.validate('abre { y no cierra'),
          throwsFormatException);
    });
  });

  group('fallback', () {
    final tables = StringTables(
      LocaleRegistry.parse(
          '{"locales":{"es-AR":"published","en":"published"},"domains":[]}'),
      {
        LocaleId.esAR: {
          'a': const StringEntry('uno'),
          'b': const StringEntry('dos {n}'),
        },
        LocaleId.en: {
          'a': const StringEntry('one'),
          'b': const StringEntry(''),
          'm': const StringEntry('machine', status: EntryStatus.machine),
        },
      },
    );

    test('activo → es-AR → clave', () {
      final en = tables.strings(LocaleId.en);
      expect(en.t('a'), 'one');
      expect(en.t('b', {'n': 2}), 'dos 2'); // vacío = falta
      expect(en.t('nope.key'), 'nope.key');
      expect(en.lookup('b'), isNull);
    });

    test('texto machine solo con allowMachineText', () {
      expect(tables.strings(LocaleId.en).t('m'), 'm');
      expect(tables.strings(LocaleId.en, allowMachineText: true).t('m'),
          'machine');
    });
  });

  group('idiomas publicados y ocultos (§ 3.1)', () {
    final reg = LocaleRegistry.parse('{"locales":{"es-AR":"published",'
        '"en":"published","zh-Hans":"hidden"},"domains":[]}');

    test('zh-Hans oculto no se ofrece ni se elige', () {
      expect(reg.selectable(), [LocaleId.esAR, LocaleId.en]);
      expect(reg.selectable(showHidden: true), LocaleId.values);
      expect(reg.resolve(chosen: 'zh-Hans'), LocaleId.esAR);
      expect(reg.resolve(chosen: 'zh-Hans', showHidden: true), LocaleId.zhHans);
    });

    test('Steam schinese con chino oculto → inglés', () {
      expect(reg.resolve(steamLanguage: 'schinese'), LocaleId.en);
      expect(reg.resolve(steamLanguage: 'latam'), LocaleId.esAR);
      expect(reg.resolve(steamLanguage: 'english'), LocaleId.en);
    });

    test('sistema: es_* → es-AR, desconocido → en, nada → es-AR', () {
      expect(reg.resolve(systemLocale: 'es_MX'), LocaleId.esAR);
      expect(reg.resolve(systemLocale: 'fr_FR'), LocaleId.en);
      expect(reg.resolve(systemLocale: 'zh_CN'), LocaleId.en);
      expect(reg.resolve(), LocaleId.esAR);
      expect(reg.resolve(chosen: 'en', systemLocale: 'es_AR'), LocaleId.en);
    });

    test('el locales.json del repo deja zh-Hans oculto', () {
      final t = StringTables.loadDirectorySync(StringTables.assetRoot)!;
      expect(t.registry.isPublished(LocaleId.zhHans), isFalse);
      expect(t.registry.isPublished(LocaleId.en), isTrue);
    });
  });

  test('GameSettings guarda el idioma (vacío = automático)', () {
    const d = GameSettings();
    expect(d.locale, '');
    final s = d.copyWith(locale: 'en');
    expect(GameSettings.fromJson(s.toJson()).locale, 'en');
    expect(GameSettings.fromJson(s.toJson()), s);
    expect(GameSettings.fromJson(const {'locale': 3}).locale, '');
  });
}
