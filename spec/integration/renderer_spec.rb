require 'spec_helper'
require 'pdf/reader'
require 'tmpdir'

RSpec.describe 'PDF renderers' do
  let(:tailored)  { fixture_json('tailored.json') }
  let(:data)      { fixture_json('data.json') }
  let(:personal)  { data['personal'] }
  let(:config)    { Cvgen::Config.new('/nonexistent/.cvgen.yml') }

  def extract_text(path)
    reader = PDF::Reader.new(path)
    reader.pages.map(&:text).join("\n")
  end

  describe Cvgen::Renderers::CvPdf do
    let(:renderer) { described_class.new(tailored: tailored, personal: personal, config: config) }

    around do |example|
      Dir.mktmpdir do |dir|
        @output_path = File.join(dir, 'cv.pdf')
        renderer.render(@output_path)
        example.run
      end
    end

    it 'creates a PDF file' do
      expect(File.exist?(@output_path)).to be true
      expect(File.size(@output_path)).to be > 1000
    end

    it 'contains the candidate name' do
      text = extract_text(@output_path)
      expect(text).to include(personal['full_name'])
    end

    it 'contains the email address' do
      text = extract_text(@output_path)
      expect(text).to include(personal['email'])
    end

    it 'contains the visa status' do
      text = extract_text(@output_path)
      expect(text).to include(personal['visa_status'])
    end

    it 'contains the Professional Summary section heading' do
      text = extract_text(@output_path)
      expect(text.upcase).to include('PROFESSIONAL SUMMARY')
    end

    it 'contains the Key Skills section heading' do
      text = extract_text(@output_path)
      expect(text.upcase).to include('KEY SKILLS')
    end

    it 'contains the Work Experience section heading' do
      text = extract_text(@output_path)
      expect(text.upcase).to include('WORK EXPERIENCE')
    end

    it 'contains the Education section heading' do
      text = extract_text(@output_path)
      expect(text.upcase).to include('EDUCATION')
    end

    it 'contains at least one employer name' do
      text = extract_text(@output_path)
      expect(text).to include('WellDev')
    end

    it 'contains at least one key skill' do
      text = extract_text(@output_path)
      expect(text).to include('Ruby on Rails')
    end

    it 'contains the Referees section' do
      text = extract_text(@output_path)
      expect(text.upcase).to include('REFEREES')
    end

    it 'does not contain raw JSON or schema artefacts' do
      text = extract_text(@output_path)
      expect(text).not_to include('"cv"')
      expect(text).not_to include('"bullets"')
    end
  end

  describe Cvgen::Renderers::CoverLetterPdf do
    let(:renderer) { described_class.new(tailored: tailored, personal: personal, config: config) }

    around do |example|
      Dir.mktmpdir do |dir|
        @output_path = File.join(dir, 'cover_letter.pdf')
        renderer.render(@output_path)
        example.run
      end
    end

    it 'creates a PDF file' do
      expect(File.exist?(@output_path)).to be true
      expect(File.size(@output_path)).to be > 500
    end

    it 'contains the candidate name' do
      text = extract_text(@output_path)
      expect(text).to include(personal['full_name'])
    end

    it 'contains the target company name' do
      text = extract_text(@output_path)
      expect(text).to include(tailored['cover_letter']['company'])
    end

    it 'contains the role title' do
      text = extract_text(@output_path)
      expect(text).to include(tailored['cover_letter']['role'])
    end

    it 'contains the first paragraph' do
      text = extract_text(@output_path)
      # First ~40 chars of the opening paragraph should appear
      opening = tailored['cover_letter']['paragraphs'].first[0, 40]
      expect(text).to include(opening)
    end

    it 'contains the sign-off name' do
      text = extract_text(@output_path)
      expect(text).to include(personal['full_name'])
    end
  end
end
