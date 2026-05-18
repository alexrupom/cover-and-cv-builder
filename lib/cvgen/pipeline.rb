require 'fileutils'

module Cvgen
  class Pipeline
    FAILURE_FILE = 'last_failure.txt'.freeze

    def initialize(config:)
      @config = config
    end

    def tailor(data_path:, job_description_text:, company:, role:, force: false)
      data = DataLoader.load(data_path)

      tailored_schema = load_tailored_schema
      builder = PromptBuilder.new(
        data: data,
        job_description: job_description_text,
        tailored_schema: tailored_schema,
        config: @config
      )

      client = ClaudeClient.new(config: @config)

      tailored = tailor_with_retry(client, builder)

      inferred_company = company || tailored.dig('cover_letter', 'company') || File.basename(data_path, '.json')
      inferred_role    = role    || tailored.dig('cover_letter', 'role')    || 'application'

      storage = Storage.prepare(
        output_dir: @config.output_dir,
        company: inferred_company,
        role: inferred_role,
        force: force
      )

      storage.write_job_txt(job_description_text)
      storage.write_tailored(tailored)

      meta = storage.write_meta(
        data_path: data_path,
        model: client.last_model,
        cost: client.last_cost,
        ats: tailored.dig('ats', 'match_score')
      )

      { tailored: tailored, storage: storage, meta: meta, cost: client.last_cost }
    end

    def render(tailored_path:, cv_only: false, letter_only: false)
      tailored = ResponseParser.parse(File.read(tailored_path, encoding: 'UTF-8'))
      data     = DataLoader.load(find_data_json)
      dir      = File.dirname(tailored_path)

      unless letter_only
        cv_path = File.join(dir, 'cv.pdf')
        Renderers::CvPdf.new(tailored: tailored, personal: data['personal'], config: @config)
                        .render(cv_path)
      end

      unless cv_only
        letter_path = File.join(dir, 'cover_letter.pdf')
        Renderers::CoverLetterPdf.new(tailored: tailored, personal: data['personal'], config: @config)
                                 .render(letter_path)
      end

      dir
    end

    def generate(data_path:, job_description_text:, company:, role:, force: false)
      result  = tailor(data_path: data_path, job_description_text: job_description_text,
                       company: company, role: role, force: force)
      storage = result[:storage]
      render(tailored_path: storage.tailored_path)
      result
    end

    private

    def tailor_with_retry(client, builder)
      attempt = 0
      system_prompt = builder.system_prompt
      payload       = builder.user_payload
      raw           = nil

      begin
        attempt += 1
        raw = client.call(system_prompt: system_prompt, payload: payload)
        ResponseParser.parse(raw, output_dir: @config.output_dir)
      rescue ResponseParser::ParseError => e
        if attempt >= 2
          failure_path = File.join(@config.output_dir, FAILURE_FILE)
          FileUtils.mkdir_p(@config.output_dir)
          File.write(failure_path, raw.to_s)
          raise "Claude returned invalid output twice. Raw response saved to #{failure_path}.\n#{e.message}"
        end

        payload += "\n\nYour previous reply was not valid JSON against the schema. " \
                   'Reply with the corrected JSON only.'
        retry
      end
    end

    def load_tailored_schema
      schema_path = File.join(__dir__, 'schema', 'tailored.schema.json')
      JSON.parse(File.read(schema_path))
    end

    def find_data_json
      path = 'data/data.json'
      raise "data/data.json not found in current directory (#{Dir.pwd})" unless File.exist?(path)

      path
    end
  end
end
