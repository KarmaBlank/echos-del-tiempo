# Spec (aprobada, sin implementar): Generación de mundo estilo roguelike de zonas

Pedido del dueño: "la generación de mundo que sea como Tales of Maj'Eyal
(ToME)". Se toman las **mecánicas** del género (mapa del mundo con zonas,
cada zona con varios pisos y su propio generador según el tipo de lugar,
salas pre-diseñadas incrustadas); los lugares, nombres y arte son propios
de Ecos del Tiempo.

Estado: diseño aprobado por el dueño (decisiones en § 4); falta
implementar. Reemplaza a `world.md` § "genMap" cuando se apruebe
(el generador actual queda como generador "ruinas clásicas").

## 1. Mapa del mundo

- Un mapa grande de tiles (pradera, bosque, montaña, agua, caminos)
  generado una vez por partida/sala con semilla, con las **entradas de
  zona** ubicadas por reglas (cerca de caminos, separadas entre sí).
- El grupo se mueve junto por el mapa del mundo (el host decide; los
  clientes ven el movimiento). Sin combate en el mapa del mundo, salvo
  encuentros aleatorios opcionales **[?]**.
- El lobby actual pasa a ser el **pueblo** inicial dentro del mapa.

## 2. Zonas

Cada zona tiene: tipo, rango de nivel, cantidad de pisos (2–5), generador
por piso, tabla de enemigos por piso y jefe en el último.

| Tipo | Generador | Idea |
|---|---|---|
| Bosque / pradera | ruido + caminos | campo abierto con arboledas que forman pasillos naturales |
| Cavernas | autómata celular | cuevas orgánicas, conectividad asegurada por flood fill |
| Ruinas | salas + pasillos (el `genMap` actual) | el generador del prototipo, intacto |
| Laberinto temporal | laberinto (backtracker) con salas | pasillos de 1–2 tiles, trampas de tiempo |
| Abismo | islas sobre vacío unidas por puentes | caer = volver al inicio del piso |

- **Vaults**: salas diseñadas a mano (archivo de texto con tiles) que el
  generador incrusta con cierta probabilidad; traen cofres/élites.
- Escaleras para bajar de piso; volver a subir permitido.
- Los mapas se generan por semilla y son idénticos para todos los
  jugadores (el host manda la semilla, como hoy).

## 3. Relación con las misiones

Se mantienen mostrador, votación y objetivos; una misión = "andá a la
zona X y cumplí el objetivo en sus pisos". Los objetivos actuales
(grupos, sellos, fragmentos) se reparten entre los pisos y el jefe queda
en el último.

## 4. Decisiones del dueño

1. **Mapa del mundo + zonas con pisos** (§ 1 y § 2).
2. **Se mantienen las misiones**, dentro de las zonas (§ 3).

Valores por defecto (cambiables): sin encuentros aleatorios en el mapa
del mundo; si el grupo cae, la misión falla como hoy (rango D, vuelta al
pueblo).
