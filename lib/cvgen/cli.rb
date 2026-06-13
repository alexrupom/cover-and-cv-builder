require 'thor'
require 'json'

module Cvgen
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    # ── init ──────────────────────────────────────────────────────────────────

    desc 'init', 'Scaffold data.json from template and write a starter .cvgen.yml'
    def init
      FileUtils.mkdir_p('data')
      copy_template(
        File.join(__dir__, '..', '..', 'templates', 'data.template.json'),
        'data/data.json'
      )
      copy_template(
        File.join(__dir__, '..', '..', '.cvgen.yml.example'),
        '.cvgen.yml'
      )
      say '✓ data/data.json and .cvgen.yml created. Edit data/data.json with your career history.', :green
    end

    # ── validate ──────────────────────────────────────────────────────────────

    desc 'validate', 'Validate data.json against its JSON Schema'
    option :data, default: 'data/data.json', desc: 'Path to data.json'
    def validate
      DataLoader.load(options[:data])
      say "✓ #{options[:data]} is valid.", :green
    rescue StandardError => e
      say e.message, :red
      exit 1
    end

    # ── tailor ────────────────────────────────────────────────────────────────

    desc 'tailor', 'Call Claude to produce a tailored.json for a job'
    option :data,     default: 'data/data.json', desc: 'Path to data.json'
    option :job,      desc: 'Path to job description file'
    option :job_text, desc: 'Job description as a string'
    option :company,  desc: 'Company name (used for folder slug)'
    option :role,     desc: 'Role title (used for folder slug)'
    option :out,      desc: 'Override output directory'
    option :force,    type: :boolean, default: false, desc: 'Overwrite existing job folder'
    def tailor
      config = load_config(options[:out])
      jd     = read_job(options)

      say 'Calling Claude… (this may take 30–60 seconds)', :yellow
      result = pipeline(config).tailor(
        data_path: options[:data],
        job_description_text: jd,
        company: options[:company],
        role: options[:role],
        force: options[:force]
      )

      print_tailor_result(result)
    rescue StandardError => e
      say e.message, :red
      exit 1
    end

    # ── render ────────────────────────────────────────────────────────────────

    desc 'render', 'Render PDFs from a tailored.json (no AI, no network)'
    option :from,        required: true, desc: 'Path to tailored.json or a job folder'
    option :cv_only,     type: :boolean, default: false
    option :letter_only, type: :boolean, default: false
    option :out,         desc: 'Override output directory'
    def render
      config = load_config(options[:out])
      tailored_path = resolve_tailored_path(options[:from])

      dir = pipeline(config).render(
        tailored_path: tailored_path,
        cv_only: options[:cv_only],
        letter_only: options[:letter_only]
      )

      say "✓ PDFs written to #{dir}", :green
    rescue StandardError => e
      say e.message, :red
      exit 1
    end

    # ── generate ──────────────────────────────────────────────────────────────

    desc 'generate', 'Tailor then render in one step (everyday command)'
    option :data,     default: 'data/data.json', desc: 'Path to data.json'
    option :job,      desc: 'Path to job description file'
    option :job_text, desc: 'Job description as a string'
    option :company,     desc: 'Company name'
    option :role,        desc: 'Role title'
    option :out,         desc: 'Override output directory'
    option :force,       type: :boolean, default: false, desc: 'Overwrite existing job folder'
    option :cv_only,     type: :boolean, default: false, desc: 'Render only the CV'
    option :letter_only, type: :boolean, default: false, desc: 'Render only the cover letter'
    def generate
      config = load_config(options[:out])
      jd     = read_job(options)

      say 'Calling Claude… (this may take 30–60 seconds)', :yellow
      result = pipeline(config).generate(
        data_path: options[:data],
        job_description_text: jd,
        company: options[:company],
        role: options[:role],
        force: options[:force],
        cv_only: options[:cv_only],
        letter_only: options[:letter_only]
      )

      print_tailor_result(result)
      say "✓ PDFs written to #{result[:storage].job_dir}", :green
    rescue StandardError => e
      say e.message, :red
      exit 1
    end

    # ── list ──────────────────────────────────────────────────────────────────

    desc 'list', 'List stored job applications'
    option :out, desc: 'Override output directory'
    def list
      config  = load_config(options[:out])
      entries = Storage.list(config.output_dir)

      if entries.empty?
        say "No applications found in #{config.output_dir}/", :yellow
        return
      end

      say 'FOLDER                                   ROLE                      ATS    DATE', :bold
      say '-' * 80
      entries.each do |e|
        role   = "#{e['company']} / #{e['role']}"[0, 24]
        score  = e['ats_score'] ? "#{e['ats_score']}%" : 'n/a'
        say format('%-40s %-25s %-6s %s', e['dir'].to_s[0, 39], role, score, e['date'].to_s)
      end
    rescue StandardError => e
      say e.message, :red
      exit 1
    end

    private

    def load_config(out_override = nil)
      cfg = Config.new
      cfg.settings['output_dir'] = out_override if out_override
      cfg
    end

    def pipeline(config)
      Pipeline.new(config: config)
    end

    def read_job(opts)
      JobDescription.read(
        file: opts[:job],
        text: opts[:job_text],
        stdin: $stdin.isatty ? nil : $stdin
      )
    end

    def resolve_tailored_path(from)
      if File.directory?(from)
        candidate = File.join(from, 'tailored.json')
        raise "No tailored.json found in #{from}" unless File.exist?(candidate)

        candidate
      elsif File.exist?(from)
        from
      else
        raise "Path not found: #{from}"
      end
    end

    def copy_template(src, dest)
      src = File.expand_path(src)
      if File.exist?(dest)
        say "  #{dest} already exists — skipping.", :yellow
      else
        require 'fileutils'
        FileUtils.cp(src, dest)
        say "  Created #{dest}", :green
      end
    end

    def print_tailor_result(result)
      tailored = result[:tailored]
      meta     = result[:meta]
      ats      = tailored['ats'] || {}

      say "\n── ATS Report ───────────────────────────────"
      say "  Score:    #{ats['match_score']}%"
      say "  Matched:  #{Array(ats['matched_keywords']).join(', ')}"

      say "  Missing:  #{Array(ats['missing_keywords']).join(', ')}", :yellow if Array(ats['missing_keywords']).any?

      tokens = result[:tokens]
      say "  Tokens:   #{tokens[:input]} in / #{tokens[:output]} out (#{tokens[:total]} total)" if tokens
      say "  Folder:   #{result[:storage].job_dir}"
      say '─────────────────────────────────────────────'
    end
  end
end
