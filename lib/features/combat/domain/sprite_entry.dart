import 'dart:typed_data';

import '../../../core/audio/sfx_overrides.dart';
import '../../../core/fx/fx_overrides.dart';

/// Categoría de un sprite en el Editor (docs/specs/game_editor.md § 3.1).
enum SpriteCategory {
  characters('PERSONAJES', 'characters'),
  enemies('ENEMIGOS', 'enemies'),
  bosses('JEFES', 'enemies'),
  items('ARMAS E ÍTEMS', 'items'),
  tiles('TILES', 'tiles'),
  ui('UI', 'ui'),
  fx('EFECTOS', 'fx');

  const SpriteCategory(this.label, this.section);

  /// Nombre visible.
  final String label;

  /// Sección del sprite_manifest.yaml de donde sale.
  final String section;

  /// La escena de contexto es un mapa (si no, una batalla).
  bool get onMap => this == tiles;
}

/// Una entrada del sprite_manifest.yaml (un frame). Solo datos: la arma
/// [SpriteCatalog], que es el único que lee el manifest.
class SpriteEntry {
  const SpriteEntry({
    required this.section,
    required this.key,
    required this.animation,
    required this.category,
    this.path,
    this.expectedSize,
  });

  /// Sección del manifest (`characters`, `enemies`, `items`, …).
  final String section;

  /// Clave dentro de la sección (`guerrero`, `slime`, `espada`).
  final String key;

  /// Frame (`idle`).
  final String animation;
  final SpriteCategory category;

  /// Ruta relativa a `assets/sprites/`, o `null` si todavía se dibuja en
  /// código (`procedural: true`).
  final String? path;

  /// `size: [w, h]` del manifest (si lo declara). Para los que tienen PNG,
  /// el tamaño esperado sale del PNG del repo.
  final (int, int)? expectedSize;

  /// Id lógico estable: `<sección>.<clave>.<frame>`.
  String get id => '$section.$key.$animation';

  bool get procedural => path == null;

  /// Carpeta de `assets/sprites/` donde se publica un PNG nuevo de una
  /// entrada procedural (`fx` → `effects/`, la carpeta ya existente).
  String get publishPath =>
      path ?? '${section == 'fx' ? 'effects' : section}/$key.png';

  /// Coincide con la búsqueda (id, clave, ruta o categoría; sin
  /// mayúsculas ni tildes).
  bool matches(String query) {
    final q = foldSearch(query.trim());
    if (q.isEmpty) return true;
    final hay = foldSearch('$id $key ${path ?? ''} ${category.label}');
    return q.split(RegExp(r'\s+')).every(hay.contains);
  }

  @override
  String toString() => id;
}

/// Minúsculas y sin tildes (búsquedas del Editor).
String foldSearch(String s) {
  const from = 'áéíóúüñ';
  const to = 'aeiouun';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString();
}

/// Capa de overrides locales que consulta [SpriteCatalog] antes que el
/// asset (game_editor.md § 4.2). La implementa el almacén de overrides
/// del Editor (disco); el juego normal no tiene ninguna.
abstract class SpriteOverrideSource {
  /// Ids ([SpriteEntry.id]) con override.
  Set<String> get overriddenIds;

  /// Bytes PNG del override de [id], o `null`.
  Future<Uint8List?> read(String id);

  /// Vuelve a leer el índice de overrides del disco.
  Future<void> refresh();
}

/// Override local de las perillas del arte procedural
/// (`overrides/procedural.yaml`, game_editor.md § 7.5).
abstract class ProceduralOverrideSource {
  /// Texto del `procedural.yaml` del override, o `null`.
  Future<String?> readProcedural();
}

/// Override local de las variantes de NPC (`overrides/npc_variants.yaml`,
/// docs/specs/npc_variants.md § 5). Lo implementa la carpeta de overrides
/// del Editor; quien no lo implementa usa solo el del repo.
abstract class NpcVariantsOverrideSource {
  /// Texto del `npc_variants.yaml` del override, o `null`.
  Future<String?> readNpcVariants();

  /// Guarda el `npc_variants.yaml` del override.
  Future<void> putNpcVariants(String yaml);
}

/// Local override of the vegetation presets
/// (`overrides/vegetation_presets.yaml`, procedural_vegetation.md § 6).
abstract class VegetationOverrideSource {
  /// Text of the override's `vegetation_presets.yaml`, or `null`.
  Future<String?> readVegetation();

  /// Saves the override's `vegetation_presets.yaml`.
  Future<void> putVegetation(String yaml);
}

/// Overrides que el Editor puede escribir (game_editor.md § 3.1 y § 4).
/// También guarda los overrides de animaciones (paso 2, § 4.2): misma
/// carpeta, mismo paquete de arte.
///
/// Y los de sonido (game_editor.md § 7.6): `sfx/<id>.wav|ogg`.
abstract class EditableSpriteOverrides
    implements
        SpriteOverrideSource,
        EditableFxOverrides,
        ProceduralOverrideSource,
        EditableSfxOverrides {
  /// Guarda el `procedural.yaml` del override (perillas, § 7.5).
  Future<void> putProcedural(String yaml);

  /// Borra el override de perillas.
  Future<void> removeProcedural();

  /// Fusiona el override de perillas en
  /// `<repo>/assets/sprites/procedural.yaml` y lo borra. `false` si no
  /// había nada.
  Future<bool> publishProcedural(String repoRoot);

  /// Carpeta de los overrides (para mostrarla).
  String get root;

  Future<void> put(String id, Uint8List png);
  Future<void> remove(String id);

  /// Zip con todos los overrides (paquete de arte).
  Future<Uint8List> exportPack();

  /// Instala un paquete; devuelve los ids. [FormatException] si es
  /// inválido.
  Future<List<String>> importPack(Uint8List zip);

  /// Copia los overrides de [entries] al repo, actualiza el manifest y
  /// los borra de la carpeta local. Devuelve los ids publicados.
  Future<List<String>> publish(String repoRoot, List<SpriteEntry> entries);
}
