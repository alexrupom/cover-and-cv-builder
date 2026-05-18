module Cvgen
  class JobDescription
    def self.read(file: nil, text: nil, stdin: nil)
      new(file: file, text: text, stdin: stdin).read
    end

    def initialize(file: nil, text: nil, stdin: nil)
      @file  = file
      @text  = text
      @stdin = stdin
    end

    def read
      content = if @text && !@text.strip.empty?
                  @text
                elsif @file
                  raise "Job description file not found: #{@file}" unless File.exist?(@file)

                  File.read(@file)
                elsif @stdin
                  @stdin.read
                else
                  raise 'No job description supplied. Use --job FILE, --job-text TEXT, or pipe via stdin.'
                end

      raise 'Job description is empty.' if content.strip.empty?

      content.strip
    end
  end
end
