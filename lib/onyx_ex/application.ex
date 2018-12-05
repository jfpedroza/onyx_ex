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
    OnyxEx.Loader.load!()
    opts = [strategy: :one_for_one, name: OnyxEx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

defmodule OnyxEx.Loader do
  def load() do
    get_app!() |> IO.inspect()

    get_project_file()
    |> get_project_path()
    |> validate_extension()
    |> load_file()
    |> IO.inspect()
    |> process_project_file()
    |> IO.inspect()
  end

  def load!() do
    case load() do
      {:ok, result} -> result
      {:error, err} -> raise "Error loading configuration: #{err}"
    end
  end

  defp get_app!() do
    Application.get_env(:onyx_ex, :app) ||
      raise ":app must be set. Make sure to put config :onyx_ex, app: :my_app in config.exs"
  end

  defp get_project_file() do
    {:ok, Application.get_env(:onyx_ex, :project, "onyx.yml")}
  end

  defp get_project_path({:ok, file}) do
    {:ok, Path.expand(file)}
  end

  defp get_project_path({:error, err}) do
    {:error, err}
  end

  defp validate_extension({:ok, path}) do
    if path =~ ~r/\.ya?ml$/ do
      {:ok, path}
    else
      {:error, "The format of #{path} is unsupported"}
    end
  end

  defp validate_extension({:error, err}) do
    {:error, err}
  end

  defp load_file({:ok, path}) do
    YamlElixir.read_from_file(path)
  end

  defp load_file({:error, err}) do
    {:error, err}
  end

  defp process_project_file({:ok, loaded}) do
    app_config = get_app_config(loaded) |> IO.inspect(label: "App config")
    apps_config = get_apps_config(loaded) |> IO.inspect(label: "Apps config")
    included = Map.get(loaded, "include", []) |> IO.inspect(label: "Included files")
    {:ok, nil}
  end

  defp process_project_file({:error, err}) do
    {:error, err}
  end

  defp get_app_config(loaded) do
    case Map.get(loaded, "app") do
      nil -> %{}
      app -> Map.get(app, "config", %{})
    end

    if {:ok, app} = Map.fetch(loaded, "app") do
      Map.get(app, "config", %{})
    else
      %{}
    end
  end

  defp get_apps_config(loaded) do
    case Map.get(loaded, "apps") do
      nil -> %{}
      apps -> Enum.map(apps, fn {name, app} -> {name, Map.get(app, "config", %{})} end)
    end
  end
end
