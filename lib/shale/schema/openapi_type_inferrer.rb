# frozen_string_literal: true

require_relative 'compiler/boolean'
require_relative 'compiler/date'
require_relative 'compiler/float'
require_relative 'compiler/integer'
require_relative 'compiler/string'
require_relative 'compiler/time'
require_relative 'compiler/value'

module Shale
  module Schema
    class OpenAPITypeInferrer
      # Infer Shale compiler type from an OpenAPI schema hash
      #
      # @param [Hash, nil] schema
      #
      # @return [Shale::Schema::Compiler::Value]
      #
      # @api private
      def self.infer(schema)
        return Compiler::Value.new unless schema.is_a?(Hash)

        type = schema['type']
        format = schema['format']

        if type.is_a?(Array)
          type -= ['null']

          if type.length > 1
            return Compiler::Value.new
          else
            type = type[0]
          end
        end

        case type
        when 'string'
          case format
          when 'date'
            Compiler::Date.new
          when 'date-time'
            Compiler::Time.new
          else
            Compiler::String.new
          end
        when 'number'
          Compiler::Float.new
        when 'integer'
          Compiler::Integer.new
        when 'boolean'
          Compiler::Boolean.new
        else
          Compiler::Value.new
        end
      end
    end
  end
end
