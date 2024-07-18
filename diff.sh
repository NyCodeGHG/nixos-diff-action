#!/usr/bin/env bash

set -euo pipefail

# 24.05
NIXPKGS="https://github.com/NixOS/nixpkgs/archive/c716603a63aca44f39bef1986c13402167450e0a.tar.gz"

if [[ ! -x "$(command -v nix)" ]]; then
    echo '::error::Could not find nix. Did you install Nix?'
    exit 1
fi

function buildConfiguration() {
    local configPath="$1"
    local nixosConfig="$2"

    nix build "$configPath#nixosConfigurations.$nixosConfig.config.system.build.toplevel" --no-link --print-out-paths
}

echo "::group::Building base configuration"
base=$(buildConfiguration "$GITHUB_WORKSPACE/nix-diff-base" "$CONFIGURATION")
echo "Successfully built base configuration: $base"
echo "::endgroup::"

echo "::group::Building PR configuration"
target=$(buildConfiguration "$GITHUB_WORKSPACE/nix-diff-target" "$CONFIGURATION")
echo "Successfully built target configuration: $target"
echo "::endgroup::"

if [[ "$base" == "$target" ]]; then
    echo "Configuration has not changed. Skipping."
    exit 0
fi

echo "::group::Fetching nvd"
nvd="$(nix build -f "$NIXPKGS" --no-link --print-out-paths)/bin/nvd"
echo "nvd is $nvd"
echo "::endgroup::"

echo "::group::Running diff"
diff_file=$(mktemp)
"$nvd" diff "$base" "$target" | tee "$diff_file"
comment_file=$(mktemp)
cat <<EOF > "$comment_file"
:robot: Beep boop

Changes for $CONFIGURATION in this Pull Request:
\`\`\`
$(cat "$diff_file")
\`\`\`
<!-- nixos-diff-pr-comment-marker: $CONFIGURATION -->
EOF
echo "comment_file=$comment_file" >> "$GITHUB_OUTPUT"
echo "::endgroup::"
