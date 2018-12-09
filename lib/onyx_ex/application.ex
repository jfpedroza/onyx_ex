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

    OnyxEx.get_app!()
    OnyxEx.Loader.load!()
    opts = [strategy: :one_for_one, name: OnyxEx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

defmodule OnyxEx.Loader do
  def load() do
    if :ets.whereis(:onyx) == :undefined do
      :onyx = :ets.new(:onyx, [:named_table, {:read_concurrency, true}, :protected])
    end

    get_project_file()
    |> get_project_path()
    |> file_exists?()
    |> validate_extension()
    |> load_file()
    |> process_project_file()
    |> push_into_ets()
  end

  def load!() do
    case load() do
      {:ok, result} -> result
      {:error, err} -> raise "Error loading configuration: #{err}"
    end
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

  defp file_exists?({:ok, path}) do
    if File.exists?(path), do: {:ok, path}, else: {:error, "#{path} doesn't exist"}
  end

  defp file_exists?({:error, err}) do
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
    case YamlElixir.read_from_file(path) do
      {:ok, loaded} -> {:ok, loaded}
      {:error, err} -> {:error, "Error loading file #{path}: #{err}"}
    end
  end

  defp load_file({:error, err}) do
    {:error, err}
  end

  defp process_project_file({:ok, loaded}) do
    app_config = get_app_config(loaded)
    apps_config = get_apps_config(loaded)

    included =
      Map.get(loaded, "include", [])
      |> Enum.map(fn file_name ->
        {:ok, file_name}
        |> get_project_path()
        |> file_exists?()
        |> validate_extension()
        |> load_file()
        |> process_included_file()
      end)

    case Enum.find(included, fn {atom, _} -> atom == :error end) do
      nil ->
        %{
          app: app_config,
          apps: apps_config,
          included: Enum.map(included, fn {:ok, inc} -> inc end)
        }
        |> merge()

      {:error, err} ->
        {:error, err}
    end
  end

  defp process_project_file({:error, err}) do
    {:error, err}
  end

  defp process_included_file({:ok, loaded}) do
    app_config = get_app_config(loaded)
    apps_config = get_apps_config(loaded)
    {:ok, %{app: app_config, apps: apps_config}}
  end

  defp process_included_file({:error, err}) do
    {:error, err}
  end

  defp get_app_config(loaded) do
    case Map.fetch(loaded, "app") do
      {:ok, app} ->
        Map.get(app, "config", %{})
        |> make_key_atoms()

      :error ->
        %{}
    end
  end

  defp get_apps_config(loaded) do
    case Map.get(loaded, "apps") do
      nil ->
        %{}

      apps ->
        apps
        |> Enum.map(fn {name, app} ->
          {String.to_atom(name), Map.get(app, "config", %{}) |> make_key_atoms()}
        end)
        |> Map.new()
    end
  end

  defp make_key_atoms(config) do
    config
    |> Map.new(fn {key, val} ->
      {String.to_atom(key),
       case val do
         val when is_map(val) ->
           Map.new(val, fn {sub_key, sub_val} -> {String.to_atom(sub_key), sub_val} end)

         val ->
           val
       end}
    end)
  end

  defp merge(%{app: app, apps: apps, included: included}) do
    with {:ok, app} <- merge_app(app, Enum.map(included, & &1.app)),
         {:ok, apps} <- merge_apps(apps, Enum.map(included, & &1.apps)) do
      {:ok, %{app: app, apps: apps}}
    end
  end

  defp merge_app(app, included) do
    Enum.reduce(included, {:ok, app}, fn
      inc, {:ok, app} ->
        merge_included_app(app, inc)

      _inc, {:error, err} ->
        {:error, err}
    end)
  end

  defp merge_included_app(app, included_app) do
    Enum.reduce(included_app, {:ok, app}, fn
      {key, val}, {:ok, app} ->
        if Map.has_key?(app, key) do
          case app[key] do
            map when is_map(map) ->
              if is_map(val) do
                {:ok, %{app | key => Map.merge(map, val)}}
              else
                {:error, "Incompatible config value types (found string and map). Key: #{key}"}
              end

            _str ->
              unless is_map(val) do
                {:ok, %{app | key => val}}
              else
                {:error, "Incompatible config value types (found string and map). Key: #{key}"}
              end
          end
        else
          {:ok, Map.put(app, key, val)}
        end

      _, {:error, err} ->
        {:error, err}
    end)
  end

  defp merge_apps(apps, included) do
    Enum.reduce(included, {:ok, apps}, fn
      inc, {:ok, apps} ->
        merge_included_apps(apps, inc)

      _inc, {:error, err} ->
        {:error, err}
    end)
  end

  defp merge_included_apps(apps, included_apps) do
    Enum.reduce(included_apps, {:ok, apps}, fn
      {name, app}, {:ok, apps} ->
        if Map.has_key?(apps, name) do
          case merge_included_app(apps[name], app) do
            {:ok, app} -> {:ok, %{apps | name => app}}
            {:error, err} -> {:error, err}
          end
        else
          {:ok, Map.put(apps, name, app)}
        end

      _, {:error, err} ->
        {:error, err}
    end)
  end

  defp push_into_ets({:ok, loaded}) do
    Enum.map(loaded.app, fn {key, val} ->
      :ets.insert(:onyx, {{:_app, key}, val})
    end)

    Enum.map(loaded.apps, fn {name, app} ->
      Enum.map(app, fn {key, val} ->
        :ets.insert(:onyx, {{name, key}, val})
      end)
    end)

    {:ok, nil}
  end

  defp push_into_ets({:error, err}) do
    {:error, err}
  end
end
