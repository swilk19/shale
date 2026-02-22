# frozen_string_literal: true

require 'shale/adapter/json'
require 'shale/schema/openapi_parser'

RSpec.describe Shale::Schema::OpenAPIParser do
  before(:each) do
    Shale.json_adapter = Shale::Adapter::JSON
  end

  describe '.parse' do
    context 'with OpenAPI 3.0 JSON document' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.3",
            "info": { "title": "Pet Store", "version": "1.0.0" },
            "paths": {
              "/pets": {
                "get": { "summary": "List pets" }
              }
            },
            "components": {
              "schemas": {
                "Pet": {
                  "type": "object",
                  "properties": {
                    "name": { "type": "string" },
                    "age": { "type": "integer" }
                  }
                }
              }
            }
          }
        DATA
      end

      it 'detects version 3.0' do
        result = described_class.parse(document)
        expect(result[:version]).to eq('3.0')
      end

      it 'extracts schemas from components/schemas' do
        result = described_class.parse(document)
        expect(result[:schemas].keys).to eq(['Pet'])
        expect(result[:schemas]['Pet']['type']).to eq('object')
        expect(result[:schemas]['Pet']['properties']['name']).to eq({ 'type' => 'string' })
        expect(result[:schemas]['Pet']['properties']['age']).to eq({ 'type' => 'integer' })
      end

      it 'ignores paths and other routing content' do
        result = described_class.parse(document)
        expect(result.keys).to eq(%i[version schemas])
      end
    end

    context 'with OpenAPI 3.1 YAML document' do
      let(:document) do
        <<~DATA
          openapi: "3.1.0"
          info:
            title: Pet Store
            version: "1.0.0"
          components:
            schemas:
              Pet:
                type: object
                properties:
                  name:
                    type: string
              Owner:
                type: object
                properties:
                  email:
                    type: string
        DATA
      end

      it 'detects version 3.1' do
        result = described_class.parse(document)
        expect(result[:version]).to eq('3.1')
      end

      it 'extracts all schemas' do
        result = described_class.parse(document)
        expect(result[:schemas].keys).to contain_exactly('Pet', 'Owner')
      end
    end

    context 'with Swagger 2.0 JSON document' do
      let(:document) do
        <<~DATA
          {
            "swagger": "2.0",
            "info": { "title": "Pet Store", "version": "1.0.0" },
            "paths": {},
            "definitions": {
              "Pet": {
                "type": "object",
                "properties": {
                  "name": { "type": "string" }
                }
              }
            }
          }
        DATA
      end

      it 'detects version 2.0' do
        result = described_class.parse(document)
        expect(result[:version]).to eq('2.0')
      end

      it 'extracts schemas from definitions' do
        result = described_class.parse(document)
        expect(result[:schemas].keys).to eq(['Pet'])
        expect(result[:schemas]['Pet']['type']).to eq('object')
      end
    end

    context 'with empty schemas section' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
            "info": { "title": "Empty", "version": "1.0.0" },
            "paths": {}
          }
        DATA
      end

      it 'returns empty schemas hash' do
        result = described_class.parse(document)
        expect(result[:version]).to eq('3.0')
        expect(result[:schemas]).to eq({})
      end
    end

    context 'with multiple schemas' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.2",
            "info": { "title": "Test", "version": "1.0.0" },
            "components": {
              "schemas": {
                "Address": {
                  "type": "object",
                  "properties": {
                    "street": { "type": "string" }
                  }
                },
                "Person": {
                  "type": "object",
                  "properties": {
                    "name": { "type": "string" },
                    "address": { "$ref": "#/components/schemas/Address" }
                  }
                },
                "Company": {
                  "type": "object",
                  "properties": {
                    "name": { "type": "string" }
                  }
                }
              }
            }
          }
        DATA
      end

      it 'extracts all schema definitions' do
        result = described_class.parse(document)
        expect(result[:schemas].keys).to contain_exactly('Address', 'Person', 'Company')
      end

      it 'preserves $ref references in schema bodies' do
        result = described_class.parse(document)
        expect(result[:schemas]['Person']['properties']['address']).to eq(
          { '$ref' => '#/components/schemas/Address' }
        )
      end
    end

    context 'when version is missing' do
      let(:document) do
        <<~DATA
          {
            "info": { "title": "No Version", "version": "1.0.0" }
          }
        DATA
      end

      it 'raises SchemaError' do
        expect do
          described_class.parse(document)
        end.to raise_error(Shale::SchemaError, 'unsupported or missing OpenAPI/Swagger version')
      end
    end

    context 'when version is unsupported' do
      let(:document) do
        <<~DATA
          {
            "openapi": "4.0.0",
            "info": { "title": "Future", "version": "1.0.0" }
          }
        DATA
      end

      it 'raises SchemaError' do
        expect do
          described_class.parse(document)
        end.to raise_error(Shale::SchemaError, 'unsupported or missing OpenAPI/Swagger version')
      end
    end

    context 'when document is not valid JSON or YAML' do
      let(:document) { '{{{{not valid at all' }

      it 'raises SchemaError' do
        expect do
          described_class.parse(document)
        end.to raise_error(Shale::SchemaError, 'document is not valid JSON or YAML')
      end
    end

    context 'with Swagger 2.0 and empty definitions' do
      let(:document) do
        <<~DATA
          {
            "swagger": "2.0",
            "info": { "title": "Empty", "version": "1.0.0" },
            "paths": {}
          }
        DATA
      end

      it 'returns empty schemas hash' do
        result = described_class.parse(document)
        expect(result[:version]).to eq('2.0')
        expect(result[:schemas]).to eq({})
      end
    end
  end
end
