// Phased zone boss sprites (docs/specs/bosses.md § v0.50) in the same
// pixel pipeline as tool/export_sprites.dart (1 px outline, X shaded),
// all facing left. Run `dart run tool/export_boss_sprites.dart` from the
// project root: writes the Rey Limo phases and the boss material icons.
// The manifest maps each id to its file; the game never names a file.
import 'dart:io';

import 'export_sprites.dart' show RgbaImage, encodePng, makeSprite;

/// Rey Limo, phase 1: crowned king slime.
const kReyLimoKing = [
  '.......C...C...C......',
  '.......CC.CCC.CC......',
  '.......CCCCJCCCC......',
  '.......CCCCCCCCC......',
  '.....XXXXXXXXXXXXX....',
  '...XXLLXXXXXXXXXXXXX..',
  '..XXLXXXXXXXXXXXXXXXX.',
  '..XLXXWWWXXXXXWWWXXXX.',
  '.XXXXXWOWXXXXXWOWXXXXX',
  '.XXXXXWOWXXXXXWOWXXXXX',
  '.XXXXXXXXXXXXXXXXXXXXX',
  '.XXXXXXXMMMMMMXXXXXXXX',
  'XXXXXXXXXMMMMXXXXXXXXX',
  'XXXXXXXXXXXXXXXXXXXXXX',
  'XXXXXXXXXXXXXXXXXXXXXX',
  '.XXXXXXXXXXXXXXXXXXXX.',
  '..XXXDXXXXXXXXXXDXXX..',
  '.....D..........D.....',
];

/// Phase 2 «División»: cracked down the middle, crown askew.
const kReyLimoSplit = [
  '....C...C...C.........',
  '....CC.CCC.CC.........',
  '.....CCCCJCCCC........',
  '......CCCCCCCCC.......',
  '.....XXXXXXXXKXXXX....',
  '...XXLLXXXXXXKXXXXXX..',
  '..XXLXXXXXXXKXXXXXXXX.',
  '..XLXXWWWXXXKXWWWXXXX.',
  '.XXXXXWOWXXKXXWOWXXXXX',
  '.XXXXXWOWXXKXXWOWXXXXX',
  '.XXXXXXXXXXKXXXXXXXXXX',
  '.XXXXXXXMMMKMMXXXXXXXX',
  'XXXXXXXXXMKMMXXXXXXXXX',
  'XXXXXXXXXXK.XXXXXXXXXX',
  'XXXXXXXXXX...XXXXXXXXX',
  '.XXXXXXXXX...XXXXXXXX.',
  '..XXDXXXX.....XXXDXX..',
  '....D...D.....D...D...',
];

/// Phase 3 «Marea Real»: violet tide, red eyes, glowing crown.
const kReyLimoTide = [
  '......G.C..C..C.G.....',
  '.......CC.CCC.CC......',
  '.......CCCCJCCCC......',
  '.......CCCCCCCCC......',
  '.....XXXXXXXXXXXXX....',
  '...XXLLXXXXXXXXXXXXX..',
  '..XXLBBBXXXXXXXBBBXXX.',
  '..XLXXRRRXXXXXRRRXXXX.',
  '.XXXXXRORXXXXXRORXXXXX',
  '.XXXXXXRXXXXXXXRXXXXXX',
  '.XXXXXXXXXXXXXXXXXXXXX',
  '.XXXXXXMMMMMMMMXXXXXXX',
  'XXXXXXXMTMTMTMMXXXXXXX',
  'XXXXXXXXXXXXXXXXXXXXXX',
  'XXXXXXXXXXXXXXXXXXXXXX',
  'AXXXXXXXXXXXXXXXXXXXXA',
  'AAXXXAXXXXXXXXXXAXXXAA',
  '.AAA.AA....AA...AA.AAA',
];

/// Corona de Gel (`boss_gelcrown`): the crown on a gel drop.
const kGelCrownIcon = [
  '..............',
  '..C...C...C...',
  '..CC.CCC.CC...',
  '..CCCCJCCCC...',
  '..CCCCCCCCC...',
  '.GGGGGGGGGGG..',
  'GGLLGGGGGGGGG.',
  'GLGGGGGGGGGGGG',
  'GGGGGGGGGGGGGG',
  'GGGGGGGGGGGGGG',
  '.GGGGGGGGGGGG.',
  '..GGDGGGGDGG..',
  '....D....D....',
  '..............',
];

const _crown = {'C': '#f5c542', 'J': '#e8434b'};

const kReyLimoPalette = {
  ..._crown,
  'X': '#e1b12c',
  'L': '#fbe38a',
  'W': '#ffffff',
  'O': '#1b1b1b',
  'M': '#5c3a12',
  'D': '#c99520',
};

const kReyLimoSplitPalette = {
  ..._crown,
  'X': '#d6a52a',
  'L': '#f6dc86',
  'W': '#ffffff',
  'O': '#1b1b1b',
  'M': '#5c3a12',
  'K': '#6b4a12',
  'D': '#b8861c',
};

const kReyLimoTidePalette = {
  'C': '#ffd23f',
  'J': '#3fe0d0',
  'G': '#fff3a0',
  'X': '#8e3fb5',
  'L': '#c98ae6',
  'B': '#2a0f3a',
  'R': '#ff3b3b',
  'O': '#2a0000',
  'M': '#2a0f3a',
  'T': '#f2f2f2',
  'A': '#3fb6e0',
};

const kGelCrownPalette = {
  ..._crown,
  'G': '#e1b12c',
  'L': '#fbe38a',
  'D': '#c99520',
};

/// Published path → image.
Map<String, RgbaImage> buildBossSprites() => {
      'enemies/reyLimo/king.png': makeSprite(kReyLimoKing, kReyLimoPalette),
      'enemies/reyLimoFase2/idle.png':
          makeSprite(kReyLimoSplit, kReyLimoSplitPalette),
      'enemies/reyLimoFase3/idle.png':
          makeSprite(kReyLimoTide, kReyLimoTidePalette),
      'items/vida_mine_boss_gelcrown.png':
          makeSprite(kGelCrownIcon, kGelCrownPalette),
    };

void main() {
  final root = Directory('assets/sprites');
  if (!root.existsSync()) {
    stderr.writeln('Run it from the project root (${root.path} missing).');
    exitCode = 1;
    return;
  }
  for (final e in buildBossSprites().entries) {
    final f = File('${root.path}/${e.key}');
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(encodePng(e.value));
    stdout.writeln('${f.path} (${e.value.width}x${e.value.height})');
  }
}
