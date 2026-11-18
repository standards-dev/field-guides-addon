# Standards.gg Field Guides — WoW Forever addon

The [Standards.gg Field Guides](https://standards.gg/field-guides/) (version 1.7.0) inside World of Warcraft: Forever.
All nine classes and 28 specializations, with talent builds, leveling routes, stat priorities, rotations, macros, the dungeon loot atlas, professions, crafts and quest gear.

## Download

Get **`StandardsGuides-Forever-1.7.0-addon.zip`** from the [Releases](../../releases) page.

## Install

1. Close the game.
2. Extract the zip into `World of Warcraft\_forever_\Interface\AddOns`.
   You should end up with ten folders: `StandardsGuides` plus one `StandardsGuides_<Class>` data pack per class.
3. Start the game. On the character screen, open **AddOns** and make sure **Standards.gg Field Guides** is enabled.

The addon is built for WoW Forever (`## Interface: 16001`).
To try it on Classic Era (Hardcore / Era / Season of Discovery), change `## Interface: 16001` to `## Interface: 11509` in the ten `.toc` files.
The guide content is written for Forever, so some talents and items will not exist there.

## Use

| Command | What it does |
| --- | --- |
| `/sgg` | Open or close the field guides hub |
| `/sgg me` | Open your class guide |
| `/sgg mage fire` | Open a specific guide |
| `/sgg talents` | Show what the game reports for your talent trees (useful if a tree will not load) |
| `/sgg perf` | Show render time, shown widgets and memory |
| `/sgg scale 0.8` | Window scale (0.5–1.5) |
| `/sgg minimap` | Show or hide the minimap button |
| `/sgg pins` | List dungeon and open-world quests above level 30 (`/sgg pins mage` or `/sgg pins tanaris` filters) |
| `/sgg pin <quest or npc>` | Open the map on the quest giver and set the map pin (waypoint) there |
| `/sgg reset` | Re-centre the window |

Minimap button: left-click opens the hub, right-click opens your class guide.

## Features

- **Hub and guides:** the site's layout in the WoW UI colour palette, with section navigation and search.
- **Talents:**
  - Your class's trees come straight from the game, with a level preview.
  - If the game has not shared a class's trees yet (a new character is still loading, or another class than yours), the guide draws the Forever trees bundled with that class pack and refreshes to the game's own trees once they load.
  - **Apply build** learns your unspent points in the guide's leveling order. It asks first, runs out of combat only, and works on your own class.
- **Dungeon loot atlas, crafts and quest gear:**
  - Filters and search.
  - Item icons and tooltips come from the game: Shift-click links an item, Ctrl-click previews it.
- **Atlas:** dungeons and quest givers open on the zone map, or as a pin on the world map.
- **Macros:** **Create macro** adds the macro and puts it on your cursor.
- **Personal notes:** saved per specialization.
- **Lightweight:** class data loads only when you open that class; only what's on screen is drawn.

## Terms

© Standards.gg. All rights reserved. You may download and use this addon. You may not modify it or redistribute modified copies. See [LICENSE](LICENSE).

Anyone who collects content or data from these guides must credit Standards.gg and link to https://standards.gg/field-guides/ (or the guide page they used) in any content they create with it.
This covers text, talent builds, stat priorities, item and loot lists, screenshots and recordings, datasets, and use in AI training or AI-generated answers.

**Credit line:** `Source: Standards.gg Field Guides - https://standards.gg/field-guides/`

Fonts: Cinzel and Inter, used under the SIL Open Font License 1.1. The license texts are in `StandardsGuides/Fonts`.

Class artwork comes from the World of Warcraft Fan Site Kit.
World of Warcraft® and Blizzard Entertainment® are trademarks or registered trademarks of Blizzard Entertainment, Inc. in the U.S. and/or other countries.
This addon is not associated with or endorsed by Blizzard Entertainment.

## 1.7.0: dungeon quests and pins

- The nine Sunken Temple class-quest chains add three rewards per class (item ids and rarity from the DungeonJournal addon; stats and spec fit are community-reported and not verified in Forever).
- `QuestPins.lua` lists all 271 dungeon quests above level 30 (every Forever dungeon), with levels, prerequisites, rewards and class restrictions, taken from the DungeonJournal addon 2.0.9. 180 of them have a map position and can be pinned.
- `/sgg pins <text>` searches by dungeon, zone, quest giver, reward, class or spec (`/sgg pins blackrock`, `/sgg pins winterspring`, `/sgg pins warlock`). Open-world entries (506 quests with item rewards) show which classes and specs the reward items suit, worked out from item stats, not a ranking; `/sgg pin <quest>` opens the map there and sets the waypoint.
