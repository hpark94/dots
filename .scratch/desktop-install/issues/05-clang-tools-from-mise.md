# 05: clangd, clang-format and clang-tidy from mise

**What to build:** The three C/C++ tools nvim uses (clangd as the language
server, clang-format through conform, clang-tidy through nvim-lint) come from
the toolchain file, on every machine and both Roles, and no longer from a
hand-extracted 12 GB LLVM tarball.

**Blocked by:** None, can start immediately.

**Status:** ready-for-agent

- [ ] `.config/mise/config.toml` has the three entries from the spec,
      `"github:clangd/clangd" = "22.1.6"`, `"pypi:clang-format" = "23.1.1"` and
      `"pypi:clang-tidy" = "22.1.8"`.
- [ ] Proven in a scratch directory with `~/.local/llvm` off `PATH` and
      `MISE_DATA_DIR`, `MISE_CACHE_DIR`, `MISE_STATE_DIR` and `MISE_CONFIG_DIR`
      redirected, with the live install count unchanged before and after:
      clang-format formats against the repo's `.clang-format`, clangd attaches
      to a `cpp` buffer, and nvim-lint runs clang-tidy on it.
- [ ] The report says what the proof needed for the C++ standard library: the
      reference machine has no `gcc-c++`, and the roster row that supplies it
      arrives with ticket 02.

**Further Notes:** Spec section "C/C++ tooling from mise". clangd and
clang-format were decided and proved in
[What the configs must stop assuming](../../distro-provisioning/issues/06-config-assumptions.md)
section 7, which gives the proof's method. clang-tidy was added in the handoff,
[Turn the decisions into a spec and build tickets](../../distro-provisioning/issues/09-spec-and-build-tickets.md),
because `nvim-lint.lua:15` runs it and it came from the same tarball. Removing
the tarball and the `~/.env` lines is ticket 08.
