# Pull Request

## Description

<!-- Provide a clear and concise description of what this PR does -->

## Type of change

<!-- Mark the relevant option with an "x" -->

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Code refactoring
- [ ] Test improvements
- [ ] CI/CD improvements

## Related issues

<!-- Link any related issues -->
Fixes #<!-- issue number -->
Closes #<!-- issue number -->
Related to #<!-- issue number -->

## Changes made

<!-- List the main changes made in this PR -->

-
-
-

## Testing

<!-- Describe the tests you ran to verify your changes -->

### Test environment
- [ ] Elixir version: <!-- e.g., 1.17.0 -->
- [ ] OTP version: <!-- e.g., 27 -->
- [ ] Absinthe version: <!-- e.g., 1.7.0 -->
- [ ] Permit version: <!-- e.g., 0.4.0 -->

### Test cases
- [ ] All existing tests pass
- [ ] New tests added for new functionality at appropriate levels
- [ ] Authorization behavior verified in test app

### Test commands run
```bash
# List the commands you ran to test
mix test
MIX_ENV=test mix credo
MIX_ENV=test mix dialyzer
```

## Library API changes

<!-- Describe any changes to the public API of permit_absinthe -->

- [ ] No API changes
- [ ] New macros/functions added
- [ ] Modified existing API
- [ ] New options/configuration added

### API Example
```elixir
# Example of new/changed API usage
defmodule MyAppWeb.Schema do
  use Absinthe.Schema
  use Permit.Absinthe, authorization_module: MyApp.Authorization

  object :post do
    permit schema: MyApp.Blog.Post, new_option: :value
    field :id, :id
    field :title, :string
  end
end
```

## Documentation

- [ ] Updated README.md (if applicable)
- [ ] Updated documentation comments (with integration examples for new features)
- [ ] Updated CHANGELOG.md (if applicable)
- [ ] Added usage examples for library consumers

## Code quality

- [ ] Code follows the existing style conventions
- [ ] Self-review of the code has been performed
- [ ] Code has been commented, particularly in hard-to-understand areas
- [ ] No new linting warnings introduced
- [ ] No new Dialyzer warnings introduced

## Backward compatibility

- [ ] This change is backward compatible
- [ ] This change includes breaking changes (please describe below)
- [ ] Migration guide provided for breaking changes

### Breaking Changes
<!-- If there are breaking changes, describe them here -->

## Performance Impact

- [ ] No performance impact
- [ ] Performance improvement (better authorization checks, reduced overhead, etc.)
- [ ] Potential performance regression (please describe)

### Performance Notes
<!-- Describe any performance considerations, especially regarding authorization overhead -->

## Security Considerations

- [ ] No security impact
- [ ] Security improvement (better authorization checks)
- [ ] Potential security impact (please describe)

## Additional Notes

<!-- Any additional information that reviewers should know -->

## Usage Examples

<!-- If applicable, add code examples showing how to use the new feature -->

```elixir
# Example of how consumers would use this feature
defmodule MyAppWeb.Schema do
  use Absinthe.Schema
  use Permit.Absinthe, authorization_module: MyApp.Authorization

  query do
    field :posts, list_of(:post) do
      resolve &load_and_authorize/2
    end
  end

  object :post do
    permit schema: MyApp.Blog.Post
    field :id, :id
    field :title, :string
  end
end
```

## Checklist

- [ ] I have read the [Contributing Guidelines](CONTRIBUTING.md)
- [ ] I have performed a self-review of my code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] Any dependent changes have been merged and published
- [ ] I have tested the integration with different Absinthe configurations

## Reviewer Notes

<!-- Any specific areas you'd like reviewers to focus on -->

---

<!-- Thank you for contributing to Permit.Absinthe! -->
