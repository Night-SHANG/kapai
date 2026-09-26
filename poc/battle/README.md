# P0-3 — Three-character Card Battle

Phase A only in this commit.

Goal: compare draw models while keeping action economy fixed.

Common rules:
- 3 characters
- 8 cards each
- 6 visible cards
- 3 normal card plays per turn
- 2 redraws per turn
- retain unused cards
- 12 simulated turns per run
- 1000 runs per model
- deterministic RandomNumberGenerator seed

A1: per_character_quota
- independent draw/discard piles
- each character refills to 2 cards
- redraw replacement comes directly from the same character pile

A2: shared_fair_pool
- one shared 24-card draw pile
- refill guarantees missing characters before normal top-deck draws
- same-character redraw searches the shared pile
- every forced search and skipped card is recorded

This phase does not decide fun or final battle rules. It only measures structural fairness, intervention complexity and determinism.

Phase B (later): compare 3 Card Plays vs shared 4 AP using the Phase A winner.
