import 'package:echos_del_tiempo/core/audio/music/music_catalog.dart';
import 'package:echos_del_tiempo/core/audio/sfx_catalog.dart';
import 'package:echos_del_tiempo/core/audio/sfx_recipes.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_style.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/ult_cinematic.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_sfx.dart';
import 'package:echos_del_tiempo/game_engine/data/ascension_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sonido, música y guiones propios de la ascensión (ascension.md § 4-5).
void main() {
  test('cada habilidad del kit tiene firma y color propios', () {
    for (final id in kAscensionSkills.keys) {
      expect(kSfxCatalog, contains(Sfx.skill(id)), reason: id);
      expect(kSkillColors, contains(id), reason: id);
      expect(kSkillsById, contains(id), reason: id);
    }
  });

  test('cada ULT de ascensión: guion, color, sonido en 3 partes distintas', () {
    final builds = <String>{};
    for (final u in kAscensionUltimates.values) {
      expect(kUltScripts, contains(u.id), reason: u.id);
      expect(kSkillColors, contains(u.id), reason: u.id);
      expect(kSkillsById[u.id], same(u));
      final s = ultScriptFor(u.id);
      final build = kSfxCatalog[Sfx.ult(u.id, Sfx.ultBuild)]!;
      final release = kSfxCatalog[Sfx.ult(u.id, Sfx.ultRelease)]!;
      final impact = kSfxCatalog[Sfx.ult(u.id, Sfx.ultImpact)]!;
      expect(build.length, lessThanOrEqualTo(s.buildMs / 1000 + 0.15), reason: u.id);
      expect(release.length, lessThanOrEqualTo(s.releaseMs / 1000), reason: u.id);
      expect(impact.peak, SfxLevel.ultImpact);
      builds.add(build.voices
          .map((v) => '${v.wave}:${v.frequency}:${v.duration}:${v.delay}')
          .join(','));
    }
    expect(builds, hasLength(kAscensionUltimates.length));
    expect(kAscensionUltVoices.keys.toSet(),
        {for (final u in kAscensionUltimates.values) u.id});
  });

  test('cinemática, trampas y jingle', () {
    for (final id in [
      Sfx.ascBuild,
      Sfx.ascReveal,
      Sfx.trapSpike,
      Sfx.trapPulse,
      Sfx.trapSpring,
    ]) {
      expect(kSfxCatalog, contains(id), reason: id);
    }
    expect(SessionSfx.ascensionCues.map((c) => c.id),
        [Sfx.ascBuild, Sfx.ascReveal]);
    expect(SessionSfx.ascensionCues.last.delayMs, 2200);
    final j = kMusicCatalog[Music.ascension]!;
    expect(j.loop, isFalse);
  });
}
