defmodule Agentmancer.Vault do
  import Ecto.Query
  alias Agentmancer.Repo
  alias Agentmancer.Vault.{VariableScope, Variable, RunEnvSnapshot}

  @scope_levels [:global, :project, :repository, :workflow, :run_override]

  def resolve_env(opts \\ []) do
    project_id = Keyword.get(opts, :project_id)
    repository_id = Keyword.get(opts, :repository_id)
    workflow_definition_id = Keyword.get(opts, :workflow_definition_id)
    run_id = Keyword.get(opts, :run_id)

    scope_filters =
      [
        {:global, []},
        if(project_id, do: {:project, [project_id: project_id]}),
        if(repository_id, do: {:repository, [repository_id: repository_id]}),
        if(workflow_definition_id,
          do: {:workflow, [workflow_definition_id: workflow_definition_id]}
        ),
        if(run_id, do: {:run_override, [run_id: run_id]})
      ]
      |> Enum.reject(&is_nil/1)

    Enum.reduce(scope_filters, %{}, fn {level, filters}, acc ->
      query =
        VariableScope
        |> where([s], s.level == ^level)
        |> apply_scope_filters(filters)

      case Repo.one(query) do
        nil ->
          acc

        scope ->
          variables =
            Variable
            |> where([v], v.variable_scope_id == ^scope.id)
            |> Repo.all()

          Enum.reduce(variables, acc, fn var, env ->
            Map.put(env, var.key, var.value_ciphertext)
          end)
      end
    end)
  end

  defp apply_scope_filters(query, []), do: query

  defp apply_scope_filters(query, [{:project_id, id} | rest]) do
    query |> where([s], s.project_id == ^id) |> apply_scope_filters(rest)
  end

  defp apply_scope_filters(query, [{:repository_id, id} | rest]) do
    query |> where([s], s.repository_id == ^id) |> apply_scope_filters(rest)
  end

  defp apply_scope_filters(query, [{:workflow_definition_id, id} | rest]) do
    query |> where([s], s.workflow_definition_id == ^id) |> apply_scope_filters(rest)
  end

  defp apply_scope_filters(query, [{:run_id, id} | rest]) do
    query |> where([s], s.run_id == ^id) |> apply_scope_filters(rest)
  end

  def get_or_create_scope(level, opts \\ []) when level in @scope_levels do
    attrs =
      %{level: level}
      |> maybe_put(:project_id, Keyword.get(opts, :project_id))
      |> maybe_put(:repository_id, Keyword.get(opts, :repository_id))
      |> maybe_put(:workflow_definition_id, Keyword.get(opts, :workflow_definition_id))
      |> maybe_put(:run_id, Keyword.get(opts, :run_id))

    query =
      VariableScope
      |> where([s], s.level == ^level)
      |> apply_scope_filters(
        Keyword.take(opts, [:project_id, :repository_id, :workflow_definition_id, :run_id])
      )

    case Repo.one(query) do
      nil -> %VariableScope{} |> VariableScope.changeset(attrs) |> Repo.insert()
      scope -> {:ok, scope}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  def list_variables_for_scope(scope_id) do
    Variable
    |> where([v], v.variable_scope_id == ^scope_id)
    |> order_by(:key)
    |> Repo.all()
  end

  def set_variable(scope_id, key, value, opts \\ []) do
    is_secret = Keyword.get(opts, :is_secret, false)
    description = Keyword.get(opts, :description)

    case Repo.get_by(Variable, variable_scope_id: scope_id, key: key) do
      nil ->
        %Variable{}
        |> Variable.changeset(%{
          variable_scope_id: scope_id,
          key: key,
          value_ciphertext: value,
          is_secret: is_secret,
          description: description
        })
        |> Repo.insert()

      existing ->
        existing
        |> Variable.changeset(%{
          value_ciphertext: value,
          is_secret: is_secret,
          description: description
        })
        |> Repo.update()
    end
  end

  def delete_variable(variable_id) do
    Variable |> Repo.get!(variable_id) |> Repo.delete()
  end

  def create_run_env_snapshot(run_id, env_map, scope_chain) do
    %RunEnvSnapshot{}
    |> RunEnvSnapshot.changeset(%{
      run_id: run_id,
      env_ciphertext: Jason.encode!(env_map),
      scope_chain: scope_chain
    })
    |> Repo.insert()
  end
end
