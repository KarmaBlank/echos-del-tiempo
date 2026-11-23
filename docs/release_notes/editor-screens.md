# Ecos del Tiempo vX.Y.Z

## Editor: PANTALLAS
- **Área nueva PANTALLAS en el Editor:** armás una pantalla del juego
  sobre un lienzo a la resolución del juego, arrancando por la pantalla de
  TÍTULO.
- **Paleta del sistema de diseño** con subpestañas ÁTOMOS, MOLÉCULAS,
  ORGANISMOS y PLANTILLAS. Sale de un registro: cuando se suma un
  componente nuevo al sistema de diseño, aparece solo.
- **Lienzo:** tocás para elegir, arrastrás para mover (con imán a una
  grilla de 8 px), estirás desde la esquina, mandás ADELANTE / ATRÁS,
  DUPLICAR, BORRAR y DESHACER.
- **Vista previa** en tamaños comunes de ventana (de 1024×768 a
  2560×1440) con las anclas aplicadas.
- **Inspector:** texto, variante y tamaño (solo los del componente, nunca
  colores sueltos), estilo de texto del sistema, rol (título, subtítulo,
  texto, detalle), alineación, anclas, orden de foco, acción, fuente de
  datos o hueco, y la caja en números.
- **Organismos con datos:** al poner una grilla de ítems elegís de dónde
  saca los datos ("Inventario del jugador", "Semillas del ayudante"...) y
  ves qué aparecería, con datos de ejemplo.
- **VERIFICAR:** revisa contraste, tamaño mínimo de texto, jerarquía de
  títulos, rol contra estilo, tamaño de los botones, texto recortado,
  orden de foco con teclado y botones deshabilitados en gris. Cada aviso
  trae su arreglo y, cuando se puede, el botón APLICAR.
- **GUARDAR** deja la pantalla como datos en
  `assets/layouts/title.screen.json`.

## Pantalla de título
- **Nueva disposición:** nombre del juego arriba, el bloque de mundo,
  personajes y sala en un panel al centro, y CONFIGURACIÓN, SALIR DEL
  JUEGO y el "?" abajo a la derecha. Se acomoda al tamaño de la ventana.
- El juego dibuja el título desde el archivo que guarda el Editor; si
  falta, usa la pantalla de siempre.
