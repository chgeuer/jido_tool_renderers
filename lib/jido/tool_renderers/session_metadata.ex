defmodule Jido.ToolRenderers.SessionMetadata do
  @moduledoc """
  Metadata about a coding agent session, used by session viewer components
  to display status, model info, and session-level context.
  """

  @type t :: %__MODULE__{
          session_id: String.t(),
          status: atom(),
          model: String.t() | nil,
          agent_type: atom() | nil,
          cwd: String.t() | nil,
          title: String.t() | nil,
          tokens: token_stats(),
          started_at: DateTime.t() | nil
        }

  @type token_stats :: %{
          optional(:input_tokens) => non_neg_integer(),
          optional(:output_tokens) => non_neg_integer(),
          optional(:total_cost) => String.t()
        }

  defstruct [
    :session_id,
    :model,
    :agent_type,
    :cwd,
    :title,
    :started_at,
    status: :unknown,
    tokens: %{}
  ]
end
