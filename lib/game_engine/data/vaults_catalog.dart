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
/// `fortaleza`, `laberinto`, `grieta`, `abismo` (abismo y corazón) y
/// `cementerio`.
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
  // ---- v0.3.0 (worldgen.md § 8.1): `o` engranaje, `%` lava, `=` puente,
  // `_` vacío, `t` lápida. El borde puede ser `#`, `+` o `_`.
  'laberinto': [
    VaultDef('relojeria', [
      '###+###',
      '#o:::o#',
      '#::c::#',
      '+::e::+',
      '#o:::o#',
      '#######',
    ]),
    VaultDef('engranajes', [
      '#########',
      '#:o:::o:#',
      '#:::e:::#',
      '+:o:c:o:+',
      '#:::::::#',
      '####+####',
    ]),
    VaultDef('campanario', [
      '#####+#####',
      '#:::::::::#',
      '#:o:::::o:#',
      '#:::oeo:::#',
      '#:c:::::c:#',
      '###########',
    ]),
    VaultDef('pendulo', [
      '##+##',
      '#:::#',
      '#:o:#',
      '#:e:#',
      '#:c:#',
      '##+##',
    ]),
  ],
  'grieta': [
    VaultDef('forja', [
      '#########',
      '#:::%:::#',
      '#:c:=:e:#',
      '+:::%:::+',
      '#########',
    ]),
    VaultDef('isla_magma', [
      '####+####',
      '#:::::::#',
      '#:%%=%%:#',
      '#:%:c:%:#',
      '#:%:e:%:#',
      '#:%%%%%:#',
      '#:::::::#',
      '#########',
    ]),
    VaultDef('respiradero', [
      '#######',
      '#c:%:c#',
      '#::%::#',
      '#::=::#',
      '#:e%::#',
      '#+#####',
    ]),
    VaultDef('brasero', [
      '##+##',
      '#:::#',
      '#%c%#',
      '#:e:#',
      '##+##',
    ]),
  ],
  'abismo': [
    VaultDef('islote', [
      '___+___',
      '_:::::_',
      '+:c:e:+',
      '_:::::_',
      '___+___',
    ]),
    VaultDef('santuario', [
      '____+____',
      '_:::::::_',
      '_:#:::#:_',
      '+:::e:::+',
      '_:#:c:#:_',
      '_:::::::_',
      '_________',
    ]),
    VaultDef('gemelas', [
      '_________',
      '_:::_:::_',
      '+:c:=:e:+',
      '_:::_:::_',
      '_________',
    ]),
    VaultDef('mirador', [
      '__+__',
      '_:::_',
      '_:c:_',
      '_:e:_',
      '_:::_',
      '__+__',
    ]),
  ],
  'cementerio': [
    VaultDef('mausoleo', [
      '####+####',
      '#:t:::t:#',
      '#:::e:::#',
      '#:t:c:t:#',
      '#########',
    ]),
    VaultDef('fosa', [
      '_______',
      '_t:::t_',
      '+::c::+',
      '_t:e:t_',
      '_______',
    ]),
    VaultDef('cripta_eras', [
      '#######',
      '#c:t:c#',
      '#:::::#',
      '#t:e:t#',
      '###+###',
    ]),
    VaultDef('panteon', [
      '___+___',
      '_t:::t_',
      '_:t:t:_',
      '_::e::_',
      '_:c:c:_',
      '_______',
    ]),
  ],
};
