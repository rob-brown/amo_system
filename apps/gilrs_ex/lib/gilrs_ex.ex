defmodule GilrsEx do
  @moduledoc """
  Elixir bindings for the Gilrs (Game Input Library for Rust) library.

  Provides cross-platform gamepad/joystick support for Linux, macOS, and Windows.
  """

  defmodule Event do
    @moduledoc """
    Represents a gamepad event from GilRs.
    """
    defstruct [:gamepad_id, :event_type, :button, :button_code, :axis, :axis_code, :value]

    @type t :: %__MODULE__{
            gamepad_id: non_neg_integer(),
            event_type: String.t(),
            button: String.t() | nil,
            button_code: non_neg_integer() | nil,
            axis: String.t() | nil,
            axis_code: non_neg_integer() | nil,
            value: float() | nil
          }
  end

  defmodule Native do
    @moduledoc false
    use Rustler, otp_app: :gilrs_ex, crate: :gilrs_ex

    def new(), do: :erlang.nif_error(:nif_not_loaded)
    def next_event(_resource), do: :erlang.nif_error(:nif_not_loaded)
    def connected_gamepads(_resource), do: :erlang.nif_error(:nif_not_loaded)
    def gamepad_name(_resource, _id), do: :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Creates a new Gilrs context.

  Returns `{:ok, resource}` on success, or `{:error, reason}` on failure.

  ## Examples

      {:ok, gilrs} = GilrsEx.new()
  """
  @spec new() :: {:ok, reference()} | {:error, String.t()}
  def new do
    case Native.new() do
      {:ok, resource} -> {:ok, resource}
      {:error, reason} -> {:error, reason}
      resource when is_reference(resource) -> {:ok, resource}
    end
  end

  @doc """
  Polls for the next gamepad event.

  Returns `{:ok, event}` if an event is available, or `:none` if no events are queued.

  ## Examples

      {:ok, event} = GilrsEx.next_event(gilrs)
      %GilrsEx.Event{gamepad_id: 0, event_type: "button_pressed", button: "south"}
  """
  @spec next_event(reference()) :: {:ok, Event.t()} | :none | {:error, term()}
  def next_event(resource) do
    case Native.next_event(resource) do
      {:ok, %Event{} = event} -> {:ok, event}
      %Event{} = event -> {:ok, event}
      {:error, :none} -> :none
      :none -> :none
      {:error, _} = error -> error
    end
  end

  @doc """
  Returns a list of currently connected gamepad IDs.

  ## Examples

      {:ok, ids} = GilrsEx.connected_gamepads(gilrs)
      [0, 1]
  """
  @spec connected_gamepads(reference()) :: {:ok, [non_neg_integer()]} | {:error, term()}
  def connected_gamepads(resource) do
    case Native.connected_gamepads(resource) do
      {:ok, ids} when is_list(ids) -> {:ok, ids}
      ids when is_list(ids) -> {:ok, ids}
      {:error, _} = error -> error
    end
  end

  @doc """
  Returns the name of a gamepad by its ID.

  ## Examples

      {:ok, name} = GilrsEx.gamepad_name(gilrs, 0)
      "Xbox 360 Controller"
  """
  @spec gamepad_name(reference(), non_neg_integer()) :: {:ok, String.t()} | {:error, term()}
  def gamepad_name(resource, id) do
    case Native.gamepad_name(resource, id) do
      {:ok, name} when is_binary(name) -> {:ok, name}
      name when is_binary(name) -> {:ok, name}
      {:error, _} = error -> error
    end
  end
end
