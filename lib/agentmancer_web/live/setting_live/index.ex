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
       required_vars_status: Vault.required_variables_status(variables),
       optional_variables: Vault.optional_variables(variables),
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
  def handle_event(
        "save_required_variable",
        %{"key" => key, "value" => value, "secret" => secret},
        socket
      ) do
    {:ok, scope} = Vault.get_or_create_scope(:global)

    case Vault.set_variable(scope.id, key, value, is_secret: secret == "true") do
      {:ok, _var} ->
        {:noreply,
         socket
         |> put_flash(:info, "Variable saved.")
         |> reload_variables()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save variable.")}
    end
  end

  def handle_event("save_variable", %{"key" => key, "value" => value, "secret" => secret}, socket) do
    {:ok, scope} = Vault.get_or_create_scope(:global)

    case Vault.set_variable(scope.id, key, value, is_secret: secret == "true") do
      {:ok, _var} ->
        {:noreply,
         socket
         |> put_flash(:info, "Variable saved.")
         |> assign(var_key: "", var_value: "", var_secret: false)
         |> reload_variables()}

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
        {:noreply,
         socket
         |> put_flash(:info, "Variable deleted.")
         |> reload_variables()}

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

  defp reload_variables(socket) do
    {scope_id, variables} = load_global_variables()

    assign(socket,
      scope_id: scope_id,
      variables: variables,
      required_vars_status: Vault.required_variables_status(variables),
      optional_variables: Vault.optional_variables(variables)
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Settings
        <:subtitle>Global variables and secrets</:subtitle>
      </.header>

      <div class="mt-6 space-y-6">
        <div class="card bg-base-200">
          <div class="card-body">
            <h3 class="card-title text-sm">Required Variables</h3>
            <p class="text-sm text-base-content/60 mb-2">
              These variables are required for core functionality.
            </p>
            <div class="space-y-4">
              <div
                :for={req <- @required_vars_status}
                class="flex flex-wrap gap-3 items-end border-b border-base-300/30 pb-4 last:border-0"
              >
                <div class="flex-1 min-w-[200px]">
                  <div class="flex items-center gap-2">
                    <span class="font-mono text-sm">{req.key}</span>
                    <span :if={req.configured} class="badge badge-sm badge-success">
                      Configured
                    </span>
                    <span :if={!req.configured} class="badge badge-sm badge-error">
                      Not configured
                    </span>
                  </div>
                  <p class="text-xs text-base-content/50 mt-1">{req.description}</p>
                </div>
                <form phx-submit="save_required_variable" class="flex gap-2 items-end">
                  <input type="hidden" name="key" value={req.key} />
                  <input type="hidden" name="secret" value={to_string(req.secret)} />
                  <div class="form-control">
                    <input
                      type="password"
                      name="value"
                      required
                      class="input input-bordered w-64"
                      placeholder={if req.configured, do: "Update value...", else: "Enter value..."}
                    />
                  </div>
                  <button type="submit" class="btn btn-primary">
                    {if req.configured, do: "Update", else: "Save"}
                  </button>
                </form>
              </div>
            </div>
          </div>
        </div>

        <div class="card bg-base-200">
          <div class="card-body">
            <h3 class="card-title text-sm">Add Variable</h3>
            <p class="text-sm text-base-content/60 mb-2">
              Custom variables available to all projects and workflows.
            </p>
            <form phx-submit="save_variable" class="flex flex-wrap gap-3 items-end">
              <div class="form-control">
                <label class="label"><span class="label-text">Key</span></label>
                <input
                  type="text"
                  name="key"
                  value={@var_key}
                  required
                  class="input input-bordered w-48"
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
                  class="input input-bordered w-64"
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
                    class="checkbox"
                  />
                </label>
              </div>
              <button type="submit" class="btn btn-primary">Save Variable</button>
            </form>
          </div>
        </div>

        <div class="card bg-base-200">
          <div class="card-body">
            <h3 class="card-title text-sm">Custom Variables</h3>
            <div :if={@optional_variables == []} class="text-base-content/60 text-sm">
              No custom variables set.
            </div>
            <.table :if={@optional_variables != []} id="global-variables" rows={@optional_variables}>
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
                  class="btn btn-ghost text-error"
                  data-confirm="Delete this variable?"
                >
                  Delete
                </button>
              </:action>
            </.table>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
