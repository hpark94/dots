# 15 What `.env` holds, and whether `.envs.sh` needs the Role Marker

**Type:** `grilling`

**Status:** resolved

**Blocked by:** None, can start immediately

**Map:** [Portable dotfiles](../map.md)

## Question

Graduated from the map's fog patch on machine-local overrides and secrets. Two
small questions left after [05](05-choose-deployment-mechanism.md) resolved
`.gitconfig`, [01](01-name-the-split.md) resolved the Role Marker, and
[12](12-ssh-config-ownership.md) resolved `~/.ssh/config`:

1. What belongs in the `${HOME}/.env` that `.envs.sh:11-13` sources if present?
   It is untracked and undocumented today.
2. Does `.envs.sh` itself need the Role Marker at all, given it is a shared,
   tracked file that ships identically to both Roles?

## Answer

**1. `.env` is machine-local secrets: credentials, tokens, and anything else in
that class.** It stays untracked, undocumented beyond that scope statement, and
sourced conditionally (`.envs.sh:11 [[ -f "${HOME}/.env" ]]`). No further sweep
for other Write-Back Configs was requested; `gh`'s `~/.gitconfig` write remains
the only one found.

**2. No, and this was already the shape after [13](13-role-marker-reader.md).**
`.envs.sh` is tracked, ships byte-identical to both Roles per
[01](01-name-the-split.md), and reads no Role Marker:
[13](13-role-marker-reader.md) already moved `DOCKER_HOST`,
`LIBVIRT_DEFAULT_URI` and `OMPI_CXX` from Role Fact to Capability Probe for
exactly this reason, to keep the Marker off the login path. This ticket confirms
rather than changes that design; no new mechanism follows from it.

This closes the map's "Machine-local overrides and secrets" fog patch. Nothing
further graduates from it.
