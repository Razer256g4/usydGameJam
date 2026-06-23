# Platform 0

> A psychological horror game about a train that refuses to reach your destination
> until you remember who was left behind.

**Theme: Flip the Script.** Every helpful thing in this game lies, hurts, or only helps once
you understand its real purpose. The pills that calm you hide the truth. The announcements
that guide you keep you passive. The faceless passenger you want to avoid is the person you
have to face. Avoidance is the enemy.

This repo is a **clean, runnable baseline** — a reusable engine plus a complete vertical slice
(title → train hub → 2 explorable stations → final scene → 5 endings). It runs *today* with
placeholder art so you can playtest the loop on hour one, then pour content and art in.

Built in **Godot 4.7** (GL Compatibility renderer → exports to Web + Windows).

---

## Run it

Open the project in Godot 4.7 and press **F5**. Main scene is `scenes/Boot.tscn`.

| Key | Action |
| --- | --- |
| `WASD` / Arrows | Move |
| `E` / `Enter` | Interact / advance dialogue |
| `Q` | Take a pill (stabilise reality, hide the truth) |
| `T` | Glance at your ticket (your role / destination) |
| Mouse or `Enter` | Pick an option in a choice menu |

---

## The big idea: one inverted axis

The whole game hangs off a single state, `GameState.reality`:

```
STABLE  ◄──── pills ────  UNCERTAIN  ──── chasing the truth ────►  MEMORY_LEAK
(safe lies,                (default)                               (truth visible,
 clues hidden)                                                      world hostile)
```

- **Pills** push you to `STABLE`: the screen calms (shader intensity drops), but hidden clues
  vanish and the ticket softens into safer lies. Each pill also raises your `denial` score,
  which changes your ending.
- **Finding evidence / approaching the victim** calls `nudge_truth()`, dragging reality toward
  `MEMORY_LEAK`: the screen grains and reddens, and objects reveal what they were hiding.

Every interactable shows **different text for each reality state**. That's the theme made
mechanical — comfort vs. truth is a real, repeated decision, not a slogan.

---

## Architecture (why it's reusable)

```
scripts/
  autoload/
    GameState.gd     single source of truth: reality, pills, flags, fragments, ticket, endings
    SceneDirector.gd fade-through scene changes + named spawn points
    Audio.gd         tiny audio facade (safe to call before any sound files exist)
  ui/
    Hud.gd           the ONE facade everything talks to: say / choice / announce / ticket / fade
    EndingScreen.gd  ending cards + restart
  world/
    Station.gd       BUILDS A WHOLE ROOM FROM DATA — the core of the baseline
    Interactable.gd  the one reusable "thing you interact with" (7 behaviour kinds)
    TrainCabin.gd    \
    StationForgets.gd } each is ~60 lines of DATA, no boilerplate (all `extends Station`)
    StationWitness.gd /
    FinalTrain.gd    /
  player/Player.gd   top-down movement + "interact with nearest" (draws itself as placeholder)
  Boot.gd            title screen
shaders/
  reality_overlay.gdshader   vignette + scanlines + grain, intensity driven by reality state
scenes/                      thin .tscn wrappers (root node + script); content lives in the .gd
```

Three ideas keep it clean:

1. **Data-driven rooms.** `Station.gd` reads a single Dictionary and builds the floor, walls,
   camera, player spawn, and every prop. A location is *data*, not hand-wired nodes — so adding
   content is editing an array, and there are no fragile scenes to merge during a jam.
2. **One Interactable, many behaviours.** `Interactable.Kind` = `EXAMINE / DOOR / FRAGMENT /
   ROLE_TERMINAL / SCREEN_TERMINAL / FINAL_CHOICE / FLAG_SET`. Presentation (the lines) is chosen
   by reality state; behaviour is chosen by `kind`. Gating (`requires_flag`,
   `requires_fragments`, `locked`) and effects (`sets_flag`, `nudge_truth`, `then_objective`)
   are all data fields.
3. **One UI facade.** Gameplay never touches UI nodes directly — it calls
   `await Hud.say(...)`, `await Hud.choice(...)`, `await Hud.announce(...)`. Dialogue and menus
   are *blocking* (the player freezes), so flow reads top-to-bottom.

---

## How to add content (the part your team will use)

### Add a prop to a station
Open the station's `.gd` and add one Dictionary to its `props` array:

```gdscript
{
    "kind": Interactable.Kind.EXAMINE, "name": "Mirror", "pos": Vector2(300, 120),
    "size": Vector2(20, 30), "color": Color(0.3, 0.4, 0.5), "verb": "Look into the",
    "stable":    "You look fine. You look normal.",
    "uncertain": "Your reflection is half a second behind you.",
    "leak":      "There are two of you in the glass. Only one of you got off the train.",
},
```

That's a full inverted object: harmless when sedated, accusatory when you're facing the truth.

### Prop field reference
| Field | Used by | Meaning |
| --- | --- | --- |
| `kind` | all | behaviour (see `Interactable.Kind`) |
| `name`, `pos`, `size`, `color`, `verb` | all | label, position, placeholder box, prompt verb |
| `stable` / `uncertain` / `leak` | text | line shown per reality state (any may be omitted) |
| `requires_flag` / `requires_fragments` | gating | locked until met; shows `locked` text if present |
| `locked` | gating | line shown while locked |
| `sets_flag`, `nudge_truth`, `then_objective` | effects | applied on success |
| `target_scene`, `target_spawn` | `DOOR` | where it leads |
| `set_id`, `piece`, `total` | `FRAGMENT` | collectible set membership |
| `options`, `correct`, `prompt`, `on_correct`, `on_wrong` | `ROLE_TERMINAL` | menu + right answer |
| `screens` (`text`, `req`, `req_reality`) | `SCREEN_TERMINAL` | monitors revealed by progress |
| `options`, `prompt` | `FINAL_CHOICE` | the ending decision |
| `becomes_name` | `FLAG_SET` | rename the object after use (e.g. blank sign → WITNESS) |
| `provider` | live text | name of a `_provide_<x>()` method for state-dependent dialogue |

### Add a whole new station
1. `scripts/world/MyStation.gd` → `extends Station`, override `_station_data()` returning the
   room dict (copy an existing one).
2. `scenes/world/MyStation.tscn` → a single `Node2D` with that script (copy an existing `.tscn`).
3. Point a `DOOR` prop's `target_scene` at it. Done — movement, camera, walls, fades, HUD,
   reality system all work automatically.

---

## Drop in assets (no code changes needed)
- **Ambience / SFX:** put `.ogg` files where the data expects them (`audio/ambience/train.ogg`,
  `station1.ogg`, `station2.ogg`, `final.ogg`, `audio/sfx/pill.ogg`). Missing files are ignored.
- **Art:** the player and props draw placeholder boxes in `_draw()`. Replace by adding a
  `Sprite2D` / `AnimatedSprite2D` child — movement, collision and interaction are untouched.
- **Font:** add a project theme with a pixel font for instant polish across all UI.

---

## Suggestions, mapped to the judging criteria

**Theme integration (20).** This is your strongest axis — lean all the way in. The reality
state already inverts every object. Make the *inversion legible*: the first time a pill hides a
clue the player was reading, flash the clue out visibly so they connect "comfort = blindness".
Keep the rule consistent (the design doc's Rule 2): announcements lie **only** when keeping you
passive; the ticket tells the truth **only** when you accept responsibility. Consistency is what
turns a gimmick into "innovation".

**Gameplay fun (20).** Horror puzzles die when players get stuck, not scared. Two guards are in
the baseline already (the objective line + locked-door text) — use them. Make every choice
change something *visible within 1 second*: pill → screen calms + a clue blanks; correct role →
crowd parts + ticket reprints. Keep both puzzles one-step (3 fragments; phone → truth → role).

**Innovation (20).** The pill trade-off (the thing that helps you is the thing that blinds you)
is genuinely novel — put it front-and-centre in the itch description and the opening 60 seconds.
The "CCTV shows the official lie until you distrust it" beat (Monitor C only appears once you've
found the phone *and* let reality slip) is the most original moment; make sure players reach it.

**Polish (10).** Cheap, high-impact: (1) the reality shader is wired — tune the three intensity
values in `Hud._on_reality`; (2) add a pixel font; (3) add the 4 ambience loops + a pill SFX;
(4) a screen-shake / flash on `nudge_truth`. That's a "polished" rating for ~2 hours of work.

**Tech achievement (15).** The data-driven Station/Interactable engine *is* the tech story —
say so on the page: "every location and object is authored as data through one reusable system."
A web export that runs smoothly in-browser also reads as technical competence to judges.

**Commercial (15).** Ship a tight 8–12 min build with a real itch page: a cover that shows the
pill/reflection hook, "headphones recommended", clear controls, and one screenshot of a leak
moment. The premise is pitch-shaped — one sentence sells it. Multiple endings + a short runtime
invite replays, which is the commercial signal judges look for.

### Recommended next steps (in order)
1. Playtest the slice end-to-end; fix any softlock first.
2. Add the pill-hides-a-clue *visual* feedback — it's the whole theme in one beat.
3. Audio pass (4 loops + pill SFX) and a pixel font.
4. Replace placeholder boxes with sprites for the player, victim, and the 5–6 hero props.
5. Export Web + Windows, write the itch page, ship.

---

## Conventions
- Input is registered in `GameState._setup_input()` (code, not `project.godot`) to stay
  merge-friendly during the jam.
- Collision layers: `1` = walls, `2` = player, `4` = interactables.
- All UI lives on the autoloaded `Hud` (a `CanvasLayer`), so it persists across scene changes.
