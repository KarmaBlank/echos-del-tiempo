/// Press Start 2P cubre ASCII y Latin-1 (á, ñ, ¡, ×, ½, ·), pero no
/// flechas ni signos tipográficos. Esto los cambia por equivalentes que
/// la fuente sí tiene, para que el texto no mezcle fuentes.
String retroText(String s) => s
    .replaceAll('→', '>')
    .replaceAll('←', '<')
    .replaceAll('−', '-')
    .replaceAll('…', '...')
    .replaceAll('—', '-');
