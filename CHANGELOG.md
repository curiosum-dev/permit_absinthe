# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-08-07

### Added

- Map GraphQL types to Permit resource modules using the `permit` macro
- Built-in `load_and_authorize/2` resolver for automatic resource loading and authorization
- `Permit.Absinthe.Middleware.LoadAndAuthorize` middleware for complex resolution scenarios
- `:load_and_authorize` directive for declarative authorization
- `Permit.Absinthe.Dataloader` for authorized dataloader integration
- Action-based authorization with default `:read` action for queries
- Custom ID parameter support via `id_param_name` and `id_struct_field_name` options
- Test helpers and reference implementation

[0.1.0]: https://github.com/permit-elixir/permit_absinthe/releases/tag/v0.1.0
