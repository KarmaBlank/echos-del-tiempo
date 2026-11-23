# Aviso de versión nueva en el HUD del mundo (v0.37.3)

- Si el actualizador (`lib/core/update`) supo en esta ejecución que hay
  una versión nueva (`UpdateController.newerVersion` ≠ `null`), el HUD
  del mundo muestra arriba a la izquierda, justo debajo de la fila de
  botones del menú, `Hay una nueva actualización`.
- El texto late suave en bucle (opacidad 45 % ↔ 100 %, 1,2 s).
- No hace nada al clic; solo tiene una X (`DsButton` compacto) que lo
  cierra por esta partida (vuelve al entrar de nuevo al mundo).
- Átomos del sistema de diseño: fondo `DsColors.surface`, borde
  `DsColors.border`, texto `DsText.detail(DsColors.reward)`; sin negrita
  ni bordes redondeados.
- Va dentro del bloque izquierdo de la fila de arriba, así los objetivos
  de misión se corren abajo y no se superponen.

## Nombre sobre los jugadores en el mapa

- Encima de cada jugador se dibuja solo su nombre (sin ascensión ni
  título), un paso más chico que antes (tamaño 5 en vez de 6).
