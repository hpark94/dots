# 06 Shape of the shared note config

> **Superseded 2026-07-27:** the notetaking rewrite is being re-grilled from scratch. The dedicated `.scratch/notetaking-rewrite/` spec and tickets were removed, and this ticket's decisions are kept only as historical input, no longer authoritative.

**Type:** `grilling`

**Status:** resolved

**Blocked by:** None, can start immediately

**Map:** [Portable dotfiles](../map.md)

## Question

What format and shape does the one config shared by `note` and the nvim notetaking module take,
and how does each consumer read it?

(It was three consumers when this was written. [04](04-note-restructure-prototype.md) deleted
`scratch`.)

### The problem being solved

`.config/notes/config.sh` is a **bash file**, so bash consumers get it for free and every other
consumer pays. nvim pays per lookup: `util.lua:get_note_path` runs

```
vim.fn.system({ "bash", "-c", "source <config_path> && echo $<VAR>" })
```

`get_base_path` and `get_assets_path` both call it, `is_note()` calls `get_base_path` via
`is_in_vault()`, and `is_note()` gates nearly every notetaking action. So a synchronous bash
subprocess fires on essentially every note operation, to read a string constant.

The config file also mixes three different kinds of thing that may not belong together: path
constants (`VAULT_*`), behavior (`normalize_filename`, `handle_exe`, `check_args`), and a directory
guard with a side effect (`check_dirs`, which creates directories on every `note` invocation).

### Carry into the session

- **nvim needs no `jq` and no subprocess at all** if the format is JSON: `vim.json.decode` reads it
  natively. Bash would need `jq`, which is already a hard dependency here (`mise` pins
  `jq = "1.8.1"`, and `.config/sway/config:119` uses it in a keybind). TOML is the reverse trade:
  nicer to hand-edit, but neither bash nor nvim reads it without help.
- The functions in `config.sh` are not config. Decide whether they move into the script, into a
  shared library, or disappear because the rewrite made them unnecessary.

### Hard constraint from [01](01-name-the-split.md): an absent config must fail closed

**Today it fails open, in the worst possible direction.** `util.lua:49` reads every value with

```
vim.fn.system({ "bash", "-c", "source <config_path> && echo $<VAR>" })
```

If the config is missing or unreadable, `source` fails, `&&` short-circuits, nothing is echoed, and
`get_base_path()` returns `""`. `is_in_vault()` then evaluates
`vim.startswith(currentpath, "")`, which is **true for every path in existence**. So `is_note()`
returns true for every markdown buffer, and the notetaking mappings go live and wrong on files that
have nothing to do with the vault.

Note the failure is silent on both sides: `vim.fn.system` swallows the non-zero exit, and an empty
base path is indistinguishable from a legitimately configured one.

**Whatever format is chosen must make a missing, empty, or unparseable config produce "not a note",
never "everything is a note."** This is a property of the *reading* path, so it survives any answer
to the format question, and it should be stated as a requirement rather than left to fall out of the
implementation.

### What [01](01-name-the-split.md) settled, and how it simplifies this

- **The vault is Desktop-only, but this config ships to both Roles.** `note` and `scratch` carry a
  Role check; `.config/notes/` and the nvim module do not. The config ships everywhere *precisely
  because* its absence is what triggers the fail-open above.
- **There are no machine-varying paths to design for.** The config is byte-identical on every
  machine, and the Role check lives in the scripts rather than in the config. That removes the
  "what happens to machine-varying paths" question this ticket was originally going to have to
  answer, and it means the format needs no conditionals, no templating and no per-host layer.
- **`check_dirs` is the one side effect to keep isolated.** It is what makes `note` non-inert on a
  Headless machine, `mkdir -p`ing a vault tree that syncs nowhere. Sourcing the config alone is
  already safe, since `note:3` calls `check_dirs` explicitly rather than the config running it at
  load time. Preserve that property: loading config must stay free of side effects.

### What [04](04-note-restructure-prototype.md) settled

- **`note` stays bash and drops python entirely**, so the `jq`-versus-native-parse trade stands
  rather than dissolving: bash consumers still read the config for free and nvim still pays.
- **`scratch` is deleted**, so there are now **two** consumers, not three: `note` and the nvim module.
- **The roster shrank to 7 flags and the vault went flat.** The `VAULT_*` path constants mostly
  disappear with it: there is no `VAULT_DAILY_PATH`, `VAULT_ZETTEL_PATH` or `VAULT_SCRATCH_PATH` any
  more, only a base path plus `assets/` and `templates/`. Whatever this config becomes is far smaller
  than `config.sh` is today, which should be weighed before picking a format with any ceremony to it.
- **`normalize_filename` and `handle_exe` are gone.** The first is now a locale-aware bash function
  with no python, the second dies with `--nvim-mode`. Of the three functions in `config.sh` only
  `check_args` survives in any form, which sharpens the "the functions are not config" point above:
  there may be nothing left to relocate.
- **A new hard requirement, verified:** whoever reads this config must not inherit its locale.
  `export LC_ALL="${NOTE_LOCALE:-C.UTF-8}"` has to happen before any `[[:alnum:]]` matching. Under an
  inherited `LC_ALL=C` a Korean title slugs to the **empty string**, not to a stripped-down version,
  so the filename becomes a hidden `.md` that every Korean-titled note collapses into. If this config
  ever grows a "where does the locale come from" answer, that is the constraint it must satisfy.

### What resolution must cover

Format, what is in it and what is not, how each of the two consumers reads it, and how each
consumer's read path satisfies the fail-closed constraint above.

## Answer

### Format: JSON, at `~/.config/notes/config.json`

Decided on verified dependency facts, not preference:

| | bash | nvim |
|---|---|---|
| **JSON** | `jq`, already pinned (`mise` 1.8.1) and already used in `sway/config:119` | `vim.json.decode`, **built into nvim** |
| **TOML** | no reader present: no `yq`, `taplo`, `dasel`, `tomlq` | no Lua `toml` module, and `treesitter.lua:8-34` installs `json` but **not** `toml` |

TOML would cost a new CLI *and* a new nvim plugin whose only job is reading one path, and it would
replace a bash subprocess with a plugin dependency rather than removing a dependency. JSON removes
the subprocess outright, which is the complaint this ticket was opened about.

The operator noted a general preference for comments in configuration, which TOML alone offers. That
is served instead by a README section documenting the schema. This is a public repo, and people read
the README, not `~/.config/notes/config.json`. No separate `config.example.json` is needed, because
the tracked `config.json` *is* the worked example (see the last section).

### What is in it, and what is not

```json
{
  "vault": "~/Sync/vault"
}
```

**One key.** The vault path is genuinely configurable: it is a Syncthing folder today, the operator
wants to be able to move it, and a public user will have it somewhere else.

Everything else that is in `config.sh` today is **not config** and does not survive:

- `VAULT_ASSETS_PATH` is **derived** (`<vault>/assets`), as is the vault's `templates/`.
  [04](04-note-restructure-prototype.md) fixed the layout, so these are not choices.
- `VAULT_DAILY_PATH`, `VAULT_SCRATCH_PATH`, `VAULT_ZETTEL_PATH` are **gone** with the flat vault.
- `SYNC_FOLDER_PATH` and `NOTIZEN_CONFIG_PATH` are used **only inside `config.sh` itself** to build
  other variables. They were never consumed anywhere else; they are intermediates, not settings.
- `NOTIZEN_TEMPL_PATH` is a fixed XDG location (`~/.config/notes/templates`), not a user choice.

**`~` is expanded by each consumer at read time**, since JSON has no shell expansion. Both sides must
do this identically or the two disagree about where the vault is: bash `${v/#\~/$HOME}`, Lua
`vim.fn.expand(v)`.

### How each consumer reads it

Two consumers, not three: [04](04-note-restructure-prototype.md) deleted `scratch`.

**bash**, one `jq` call at startup rather than one per value:

```sh
v=$(jq -er '.vault // empty' "$config") || die "no .vault in $config"
[[ -n $v ]] || die "empty vault in $config"
vault="${v/#\~/$HOME}"
```

**nvim**, no subprocess at all, read **once at `setup()`** and cached rather than per lookup:

```lua
if not vim.uv.fs_stat(path) then return nil end
local ok, lines = pcall(vim.fn.readfile, path)
if not ok then return nil end
local ok2, cfg = pcall(vim.json.decode, table.concat(lines, "\n"))
if not ok2 or type(cfg) ~= "table" then return nil end
if type(cfg.vault) ~= "string" or cfg.vault == "" then return nil end
return vim.fn.expand(cfg.vault)
```

Caching at setup means editing the config needs an nvim restart. That is a deliberate trade: today
`is_note()` gates nearly every notetaking action and each call spawns `bash` to read a string
constant.

### The fail-closed constraint is satisfied, and verified

Executed in this repo's actual nvim, not reasoned:

```
today's bug: vim.startswith('/etc/passwd', '') = true

  good.json      base=/home/hpark/Sync/vault   is_in_vault('/etc/passwd')=false
  empty.json     base=nil                      is_in_vault('/etc/passwd')=false
  broken.json    base=nil                      is_in_vault('/etc/passwd')=false
  missing.json   base=nil                      is_in_vault('/etc/passwd')=false
  good.json      base=/home/hpark/Sync/vault   is_in_vault(<vault>/x.md)=true
```

The fix is structural rather than a patch. A file read **distinguishes absent from present**: a
missing file, malformed JSON and an empty value all produce `nil`, whereas today `vim.fn.system`
returns `""` on failure, which is indistinguishable from success and matches every path on the
system. `is_in_vault` gains one guard: `if not base or base == "" then return false end`.

The bash side fails closed on the same four cases, verified: unreadable, absent key, malformed, empty.

### `.config/notes/config.sh` is deleted outright

Nothing in it survives as config, and [04](04-note-restructure-prototype.md) killed the rest:

| | fate |
|---|---|
| `VAULT_*` / `NOTIZEN_*` | one JSON key plus derivations |
| `check_dirs` | `note` creates what it needs, at the point of need |
| `normalize_filename` | gone; the slug is now locale-aware bash with no python |
| `handle_exe` | gone with `--nvim-mode` |
| `check_args` | folds into `note` |

The "are the functions config, and where do they move" question this ticket carried therefore
resolves to **nowhere: there is nothing left to relocate.**

### Tracked, not an example-copy

`config.json` is **tracked and stowed**. It is not a Write-Back Config in the sense
[05](05-choose-deployment-mechanism.md) defined: no tool rewrites it, so the `~/.gitconfig` treatment
does not apply, and an untracked copy would reintroduce exactly the ordering trap
[05](05-choose-deployment-mechanism.md) removed. It also satisfies
[01](01-name-the-split.md)'s requirement that this config ship to both Roles.

A public user editing it sees one modified tracked file, which is honest and is what forking is for.
`note` remains Desktop-only by its Role check, per [01](01-name-the-split.md); the config shipping
everywhere does not make the vault exist everywhere.
