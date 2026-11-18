# Feature: endgame

Portal del Eco (pestañas ECOS y ATLAS) y Atlas del Tiempo de la cuenta.
Spec: docs/specs/ecos_atlas.md (y endgame.md § 1, § 2, § 4).

- domain/   — textos y motivos de bloqueo (puros, sin Flutter)
- presentation/ — panel del portal y vista del Atlas

Las reglas viven en `game_engine/` (`EcoRules`, `AtlasRules`); el Atlas
se guarda en la cuenta (`features/characters`, `AccountAtlasStore`).
