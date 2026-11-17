import 'dart:io';
import 'dart:typed_data';

import 'package:echos_del_tiempo/core/audio/sfx_catalog.dart';
import 'package:echos_del_tiempo/core/audio/sfx_recipes.dart';
import 'package:echos_del_tiempo/core/audio/wav_synth.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/ult_cinematic.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:flutter_test/flutter_test.dart';

/// Muestras para escuchar: `SFX_SAMPLES_DIR=<carpeta> flutter test
/// test/core/audio/sfx_catalog_test.dart` (docs/specs/audio.md
/// § "Muestras").
const _samples = {
  'sword_attack_swing.wav': Sfx.swingBlade,
  'sword_impact_slash.wav': Sfx.impactSlash,
  'hammer_impact_blunt.wav': Sfx.impactBlunt,
  'bow_shot.wav': Sfx.shotBow,
  'rifle_shot.wav': Sfx.shotRifle,
  'crit_clink.wav': Sfx.critClink,
  'skill_bola_fireball_cast.wav': 'skill.bola',
  'impact_fire.wav': Sfx.impactFire,
  'skill_lanzaH_ice_lance_cast.wav': 'skill.lanzaH',
  'impact_ice_crystal.wav': Sfx.impactIce,
  'skill_niebla_poison_fog.wav': 'skill.niebla',
  'skill_juicio_holy_hammer.wav': 'skill.juicio',
  'skill_curaM_heal.wav': 'skill.curaM',
  'skill_provocar_taunt.wav': 'skill.provocar',
  'skill_prisa_haste.wav': 'skill.prisa',
  'skill_detener_time_stop.wav': 'skill.detener',
  'skip_freeze_shatter.wav': Sfx.skipFreeze,
  'status_stun_dizzy.wav': 'status.stun',
  'tick_burn.wav': 'tick.burn',
  'enemy_slime_squish.wav': 'enemy.slime',
  'enemy_bat_screech.wav': 'enemy.bat',
  'enemy_golem_stomp.wav': 'enemy.golem',
  'enemy_ghost_wail.wav': 'enemy.ghost',
  'enemy_devorador_boss_roar.wav': 'enemy.devorador',
  'player_hurt.wav': Sfx.impactHurt,
  'item_potion_gulp.wav': Sfx.potion,
  'ko_enemy.wav': Sfx.koEnemy,
  'revive.wav': Sfx.revive,
  // Procs del árbol.
  'proc_zip_bounce_1.wav': 'proc.zip.0',
  'proc_combustion_whump.wav': Sfx.whump,
  'proc_contraataque_clang.wav': Sfx.clang,
  'proc_castigo_divino_bell.wav': Sfx.bell,
  'proc_eco_arcano_bola_echo.wav': 'echo.bola',
  'proc_frenesi_whoosh.wav': Sfx.frenzyWhoosh,
  'proc_represalia_flare.wav': Sfx.flare,
  'proc_marca_cazador_lock.wav': Sfx.mark,
  'proc_debilitar_weaken.wav': Sfx.weaken,
  'proc_shield_up.wav': Sfx.shieldUp,
  'proc_shield_break.wav': Sfx.shieldBreak,
  'proc_danza_extra_turn.wav': Sfx.extraTurn,
  'proc_sed_sangre_heartbeat.wav': Sfx.heartbeat,
  'proc_plaga_contagiosa.wav': Sfx.plague,
  'proc_choque_termico_steam.wav': Sfx.steam,
  'proc_guardian_ult_charge.wav': Sfx.ultCharge,
  'proc_martillo_bendito_anvil.wav': Sfx.anvil,
  'proc_viento_favor_wind.wav': Sfx.wind,
};

/// Secuencias de procs en sus tiempos (ms), para escuchar el ritmo.
const _procSequences = {
  // Cadena Infinita: tres saltos a 130 ms.
  'proc_chain_3_hops.wav': [('proc.zip.0', 0), ('proc.zip.1', 130), ('proc.zip.2', 260)],
  // Golpe con escudo: impacto + vidrio que se quiebra.
  'proc_shield_absorb_hit.wav': [(Sfx.impactHurt, 0), (Sfx.shieldBreak, 0)],
  // Combustión: impacto de fuego, estallido 120 ms después.
  'proc_combustion_full.wav': [(Sfx.impactFire, 0), (Sfx.whump, 120)],
};

void main() {
  const synth = WavSynth();

  test('procs del árbol: cada sonido existe, suena y no recorta', () {
    final ids = [
      for (var h = 0; h <= Sfx.maxZip; h++) Sfx.zip(h),
      Sfx.whump, Sfx.clang, Sfx.bell, Sfx.frenzyWhoosh, Sfx.flare, //
      Sfx.mark, Sfx.weaken, Sfx.shieldUp, Sfx.shieldBreak, Sfx.extraTurn,
      Sfx.heartbeat, Sfx.plague, Sfx.steam, Sfx.ultCharge, Sfx.anvil,
      Sfx.wind,
    ];
    for (final id in ids) {
      final def = kSfxCatalog[id];
      expect(def, isNotNull, reason: id);
      expect(def!.length, inInclusiveRange(0.05, 1.0), reason: id);
      final s = synth.samplesOf(def);
      final peak = s.fold<double>(0, (m, x) => x.abs() > m ? x.abs() : m);
      expect(peak, closeTo(def.peak!, 1e-6), reason: id);
    }
    // Los zips suben con cada salto.
    double f(int h) => kSfxCatalog[Sfx.zip(h)]!.voices.first.frequency;
    expect(f(0) < f(1) && f(1) < f(2), isTrue);
    // Eco Arcano: cada firma tiene su eco, más bajo que la firma.
    for (final id in kSkillVoices.keys) {
      final echo = kSfxCatalog[Sfx.echo(id)];
      expect(echo, isNotNull, reason: id);
      expect(echo!.peak!, lessThan(kSfxCatalog[Sfx.skill(id)]!.peak!));
      expect(echo.length, greaterThan(kSfxCatalog[Sfx.skill(id)]!.length));
    }
  });

  test('cada habilidad de kSkills tiene su firma', () {
    for (final id in kSkills.keys) {
      expect(kSfxCatalog, contains(Sfx.skill(id)), reason: id);
    }
    // Y no hay firmas de habilidades que no existen.
    for (final id in kSkillVoices.keys) {
      expect(kSkills, contains(id), reason: id);
    }
  });

  test('las firmas de habilidad son todas distintas', () {
    final seen = <String, String>{};
    for (final id in kSkills.keys) {
      final bytes = synth.renderDef(kSfxCatalog[Sfx.skill(id)]!);
      final key = String.fromCharCodes(bytes.sublist(WavSynth.headerBytes));
      expect(seen[key], isNull, reason: '$id suena igual que ${seen[key]}');
      seen[key] = id;
    }
  });

  test('cada tipo de enemigo tiene su sonido', () {
    for (final type in kEnemies.keys) {
      expect(kSfxCatalog, contains(Sfx.enemy(type)), reason: type);
    }
    expect(kSfxCatalog, contains(Sfx.enemyGeneric));
    expect(kSfxCatalog, contains(Sfx.enemyHeavy));
  });

  test('cada tipo de arma tiene arranque e impacto', () {
    for (final w in kWeapons.values) {
      expect(kSfxCatalog, contains(kWeaponStartSfx[w.type]), reason: w.type);
      expect(kSfxCatalog, contains(kWeaponImpactSfx[w.type]), reason: w.type);
    }
  });

  test('cada estado tiene sonido al aplicarse; los de daño/cura por turno, '
      'su tic', () {
    for (final k in StatusKind.values) {
      expect(kSfxCatalog, contains(Sfx.status(k.name)), reason: k.name);
    }
    for (final k in [
      StatusKind.burn,
      StatusKind.poison,
      StatusKind.holy,
      StatusKind.regen,
    ]) {
      expect(kSfxCatalog, contains(Sfx.tick(k.name)), reason: k.name);
    }
  });

  test('niveles: ningún sonido recorta, todos normalizados a su pico, '
      'cortos y deterministas', () {
    for (final e in kSfxCatalog.entries) {
      final def = e.value;
      expect(def.peak, isNotNull, reason: e.key);
      // Solo las partes de las ULT pasan el nivel del crítico.
      expect(def.peak!,
          lessThanOrEqualTo(
              e.key.startsWith('ult_') ? SfxLevel.ultImpact : SfxLevel.crit),
          reason: e.key);
      final s = synth.samplesOf(def);
      var peak = 0.0;
      for (final x in s) {
        if (x.abs() > peak) peak = x.abs();
      }
      expect(peak, closeTo(def.peak!, 1e-9), reason: e.key);
      expect(def.length, lessThanOrEqualTo(1.8), reason: e.key);
      expect(synth.samplesOf(def), s, reason: e.key);
    }
  });

  test('el clink del crítico se oye encima del impacto y es agudo y corto',
      () {
    final clink = kSfxCatalog[Sfx.critClink]!;
    expect(clink.peak!, greaterThan(kSfxCatalog[Sfx.impactSlash]!.peak!));
    expect(clink.length, lessThan(0.3));
    // Dos parciales agudos inarmónicos.
    final tonal = clink.voices.where((v) => v.wave != Waveform.noise).toList();
    expect(tonal.first.frequency, greaterThan(1500));
    final ratio = tonal[1].frequency / tonal[0].frequency;
    expect((ratio - ratio.round()).abs(), greaterThan(0.2));
    // Leve descenso de altura y ataque rápido.
    for (final v in tonal) {
      expect(v.endFrequency!, lessThan(v.frequency));
      expect(v.attack, lessThan(0.005));
    }
  });

  test('ULT: cada una tiene preparación, descarga e impacto propios, '
      'que entran en sus fases', () {
    for (final sk in kUltimates.values) {
      final script = ultScriptFor(sk.id);
      expect(kUltScripts, contains(sk.id));
      final build = kSfxCatalog[Sfx.ult(sk.id, Sfx.ultBuild)];
      final release = kSfxCatalog[Sfx.ult(sk.id, Sfx.ultRelease)];
      final impact = kSfxCatalog[Sfx.ult(sk.id, Sfx.ultImpact)];
      expect([build, release, impact], everyElement(isNotNull), reason: sk.id);
      // La preparación termina con la descarga (un resto de 0.15 s).
      expect(build!.length, lessThanOrEqualTo(script.buildMs / 1000 + 0.15),
          reason: sk.id);
      // La descarga no pasa del regreso.
      expect(release!.length, lessThanOrEqualTo(script.releaseMs / 1000),
          reason: sk.id);
      expect(impact!.peak, SfxLevel.ultImpact);
      expect(impact.peak!, greaterThan(kSfxCatalog[Sfx.impactBlunt]!.peak!));
    }
    // Todas distintas entre sí.
    for (final part in Sfx.ultParts) {
      final voices = {
        for (final sk in kUltimates.values)
          kSfxCatalog[Sfx.ult(sk.id, part)]!
              .voices
              .map((v) => '${v.wave}:${v.frequency}:${v.duration}:${v.delay}')
              .join(','),
      };
      expect(voices, hasLength(kUltimates.length), reason: part);
    }
  });

  test('ULT: se conserva el beep del prototipo', () {
    expect(kSfxCatalog[Sfx.ultimate]!.voices, kLegacyTones[Sfx.ultimate]);
  });

  test('muestras WAV (sólo con SFX_SAMPLES_DIR)', () {
    final dir = Platform.environment['SFX_SAMPLES_DIR'];
    for (final id in _samples.values) {
      expect(kSfxCatalog, contains(id), reason: id);
    }
    if (dir == null || dir.isEmpty) return;
    Directory(dir).createSync(recursive: true);
    for (final e in _samples.entries) {
      File('$dir${Platform.pathSeparator}${e.key}')
          .writeAsBytesSync(synth.renderDef(kSfxCatalog[e.value]!));
    }
    // Secuencias de procs, mezcladas en sus tiempos.
    for (final e in _procSequences.entries) {
      final layers = [
        for (final (id, at) in e.value)
          (synth.samplesOf(kSfxCatalog[id]!), (at / 1000 * synth.sampleRate).round()),
      ];
      final n = layers.fold<int>(
          0, (m, l) => l.$2 + l.$1.length > m ? l.$2 + l.$1.length : m);
      final mix = Float64List(n);
      for (final (s, o) in layers) {
        for (var i = 0; i < s.length; i++) {
          mix[o + i] += s[i];
        }
      }
      for (var i = 0; i < n; i++) {
        mix[i] = mix[i].clamp(-1.0, 1.0);
      }
      File('$dir${Platform.pathSeparator}${e.key}')
          .writeAsBytesSync(synth.encode(mix));
    }
    // Cada ULT completa: preparación + descarga + impactos en 3 objetivos.
    for (final sk in kUltimates.values) {
      final script = ultScriptFor(sk.id);
      final parts = [
        (Sfx.ult(sk.id, Sfx.ultBuild), 0),
        (Sfx.ult(sk.id, Sfx.ultRelease), script.buildMs),
        for (var i = 0; i < (sk.allTargets ? 3 : 1); i++)
          (Sfx.ult(sk.id, Sfx.ultImpact), script.impactFor(i)),
      ];
      final layers = [
        for (final (id, at) in parts) (synth.samplesOf(kSfxCatalog[id]!), at),
      ];
      final n = layers.fold<int>(0, (m, l) {
        final end = (l.$2 / 1000 * synth.sampleRate).round() + l.$1.length;
        return end > m ? end : m;
      });
      final mix = Float64List(n);
      for (final (s, at) in layers) {
        final o = (at / 1000 * synth.sampleRate).round();
        for (var i = 0; i < s.length; i++) {
          mix[o + i] += s[i];
        }
      }
      for (var i = 0; i < n; i++) {
        mix[i] = mix[i].clamp(-1.0, 1.0);
      }
      final name = sk.name
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll('á', 'a')
          .replaceAll('é', 'e')
          .replaceAll('í', 'i')
          .replaceAll('ó', 'o')
          .replaceAll('ú', 'u');
      File('$dir${Platform.pathSeparator}ult_$name.wav')
          .writeAsBytesSync(synth.encode(mix));
    }
  });
}
