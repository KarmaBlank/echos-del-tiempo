# Ecos del Tiempo — brief de sprites de personajes

¡Gracias por ayudar! Esto es todo lo que necesitás para dibujar los
personajes. El estilo es pixel art simple, como los actuales (ver
`referencia_personajes.png`).

## Qué dibujar (12 personajes)

| Clase | Base | Ascensión 1 | Ascensión 2 |
|---|---|---|---|
| Guerrero | Guerrero | Berserker | Señor de la Guerra |
| Maga | Maga | Cronomante | Elementalista |
| Tirador | Tirador | Francotirador | Trampero |
| Paladín | Paladín | Templario | Guardián |

Cada **ascensión** es la misma silueta de su clase, pero "transformada"
(más imponente). Ideas de cada una:

- **Berserker:** ojos rojos brillantes, pintura de guerra, hombreras de
  hierro, capa negra desgarrada.
- **Señor de la Guerra:** yelmo dorado con penacho carmesí, capa carmesí,
  cuerno de guerra.
- **Cronomante:** capucha verde azulada, esfera de reloj en el pecho,
  túnica larga.
- **Elementalista:** pelo de fuego, túnica de tres colores (fuego, hielo,
  veneno).
- **Francotirador:** capucha y capa verde oscuro, rifle largo a la
  espalda, mira con destello.
- **Trampero:** gorro de piel con cola, manto de piel, correas ámbar,
  un cepo en el cinto.
- **Templario:** tabardo blanco con un sol, diadema dorada, capa crema.
- **Guardián:** yelmo cerrado con visor cian, hombreras anchas, tabardo
  azul.

Los colores son libres: podés usar los actuales o los tuyos.

## Dos vistas por personaje

- **De lado (`side.png`):** mirando a la **derecha** (el juego la espeja
  para la izquierda). Se usa en las batallas y al caminar de lado.
- **De frente (`front.png`):** mirando a la cámara. Se usa al caminar
  hacia arriba/abajo en el mapa y en la selección de personaje.

## Formato (importante)

- **Tamaño:** cada PNG mide **14 × 18 píxeles**. La zona de dibujo es de
  **12 × 16** y se deja **1 px alrededor para el contorno** (ver
  `plantilla_14x18_guia.png`; `plantilla_14x18_vacia.png` es el lienzo
  vacío listo para usar).
- **1 píxel del PNG = 1 píxel del sprite.** No lo agrandes: el juego lo
  escala solo.
- **Fondo transparente**, colores planos, **sin antialias ni
  semitransparencias**.
- **Los pies van en la última fila de la zona de dibujo** (la línea roja
  de la guía) y el personaje centrado. Todas las vistas y todas las
  ascensiones tienen que apoyar los pies en la misma fila, para que no
  "salten" en pantalla.
- **SIN arma en la mano.** El juego dibuja el arma aparte, según lo que
  tengas equipado (espada, báculo, arco, escudo…). Si el sprite la trae,
  se verían dos armas. Accesorios a la espalda (rifle, cepo, cuerno)
  están bien.
- **No hace falta animar:** el juego hace el balanceo, la estocada, la
  caída y la defensa moviendo el sprite.

## Cómo entregar

Una carpeta por clase con estos nombres (en minúsculas, sin tildes):

```
guerrero/   side.png  front.png
            berserker_side.png  berserker_front.png
            senorGuerra_side.png  senorGuerra_front.png
maga/       side.png  front.png
            cronomante_side.png  cronomante_front.png
            elementalista_side.png  elementalista_front.png
tirador/    side.png  front.png
            francotirador_side.png  francotirador_front.png
            trampero_side.png  trampero_front.png
paladin/    side.png  front.png
            templario_side.png  templario_front.png
            guardian_side.png  guardian_front.png
```

Si querés, empezá con **un solo personaje** (por ejemplo el Guerrero, de
lado y de frente) y lo probamos en el juego antes de hacer el resto.

## Opcional, para más adelante

- **Auras de ascensión** (efecto detrás del personaje): PNG de **24 × 26**
  sin contorno, una por ascensión.
- **Enemigos:** se pueden rehacer después con el mismo método.
