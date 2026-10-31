{ pkgs }:
let
  mkClaude = import ./module/home-manager/claude-wrapper.nix {
    inherit pkgs;
    inherit (pkgs) lib;
  };
  stub = pkgs.writeShellScriptBin "claude" ''
    printf '%s\n' "$@"
  '';
  tools = [
    pkgs.claude-config-merge
    pkgs.jq
    pkgs.diffutils
  ];
in
{
  claude-config-merge = pkgs.runCommand "claude-config-merge-check" { nativeBuildInputs = tools; } ''
    export HOME=$TMPDIR/home
    mkdir -p $HOME
    t=$TMPDIR/t
    mkdir -p $t/a/claude/{mcp.d,settings.d,plugins/p1/.claude-plugin} $t/b/claude/{mcp.d,settings.d,plugins/p1dup/.claude-plugin,plugins/p2/.claude-plugin}
    ln -s $t/a $t/a-link
    echo '{"name":"p1"}' > $t/a/claude/plugins/p1/.claude-plugin/plugin.json
    echo '{"name":"p1"}' > $t/b/claude/plugins/p1dup/.claude-plugin/plugin.json
    echo '{"name":"p2"}' > $t/b/claude/plugins/p2/.claude-plugin/plugin.json
    echo '{"mcpServers":{"one":{"command":"/x/one"}}}' > $t/a/claude/mcp.d/a.json
    echo '{"mcpServers":{"two":{"command":"/x/two"}}}' > $t/b/claude/mcp.d/b.json
    echo '{"model":"opus","permissions":{"allow":["A","B"]},"env":{"X":"1"}}' > $t/a/claude/settings.d/a.json
    echo '{"permissions":{"allow":["B","C"]},"env":{"Y":"2"},"model":null}' > $t/b/claude/settings.d/b.json
    echo '{"model":"sonnet","effort":"low","permissions":{"deny":["D"]}}' > $t/base.json
    export XDG_RUNTIME_DIR=$TMPDIR/run
    mkdir -p $XDG_RUNTIME_DIR

    # union, array dedupe, scalar override, null keeps, missing dir skipped, symlinked dup dir once, plugin deduped by name
    export CLAUDE_CONFIG_MERGE_SHARE_DIRS=$t/a:$t/a-link:$t/missing:$t/b
    claude-config-merge --base $t/base.json --out $TMPDIR/o1
    jq -e '.mcpServers == {one:{command:"/x/one"},two:{command:"/x/two"}}' $TMPDIR/o1/mcp.json
    jq -e '.permissions.allow == ["A","B","C"] and .permissions.deny == ["D"]
      and .model == "opus" and .effort == "low" and .env == {X:"1",Y:"2"}' $TMPDIR/o1/settings.json
    printf '%s\n%s\n' $(realpath $t/a/claude/plugins/p1) $(realpath $t/b/claude/plugins/p2) | diff - $TMPDIR/o1/plugin-dirs

    # duplicate server name fails and names both files
    mkdir -p $t/c/claude/mcp.d
    echo '{"mcpServers":{"one":{"command":"/y"}}}' > $t/c/claude/mcp.d/c.json
    export CLAUDE_CONFIG_MERGE_SHARE_DIRS=$t/a:$t/c
    if claude-config-merge --base $t/base.json --out $TMPDIR/o2 2> $TMPDIR/err; then echo "dup accepted"; exit 1; fi
    grep -q "a/claude/mcp.d/a.json" $TMPDIR/err
    grep -q "c/claude/mcp.d/c.json" $TMPDIR/err

    # no servers: no mcp.json
    mkdir -p $t/empty
    export CLAUDE_CONFIG_MERGE_SHARE_DIRS=$t/empty
    claude-config-merge --base $t/base.json --out $TMPDIR/o3
    test ! -e $TMPDIR/o3/mcp.json
    jq -e '. == input' $TMPDIR/o3/settings.json $t/base.json
    test ! -s $TMPDIR/o3/plugin-dirs
    touch $out
  '';

  claude-wrapper =
    pkgs.runCommand "claude-wrapper-check" { nativeBuildInputs = [ pkgs.diffutils ]; }
      ''
        t=$TMPDIR/t
        mkdir -p $t/a/claude/{mcp.d,plugins/p1/.claude-plugin} $t/empty
        echo '{"name":"p1"}' > $t/a/claude/plugins/p1/.claude-plugin/plugin.json
        echo '{"mcpServers":{"one":{"command":"/x/one"}}}' > $t/a/claude/mcp.d/a.json
        export XDG_RUNTIME_DIR=$TMPDIR/run
        mkdir -p $XDG_RUNTIME_DIR
        w=${
          mkClaude {
            settings = {
              model = "sonnet";
            };
            package = stub;
          }
        }/bin/claude

        CLAUDE_CONFIG_MERGE_SHARE_DIRS=$t/a $w --hello > $TMPDIR/out1
        printf '%s\n' --settings $XDG_RUNTIME_DIR/claude/settings.json --mcp-config $XDG_RUNTIME_DIR/claude/mcp.json \
          --plugin-dir $(realpath $t/a/claude/plugins/p1) --hello | diff - $TMPDIR/out1

        CLAUDE_CONFIG_MERGE_SHARE_DIRS=$t/empty $w --hello > $TMPDIR/out2
        printf '%s\n' --settings $XDG_RUNTIME_DIR/claude/settings.json --hello | diff - $TMPDIR/out2
        touch $out
      '';
}
