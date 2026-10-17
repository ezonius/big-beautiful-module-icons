 ## Big Beautiful Module Icons

Design goals:
- Prevent overlap between the recipe icon and module slots.
- Scale module slots based on collision box area.
- Create "square packings" of module slots.
- Fix module rendering going outside the bounding box of the machine with 20+ module slots.
- Supports all mods.

## Settings

**Maximum rendered module icons** (`bbmi-max-rendered-module-icons`) — a startup mod setting, default 20, range 0–20. Because it is read at data stage, changing it requires a full game restart, not just a settings reload. A value of 0 means no cap / feature off — all module icons are rendered as before. Values from 1 to 20 limit how many module icons are drawn per machine (in alt-mode): the capped value is used in place of the machine's real module slot count before the layout math, so the machine renders the layout it would have with that many slots. The cap engages on any machine whose module slot count exceeds the setting's value — not only machines with more than 20 slots. At the default of 20 this only affects machines that mods such as `more-module-slots` / `configurable-beacons` push past 20 module slots, but a lower value caps vanilla machines too (e.g. with a value of 5, a 10-slot machine renders only 5 icons). A value of 0 disables capping entirely.
