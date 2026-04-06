class BrazeAgency < Formula
  desc "Braze specialist agents for Claude Code — 9 agents, 166 skills, 1,304 topics"
  homepage "https://github.com/delta-and-beta/braze-agency"
  url "https://github.com/delta-and-beta/braze-agency/archive/refs/tags/v1.1.0.tar.gz"
  sha256 "9af4acc6d481536db4dda4c449f30c2c126078d37865b11d5b0ede605bb808cf"
  license "MIT"

  depends_on "node"

  def install
    # Ensure Homebrew's node/npm are used (not nvm/system versions)
    ENV.prepend_path "PATH", Formula["node"].opt_bin

    # Install native dependency (better-sqlite3 for FTS5 search)
    system "npm", "install", "--production", "--ignore-scripts=false"

    # Install plugin content to share/
    plugin_dir = share/"braze-agency"
    plugin_dir.install ".claude-plugin",
                       "agents", "skills", "commands", "bin",
                       "memory.db", "keywords.txt",
                       "skill_index.json", "skill_meta.json",
                       "package.json", "node_modules"

    # Create wrapper script
    node_bin = Formula["node"].opt_bin/"node"
    (bin/"braze-agency").write <<~SH
      #!/bin/bash
      PLUGIN_DIR="#{plugin_dir}"
      NODE_BIN="#{node_bin}"
      export NODE_PATH="$PLUGIN_DIR/node_modules"

      case "$1" in
        search)
          shift
          exec "$NODE_BIN" "$PLUGIN_DIR/bin/search.mjs" "$@"
          ;;
        register)
          echo "Registering braze-agency with Claude Code..."
          claude plugin marketplace add "$PLUGIN_DIR" 2>/dev/null
          claude plugin install braze@braze-agency 2>/dev/null
          echo "✓ Done. Run /reload-plugins inside Claude Code to activate."
          ;;
        status)
          echo "braze-agency status:"
          echo ""
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
          echo "  register                  Register with Claude Code"
          echo "  status                    Show plugin info"
          echo ""
          echo "Examples:"
          echo "  braze-agency search \"email bounce\" --limit 5"
          echo "  braze-agency register"
          ;;
      esac
    SH
  end

  def post_install
    # Register as Claude Code marketplace + install plugin
    # This requires 'claude' CLI to be installed (brew install claude-code)
    if which("claude")
      system "claude", "plugin", "marketplace", "add", "#{share}/braze-agency"
      system "claude", "plugin", "install", "braze@braze-agency"
    else
      opoo "Claude Code CLI not found. Run 'braze-agency register' after installing claude-code."
    end
  end

  def caveats
    <<~EOS
      Braze Agency is installed and registered with Claude Code.

      Run /reload-plugins inside Claude Code to activate, or restart Claude Code.

      Search from terminal:
        braze-agency search "query"

      If agents don't appear, run:
        braze-agency register
    EOS
  end

  test do
    assert_match "braze-agency", shell_output("#{bin}/braze-agency")
  end
end
