# LibBonusId

A World of Warcraft addon library that accurately calculates item levels from bonus IDs embedded in item links.

WoW item links contain bonus IDs that modify an item's level through scaling curves, content tuning, era-based squishing, and other transformations. The game's internal logic for resolving these into a final item level is complex and undocumented. LibBonusId replicates this logic using pre-processed DB2 data to provide accurate item level calculations without relying on tooltip parsing or other in-game APIs.

## Installation

Add `LibBonusId.xml` to your `.toc` file to load both the library code (`LibBonusId.lua`) and the data file (`Data.lua`).

If you're using the [BigWigs packager](https://github.com/BigWigsMods/packager), you can reference LibBonusId as an external library:

```yaml
externals:
  Libs/LibBonusId:
    url: https://github.com/TradeSkillMaster/LibBonusId.git
```

## API

Load the library through LibStub:

```lua
local LibBonusId = LibStub("LibBonusId")
```

### `LibBonusId.CalculateItemLevelFromItemLink(link)`

Calculates the item level from an item link.

```lua
local itemLevel = LibBonusId.CalculateItemLevelFromItemLink(itemLink)
```

**Parameters:**
- `link` (string) — A full item link

**Returns:** The calculated item level.

### `LibBonusId.CalculateItemLevelFromItemInfo(itemId, bonusIds, modifierDropLevel, modifierContentTuningId)`

Calculates the item level from pre-parsed item link components.

```lua
local itemLevel = LibBonusId.CalculateItemLevelFromItemInfo(itemId, bonusIds, modifierDropLevel, modifierContentTuningId)
```

**Parameters:**
- `itemId` (number) — The item ID
- `bonusIds` (number[]) — List of bonus IDs applied to the item
- `modifierDropLevel` (number?) — The player's level when the item dropped (modifier type 9 in the item link). Omit or pass `nil` if not present.
- `modifierContentTuningId` (number?) — The content tuning ID for the item (modifier type 28 in the item link). Omit or pass `nil` if not present.

**Returns:** The calculated item level (number).

### `LibBonusId.GetBonusStringForLevel(itemLevel)`

Returns a bonus string (partial item link format) that produces the given item level. This is the reverse of the calculation APIs — given a target item level, it finds a set of bonus IDs (and optional drop level modifier) that will produce that level when applied to any item.

```lua
local bonusString = LibBonusId.GetBonusStringForLevel(itemLevel)
```

**Parameters:**
- `itemLevel` (number) — The target item level

**Returns:** A bonus string (string?) in one of these formats, or `nil` if no match is found:
- `"1:<bonusId>"` — A single bonus ID that sets or scales to the target level
- `"2:<bonusId1>:<bonusId2>"` — Two bonus IDs (an add + set combo) sorted numerically
- `"1:<bonusId>:1:9:<dropLevel>"` — A curve-based bonus ID with a drop level modifier

The returned string uses the same encoding as the bonus/modifier portion of an item link. The first number is the bonus ID count, followed by the bonus IDs, then an optional modifier count and modifier key-value pairs (type 9 = drop level).

## Data File

The bundled `Data.lua` file is generated from Blizzard's DB2 tables for a specific game build. The data is serialized and compressed in a way that leverages WoW's built-in `C_EncodingUtil` APIs to minimize the impact on loading times (adds ~20ms in testing including both reading the file and decoding the data).

Multiple addons using this library with their own copy of the data file will be handled gracefully. The first one to load will initialize the data, and any subsequent instance of the library will overwrite the data if and only if it has data which better matches the current build.

The data contains:
- **Bonus entries** — Pre-processed operations for each bonus ID (what type of level modification to apply)
- **Curves** — Piecewise curves mapping input values (player level or base item level) to output values (item level)
- **Content tuning** — Content-type level clamping and scaling rules
- **Item base levels** — The base item level for every non-stackable item
- **Midnight items** — Set of item IDs where the base item level has the Midnight-era squish pre-applied
- **Squish curve** — The curve used for the Midnight-era item level squish

## Generating Data.lua

The tool to generate `Data.lua` from Blizzard's DB2 tables is available at [BonusIdTool](https://github.com/TradeSkillMaster/BonusIdTool).

## How Item Level Calculation Works

The algorithm replicates WoW's internal item level resolution. Note that this is a black-box reimplementation of the game's logic, so the actual implementation may be completely different, but this implementation is tested to match the output of the game's logic. Here's what happens when you call either of this library's API functions:

### 1. Base Item Level

Every item has a base item level stored in `ItemSparse`. The item also carries an `ItemSquishEraID` that determines whether it's natively in the Midnight (post-squish) scale (era 2).

### 2. Link Parsing

See [this page](https://warcraft.wiki.gg/wiki/ItemLink) for more thorough documentation on item link encoding, but for the purposes of this library, an item link encodes:
- **Item ID** — identifies the base item
- **Bonus IDs** — a list of numeric IDs that each apply a modification
- **Modifiers** — key-value pairs including the drop level (type 9) and content tuning ID (type 28)

### 3. Bonus ID Resolution

Before applying bonuses, the library resolves and sorts them:

- **APPLY_BONUS redirects**: Some bonus IDs are simple redirects to another bonus ID. These are resolved first. The game only follows one level of APPLY_BONUS indirection — if a bonus ID redirects to a target that itself contains an APPLY_BONUS, the chain is not followed and the bonus is effectively ignored.
- **Sort by priority**: Bonus IDs are sorted by their type's priority class, then numerically within the same class. The priority classes are:

  | Priority | Bonus Types |
  |----------|-------------|
  | 0 | Everything else (processed first) |
  | 1 | Stat Scaling, Stat Fixed |
  | 2 | Scaling Config, Scaling Config 2 |
  | 3 | Offset Curve |
  | 4 | Midnight Item Level, Crafting Quality |

### 4. Bonus Collection and Deduplication

Bonuses are collected in two passes:
1. **Indirect bonuses** first — these come from APPLY_BONUS entries with multiple sub-entries
2. **Direct bonuses** second — these override indirect bonuses through dedup

Deduplication groups bonuses by operation type:
- `scale` and `set` operations compete for the **level** slot (last one wins)
- `add` operations compete for the **add** slot (last one wins)
- `legacyAdd` operations are never deduplicated

When two bonuses compete for the same slot, the one with the lower priority value wins. If neither has an explicit priority, the later one overwrites.

### 5. Bonus Operations

Each bonus applies one of these operations:

| Operation | Effect |
|-----------|--------|
| **scale** | Looks up item level from a curve using the player's drop level (or a default). May apply content tuning to clamp/adjust the drop level first. Adds an optional offset. |
| **set** | Sets the item level to a fixed value (pre-computed from an offset curve at data generation time). |
| **add** | Adds a flat amount to the current item level. Used by MIDNIGHT_ITEM_LEVEL and CRAFTING_QUALITY bonuses. |
| **legacyAdd** | Adds a flat amount (from INCREASE_ITEM_LEVEL, bonus type 1). Never deduplicated — all legacy add bonuses stack. |

### 6. Content Tuning

Content tuning clamps or adjusts the drop level before it's fed into a scaling curve. The tuning operation depends on the bonus type. Supported operations:

| Operation | Formula |
|-----------|---------|
| **clamp** | `clamp(dropLevel, min, max)` |
| **cap** | `min(dropLevel, max)` |
| **const** | Returns a fixed value regardless of drop level |
| **capAdd** | `min(dropLevel, cap) + offset` |
| **capAddFloor** | `max(min(dropLevel, cap) + offset, floor)` |

Different bonus types may receive different content tuning operations. For example, SCALING_CONFIG uses `clamp(min, max)` while SCALING_CONFIG_2 uses `cap(max + 1)` under `MaxLevelScalingOffset=1`.

Content tuning entries are also subject to **ConditionalContentTuning** redirects — entries that remap a content tuning ID to a different one based on context (some apply to all bonus types, others only to scaling configs).

### 7. Midnight Squish

The Midnight expansion introduced an item level compression ("squish") that maps legacy item levels onto a compressed modern scale. A squish curve maps pre-squish levels 1–1300 to post-squish levels 1–170. Any pre-squish value above the curve's maximum produces item level 1.

Whether the squish applies depends on the item's scaling era:

- Items with `ItemSquishEraID=2` are natively in the Midnight scale — no squish needed
- SCALING_CONFIG bonuses set Midnight scaling if their config's `ItemSquishEraID != 1`, or if `Flags & 1` is set
- SCALING_CONFIG_2 bonuses set Midnight scaling if their config's `ItemSquishEraID != 1`
- OFFSET_CURVE bonuses set Midnight scaling if `Value_2 != 1`
- CRAFTING_QUALITY bonuses force Midnight scaling — if the item isn't already in the Midnight scale, it gets squished first, then the crafting quality adjustment is added in the post-squish scale

If no bonus sets Midnight scaling and the item isn't natively Midnight-era, the final item level is squished at the end.

### 8. Curve Interpolation

Curves are piecewise-linear functions stored as `{x: y}` point tables. To evaluate a curve at a given input:
- If the input matches a point exactly, return that point's value
- If the input falls between two points, linearly interpolate
- If the input is below/above all points, clamp to the nearest endpoint's value

All curve outputs are rounded to the nearest integer.

### 9. Final Result

After all bonuses are applied, the item level is clamped to a minimum of 1. If the item never entered the Midnight scale during processing, the squish curve is applied as the final step.

## DB2 Tables Used

The calculation draws from these Blizzard DB2 tables:

| Table | Purpose |
|-------|---------|
| **ItemSparse** | Base item level and squish era per item |
| **ItemBonus** | Bonus ID to operation mapping (type, values) |
| **ItemScalingConfig** | Links scaling bonuses to offset curves, squish era, and default levels |
| **ItemOffsetCurve** | Maps scaling configs to curve IDs with offsets |
| **CurvePoint** | Raw data points for piecewise-linear curves |
| **ContentTuning** | Per-zone level scaling rules (min/max levels, offsets, flags) |
| **ConditionalContentTuning** | Context-dependent content tuning redirects |
| **ItemSquishEra** | Identifies the squish curve for each era |

## Contributing

If you find an item where LibBonusId returns the wrong item level, please open an issue and include the full item link.

## Credits

This library was created by Sapu, but was only made possible with the help of:

- Significant pre-existing work by Seriallos of [Raidbots](https://www.raidbots.com/), especially his [notes on item levels in Midnight](https://gist.github.com/seriallos/1b15ddda52ead945ab58e8140af5ca0a) plus discussions in Discord
- Claude Code for reverse-engineering of content tuning IDs and dedup/priority logic

## License

LibBonusId is provided under the MIT license. See LICENSE.txt for more information.
