defmodule Jido.ToolRenderers.UnifiedCommandRenderingTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Jido.ToolRenderers
  alias Jido.ToolRenderers.Adapters.CopilotLv
  alias Jido.ToolRenderers.Bash

  test "canonicalizes shell and file tool aliases" do
    assert ToolRenderers.canonical_tool_name("exec_command") == "bash"
    assert ToolRenderers.canonical_tool_name("write_stdin") == "write_bash"
    assert ToolRenderers.canonical_tool_name("read_file") == "view"
    assert ToolRenderers.renderer_for("exec_command") == Bash
  end

  test "normalizes copilot_lv tool events to shared tool names and decoded args" do
    raw_tool = %{
      type: "tool.combined",
      data: %{
        "toolName" => "exec_command",
        "arguments" => ~s({"cmd":"rg --files","workdir":"/tmp/project"}),
        "toolCallId" => "call-1",
        "completed" => true,
        "result" => "README.md\nlib/app.ex"
      }
    }

    event = CopilotLv.convert_event(raw_tool)

    assert event.type == :tool_call
    assert event.data["tool"] == "bash"
    assert event.data["arguments"] == %{"cmd" => "rg --files", "workdir" => "/tmp/project"}

    group =
      CopilotLv.convert_event(%{
        type: "tool.group",
        data: %{
          "events" => [raw_tool],
          "tool_names" => ["exec_command"],
          "tool_count" => 1
        }
      })

    assert group.data["tool_names"] == ["bash"]
  end

  test "renders codex exec_command like a bash command with workdir and output" do
    html =
      render_component(&Bash.render/1,
        tool: "exec_command",
        args: %{
          "cmd" => "rg --files",
          "workdir" => "/home/chgeuer/github/chgeuer/basileus/docs",
          "max_output_tokens" => 4000
        },
        completed: true,
        content: "README.md\n01-product-intent.md",
        error_msg: "",
        tool_call_id: "call-1"
      )

    assert html =~ "bash"
    assert html =~ "rg --files"
    assert html =~ "cd /home/chgeuer/github/chgeuer/basileus/docs"
    assert html =~ "4000 tok"
    assert html =~ "README.md"
  end

  test "renders empty write_stdin polls like read_bash interactions" do
    html =
      render_component(&Bash.render/1,
        tool: "write_stdin",
        args: %{
          "session_id" => 45452,
          "chars" => "",
          "yield_time_ms" => 1000,
          "max_output_tokens" => 12000
        },
        completed: true,
        content: "Output:\n/home/chgeuer/github/chgeuer/basileus/docs",
        error_msg: "",
        tool_call_id: "call-2"
      )

    assert html =~ "read_bash"
    assert html =~ "45452"
    assert html =~ "1000 ms"
    assert html =~ "12000 tok"
  end
end
