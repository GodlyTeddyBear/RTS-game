# Foundation

**Source of truth for detailed design:** [docs/GDD.md](../docs/GDD.md).

## One-line vision

Sci-fi **hybrid RTS wave defense**: summoner commander, **single lane**, **one resource**, **commander death ends run**, **score** chase into **endless mutator escalation** after the scripted climax. **Solo first**; co-op is a later product phase.

## Pillars (from GDD)

1. Tactical clarity  
2. Meaningful prep  
3. Escalating adaptation  
4. Score integrity  

## Product boundaries (v1)

- **In scope:** Run loop, lane combat, structures and summons as designed, wave tooling, scoring, endless + mutators, light meta progression (TBD in GDD).
- **Out of scope:** Story campaign, VO, PvP-first balance, multi-lane macro RTS.

## Engineering alignment

Implementation follows project architecture in [AGENTS.md](../AGENTS.md) (Knit, bounded contexts, feature slices). This file does not duplicate coding standards.
