# frozen_string_literal: true

require 'shale/schema/openapi_type_inferrer'

RSpec.describe Shale::Schema::OpenAPITypeInferrer do
  describe '.infer' do
    context 'with scalar types' do
      it 'infers String from string type' do
        result = described_class.infer({ 'type' => 'string' })
        expect(result).to be_a(Shale::Schema::Compiler::String)
      end

      it 'infers Integer from integer type' do
        result = described_class.infer({ 'type' => 'integer' })
        expect(result).to be_a(Shale::Schema::Compiler::Integer)
      end

      it 'infers Float from number type' do
        result = described_class.infer({ 'type' => 'number' })
        expect(result).to be_a(Shale::Schema::Compiler::Float)
      end

      it 'infers Boolean from boolean type' do
        result = described_class.infer({ 'type' => 'boolean' })
        expect(result).to be_a(Shale::Schema::Compiler::Boolean)
      end
    end

    context 'with format-based inference' do
      it 'infers Date from string with date format' do
        result = described_class.infer({ 'type' => 'string', 'format' => 'date' })
        expect(result).to be_a(Shale::Schema::Compiler::Date)
      end

      it 'infers Time from string with date-time format' do
        result = described_class.infer({ 'type' => 'string', 'format' => 'date-time' })
        expect(result).to be_a(Shale::Schema::Compiler::Time)
      end

      it 'infers String from string with unknown format' do
        result = described_class.infer({ 'type' => 'string', 'format' => 'email' })
        expect(result).to be_a(Shale::Schema::Compiler::String)
      end
    end

    context 'with unknown or missing types' do
      it 'returns Value for unknown type' do
        result = described_class.infer({ 'type' => 'unknown' })
        expect(result).to be_a(Shale::Schema::Compiler::Value)
      end

      it 'returns Value for nil schema' do
        result = described_class.infer(nil)
        expect(result).to be_a(Shale::Schema::Compiler::Value)
      end

      it 'returns Value for empty hash' do
        result = described_class.infer({})
        expect(result).to be_a(Shale::Schema::Compiler::Value)
      end
    end

    context 'with object and array types' do
      it 'returns Value for object type' do
        result = described_class.infer({ 'type' => 'object' })
        expect(result).to be_a(Shale::Schema::Compiler::Value)
      end

      it 'returns Value for array type' do
        result = described_class.infer({ 'type' => 'array' })
        expect(result).to be_a(Shale::Schema::Compiler::Value)
      end
    end

    context 'with OAS 3.0 nullable' do
      it 'strips nullable and infers from type' do
        result = described_class.infer({ 'type' => 'string', 'nullable' => true })
        expect(result).to be_a(Shale::Schema::Compiler::String)
      end

      it 'strips nullable and infers from type and format' do
        result = described_class.infer({
          'type' => 'string',
          'format' => 'date-time',
          'nullable' => true,
        })
        expect(result).to be_a(Shale::Schema::Compiler::Time)
      end
    end

    context 'with OAS 3.1 type arrays' do
      it 'removes null and infers remaining type' do
        result = described_class.infer({ 'type' => %w[string null] })
        expect(result).to be_a(Shale::Schema::Compiler::String)
      end

      it 'removes null and infers remaining type with format' do
        result = described_class.infer({
          'type' => %w[string null],
          'format' => 'date',
        })
        expect(result).to be_a(Shale::Schema::Compiler::Date)
      end

      it 'returns Value for multiple non-null types' do
        result = described_class.infer({ 'type' => %w[string integer] })
        expect(result).to be_a(Shale::Schema::Compiler::Value)
      end
    end
  end
end
