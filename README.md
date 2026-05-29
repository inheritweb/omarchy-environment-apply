# omarchy-environment-apply

Apply an Omarchy desktop environment from a public environment repo.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/andyflan/omarchy-environment-apply/main/scripts/install.sh \
  | bash -s -- \
    --from https://raw.githubusercontent.com/andyflan/omarchy-environment-apply/main/bin/omarchy-environment-apply
```

This installs `omarchy-environment-apply` to `~/.local/bin`.

## Apply An Environment

```bash
omarchy-environment-apply github:owner/environment-repo
```

The environment repo should contain:

```text
environment.json
assets/
  wallpaper.jpg
```

Dependent files are loaded from `assets/`. In `environment.json`, use the filename:

## Environment File

```json
{
  "version": 1,
  "themes": {
    "install": [
      {
        "repo": "https://github.com/example/omarchy-forest-theme.git",
        "apply_theme": true
      }
    ],
    "backgrounds": [
      {
        "theme": "forest",
        "source": "wallpaper.jpg",
        "target_name": "wallpaper.jpg",
        "set_as_default": true
      }
    ]
  }
}
```

Supported top-level keys:

- `version`: must be `1`
- `themes.install[]`
- `themes.backgrounds[]`
- `files[]`
- `browsers.add/remove[]`
- `editors.add/remove[]`
- `packages.add/remove[]`
- `web_apps.add/remove[]`

See [examples/environment.json](examples/environment.json).

## Development

Run tests locally:

```bash
./tests/test.sh
```

Run tests in Docker:

```bash
docker compose run --rm tests
```

Install from a local checkout:

```bash
./scripts/install.sh --force
```

Apply a local environment file:

```bash
./bin/omarchy-environment-apply examples/environment.json
./bin/omarchy-environment-apply examples/environment.json --dry-run --verbose
```

## VM Testing

The VM helper boots Omarchy away from your real desktop and exposes VNC on `127.0.0.1:5900`.

```bash
./scripts/vm up
./scripts/vm key super-return
./scripts/vm screenshot
./scripts/vm down
./scripts/vm clear
./scripts/vm reset
```

`./scripts/vm up` builds the container and boots Omarchy. First boot currently opens the Omarchy installer over VNC at `127.0.0.1:5900`; complete that once, then later boots start from `.vm/omarchy.qcow2`.

### Keyboard Passthrough

When the host is also running Omarchy, host Hyprland shortcuts can intercept keys before they reach the VM.

Add a passthrough submap to the host Hyprland config:

```text
bind = SUPER, F10, submap, passthrough
submap = passthrough
bind = SUPER, F10, submap, reset
submap = reset
```

Then reload Hyprland:

```bash
omarchy restart hyprland
```

Press `Super+F10` before using the VNC window to pass shortcuts through to the guest. Press `Super+F10` again to return host shortcuts to normal.

Screenshots are saved under `.vm/screenshots/`. The Omarchy ISO is kept under `.vm/` and is not removed by `vm clear`.

Use `vm key` for key combinations that your host window manager captures:

```bash
./scripts/vm key super-return
./scripts/vm key super+space
./scripts/vm key ctrl-alt-f2
```
