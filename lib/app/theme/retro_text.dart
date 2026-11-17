/// Press Start 2P cubre ASCII, Latin-1 en minúscula (á, ñ, ¡, ×, ½, ·, »)
/// y algunos símbolos (`★ → ← ♥ ♦ ▶ • — …`), pero no emojis, `✦ ⚔ ⏱ ⏳
/// ✔ ✘ ₵ 🛡`, ni dibuja bien las MAYÚSCULAS acentuadas ("MISIóN"). Esto
/// los cambia por equivalentes que la fuente sí tiene, para que el texto
/// no mezcle fuentes. Ver docs/specs/ui_style.md § "Texto y la fuente".
String retroText(String s) => s
    .replaceAll('−', '-')
    .replaceAll('▸', '>')
    .replaceAll('₵', '\$')
    .replaceAll('✦', '♦')
    .replaceAll(' ⏳', ' (retrasa)')
    .replaceAll('⏳ ', '')
    .replaceAll('⏳', '')
    .replaceAll('✔', 'ok')
    .replaceAll('✘', 'x')
    .replaceAll('⚔ ', '')
    .replaceAll('⏱ ', '')
    .replaceAll('🛡', '')
    .replaceAll('ⓘ', '')
    .replaceAll('Á', 'A')
    .replaceAll('É', 'E')
    .replaceAll('Í', 'I')
    .replaceAll('Ó', 'O')
    .replaceAll('Ú', 'U');
