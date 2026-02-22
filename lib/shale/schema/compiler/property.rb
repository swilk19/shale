# frozen_string_literal: true

require_relative '../../utils'

module Shale
  module Schema
    module Compiler
      # Class representing Shale's property
      #
      # @api private
      class Property
        # Return mapping's name
        #
        # @return [String]
        #
        # @api private
        attr_reader :mapping_name

        # Return attribute's name
        #
        # @return [String]
        #
        # @api private
        attr_reader :attribute_name

        # Return types's name
        #
        # @return [String]
        #
        # @api private
        attr_reader :type

        # Initialize Property object
        #
        # @param [String] name
        # @param [Shale::Schema::Compiler::Type] type
        # @param [true, false] collection
        # @param [Object] default
        # @param [true, false] required
        #
        # @api private
        def initialize(name, type, collection, default, required: false)
          @mapping_name = name
          @attribute_name = Utils.snake_case(name)
          @type = type
          @collection = collection
          @default = default
          @required = required
        end

        # Return whether property is a collection
        #
        # @return [true, false]
        #
        # @api private
        def collection?
          @collection
        end

        # Return whether property is required
        #
        # @return [true, false]
        #
        # @api private
        def required?
          @required
        end

        # Return default value
        #
        # @return [nil, Object]
        #
        # @api private
        def default
          return if collection?
          @default.is_a?(::String) ? @default.dump : @default
        end
      end
    end
  end
end
