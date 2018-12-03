defmodule OnyxEx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: OnyxEx.Worker.start_link(arg)
      # {OnyxEx.Worker, arg},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options

    :onyx = :ets.new(:onyx, [:named_table, {:read_concurrency, true}, :public, :protected])
    opts = [strategy: :one_for_one, name: OnyxEx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
