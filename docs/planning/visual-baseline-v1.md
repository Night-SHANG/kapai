# Visual Baseline v1.1

Status: SELECTED FOR REFINEMENT
Date: 2026-09-27

The first visual comparison sheet has been reviewed.

Selected:
- Fortress: A1
- Old City map: B1
- Battle: C3 **UI information language only**

The C3 camera/staging shown in the first sheet is rejected. It drifted toward near-3D cinematic combat and does not match the project's 2D combat model.

## Unified art direction

Overall:
- semi-realistic / realistic sci-fi
- post-apocalypse after the event
- old-world high-technology ruins
- quiet, empty, cold atmosphere
- small amounts of warm warning/service lighting
- avoid full-neon cyberpunk
- avoid overt anime UI language
- avoid medieval/card-table motifs

UI:
- dark technical command-interface base
- restrained cyan/blue for neutral/system information
- orange/red for Threat, warning, hostility and irreversible consequences
- thin lines, modular panels, strong hierarchy
- readable typography
- decoration never overrules readability

## Fortress master — A1

Keep:
- monumental industrial interior
- vertical scale and long-term command-base feeling
- dark steel + limited warm utility lights
- permanent navigation and resource hierarchy

## Old City map master — B1

Keep:
- recognizable ruined city underneath a tactical route layer
- route graph tied to real locations
- persistent Threat/intelligence visibility
- distinct silhouettes for current node, objective, extraction and danger

## Battle presentation — corrected

### Camera / staging

Formal direction:
**2D side-view tactical stage**, not top-down and not 3D.

- player team occupies the left side
- enemies occupy the right side
- the battlefield is read horizontally
- Vanguard / Mid / Rear are explicit linear slots
- slight painted perspective/parallax is allowed in the background
- characters remain 2D static/semi-static PNG sprites
- no free 3D camera, no navigable ground plane, no implied grid

Why not top-down:
the battle rules do not contain free movement, tiles, range geometry, cover or flanking coordinates. A top-down view would falsely promise a spatial tactics game.

Why not C3 cinematic 3D:
it over-emphasizes scene spectacle and under-emphasizes the actual card/formation/intent information model.

### Mature-reference hierarchy

Use different mature games for different responsibilities:

- **SteamWorld Quest**: primary structural battle reference — 3-character party, 6-card hand, 3 plays, 2 redraws, retained cards.
- **Trials of Fire**: multi-character card-source and bad-hand handling reference.
- **Marvel's Midnight Suns**: shared Card Plays and deterministic execution/prediction reference.
- **Slay the Spire**: enemy Intent and readable card/status presentation.
- **Into the Breach**: prediction clarity and “known board state” information discipline.
- **Darkest Dungeon**: useful visual/staging reference for readable left-vs-right party/enemy lineup and strong silhouette separation; not a mechanical combat template.
- **Card Framework**: presentation implementation helper only; it does not dictate camera, battle state, formation or rules.

### Formal battle layout

Top 60-65%:
- 2D battlefield illustration
- allies left, enemies right
- clear formation slot anchors
- enemy Intent directly above/near each enemy
- target lines / preview overlays appear only when needed
- HP / Shield / critical statuses stay close to entities

Bottom 30-35%:
- unified 6-card hand
- card owner shown by portrait + frame/shape, never color alone
- selected-card detail/preview expands without covering the battlefield

Compact tactical resource cluster:
- Card Plays 3/3
- Redraw 2/2
- Formation 1/1
- Sync
- End Turn separated to prevent misclick

The battlefield must preserve empty visual space for:
- target preview
- formation arrows
- VFX
- status changes
- damage/heal numbers

## Production consequence

The corrected battle direction becomes the source for:
- UI component bible
- battle composition guide
- character sprite scale
- formation slot layout
- intent/status icon language
- Godot Battle Scene layout
- image-generation prompts

Next master mockup:
generate the battle screen specifically as a **2D side-view card battle interface** based on this corrected reference hierarchy.
