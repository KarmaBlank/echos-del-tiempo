import '../data/skills_catalog.dart' show dualKey;
import '../models/battle_state.dart';
import '../models/skill.dart';

/// Reglas de qué dúo puede hacer quién (docs/specs/combat.md § "Dúos").
/// Puro: lo usan el motor (validar el comando) y la UI (la lista DÚOS).

/// El dúo [id] / [d] lo pueden hacer [p] y [q] (sin mirar MP ni vida):
/// uno de clase si `id == dualKey(clase p, clase q)`; uno de armas si los
/// tipos de arma de los dos son su par, en cualquier orden.
bool dualFits(String id, DualDef d, Combatant p, Combatant q) {
  final w = d.weapons;
  if (w == null) {
    final a = p.classId, b = q.classId;
    return a != null && b != null && id == dualKey(a, b);
  }
  final a = p.weaponType, b = q.weaponType;
  if (a == null || b == null || w.length != 2) return false;
  return (a == w[0] && b == w[1]) || (a == w[1] && b == w[0]);
}

/// Los ids de los dúos que [p] puede hacer con [q]: primero el de clase
/// (si lo hay), después los de armas en el orden del catálogo.
List<String> dualIdsFor(
    Map<String, DualDef> duals, Combatant p, Combatant q) {
  final out = <String>[];
  final a = p.classId, b = q.classId;
  if (a != null && b != null) {
    final k = dualKey(a, b);
    final d = duals[k];
    if (d != null && !d.byWeapon) out.add(k);
  }
  for (final e in duals.entries) {
    if (e.value.byWeapon && dualFits(e.key, e.value, p, q)) out.add(e.key);
  }
  return out;
}
