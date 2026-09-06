#!/usr/bin/env bash
# setup.sh — one-time install of the toolchain scripts/check.sh needs.
# Safe to re-run; skips anything already present.

set -uo pipefail

echo "== Homebrew tools (luau, selene, stylua) =="
command -v brew >/dev/null 2>&1 || { echo "Homebrew required: https://brew.sh" >&2; exit 1; }
brew install luau selene stylua

echo
echo "== rojo =="
if command -v rojo >/dev/null 2>&1 || [ -x "$HOME/.local/bin/rojo" ]; then
	echo "rojo already installed"
else
	echo "rojo not found — install from https://rojo.space (or: cargo install rojo)" >&2
fi

echo
echo "== luau-lsp (typechecker with Roblox API definitions) =="
# Not in Homebrew core; grab the released macOS binary.
if [ -x "$HOME/.local/bin/luau-lsp" ]; then
	echo "luau-lsp already installed: $("$HOME/.local/bin/luau-lsp" --version)"
else
	tag=$(curl -sfL https://api.github.com/repos/JohnnyMorganz/luau-lsp/releases/latest \
		| grep '"tag_name"' | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
	[ -n "$tag" ] || { echo "could not resolve latest luau-lsp release" >&2; exit 1; }
	tmp=$(mktemp -d)
	curl -sfL -o "$tmp/luau-lsp.zip" \
		"https://github.com/JohnnyMorganz/luau-lsp/releases/download/$tag/luau-lsp-macos.zip" \
		|| { echo "download failed" >&2; exit 1; }
	unzip -oq "$tmp/luau-lsp.zip" -d "$tmp"
	mkdir -p "$HOME/.local/bin"
	cp "$tmp/luau-lsp" "$HOME/.local/bin/luau-lsp"
	chmod +x "$HOME/.local/bin/luau-lsp"
	xattr -d com.apple.quarantine "$HOME/.local/bin/luau-lsp" 2>/dev/null
	rm -rf "$tmp"
	echo "installed luau-lsp $tag"
fi

echo
echo "Done. Run: scripts/check.sh"
