defmodule AgentmancerWeb.SettingLive.Index do
  use AgentmancerWeb, :live_view

  alias Agentmancer.Vault

  @impl true
  def mount(_params, _session, socket) do
    {scope_id, variables} = load_global_variables()

    {:ok,
     assign(socket,
       page_title: "Settings",
       scope_id: scope_id,
       variables: variables,
       var_key: "",
       var_value: "",
       var_secret: false
     )}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save_variable", %{"key" => key, "value" => value, "secret" => secret}, socket) do
    {:ok, scope} = Vault.get_or_create_scope(:global)

    case Vault.set_variable(scope.id, key, value, is_secret: secret == "true") do
      {:ok, _var} ->
        {scope_id, variables} = load_global_variables()

        {:noreply,
         socket
         |> put_flash(:info, "Variable saved.")
         |> assign(
           scope_id: scope_id,
           variables: variables,
           var_key: "",
           var_value: "",
           var_secret: false
         )}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save variable.")}
    end
  end

  def handle_event("save_variable", %{"key" => key, "value" => value}, socket) do
    handle_event("save_variable", %{"key" => key, "value" => value, "secret" => "false"}, socket)
  end

  def handle_event("delete_variable", %{"id" => id}, socket) do
    case Vault.delete_variable(id) do
      {:ok, _} ->
        {scope_id, variables} = load_global_variables()

        {:noreply,
         socket
         |> put_flash(:info, "Variable deleted.")
         |> assign(scope_id: scope_id, variables: variables)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete variable.")}
    end
  end

  defp load_global_variables do
    case Vault.get_or_create_scope(:global) do
      {:ok, scope} -> {scope.id, Vault.list_variables_for_scope(scope.id)}
      _ -> {nil, []}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Settings
        <:subtitle>Global configuration and variables</:subtitle>
      </.header>

      <div class="mt-6">
        <h2 class="text-lg font-semibold mb-4">Global Variables</h2>
        <p class="text-sm text-base-content/60 mb-4">
          Global variables are available to all projects and workflows.
        </p>

        <div class="mb-6">
          <form phx-submit="save_variable" class="flex flex-wrap gap-3 items-end max-w-2xl">
            <div class="form-control">
              <label class="label"><span class="label-text">Key</span></label>
              <input
                type="text"
                name="key"
                value={@var_key}
                required
                class="input input-bordered input-sm w-48"
                placeholder="API_KEY"
              />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Value</span></label>
              <input
                type="text"
                name="value"
                value={@var_value}
                required
                class="input input-bordered input-sm w-64"
                placeholder="value..."
              />
            </div>
            <div class="form-control">
              <label class="label cursor-pointer gap-2">
                <span class="label-text">Secret</span>
                <input
                  type="checkbox"
                  name="secret"
                  value="true"
                  checked={@var_secret}
                  class="checkbox checkbox-sm"
                />
              </label>
            </div>
            <button type="submit" class="btn btn-primary btn-sm">Save Variable</button>
          </form>
        </div>

        <div :if={@variables == []} class="text-base-content/60 text-sm">
          No global variables set.
        </div>

        <.table :if={@variables != []} id="global-variables" rows={@variables}>
          <:col :let={var} label="Key">
            <span class="font-mono text-sm">{var.key}</span>
          </:col>
          <:col :let={var} label="Value">
            <span :if={var.is_secret} class="text-base-content/40 italic">***hidden***</span>
            <span :if={!var.is_secret} class="font-mono text-sm">{var.value_ciphertext}</span>
          </:col>
          <:col :let={var} label="Secret">
            <span :if={var.is_secret} class="badge badge-sm badge-warning">secret</span>
          </:col>
          <:col :let={var} label="Description">
            <span class="text-sm text-base-content/60">{var.description || "-"}</span>
          </:col>
          <:action :let={var}>
            <button
              phx-click="delete_variable"
              phx-value-id={var.id}
              class="btn btn-ghost btn-xs text-error"
              data-confirm="Delete this variable?"
            >
              Delete
            </button>
          </:action>
        </.table>
      </div>
    </Layouts.app>
    """
  end
end
