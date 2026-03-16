defmodule Jido.ToolRenderers do
  @moduledoc """
  Registry mapping tool names to their specialized renderer modules.

  Each renderer is a Phoenix.Component module with a `render/1` function that
  receives assigns with: tool, args, completed, content, error_msg, tool_call_id.

  To add a new renderer:
  1. Create a module in tool_renderers/ with `use Phoenix.Component` and a `render/1` function
  2. Add a mapping here in `renderer_for/1`
  """

  alias Jido.ToolRenderers.{
    ApplyPatch,
    AskUser,
    Bash,
    FileWrite,
    Generic,
    GitHub,
    Glob,
    Grep,
    ReadAgent,
    ReportIntent,
    Sql,
    Task,
    UpdateTodo,
    View,
    WebFetch,
    WebSearch
  }

  @doc """
  Normalizes provider-specific tool names to a shared canonical name so
  equivalent actions render consistently across providers.
  """
  def canonical_tool_name(tool_name) when is_binary(tool_name) do
    case tool_name do
      "Bash" -> "bash"
      "shell_command" -> "bash"
      "run_shell_command" -> "bash"
      "exec_command" -> "bash"
      "BashOutput" -> "read_bash"
      "write_stdin" -> "write_bash"
      "KillShell" -> "stop_bash"
      "Read" -> "view"
      "read_file" -> "view"
      "view_file" -> "view"
      "Grep" -> "grep"
      "rg" -> "grep"
      "search_file_content" -> "grep"
      "Glob" -> "glob"
      "list_directory" -> "glob"
      "list_files" -> "glob"
      other -> other
    end
  end

  def canonical_tool_name(tool_name), do: tool_name

  @doc "Returns the renderer module for a given tool name."
  def renderer_for(tool_name) do
    case canonical_tool_name(tool_name) do
      # ── User interaction ──
      "ask_user" ->
        AskUser

      "AskUserQuestion" ->
        AskUser

      # ── Web ──
      "web_search" ->
        WebSearch

      "WebSearch" ->
        WebSearch

      "web_fetch" ->
        WebFetch

      "WebFetch" ->
        WebFetch

      # ── Tasks/agents ──
      "task" ->
        Task

      "Task" ->
        Task

      "TaskCreate" ->
        Task

      "TaskUpdate" ->
        UpdateTodo

      "TaskOutput" ->
        ReadAgent

      "read_agent" ->
        ReadAgent

      "list_agents" ->
        ReadAgent

      # ── File operations ──
      "create" ->
        FileWrite

      "edit" ->
        FileWrite

      "Write" ->
        FileWrite

      "Edit" ->
        FileWrite

      "write_file" ->
        FileWrite

      "replace" ->
        FileWrite

      "apply_patch" ->
        ApplyPatch

      "view" ->
        View

      "Read" ->
        View

      "read_file" ->
        View

      # ── Shell / bash ──
      "bash" ->
        Bash

      "Bash" ->
        Bash

      "read_bash" ->
        Bash

      "write_bash" ->
        Bash

      "stop_bash" ->
        Bash

      "list_bash" ->
        Bash

      "KillShell" ->
        Bash

      "shell_command" ->
        Bash

      "run_shell_command" ->
        Bash

      # ── Search ──
      "grep" ->
        Grep

      "Grep" ->
        Grep

      "rg" ->
        Grep

      "search_file_content" ->
        Grep

      "glob" ->
        Glob

      "Glob" ->
        Glob

      "list_directory" ->
        Glob

      # ── Other ──
      "sql" ->
        Sql

      "report_intent" ->
        ReportIntent

      "update_todo" ->
        UpdateTodo

      "TodoWrite" ->
        UpdateTodo

      "task_complete" ->
        UpdateTodo

      "ExitPlanMode" ->
        ReportIntent

      "EnterPlanMode" ->
        ReportIntent

      "update_plan" ->
        ReportIntent

      "fetch_copilot_cli_documentation" ->
        ReportIntent

      "store_memory" ->
        Generic

      "skill" ->
        Generic

      "Skill" ->
        Generic

      "BashOutput" ->
        Bash

      "view_image" ->
        View

      "TaskList" ->
        Generic

      t when is_binary(t) and byte_size(t) > 0 ->
        cond do
          String.starts_with?(t, "github-mcp-server-") -> GitHub
          String.starts_with?(t, "mcp__") -> Generic
          true -> Generic
        end

      _ ->
        Generic
    end
  end
end
