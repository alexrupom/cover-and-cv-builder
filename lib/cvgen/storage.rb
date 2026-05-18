require 'json'
require 'digest'
require 'fileutils'
require 'date'

module Cvgen
  class Storage
    INDEX_FILE = 'index.json'.freeze

    attr_reader :job_dir

    def self.prepare(output_dir:, company:, role:, date: Date.today.iso8601, force: false)
      new(output_dir: output_dir, company: company, role: role, date: date).prepare(force: force)
    end

    def initialize(output_dir:, company:, role:, date: Date.today.iso8601)
      @output_dir = output_dir
      @company    = company || 'unknown-company'
      @role       = role    || 'unknown-role'
      @date       = date
    end

    def prepare(force: false)
      FileUtils.mkdir_p(@output_dir)
      base = slug
      path = File.join(@output_dir, base)

      unless force
        counter = 2
        while File.exist?(path)
          path = File.join(@output_dir, "#{base}-#{counter}")
          counter += 1
        end
      end

      FileUtils.mkdir_p(path)
      @job_dir = path
      self
    end

    def write_job_txt(content)
      File.write(File.join(@job_dir, 'job.txt'), content)
    end

    def write_tailored(data)
      File.write(File.join(@job_dir, 'tailored.json'), JSON.pretty_generate(data))
    end

    def write_meta(data_path:, model:, cost:, ats:)
      meta = {
        company: @company,
        role: @role,
        date: @date,
        model: model,
        cost_usd: cost,
        ats_score: ats,
        data_sha256: Digest::SHA256.file(data_path).hexdigest,
        generated_at: Time.now.iso8601
      }
      File.write(File.join(@job_dir, 'meta.json'), JSON.pretty_generate(meta))
      append_index(meta)
      meta
    end

    def tailored_path
      File.join(@job_dir, 'tailored.json')
    end

    def self.list(output_dir)
      index_path = File.join(output_dir, INDEX_FILE)
      return [] unless File.exist?(index_path)

      JSON.parse(File.read(index_path))
    rescue JSON::ParserError
      []
    end

    private

    def slug
      parts = [@company, @role, @date].map { |s| slugify(s) }
      parts.join('--')
    end

    def slugify(str)
      str.to_s
         .downcase
         .gsub(/[^a-z0-9]+/, '-')
         .gsub(/^-+|-+$/, '')
    end

    def append_index(meta)
      index_path = File.join(@output_dir, INDEX_FILE)
      entries = File.exist?(index_path) ? JSON.parse(File.read(index_path)) : []
      entries << meta.merge(dir: File.basename(@job_dir))
      File.write(index_path, JSON.pretty_generate(entries))
    end
  end
end
