# GearPreview

Source for the GearPreview addon for Return of Reckoning. The addon package is the `GearPreview/` folder; the site builds each release from it.

GearPreview adds a **scryTome Gear Preview** button to the character window. It builds a link to the [scryTome Gear Preview](https://scrytome.org/ror-gear-preview/) with your career, your worn items, their dyes and any appearance you applied to them, so you can see your look in a browser and share it.

## Install

Install it from the [addon site](https://addons.returnofreckoning.com/addons/gearpreview) or the launcher. By hand: put the `GearPreview` folder in the game's `Interface\AddOns` folder and start the game.

## Use

1. Open the character window and press the scryTome Gear Preview icon in its title bar, or type `/gp`.
2. The window shows your name, how many items the link holds and the link, already selected. Press Ctrl+A, Ctrl+C.
3. Paste the link into a browser.

The window closes with the button, `/gp`, Close or Escape.

## What the link carries

- Career, sex and name.
- Every item in a visible slot: helm, shoulders, body, gloves, belt, boots, cloak, main hand, off hand, ranged. Banner, pockets, accessories and the event slot are not visible on the figure and are left out.
- Both dye colours of each item.
- An appearance applied to an item: the figure wears that look; the item stays the one you wear.

Not carried: face, hair, beard, tusks and the other creator choices (the game does not let addons read them), the helm and cloak show/hide settings, and heraldry.

The addon reads the character window's data and nothing else. It saves nothing, sends nothing and writes no files.

## Status

The page reads these links since 2026-11-01: it opens your character with the worn items, dyes and appearances the link carries.

The link grammar and the measured slot and career tables are in [docs/link.md](docs/link.md).

## Contributing

Open an issue to discuss a change, then fork and submit a pull request. Keep the package layout intact and say how the change was checked in game.

## Publishing

The addon site is linked to this repository and packages each pushed version tag (`v0.1.0`, `v0.2.0-beta.1`). It writes the version and release date into `GearPreview.mod`, so the source keeps `version="@project-version@"` and `date="@project-date@"`.

## License

MIT, see [LICENSE](LICENSE).
