defmodule PermitAbsintheDemo.Application do
  @moduledoc """
  OTP application that boots the demo Repo and Phoenix endpoint.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PermitAbsintheDemo.Repo,
      {Phoenix.PubSub, name: PermitAbsintheDemo.PubSub},
      PermitAbsintheDemoWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__.Supervisor)
  end

  @impl true
  def config_change(changed, _new, removed) do
    PermitAbsintheDemoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
