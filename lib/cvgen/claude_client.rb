require 'open3'
require 'json'
require 'tempfile'

module Cvgen
  class ClaudeClient
    class ClaudeError < StandardError; end

    attr_reader :last_cost, :last_model, :last_tokens

    def initialize(config:, runner: nil)
      @config             = config
      @use_default_runner = runner.nil?
      @runner             = runner || method(:default_run)
    end

    def call(system_prompt:, payload:)
      @last_cost   = nil
      @last_model  = nil
      @last_tokens = nil

      check_binary!

      stdout, stderr, status = @runner.call(system_prompt, payload)

      # Open3 returns ASCII-8BIT (binary) strings. Tag them as UTF-8 so that
      # downstream regex/JSON handling of non-ASCII content (e.g. "Māori",
      # macrons, em dashes) doesn't raise an encoding-incompatibility error.
      stdout = stdout.to_s.dup.force_encoding('UTF-8')
      stderr = stderr.to_s.dup.force_encoding('UTF-8')

      raise ClaudeError, "claude exited with status #{status.exitstatus}:\n#{stderr.strip}" unless status.success?

      envelope = parse_envelope!(stdout, stderr)
      @last_cost   = envelope['cost_usd'] || envelope['total_cost_usd']
      @last_model  = envelope['model']
      @last_tokens = extract_tokens(envelope)

      envelope.fetch('result') do
        raise ClaudeError, "claude response envelope missing 'result' field.\nRaw: #{stdout[0, 500]}"
      end
    end

    private

    def check_binary!
      return unless @use_default_runner

      bin = @config.claude_bin
      return if system("which #{bin} > /dev/null 2>&1")

      raise ClaudeError,
            "The '#{bin}' binary was not found on PATH. " \
            'Install Claude Code from https://claude.ai/download and ensure it is on your PATH.'
    end

    def extract_tokens(envelope)
      usage = envelope['usage']
      return nil unless usage

      input  = usage['input_tokens'].to_i
      output = usage['output_tokens'].to_i
      { input: input, output: output, total: input + output }
    end

    def parse_envelope!(stdout, stderr)
      JSON.parse(stdout)
    rescue JSON::ParserError
      raise ClaudeError,
            "claude did not return valid JSON.\nstdout: #{stdout[0, 500]}\nstderr: #{stderr[0, 500]}"
    end

    def default_run(system_prompt, payload)
      bin = @config.claude_bin

      Tempfile.create(['cvgen_payload', '.txt']) do |f|
        f.write(payload)
        f.flush

        cmd = [
          bin,
          '--print',
          '--output-format', 'json',
          '--append-system-prompt', system_prompt
        ]

        Open3.capture3(*cmd, stdin_data: payload)
      end
    end
  end
end
