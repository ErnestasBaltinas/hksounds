# HK Sounds

**HK Sounds** is a World of Warcraft Lua addon that brings **Unreal Tournament–style announcer sounds** to your PvP experience. Hear the classic “Killing Spree”, “Rampage”, and “Godlike” shoutouts as you dominate battlegrounds, arenas, and open-world PvP.

---

## Features

🎯 **UT-style announcer sounds** for:

- First Blood
- Killing Sprees
- Multi-Kills

🎵 All of HK Sounds’ audio files are stored inside the `hksounds/sounds/` folder. This is where the addon looks for announcer sounds, and you can safely replace the `.ogg` files with your own custom sounds as long as you keep the original filenames intact.

🎛 **Customizable Sound Packs**

- Choose between **UT Classic (Male)** and **UT Classic (Female)**.
- To change the sound pack, type the slash command: `/hks` or `/hksounds` in chat to open addon options page.

🔊 **Single Sound Mode**

- If sound packs are not your thing, you can switch to **Single Sound** mode and choose one of the available sounds from the list. Once selected, the same sound will play on every killing blow.
- If you have ideas for new sounds you’d like to use, feel free to share them — they can be added to the list in future updates.
- Available sounds: `arrowimpact.ogg`, `bonk.ogg`, `gunshot.ogg`, `gunshot2.ogg`, `murky.ogg`, `murloc.ogg`, `wegothim.ogg`

⚔️ **Works in:**

- Battlegrounds
- Arenas
- Open-world PvP

🧠 **Blizzard API–friendly:** Designed around modern WoW API limitations.

---

## Important Note (Blizzard API Restrictions)

Blizzard has restricted certain combat API data in PvP instances:

- In battlegrounds and arenas, reliable attacker/victim data is no longer exposed.
- Pet kills and some edge cases may also trigger sounds.
- Behavior depends entirely on Blizzard’s event system and the information it allows addons to access.

This is currently the **most reliable method possible** within Blizzard’s restrictions.

---

## Inspiration

This addon was inspired by the classic addon **`FemaleAnnouncer`**, which is no longer supported.  
HK Sounds retains all the main functionality of the original, but is rebuilt with **new code** to work seamlessly with the latest WoW API changes (Midnight).
