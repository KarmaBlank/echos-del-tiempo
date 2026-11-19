import 'dart:math' as math;

import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/craft_rules.dart';
import '../../../game_engine/rules/loot_rules.dart';

/// Tooltips de la mesa de fusión (pestaña FUSIÓN, panels.md § "FUSIÓN
/// (v0.8.3: tooltips)"). Pedido del dueño: "que haya tooltip en cada
/// opción de la fusión porque no se entiende". Cada acción explica en
/// castellano simple: qué hace, qué cambia en TU arma (con sus números),
/// qué cuesta (y qué tienes), qué se pierde, por qué está bloqueada y un
/// ejemplo. Los números salen de [CraftRules] / [Rarity] / [LootRules]
/// (nada copiado a mano).

/// Las partes de la ayuda de una acción ([CraftHelp.op]).
class CraftOpHelp {
  const CraftOpHelp({
    required this.what,
    required this.change,
    required this.cost,
    required this.lose,
    required this.example,
    this.blocked,
  });

  /// Qué hace (una oración).
  final String what;

  /// Qué cambia en el arma elegida, con sus números.
  final String change;

  /// Qué cuesta y cuánto tienes.
  final String cost;

  /// Qué se pierde.
  final String lose;

  /// Por qué está bloqueada (`null` = se puede).
  final String? blocked;

  /// Un ejemplo (sin el `Ejemplo:`).
  final String example;

  /// Etiquetas de cada parte, en orden (también las usan las pruebas).
  static const whatLabel = 'Qué hace:',
      changeLabel = 'En tu arma:',
      costLabel = 'Cuesta:',
      loseLabel = 'Pierdes:',
      blockedLabel = 'Bloqueada:',
      exampleLabel = 'Ejemplo:';

  /// Markup del tooltip con [title] arriba (`<b>`, resaltado solo con
  /// color) y una línea por parte con su etiqueta en `k`.
  String markup(String title) => [
        '<b>${craftHelpEsc(title)}</b>',
        _part(whatLabel, what),
        _part(changeLabel, change),
        _part(costLabel, cost),
        _part(loseLabel, lose),
        if (blocked != null)
          '<span style="color:#ff6b81">$blockedLabel</span> '
              '${craftHelpEsc(blocked!)}'
              '${blockedHint(blocked!) == null ? '' : ' ${craftHelpEsc(blockedHint(blocked!)!)}'}',
        _part(exampleLabel, example),
      ].join('<br>');

  /// Qué hacer con un motivo de bloqueo común (`null` = nada que sumar).
  static String? blockedHint(String reason) {
    if (reason.startsWith('Falta ')) {
      return '(Mira dónde se consigue en el contador de materiales.)';
    }
    if (reason.startsWith('Faltan \$')) {
      return '(Vende o desarma armas que no uses para juntar créditos.)';
    }
    if (reason == 'Está equipada') {
      return '(Equipa otra arma primero.)';
    }
    if (reason == 'Arma inicial') {
      return '(Siempre te queda una arma inicial: no se destruye.)';
    }
    return null;
  }

  static String _part(String label, String text) =>
      '<span class="k">$label</span> ${craftHelpEsc(text)}';
}

/// Escapa texto libre (nombres de armas) para el markup.
String craftHelpEsc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// Textos de ayuda de la mesa de fusión.
class CraftHelp {
  const CraftHelp(this.rules);

  final CraftRules rules;

  // ------------------------------------------------------------------
  // Encabezados y migas
  // ------------------------------------------------------------------

  /// Una línea por sección del paso 2 (por nombre del grupo).
  static const groups = {
    'improve': 'MEJORAR: cambia los mods de esta misma arma gastando '
        'materiales. No destruye ninguna otra arma.',
    'transfer': 'TRASLADAR: copia un mod, la pasiva o una habilidad de otra '
        'arma tuya a esta. La otra arma se destruye.',
    'remove': 'QUITAR: borra un mod de esta arma para hacer lugar a uno '
        'mejor. Cuesta créditos.',
    'change': 'CAMBIAR: convierte el arma en otro tipo (p. ej. hacha → '
        'báculo) y se queda con lo que sirva.',
  };

  /// Una línea por paso de las migas (1 ARMA / 2 ACCIÓN / 3 CONFIRMAR).
  static const steps = [
    'Paso 1: elige el arma que quieres mejorar (la que recibe el cambio).',
    'Paso 2: elige qué hacerle. Pasa el mouse por cada acción para ver '
        'qué cambia, qué cuesta y qué pierdes.',
    'Paso 3: elige los detalles (de qué arma, qué mod) y mira ANTES → '
        'DESPUÉS. Nada se gasta hasta que confirmas.',
  ];

  // ------------------------------------------------------------------
  // Materiales
  // ------------------------------------------------------------------

  /// Para qué sirve [m] en la mesa y dónde se consigue, con lo que
  /// tienes (markup).
  String material(CraftMaterial m, PlayerProfile p) {
    final uses = switch (m) {
      CraftMaterial.esquirla =>
        'Re-tirar valores (1) y Reforjar un arma Común (1).',
      CraftMaterial.cristal => 'Agregar un mod (1) y Reforjar un arma '
          'Mágica, Rara o Épica (1).',
      CraftMaterial.prisma => 'Subir rareza (${_prismaSteps()}) y Reforjar '
          'un arma Épica (1).',
      CraftMaterial.ancla => 'No se usa en la fusión: sube el tier de un '
          'Eco en el Portal del Eco.',
      CraftMaterial.esencia =>
        'Esencia del Abismo (1): mejora los mods fijos de un legendario.',
      _ => 'No se usa en la fusión.',
    };
    final where = switch (m) {
      CraftMaterial.esquirla ||
      CraftMaterial.cristal ||
      CraftMaterial.prisma =>
        'Cae como loot (${_pct(LootRules.materialChance[m] ?? 0)} por '
            'tirada${m == CraftMaterial.esquirla ? '; los jefes dan 1 segura' : ''})'
            ' y al desarmar: ${_salvageText(m)}.',
      CraftMaterial.ancla => 'Solo cae dentro de los Ecos.',
      CraftMaterial.esencia => 'Cae de los Jefes del Abismo.',
      _ => 'Cae en Ecos de tier 10+.',
    };
    return [
      '<b>${craftHelpEsc(m.label)}</b>',
      '<span class="k">Para qué:</span> ${craftHelpEsc(uses)}',
      '<span class="k">Dónde:</span> ${craftHelpEsc(where)}',
      '<span class="k">Tienes:</span> ${p.material(m)} '
          '(máximo ${CraftMaterial.maxStack})',
    ].join('<br>');
  }

  /// `1 / 2 / 4` Prismas por escalón (de [CraftRules.upgradeRarityCost]).
  static String _prismaSteps() => [
        for (final r in Rarity.values)
          if (CraftRules.upgradeRarityCost(r) case (final n, _)) '$n',
      ].join(' / ');

  /// Qué rarezas dan [m] al desarmar (de [CraftRules.salvageYield]).
  static String _salvageText(CraftMaterial m) {
    final out = <String>[];
    for (final r in Rarity.values) {
      final y = CraftRules.salvageYield(
          ItemInstance(uid: '', baseId: '', rarity: r));
      final n = y.guaranteed[m] ?? 0;
      final c = y.chances.where((x) => x.material == m).firstOrNull;
      if (n > 0) {
        out.add('${r.label} $n');
      } else if (c != null) {
        out.add('${r.label} ${_pct(c.chance)}');
      }
    }
    return out.isEmpty ? 'nada' : out.join(', ');
  }

  static String _pct(double x) {
    final v = x * 100;
    return v == v.roundToDouble()
        ? '${v.round()}%'
        : '${v.toStringAsFixed(1)}%';
  }

  // ------------------------------------------------------------------
  // Paso 3: arma de origen y habilidad a reemplazar
  // ------------------------------------------------------------------

  /// Tooltip de una fila "¿De qué arma? (se destruye)": qué se lleva
  /// [op] de [s] y todo lo que se pierde con ella.
  String source(ItemInstance s, CraftOp op) {
    final passive = rules.items.passiveOf(s);
    final skills = rules.items.skillsOf(s);
    final takes = switch (op) {
      CraftOp.transferAffix => 'el mod que elijas debajo',
      CraftOp.transferPassive => 'su pasiva (${passive?.name ?? 'ninguna'})',
      CraftOp.transferSkill => 'la habilidad que elijas debajo',
      _ => 'lo que elijas',
    };
    return [
      '<b>${craftHelpEsc(rules.items.displayName(s))}</b>',
      '<span class="k">Te llevas:</span> ${craftHelpEsc(takes)}.',
      '<span style="color:#ff6b81">Se destruye</span> con todo lo demás: '
          '${craftHelpEsc([
        '${s.rarity.label} nivel ${s.itemLevel}',
        'Mods ${s.modCount}/${s.rarity.maxMods}',
        if (passive != null && s.rarity.hasPassive) 'pasiva ${passive.name}',
        if (s.forgeLevel > 0) 'forja +${s.forgeLevel}',
        '${skills.length} habilidad${skills.length == 1 ? '' : 'es'}',
      ].join(', '))}.',
      '<span class="k">Ejemplo:</span> si tiene un mod que querías y lo '
          'traes, el resto de sus mods se pierde.',
    ].join('<br>');
  }

  /// Línea extra del tooltip de una habilidad del destino cuando los
  /// cupos están llenos (loot.md § 16.2).
  static String replaceLine({required bool replaceable, required bool chosen}) =>
      !replaceable
          ? '<span class="k">Habilidad base:</span> viene con el arma y no '
              'se reemplaza.'
          : chosen
              ? '<span style="color:#ff6b81">Se reemplaza:</span> la pierdes '
                  'al confirmar y entra la nueva en su lugar.'
              : '<span class="k">Trasladada:</span> elígela para que la '
                  'nueva ocupe su lugar (la pierdes).';

  // ------------------------------------------------------------------
  // Acciones
  // ------------------------------------------------------------------

  /// Ayuda de [op] sobre [t] para el jugador [p]. [preview] es la vista
  /// previa con la elección por defecto (para el costo exacto) y
  /// [blocked] el motivo de `ShopGuards` (`null` = se puede).
  CraftOpHelp op(PlayerProfile p, ItemInstance t, CraftOp op,
      {CraftResult? preview, String? blocked}) {
    final r = t.rarity;
    final n = t.modCount, max = r.maxMods;
    final next =
        r.index + 1 < Rarity.values.length ? Rarity.values[r.index + 1] : null;
    final base = rules.items.baseOf(t);
    final name = rules.items.displayName(t);
    final passive = rules.items.passiveOf(t);
    final removable = [
      for (final a in t.affixes)
        if (!a.fixed) a
    ];
    final fixed = [
      for (final a in t.affixes)
        if (a.fixed) a
    ];

    // Costo exacto de la vista previa si lo tiene; si no, el de la regla.
    String cost(int credits, Map<CraftMaterial, int> mats, {String? note}) {
      final pre = preview;
      if (pre != null && (pre.credits > 0 || pre.materials.isNotEmpty)) {
        credits = pre.credits;
        mats = pre.materials;
      }
      return _costText(p, credits, mats, note: note);
    }

    String tierRange(int Function(AffixRoll, Rarity) f) {
      final lo = f(const AffixRoll('', 5, 0), r);
      final hi = f(const AffixRoll('', 1, 0), r);
      return '₵$lo (T5) a ₵$hi (T1)';
    }

    const sourceLost = 'El arma de origen se destruye con todo lo suyo: '
        'mods, pasiva, forja y habilidades.';

    return switch (op) {
      CraftOp.reroll => CraftOpHelp(
          what: 'Vuelve a tirar el valor de cada mod de esta arma, dentro '
              'del rango de su tier.',
          change: n == 0
              ? 'No tiene mods (Mods 0/$max): no hay nada que re-tirar.'
              : 'Mods $n/$max: los mismos mods con valores nuevos al azar '
                  '(pueden subir o bajar).',
          cost: cost(CraftRules.rerollCost(r), {CraftMaterial.esquirla: 1}),
          lose: 'Los valores de ahora (no se recuperan).',
          blocked: blocked,
          example: 'un mod +5 con rango 3–7 puede quedar en cualquier valor '
              'de 3 a 7.',
        ),
      CraftOp.addAffix => CraftOpHelp(
          what: 'Agrega un mod al azar del tipo de arma, si hay lugar.',
          change: r == Rarity.comun
              ? 'Un arma Común no lleva mods (Mods 0/$max): sube la rareza '
                  'primero.'
              : n >= max
                  ? 'Mods $n/$max: está llena; quita uno antes.'
                  : 'Mods $n/$max → ${n + 1}/$max.',
          cost: cost(CraftRules.addAffixCost(r), {CraftMaterial.cristal: 1}),
          lose: 'Nada, solo el costo.',
          blocked: blocked,
          example: 'un Raro con 2/${Rarity.raro.maxMods} mods queda con '
              '3/${Rarity.raro.maxMods} y un mod nuevo.',
        ),
      CraftOp.upgradeRarity => CraftOpHelp(
          what: 'Sube la rareza un escalón: Común → Mágico → Raro → Épico.',
          change: next == null || CraftRules.upgradeRarityCost(r) == null
              ? 'Ya es ${r.label}: no sube más con Prismas.'
              : _rarityChange(t, r, next),
          cost: switch (CraftRules.upgradeRarityCost(r)) {
            (final prismas, final credits) =>
              cost(credits, {CraftMaterial.prisma: prismas}),
            null => 'No se puede subir más.',
          },
          lose: next == null || CraftRules.upgradeRarityCost(r) == null
              ? 'Nada.'
              : 'Nada, pero fusionar y forjar esta arma cuesta más '
                  '(×${_factor(r.costFactor)} → ×${_factor(next.costFactor)}).',
          blocked: blocked,
          example: _upgradeExample(),
        ),
      CraftOp.essence => CraftOpHelp(
          what: 'Solo legendarios: cada mod fijo se tira 2 veces y queda el '
              'mayor; nunca baja.',
          change: r != Rarity.legendario
              ? 'Es ${r.label}: no tiene mods fijos.'
              : fixed.isEmpty
                  ? 'No tiene mods fijos.'
                  : '${fixed.length} mod${fixed.length == 1 ? '' : 's'} '
                      'fijo${fixed.length == 1 ? '' : 's'}: '
                      '${_fixedText(t, fixed)}.',
          cost: cost(0, {CraftMaterial.esencia: 1}),
          lose: 'Nada: los valores nunca bajan.',
          blocked: blocked,
          example: 'un fijo +5 (rango 3–8) sale 4 y 7 → queda +7; si sale 2 '
              'y 4, queda +5.',
        ),
      CraftOp.transferAffix => CraftOpHelp(
          what: 'Copia un mod de otra arma tuya a esta; la otra se destruye.',
          change: n >= max
              ? 'Mods $n/$max: está llena; quita uno antes.'
              : 'Mods $n/$max → ${n + 1}/$max (el mod que elijas, con su '
                  'valor).',
          cost: _costText(p, 0, const {},
              note: 'según el tier del mod: '
                  '${tierRange(CraftRules.transferAffixCost)} en un '
                  '${r.label}'),
          lose: sourceLost,
          blocked: blocked,
          example: 'traes "+6 ATQ" de una espada vieja: esta arma suma el '
              'mod y la espada desaparece.',
        ),
      CraftOp.transferPassive => CraftOpHelp(
          what: 'Pasa la pasiva de otra arma Épica a esta (también Épica); '
              'la otra se destruye.',
          change: r != Rarity.epico
              ? 'Es ${r.label}: solo una Épica recibe pasiva.'
              : 'Pasiva: ${passive?.name ?? 'ninguna'} → la de la otra '
                  'arma (con su nivel).',
          cost: cost(CraftRules.transferPassiveCost(r), const {}),
          lose: passive == null
              ? sourceLost
              : '$sourceLost Y la pasiva de ahora (${passive.name}).',
          blocked: blocked,
          example: 'tu Épica recibe la pasiva de otra Épica por '
              '₵${CraftRules.transferPassiveCost(Rarity.epico)}; las pasivas '
              'únicas de legendario no se trasladan.',
        ),
      CraftOp.transferSkill => CraftOpHelp(
          what: 'Esta arma aprende una habilidad de otra arma tuya, que se '
              'destruye.',
          change: 'Habilidades traídas ${t.extraSkills.length}/'
              '${t.skillCapacity}'
              '${t.extraSkills.length >= t.skillCapacity ? ' (lleno: eliges cuál reemplazar, también Quebrar)' : ' → ${t.extraSkills.length + 1}/${t.skillCapacity}'}.',
          cost: cost(CraftRules.transferSkillCost(r), const {}),
          lose: t.extraSkills.length >= t.skillCapacity
              ? '$sourceLost Y una habilidad traída o Quebrar (la que elijas).'
              : sourceLost,
          blocked: blocked,
          example: 'un hacha aprende una habilidad de un hacha vieja; las '
              'físicas solo pasan a armas del mismo tipo de ataque.',
        ),
      CraftOp.removeAffix => CraftOpHelp(
          what: 'Borra un mod de esta arma para hacer lugar.',
          change: removable.isEmpty
              ? 'Mods $n/$max: no tiene mods que se puedan quitar.'
              : 'Mods $n/$max → ${n - 1}/$max.',
          cost: _costText(p, 0, const {},
              note: 'según el tier del mod: '
                  '${tierRange(CraftRules.removeAffixCost)}'),
          lose: 'Ese mod, para siempre. Los mods fijos de un legendario no '
              'se quitan.',
          blocked: blocked,
          example: 'un Raro con ${Rarity.raro.maxMods}/${Rarity.raro.maxMods} '
              'mods quita uno malo y deja lugar para Agregar o Traer otro.',
        ),
      CraftOp.reforge => CraftOpHelp(
          what: 'Cambia el tipo de arma y conserva rareza, mods, pasiva, '
              'forja y habilidades traídas.',
          change: r == Rarity.legendario
              ? 'Un Legendario no cambia de base.'
              : 'Base ${base?.name ?? t.baseId} (${base?.type ?? '?'}) → '
                  'otra de nivel ${t.itemLevel} o menos.',
          cost: switch (CraftRules.reforgeCost(t)) {
            (final credits, final mats) => cost(credits, mats),
            null => 'No se puede (Legendario).',
          },
          lose: 'Los mods y la pasiva que no salen en el tipo nuevo, y la '
              'forja de Defensa si la base nueva no tiene escudo.',
          blocked: blocked,
          example: 'un arco Raro de nivel 20 pasa a báculo de nivel 20 o '
              'menos, con los mods que sirvan en báculo.',
        ),
      CraftOp.salvage ||
      CraftOp.salvageAll ||
      CraftOp.salvageSelected =>
        CraftOpHelp(
          what: 'Destruye el arma y te da materiales de fusión.',
          change: '$name desaparece.',
          cost: 'Gratis.',
          lose: 'El arma entera.',
          blocked: blocked,
          example: 'desarmar un Raro da '
              '${_yieldText(CraftRules.salvageYield(const ItemInstance(uid: '', baseId: '', rarity: Rarity.raro)))}.',
        ),
      CraftOp.sell ||
      CraftOp.sellAll ||
      CraftOp.sellSelected =>
        CraftOpHelp(
          what: 'Destruye el arma y te da créditos.',
          change: '$name desaparece.',
          cost: 'Gratis.',
          lose: 'El arma entera.',
          blocked: blocked,
          example: 'vender esta arma da ₵${rules.sellPrice(t)}.',
        ),
    };
  }

  /// `₵25 (tienes ₵5000) + 1 Esquirla del Eco (tienes 2)`.
  static String _costText(
      PlayerProfile p, int credits, Map<CraftMaterial, int> mats,
      {String? note}) {
    final parts = [
      if (credits > 0) '₵$credits (tienes ₵${p.credits})',
      for (final e in mats.entries)
        '${e.value} ${e.key.label} (tienes ${p.material(e.key)})',
      if (note != null) note,
    ];
    if (parts.isEmpty) return 'Gratis.';
    final s = parts.join(' + ');
    return note != null && credits == 0 && mats.isEmpty
        ? '${s[0].toUpperCase()}${s.substring(1)} (tienes ₵${p.credits}).'
        : '$s.';
  }

  static String _factor(double f) =>
      f == f.roundToDouble() ? f.toStringAsFixed(1) : '$f';

  /// `Raro → Épico: mods 4 → 6 (+2 lugares), pasiva nueva...`.
  static String _rarityChange(ItemInstance t, Rarity r, Rarity next) {
    final extra = next.maxMods - r.maxMods;
    final missing = math.max(0, next.minMods - t.affixes.length);
    return [
      '${r.label} → ${next.label}: lugar de mods ${r.maxMods} → '
          '${next.maxMods} (+$extra)',
      if (missing > 0)
        '+$missing mod${missing == 1 ? '' : 's'} al azar para llegar al '
            'mínimo',
      if (next.skillSlots > r.skillSlots)
        'habilidades traídas ${r.skillSlots} → ${next.skillSlots}',
      'tope de forja ${r.forgeCap} → ${next.forgeCap}',
      if (next.hasPassive && !r.hasPassive) 'y gana una pasiva al azar',
    ].join(', ');
  }

  static String _upgradeExample() {
    final c = CraftRules.upgradeRarityCost(Rarity.magico);
    if (c == null) return 'subir un Mágico a Raro.';
    return 'subir un Mágico a Raro cuesta ${c.$1} Prismas + ₵${c.$2} y deja '
        'lugar para ${Rarity.raro.maxMods} mods.';
  }

  String _fixedText(ItemInstance t, List<AffixRoll> fixed) => [
        for (final a in fixed)
          if (rules.items.rangeOf(t, a) case (final lo, final hi))
            '${rules.items.affixOf(a)?.stat.label ?? a.affixId} ${a.value} '
                '(rango $lo–$hi)'
          else
            rules.items.affixOf(a)?.stat.label ?? a.affixId,
      ].join(', ');

  static String _yieldText(SalvageYield y) => [
        for (final e in y.guaranteed.entries) '${e.value} ${e.key.label}',
        for (final c in y.chances) c.text,
      ].join(' + ');
}
