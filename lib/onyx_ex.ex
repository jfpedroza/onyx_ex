defmodule OnyxEx do
  @moduledoc """
  Documentation for OnyxEx.
  """

  def get_app!() do
    Application.get_env(:onyx_ex, :app) ||
      raise ":app must be set. Make sure to put config :onyx_ex, app: :my_app in config.exs"
  end

  def get_format() do
    Application.get_env(:onyx_ex, :format, :map)
  end

  def get!({key, sub_key}) do
    get!(get_app!(), {key, sub_key})
  end

  def get!(key) do
    get!(get_app!(), key)
  end

  def get!(app, {key, sub_key}) do
    case do_get(app, {key, sub_key}) do
      {:ok, val} -> val
      :not_found -> raise "Key, Subkey '{#{key}, #{sub_key}}' pair not found"
    end
  end

  def get!(app, key) do
    case do_get(app, key) do
      {:ok, val} -> val
      :not_found -> raise "Key '#{key}' not found"
    end
  end

  def get({key, sub_key}, default) do
    get(get_app!(), {key, sub_key}, default)
  end

  def get(key, default) do
    get(get_app!(), key, default)
  end

  def get(app, {key, sub_key}, default) do
    case do_get(app, {key, sub_key}) do
      {:ok, val} -> val
      :not_found -> default
    end
  end

  def get(app, key, default) do
    case do_get(app, key) do
      {:ok, val} -> val
      :not_found -> default
    end
  end

  defp do_get(app, {key, sub_key}) do
    case do_get(app, key) do
      {:ok, map} when is_map(map) ->
        case Map.fetch(map, sub_key) do
          {:ok, val} -> {:ok, val}
          :error -> :not_found
        end

      {:ok, kw} when is_list(kw) ->
        case Keyword.fetch(kw, sub_key) do
          {:ok, val} -> {:ok, val}
          :error -> :not_found
        end

      {:ok, val} ->
        raise "Cannot get subkey #{sub_key} out of #{inspect(val)}"

      :not_found ->
        :not_found
    end
  end

  defp do_get(app = :_app, key) do
    if :ets.whereis(:onyx) == :undefided do
      OnyxEx.Loader.load!()
    end

    case :ets.lookup(:onyx, {app, key}) do
      [{{^app, ^key}, val}] ->
        case get_format() do
          :map -> {:ok, val}
          :keyword -> {:ok, Keyword.new(val)}
          format -> raise "Invalid format #{format}. Allowed: :map, :keyword"
        end

      [] ->
        :not_found
    end
  end

  defp do_get(app, key) do
    if :ets.whereis(:onyx) == :undefided do
      OnyxEx.Loader.load!()
    end

    case :ets.lookup(:onyx, {app, key}) do
      [{{^app, ^key}, val}] ->
        case get_format() do
          :map -> {:ok, val}
          :keyword -> {:ok, Keyword.new(val)}
          format -> raise "Invalid format #{format}. Allowed: :map, :keyword"
        end

      [] ->
        do_get(:_app, key)
    end
  end

  def sigil_o(path, []) do
    case String.split(path, "|") do
      [key | [sub_key]] -> get({String.to_atom(key), String.to_atom(sub_key)}, nil)
      [key] -> get(String.to_atom(key), nil)
    end
  end

  def sigil_o(path, app) do
    case String.split(path, "|") do
      [key | [sub_key]] ->
        get(List.to_atom(app), {String.to_atom(key), String.to_atom(sub_key)}, nil)

      [key] ->
        get(List.to_atom(app), String.to_atom(key), nil)
    end
  end

  def sigil_O(path, []) do
    case String.split(path, "|") do
      [key | [sub_key]] -> get!({String.to_atom(key), String.to_atom(sub_key)})
      [key] -> get!(String.to_atom(key))
    end
  end

  def sigil_O(path, app) do
    case String.split(path, "|") do
      [key | [sub_key]] ->
        get!(List.to_atom(app), {String.to_atom(key), String.to_atom(sub_key)})

      [key] ->
        get!(List.to_atom(app), String.to_atom(key))
    end
  end
end
