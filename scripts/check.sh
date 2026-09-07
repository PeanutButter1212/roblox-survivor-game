#!/usr/bin/env bash
# check.sh — the project's verification gate.
#
# Runs every mechanical check we can do without Roblox Studio:
#   1. format    stylua   — formatting matches stylua.toml
#   2. lint      selene   — Lua/Roblox lint with the real Roblox standard library
#   3. typecheck luau-lsp — strict Luau typecheck with Roblox API definitions
#   4. build     rojo     — the project actually assembles into a place file
#
# Usage:
#   scripts/check.sh            run all gates
#   scripts/check.sh --fix      auto-format first, then run all gates
#   scripts/check.sh --strict   also fail on lint warnings (not just errors)
#
# Exit code is 0 only if every gate passed.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

FIX=0
STRICT=0
for arg in "$@"; do
	case "$arg" in
		--fix) FIX=1 ;;
		--strict) STRICT=1 ;;
		*) echo "unknown flag: $arg" >&2; exit 2 ;;
	esac
done

LUAU_LSP="${LUAU_LSP:-$HOME/.local/bin/luau-lsp}"
DEFS=".luau/globalTypes.d.luau"
# Pin the type definitions to the luau-lsp that reads them. Tracking the definitions repo's
# main branch meant the typechecker was pinned but its input wasn't: an upstream definitions
# change could turn CI red on a file nobody touched, while a developer whose copy was
# downloaded months ago still passed locally. Keep this in step with the version installed
# by scripts/setup.sh and by .github/workflows/verify.yml.
DEFS_TAG="${DEFS_TAG:-1.69.0}"
DEFS_STAMP=".luau/globalTypes.tag"
FAILED=()

hdr() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }
ok()  { printf '\033[32mPASS\033[0m  %s\n' "$1"; }
bad() { printf '\033[31mFAIL\033[0m  %s\n' "$1"; FAILED+=("$1"); }
note(){ printf '\033[33m ..\033[0m  %s\n' "$1"; }

need() {
	command -v "$1" >/dev/null 2>&1 || { echo "missing tool: $1 — run scripts/setup.sh" >&2; exit 2; }
}
need stylua; need selene; need rojo
# Fall back to PATH so this doesn't depend on luau-lsp living in one exact directory —
# the other three tools are resolved that way, and CI shouldn't break by installing
# somewhere else.
[ -x "$LUAU_LSP" ] || LUAU_LSP="$(command -v luau-lsp || true)"
[ -n "$LUAU_LSP" ] && [ -x "$LUAU_LSP" ] \
	|| { echo "missing tool: luau-lsp — run scripts/setup.sh" >&2; exit 2; }

# --- bootstrap generated artifacts (gitignored, regenerated on demand) -------------
if [ ! -f roblox.yml ]; then
	note "generating selene Roblox standard library (roblox.yml)"
	selene generate-roblox-std >/dev/null || { echo "could not generate roblox.yml (needs network)" >&2; exit 2; }
fi
# Re-download when the pin moves, not just when the file is missing, or a stale copy from
# an older pin would silently keep being used.
if [ ! -f "$DEFS" ] || [ "$(cat "$DEFS_STAMP" 2>/dev/null || echo none)" != "$DEFS_TAG" ]; then
	note "downloading Roblox type definitions ($DEFS @ $DEFS_TAG)"
	mkdir -p .luau
	curl -sfL --retry 3 --retry-all-errors -o "$DEFS" \
		"https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/${DEFS_TAG}/scripts/globalTypes.d.luau" \
		|| { echo "could not download $DEFS (needs network)" >&2; exit 2; }
	printf '%s' "$DEFS_TAG" > "$DEFS_STAMP"
fi
# The sourcemap tells luau-lsp how src/ maps onto the Roblox instance tree, so it can
# resolve `require(script:WaitForChild("Foo"))`. Cheap — always regenerate.
rojo sourcemap default.project.json -o sourcemap.json >/dev/null 2>&1 \
	|| { echo "rojo sourcemap failed — is default.project.json valid?" >&2; exit 2; }

# --- 1. format ---------------------------------------------------------------------
hdr "format (stylua)"
if [ "$FIX" -eq 1 ]; then
	stylua src/
	note "formatted src/ in place"
fi
if stylua --check src/; then
	ok "formatting"
else
	bad "formatting — run: scripts/check.sh --fix"
fi

# --- 2. lint -----------------------------------------------------------------------
hdr "lint (selene)"
selene src/ | tee /tmp/selene.out
# selene exits 1 for warnings as well as errors, so decide from its own summary line.
lint_errors=$(grep -oE '^[0-9]+ errors?$' /tmp/selene.out | grep -oE '^[0-9]+' || echo 0)
lint_warnings=$(grep -oE '^[0-9]+ warnings?$' /tmp/selene.out | grep -oE '^[0-9]+' || echo 0)
lint_parse=$(grep -oE '^[0-9]+ parse errors?$' /tmp/selene.out | grep -oE '^[0-9]+' || echo 0)
if [ "${lint_errors:-0}" -gt 0 ] || [ "${lint_parse:-0}" -gt 0 ]; then
	bad "lint — ${lint_errors:-0} errors, ${lint_parse:-0} parse errors"
elif [ "$STRICT" -eq 1 ] && [ "${lint_warnings:-0}" -gt 0 ]; then
	bad "lint — ${lint_warnings:-0} warnings (--strict)"
else
	ok "lint — 0 errors, ${lint_warnings:-0} warnings"
fi

# --- 3. typecheck ------------------------------------------------------------------
hdr "typecheck (luau-lsp)"
if "$LUAU_LSP" analyze --defs="$DEFS" --sourcemap=sourcemap.json src/ 2>&1 | tee /tmp/analyze.out; then
	ok "typecheck"
else
	bad "typecheck — $(grep -cE 'TypeError|LocalUnused|UnknownGlobal' /tmp/analyze.out || echo '?') findings"
fi

# --- 4. build ----------------------------------------------------------------------
hdr "build (rojo)"
if rojo build default.project.json -o /tmp/roblox-check-build.rbxlx >/dev/null 2>&1; then
	ok "rojo build"
	rm -f /tmp/roblox-check-build.rbxlx
else
	bad "rojo build"
fi

# --- summary -----------------------------------------------------------------------
printf '\n\033[1m== summary ==\033[0m\n'
if [ ${#FAILED[@]} -eq 0 ]; then
	printf '\033[32mAll gates passed.\033[0m\n'
	exit 0
fi
printf '\033[31m%d gate(s) failed:\033[0m\n' "${#FAILED[@]}"
for f in "${FAILED[@]}"; do printf '  - %s\n' "$f"; done
exit 1
