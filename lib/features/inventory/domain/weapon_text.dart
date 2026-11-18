import '../../../game_engine/data/game_catalog.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/upgrade_stat.dart';
import '../../../game_engine/models/weapon.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../../game_engine/data/summoner_catalog.dart';
import '../../combat/domain/skill_text.dart';
import '../../combat/domain/summon_text.dart';

/// Textos de armas de los paneles — puerto de `reqHtml`, `wPowTxt`,
/// `skHtml` (líneas 1262-1266) y `weaponTip` (1122-1131) en el markup
/// del prototipo (`ProtoMarkup`, docs/specs/ui_style.md § "Texto rico"),
/// con sus mismos colores. Ver docs/specs/panels.md.

/// `VIT`, `ESP`, `AGI`, `FUE`, `DES`.
String attributeShort(Attribute a) => a.name.toUpperCase();

/// Número sin `.0` sobrante (`fm` del prototipo).
String fmtNum(num v) {
  final r = (v * 100).roundToDouble() / 100;
  return r == r.roundToDouble() ? r.round().toString() : r.toString();
}

const _green = '#7bed9f';
const _red = '#ff6b81';
const _ice = '#74b9ff';
const _orange = '#ff9f43';
const _pink = '#e84393';

/// `reqHtml`: cada requisito en verde (cumplido) o rojo (falta).
String requirementsMarkup(WeaponDef w, PlayerAttributes attributes) => [
      for (final e in w.requirements.entries)
        hexSpan(attributes[e.key] >= e.value ? _green : _red,
            '${attributeShort(e.key)} ${e.value}'),
    ].join(' ');

/// `wPowTxt`: letra de escala por atributo de la fórmula de poder.
String weaponScaleText(WeaponDef w) {
  final f = w.mag ?? w.atk;
  return f.coefficients.entries.map((e) {
    final c = e.value;
    final grade = c >= 0.8
        ? 'A'
        : c >= 0.6
            ? 'B'
            : c >= 0.4
                ? 'C'
                : 'D';
    return '${attributeShort(e.key)} $grade';
  }).join(' ');
}

/// `skHtml`: habilidades del arma (+ la fusionada) con `⏳` y la letra del
/// estado en su color, la ULT en `#e84393` y el DEF del escudo en
/// `#74b9ff`.
String skillListMarkup(GameCatalog catalog, WeaponDef w, {String? fusedId}) {
  final ids = [...w.skillIds];
  if (fusedId != null && !ids.contains(fusedId)) ids.add(fusedId);
  final names = ids.map((id) {
    final s = catalog.skills[id];
    if (s == null) return id;
    final st = s.status;
    return '${s.name}'
        '${s.delay > 0 ? ' ⏳' : ''}'
        '${st != null ? ' ${hexSpan(statusHex(st.kind), statusLetterOf(st.kind))}' : ''}'
        '${id == fusedId ? ' (fusión)' : ''}';
  }).join(' · ');
  final ult = weaponBaseUlt(w, catalog.ultimates)?.name ?? '—';
  return '${names.isEmpty ? '—' : names} · ${hexSpan(_pink, 'ULT: $ult')}'
      '${w.shieldDefense > 0 ? ' · ${hexSpan(_ice, 'DEF +${w.shieldDefense}')}' : ''}';
}

/// `weaponTip`: el detalle de un arma (requisitos con el perfil, poder
/// calculado, mejoras, habilidades y ULT), en markup.
String weaponTooltip(ProgressionRules rules, PlayerProfile p, WeaponDef w) {
  final cat = rules.catalog;
  final owned = p.inventory.contains(w.id);
  final up = p.upgradesFor(w.id);
  final f = w.mag ?? w.atk;
  final power = f.evaluate(p.attributes) *
      (1 + WeaponUpgradeLevels.powPer * (owned ? up.pow : 0));
  final l = <String>[
    '<b>${owned ? rules.weaponDisplayName(p, w.id) : w.name}</b> '
        '<span class="k">${w.type} · tier ${w.tier}</span>',
    'Requisitos: ${w.requirements.entries.map((e) {
      final ok = p.attributes[e.key] >= e.value;
      return hexSpan(ok ? _green : _red,
          '${attributeShort(e.key)} ${e.value} ${ok ? '✔' : '✘'}');
    }).join(', ')}',
    '${w.mag != null ? 'Poder mágico' : 'Poder físico'}: ${fmtNum(f.base)} + '
        '${f.coefficients.entries.map((e) => '${attributeShort(e.key)}×${fmtNum(e.value)}').join(' + ')}'
        ' = <b>${power.round()}</b>',
  ];
  if (owned && up.total > 0) {
    l.add('Mejoras: ${UpgradeStat.values.where((s) => up.level(s) > 0).map((s) => '${s.label} +${up.level(s)}').join(', ')}');
  }
  if (w.shieldDefense > 0) l.add(hexSpan(_ice, 'DEF +${w.shieldDefense}'));
  if (w.weight > 0) {
    l.add('Peso ${fmtNum(w.weight)} (−${fmtNum(w.weight)} velocidad)');
  }
  l.add('<br><span class="k">HABILIDADES</span>');
  final fused = owned ? p.fused[w.id] : null;
  final ids = [...w.skillIds];
  if (fused != null && !ids.contains(fused)) ids.add(fused);
  for (final id in ids) {
    final s = cat.skills[id];
    if (s == null) continue;
    l.add(describeSkillMarkup(s, null) +
        (id == fused ? ' ${hexSpan(_orange, '(fusión)')}' : ''));
  }
  l.addAll(summonWeaponLines(w));
  if (weaponBaseUlt(w, cat.ultimates) case final u?) {
    l.add('<br>${describeSkillMarkup(u, null, ultimate: true, nameColor: _pink)}');
  }
  l.add('<br><span class="k">Herrería: subí Poder, Crítico o Velocidad por '
      'separado (máx nivel ${ProgressionRules.upgradeMax} c/u)</span>');
  return l.join('<br>');
}
