defmodule AgentmancerWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use AgentmancerWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="flex h-screen overflow-hidden">
      <aside class="w-64 flex flex-col bg-base-200 border-r border-base-300 shrink-0">
        <div class="p-4 border-b border-base-300">
          <.link navigate={~p"/"} class="text-lg font-bold tracking-tight">Agentmancer</.link>
        </div>

        <nav class="flex-1 p-3">
          <ul class="menu menu-sm gap-1">
            <li>
              <.link navigate={~p"/"} class="gap-2">
                <.icon name="hero-home" class="size-4" /> Dashboard
              </.link>
            </li>
            <li>
              <.link navigate={~p"/projects"} class="gap-2">
                <.icon name="hero-folder" class="size-4" /> Projects
              </.link>
            </li>
            <li>
              <.link navigate={~p"/runs"} class="gap-2">
                <.icon name="hero-play-circle" class="size-4" /> Runs
              </.link>
            </li>
            <li>
              <.link navigate={~p"/settings"} class="gap-2">
                <.icon name="hero-cog-6-tooth" class="size-4" /> Settings
              </.link>
            </li>
          </ul>
        </nav>

        <div class="p-3 border-t border-base-300">
          <div class="flex items-center gap-2 mb-2">
            <.theme_toggle />
          </div>
          <div
            :if={@current_scope && @current_scope.user}
            class="text-xs text-base-content/60 truncate mb-1"
          >
            {@current_scope.user.email}
          </div>
          <div class="flex gap-2 text-xs">
            <.link href={~p"/users/settings"} class="link link-hover">Account</.link>
            <.link href={~p"/users/log-out"} method="delete" class="link link-hover">Log out</.link>
          </div>
        </div>
      </aside>

      <main class="flex-1 overflow-y-auto">
        <div class="p-6 max-w-7xl mx-auto">
          {render_slot(@inner_block)}
        </div>
      </main>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
