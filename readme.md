# Rhythm Dungeon Crawler

A dark fantasy dungeon crawler that combines rhythm-based combat, card-based equipment, and village restoration. Explore branching dungeon routes, defeat monsters and bosses, collect loot, and spend expedition earnings to rebuild your village.

Built with **Godot 4.5.1** and **GDScript**, using the GL Compatibility renderer.

## Features

- **Rhythm-based combat:** time attacks and guards as notes reach the target line.
- **Dungeon exploration:** choose doors, face encounters, and defeat the boss at the end of each floor.
- **Equipment and consumables:** collect weapons, armor, amulets, potions, and scrolls.
- **Rest areas:** recover at campfires, sharpen weapons, and sell items to a merchant.
- **Village restoration:** use gold from expeditions to restore buildings across multiple stages.
- **Two expedition modes:** a timed 100-floor run and an endless descent with saved progress.
- **Settings:** remappable keyboard controls, audio levels, resolution, and language selection.
- **Languages:** English, Russian, Spanish, and Simplified Chinese.

## Installation and setup

### Requirements

- [Godot 4.5.1 Standard](https://godotengine.org/download/archive/4.5.1-stable/) for your operating system.
- Git to clone the repository, or a downloaded ZIP of the source code.

The project uses GDScript; the Standard edition of Godot is sufficient.

### Run from source

1. Download and extract Godot 4.5.1 Standard.
2. Clone this repository:

   ```sh
   git clone https://github.com/SBC69/Rhythm-Dungeon-Crawler.git
   cd Rhythm-Dungeon-Crawler
   ```

   Alternatively, select **Code → Download ZIP** on GitHub and extract the archive.

3. Open Godot's Project Manager, select **Import**, and choose `project.godot` from the project folder.
4. Open the project and wait for Godot to finish importing its resources.
5. Press **F5** to start the game.

The repository contains the source project. Exported Windows executables in `builds/` are excluded by `.gitignore`.

## How to play

Start a new game from the main menu and choose an expedition mode:

- **100 Floors Run (Timed):** clear 100 floors while tracking your completion time.
- **Endless Descent:** descend as far as you can, continue a saved expedition, or retire at a campfire.

Choose a door to enter the next encounter. In combat, use the attack and guard inputs when the corresponding notes reach the target line. Equip loot through the inventory and manage your health and consumables between encounters. Visit the village between expeditions to spend your wallet gold on restoration.

### Default controls

| Action | Input |
| --- | --- |
| Select interface elements | Mouse, arrow keys, or Tab / Shift+Tab |
| Confirm a selection | Enter or Space |
| Back / close supported menus | Esc |
| Rhythm attack | Space or Enter |
| Rhythm guard | Shift or right mouse button |
| Inventory | I |

Combat also provides on-screen attack and guard buttons. Gamepad navigation uses the D-pad or left stick, with **A** to confirm and **B** to go back; rhythm combat uses **A** to attack and **B** to guard.

Keyboard bindings, language, resolution, and audio levels can be changed in **Settings**.

## Build for Windows

The project includes a **Windows Desktop** export preset targeting **x86_64**, with game resources embedded in the executable.

1. Open the project in Godot 4.5.1.
2. Open **Editor → Manage Export Templates** and install the **4.5.1** export templates.
3. Open **Project → Export** and select **Windows Desktop**.
4. Select **Export Project**, disable **Export With Debug** for a release build, and save the executable as `builds/windows/RhythmDungeonCrawler.exe`.
5. Run the exported executable to play without the Godot editor.

You can also use `build_windows.bat` on Windows. Before running it, update the Godot executable path in the script to match your installation; it currently points to `D:\godot\Godot_v4.5.1-stable_win64_console.exe`.

## Project structure

| Path | Contents |
| --- | --- |
| `project.godot` | Godot project configuration and entry scene |
| `scenes/` | Game scenes and interface layouts |
| `scripts/` | Gameplay, combat, persistence, village, and interface logic |
| `assets/` | Artwork, audio, fonts, themes, and game data |
| `localization/` | Translation tables and imported translations |
| `design/` | Design proposals and balance materials |
| `tests/` | Automated tests and visual checks |
| `export_presets.cfg` | Windows export configuration |
| `build_windows.bat` | Windows release build helper |
