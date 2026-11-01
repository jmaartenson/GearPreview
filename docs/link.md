# Addon link contract (`#eq=`)

Date: 2026-10-31. Producer: the GearPreview addon (`GearPreview/`). Consumer: the scryTome Gear Preview page, which does not parse `#eq=` yet; until that lands, the link opens the page without the character. When it lands, the page shows each item under its own name, and an appearance override's look on the figure while the worn item keeps its identity.

Every table below is a dump of the live client (Main install, character
Aethelric, Archmage, rank 40) taken through the `ror-main` MCP server on
2026-10-31. The commands and raw results are kept with the maintainer's evidence for the addon.

## Grammar

```
link     = "https://scrytome.org/ror-gear-preview/#" fragment
fragment = "eq=1" [";c=" career] [";s=" sex] [";n=" name] *(";i=" item)
career   = page career key, see the career table
sex      = "M" / "F"
name     = url-encoded character name, suffix stripped
item     = slotKey ":" apiItemId ":" dyeA ":" dyeB [":" appearanceName ":" iconNum]
slotKey  = page slot key, see the slot table
apiItemId, dyeA, dyeB, iconNum = decimal digits
appearanceName = url-encoded name of the applied appearance
```

- `eq=1` is the version and always comes first.
- `c`, `s` and `n` appear in that order. The addon leaves one out only when the
  client did not give a readable value; the item list still follows.
- One `i=` per visible slot that holds an item, in the page's slot order (the
  order of the slot table). Empty slots and non-visual slots are left out.
- `apiItemId` is the item's `uniqueID`: the public API item id
  (`Sovereign Hoeth Robe of the Greatsage` is 435319; its client model `id` is
  8194 and is not in the link).
- `dyeA` and `dyeB` are `dyeTintA` and `dyeTintB`: palette ids, the same ids
  as the page's `tintpalette_equipment.csv` (224 is Evil Sun Red). `0` is an
  undyed channel.
- `appearanceName` and `iconNum` are present only when `customizedIconNum` is
  not zero. They are `customizedIconName` and `customizedIconNum` (measured:
  `Battle Brew Backpack`, 556 on the back slot). The public API has no override
  field, so this link is the only route for it. If the name cannot be read,
  the field is empty and the number is kept.
- URL encoding: the text is taken as UTF-8 bytes and every byte outside the
  unreserved characters `A-Z a-z 0-9 - . _ ~` becomes `%XX` (upper-case hex).
  A space is `%20`. The client holds names as UTF-16; the addon converts
  surrogate pairs to one character and a lone surrogate to U+FFFD.
- An item whose id or dyes cannot be read is left out, and the addon window
  says how many slots were left out.

Looks are not carried. `GameData.Player` exposes no face, hair, beard, tusks or
other creator options, and no `GetPlayerAppearance` or similar function
exists. The helm and cloak visibility toggles, heraldry, trophies and the
non-visual slots are not carried either.

## Slot table

`GameData.EquipSlots`, dumped in full. `DataUtils.GetEquipmentData()` returns
a table keyed by these numbers (20 entries; every slot from 1 to 20 is a
table, and an empty slot has `uniqueID` 0 and `id` 0). The addon reads by the
key, not by the item's `equipSlot` field: slot 11 held an item whose
`equipSlot` is 12, and slot 18 one whose `equipSlot` is 17.

| `GameData.EquipSlots` name | Number | Page slot key |
|---|---|---|
| RIGHT_HAND | 1 | `main_hand` |
| LEFT_HAND | 2 | `off_hand` |
| RANGED | 3 | `ranged` |
| EITHER_HAND | 4 | left out (an item type; the character window has no slot 4) |
| BANNER | 5 | left out (not visual) |
| BODY | 6 | `body` |
| GLOVES | 7 | `gloves` |
| BOOTS | 8 | `boots` |
| HELM | 9 | `helm` |
| SHOULDERS | 10 | `shoulders` |
| POCKET1 | 11 | left out (not visual) |
| POCKET2 | 12 | left out (not visual) |
| BACK | 13 | `back` |
| BELT | 14 | `belt` |
| EVENT | 15 | left out (not visual) |
| ACCESSORY1 | 17 | left out (not visual) |
| ACCESSORY2 | 18 | left out (not visual) |
| ACCESSORY3 | 19 | left out (not visual) |
| ACCESSORY4 | 20 | left out (not visual) |

No name maps to 16. Link order, the page's `SLOTS` order in
`web/src/careers.ts`: `helm`, `shoulders`, `body`, `gloves`, `belt`, `boots`,
`back`, `main_hand`, `off_hand`, `ranged`. The page's virtual `disc` slot has
no client slot and is never in the link. The addon looks the number up by
name in `GameData.EquipSlots` at run time and falls back to the measured
number.

## Career table

`GameData.Player.career` is a table: `{ id = 103, line = 20, name = "Archmage^m" }`
on the measured character. `line` is a `GameData.CareerLine` value; the addon
maps by `line`. The page keys are the `id` values of `CAREERS` in
`web/src/careers.ts`; four differ from the client constant name.

| `GameData.CareerLine` name | `line` | Page career key |
|---|---|---|
| IRON_BREAKER | 1 | `IRON_BREAKER` |
| SLAYER | 2 | `SLAYER` |
| RUNE_PRIEST | 3 | `RUNE_PRIEST` |
| ENGINEER | 4 | `ENGINEER` |
| BLACK_ORC | 5 | `BLACK_ORC` |
| CHOPPA | 6 | `CHOPPA` |
| SHAMAN | 7 | `SHAMAN` |
| SQUIG_HERDER | 8 | `SQUIG_HERDER` |
| WITCH_HUNTER | 9 | `WITCH_HUNTER` |
| KNIGHT | 10 | `KNIGHT_OF_THE_BLAZING_SUN` |
| BRIGHT_WIZARD | 11 | `BRIGHT_WIZARD` |
| WARRIOR_PRIEST | 12 | `WARRIOR_PRIEST` |
| CHOSEN | 13 | `CHOSEN` |
| MARAUDER | 14 | `MARAUDER` |
| ZEALOT | 15 | `ZEALOT` |
| MAGUS | 16 | `MAGUS` |
| SWORDMASTER | 17 | `SWORD_MASTER` |
| SHADOW_WARRIOR | 18 | `SHADOW_WARRIOR` |
| WHITE_LION | 19 | `WHITE_LION` |
| ARCHMAGE | 20 | `ARCHMAGE` |
| BLACKGUARD | 21 | `BLACK_GUARD` |
| WITCH_ELF | 22 | `WITCH_ELF` |
| DISCIPLE | 23 | `DISCIPLE_OF_KHAINE` |
| SORCERER | 24 | `SORCERER` |

Only `line` 20 has been read from a logged-in character; the other rows rest
on the constant table.

## Sex and name

- `GameData.Gender` is `{ MALE = 1, FEMALE = 2 }`. `GameData.Player.gender` is
  1 on the measured character, which gives `s=M`; 2 gives `s=F`.
- `GameData.Player.name` is the wide string `Aethelric^M`; `lastname` is
  `Starweave` and is not in the link. The addon cuts the name at the first
  `^`. If `gender` is unreadable it takes the letter after `^` (`M` or `F`)
  instead. What a female character's name carries has not been measured: no
  female character was logged in.

## Length

| Case | Fragment length (characters after `#`) | Whole link |
|---|---|---|
| Measured: Aethelric, 8 items (helm to back plus main hand, every visible slot he fills), one appearance override | 243 | 282 |
| Bound: 10 items, each with an appearance | at most 1,133 | at most 1,172 |

The bound adds the longest piece of each field: `KNIGHT_OF_THE_BLAZING_SUN`
(25 characters); a name of 24 characters that all encode to 6 (two UTF-8
bytes each; the client's name length limit was not measured); per item 95
characters: `;i=`, a 9-character key, a 10-digit id (the largest id in
`build/catalog/all_items.json` is 1,298,378,967), two 3-digit dyes (palette
ids run 1 to 652), a 57-character encoded appearance name (the longest
encoded item name among the 79,798 catalog rows) and a 5-digit icon number
(inferred, not measured), with their separators. Both stay under 2,000.

## Example

The link the addon produced on the live client on 2026-10-31:

```
https://scrytome.org/ror-gear-preview/#eq=1;c=ARCHMAGE;s=M;n=Aethelric;i=helm:435295:224:224;i=shoulders:435271:224:224;i=body:435319:224:224;i=gloves:435247:224:224;i=belt:435283:224:224;i=boots:435235:224:224;i=back:435307:224:224:Battle%20Brew%20Backpack:556;i=main_hand:3442:0:0
```

## Reading it from a script

The addon keeps the last link in the global `GearPreview.link`.
`GearPreview.BuildLink()` reads the client again and returns the link and
a table with `items`, `skipped`, `career`, `sex`, `name` and `length` (the
fragment length).
