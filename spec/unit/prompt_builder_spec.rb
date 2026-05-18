require 'spec_helper'

RSpec.describe Cvgen::PromptBuilder do
  let(:data)            { fixture_json('data.json') }
  let(:job_description) { fixture('job.txt') }
  let(:tailored_schema) { JSON.parse(File.read(File.join(__dir__, '../../lib/cvgen/schema/tailored.schema.json'))) }
  let(:config)          { Cvgen::Config.new('/nonexistent/.cvgen.yml') }

  subject(:builder) do
    described_class.new(
      data: data,
      job_description: job_description,
      tailored_schema: tailored_schema,
      config: config
    )
  end

  describe '#system_prompt' do
    it 'contains the no-fabrication rule' do
      expect(builder.system_prompt).to include('Never invent')
    end

    it 'contains the NZ English rule' do
      expect(builder.system_prompt).to include('New Zealand English')
    end

    it 'contains the JSON-only rule' do
      expect(builder.system_prompt).to include('JSON object only')
    end

    it 'explains that context fields are instructions, not CV content' do
      expect(builder.system_prompt).to include('context fields are instructions')
    end
  end

  describe '#user_payload' do
    it 'includes the full data.json content' do
      expect(builder.user_payload).to include(data['personal']['full_name'])
    end

    it 'includes the job description' do
      expect(builder.user_payload).to include('Senior Ruby on Rails Engineer')
    end

    it 'includes the tailored schema' do
      expect(builder.user_payload).to include('cover_letter')
      expect(builder.user_payload).to include('ats')
    end

    it 'includes bullet cap from config' do
      expect(builder.user_payload).to include(config.bullets_per_role.to_s)
    end

    it 'includes page cap from config' do
      expect(builder.user_payload).to include(config.page_cap.to_s)
    end

    it 'includes the missing_keywords instruction' do
      expect(builder.user_payload).to include('missing_keywords')
    end

    it 'instructs to omit entries with include_in_cv: false' do
      expect(builder.user_payload).to include('include_in_cv: false')
    end
  end
end
