class BrazeAgency < Formula
  desc "Braze specialist agents for Claude Code — 9 agents, 166 skills, 1,304 topics"
  homepage "https://github.com/delta-and-beta/braze-agency"
  url "https://github.com/delta-and-beta/braze-agency/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "78dcfa41a44fd2925462040a44a7142af76e44f6c09a0b3c47b904a766fbee4e"
  license "MIT"

  depends_on "node"

  def install
    # Install native dependency (better-sqlite3 for FTS5 search)
    system "npm", "install", "--production", "--ignore-scripts=false"

    # Install plugin content to share/
    plugin_dir = share/"braze-agency"
    plugin_dir.install "agents", "skills", "commands", "bin",
                       "memory.db", "keywords.txt",
                       "skill_index.json", "skill_meta.json",
                       "package.json", "node_modules"

    # Create wrapper script
    (bin/"braze-agency").write <<~SH
      #!/bin/bash
      export NODE_PATH="#{plugin_dir}/node_modules"
      exec node "#{plugin_dir}/bin/cli.mjs" "$@"
    SH
  end

  def post_install
    # Register plugin with Claude Code settings.json
    settings_path = "#{Dir.home}/.claude/settings.json"
    plugin_path = "#{share}/braze-agency"

    require "json"

    settings = if File.exist?(settings_path)
      begin
        JSON.parse(File.read(settings_path))
      rescue JSON::ParserError
        {}
      end
    else
      {}
    end

    settings["plugins"] ||= []
    unless settings["plugins"].include?(plugin_path)
      settings["plugins"] << plugin_path
      FileUtils.mkdir_p(File.dirname(settings_path))
      File.write(settings_path, JSON.pretty_generate(settings) + "\n")
      ohai "Registered with Claude Code at #{settings_path}"
    end
  end

  def caveats
    <<~EOS
      Braze Agency has been registered with Claude Code.

      Plugin: #{share}/braze-agency
      Agents: 9 (engineer, architect, strategist, analyst, tester, ...)
      Skills: 166 with 1,304 topic references

      Commands:
        braze-agency status            # Check registration
        braze-agency search "query"    # Search knowledge base
        braze-agency register          # Re-register if needed

      Restart Claude Code to activate.
    EOS
  end

  test do
    assert_match "status", shell_output("#{bin}/braze-agency status")
  end
end
