if Version.match?(System.version(), ">= 1.15.0") and Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PermitAbsinthe.Install do
    @shortdoc "Installs Permit.Absinthe authorization into your project"

    @moduledoc """
    Installs Permit.Absinthe into your project by patching the Absinthe schema module
    to include `use Permit.Absinthe`.

    ## Usage

        mix permit_absinthe.install

    ## Options

    - `--authorization-module` - Authorization module name (default: `<MyApp>.Authorization`)
    - `--schema-module` - Absinthe schema module (default: `<MyApp>Web.Schema`)
    """

    use Igniter.Mix.Task

    alias Igniter.Code.Common
    alias Igniter.Code.Function
    alias Igniter.Libs.Phoenix, as: IgniterPhoenix
    alias Igniter.Project.Module, as: ProjectModule

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :permit,
        schema: [
          authorization_module: :string,
          schema_module: :string
        ]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      options = igniter.args.options
      app_module = ProjectModule.module_name_prefix(igniter)
      web_module = IgniterPhoenix.web_module(igniter)

      authorization_module =
        parse_module(options[:authorization_module], Module.concat(app_module, Authorization))

      schema_module = parse_module(options[:schema_module], Module.concat(web_module, Schema))

      igniter
      |> patch_schema_module(schema_module, authorization_module)
      |> Igniter.add_notice("""
      Permit.Absinthe has been set up!

      Next steps:

        1. Map your GraphQL types to Ecto schemas:

             object :post do
               permit schema: MyApp.Blog.Post
               field :id, :id
               field :title, :string
             end

        2. Use the built-in resolvers:

             field :posts, list_of(:post) do
               permit action: :read
               resolve &load_and_authorize/2
             end

        3. For mutations, use middleware:

             field :update_post, :post do
               permit action: :update
               middleware Permit.Absinthe.Middleware
               resolve fn _, args, %{context: %{loaded_resource: post}} ->
                 MyApp.Blog.update_post(post, args)
               end
             end
      """)
    end

    defp patch_schema_module(igniter, schema_module, authorization_module) do
      use_code =
        "use Permit.Absinthe, authorization_module: #{inspect(authorization_module)}"

      case ProjectModule.find_and_update_module(igniter, schema_module, fn zipper ->
             inject_use_permit_absinthe(zipper, schema_module, use_code)
           end) do
        {:ok, igniter} ->
          igniter

        {:error, igniter} ->
          Igniter.add_notice(igniter, """
          Could not find schema module #{inspect(schema_module)}.
          Please add the following to your Absinthe schema module:

              #{use_code}
          """)
      end
    end

    defp inject_use_permit_absinthe(zipper, schema_module, use_code) do
      case find_use_call(zipper, Permit.Absinthe) do
        {:ok, _} -> {:ok, zipper}
        :error -> inject_after_absinthe_schema(zipper, schema_module, use_code)
      end
    end

    defp inject_after_absinthe_schema(zipper, schema_module, use_code) do
      case find_use_call(zipper, Absinthe.Schema) do
        {:ok, use_zipper} ->
          {:ok, Common.add_code(use_zipper, use_code, placement: :after)}

        :error ->
          {:warning,
           """
           Could not find `use Absinthe.Schema` in #{inspect(schema_module)}.
           Please add the following manually:

               #{use_code}
           """}
      end
    end

    defp find_use_call(zipper, module) do
      Common.move_to(zipper, fn z ->
        Function.function_call?(z, :use, [1, 2]) &&
          Function.argument_matches_predicate?(
            z,
            0,
            &Common.nodes_equal?(&1, module)
          )
      end)
    end

    defp parse_module(nil, default), do: default

    defp parse_module(string, _default) when is_binary(string) do
      string
      |> String.split(".")
      |> Module.concat()
    end
  end
end
