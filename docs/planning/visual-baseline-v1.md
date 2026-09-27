# Visual Baseline v1

Status: SELECTED FOR REFINEMENT
Date: 2026-09-27

The first visual comparison sheet has been reviewed. The unified direction is:

- Fortress: A1
- Old City map: B1
- Battle: C3

These are not three unrelated styles. They are combined into one visual language.

## Unified art direction

Overall:
- semi-realistic / realistic sci-fi
- post-apocalypse after the event, not active catastrophe
- old-world high-technology ruins
- quiet, empty, cold atmosphere
- small amounts of warm warning/service lighting
- avoid full-neon cyberpunk
- avoid overt anime UI language
- avoid medieval/card-table motifs

UI:
- dark technical command-interface base
- restrained cyan/blue for neutral/system information
- orange/red reserved for Threat, warning, hostility and irreversible consequences
- thin lines, modular panels, strong information hierarchy
- large readable typography
- decoration never overrules readability

## Fortress master — A1

Keep:
- monumental interior industrial architecture
- sense of vertical scale and long-term inhabited command base
- dark steel structure with limited warm utility lights
- clear permanent navigation rail and resource/status hierarchy
- the base feels functional, not luxurious

Refine:
- reduce visual clutter behind text
- strengthen separation between world scene and UI panels
- make squad/prep entry more prominent
- reserve space for future maintenance/workshop/codex status without overcrowding

## Old City map master — B1

Keep:
- real-world ruined city visible below/behind the tactical layer
- route graph sits on a recognizable environment rather than becoming a pure blueprint
- nodes feel like real locations
- Threat and local intelligence remain always legible

Refine:
- route lines must be readable without covering city identity
- node icons use stable shape language, not color alone
- main objective / extraction / current position / unresolved danger receive distinct silhouettes
- route state, known danger and special-event information should be inspectable without turning the map into a spreadsheet

## Battle master — C3

Keep:
- grounded cinematic ruined-street battlefield
- three allies and enemies readable as physical combatants, not UI tokens
- battle UI remains subordinate to the battlefield
- hand anchored at the bottom
- visible Intent and target information

Refine:
- six-card hand must clearly show owner identity through portrait + frame/shape, not color only
- Card Plays / Redraw / Formation / Sync grouped as one compact tactical resource area
- ally HP/status and enemy Intent hierarchy must be clearer than decorative card art
- formation positions should be perceptible immediately
- avoid oversized character sprites that leave no room for targeting lines / VFX / status information

## Production consequence

This direction becomes the source for:
- UI component bible
- environment visual bible
- character battle-scale rules
- icon/status/intent language
- Codex/image-generation prompt templates
- Godot layout targets

Next visual pass should produce three separate 16:9 polished master mockups using this unified language:
1. Fortress overview
2. Old City region map
3. Standard battle
