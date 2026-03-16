# JidoToolRenderers

Phoenix LiveView components for rendering coding agent chat sessions. Provides specialized, rich UI renderers for AI tool calls (bash, file editing, search, etc.) and a session viewer with dual-mode rendering (rich HTML and xterm.js terminal).

Used by [copilot_lv](https://github.com/agentjido/copilot_lv) and other LiveView apps that display conversations with coding agents like Claude, Codex, Gemini, and GitHub Copilot.

## Installation

Add the dependency to your `mix.exs`:

```elixir
def deps do
  [
    {:jido_tool_renderers, github: "chgeuer/jido_tool_renderers"}
  ]
end
```

For the terminal view mode, install xterm.js in your consuming app:

```bash
npm install @xterm/xterm @xterm/addon-fit
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Consuming LiveView App                │
│  (copilot_lv, symphony, etc.)                           │
└────────────┬──────────────────────────────┬──────────────┘
             │ raw events                   │
             ▼                              │
┌────────────────────────┐                  │
│       Adapters         │                  │
│  CopilotLv | Symphony  │                  │
└────────────┬───────────┘                  │
             │ SessionEvent structs         │
             ▼                              ▼
┌────────────────────────────────────────────────────────┐
│                    SessionViewer                        │
│  ┌──────────────────────┐  ┌────────────────────────┐  │
│  │    Rich (HTML)        │  │  Terminal (xterm.js)    │  │
│  │  ┌────────────────┐  │  │  ┌──────────────────┐  │  │
│  │  │ Tool Renderers │  │  │  │  AnsiFormatter    │  │  │
│  │  │ (per-tool UI)  │  │  │  │  (ANSI output)    │  │  │
│  │  └────────────────┘  │  │  └──────────────────┘  │  │
│  └──────────────────────┘  └────────────────────────┘  │
│                 Interaction Controls                     │
│           (interactive / readonly_live / readonly)       │
└─────────────────────────────────────────────────────────┘
```

## Core Concepts

### SessionEvent

All agent events are normalized into `Jido.ToolRenderers.SessionEvent` structs with a type and data map:

```elixir
%SessionEvent{
  id: "evt-1",
  type: :tool_call,
  data: %{
    "tool" => "bash",
    "arguments" => %{"command" => "mix test"},
    "tool_call_id" => "tc-123",
    "completed" => true,
    "result" => "All tests passed",
    "error" => nil
  },
  timestamp: ~U[2025-01-01 00:00:00Z],
  metadata: %{}
}
```

**Event types:**

| Type | Description |
|------|-------------|
| `:user_message` | User prompt text, optional attachments |
| `:assistant_message` | LLM output text (accumulated from chunks) |
| `:assistant_reasoning` | Internal thinking/reasoning blocks |
| `:assistant_intent` | Reported intent/status update |
| `:assistant_usage` | Token usage stats for a turn |
| `:tool_call` | Individual tool invocation with args and result |
| `:tool_group` | Grouped consecutive tool calls (collapsible) |
| `:turn_start` / `:turn_end` | Turn boundaries |
| `:session_error` | Error message |
| `:session_info` | Informational status message |
| `:session_idle` | Session is idle/waiting |
| `:ask_user` | Agent requesting user input |

Convenience constructors are provided:

```elixir
SessionEvent.user_message("Fix the tests")
SessionEvent.assistant_message("I'll look into it...")
SessionEvent.tool_call("bash", %{"command" => "mix test"}, completed: true, result: "OK")
SessionEvent.tool_group(child_events, tool_names: ["bash", "grep"])
```

### Tool Renderer Registry

`Jido.ToolRenderers.renderer_for/1` maps tool names to specialized renderer modules. It also normalizes provider-specific tool names to canonical forms via `canonical_tool_name/1`:

```elixir
Jido.ToolRenderers.renderer_for("bash")    #=> Jido.ToolRenderers.Bash
Jido.ToolRenderers.renderer_for("Read")    #=> Jido.ToolRenderers.View
Jido.ToolRenderers.renderer_for("unknown") #=> Jido.ToolRenderers.Generic

# Provider-agnostic normalization
Jido.ToolRenderers.canonical_tool_name("Bash")              #=> "bash"
Jido.ToolRenderers.canonical_tool_name("shell_command")      #=> "bash"
Jido.ToolRenderers.canonical_tool_name("run_shell_command")  #=> "bash"
Jido.ToolRenderers.canonical_tool_name("Read")               #=> "view"
```

## Tool Renderers

Each renderer is a `Phoenix.Component` module with a `render/1` function. They receive assigns including `tool`, `args`, `completed`, `content`, `error_msg`, and `tool_call_id`.

| Renderer | Tool Names | Description |
|----------|-----------|-------------|
| `Bash` | `bash`, `read_bash`, `write_bash`, `stop_bash`, `list_bash` | Terminal commands with `$ ` prompt styling, auto-collapsing output, shell ID and mode badges |
| `View` | `view`, `Read`, `read_file` | File viewer; renders `.md` files as markdown, others as preformatted text |
| `FileWrite` | `create`, `edit`, `Write`, `replace` | File create/edit with inline diff display (old → new) and markdown preview |
| `ApplyPatch` | `apply_patch` | Unified diff display with color-coded additions/deletions |
| `Grep` | `grep`, `rg`, `search_file_content` | Search pattern displayed as inline code with path/glob/type context |
| `Glob` | `glob`, `list_directory`, `list_files` | File pattern matching with path context |
| `WebSearch` | `web_search` | Search results rendered as markdown with citation badges |
| `WebFetch` | `web_fetch` | Fetched URL with clickable link and markdown result |
| `AskUser` | `ask_user` | Question with choice list; shows selected answer with checkmarks |
| `Task` | `task` | Sub-agent tasks with type badges (explore/general-purpose/code-review/task), prompt preview |
| `ReadAgent` | `read_agent`, `list_agents` | Agent results with metadata line and markdown body |
| `Sql` | `sql` | SQL query display with database badge and tabular result rendering |
| `GitHub` | `github-mcp-server-*` | GitHub MCP tools with repo reference, method badge, and markdown results |
| `ReportIntent` | `report_intent`, `update_plan`, `ExitPlanMode` | Compact intent display |
| `UpdateTodo` | `update_todo`, `task_complete` | Todo list with checkboxes; task completion summary |
| `Generic` | *(fallback)* | Default renderer: JSON arguments + preformatted result |

### Shared Sub-Components

`Jido.ToolRenderers.Generic` provides shared components used across all renderers:

- `Generic.status_indicator/1` — Shows ✓ (success), ✗ (error), or loading dots (pending)
- `Generic.error_display/1` — Conditional error message display
- `Generic.result_pre/1` — Collapsible preformatted text result
- `Generic.result_markdown/1` — Collapsible markdown-rendered result with copy button

## Session Viewer

The main `SessionViewer.session_view/1` component provides a complete chat UI with:

- **Dual view modes**: Rich HTML (DaisyUI chat bubbles) or Terminal (xterm.js)
- **Three interaction modes**: `:interactive`, `:readonly_live`, `:readonly`
- **Session metadata display**: Title, status badge, model info

### Usage

```elixir
alias Jido.ToolRenderers.SessionViewer
alias Jido.ToolRenderers.SessionViewer.Rich

# Historical replay (readonly)
<SessionViewer.session_view
  id="session-1"
  view_mode={:rich}
  interaction_mode={:readonly}
  session_metadata={@session_meta}
>
  <:events>
    <div id="events" phx-update="stream">
      <div :for={{dom_id, event} <- @streams.events} id={dom_id}>
        <Rich.event_item event={event} />
      </div>
    </div>
  </:events>
</SessionViewer.session_view>

# Active driving (interactive)
<SessionViewer.session_view
  id="session-1"
  view_mode={@view_mode}
  interaction_mode={:interactive}
  status={@status}
  model={@model}
  session_metadata={@session_meta}
  ask_user_request={@ask_user_request}
>
  <:events>...</:events>
</SessionViewer.session_view>

# Passive watching (readonly_live)
<SessionViewer.session_view
  id="session-1"
  view_mode={@view_mode}
  interaction_mode={:readonly_live}
  status={@status}
  session_metadata={@session_meta}
>
  <:events>...</:events>
</SessionViewer.session_view>
```

### Rich Mode

`SessionViewer.Rich.event_item/1` renders each `SessionEvent` as styled HTML:

- **User messages** — Right-aligned chat bubbles with markdown, copy button, and pasted attachment badges
- **Assistant messages** — Left-aligned chat bubbles with rendered markdown
- **Reasoning** — Collapsible italic blocks with 🧠 preview
- **Intent** — Inline italic status with 💭 icon
- **Tool calls** — Card with the specialized tool renderer dispatched via the registry
- **Tool groups** — Collapsible section grouping parallel tool calls with summary
- **Usage stats** — Compact token count and cost display
- **Errors** — Alert banners

### Terminal Mode

`SessionViewer.Terminal` renders events as ANSI-colored text in an xterm.js terminal. The `AnsiFormatter` converts `SessionEvent` structs to ANSI escape sequences.

```elixir
# Format a single event for incremental push
ansi = Terminal.format_event(event)
socket = push_event(socket, "xterm:write", %{data: ansi, target: "session-term"})

# Format all events for initial content
content = Terminal.format_all(events)
```

### Session Overview Dashboard

`SessionOverview.grid/1` renders a responsive grid of mini terminal panels, each showing a live preview of a session:

```elixir
<SessionOverview.grid
  sessions={@sessions}
  navigate_fn={fn id -> "/session/#{id}" end}
/>
```

Each session in the list should have `id`, `metadata` (`SessionMetadata` struct), and `recent_events` (list of `SessionEvent` structs).

## Adapters

Adapters convert provider-specific event formats into `SessionEvent` structs.

### CopilotLv Adapter

Converts copilot_lv's normalized event maps (string-keyed, with types like `"user.message"`, `"tool.combined"`, `"tool.group"`) into `SessionEvent` structs:

```elixir
alias Jido.ToolRenderers.Adapters.CopilotLv

events = CopilotLv.convert_events(raw_events)
event = CopilotLv.convert_event(raw_event)
```

### Symphony Adapter

Converts jido_symphony's atom-keyed event maps (`:agent_text`, `:tool_call`, etc.) and coalesced block maps into `SessionEvent` structs:

```elixir
alias Jido.ToolRenderers.Adapters.Symphony

events = Symphony.convert_events(raw_events)
event = Symphony.convert_block(coalesced_block)
```

## JavaScript Hooks

### XtermSession Hook

The `priv/static/js/xterm_hook.js` file provides a LiveView hook for xterm.js terminal rendering. Register it in your app's JavaScript:

```javascript
import { XtermSession } from "jido_tool_renderers/xterm_hook"

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: { XtermSession }
})
```

The hook:
- Dynamically imports `@xterm/xterm` and `@xterm/addon-fit`
- Renders with a dark VS Code-style theme
- Listens for `xterm:write` and `xterm:clear` push events from the server
- Auto-resizes via `ResizeObserver`

### Additional Hooks

The consuming app should also provide these LiveView hooks used by the rich renderer:

- **`MarkdownContent`** — Renders `data-markdown` attribute content as HTML (e.g., using `marked` or `markdown-it`)
- **`CopyMarkdown`** — Copies rendered markdown content to clipboard
- **`UserMessage`** — Renders user message markdown

## Adding a New Tool Renderer

1. Create a module in `lib/jido/tool_renderers/` with `use Phoenix.Component` and a `render/1` function:

```elixir
defmodule Jido.ToolRenderers.MyTool do
  use Phoenix.Component
  alias Jido.ToolRenderers.Generic

  def render(assigns) do
    args = assigns.args || %{}
    # Extract relevant args...

    ~H"""
    <div class="flex items-center gap-2">
      <span class="badge badge-info badge-sm">🔧 my_tool</span>
      <Generic.status_indicator completed={@completed} error_msg={@error_msg} />
    </div>
    <Generic.error_display error_msg={@error_msg} />
    <Generic.result_pre content={@content} completed={@completed} />
    """
  end
end
```

2. Add a mapping in `Jido.ToolRenderers.renderer_for/1`:

```elixir
"my_tool" -> MyTool
```

## UI Framework

Components use [DaisyUI](https://daisyui.com/) classes (built on Tailwind CSS). The consuming app must include DaisyUI in its CSS build. Key classes used:

- `chat`, `chat-bubble` — Conversation layout
- `badge` — Tool name and status indicators
- `card` — Tool call containers
- `alert` — Errors and info messages
- `btn` — Interactive controls
- `loading` — Spinner animations

## Requirements

- Elixir ~> 1.18
- Phoenix LiveView ~> 1.0
- Jason ~> 1.4
- DaisyUI + Tailwind CSS (in consuming app)
- `@xterm/xterm` + `@xterm/addon-fit` (optional, for terminal mode)

## License

See [LICENSE](LICENSE) for details.
