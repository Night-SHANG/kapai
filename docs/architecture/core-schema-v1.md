# Core Data Schema v1

Status: LOCKED BASELINE
Source: P0-1..P0-6 technical decisions
Engine baseline: Godot 4.7.1 stable

This is the first production-facing data contract after P0. It is not a promise that every field is immutable forever; changes must be explicit and must preserve save migration rules.

## 1. Version semantics

- Core contract version: 1.
- Production `save_schema_version`: **1**.
- The P0 Save fixtures named schema_v1/v2/v3/v4 were synthetic migration tests. They are not production release history and do not force the real game to start at save schema 3.
- `game_version` and `save_schema_version` are independent.
- Save schema increments only when persisted structure/semantics require migration.

## 2. Definition vs State

Definition:
- static authored content
- shipped with a game version
- stored as typed Godot Resources
- registered through YARD
- referenced by stable business ID

State:
- player/runtime mutable state
- saved through project-owned DTOs
- stores stable IDs, primitives, arrays and dictionaries
- never embeds a full Definition Resource as durable save truth

The project `DefinitionRegistry` adapter is the only domain-facing lookup boundary. Direct YARD calls should remain infrastructure-level.

## 3. Stable ID contract

Durable references use IDs such as:
- `char_bastion`
- `card_bastion_guard`
- `item_core_fragment`
- `event_test_sealed_lab`

Save data must not use:
- `res://...` paths as business identity
- NodePath as identity
- Resource UID as business identity
- plugin runtime object identity

File paths and Resource UIDs may change while the stable ID remains constant.

Renamed durable IDs require an explicit migration alias/replacement policy. Deleted critical IDs must either migrate/compensate explicitly or fail closed.

## 4. Static Definition baseline

### CharacterDefinition
- registry ID
- name_key / description_key
- tags / exploration_tags
- preferred_positions
- core_passive_id
- starting_card_ids
- unlock_card_ids
- allowed_module_slots
- portrait_ref / battle_art_ref / icon_ref
- story_definition_id
- unlock_definition_id
- default_loadout_id

Mutable HP, injuries, recovery and equipped content belong to CharacterState.

### CardDefinition
- registry ID
- owner_character_id
- name_key
- description_template_key
- tags
- target_rule_id
- effects / ActionSpecs
- position_modifiers
- synergy_hooks
- play_cost (default 1 Card Play; rare explicit Heavy may be 2)
- exhaust / volatile rules
- upgrade_variant_ids
- unlock_condition_id
- icon/art/vfx/sfx presentation refs

Cards express effects through domain specs; they do not directly mutate arbitrary BattleState fields.

### StatusDefinition / EffectDefinition
Status:
- registry ID
- name/description keys
- tags
- duration policy / turns
- stack/max/refresh policy
- modifiers
- turn start/end effects
- triggers
- cleanse tags
- presentation refs

Effect/ActionSpec baseline includes:
- damage/repair/shield
- apply/remove/consume/convert/transfer status
- formation move/lock
- draw/redraw/discard/exhaust/transform
- reveal/reduce/delay intent
- gain/spend Sync
- gain Card Play
- retreat modification

The project-owned lightweight EffectRuntime owns status/effect semantics. BattleResolver owns battle ordering and reaction timing.

### ModuleDefinition
- registry ID
- name/description keys
- module_type / slot_type
- allowed_character_tags
- query_conditions
- passive_effects
- card_tag_modifiers
- exploration_tags_added
- unlock_source
- icon_ref

### EnemyDefinition / EnemyIntentDefinition
Enemy:
- registry ID
- faction/archetype tags
- max_hp/base attributes
- resistances
- intent_ids
- loot/codex refs
- battle/icon refs
- elite/region variants

Intent:
- registry ID
- preview data
- tags
- conditions
- weight
- cooldown/cannot_repeat
- phase requirements
- actions
- target query

Intent Preflight must prove at least one legal action exists for required states/phases.

### ItemDefinition
- registry ID
- name/description keys
- item_type/tags
- unit_weight
- max_stack
- discardable
- secure_storage_allowed
- key_item
- event capabilities/effects
- icon_ref/source rules

YARD is the only authored static Item authority. There is no hand-maintained GLoot prototype database.

### LocationDefinition
- registry ID / region_id
- name/description keys
- tags / node_type
- fixed_or_procedural
- graph refs
- interaction/event/enemy/loot pool IDs
- facility_id
- extraction rules
- art_scene_ref
- discovery conditions
- story flags

### EventDefinition
- registry ID
- tags / region/location filters
- availability conditions
- options
- repeat policy / cooldown
- dialogue source/resource reference
- priority/weight

EventOption:
- option_id
- presentation text/cue
- conditions
- commands
- preview policy

Event Condition is pure/read-only and composable (ALL/ANY/NOT). Event UI/Dialogue returns only `option_id`.

### FacilityDefinition / ResearchDefinition / RegionDefinition
These remain data-driven and stable-ID based. WorldState/FortressState own their mutable progress.

## 5. Runtime State baseline

### CharacterState
- character_id
- unlocked
- recovery_stage
- unlocked_card_ids
- active_deck_card_ids
- equipped_module_ids / module instances
- injury state
- maintenance_remaining_cycles
- story state/flags
- transcendence state
- build preset metadata
- explicit runtime overrides only when unavoidable

### ItemStack / InventoryState
ItemStack:
- item_id
- count
- optional instance_id for unique/non-stackable items
- optional constrained overrides

InventoryState:
- stacks
- capacity/weight state where runtime-owned
- secure-storage state
- slot/module assignment state

All add/remove/split/merge/transfer/extraction operations pass through the project Inventory Domain and remain atomic.

### LocationState / WorldState
LocationState:
- location_id
- discovered
- visited_count
- objective/search state
- restored/occupied/outpost state
- temporary modifiers
- local flags

WorldState is the sole permanent-world authority:
- current_world_cycle
- discovered regions/locations
- region/location states
- unlocked routes
- restored facilities
- forward outposts
- world_flags
- event_history
- active world modifiers
- main story state
- endgame feasibility states
- global character-story flags

Worldmap/UI/Dialogue/Quest helpers never become a second permanent truth source.

### FortressState
- scrap/data/core
- power capacity
- facility levels
- maintenance slots
- completed research
- warehouse inventory
- command-skill unlocks
- secure-storage upgrades
- loadout/preset metadata

### ExpeditionState
Per-run only:
- expedition_id
- region/start/current location
- party_character_ids[3]
- formation
- current HP
- expedition statuses
- Threat value/stage
- carried inventory
- secure storage
- used tools/runtime tool state
- temporary protocols
- patrol/Hunter state
- current objectives
- expedition RNG state
- optional current BattleState
- optional pending EventContinuation

Most of this clears or settles at extraction/wipe resolution.

### BattleState
Pure serializable state:
- turn_index
- ally/enemy states
- formation
- per-character Draw/Discard
- 2-card quota per character / combined visible hand
- card_plays_remaining (baseline 3)
- redraws_remaining (baseline 2)
- formation_adjustments_remaining (baseline 1 adjacent free adjustment)
- Sync
- active effects/statuses
- active triggers
- enemy Intent state
- retreat state
- battle_draw/enemy_ai RNG states
- optional debug command log/hash data

Presentation does not mutate this state directly. Mouse/keyboard/gamepad input routes to BattleCommand.

### EventHistory / TutorialState / RNGServiceState
EventHistory stores once/cooldown history as committed world data.

RNGServiceState maintains isolated streams:
- battle_draw
- enemy_ai
- loot
- event
- world

UI/presentation randomness must never advance gameplay RNG streams.

## 6. SaveProfile v1

Production SaveProfile v1 contains:
- save_schema_version = 1
- game_version
- profile_id
- created_at / last_saved_at / playtime
- WorldState
- FortressState
- CharacterState map/list
- optional current ExpeditionState
- TutorialState
- RNGServiceState
- migration metadata

Settings/preferences may live outside the playthrough save.

Save DTO values are primitives/arrays/dictionaries/stable IDs only. Node, Scene instance, Object reference and plugin runtime object persistence is forbidden.

## 7. Transaction boundaries

Committed-domain-state only.

Event:
`option_id -> EventResolver -> draft state -> all EventCommands succeed -> commit`

Inventory:
validate source/destination/capacity/business policy before commit; no half-transfer.

Save:
SaveState Lite serializes only committed DTO state. It must not snapshot a partially applied EventCommand/settlement transaction.

Approved autosave examples:
- expedition start
- node settlement
- battle end
- safe turn boundary
- extraction settlement
- fortress major upgrade
- character reconstruction
- committed main-story event

## 8. Migration rules

Every persistent structural change must define:
- from schema
- to schema
- deterministic transform
- stable-ID alias/replacement/removal policy
- post-migration validation
- fixture covering the previous stable schema

Newer save schema opened by an older game fails closed.

Missing critical Definition after migration fails closed unless an explicit replacement/compensation/removal policy exists.

## 9. Preflight obligations

Production Preflight must continuously check:
- duplicate/empty/dangling stable IDs
- Definition reference integrity
- localization keys/placeholders
- Intent reachability
- Effect recursion/bounds
- Inventory stack/weight/key-item contracts
- Event option/condition/command/cue reachability
- World graph reachability
- deterministic RNG regression
- save migration fixtures
- newer-schema rejection
- dependency lock drift

This document is the baseline; domain-specific decision files remain authoritative for edge-case behavior.
