import '../models/skill.dart';
import '../models/status.dart';
import 'skills_catalog.dart';

/// Dúos de ARMAS (v0.8.3, docs/specs/combat.md § "Dúos"): se habilitan
/// por el par de tipos de arma (`WeaponDef.type`) de los dos que lo hacen,
/// en cualquier orden, sin importar la clase. Conviven con los dúos de
/// clase de [kDuals] (si un par cumple los dos, se ofrecen los dos).
///
/// La clave es el id estable del dúo (viaja en `DualCommand.dualId` y en
/// `ActionEvent.skillId`); empieza con `w_` y nunca tiene `+` (así no
/// choca con las claves `claseA+claseB` de [kDuals]). El elemento sale
/// del estado (`elementOfDual`): con él ceban y detonan reacciones.
const Map<String, DualDef> kWeaponDuals = {
  'w_flechaArcana': DualDef('Flecha Arcana Gemela',
      StatusApplication(StatusKind.charged, 1), 1.45,
      weapons: ['arco', 'báculo']),
  'w_bastionRunico': DualDef('Bastión Rúnico',
      StatusApplication(StatusKind.holy, 2), 1.45,
      weapons: ['espada+escudo', 'tomo']),
  'w_fuegoCruzado': DualDef('Fuego Cruzado Letal',
      StatusApplication(StatusKind.burn, 2), 1.45,
      weapons: ['dagas', 'rifle']),
  'w_terremotoDoble': DualDef('Terremoto Doble',
      StatusApplication(StatusKind.stun, 1, chance: 0.4), 1.45,
      weapons: ['hacha', 'martillo+escudo']),
  'w_saetaVoltaica': DualDef('Saeta Voltaica',
      StatusApplication(StatusKind.charged, 1), 1.45,
      weapons: ['varita', 'ballesta']),
  'w_juicioPerforante': DualDef('Juicio Perforante',
      StatusApplication(StatusKind.holy, 2), 1.45,
      weapons: ['lanza', 'maza+escudo']),
  'w_filoIgneo': DualDef('Filo Ígneo Arcano',
      StatusApplication(StatusKind.burn, 2), 1.45,
      weapons: ['espada', 'varita']),
  'w_hojaMaldita': DualDef('Hoja Maldita',
      StatusApplication(StatusKind.poison, 2), 1.45,
      weapons: ['tomo', 'dagas']),
  'w_tajoGlaciar': DualDef('Tajo Glaciar',
      StatusApplication(StatusKind.freeze, 1), 1.45,
      weapons: ['hacha', 'báculo']),
  'w_diluvioAstas': DualDef('Diluvio de Astas',
      StatusApplication(StatusKind.wet, 1), 1.45,
      weapons: ['lanza', 'arco']),
};

/// Todos los dúos: los de clase (por `dualKey`) y los de armas (por id).
/// Es lo que usa `GameCatalog.standard`.
const Map<String, DualDef> kAllDuals = {...kDuals, ...kWeaponDuals};
