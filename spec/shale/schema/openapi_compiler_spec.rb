# frozen_string_literal: true

require 'shale/adapter/json'
require 'shale/schema/openapi_compiler'

RSpec.describe Shale::Schema::OpenAPICompiler do
  before(:each) do
    Shale.json_adapter = Shale::Adapter::JSON
  end

  describe '#as_models' do
    context 'with a single object schema' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.3",
            "info": { "title": "Test", "version": "1.0.0" },
            "components": {
              "schemas": {
                "Person": {
                  "type": "object",
                  "properties": {
                    "name": { "type": "string" },
                    "age": { "type": "integer" },
                    "active": { "type": "boolean" }
                  }
                }
              }
            }
          }
        DATA
      end

      it 'generates one model with correct properties' do
        models = described_class.new.as_models(document)

        expect(models.length).to eq(1)
        expect(models[0].id).to eq('Person')
        expect(models[0].name).to eq('Person')
        expect(models[0].properties.length).to eq(3)
        expect(models[0].properties[0].mapping_name).to eq('name')
        expect(models[0].properties[0].type).to be_a(Shale::Schema::Compiler::String)
        expect(models[0].properties[1].mapping_name).to eq('age')
        expect(models[0].properties[1].type).to be_a(Shale::Schema::Compiler::Integer)
        expect(models[0].properties[2].mapping_name).to eq('active')
        expect(models[0].properties[2].type).to be_a(Shale::Schema::Compiler::Boolean)
      end
    end

    context 'with multiple schemas and $ref' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "components": {
              "schemas": {
                "Address": {
                  "type": "object",
                  "properties": {
                    "street": { "type": "string" },
                    "city": { "type": "string" }
                  }
                },
                "Person": {
                  "type": "object",
                  "properties": {
                    "name": { "type": "string" },
                    "address": { "$ref": "#/components/schemas/Address" }
                  }
                }
              }
            }
          }
        DATA
      end

      it 'generates models with references' do
        models = described_class.new.as_models(document)

        expect(models.length).to eq(2)

        address = models.find { |m| m.id == 'Address' }
        person = models.find { |m| m.id == 'Person' }

        expect(address).not_to be_nil
        expect(address.properties.length).to eq(2)

        expect(person).not_to be_nil
        expect(person.properties.length).to eq(2)
        expect(person.properties[1].mapping_name).to eq('address')
        expect(person.properties[1].type).to be_a(Shale::Schema::Compiler::Complex)
        expect(person.properties[1].type.id).to eq('Address')
      end
    end

    context 'with array property referencing another schema' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "components": {
              "schemas": {
                "Tag": {
                  "type": "object",
                  "properties": {
                    "name": { "type": "string" }
                  }
                },
                "Pet": {
                  "type": "object",
                  "properties": {
                    "name": { "type": "string" },
                    "tags": {
                      "type": "array",
                      "items": { "$ref": "#/components/schemas/Tag" }
                    }
                  }
                }
              }
            }
          }
        DATA
      end

      it 'generates collection attribute' do
        models = described_class.new.as_models(document)

        pet = models.find { |m| m.id == 'Pet' }
        tags_prop = pet.properties.find { |p| p.mapping_name == 'tags' }

        expect(tags_prop.collection?).to eq(true)
        expect(tags_prop.type).to be_a(Shale::Schema::Compiler::Complex)
        expect(tags_prop.type.id).to eq('Tag')
      end
    end

    context 'with namespace_mapping' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
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
                }
              }
            }
          }
        DATA
      end

      let(:mapping) do
        { 'Address' => 'Models', 'Person' => 'Models' }
      end

      it 'generates models with modules' do
        models = described_class.new.as_models(document, namespace_mapping: mapping)

        expect(models.length).to eq(2)

        address = models.find { |m| m.id == 'Address' }
        person = models.find { |m| m.id == 'Person' }

        expect(address.name).to eq('Models::Address')
        expect(person.name).to eq('Models::Person')
      end
    end

    context 'with all scalar types' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "components": {
              "schemas": {
                "Record": {
                  "type": "object",
                  "properties": {
                    "name": { "type": "string" },
                    "count": { "type": "integer" },
                    "score": { "type": "number" },
                    "active": { "type": "boolean" },
                    "born": { "type": "string", "format": "date" },
                    "updated": { "type": "string", "format": "date-time" }
                  }
                }
              }
            }
          }
        DATA
      end

      it 'maps all scalar types correctly' do
        models = described_class.new.as_models(document)

        expect(models.length).to eq(1)
        props = models[0].properties

        expect(props[0].type).to be_a(Shale::Schema::Compiler::String)
        expect(props[1].type).to be_a(Shale::Schema::Compiler::Integer)
        expect(props[2].type).to be_a(Shale::Schema::Compiler::Float)
        expect(props[3].type).to be_a(Shale::Schema::Compiler::Boolean)
        expect(props[4].type).to be_a(Shale::Schema::Compiler::Date)
        expect(props[5].type).to be_a(Shale::Schema::Compiler::Time)
      end
    end

    context 'with circular self-reference' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "components": {
              "schemas": {
                "TreeNode": {
                  "type": "object",
                  "properties": {
                    "value": { "type": "string" },
                    "children": {
                      "type": "array",
                      "items": { "$ref": "#/components/schemas/TreeNode" }
                    }
                  }
                }
              }
            }
          }
        DATA
      end

      it 'handles self-referencing schemas' do
        models = described_class.new.as_models(document)

        expect(models.length).to eq(1)
        expect(models[0].id).to eq('TreeNode')

        children = models[0].properties.find { |p| p.mapping_name == 'children' }
        expect(children.collection?).to eq(true)
        expect(children.type).to eq(models[0])
      end
    end

    context 'with Swagger 2.0 document' do
      let(:document) do
        <<~DATA
          {
            "swagger": "2.0",
            "info": { "title": "Test", "version": "1.0.0" },
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

      it 'generates models from definitions' do
        models = described_class.new.as_models(document)

        expect(models.length).to eq(1)
        expect(models[0].id).to eq('Pet')
        expect(models[0].properties[0].mapping_name).to eq('name')
      end
    end

    context 'when $ref points to a non-object schema' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "components": {
              "schemas": {
                "PhoneNumber": {
                  "type": "string"
                },
                "Contact": {
                  "type": "object",
                  "properties": {
                    "phone": { "$ref": "#/components/schemas/PhoneNumber" }
                  }
                }
              }
            }
          }
        DATA
      end

      it 'resolves ref to scalar type' do
        models = described_class.new.as_models(document)

        expect(models.length).to eq(1)
        expect(models[0].id).to eq('Contact')
        expect(models[0].properties[0].type).to be_a(Shale::Schema::Compiler::String)
      end
    end

    context 'with default values' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "components": {
              "schemas": {
                "Config": {
                  "type": "object",
                  "properties": {
                    "enabled": { "type": "boolean", "default": true },
                    "name": { "type": "string", "default": "default_name" }
                  }
                }
              }
            }
          }
        DATA
      end

      it 'captures default values' do
        models = described_class.new.as_models(document)

        expect(models[0].properties[0].default).to eq(true)
        expect(models[0].properties[1].default).to eq('"default_name"')
      end
    end

    context 'with invalid document' do
      it 'raises SchemaError' do
        expect do
          described_class.new.as_models('{{{{not valid')
        end.to raise_error(Shale::SchemaError, 'document is not valid JSON or YAML')
      end
    end

    context 'with allOf merging two inline objects' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "components": {
              "schemas": {
                "Employee": {
                  "allOf": [
                    {
                      "type": "object",
                      "properties": {
                        "name": { "type": "string" }
                      }
                    },
                    {
                      "type": "object",
                      "properties": {
                        "employee_id": { "type": "integer" }
                      }
                    }
                  ]
                }
              }
            }
          }
        DATA
      end

      it 'merges properties from all members' do
        models = described_class.new.as_models(document)

        expect(models.length).to eq(1)
        expect(models[0].id).to eq('Employee')
        expect(models[0].properties.length).to eq(2)
        expect(models[0].properties[0].mapping_name).to eq('name')
        expect(models[0].properties[0].type).to be_a(Shale::Schema::Compiler::String)
        expect(models[0].properties[1].mapping_name).to eq('employee_id')
        expect(models[0].properties[1].type).to be_a(Shale::Schema::Compiler::Integer)
      end
    end

    context 'with allOf combining $ref and inline properties' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "components": {
              "schemas": {
                "Address": {
                  "type": "object",
                  "properties": {
                    "street": { "type": "string" },
                    "city": { "type": "string" }
                  }
                },
                "Office": {
                  "allOf": [
                    { "$ref": "#/components/schemas/Address" },
                    {
                      "type": "object",
                      "properties": {
                        "floor": { "type": "integer" }
                      }
                    }
                  ]
                }
              }
            }
          }
        DATA
      end

      it 'merges ref properties with inline properties' do
        models = described_class.new.as_models(document)

        expect(models.length).to eq(2)

        office = models.find { |m| m.id == 'Office' }
        expect(office.properties.length).to eq(3)
        expect(office.properties.map(&:mapping_name)).to eq(%w[street city floor])
      end
    end

    context 'with deeply nested allOf chain' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "components": {
              "schemas": {
                "Base": {
                  "type": "object",
                  "properties": {
                    "id": { "type": "integer" }
                  }
                },
                "Middle": {
                  "allOf": [
                    { "$ref": "#/components/schemas/Base" },
                    {
                      "type": "object",
                      "properties": {
                        "name": { "type": "string" }
                      }
                    }
                  ]
                },
                "Child": {
                  "allOf": [
                    { "$ref": "#/components/schemas/Middle" },
                    {
                      "type": "object",
                      "properties": {
                        "age": { "type": "integer" }
                      }
                    }
                  ]
                }
              }
            }
          }
        DATA
      end

      it 'flattens properties through the chain' do
        models = described_class.new.as_models(document)

        expect(models.length).to eq(3)

        child = models.find { |m| m.id == 'Child' }
        expect(child.properties.length).to eq(3)
        expect(child.properties.map(&:mapping_name)).to eq(%w[id name age])
      end
    end

    context 'with allOf having conflicting property names' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "components": {
              "schemas": {
                "Merged": {
                  "allOf": [
                    {
                      "type": "object",
                      "properties": {
                        "value": { "type": "string" }
                      }
                    },
                    {
                      "type": "object",
                      "properties": {
                        "value": { "type": "integer" }
                      }
                    }
                  ]
                }
              }
            }
          }
        DATA
      end

      it 'keeps the first occurrence' do
        models = described_class.new.as_models(document)

        expect(models.length).to eq(1)
        expect(models[0].properties.length).to eq(1)
        expect(models[0].properties[0].mapping_name).to eq('value')
        expect(models[0].properties[0].type).to be_a(Shale::Schema::Compiler::String)
      end
    end

    context 'with allOf in property position' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "components": {
              "schemas": {
                "Address": {
                  "type": "object",
                  "properties": {
                    "street": { "type": "string" }
                  }
                },
                "Company": {
                  "type": "object",
                  "properties": {
                    "name": { "type": "string" },
                    "headquarters": {
                      "allOf": [
                        { "$ref": "#/components/schemas/Address" },
                        {
                          "type": "object",
                          "properties": {
                            "floor": { "type": "integer" }
                          }
                        }
                      ]
                    }
                  }
                }
              }
            }
          }
        DATA
      end

      it 'compiles allOf property as a complex type' do
        models = described_class.new.as_models(document)

        company = models.find { |m| m.id == 'Company' }
        hq = company.properties.find { |p| p.mapping_name == 'headquarters' }

        expect(hq.type).to be_a(Shale::Schema::Compiler::Complex)
        expect(hq.type.properties.length).to eq(2)
        expect(hq.type.properties.map(&:mapping_name)).to eq(%w[street floor])
      end
    end

    context 'with additionalProperties-only schema as property' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "components": {
              "schemas": {
                "Pod": {
                  "type": "object",
                  "properties": {
                    "name": { "type": "string" },
                    "labels": {
                      "type": "object",
                      "additionalProperties": { "type": "string" }
                    }
                  }
                }
              }
            }
          }
        DATA
      end

      it 'maps additionalProperties to Value type' do
        models = described_class.new.as_models(document)

        expect(models.length).to eq(1)
        pod = models[0]
        labels = pod.properties.find { |p| p.mapping_name == 'labels' }

        expect(labels.type).to be_a(Shale::Schema::Compiler::Value)
      end
    end

    context 'with additionalProperties-only schema via $ref' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "components": {
              "schemas": {
                "StringMap": {
                  "type": "object",
                  "additionalProperties": { "type": "string" }
                },
                "Pod": {
                  "type": "object",
                  "properties": {
                    "name": { "type": "string" },
                    "labels": { "$ref": "#/components/schemas/StringMap" }
                  }
                }
              }
            }
          }
        DATA
      end

      it 'resolves ref to Value type and skips generating mapper for map schema' do
        models = described_class.new.as_models(document)

        expect(models.length).to eq(1)
        expect(models[0].id).to eq('Pod')

        labels = models[0].properties.find { |p| p.mapping_name == 'labels' }
        expect(labels.type).to be_a(Shale::Schema::Compiler::Value)
      end
    end

    context 'with object having both properties and additionalProperties' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "components": {
              "schemas": {
                "Config": {
                  "type": "object",
                  "properties": {
                    "name": { "type": "string" }
                  },
                  "additionalProperties": true
                }
              }
            }
          }
        DATA
      end

      it 'generates Complex type with named properties' do
        models = described_class.new.as_models(document)

        expect(models.length).to eq(1)
        expect(models[0].id).to eq('Config')
        expect(models[0].properties.length).to eq(1)
        expect(models[0].properties[0].mapping_name).to eq('name')
      end
    end

    context 'with primitive definitions referenced via $ref' do
      let(:document) do
        <<~DATA
          {
            "swagger": "2.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "paths": {},
            "definitions": {
              "Quantity": {
                "type": "string"
              },
              "Time": {
                "type": "string",
                "format": "date-time"
              },
              "IntOrString": {
                "type": "string",
                "format": "int-or-string"
              },
              "JSON": {
                "description": "Represents an unstructured JSON value"
              },
              "Resource": {
                "type": "object",
                "properties": {
                  "cpu": { "$ref": "#/definitions/Quantity" },
                  "created": { "$ref": "#/definitions/Time" },
                  "port": { "$ref": "#/definitions/IntOrString" },
                  "metadata": { "$ref": "#/definitions/JSON" }
                }
              }
            }
          }
        DATA
      end

      it 'resolves primitive definitions to scalar types without generating mapper classes' do
        models = described_class.new.as_models(document)

        expect(models.length).to eq(1)
        expect(models[0].id).to eq('Resource')

        cpu = models[0].properties.find { |p| p.mapping_name == 'cpu' }
        expect(cpu.type).to be_a(Shale::Schema::Compiler::String)

        created = models[0].properties.find { |p| p.mapping_name == 'created' }
        expect(created.type).to be_a(Shale::Schema::Compiler::Time)

        port = models[0].properties.find { |p| p.mapping_name == 'port' }
        expect(port.type).to be_a(Shale::Schema::Compiler::String)

        metadata = models[0].properties.find { |p| p.mapping_name == 'metadata' }
        expect(metadata.type).to be_a(Shale::Schema::Compiler::Value)
      end
    end

    context 'with required fields' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "components": {
              "schemas": {
                "Person": {
                  "type": "object",
                  "required": ["name"],
                  "properties": {
                    "name": { "type": "string" },
                    "age": { "type": "integer" },
                    "email": { "type": "string" }
                  }
                }
              }
            }
          }
        DATA
      end

      it 'tracks which properties are required' do
        models = described_class.new.as_models(document)

        person = models[0]
        name_prop = person.properties.find { |p| p.mapping_name == 'name' }
        age_prop = person.properties.find { |p| p.mapping_name == 'age' }
        email_prop = person.properties.find { |p| p.mapping_name == 'email' }

        expect(name_prop.required?).to eq(true)
        expect(age_prop.required?).to eq(false)
        expect(email_prop.required?).to eq(false)
      end
    end

    context 'with required fields in allOf members' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "components": {
              "schemas": {
                "Employee": {
                  "allOf": [
                    {
                      "type": "object",
                      "required": ["name"],
                      "properties": {
                        "name": { "type": "string" },
                        "age": { "type": "integer" }
                      }
                    },
                    {
                      "type": "object",
                      "required": ["employee_id"],
                      "properties": {
                        "employee_id": { "type": "integer" },
                        "department": { "type": "string" }
                      }
                    }
                  ]
                }
              }
            }
          }
        DATA
      end

      it 'tracks required from each allOf member' do
        models = described_class.new.as_models(document)

        employee = models[0]
        name_prop = employee.properties.find { |p| p.mapping_name == 'name' }
        age_prop = employee.properties.find { |p| p.mapping_name == 'age' }
        id_prop = employee.properties.find { |p| p.mapping_name == 'employee_id' }
        dept_prop = employee.properties.find { |p| p.mapping_name == 'department' }

        expect(name_prop.required?).to eq(true)
        expect(age_prop.required?).to eq(false)
        expect(id_prop.required?).to eq(true)
        expect(dept_prop.required?).to eq(false)
      end
    end

    context 'with no required array' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "components": {
              "schemas": {
                "Widget": {
                  "type": "object",
                  "properties": {
                    "color": { "type": "string" }
                  }
                }
              }
            }
          }
        DATA
      end

      it 'defaults all properties to not required' do
        models = described_class.new.as_models(document)

        color = models[0].properties[0]
        expect(color.required?).to eq(false)
      end
    end

    context 'with dotted schema names' do
      let(:document) do
        <<~DATA
          {
            "swagger": "2.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "paths": {},
            "definitions": {
              "io.k8s.api.core.v1.Container": {
                "type": "object",
                "properties": {
                  "name": { "type": "string" },
                  "image": { "type": "string" }
                }
              },
              "io.k8s.api.core.v1.Pod": {
                "type": "object",
                "properties": {
                  "metadata": { "type": "string" },
                  "container": { "$ref": "#/definitions/io.k8s.api.core.v1.Container" }
                }
              }
            }
          }
        DATA
      end

      it 'uses last dot-segment as class name' do
        models = described_class.new.as_models(document)

        expect(models.length).to eq(2)

        pod = models.find { |m| m.id == 'io.k8s.api.core.v1.Pod' }
        container = models.find { |m| m.id == 'io.k8s.api.core.v1.Container' }

        expect(pod).not_to be_nil
        expect(pod.root_name).to eq('Pod')
        expect(pod.name).to eq('Pod')

        expect(container).not_to be_nil
        expect(container.root_name).to eq('Container')
        expect(container.name).to eq('Container')
      end

      it 'uses namespace_mapping for fully qualified names' do
        mapping = {
          'io.k8s.api.core.v1.Pod' => 'K8s::Core::V1',
          'io.k8s.api.core.v1.Container' => 'K8s::Core::V1',
        }

        models = described_class.new.as_models(document, namespace_mapping: mapping)

        pod = models.find { |m| m.id == 'io.k8s.api.core.v1.Pod' }
        container = models.find { |m| m.id == 'io.k8s.api.core.v1.Container' }

        expect(pod.name).to eq('K8s::Core::V1::Pod')
        expect(container.name).to eq('K8s::Core::V1::Container')
      end
    end

    context 'with dotted schema names using allOf' do
      let(:document) do
        <<~DATA
          {
            "swagger": "2.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "paths": {},
            "definitions": {
              "io.k8s.api.core.v1.Base": {
                "type": "object",
                "properties": {
                  "kind": { "type": "string" }
                }
              },
              "io.k8s.api.core.v1.Pod": {
                "allOf": [
                  { "$ref": "#/definitions/io.k8s.api.core.v1.Base" },
                  {
                    "type": "object",
                    "properties": {
                      "spec": { "type": "string" }
                    }
                  }
                ]
              }
            }
          }
        DATA
      end

      it 'uses last dot-segment as class name for allOf schemas' do
        models = described_class.new.as_models(document)

        pod = models.find { |m| m.id == 'io.k8s.api.core.v1.Pod' }
        expect(pod).not_to be_nil
        expect(pod.root_name).to eq('Pod')
        expect(pod.properties.map(&:mapping_name)).to eq(%w[kind spec])
      end
    end

    context 'with unsupported version' do
      let(:document) do
        '{ "openapi": "4.0.0", "info": { "title": "Future", "version": "1.0.0" } }'
      end

      it 'raises SchemaError' do
        expect do
          described_class.new.as_models(document)
        end.to raise_error(Shale::SchemaError, 'unsupported or missing OpenAPI/Swagger version')
      end
    end
  end

  describe '#to_models' do
    context 'with a simple schema' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "components": {
              "schemas": {
                "Person": {
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

      let(:expected) do
        <<~DATA
          require 'shale'

          class Person < Shale::Mapper
            attribute :name, Shale::Type::String

            json do
              map 'name', to: :name
            end

            yaml do
              map 'name', to: :name
            end
          end
        DATA
      end

      it 'generates Ruby source code' do
        models = described_class.new.to_models(document)
        expect(models).to eq({ 'person' => expected })
      end
    end

    context 'with multiple schemas and references' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
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
                }
              }
            }
          }
        DATA
      end

      let(:expected_address) do
        <<~DATA
          require 'shale'

          class Address < Shale::Mapper
            attribute :street, Shale::Type::String

            json do
              map 'street', to: :street
            end

            yaml do
              map 'street', to: :street
            end
          end
        DATA
      end

      let(:expected_person) do
        <<~DATA
          require 'shale'

          require_relative 'address'

          class Person < Shale::Mapper
            attribute :name, Shale::Type::String
            attribute :address, Address

            json do
              map 'name', to: :name
              map 'address', to: :address
            end

            yaml do
              map 'name', to: :name
              map 'address', to: :address
            end
          end
        DATA
      end

      it 'generates Ruby source code for all models' do
        models = described_class.new.to_models(document)
        expect(models).to eq({
          'address' => expected_address,
          'person' => expected_person,
        })
      end
    end

    context 'with namespace_mapping' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
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
                }
              }
            }
          }
        DATA
      end

      let(:mapping) do
        { 'Address' => 'api', 'Person' => 'api' }
      end

      let(:expected_address) do
        <<~DATA
          require 'shale'

          module Api
            class Address < Shale::Mapper
              attribute :street, Shale::Type::String

              json do
                map 'street', to: :street
              end

              yaml do
                map 'street', to: :street
              end
            end
          end
        DATA
      end

      let(:expected_person) do
        <<~DATA
          require 'shale'

          require_relative 'address'

          module Api
            class Person < Shale::Mapper
              attribute :name, Shale::Type::String
              attribute :address, Api::Address

              json do
                map 'name', to: :name
                map 'address', to: :address
              end

              yaml do
                map 'name', to: :name
                map 'address', to: :address
              end
            end
          end
        DATA
      end

      it 'generates Ruby source code with modules' do
        models = described_class.new.to_models(document, namespace_mapping: mapping)
        expect(models).to eq({
          'api/address' => expected_address,
          'api/person' => expected_person,
        })
      end
    end

    context 'with allOf schema' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "components": {
              "schemas": {
                "Person": {
                  "type": "object",
                  "properties": {
                    "name": { "type": "string" }
                  }
                },
                "Employee": {
                  "allOf": [
                    { "$ref": "#/components/schemas/Person" },
                    {
                      "type": "object",
                      "properties": {
                        "employee_id": { "type": "integer" }
                      }
                    }
                  ]
                }
              }
            }
          }
        DATA
      end

      let(:expected_person) do
        <<~DATA
          require 'shale'

          class Person < Shale::Mapper
            attribute :name, Shale::Type::String

            json do
              map 'name', to: :name
            end

            yaml do
              map 'name', to: :name
            end
          end
        DATA
      end

      let(:expected_employee) do
        <<~DATA
          require 'shale'

          class Employee < Shale::Mapper
            attribute :name, Shale::Type::String
            attribute :employee_id, Shale::Type::Integer

            json do
              map 'name', to: :name
              map 'employee_id', to: :employee_id
            end

            yaml do
              map 'name', to: :name
              map 'employee_id', to: :employee_id
            end
          end
        DATA
      end

      it 'generates Ruby source code with merged properties' do
        models = described_class.new.to_models(document)
        expect(models).to eq({
          'person' => expected_person,
          'employee' => expected_employee,
        })
      end
    end

    context 'with collection and default values' do
      let(:document) do
        <<~DATA
          {
            "openapi": "3.0.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "components": {
              "schemas": {
                "Config": {
                  "type": "object",
                  "properties": {
                    "enabled": { "type": "boolean", "default": true },
                    "tags": {
                      "type": "array",
                      "items": { "type": "string" }
                    }
                  }
                }
              }
            }
          }
        DATA
      end

      let(:expected) do
        <<~DATA
          require 'shale'

          class Config < Shale::Mapper
            attribute :enabled, Shale::Type::Boolean, default: -> { true }
            attribute :tags, Shale::Type::String, collection: true

            json do
              map 'enabled', to: :enabled
              map 'tags', to: :tags
            end

            yaml do
              map 'enabled', to: :enabled
              map 'tags', to: :tags
            end
          end
        DATA
      end

      it 'generates Ruby source code with collections and defaults' do
        models = described_class.new.to_models(document)
        expect(models).to eq({ 'config' => expected })
      end
    end
  end
end
