# frozen_string_literal: true

require_relative '../../shale'
require_relative '../utils'
require_relative 'compiler/boolean'
require_relative 'compiler/complex'
require_relative 'compiler/date'
require_relative 'compiler/float'
require_relative 'compiler/integer'
require_relative 'compiler/property'
require_relative 'compiler/string'
require_relative 'compiler/time'
require_relative 'compiler/value'
require_relative 'json_compiler'
require_relative 'openapi_parser'
require_relative 'openapi_ref_resolver'
require_relative 'openapi_type_inferrer'

module Shale
  module Schema
    # Class for compiling OpenAPI/Swagger schemas into Ruby data models
    #
    # @api public
    class OpenAPICompiler
      # Reuse the Shale model template from JSONCompiler
      # @api private
      MODEL_TEMPLATE = JSONCompiler::MODEL_TEMPLATE

      # Generate Shale models from OpenAPI document and return as Complex objects
      #
      # @param [String] document raw JSON or YAML OpenAPI/Swagger document
      # @param [Hash<String, String>, nil] namespace_mapping
      #
      # @raise [SchemaError] when document has errors
      #
      # @return [Array<Shale::Schema::Compiler::Complex>]
      #
      # @api public
      def as_models(document, namespace_mapping: nil)
        @namespace_mapping = namespace_mapping || {}
        @types = {}

        parsed = OpenAPIParser.parse(document)
        @ref_resolver = OpenAPIRefResolver.new(parsed[:schemas], parsed[:version])
        @schemas = parsed[:schemas]

        @schemas.each do |name, schema|
          compile_schema(name, schema)
        end

        total_duplicates = Hash.new(0)
        duplicates = Hash.new(0)

        types = @types.values

        types.each { |type| total_duplicates[type.name] += 1 }

        types.each do |type|
          duplicates[type.name] += 1

          if total_duplicates[type.name] > 1
            type.root_name = format("#{type.root_name}%d", duplicates[type.name])
          end
        end

        types
      end

      # Generate Shale models from OpenAPI document
      #
      # @param [String] document raw JSON or YAML OpenAPI/Swagger document
      # @param [Hash<String, String>, nil] namespace_mapping
      #
      # @raise [SchemaError] when document has errors
      #
      # @return [Hash<String, String>]
      #
      # @api public
      def to_models(document, namespace_mapping: nil)
        types = as_models(document, namespace_mapping: namespace_mapping)

        types.to_h do |type|
          [type.file_name, MODEL_TEMPLATE.result(binding)]
        end
      end

      private

      # Compile a named schema into a Compiler::Complex
      #
      # @param [String] name schema name
      # @param [Hash] schema schema definition
      #
      # @return [Shale::Schema::Compiler::Complex, nil]
      #
      # @api private
      def compile_schema(name, schema)
        return unless schema.is_a?(Hash)

        if schema.key?('$ref')
          target_name, target_schema = @ref_resolver.resolve(schema['$ref'])
          return compile_schema(target_name, target_schema)
        end

        return unless schema['type'] == 'object'
        return @types[name] if @types.key?(name)

        package = @namespace_mapping[name]
        complex = Compiler::Complex.new(name, name, package)
        @types[name] = complex

        (schema['properties'] || {}).each do |prop_name, prop_schema|
          property = compile_property(prop_name, prop_schema)
          complex.add_property(property) if property
        end

        complex
      end

      # Compile a property schema into a Compiler::Property
      #
      # @param [String] name property name
      # @param [Hash] schema property schema definition
      #
      # @return [Shale::Schema::Compiler::Property, nil]
      #
      # @api private
      def compile_property(name, schema)
        return unless schema.is_a?(Hash)

        collection = false
        default = nil

        if schema['type'] == 'array'
          collection = true
          schema = schema['items'] || {}
        end

        if schema.key?('$ref')
          target_name, target_schema = @ref_resolver.resolve(schema['$ref'])
          type = find_or_compile_ref_target(target_name, target_schema)
        elsif schema['type'] == 'object'
          type = compile_schema(name, schema)
        else
          type = OpenAPITypeInferrer.infer(schema)
        end

        if schema.is_a?(Hash) && schema.key?('default')
          default = schema['default']
        end

        Compiler::Property.new(name, type, collection, default) if type
      end

      # Find or compile a ref target
      #
      # @param [String] name
      # @param [Hash] schema
      #
      # @return [Shale::Schema::Compiler::Complex, Shale::Schema::Compiler::Value]
      #
      # @api private
      def find_or_compile_ref_target(name, schema)
        if schema.is_a?(Hash) && schema['type'] == 'object'
          compile_schema(name, schema)
        else
          OpenAPITypeInferrer.infer(schema)
        end
      end
    end
  end
end
