# Spec: Niveles de ULT

Estado: propuesta (sin código). Hoy una ULT sube del nivel 1 al 5 con
créditos y materiales (`TuningId.ultUpgrade`) y gana +6% de poder por
nivel (`TuningId.ultLevel`, ultimates_v2.md § 2.4). Esta spec hace que el
nivel se note mucho más, en lo visual y en el poder, y que cada nivel la
haga un poco más cara de cargar.

## 1. Visual por nivel

Cada nivel suma capas a la cinemática y a los efectos de la ULT
(`fx_timeline.dart`, guiones del editor de animaciones). Los niveles se
agregan, no se reemplazan:

| nivel | agrega |
|---|---|
| 1 | el guion base |
| 2 | más partículas en el impacto (× 1.5) y un destello de pantalla |
| 3 | guion más largo (una toma extra antes del impacto) y una capa de sonido grave |
| 4 | efecto de pantalla (temblor y viñeta del color del elemento) y partículas × 2 |
| 5 | impacto doble, capa de sonido brillante y una franja de nombre de la ULT |

- Las capas por nivel viven en el guion de la ULT (`levelLayers`), no en
  código; el editor de animaciones las muestra por nivel.
- Respetan Ajustes: con efectos reducidos o la densidad de partículas
  baja, se recortan igual que hoy; la duración extra respeta el tope de
  duración de la ULT (`kUltMaxDurationMs`).

## 2. Poder y costo de carga

- Poder: `perLevel` (hoy 0.06) sube a un ajuste por nivel
  (`powerByLevel`: 1.00 / 1.08 / 1.17 / 1.27 / 1.40).
- Carga necesaria: la barra pasa de 100 fijo a `100 × chargeByLevel`
  (1.00 / 1.05 / 1.10 / 1.16 / 1.22). Lo que escala es la carga base
  (golpes, Defender, daño recibido, ganancia de la habilidad).
- La carga extra (árbol, mods, efectos) sigue con su tope de 50% por
  acción y por turno (combat.md § "Límites"), medido sobre la barra de
  ese nivel.
- Costo variable de la ULT (`kUltCost`) se mide en fracción de la barra,
  no en puntos.

## 3. Costo de mejora

Más caro por nivel: `credits × nivel²` en vez de `× nivel` (ajuste
`creditsCurve`: lineal o cuadrática), Cristales como hoy, Prismas y
Fragmentos desde los mismos niveles.

## 4. UI de la mejora

Al apretar MEJORAR, antes de confirmar:

"Ahora la ULT cuesta un poco más cargarla, pero es más espectacular."

| | nivel 2 | nivel 3 |
|---|---|---|
| poder | 108% | 117% |
| carga necesaria | 105 | 110 |
| efectos nuevos | | toma extra, sonido grave |

Y la vista previa animada muestra el nivel nuevo. En la ficha de la ULT
del repertorio, la línea "Carga: 110 (nivel 3)".

## 5. Ajustes de Balance

Grupo nuevo "ULT: niveles" (reemplaza `ultLevel`): `powerByLevel[1..5]`,
`chargeByLevel[1..5]`, `creditsCurve`. Un parche viejo con `perLevel` se
traduce a `powerByLevel` con aviso (como `ultCost` hoy).

## 6. Netcode

La barra necesaria depende del nivel, que ya viaja con el perfil; el
combatiente lleva `ultNeed` en el estado de batalla. Sube
`kProtocolVersion`.
