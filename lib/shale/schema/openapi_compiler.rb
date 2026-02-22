# frozen_string_literal: true

require 'erb'

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
require_relative 'openapi_parser'
require_relative 'openapi_ref_resolver'
require_relative 'openapi_type_inferrer'

module Shale
  module Schema
    # Class for compiling OpenAPI/Swagger schemas into Ruby data models
    #
    # @api public
    class OpenAPICompiler
      # Shale model template with both json and yaml mappings
      # @api private
      MODEL_TEMPLATE = ERB.new(<<~TEMPLATE, trim_mode: '-')
        require 'shale'
        <%- unless type.references.empty? -%>

        <%- type.references.each do |property| -%>
        require_relative '<%= type.relative_path(property.type.file_name) %>'
        <%- end -%>
        <%- end -%>

        <%- type.modules.each_with_index do |name, i| -%>
        <%= '  ' * i %>module <%= name %>
        <%- end -%>
        <%- indent = '  ' * type.modules.length -%>
        <%= indent %>class <%= type.root_name %> < Shale::Mapper
          <%- type.properties.each do |property| -%>
          <%= indent %>attribute :<%= property.attribute_name %>, <%= property.type.name -%>
          <%- if property.collection? %>, collection: true<% end -%>
          <%- unless property.default.nil? %>, default: -> { <%= property.default %> }<% end %>
          <%- end -%>

          <%= indent %>json do
            <%- type.properties.each do |property| -%>
            <%= indent %>map '<%= property.mapping_name %>', to: :<%= property.attribute_name %>
            <%- end -%>
          <%= indent %>end

          <%= indent %>yaml do
            <%- type.properties.each do |property| -%>
            <%= indent %>map '<%= property.mapping_name %>', to: :<%= property.attribute_name %>
            <%- end -%>
          <%= indent %>end
        <%= indent %>end
        <%- type.modules.length.times do |i| -%>
        <%= '  ' * (type.modules.length - i - 1) %>end
        <%- end -%>
      TEMPLATE

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

        if schema.key?('allOf')
          return compile_all_of(name, schema)
        end

        return unless schema['type'] == 'object'
        return if additional_properties_only?(schema)
        return @types[name] if @types.key?(name)

        package = @namespace_mapping[name]
        root = name.include?('.') ? name.split('.').last : name
        complex = Compiler::Complex.new(name, root, package)
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
        elsif schema.key?('allOf')
          type = compile_all_of(name, schema)
        elsif additional_properties_only?(schema)
          type = Compiler::Value.new
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
        if additional_properties_only?(schema)
          Compiler::Value.new
        elsif schema.is_a?(Hash) && schema['type'] == 'object'
          compile_schema(name, schema)
        elsif schema.is_a?(Hash) && schema.key?('allOf')
          compile_all_of(name, schema)
        else
          OpenAPITypeInferrer.infer(schema)
        end
      end

      # Compile an allOf composition schema by merging all member schemas' properties
      #
      # @param [String] name schema name
      # @param [Hash] schema schema definition containing 'allOf' key
      #
      # @return [Shale::Schema::Compiler::Complex]
      #
      # @api private
      def compile_all_of(name, schema)
        return @types[name] if @types.key?(name)

        package = @namespace_mapping[name]
        root = name.include?('.') ? name.split('.').last : name
        complex = Compiler::Complex.new(name, root, package)
        @types[name] = complex

        collect_all_of_properties(schema, complex)

        (schema['properties'] || {}).each do |prop_name, prop_schema|
          property = compile_property(prop_name, prop_schema)
          complex.add_property(property) if property
        end

        complex
      end

      # Check if schema is a pure additionalProperties map with no named properties
      #
      # @param [Hash, nil] schema
      #
      # @return [Boolean]
      #
      # @api private
      def additional_properties_only?(schema)
        schema.is_a?(Hash) &&
          schema['type'] == 'object' &&
          schema.key?('additionalProperties') &&
          (schema['properties'].nil? || schema['properties'].empty?)
      end

      # Recursively collect properties from allOf member schemas
      #
      # @param [Hash] schema schema containing 'allOf' key
      # @param [Shale::Schema::Compiler::Complex] complex target complex type
      #
      # @api private
      def collect_all_of_properties(schema, complex)
        schema['allOf'].each do |member_schema|
          next unless member_schema.is_a?(Hash)

          if member_schema.key?('$ref')
            _, member_schema = @ref_resolver.resolve(member_schema['$ref'])
          end

          if member_schema.key?('allOf')
            collect_all_of_properties(member_schema, complex)
          else
            (member_schema['properties'] || {}).each do |prop_name, prop_schema|
              property = compile_property(prop_name, prop_schema)
              complex.add_property(property) if property
            end
          end
        end
      end
    end
  end
end
