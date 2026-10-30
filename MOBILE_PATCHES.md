# Mobile patches

The `mobile` branch carries local changes on top of upstream `main`.
`origin` is `tanakrit-d/BalatroMultiplayerAPI`; `upstream` is
`Balatro-Multiplayer/BalatroMultiplayerAPI`. No upstream pull request is needed.

## Steam-free Community login

The API starts and runs mod registration callbacks without Steam when a
custom server is selected. Community login uses the existing Steam identity
on desktop; without Steam it uses 32 bytes of OS randomness, saved as
`mpapi/mobile-device-id.txt` under LÖVE's game save directory. It never uses
the gameplay RNG or a shared guest identity. A read, format or write failure
stops login instead of silently creating another account. Official login
and forced Steam login retain the Steam requirement.

Install this branch's API alongside PvP, and configure the API:

```lua
return {
    ['chat_enabled'] = false,
    ['use_custom_server'] = true,
    ['server_host'] = 'YOUR_UNRAID_IP',
    ['server_port'] = 7350,
    ['server_secure'] = false,
    ['nakama_server_key'] = 'defaultkey',
    ['mobile_display_name'] = 'Your name',
}
```

Replace `YOUR_UNRAID_IP`. Set the server's `BMP_SERVER_KIND=community`.
If old settings override the config, remove `config/MultiplayerAPI.jkr`
from the game's save directory and restart. Leave `mpapi/mobile-device-id.txt`
in place. Back up that file privately: it grants access to the mobile account;
deleting it creates a new account, and copying it to another device shares
the account. Renaming the display name does not change the identity.

## Upstream updates

From a clean checkout:

```sh
git fetch upstream --tags
git switch mobile
git merge upstream/main
lua tests/mobile_login_test.lua
git diff --check
```

Resolve any conflicts while preserving both upstream behavior and this
patch. Test on a device before pushing `mobile` to `origin`. Use upstream
release tags instead of `upstream/main` when updating to a specific release.
Keep patch commits focused, merge rather than rebase published history, and
never use GitHub's fork sync to overwrite `mobile`.

The regression test covers persistence, invalid/unwritable credentials,
OS randomness failures, Steam-free startup and login, desktop Steam identity,
Official ticket authentication, and Dev impersonation. Before packaging,
test two separate devices, a complete PvP match, reconnect/backgrounding,
and a restart/mod update that retains the account. Native mobile networking
has not been validated by the standalone Lua tests.

Record the exact API and PvP commits used for each device-tested build in
`MOBILE_BASELINE.md`. Source archives from the `mobile` branch include these
patches; inherited upstream GitHub releases do not.
