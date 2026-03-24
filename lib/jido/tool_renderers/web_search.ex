defmodule Jido.ToolRenderers.WebSearch do
  use Phoenix.Component
  alias Jido.ToolRenderers.Generic
  alias Jido.ToolRenderers.Components

  def render(assigns) do
    args = assigns.args || %{}
    query = args["query"] || ""
    {search_text, citations, _search_url} = parse_result(assigns.content)

    md_id = "ws-#{assigns.tool_call_id || System.unique_integer([:positive])}"

    assigns =
      assign(assigns, query: query, search_text: search_text, citations: citations, md_id: md_id)

    ~H"""
    <div class="flex items-center gap-2">
      <span class="badge badge-accent badge-sm">🔍 web_search</span>
      <Generic.status_indicator completed={@completed} error_msg={@error_msg} />
    </div>
    <div class="text-sm font-medium mt-1">"{@query}"</div>
    <Generic.error_display error_msg={@error_msg} />
    <%= if @search_text != "" do %>
      <details class="text-xs" open>
        <summary class="cursor-pointer text-base-content/50">Search results</summary>
        <div class="mt-1 p-3 bg-base-100 border border-base-300 rounded max-h-96 overflow-y-auto">
          <Components.markdown_content id={@md_id} content={@search_text} />
        </div>
      </details>
      <%= if @citations != [] do %>
        <div class="mt-1 flex flex-wrap gap-1">
          <%= for {title, url} <- @citations do %>
            <a href={url} target="_blank" class="badge badge-ghost badge-xs hover:badge-primary gap-1">
              🔗 {String.slice(title, 0..40)}
            </a>
          <% end %>
        </div>
      <% end %>
    <% end %>
    """
  end

  defp parse_result(""), do: {"", [], nil}

  defp parse_result(content) do
    case Jason.decode(content) do
      {:ok,
       %{"type" => "text", "text" => %{"value" => text, "annotations" => annotations}} = data} ->
        clean_text = Regex.replace(~r/【[^】]+】/, text, "")

        citations =
          (annotations || [])
          |> Enum.filter(&is_map/1)
          |> Enum.map(fn a ->
            cit = a["url_citation"] || %{}
            {cit["title"] || "", cit["url"] || ""}
          end)
          |> Enum.filter(fn {_, url} -> url != "" end)
          |> Enum.uniq_by(fn {_, url} -> url end)

        search_url =
          case data["bing_searches"] do
            [%{"url" => url} | _] -> url
            _ -> nil
          end

        {clean_text, citations, search_url}

      _ ->
        {content, [], nil}
    end
  end
end
