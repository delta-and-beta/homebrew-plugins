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

    # Create wrapper script with auto-register + search routing
    node_bin = Formula["node"].opt_bin/"node"
    (bin/"braze-agency").write <<~SH
      #!/bin/bash
      PLUGIN_DIR="#{plugin_dir}"
      NODE_BIN="#{node_bin}"
      SETTINGS="$HOME/.claude/settings.json"
      export NODE_PATH="$PLUGIN_DIR/node_modules"

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
        "$NODE_BIN" -e "
          const fs = require('fs');
          fs.writeFileSync('$SETTINGS', JSON.stringify({plugins:['$PLUGIN_DIR']}, null, 2) + '\\n');
          console.error('✓ Registered braze-agency with Claude Code');
        " 2>&1
      fi

      # Route commands
      case "$1" in
        search)
          shift
          exec "$NODE_BIN" "$PLUGIN_DIR/bin/search.mjs" "$@"
          ;;
        register)
          echo "Already registered (auto-registers on every run)"
          grep -q "$PLUGIN_DIR" "$SETTINGS" 2>/dev/null && echo "✓ Plugin: $PLUGIN_DIR" || echo "✗ Not in settings"
          ;;
        status)
          echo "braze-agency status:"
          echo ""
          if grep -q "$PLUGIN_DIR" "$SETTINGS" 2>/dev/null; then
            echo "  Registered: ✓ yes"
          else
            echo "  Registered: ✗ no"
          fi
          echo "  Plugin:     $PLUGIN_DIR"
          agents=$(ls "$PLUGIN_DIR/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')
          echo "  Agents:     $agents"
          skills=$(find "$PLUGIN_DIR/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
          echo "  Skills:     $skills"
          if [ -f "$PLUGIN_DIR/memory.db" ]; then
            size=$(du -m "$PLUGIN_DIR/memory.db" | cut -f1)
            echo "  Memory:     ✓ ${size}MB"
          else
            echo "  Memory:     ✗ missing"
          fi
          ;;
        *)
          echo "braze-agency — Braze specialist agents for Claude Code"
          echo ""
          echo "Commands:"
          echo "  search \"query\"            Search skills (default)"
          echo "  search \"query\" --topic    Search topics"
          echo "  search --list-skills      List all skills"
          echo "  search --get-topic <id>   Read a topic"
          echo "  status                    Show registration status"
          echo ""
          echo "Examples:"
          echo "  braze-agency search \"email bounce\" --limit 5"
          echo "  braze-agency search \"push notifications\" --topic"
          echo "  braze-agency search --list-skills"
          echo "  braze-agency status"
          ;;
      esac
    SH
  end

  def caveats
    <<~EOS
      Braze Agency is installed. Run any command to auto-register with Claude Code:

        braze-agency search "query"    # Search knowledge base
        braze-agency status            # Check registration

      Plugin: #{share}/braze-agency
      Agents: 9 (engineer, architect, strategist, analyst, tester, ...)
      Skills: 166 with 1,304 topic references

      Restart Claude Code after first run to activate.
    EOS
  end

  test do
    assert_match "braze-agency", shell_output("#{bin}/braze-agency")
  end
end
