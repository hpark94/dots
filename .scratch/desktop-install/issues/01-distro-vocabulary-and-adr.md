# 01: Distro Fact, a sharper Capability Probe, and ADR-0011

**What to build:** The glossary gives a name to a difference between distros and
says where that kind of difference is allowed to go. The Capability Probe entry
separates a probe that adapts from a precondition check that refuses. An ADR
records that the deployed tree never reads the distro, which would otherwise be
an absence of code that nobody can explain.

**Blocked by:** None, can start immediately.

**Status:** done

- [x] `CONTEXT.md` has the **Distro Fact** entry under Deployment, next to Role
      Fact, verbatim from the spec section "Nothing deployed reads the distro".
- [x] The **Capability Probe** entry ends with the two sentences from the spec
      section "A probe adapts, a precondition check refuses", and its `_Avoid_`
      line reads as given there, with both additions: the distro's name, and a
      `command -v` that exits.
- [x] `docs/adr/0011-the-deployed-tree-never-reads-the-distro.md` exists in the
      form of the other ADRs. It records the decision, the two refused
      alternatives (reading `os-release` in deployed code, and inside an install
      artifact), that there is no Distro Marker and why, and that a vendor
      command quoted in a documented step is not a violation. Its content is 01
      sections 2 to 5, which specified it without writing it.
- [x] `grep -rn "os-release\|ID_LIKE"` over the tracked tree, excluding
      `.scratch`, finds only prose, so the ADR describes the repo as it stands.

**Further Notes:** Spec: `.scratch/desktop-install/spec.md`, sections "Nothing
deployed reads the distro" and "A probe adapts, a precondition check refuses".
The reasoning is in
[Name the distro divergence](../../distro-provisioning/issues/01-name-the-distro-divergence.md)
sections 1 to 5 and
[What the configs must stop assuming](../../distro-provisioning/issues/06-config-assumptions.md)
section 2. The Completeness Check entry is ticket 06's and is not written here.
