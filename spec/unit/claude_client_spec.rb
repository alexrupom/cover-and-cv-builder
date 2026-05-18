require 'spec_helper'

FakeStatus = Struct.new(:exitstatus) do
  def success?
    exitstatus.zero?
  end
end

RSpec.describe Cvgen::ClaudeClient do
  let(:config) { Cvgen::Config.new('/nonexistent/.cvgen.yml') }

  def make_status(success)
    FakeStatus.new(success ? 0 : 1)
  end

  def make_client(stdout:, stderr: '', success: true)
    runner = ->(_, _) { [stdout, stderr, make_status(success)] }
    described_class.new(config: config, runner: runner)
  end

  describe '#call' do
    context 'with a successful Claude response' do
      let(:envelope) do
        {
          'type' => 'result',
          'subtype' => 'success',
          'result' => '{"cv": {}}',
          'total_cost_usd' => 0.0012,
          'model' => 'claude-sonnet-4-6'
        }.to_json
      end

      it 'returns the result string' do
        client = make_client(stdout: envelope)
        expect(client.call(system_prompt: 'sys', payload: 'payload')).to eq('{"cv": {}}')
      end

      it 'exposes last_cost from the envelope' do
        client = make_client(stdout: envelope)
        client.call(system_prompt: 'sys', payload: 'payload')
        expect(client.last_cost).to be_within(0.0001).of(0.0012)
      end

      it 'exposes last_model from the envelope' do
        client = make_client(stdout: envelope)
        client.call(system_prompt: 'sys', payload: 'payload')
        expect(client.last_model).to eq('claude-sonnet-4-6')
      end
    end

    context 'when claude exits non-zero' do
      it 'raises ClaudeError with stderr included' do
        client = make_client(stdout: '', stderr: 'rate limit exceeded', success: false)
        expect { client.call(system_prompt: 'sys', payload: 'p') }
          .to raise_error(Cvgen::ClaudeClient::ClaudeError, /rate limit/)
      end
    end

    context 'when stdout is not valid JSON' do
      it 'raises ClaudeError' do
        client = make_client(stdout: 'not json')
        expect { client.call(system_prompt: 'sys', payload: 'p') }
          .to raise_error(Cvgen::ClaudeClient::ClaudeError, /valid JSON/)
      end
    end

    context 'when envelope has no result field' do
      it 'raises ClaudeError' do
        envelope = { 'type' => 'error' }.to_json
        client   = make_client(stdout: envelope)
        expect { client.call(system_prompt: 'sys', payload: 'p') }
          .to raise_error(Cvgen::ClaudeClient::ClaudeError, /result/)
      end
    end
  end
end
