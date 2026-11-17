# Spec (aprobada, sin implementar): Loot con modificadores y filtros

Pedido del dueño: "que el loot sea como POE, que se puedan crear filtros,
que las armas tengan modificadores". Se toman las **mecánicas** del género
(bases + afijos aleatorios por rareza, filtros de loot editables); nombres,
textos y contenido son propios de Ecos del Tiempo.

Estado: diseño aprobado por el dueño (decisiones en § 7); falta
implementar.

## 1. Bases

- Las 32 armas actuales (`WEAPONS`) pasan a ser **bases**: tipo, clase,
  requisitos, fórmula ATQ/MAG, peso, escudo y habilidades quedan igual.
- Cada base tiene **nivel de objeto mínimo** (= su tier actual × 6) y
  puede traer un **implícito** fijo (p. ej. escudos: +DEF; arcos: +crítico).
- Una instancia de arma (`ItemInstance`) guarda: base, rareza, nivel de
  objeto, lista de afijos con sus valores tirados, mejoras de forja y
  habilidad fusionada. El inventario pasa de lista de ids a lista de
  instancias (el perfil viejo se migra: cada id → instancia Normal).

## 2. Rarezas

| Rareza | Afijos | Color del nombre |
|---|---|---|
| Normal | 0 | blanco |
| Mágica | 1–2 (máx. 1 prefijo + 1 sufijo) | azul |
| Rara | 3–6 (máx. 3 + 3), nombre aleatorio de 2 palabras | amarillo |
| Única | fijos, diseñados a mano, con un efecto especial | naranja |

Probabilidad base al soltar: Normal 70%, Mágica 24%, Rara 5.5%, Única 0.5%,
modificada por el nivel de zona y por élites/jefes (élite ×3 a rara, jefe
garantiza mágica o mejor).

## 3. Afijos

- **Prefijos** (ofensivos/base): % ATQ, % MAG, daño plano, % crítico,
  multiplicador de crítico, velocidad, stacks extra de Quemadura /
  Veneno / Congelación al aplicar, carga de ULT.
- **Sufijos** (atributos/defensa): +VIT/ESP/AGI/FUE/DES, +vida, +maná,
  +DEF, % curación recibida, regeneración por turno, resistencia a
  estados (menos stacks recibidos), robo de vida.
- Cada afijo tiene **tiers** por nivel de objeto (p. ej. % ATQ: T5 5–9%
  nivel 1, ..., T1 35–40% nivel 30) y un **peso** de aparición; algunos
  solo salen en ciertos tipos de arma (stacks de Congelación: báculos,
  tomos, rifles; DEF: escudos).
- Los afijos se aplican en `StatsCalculator` en un paso nuevo, **antes**
  del árbol de pasivas, y aparecen en el desglose del log de combate
  ("ATQ 21 = base 15 + 40% arma").

## 4. Fuentes de loot

- Enemigos al morir (por grupo), cofres, élites y jefes.
- **Loot por jugador** (instanciado): cada jugador ve y recoge su propio
  loot, sin peleas en co-op.
- El loot cae en el mapa como objeto con su nombre visible (según el
  filtro), se recoge caminando encima o con E.

## 4b. Inventario y dar objetos a otros jugadores

Inventario de casillas por personaje, al estilo de los RPG de grupo
donde cada miembro carga lo suyo y se lo puede pasar a otro:
- Grilla de casillas (p. ej. 8×5) por jugador; cada objeto ocupa 1
  casilla; materiales de crafteo y pociones se apilan.
- Panel de inventario con el propio a la izquierda y, con pestañas, el
  de cada compañero de sala a la derecha.
- **Dar**: arrastrar un objeto del propio inventario al de un compañero
  (o botón "Dar a..."). Llega al instante si el otro tiene lugar; si no,
  se rechaza con el motivo. No hace falta estar cerca.
- Solo se puede dar fuera de batalla. El host valida (`GiveItemAction`),
  como todas las acciones.
- Se puede soltar un objeto al piso; queda visible para todos y lo
  levanta cualquiera (única forma de loot compartido).
- Ver el inventario de un compañero es solo lectura: no se le puede
  sacar nada.

## 5. Crafteo

Tres materiales que también caen como loot.
- **Esquirla del Eco**: vuelve a tirar los valores de los afijos.
- **Cristal de Era**: agrega un afijo (si hay lugar).
- **Prisma Roto**: convierte Normal → Mágica o Mágica → Rara.
La forja actual (mejoras por stat) y la fusión de habilidades se mantienen.

## 6. Filtros de loot

- El jugador crea **reglas** en orden; gana la primera que coincide.
- Condiciones: rareza, clase/tipo de arma, base, nivel de objeto ≥ / ≤,
  "tiene afijo X (tier ≤ N)", cantidad de afijos, material de crafteo,
  "sirve para mi clase".
- Acciones: **mostrar / ocultar**, color del texto, color del borde, color
  de fondo, tamaño del texto, sonido (de un catálogo) y un ícono en el
  minimapa.
- Se editan en un panel del juego (lista de reglas con ▲▼, agregar,
  duplicar, borrar) y se guardan en el perfil.
- Formato de texto exportable/importable para compartirlo, p. ej.:

```
Mostrar
  Rareza >= Rara
  Clase Guerrero
  Color 255 210 60
  Sonido alerta
Ocultar
  Rareza Normal
  NivelObjeto < 10
```

- Filtro por defecto incluido (oculta Normales de nivel bajo, resalta
  raras y únicas).

## 7. Decisiones del dueño

1. Loot **por jugador**, con inventario de casillas por personaje y la
   posibilidad de **dar objetos** a otros jugadores (§ 4b).
2. Crafteo **sí**, con los 3 materiales de § 5.

Valores por defecto (cambiables): la tienda sigue vendiendo bases
Normales; 2 únicas por clase para empezar.
