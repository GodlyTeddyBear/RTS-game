# Phase 2 — Environment design (vertical slice)

**Theme lock:** Outdoor **sci-fi agri frontier** — industrial cultivation, not fantasy pastoral. The run is a **single defended approach** through **active farmland**: the **lane** is a service corridor; **`side_pocket`** zones read as **resource patches** (extraction plots); the **command post** sits at the **processing hub**.

**Sources of truth:** [docs/GDD.md](../../docs/GDD.md) §9 (zone types), [Phase2CompletionChecklist.md](Phase2CompletionChecklist.md). If this doc conflicts with the GDD, **GDD wins**.

**Related:** Asset placement and Blender scope — [Phase2StudioVsBlenderProduction.md](Phase2StudioVsBlenderProduction.md).

---

## Design goals

| Goal | How the environment supports it |
|------|----------------------------------|
| **Tactical clarity** (GDD pillar) | Lane, patches, and base are **readable at a glance** — hard edges, contrasting materials, no tall clutter on the combat floor. |
| **Meaningful map position** (GDD §9) | Patches **look like worth holding**; losing one should feel like losing **arable / output capacity**, not a random pad. |
| **Sci-fi RTS fantasy** | **Agri-tech** vocabulary: grids, troughs, condensers, silos, nutrient plumbing — still **hard-surface industrial**. |
| **Phase 2 scope** | One outdoor slice, **one lane**, **six waves** — environment can be **modular** (repeatable patch kit + deck segment) without full open world. |

---

## Zone types → landscape read

GDD names are authoritative; this table is the **visual translation** for artists and level builders.

| GDD zone | Player read | Environmental idea |
|----------|-------------|---------------------|
| `lane` | **Combat corridor** | Raised **service causeway**: grated deck, compacted soil under plating, or **irrigation levee** — always **one clear walking surface** from spawn approach toward base. |
| `side_pocket` | **Resource patch** (placement + extraction) | Bounded **cultivation cells**: hydro grids, algae raceways, mineral slurry beds, **condenser fields** — each patch is a **fenced or bermed platform** touching the lane shoulder. |
| `base_anchor` | **Command post** | **Processing hub** — silo stack, combine tower, nutrient port, or agri-command bunker; **largest silhouette** on the map. |
| `blocked` | **Impassable** | **Fallow sink**, **sludge sump**, **collapsed greenhouse**, **deep irrigation cut**, **equipment graveyard** — **obvious** height gap or barrier, not ambiguous crops. |

**Rule:** Enemies path on the **`lane`** toward the base; patches are **off the main combat line** but **economically loud** so pressure on extractors stays understandable.

---

## Resource patches (Ferrium, Ceren, Voltrite)

Each **`side_pocket`** is assigned **one** resource type (GDD §9). Use **distinct silhouette + trim** so players learn the map without staring at UI.

| Resource | Suggested visual language | Silhouette cues |
|----------|---------------------------|-----------------|
| **Ferrium** | **Chassis / mineral** bias — slurry trenches, ore mulch beds, **red-amber** hazard trim, crawler tracks at patch edge. | Low, **wide** beds; **dust** or rust streaks; heavy **plating** at patch corners. |
| **Ceren** | **Field / control** bias — **mist rails**, coolant manifolds, **teal / cyan** glow, shallow flood trays. | **Horizontal** louvers, vapor wisps (subtle), **wet** dark base material. |
| **Voltrite** | **High-energy** bias — **collector stilts**, capacitor mushrooms, **violet / amber** warning bands, conduit hoops. | **Taller** skinny elements; **spark** or arc VFX kept **small** so swarm reads stay clean. |

**Shared patch kit:** Common border pieces (berm, railing, trough lip), **Extractor** pad center, **runoff channel** toward `blocked` or decorative void — reinforces “this is a working farm block.”

---

## Lane composition

- **Width:** Enough for **multiple swarm units + commander** without crowding the camera; avoid tight chokes unless design deliberately adds one later.
- **Length:** Supports **readable travel time** from spawn to base; horizon shows **open sky** or distant **cultivation blocks** (instancing-friendly).
- **Directional read:** Subtle **centerline**, **lighting gradient** (warmer toward base), or **crop rows** in adjacent patches all pointing **toward the hub** — never rely on UI arrows alone.
- **Verticality:** Keep **combat plane flat**; decorative height stays **beside** or **behind** the lane.

---

## Sky, light, atmosphere

- **Time:** **Alien daylight** or **late afternoon** — one dominant sun for consistent shadows and swarm rim light.
- **Fog:** **Light aerial haze** or heat shimmer; **lower fog density** over the `lane` than in the far field so units stay crisp.
- **Base:** **Warm running lights** or beacon on the command post — emotional anchor and loss-state readability.
- **Patches:** **Typed accent lights** matching Ferrium / Ceren / Voltrite trim; avoid **strobing** or busy neons on the lane itself.

---

## Modular kit (Roblox Studio–first)

Build Phase 2 from **reusable modules** so iteration is fast:

| Module | Contents |
|--------|----------|
| **Lane segment** | Deck / soil panel, edge trim, optional drainage grate, snap length (e.g. 24–32 studs). |
| **Patch shell** | Berm + corner posts + **one** typed insert (Ferrium / Ceren / Voltrite mesh or material variant). |
| **Hub platform** | `base_anchor` footprint, command post socket, approach ramp alignment. |
| **Blocked filler** | Sink geometry, fence, wreckage — **never** mistaken for `lane`. |
| **Props** | Conduit bundles, nutrient tanks, tool crates, **short** crop massing (low poly) **inside** patches only. |

**Blender later:** Hero pieces (unique hub details, hero extractor variants); **Studio CSG/meshes** OK for slice greybox.

---

## Tactical clarity — do / don’t

**Do**

- Keep **lane surface** a **single material family**; differentiate patches with **borders + typed inserts**.
- Use **negative space** — players should **count threats** without occlusion.
- Test **night-ish** lighting once; if contrast fails, simplify materials before adding lights.

**Don’t**

- **Tall crops**, dense corn walls, or particle soup on the **lane**.
- **Camouflaged** enemy tones against the floor — tune faction colors after first environment pass.
- **Symmetric** patch layout that makes “which resource am I on?” ambiguous — vary spacing or hub-facing order slightly if needed for learning.

---

## Phase 2 checklist cross-check

| Checklist / GDD need | Environment note |
|----------------------|------------------|
| Single lane end-to-end | Causeway uninterrupted from approach to **`base_anchor`**. |
| Base + dual loss legible | Hub is unmistakable; damaged state (later) should read on **silhouette + lights**. |
| Side pockets + extraction | Patches **look productive**; Extractor ghost/placement reads on **pad center**. |
| Six waves, teaching | First minutes should teach **lane vs patch vs base** without a tutorial paragraph. |

---

## Open decisions (fill as you lock art)

| Decision | Options / notes |
|----------|-----------------|
| **Biome accent** | Temperate terraform vs arid reclamation vs coastal algae — stays within **sci-fi agri**. |
| **Weather** | Static sky first; rain/sand optional **after** readability pass. |
| **Spawn vista** | What the player sees **behind** the wave spawn — distant harvesters, storm front, orbital mirror (low detail). |

When locked, add **one reference line** to your moodboard folder or image links here (optional; keep repo lightweight).
