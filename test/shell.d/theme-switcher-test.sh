#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

need_bin=$(command -v need)

home="$tmp/home"
cache_home="$tmp/cache"
omarchy_root="$tmp/omarchy"
user_themes="$home/.config/omarchy/themes"
stock_themes="$omarchy_root/themes"
stub_bin="$tmp/bin"
calls="$tmp/build-calls"
mkdir -p "$user_themes/override" "$user_themes/fallback" "$stock_themes/override" \
  "$stock_themes/fallback" "$stock_themes/obsolete" "$home/.local/state/omarchy/current" \
  "$stub_bin/bin" "$tmp/linked-theme"
cp "$ROOT/needfile" "$omarchy_root/needfile"

cat >"$stub_bin/bin/omarchy-theme-preview-build" <<EOF
#!/bin/bash
printf '%s\\n' call >>"$calls"
exec "$ROOT/bin/omarchy-theme-preview-build" "\$@"
EOF
cat >"$stub_bin/omarchy-menu-images" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" >"${MENU_ARGS_FILE:?}"
EOF
chmod +x "$stub_bin/bin/omarchy-theme-preview-build" "$stub_bin/omarchy-menu-images"
ln -s "$stub_bin/bin" "$omarchy_root/bin"
ln -s "$need_bin" "$stub_bin/need"

printf 'user override\n' >"$user_themes/override/preview.png"
printf 'stock override\n' >"$stock_themes/override/preview.jpg"
printf 'fallback\n' >"$user_themes/fallback/colors.toml"
printf 'stock fallback\n' >"$stock_themes/fallback/preview.webp"
printf 'obsolete\n' >"$stock_themes/obsolete/preview.png"
printf 'linked\n' >"$tmp/linked-theme/preview.png"
ln -s "$tmp/linked-theme" "$user_themes/linked"

run_switcher() {
  HOME="$home" XDG_CACHE_HOME="$cache_home" OMARCHY_PATH="$omarchy_root" \
    MENU_ARGS_FILE="$tmp/menu-args" PATH="$stub_bin:$PATH" \
    "$ROOT/bin/omarchy-theme-switcher" --preload
}

run_switcher
preview_dir="$cache_home/omarchy/theme-selector/previews"
[[ $(readlink "$preview_dir/override.png") == "$user_themes/override/preview.png" ]] ||
  fail "user preview overrides the bundled preview"
[[ $(readlink "$preview_dir/fallback.webp") == "$stock_themes/fallback/preview.webp" ]] ||
  fail "bundled preview fills a user theme without a preview"
[[ $(readlink -f "$preview_dir/linked.png") == "$tmp/linked-theme/preview.png" ]] ||
  fail "user theme symlink produces a preview"
[[ -L $preview_dir/obsolete.png ]] || fail "first build creates a dynamic bundled preview"
grep -qx -- '--preload' "$tmp/menu-args" || fail "theme switcher preserves --preload"
selected_line=$(grep -n -Fx -- '--selected' "$tmp/menu-args" | cut -d: -f1)
[[ -z $(sed -n "$((selected_line + 1))p" "$tmp/menu-args") ]] ||
  fail "missing current theme leaves preview selection empty"
pass "theme switcher builds previews and preserves override/fallback selection"

printf 'override\n' >"$home/.local/state/omarchy/current/theme.name"
run_switcher
[[ $(wc -l <"$calls") == 1 ]] || fail "Need leaves a fresh preview build untouched"
grep -Fqx -- "$preview_dir/override.png" "$tmp/menu-args" || fail "theme switcher selects the current preview"
pass "theme switcher preview build is fresh on a second invocation"

printf 'changed\n' >>"$tmp/linked-theme/preview.png"
run_switcher
[[ $(wc -l <"$calls") == 2 ]] || fail "Need rebuilds previews after a source change"
pass "Need rebuilds previews after a source change behind a theme symlink"

rm -rf "$stock_themes/obsolete"
run_switcher
[[ ! -e $preview_dir/obsolete.png && ! -L $preview_dir/obsolete.png ]] ||
  fail "Need removes obsolete dynamic previews"
pass "theme switcher removes obsolete generated previews"
