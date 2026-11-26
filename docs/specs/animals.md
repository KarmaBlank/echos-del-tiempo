# Spec: Animales de granja (oficio Cultivo / granjero)

Estado: implementado en feat/farm-animals (protocolo 100). Extiende
`farming.md` (Cultivo, huerta, ayudantes) y reemplaza la idea vieja del
CORRAL de `farming.md` § 13. Principios: `design_pillars.md` (partes
simples, nada obligatorio, calma real, todo en Balance). Lore: solo
`docs/lore.md`.

Todo número de esta spec está en Editor → Balance → **Animales**
(`kTuning['animals']`, `lib/game_engine/data/tuning_catalog.dart`). El
catálogo (qué animales, qué construcción, qué producto, qué herramienta,
qué sprite) son datos en `lib/game_engine/data/animals_catalog.dart`:
cada entrada solo dice ids y claves; precios, días y XP los lee del
Balance por clave (`<id>Price`, `<id>Every`, …).

Código: `animals_catalog.dart`, `models/farm_animal.dart`,
`rules/animal_rules.dart`, `rules/session_engine_animals.dart` (parte del
motor), `map/animal_layer.dart`, `panels/animal_panel.dart`, la pestaña
GRANJA de `panels/trader_panel.dart`. Sprites: `tool/export_animal_sprites.dart`
→ `items.vida_*` del manifiesto (nunca un archivo nombrado en Dart).

---

## 1. Idea (una tecla, nada obligatorio)

- Comprás un GALLINERO o un ESTABLO en EDITAR PUEBLO (oro), comprás
  animales en el agropecuario (pestaña GRANJA) y van solos a su casa.
- Cada día del mundo: le das de comer (heno) y lo acariciás (E). Al día
  siguiente deja su producto: huevos en el piso del gallinero, leche y
  lana se sacan con E y la herramienta (Cubeta, Tijeras).
- El cariño (0 a 5 corazones) sube la calidad del producto, con las
  mismas calidades de la huerta (normal, rara = "plata", épica = "oro";
  nunca legendaria).
- **Nada se pierde:** los animales nunca mueren ni se van. Sin comida no
  producen y el cariño baja despacio; con comida vuelven a producir al
  día siguiente.

## 2. Catálogo inicial

| Construcción | Huella | Casa | Cupo | Precio | Nivel de Cultivo |
|---|---|---|---|---|---|
| GALLINERO (`gallinero`) | 5 × 4 | 2 × 2 arriba a la izquierda | 6 | 600 oro (`coopPrice`) | 3 (`coopLevel`) |
| ESTABLO (`establo`) | 7 × 5 | 3 × 3 arriba a la izquierda | 6 | 1500 oro (`barnPrice`) | 6 (`barnLevel`) |

El resto de la huella es el patio: pasto con cerco (los cercos con
autotile del taller), con un portón abajo al medio. El patio se camina;
la casa es sólida.

| Animal | Vive en | Precio | Nivel | Producto | Cada | Herramienta |
|---|---|---|---|---|---|---|
| Gallina | gallinero | 150 | 3 | Huevo | 1 día | — (al piso, imán) |
| Pato | gallinero | 300 | 5 | Huevo de pato | 2 días | — (al piso, imán) |
| Vaca | establo | 800 | 6 | Leche | 1 día | Cubeta |
| Cabra | establo | 600 | 8 | Leche de cabra | 2 días | Cubeta |
| Oveja | establo | 700 | 10 | Lana | 3 días | Tijeras |

| Producto | Precio normal | XP de Cultivo |
|---|---|---|
| Huevo | 20 | 6 |
| Huevo de pato | 50 | 14 |
| Leche | 35 | 9 |
| Leche de cabra | 80 | 20 |
| Lana | 140 | 30 |

El precio y la XP suben con la calidad con `qualityMult<Calidad>` de
Cultivo (× 1, × 1.3, × 1.8).

Herramientas (una vez, quedan para siempre): Cubeta 400 oro, Tijeras 600
oro (`cubetaPrice`, `tijerasPrice`). Heno: 5 oro el fardo (`hayPrice`), o
PICAR FARDOS en la GRANJA: cada cultivo (cualquiera, cualquier calidad)
da `hayPerCrop` (2) fardos.

**Más adelante (solo spec, sin código):** Cerdo (establo) que busca
trufas en el patio en vez de dar un producto fijo; máquinas de queso y de
mayonesa en el TALLER DE OFICIOS (leche → queso, huevo → mayonesa, misma
calidad, más precio).

## 3. Construcciones (EDITAR PUEBLO)

- Salen en la paleta CONSTRUIR con su precio en oro y el nivel de Cultivo
  pedido. Sin el nivel o sin oro, el botón gris con el motivo ("Necesitás
  Cultivo nivel 6", "Falta oro (120/1500)").
- Se mueven como las demás: los animales, el heno y el cofre viajan con
  la construcción. No se funden entre sí (como las casas).
- **Borrar** una construcción con animales no se puede (botón gris:
  "Tiene animales: no se pueden echar"). Vacía, se borra sin devolver oro
  (como la huerta).

## 4. Animales

### 4.1 Comprar
- Pestaña GRANJA del agropecuario, filtro ANIMALES: grilla tipo
  INVENTARIO con el detalle a la derecha (precio, producto, cada cuántos
  días, herramienta, dónde vive). COMPRAR lo manda a la primera
  construcción de su tipo con lugar. Gris con motivo: sin gallinero /
  establo, sin lugar, sin nivel, sin oro.
- Nombre: uno de una lista corta por especie (i18n), según el número del
  animal; no se escribe.

### 4.2 El día de un animal
Cada animal guarda (`models/farm_animal.dart`): especie, cariño (0 a
`affMax` = 500 puntos, 100 por corazón), el último día en que comió, el
último día en que lo acariciaron, días de ciclo acumulados y el producto
listo (calidad) si hay.

Durante el día del mundo `d`:
- **Comer:** E sobre el animal con heno en la bolsa (o desde el depósito
  de heno de su construcción) → comió hoy (+`feedGain` de cariño, XP
  `feedXp`). Una vez por día.
- **Acariciar:** E sobre un animal que ya comió (o sin heno a mano) →
  +`petGain` de cariño, XP `petXp`. Una vez por día.
- **Juntar:** si tiene producto listo, E lo junta: el huevo salta al piso
  y el imán lo trae (como la cosecha); leche y lana piden Cubeta o
  Tijeras ("Necesitás una cubeta: comprala en la GRANJA"). XP del
  producto × calidad.

La tecla E hace lo primero que falte en ese orden: juntar → comer →
acariciar. El cursor de acción marca al animal (verde: hay algo para
hacer; naranja: ya está todo hecho hoy).

Al cambiar el día del mundo (anfitrión, `AnimalRules.onDay`):
- Comió ayer → suma un día de ciclo; al llegar a `<especie>Every` el
  producto queda listo con la calidad de su cariño (si ya había uno sin
  juntar, no se apila).
- No comió ayer → no suma ciclo y pierde `unfedDecay` de cariño.
- No lo acariciaron ayer → pierde `unpetDecay` de cariño.
- El cariño nunca baja de 0 y el animal nunca se va.

### 4.3 Calidad por cariño
Con `h` corazones (cariño ÷ 100, hacia abajo):
- rara: `qRaroPerHeart` × h (0.10 por corazón);
- épica: `qEpicoPerHeart` × max(0, h − 2) (0.08 por corazón desde el 3.º);
- el resto, normal.

A 5 corazones: 50 % rara, 24 % épica.

### 4.4 Noche
Los animales duermen dentro de su casa de noche (`SkyRules.isNight`):
no se dibujan en el patio y E sobre la casa abre el panel del
corral. Igual se los puede atender desde el panel.

## 5. Panel del corral (E sobre la casa o con un animal)

Organismo `AnimalPanel` sobre `DsGridDetailLayout` (la misma grilla +
detalle de INVENTARIO y `DsCollectionTemplate`), solo con `DsColors`:
- Encabezado en una fila: contadores con ícono (animales / capacidad,
  heno en el depósito / `siloMax`, heno en la bolsa) y DEPOSITAR HENO
  (todo el heno de la bolsa, hasta `siloMax`).
- Grilla de 6 columnas anclada arriba a la izquierda, casillas del
  tamaño de INVENTARIO con solo el sprite (borde del color de calidad si
  tiene producto listo). Nada de texto abajo: nombre, especie,
  corazones y estado van en el tooltip.
- Panel derecho con todo el ancho restante (mínimo 340 px): retrato
  grande, nombre (Título), especie (etiqueta), cinco corazones y una
  lista de tildes: comió hoy, lo acariciaron hoy, listo para juntar (o
  en cuántos días), y la línea de calidad (odds de plata y oro).
- Botones en una sola fila fija abajo del panel derecho: DAR DE COMER,
  ACARICIAR, JUNTAR; grises con el motivo en el tooltip si no se puede.
- Nada truncado: los textos largos bajan de línea.

## 6. Ayudantes (granjero de corral)

- Se contratan en la FUENTE RÚNICA con CONTRATAR GRANJERO DE CORRAL (y
  después se elige la construcción en el mapa, como los demás). Uno por
  construcción (`helperPerHome`). Requisito en el botón:
  "Necesitás subir tu oficio de Cultivo a nivel 8" (`helperLevel`). Costo
  igual al granjero de huerta (`town.helperCost`, materiales de huerta).
- Cada vuelta de ayudantes (`helperEverySec` del pueblo) atiende a todos
  los animales de su construcción que falten:
  - come del **depósito de heno** de la construcción (no de la bolsa de
    nadie); sin heno, no come;
  - acaricia con `helperPetGain` (15) y nunca sube el cariño por encima
    de `helperHeartCap` (2 corazones): lo demás es del cariño a mano;
  - junta los productos listos al **cofre** de la construcción (con
    `town.helperXpShare` de la XP al recogerlo, como la huerta).
- **Paridad:** a mano rinde ≥ `gearV2.parityManualEdge` (1.15) × el
  ayudante en valor por día (test `animal_parity_test`: 30 días desde 0
  corazones y en régimen; hoy × 1.17–1.19 en 30 días y × 1.26 en régimen).

## 7. XP y árbol

- Toda la XP va a Cultivo (`life.farm.xp`), con tope por personaje y por
  día del mundo `xpDayCap` (300): un corral ayuda, no reemplaza a la
  huerta, y los tres oficios siguen subiendo parejo (Cultivo ≈ 45 XP/min
  en la huerta, farming.md § 18; un gallinero lleno ≈ 8 XP/min).
- **Árbol de Cultivo:** sin nodos nuevos en esta versión (más adelante,
  si hace falta: "Mano suave" +petGain y "Granja ordenada" + depósito).

## 8. Venta y cocina

- Venta: GRANJA → VENDER (grilla), uno o VENDER TODO; también el puesto
  del jugador si existe la vía (más adelante).
- Cocina: dos recetas nuevas que usan productos de la misma calidad que
  los cultivos elegidos en la olla:
  - Tortilla de campo (vida): 2 huevos + 1 papa de piedra.
  - Flan de leche (ataque): 2 leches + 1 huevo.

## 9. Red, guardado y migración

- **Protocolo 100** (`wire.dart`): `TownBuild` suma `an` (animales) y `hy`
  (heno en el depósito); `FarmSkills` suma `ag` (productos por clave
  `<producto>@<calidad>`), `at` (herramientas de granja) y `hy` (heno);
  acciones `TownOp.buyAnimal / animalFeed / animalPet / animalCollect /
  depositHay` y `FarmShopOp.buyHay / buyRanchTool / makeHay / sellGoods`.
  Todo lo valida el anfitrión (co-op host-authoritative); el corral viaja
  en el pueblo del snapshot.
- **Guardado:** aditivo y tolerante. Un mundo o un perfil viejo sin esos
  campos carga sin animales, sin heno y sin herramientas; las claves de
  especie o producto que no existan se descartan al cargar.

## 10. Previews

`docs/preview/animals/*.png` (con `PREVIEW=1`, test
`test/features/world/animal_preview_test.dart`): gallinero con gallinas,
establo con vaca y oveja, panel del gallinero (`panel.png`), panel del
establo (`panel_barn.png`), tienda GRANJA.
