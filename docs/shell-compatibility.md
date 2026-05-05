# Shell Compatibility

All `oz_pw_*.sh` scripts and `bin/warp-tools` must run identically under:
- **bash 4.0+** (macOS Homebrew bash 5+, Linux distro bash 4.0+)
- **zsh 5.0+** (macOS system zsh 5.9, Linux distro zsh 5.0+)

Scripts use `#!/usr/bin/env bash` shebang but are written in the POSIX+common-subset
so that CI can also run them explicitly under `zsh` for compatibility validation.

---

## Forbidden Constructs

The following constructs are NOT allowed in any `oz_pw_*.sh` or `bin/warp-tools` script,
because they are either bash-only or zsh-only and would break compatibility:

### Associative Arrays

**Forbidden:**
```bash
declare -A mymap     # bash-only (without typeset -A fallback)
typeset -A mymap     # zsh-only syntax in bash context
mymap[key]=value
```

**Allowed alternative:** Use individual scalar variables or positional lookups.

### zsh-only Globbing

**Forbidden:**
```bash
ls **/*(N)           # zsh-only recursive glob with NULL_GLOB
```

**Allowed alternative:** Use `find` or explicit loops.

### zsh-only Parameter Expansion

**Forbidden:**
```bash
result=${(j:,:)arr}  # zsh parameter expansion flags
```

**Allowed alternative:** Use `printf` or `awk` to join values.

### bash-only Variable Tests

**Forbidden:**
```bash
[[ -v myvar ]]       # bash 4.2+ only — not portable to zsh < 5.3
```

**Allowed alternative:**
```bash
[ -n "${myvar+x}" ]  # POSIX-compatible unset test
```

### Process Substitution (on untested paths)

**Forbidden (on paths that may not be supported):**
```bash
diff <(cmd1) <(cmd2)  # may not work correctly in all zsh contexts
```

**Allowed:** Use temporary files or sequential variable capture instead.

### Bash-only `echo` Behavior

**Forbidden:**
```bash
echo "line\n"         # behavior differs between bash and zsh
```

**Allowed alternative:**
```bash
printf 'line\n'       # always portable
```

### `[[ ]]` Extended Tests (Use Judiciously)

`[[` works in both bash and zsh but is not POSIX. It is permitted as a known
common-subset feature BUT only for patterns that are identical in both shells.
Prefer `[` (single bracket) and `case` for maximum portability.

---

## Required Patterns

### Shebang
```bash
#!/usr/bin/env bash
```

### Error Handling
```bash
set -euo pipefail
```

### Sourcing files
```bash
# shellcheck source=/dev/null
. "${PROFILES_ENV}"   # Use . (dot) not source; source is bash-only in strict POSIX
```

### String Operations
```bash
# Use external tools, not bash-specific expansions
trimmed="$(printf '%s' "$str" | sed 's/^ *//;s/ *$//')"  # NOT ${str# } or ${str% }
```

### Reading Profile IDs
```bash
resolve_profile_id() {
  local name="$1"
  oz agent profile list 2>/dev/null \
    | awk -F'┆' -v n="$name" '$2 ~ "^[[:space:]]*" n { gsub(/[^a-zA-Z0-9]/, "", $1); print $1 }' \
    | head -1
}
```

---

## CI Test Matrix

The `tests/shell_compat/run_compat.sh` fixture runs every script against four environments:

| Environment | Interpreter | Version |
|---|---|---|
| macOS | zsh | 5.9 (system) |
| macOS | bash | 5.x (Homebrew) |
| Linux | bash | 4.0+ (distro) |
| Linux | zsh | 5.0+ (distro) |

Any difference in exit code, output content, or side effects between interpreters is a
**ship blocker** — fix the script before merging.

### Running locally

```bash
# Run the compat suite under both interpreters
bash tests/shell_compat/run_compat.sh
zsh  tests/shell_compat/run_compat.sh

# Run the negative rule test under both interpreters
bash tests/test_oz_pw_plan_negative_rule.sh
zsh  tests/test_oz_pw_plan_negative_rule.sh

# Run via doctor (includes self-test)
bin/warp-tools doctor --self-test
```

Last Updated: 2026.04.24 @ 21:54:03
