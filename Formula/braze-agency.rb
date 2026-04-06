class BrazeAgency < Formula
  desc "Braze specialist agents for Claude Code — 9 agents, 166 skills, 1,304 topics"
  homepage "https://github.com/delta-and-beta/braze-agency"
  url "https://github.com/delta-and-beta/braze-agency/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "78dcfa41a44fd2925462040a44a7142af76e44f6c09a0b3c47b904a766fbee4e"
  license "MIT"

  depends_on "node"

  def install
    # Ensure Homebrew's node/npm are used (not nvm/system versions)
    ENV.prepend_path "PATH", Formula["node"].opt_bin

    # Install native dependency (better-sqlite3 for FTS5 search)
    system "npm", "install", "--production", "--ignore-scripts=false"

    # Install plugin content to share/
    plugin_dir = share/"braze-agency"
    plugin_dir.install "agents", "skills", "commands", "bin",
                       "memory.db", "keywords.txt",
                       "skill_index.json", "skill_meta.json",
                       "package.json", "node_modules"

    # Create wrapper script that auto-registers on first run
    node_bin = Formula["node"].opt_bin/"node"
    (bin/"braze-agency").write <<~SH
      #!/bin/bash
      PLUGIN_DIR="#{plugin_dir}"
      NODE_BIN="#{node_bin}"
      SETTINGS="$HOME/.claude/settings.json"

      # Auto-register with Claude Code on first run
      if [ -f "$SETTINGS" ]; then
        if ! grep -q "$PLUGIN_DIR" "$SETTINGS" 2>/dev/null; then
          "$NODE_BIN" -e "
            const fs = require('fs');
            const s = JSON.parse(fs.readFileSync('$SETTINGS', 'utf-8'));
            s.plugins = s.plugins || [];
            if (!s.plugins.includes('$PLUGIN_DIR')) {
              s.plugins.push('$PLUGIN_DIR');
              fs.writeFileSync('$SETTINGS', JSON.stringify(s, null, 2) + '\\n');
              console.error('✓ Registered braze-agency with Claude Code');
            }
          " 2>&1
        fi
      else
        mkdir -p "$(dirname "$SETTINGS")"
        echo '{"plugins":["'"$PLUGIN_DIR"'"]}' | "$NODE_BIN" -e "
          const fs = require('fs');
          let d = '';
          process.stdin.on('data', c => d += c);
          process.stdin.on('end', () => {
            fs.writeFileSync('$SETTINGS', JSON.stringify(JSON.parse(d), null, 2) + '\\n');
            console.error('✓ Registered braze-agency with Claude Code');
          });
        " 2>&1
      fi

      export NODE_PATH="$PLUGIN_DIR/node_modules"
      exec "$NODE_BIN" "$PLUGIN_DIR/bin/cli.mjs" "$@"
    SH
  end

  def caveats
    <<~EOS
      Braze Agency is installed. Run any command to auto-register with Claude Code:

        braze-agency status            # Check status + auto-registers
        braze-agency search "query"    # Search knowledge base

      Plugin: #{share}/braze-agency
      Agents: 9 (engineer, architect, strategist, analyst, tester, ...)
      Skills: 166 with 1,304 topic references

      Restart Claude Code after first run to activate.
    EOS
  end

  test do
    assert_match "braze-agency", shell_output("#{bin}/braze-agency 2>&1", 0)
  end
end
