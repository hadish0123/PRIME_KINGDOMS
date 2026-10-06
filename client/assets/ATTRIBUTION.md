# Third-party 3D assets

The character and village models used in this development build are by **Quaternius** and licensed under **CC0 1.0**. They can be used, modified and redistributed in commercial projects. The original artist's license and pack descriptions are available at:

- RPG Characters: https://quaternius.com/packs/rpgcharacters.html
- Medieval Village Pack: https://quaternius.com/packs/medievalvillage.html
- License: https://quaternius.com/license.html
- CC0 legal text: https://creativecommons.org/publicdomain/zero/1.0/legalcode

Characters: Ranger, Warrior, Monk. Buildings/props: house_1, house_2, house_3, inn, blacksmith, well, fence, cart and two market stands.

The artist's Google Drive distribution was unavailable at build time because of its download quota. These CC0 copies were retrieved from public mirrors:

- Original embedded glTF characters: https://github.com/euuuuuuan/cairnfall-public/tree/main/assets/vendor/quaternius_rpg
- Converted village GLB models: https://github.com/ArcaneHunters/World-of-Arcane-Hunters/tree/master/public/models/props

`tools/assets/sources.json` pins immutable source commits and each model's Git blob SHA. Run `npm ci --prefix tools/assets` and `npm run --prefix tools/assets prepare:models` before opening the client. GitHub Actions performs the same verified download automatically. Generated GLB files are embedded in the APK.

Character glTF files are repackaged into binary GLB. Village meshes are decompressed and dequantized for Godot. In-engine scaling, animation looping and collision shapes are supplied by this project. No code, music or other artwork from the mirror projects is included.
