# HostZen eggs

[Calagopus](https://calagopus.com) eggs used by [HostZen](https://hostzen.net). Import `<egg>/egg-<egg>.json` in Admin → Nests, or add this repository under Admin → Egg Repositories.

## FXServer (`fxserver/`)

FiveM and RedM, with txAdmin on by default. Pairs with the HostZen FiveM extension, whose Artifacts page picks the FXServer version, but works without it (recommended or latest build).

- Installs fail with a clear reason, so the panel can show the log and offer a retry. A failed install leaves the previous FXServer build in place.
- `alpine/` (the FXServer build) is hidden from the file manager and SFTP.
- CFX's default resources are copied only when asked for (or on a new server without txAdmin).
- txAdmin is branded through its `TXHOST_*` host variables. The extension gives txAdmin the server's second port automatically.
- The game (FiveM or RedM) is an admin-only variable, so one egg covers both.

Images come from [HostZen/yolks](https://github.com/HostZen/yolks).

## Editing

Each egg is `egg.base.json` plus `install.sh`. Run `node scripts/build.mjs` to rebuild `egg-<egg>.json` (CI checks it's up to date).
