defmodule OnyxEx do
  @moduledoc """
  Documentation for OnyxEx.
  """

  @app Mix.Project.config()

  def get(_path) do
    Application.get_all_env(:onyx_ex)
  end
end
