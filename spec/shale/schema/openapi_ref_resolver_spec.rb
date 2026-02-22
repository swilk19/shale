# frozen_string_literal: true

require 'shale/schema/openapi_ref_resolver'

RSpec.describe Shale::Schema::OpenAPIRefResolver do
  describe '#resolve' do
    context 'with OpenAPI 3.x' do
      let(:version) { '3.0' }

      it 'resolves a simple $ref to the target schema' do
        schemas = {
          'Address' => {
            'type' => 'object',
            'properties' => { 'street' => { 'type' => 'string' } },
          },
        }

        resolver = described_class.new(schemas, version)
        name, schema = resolver.resolve('#/components/schemas/Address')

        expect(name).to eq('Address')
        expect(schema).to eq(schemas['Address'])
      end

      it 'resolves nested refs through a chain' do
        schemas = {
          'Alias' => { '$ref' => '#/components/schemas/Intermediate' },
          'Intermediate' => { '$ref' => '#/components/schemas/Real' },
          'Real' => { 'type' => 'object', 'properties' => {} },
        }

        resolver = described_class.new(schemas, version)
        name, schema = resolver.resolve('#/components/schemas/Alias')

        expect(name).to eq('Real')
        expect(schema).to eq(schemas['Real'])
      end

      it 'raises SchemaError for circular refs' do
        schemas = {
          'A' => { '$ref' => '#/components/schemas/B' },
          'B' => { '$ref' => '#/components/schemas/A' },
        }

        resolver = described_class.new(schemas, version)

        expect do
          resolver.resolve('#/components/schemas/A')
        end.to raise_error(Shale::SchemaError, /circular reference detected/)
      end

      it 'raises SchemaError for self-referencing refs' do
        schemas = {
          'Self' => { '$ref' => '#/components/schemas/Self' },
        }

        resolver = described_class.new(schemas, version)

        expect do
          resolver.resolve('#/components/schemas/Self')
        end.to raise_error(Shale::SchemaError, /circular reference detected/)
      end

      it 'raises SchemaError when ref target is not found' do
        schemas = {}

        resolver = described_class.new(schemas, version)

        expect do
          resolver.resolve('#/components/schemas/Missing')
        end.to raise_error(Shale::SchemaError, "can't resolve reference '#/components/schemas/Missing'")
      end

      it 'raises SchemaError for invalid ref format' do
        schemas = { 'Foo' => { 'type' => 'object' } }

        resolver = described_class.new(schemas, version)

        expect do
          resolver.resolve('#/definitions/Foo')
        end.to raise_error(Shale::SchemaError, /invalid reference format/)
      end

      it 'works with version 3.1' do
        schemas = {
          'Pet' => { 'type' => 'object', 'properties' => {} },
        }

        resolver = described_class.new(schemas, '3.1')
        name, schema = resolver.resolve('#/components/schemas/Pet')

        expect(name).to eq('Pet')
        expect(schema).to eq(schemas['Pet'])
      end
    end

    context 'with Swagger 2.0' do
      let(:version) { '2.0' }

      it 'resolves a simple $ref to the target schema' do
        schemas = {
          'Address' => {
            'type' => 'object',
            'properties' => { 'street' => { 'type' => 'string' } },
          },
        }

        resolver = described_class.new(schemas, version)
        name, schema = resolver.resolve('#/definitions/Address')

        expect(name).to eq('Address')
        expect(schema).to eq(schemas['Address'])
      end

      it 'resolves nested refs through a chain' do
        schemas = {
          'Alias' => { '$ref' => '#/definitions/Real' },
          'Real' => { 'type' => 'object', 'properties' => {} },
        }

        resolver = described_class.new(schemas, version)
        name, schema = resolver.resolve('#/definitions/Alias')

        expect(name).to eq('Real')
        expect(schema).to eq(schemas['Real'])
      end

      it 'raises SchemaError for circular refs' do
        schemas = {
          'A' => { '$ref' => '#/definitions/B' },
          'B' => { '$ref' => '#/definitions/A' },
        }

        resolver = described_class.new(schemas, version)

        expect do
          resolver.resolve('#/definitions/A')
        end.to raise_error(Shale::SchemaError, /circular reference detected/)
      end

      it 'raises SchemaError for invalid ref format' do
        schemas = { 'Foo' => { 'type' => 'object' } }

        resolver = described_class.new(schemas, version)

        expect do
          resolver.resolve('#/components/schemas/Foo')
        end.to raise_error(Shale::SchemaError, /invalid reference format/)
      end
    end
  end
end
