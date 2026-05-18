require 'json'
require 'json_schemer'

module Cvgen
  class DataLoader
    SCHEMA_PATH = File.join(__dir__, 'schema', 'data.schema.json')

    def self.load(path)
      new(path).load
    end

    def initialize(path)
      @path = path
    end

    def load
      raise "data.json not found at #{@path}" unless File.exist?(@path)

      raw = File.read(@path, encoding: 'UTF-8')
      raise 'data.json is empty' if raw.strip.empty?

      data = JSON.parse(raw)
      validate!(data)
      data
    end

    private

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
      raise "data.json failed schema validation:\n#{messages.join("\n")}"
    end
  end
end
