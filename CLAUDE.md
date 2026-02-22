# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Shale is a Ruby object mapper and serializer gem. It converts between Ruby objects and JSON, YAML, TOML, CSV, and XML formats. Users subclass `Shale::Mapper` to define attributes and format-specific mappings.

## Common Commands

- **Install dependencies**: `bundle install`
- **Run all tests**: `bundle exec rspec`
- **Run a single test file**: `bundle exec rspec spec/shale/type/complex_spec/with_custom_mapping_spec.rb`
- **Run a single test by line**: `bundle exec rspec spec/shale/mapper_spec.rb:42`
- **Lint**: `bundle exec rubocop lib spec`
- **Default rake task** (runs tests): `bundle exec rake`

## Code Style

- All files use `# frozen_string_literal: true`
- All Metrics cops are disabled (method length, class length, ABC size, etc.)
- `Style/Documentation` is disabled — no YARD doc comments required
- Trailing commas are required in multiline arrays and hashes
- `Layout/ArgumentAlignment` uses `with_fixed_indentation`
- RuboCop targets Ruby 3.0; `NewCops: enable`

## Architecture

### Type System

`Shale::Type::Value` is the base type. Scalar types (`Boolean`, `Date`, `Decimal`, `Float`, `Integer`, `String`, `Time`) inherit from it and implement `cast`. `Shale::Type::Complex` handles full object mapping and uses `class_eval` to generate `of_<format>`/`as_<format>` methods for each supported format. `Shale::Mapper` inherits from `Complex` and is the public API users subclass.

### Adapter Pattern

All format parsers are swappable via `Shale.json_adapter`, `.yaml_adapter`, `.toml_adapter`, `.csv_adapter`, `.xml_adapter`. Adapters live in `lib/shale/adapter/` and must implement `.load`/`.dump` (dict formats) or conform to the XML adapter interface (document/node classes for Nokogiri, Ox, REXML).

### Mapping DSL

Mapper subclasses use block-based DSL methods (`json { }`, `yaml { }`, `xml { }`, `toml { }`, `hsh { }`, `csv { }`) to define format-specific mappings. Mappings support `using:` for custom serialization methods, `group` blocks for delegation, and `only:`/`except:` for partial rendering.

### Inheritance

`Mapper.inherited` copies all mapping and attribute state to subclasses via `dup`. Mappings are finalized when a format block is declared.

### Schema Module

`Shale::Schema` provides JSON Schema and XML Schema generation (`to_json`/`to_xml`) and compilation (`from_json`/`from_xml`). The `shaleb` CLI (`exe/shaleb`) exposes this functionality.

### Test Structure

Specs mirror the `lib/` directory structure. Complex type specs are split into scenario-based files under `spec/shale/type/complex_spec/` (e.g., `with_custom_mapping_spec.rb`, `with_xml_namespaces_spec.rb`).
