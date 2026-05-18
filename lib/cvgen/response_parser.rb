require 'json'
require 'json_schemer'

module Cvgen
  class ResponseParser
    SCHEMA_PATH = File.join(__dir__, 'schema', 'tailored.schema.json')

    class ParseError < StandardError; end

    def self.parse(raw_result, output_dir: 'output')
      new(raw_result, output_dir: output_dir).parse
    end

    def initialize(raw_result, output_dir: 'output')
      @raw        = raw_result
      @output_dir = output_dir
    end

    def parse
      json_str = strip_fences(@raw)
      data     = parse_json!(json_str)
      validate!(data)
      data
    end

    private

    def strip_fences(str)
      str.strip
         .gsub(/\A```(?:json)?\s*/i, '')
         .gsub(/\s*```\z/, '')
         .strip
    end

    def parse_json!(str)
      JSON.parse(str)
    rescue JSON::ParserError => e
      raise ParseError, "Response is not valid JSON: #{e.message}"
    end

    def validate!(data)
      schema_raw = File.read(SCHEMA_PATH, encoding: 'UTF-8')
      schema     = JSON.parse(schema_raw)
      schemer    = JSONSchemer.schema(schema)
      errors     = schemer.validate(data).to_a

      return if errors.empty?

      messages = errors.map do |e|
        ptr = e['data_pointer']
        loc = ptr && !ptr.empty? ? ptr : '(root)'
        "  #{loc}: #{e['error']}"
      end
      raise ParseError, "tailored.json failed schema validation:\n#{messages.join("\n")}"
    end
  end
end
