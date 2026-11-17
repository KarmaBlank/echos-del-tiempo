/// Press Start 2P cubre ASCII y Latin-1 en minúscula (á, ñ, ¡, ×, ½, ·),
/// pero no flechas, signos tipográficos ni las MAYÚSCULAS acentuadas (las
/// dibuja como minúsculas: "MISIóN"). Esto los cambia por equivalentes
/// que la fuente sí tiene, para que el texto no mezcle fuentes.
String retroText(String s) => s
    .replaceAll('→', '>')
    .replaceAll('←', '<')
    .replaceAll('−', '-')
    .replaceAll('…', '...')
    .replaceAll('—', '-')
    .replaceAll('★', '*')
    .replaceAll('▸', '>')
    .replaceAll('₵', '\$')
    .replaceAll('Á', 'A')
    .replaceAll('É', 'E')
    .replaceAll('Í', 'I')
    .replaceAll('Ó', 'O')
    .replaceAll('Ú', 'U');
