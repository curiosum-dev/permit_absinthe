defmodule PermitAbsintheDemoWeb.ErrorJSON do
  @moduledoc false

  def render(template, _assigns) when is_binary(template) do
    %{errors: [%{message: Phoenix.Controller.status_message_from_template(template)}]}
  end
end
