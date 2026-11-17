# Feature: missions

- domain/   — entidades + casos de uso puros (sin Flutter, sin red)
- data/     — repos concretos, mapeo de los modelos de game_engine (SessionAction, SessionEvent) <-> modelos de domain
- presentation/ — widgets/Flame components + controllers (Riverpod)

Cada capa solo conoce la de abajo (presentation -> domain <- data).
domain nunca importa nada de Flutter ni de netcode/*.
