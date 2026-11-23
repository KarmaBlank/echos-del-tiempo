# Armería y Forja con cara propia

- La **ARMERÍA** del pueblo ya no usa la casa provisoria: ahora es una
  tienda de piedra con un emblema de espada cruzada sobre dos escudos en
  el frente, y estantes de espadas en las ventanas. Se lee de un vistazo
  en el mapa.
- La **FORJA** tiene un puesto nuevo: fragua de ladrillo con brasas, un
  yunque grande con la barra al rojo y el martillo, y un barril para
  templar. Antes se pintaba desde el código; ahora es un sprite más.
- Los dos salen de `tool/export_building_sprites.dart` y se registran en
  `sprite_manifest.yaml` (`items.vida_armeria`, `items.vida_forja`): el
  arte se cambia ahí sin tocar Dart.
- Los carteles al pasar el mouse y los avisos de `[E]` siguen iguales.
