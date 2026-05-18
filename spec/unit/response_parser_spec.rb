require 'spec_helper'

RSpec.describe Cvgen::ResponseParser do
  let(:valid_json) { fixture('tailored.json') }

  describe '.parse' do
    context 'with clean JSON' do
      it 'returns the parsed hash' do
        result = described_class.parse(valid_json)
        expect(result).to be_a(Hash)
        expect(result['cv']['headline']).to be_a(String)
        expect(result['ats']['match_score']).to be_a(Integer)
      end
    end

    context 'with JSON wrapped in markdown fences' do
      it 'strips ```json ... ``` fences' do
        fenced = "```json\n#{valid_json}\n```"
        expect { described_class.parse(fenced) }.not_to raise_error
      end

      it 'strips plain ``` fences' do
        fenced = "```\n#{valid_json}\n```"
        expect { described_class.parse(fenced) }.not_to raise_error
      end
    end

    context 'with leading/trailing whitespace' do
      it 'handles extra whitespace without raising' do
        padded = "\n  \n#{valid_json}\n  \n"
        expect { described_class.parse(padded) }.not_to raise_error
      end
    end

    context 'with invalid JSON' do
      it 'raises ParseError' do
        expect { described_class.parse('not json at all') }
          .to raise_error(Cvgen::ResponseParser::ParseError, /not valid JSON/)
      end
    end

    context 'with JSON that fails schema validation' do
      it 'raises ParseError mentioning schema validation' do
        bad = JSON.generate({ 'cv' => {}, 'cover_letter' => {}, 'ats' => {} })
        expect { described_class.parse(bad) }
          .to raise_error(Cvgen::ResponseParser::ParseError, /schema validation/)
      end
    end
  end
end
