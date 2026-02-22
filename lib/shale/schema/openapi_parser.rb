# frozen_string_literal: true

require_relative '../../shale'

module Shale
  module Schema
    class OpenAPIParser
      # Parse an OpenAPI/Swagger document string and extract schema definitions
      #
      # @param [String] document raw JSON or YAML string
      #
      # @raise [SchemaError] when document is unparseable or version is unsupported
      #
      # @return [Hash] with keys:
      #   :version  - String ("3.0", "3.1", or "2.0")
      #   :schemas  - Hash<String, Hash> (schema name => schema definition)
      #
      # @api public
      def self.parse(document)
        doc = load_document(document)
        version = detect_version(doc)
        schemas = extract_schemas(doc, version)

        { version: version, schemas: schemas }
      end

      # Load document string as a Hash, trying JSON first then YAML
      #
      # @param [String] document
      #
      # @raise [SchemaError] when document cannot be parsed
      #
      # @return [Hash]
      #
      # @api private
      def self.load_document(document)
        Shale.json_adapter.load(document)
      rescue StandardError
        begin
          Shale.yaml_adapter.safe_load(document, permitted_classes: [Date, Time])
        rescue StandardError
          raise SchemaError, 'document is not valid JSON or YAML'
        end
      end
      private_class_method :load_document

      # Detect OpenAPI/Swagger version from parsed document
      #
      # @param [Hash] doc
      #
      # @raise [SchemaError] when version is missing or unsupported
      #
      # @return [String] "3.0", "3.1", or "2.0"
      #
      # @api private
      def self.detect_version(doc)
        openapi = doc['openapi']
        swagger = doc['swagger']

        if openapi.is_a?(::String)
          return '3.1' if openapi.start_with?('3.1')
          return '3.0' if openapi.start_with?('3.0')
        end

        return '2.0' if swagger.is_a?(::String) && swagger.start_with?('2.0')

        raise SchemaError, 'unsupported or missing OpenAPI/Swagger version'
      end
      private_class_method :detect_version

      # Extract schema definitions based on version
      #
      # @param [Hash] doc
      # @param [String] version
      #
      # @return [Hash<String, Hash>]
      #
      # @api private
      def self.extract_schemas(doc, version)
        case version
        when '3.0', '3.1'
          doc.dig('components', 'schemas') || {}
        when '2.0'
          doc['definitions'] || {}
        else
          {}
        end
      end
      private_class_method :extract_schemas
    end
  end
end
