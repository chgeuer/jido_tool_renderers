defmodule Jido.ToolRenderers.Components do
  @moduledoc """
  Shared UI components for tool renderers.

  Provides a unified `markdown_content` component that renders markdown
  with a built-in copy-to-clipboard button. All renderers should use this
  instead of wiring up `MarkdownContent` and `CopyMarkdown` hooks manually.
  """
  use Phoenix.Component

  @doc """
  Renders markdown content with a built-in copy button.

  Uses the `MarkdownContent` JS hook to render markdown client-side via `marked`,
  and the `CopyMarkdown` hook for one-click clipboard copy. The copy button
  appears on hover.

  ## Examples

      <Components.markdown_content id="my-md" content={@some_markdown} />
      <Components.markdown_content id="my-md" content={@text} class="text-xs" copy={false} />
  """
  attr :id, :string, required: true, doc: "unique DOM id for the markdown container"
  attr :content, :string, required: true, doc: "raw markdown text to render"
  attr :class, :any, default: nil, doc: "additional CSS classes for the markdown container"
  attr :copy, :boolean, default: true, doc: "whether to show the copy-to-clipboard button"

  def markdown_content(assigns) do
    ~H"""
    <div class="relative group">
      <div
        id={@id}
        class={["markdown-body", @class]}
        phx-hook="MarkdownContent"
        data-markdown={@content}
      >
      </div>
      <button
        :if={@copy}
        class="absolute top-2 right-2 btn btn-ghost btn-xs opacity-0 group-hover:opacity-100 transition-opacity text-base-content/50 hover:text-base-content"
        phx-hook="CopyMarkdown"
        id={"copy-#{@id}"}
        data-target={@id}
      >
        📋
      </button>
    </div>
    """
  end
end
