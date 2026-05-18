require 'spec_helper'
require 'tempfile'

RSpec.describe Cvgen::DataLoader do
  describe '.load' do
    context 'with a valid data.json' do
      it 'returns parsed data without raising' do
        data = described_class.load(fixture_path('data.json'))
        expect(data).to be_a(Hash)
        expect(data['personal']['full_name']).to be_a(String)
      end

      it 'includes required top-level keys' do
        data = described_class.load(fixture_path('data.json'))
        %w[personal professional_summary skills experience education].each do |key|
          expect(data).to have_key(key), "expected key '#{key}' to be present"
        end
      end
    end

    context 'with a missing file' do
      it 'raises with a helpful message' do
        expect { described_class.load('/nonexistent/data.json') }
          .to raise_error(RuntimeError, /not found/)
      end
    end

    context 'with an empty file' do
      it 'raises' do
        Tempfile.create(['empty', '.json']) do |f|
          f.flush
          expect { described_class.load(f.path) }.to raise_error(RuntimeError)
        end
      end
    end

    context 'with invalid JSON' do
      it 'raises a JSON parse error' do
        Tempfile.create(['bad', '.json']) do |f|
          f.write('{ not valid json')
          f.flush
          expect { described_class.load(f.path) }.to raise_error(JSON::ParserError)
        end
      end
    end

    context 'with JSON that fails schema validation' do
      it 'raises with a message mentioning the failing field' do
        bad = { 'personal' => {}, 'professional_summary' => { 'summary' => 'x' },
                'skills' => {}, 'experience' => [], 'education' => [] }
        Tempfile.create(['invalid', '.json']) do |f|
          f.write(JSON.generate(bad))
          f.flush
          expect { described_class.load(f.path) }
            .to raise_error(RuntimeError, /schema validation/)
        end
      end
    end
  end
end
