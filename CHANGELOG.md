# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-02-16

### Added

- Extended `permit` configuration options for resolver customization (#5 - thanks @arturz):
  - `:fetch_subject`
  - `:base_query`
  - `:finalize_query`
  - `:handle_unauthorized`
  - `:handle_not_found`
  - `:unauthorized_message`
  - `:loader`
  - `:wrap_authorized`
- Support for collection results from custom `:loader` callbacks.
- Expanded test coverage for configuration options and loader edge cases.

### Changed

- Simplified dataloader integration: `authorized_dataloader/3` now self-initializes Permit dataloader sources per field (#9). This removed the need to use `Permit.Absinthe.Middleware.DataloaderSetup`.
- Updated docs and examples to reflect the new dataloader flow and onboarding guidance.
- Updated dependency and CI matrix configuration for current Elixir/OTP compatibility.

### Fixed

- Fixed metadata lookup and callback arity detection for nested Absinthe type wrappers (#7).
- Fixed dataloader source key handling in resolution context (part of #9).
- Improved dataloader source key stability by using tuple-based source keys (part of #9).

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
[0.2.0]: https://github.com/permit-elixir/permit_absinthe/releases/tag/v0.2.0
