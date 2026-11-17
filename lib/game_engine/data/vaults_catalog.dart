/// Vaults: salas diseñadas a mano que los generadores incrustan en los
/// pisos (docs/specs/worldgen.md § 6.6). Caracteres:
/// `#` muro, `:` suelo de vault, `,` camino, `~` agua, `+` abertura
/// (camino), `c` cofre (suelo de vault + cofre), `e` élite (suelo de
/// vault + grupo élite opcional). Todas las filas miden lo mismo y el
/// borde es muro o abertura.
class VaultDef {
  final String id;
  final List<String> rows;
  const VaultDef(this.id, this.rows);

  int get width => rows.first.length;
  int get height => rows.length;
}

/// Vaults por tipo: `bosque` (pradera y bosque), `ruinas`, `cavernas`,
/// `fortaleza` (fortaleza y laberinto).
const Map<String, List<VaultDef>> kVaults = {
  'bosque': [
    VaultDef('claro_cofres', [
      '###+###',
      '#:::::#',
      '#:c:c:#',
      '+::e::+',
      '#:::::#',
      '###+###',
    ]),
    VaultDef('estanque', [
      '#####+#####',
      '#:::::::::#',
      '#:~~~:~~~:#',
      '+:~c:e:c~:+',
      '#:~~~:~~~:#',
      '#:::::::::#',
      '#####+#####',
    ]),
    VaultDef('cabana', [
      '#########',
      '#:::#:::#',
      '#:c:#:e:#',
      '#:::+:::#',
      '##+###+##',
    ]),
    VaultDef('anillo', [
      '##+####',
      '#:::::#',
      '#:###:#',
      '#:#c#:+',
      '#:#e#:#',
      '#:::::#',
      '#######',
    ]),
  ],
  'ruinas': [
    VaultDef('cripta', [
      '#########',
      '#:::#:::#',
      '#:c:#:c:#',
      '#:::e:::#',
      '####+####',
    ]),
    VaultDef('altar', [
      '####+####',
      '#:::::::#',
      '#:#:::#:#',
      '+:::e:::+',
      '#:#:c:#:#',
      '#:::::::#',
      '#########',
    ]),
    VaultDef('biblioteca', [
      '###########',
      '#:#:#:#:#:#',
      '#:::::::::+',
      '#c#:#e#:#c#',
      '###########',
    ]),
    VaultDef('patio', [
      '##+##',
      '#:::#',
      '#~c~#',
      '#:e:#',
      '##+##',
    ]),
  ],
  'cavernas': [
    VaultDef('gruta', [
      '##+####',
      '#::::##',
      '#:c::~#',
      '#::e:~#',
      '##::::+',
      '#######',
    ]),
    VaultDef('lago_helado', [
      '####+####',
      '#:::::::#',
      '#:~~~~~:#',
      '+:~c:e~:+',
      '#:~~~~~:#',
      '#:::::::#',
      '#########',
    ]),
    VaultDef('nido', [
      '#######',
      '#c:::c#',
      '#::e::#',
      '##:::##',
      '###+###',
    ]),
    VaultDef('grieta', [
      '##########',
      '+::::::::#',
      '#####::e:#',
      '#c:::::::+',
      '##########',
    ]),
  ],
  'fortaleza': [
    VaultDef('armeria', [
      '#########',
      '#c:#:#:c#',
      '#:::::::#',
      '#:::e:::#',
      '####+####',
    ]),
    VaultDef('salon_trono', [
      '#####+#####',
      '#:::::::::#',
      '#:#:#:#:#:#',
      '#:::::::::#',
      '#:#:#e#:#:#',
      '#::::c::::#',
      '###########',
    ]),
    VaultDef('calabozo', [
      '#######',
      '#c#e#c#',
      '#:#:#:#',
      '#:::::+',
      '#######',
    ]),
    VaultDef('torre', [
      '##+##',
      '#:::#',
      '#:e:#',
      '#:c:#',
      '#####',
    ]),
  ],
};
