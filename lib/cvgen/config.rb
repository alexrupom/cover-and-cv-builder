require 'yaml'

module Cvgen
  class Config
    DEFAULTS = {
      'claude_bin' => 'claude',
      'page_cap' => 2,
      'bullets_per_role' => 5,
      'nz_english' => true,
      'output_dir' => 'output',
      'font' => 'helvetica'
    }.freeze

    attr_reader :settings

    def initialize(path = '.cvgen.yml')
      file_settings = File.exist?(path) ? YAML.safe_load_file(path) || {} : {}
      @settings = DEFAULTS.merge(file_settings)
    end

    def [](key)
      @settings[key.to_s]
    end

    def claude_bin
      @settings['claude_bin']
    end

    def page_cap
      @settings['page_cap'].to_i
    end

    def bullets_per_role
      @settings['bullets_per_role'].to_i
    end

    def nz_english?
      @settings['nz_english']
    end

    def output_dir
      @settings['output_dir']
    end

    def font
      @settings['font']
    end
  end
end
