# frozen_string_literal: true

require_relative '../error'

module Shale
  module Schema
    class OpenAPIRefResolver
      # @param schemas [Hash<String, Hash>] schema name => schema definition
      # @param version [String] "3.0", "3.1", or "2.0"
      #
      # @api public
      def initialize(schemas, version)
        @schemas = schemas
        @version = version
      end

      # Resolve a $ref string to the schema it points to
      #
      # @param ref [String] e.g. "#/components/schemas/Address"
      #
      # @raise [SchemaError] when ref can't be resolved or circular ref detected
      #
      # @return [Array(String, Hash)] [schema_name, schema_definition]
      #
      # @api public
      def resolve(ref)
        resolve_ref(ref, Set.new)
      end

      private

      # Recursively resolve a $ref, tracking visited refs to detect cycles
      #
      # @param ref [String]
      # @param seen [Set<String>]
      #
      # @return [Array(String, Hash)]
      #
      # @api private
      def resolve_ref(ref, seen)
        if seen.include?(ref)
          raise SchemaError, "circular reference detected: #{ref}"
        end

        seen.add(ref)

        name = extract_schema_name(ref)
        schema = @schemas[name]

        unless schema
          raise SchemaError, "can't resolve reference '#{ref}'"
        end

        if schema.key?('$ref')
          resolve_ref(schema['$ref'], seen)
        else
          [name, schema]
        end
      end

      # Extract the schema name from a $ref JSON pointer
      #
      # @param ref [String]
      #
      # @raise [SchemaError] when ref format is invalid
      #
      # @return [String]
      #
      # @api private
      def extract_schema_name(ref)
        _, fragment = ref.split('#', 2)

        unless fragment
          raise SchemaError, "invalid reference format: #{ref}"
        end

        segments = fragment.split('/').reject(&:empty?)

        case @version
        when '3.0', '3.1'
          unless segments.length == 3 && segments[0] == 'components' && segments[1] == 'schemas'
            raise SchemaError, "invalid reference format: #{ref}"
          end

          segments[2]
        when '2.0'
          unless segments.length == 2 && segments[0] == 'definitions'
            raise SchemaError, "invalid reference format: #{ref}"
          end

          segments[1]
        else
          raise SchemaError, "unsupported version: #{@version}"
        end
      end
    end
  end
end
