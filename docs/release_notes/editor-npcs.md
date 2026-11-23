# Editor: habitantes (NPC)

## Novedades

- **Nueva área NPC en el Editor.** Grilla con los diez habitantes (los
  cinco que se mudan y los cinco pescadores nativos) y, a la derecha, su
  ficha: rol, bioma, si se muda o es arraigado, sprite y los umbrales de
  amistad.
- **DIÁLOGO.** Saludos, árbol de temas y sub-temas con sus condiciones
  (charlas, pedidos, amistad y dónde: en su bioma o en el pueblo), lo que
  dicen los arraigados al invitarlos y las frases de la orilla. Todo se
  escribe a mano: agregar, borrar y reordenar, con contador de
  caracteres que avisa si una línea pasa de 90. PROBAR abre la charla en
  el mismo cuadro de diálogo del juego, con el avance que elijas.
- **PEDIDOS.** La cadena de encargos de cada habitante se edita paso por
  paso. Las órdenes, pedidos del pueblo, encargos de forja de Brann y el
  pedido del día de los pescadores se muestran como reglas (cada cuántos
  días, niveles de oficio, tamaños, recompensas) y se ajustan ahí mismo;
  GENERAR EJEMPLOS tira una semana de pedidos para el nivel que elijas.
- **Los textos ahora son datos.** Charlas y cadenas de encargos viven en
  `assets/data/npcs/npcs.json`; el juego los lee al arrancar y, si el
  archivo falta o está roto, usa los de siempre. Nada cambió en lo que
  dicen: el contenido se migró tal cual.
- **Balance → Pesca.** Los números de Pesca (incluido el pedido del día
  del pescador) se pueden ajustar por el parche de balance.
