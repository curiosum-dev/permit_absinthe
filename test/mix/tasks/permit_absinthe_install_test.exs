if Code.ensure_loaded?(Igniter.Test) do
  defmodule Mix.Tasks.PermitAbsinthe.InstallTest do
    use ExUnit.Case

    import Igniter.Test

    defp project_with_schema(schema_code \\ nil) do
      code =
        schema_code ||
          """
          defmodule TestWeb.Schema do
            use Absinthe.Schema
          end
          """

      test_project(files: %{
        "lib/test_web/schema.ex" => code
      })
    end

    describe "permit_absinthe.install" do
      test "patches schema module to add use Permit.Absinthe" do
        igniter =
          project_with_schema()
          |> Igniter.compose_task("permit_absinthe.install", [])
          |> apply_igniter!()

        source = Rewrite.source!(igniter.rewrite, "lib/test_web/schema.ex")
        content = Rewrite.Source.get(source, :content)

        assert content =~
                 "use Permit.Absinthe, authorization_module: Test.Authorization"
      end

      test "uses custom authorization module" do
        igniter =
          project_with_schema()
          |> Igniter.compose_task("permit_absinthe.install", [
            "--authorization-module",
            "Test.Auth"
          ])
          |> apply_igniter!()

        source = Rewrite.source!(igniter.rewrite, "lib/test_web/schema.ex")
        content = Rewrite.Source.get(source, :content)

        assert content =~ "authorization_module: Test.Auth"
      end

      test "uses custom schema module" do
        project =
          test_project(files: %{
            "lib/test_web/graphql_schema.ex" => """
            defmodule TestWeb.GraphqlSchema do
              use Absinthe.Schema
            end
            """
          })

        igniter =
          project
          |> Igniter.compose_task("permit_absinthe.install", [
            "--schema-module",
            "TestWeb.GraphqlSchema"
          ])
          |> apply_igniter!()

        source = Rewrite.source!(igniter.rewrite, "lib/test_web/graphql_schema.ex")
        content = Rewrite.Source.get(source, :content)

        assert content =~ "use Permit.Absinthe"
      end

      test "does not duplicate use Permit.Absinthe if already present" do
        schema_code = """
        defmodule TestWeb.Schema do
          use Absinthe.Schema
          use Permit.Absinthe, authorization_module: Test.Authorization
        end
        """

        igniter =
          project_with_schema(schema_code)
          |> Igniter.compose_task("permit_absinthe.install", [])
          |> apply_igniter!()

        source = Rewrite.source!(igniter.rewrite, "lib/test_web/schema.ex")
        content = Rewrite.Source.get(source, :content)

        matches = Regex.scan(~r/use Permit\.Absinthe/, content)
        assert length(matches) == 1
      end
    end
  end
end
