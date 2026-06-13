require 'markdownator'

module Cvgen
  class JobDescription
    # Markdown files are already in our target format and read verbatim;
    # every other format is converted to Markdown via the markdownator gem.
    PASSTHROUGH_EXTENSIONS = ['.md'].freeze

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

                  read_file(@file)
                elsif @stdin
                  @stdin.read
                else
                  raise 'No job description supplied. Use --job FILE, --job-text TEXT, or pipe via stdin.'
                end

      raise 'Job description is empty.' if content.strip.empty?

      content.strip
    end

    private

    # Markdown files are read directly; every other format (PDF, DOCX, HTML,
    # TXT, …) is converted to Markdown via the markdownator gem.
    #
    # Markdownator returns ASCII-8BIT (binary) strings; we re-tag them as UTF-8
    # so non-ASCII content (e.g. "Māori", macrons) doesn't trigger an
    # encoding-incompatibility error when the text is built into the prompt.
    def read_file(path)
      return File.read(path) if PASSTHROUGH_EXTENSIONS.include?(File.extname(path).downcase)

      Markdownator.convert(path).markdown.dup.force_encoding('UTF-8')
    end
  end
end
