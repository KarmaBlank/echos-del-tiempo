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
  // Enemigos (wind-up + golpe) y su impacto propio.
  'enemy_slime_attack.wav': 'enemy.slime',
  'enemy_bat_attack.wav': 'enemy.bat',
  'enemy_golem_attack.wav': 'enemy.golem',
  'enemy_ghost_attack.wav': 'enemy.ghost',
  'enemy_reyLimo_attack.wav': 'enemy.reyLimo',
  'enemy_golemReloj_attack.wav': 'enemy.golemReloj',
  'enemy_devorador_attack.wav': 'enemy.devorador',
  'enemy_slime_hit.wav': 'enemy.hit.slime',
  'enemy_bat_hit.wav': 'enemy.hit.bat',
  'enemy_golem_hit.wav': 'enemy.hit.golem',
  'enemy_ghost_hit.wav': 'enemy.hit.ghost',
  'enemy_reyLimo_hit.wav': 'enemy.hit.reyLimo',
  'enemy_golemReloj_hit.wav': 'enemy.hit.golemReloj',
  'enemy_devorador_hit.wav': 'enemy.hit.devorador',
  'enemy_heavy.wav': Sfx.enemyHeavy,
  // Armas de loot v2 y loot en el mapa.
  'spear_attack_thrust.wav': Sfx.swingSpear,
  'spear_impact_pierce.wav': Sfx.impactPierce,
  'daggers_attack_swish.wav': Sfx.swingDaggers,
  'daggers_impact.wav': Sfx.impactDagger,
  'wand_shot.wav': Sfx.shotWand,
  'wand_impact.wav': Sfx.impactWand,
  'crossbow_shot.wav': Sfx.shotCrossbow,
  'crossbow_impact_bolt.wav': Sfx.impactBolt,
  'loot_alerta.wav': 'loot.alerta',
  'loot_campana.wav': 'loot.campana',
  'loot_gema.wav': 'loot.gema',
  'loot_legendario.wav': 'loot.legendario',
  'loot_material.wav': 'loot.material',
  'loot_suave.wav': 'loot.suave',
  'loot_pickup.wav': Sfx.lootPickup,
  'loot_legendary_beam.wav': Sfx.lootBeam,
  // Quiebre y aviso.
  'break_tick.wav': Sfx.breakTick,
  'break_shatter.wav': Sfx.breakShatter,
  'break_vulnerable_hit_accent.wav': Sfx.breakVuln,
  'break_dazed_skip.wav': Sfx.breakDazed,
  'enemy_ult_warning_sting.wav': Sfx.enemyUltWarn,
  // v0.2: enemigos nuevos (wind-up + golpe, impacto) y mecánicas de jefe.
  'v02_enemy_arana.wav': 'enemy.arana',
  'v02_hit_arana.wav': 'enemy.hit.arana',
  'v02_enemy_lobo.wav': 'enemy.lobo',
  'v02_hit_lobo.wav': 'enemy.hit.lobo',
  'v02_enemy_murcielagoHielo.wav': 'enemy.murcielagoHielo',
  'v02_hit_murcielagoHielo.wav': 'enemy.hit.murcielagoHielo',
  'v02_enemy_elementalEscarcha.wav': 'enemy.elementalEscarcha',
  'v02_hit_elementalEscarcha.wav': 'enemy.hit.elementalEscarcha',
  'v02_enemy_esqueleto.wav': 'enemy.esqueleto',
  'v02_hit_esqueleto.wav': 'enemy.hit.esqueleto',
  'v02_enemy_caballeroCaido.wav': 'enemy.caballeroCaido',
  'v02_hit_caballeroCaido.wav': 'enemy.hit.caballeroCaido',
  'v02_enemy_matriarca.wav': 'enemy.matriarca',
  'v02_hit_matriarca.wav': 'enemy.hit.matriarca',
  'v02_enemy_sierpe.wav': 'enemy.sierpe',
  'v02_hit_sierpe.wav': 'enemy.hit.sierpe',
  'v02_enemy_caballeroHueco.wav': 'enemy.caballeroHueco',
  'v02_hit_caballeroHueco.wav': 'enemy.hit.caballeroHueco',
  'v02_boss_intro.wav': Sfx.bossIntro,
  'v02_boss_web.wav': Sfx.webCast,
  'v02_boss_web_free.wav': Sfx.webFree,
  'v02_boss_web_stuck.wav': Sfx.webStuck,
  'v02_boss_frost.wav': Sfx.frost,
  'v02_boss_thaw.wav': Sfx.thaw,
  'v02_boss_crystal_break.wav': Sfx.crystalBreak,
  'v02_boss_crystal_reform.wav': Sfx.crystalReform,
  'v02_boss_stance.wav': Sfx.stanceShift,
  'v02_boss_block.wav': Sfx.stanceBlock,
  // v0.3: enemigos de las zonas 6–10 y mecánicas de sus jefes.
  'v03_enemy_ecoSombra.wav': 'enemy.ecoSombra',
  'v03_hit_ecoSombra.wav': 'enemy.hit.ecoSombra',
  'v03_enemy_guardianReloj.wav': 'enemy.guardianReloj',
  'v03_hit_guardianReloj.wav': 'enemy.hit.guardianReloj',
  'v03_enemy_hechicera.wav': 'enemy.hechicera',
  'v03_hit_hechicera.wav': 'enemy.hit.hechicera',
  'v03_enemy_ecoHechicera.wav': 'enemy.ecoHechicera',
  'v03_hit_ecoHechicera.wav': 'enemy.hit.ecoHechicera',
  'v03_enemy_salamandra.wav': 'enemy.salamandra',
  'v03_hit_salamandra.wav': 'enemy.hit.salamandra',
  'v03_enemy_golemMagma.wav': 'enemy.golemMagma',
  'v03_hit_golemMagma.wav': 'enemy.hit.golemMagma',
  'v03_enemy_bestiaMagma.wav': 'enemy.bestiaMagma',
  'v03_hit_bestiaMagma.wav': 'enemy.hit.bestiaMagma',
  'v03_enemy_necrofago.wav': 'enemy.necrofago',
  'v03_hit_necrofago.wav': 'enemy.hit.necrofago',
  'v03_enemy_almaErrante.wav': 'enemy.almaErrante',
  'v03_hit_almaErrante.wav': 'enemy.hit.almaErrante',
  'v03_enemy_espectroCoronado.wav': 'enemy.espectroCoronado',
  'v03_hit_espectroCoronado.wav': 'enemy.hit.espectroCoronado',
  'v03_enemy_siervoEspectral.wav': 'enemy.siervoEspectral',
  'v03_hit_siervoEspectral.wav': 'enemy.hit.siervoEspectral',
  'v03_enemy_vigilanteVacio.wav': 'enemy.vigilanteVacio',
  'v03_hit_vigilanteVacio.wav': 'enemy.hit.vigilanteVacio',
  'v03_enemy_ojoAbismo.wav': 'enemy.ojoAbismo',
  'v03_hit_ojoAbismo.wav': 'enemy.hit.ojoAbismo',
  'v03_enemy_centinela.wav': 'enemy.centinela',
  'v03_hit_centinela.wav': 'enemy.hit.centinela',
  'v03_enemy_heraldoEras.wav': 'enemy.heraldoEras',
  'v03_hit_heraldoEras.wav': 'enemy.hit.heraldoEras',
  'v03_enemy_fragmentoTiempo.wav': 'enemy.fragmentoTiempo',
  'v03_hit_fragmentoTiempo.wav': 'enemy.hit.fragmentoTiempo',
  'v03_boss_echo_summon.wav': Sfx.echoSummon,
  'v03_boss_echo_hit.wav': Sfx.echoResist,
  'v03_boss_lava_rise.wav': Sfx.lavaRise,
  'v03_boss_lava_burn.wav': Sfx.lavaBurn,
  'v03_boss_lava_fade.wav': Sfx.lavaFade,
  'v03_boss_summon.wav': Sfx.summon,
  'v03_boss_immune.wav': Sfx.immune,
  'v03_boss_mark_cast.wav': Sfx.markCast,
  'v03_boss_mark_hit.wav': Sfx.markHit,
  'v03_boss_mark_guard.wav': Sfx.markGuard,
  'v03_boss_phase_shift.wav': Sfx.phaseShift,
  'v03_boss_evade.wav': Sfx.evade,
};

/// Secuencias de procs en sus tiempos (ms), para escuchar el ritmo.
const _procSequences = {
  // Cadena Infinita: tres saltos a 130 ms.
  'proc_chain_3_hops.wav': [('proc.zip.0', 0), ('proc.zip.1', 130), ('proc.zip.2', 260)],
  // Golpe con escudo: impacto + vidrio que se quiebra.
  'proc_shield_absorb_hit.wav': [(Sfx.impactHurt, 0), (Sfx.shieldBreak, 0)],
  // Combustión: impacto de fuego, estallido 120 ms después.
  'proc_combustion_full.wav': [(Sfx.impactFire, 0), (Sfx.whump, 120)],
  // Ataque enemigo completo: wind-up + golpe y su impacto a 160 ms.
  'enemy_golem_full.wav': [('enemy.golem', 0), ('enemy.hit.golem', 160)],
  'enemy_slime_full.wav': [('enemy.slime', 0), ('enemy.hit.slime', 160)],
  'enemy_bat_full.wav': [('enemy.bat', 0), ('enemy.hit.bat', 160)],
  'enemy_devorador_full.wav': [('enemy.devorador', 0), ('enemy.hit.devorador', 160)],
  // Un golpe que quiebra: impacto, tic y cristal.
  'break_full_hit.wav': [(Sfx.impactBlunt, 0), (Sfx.breakShatter, 0)],
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

  test('enemigos: wind-up antes del golpe, impacto propio por tipo y más '
      'fuertes que las acciones del grupo', () {
    final hits = <String>{};
    for (final type in kEnemies.keys) {
      final def = kSfxCatalog[Sfx.enemy(type)]!;
      // Voces del wind-up antes del golpe y la voz del ataque después.
      expect(def.voices.any((v) => v.delay < kEnemyBodyAt && v.end <= 0.2),
          isTrue, reason: type);
      expect(def.voices.any((v) => v.delay >= kEnemyBodyAt), isTrue, reason: type);
      expect(def.peak!, greaterThan(SfxLevel.action), reason: type);
      final hit = kSfxCatalog[Sfx.enemyHit(type)];
      expect(hit, isNotNull, reason: type);
      expect(hit!.peak!, greaterThan(SfxLevel.impact), reason: type);
      hits.add(hit.voices
          .map((v) => '${v.wave}:${v.frequency}:${v.duration}:${v.delay}')
          .join(','));
    }
    expect(hits, hasLength(kEnemies.length), reason: 'impactos distintos');
    // Los jefes, más que los comunes.
    expect(kSfxCatalog[Sfx.enemy('devorador')]!.peak!,
        greaterThan(kSfxCatalog[Sfx.enemy('slime')]!.peak!));
  });

  test('quiebre: tic sutil, cristal fuerte, acento y aviso', () {
    final tick = kSfxCatalog[Sfx.breakTick]!;
    expect(tick.peak!, lessThan(SfxLevel.status));
    expect(tick.length, lessThan(0.1));
    final shatter = kSfxCatalog[Sfx.breakShatter]!;
    expect(shatter.peak!, greaterThan(SfxLevel.impact));
    expect(shatter.length, inInclusiveRange(0.3, 0.8));
    expect(kSfxCatalog[Sfx.breakVuln]!.length, lessThan(0.25));
    expect(kSfxCatalog[Sfx.breakDazed], isNotNull);
    final warn = kSfxCatalog[Sfx.enemyUltWarn]!;
    expect(warn.peak!, greaterThan(SfxLevel.impact));
    expect(warn.length, lessThan(1.0));
  });

  test('ULT enemigas: tres partes propias que entran en sus fases', () {
    for (final id in kEnemyUlts.keys) {
      final script = ultScriptFor(id);
      expect(kEnemyUltVoices, contains(id));
      final build = kSfxCatalog[Sfx.ult(id, Sfx.ultBuild)]!;
      final release = kSfxCatalog[Sfx.ult(id, Sfx.ultRelease)]!;
      final impact = kSfxCatalog[Sfx.ult(id, Sfx.ultImpact)]!;
      expect(build.length, lessThanOrEqualTo(script.buildMs / 1000 + 0.15), reason: id);
      expect(release.length, lessThanOrEqualTo(script.releaseMs / 1000), reason: id);
      expect(impact.peak, SfxLevel.ultImpact);
    }
    for (final part in Sfx.ultParts) {
      final voices = {
        for (final id in kEnemyUlts.keys)
          kSfxCatalog[Sfx.ult(id, part)]!
              .voices
              .map((v) => '${v.wave}:${v.frequency}:${v.duration}:${v.delay}')
              .join(','),
      };
      expect(voices, hasLength(kEnemyUlts.length), reason: part);
    }
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
      // Solo las partes de las ULT (del grupo y enemigas) pasan el nivel
      // del crítico.
      final ult = e.key.startsWith('ult_') || e.key.startsWith('eult_');
      expect(def.peak!,
          lessThanOrEqualTo(ult ? SfxLevel.ultImpact : SfxLevel.crit),
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
    for (final sk in kAllUltimates.values) {
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
        for (final sk in kAllUltimates.values)
          kSfxCatalog[Sfx.ult(sk.id, part)]!
              .voices
              .map((v) => '${v.wave}:${v.frequency}:${v.duration}:${v.delay}')
              .join(','),
      };
      expect(voices, hasLength(kAllUltimates.length), reason: part);
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
    for (final sk in kAllUltimates.values) {
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
    // Cada ULT enemiga completa (a todos: 3 impactos; a uno: 1).
    for (final ult in kEnemyUlts.values) {
      final script = ultScriptFor(ult.id);
      final parts = [
        (Sfx.ult(ult.id, Sfx.ultBuild), 0),
        (Sfx.ult(ult.id, Sfx.ultRelease), script.buildMs),
        for (var i = 0; i < (ult.allTargets ? 3 : 1); i++)
          (Sfx.ult(ult.id, Sfx.ultImpact), script.impactFor(i)),
        if (ult.guaranteedCrit) (Sfx.critClink, script.impactMs),
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
      File('$dir${Platform.pathSeparator}enemy_ult_${ult.id.substring(5)}.wav')
          .writeAsBytesSync(synth.encode(mix));
    }
  });
}
