import 'dart:io';

import 'package:echos_del_tiempo/core/audio/sfx_catalog.dart';
import 'package:echos_del_tiempo/core/audio/sfx_recipes.dart';
import 'package:echos_del_tiempo/core/audio/wav_synth.dart';
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
};

void main() {
  const synth = WavSynth();

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
      expect(def.peak!, lessThanOrEqualTo(SfxLevel.crit), reason: e.key);
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
  });
}
