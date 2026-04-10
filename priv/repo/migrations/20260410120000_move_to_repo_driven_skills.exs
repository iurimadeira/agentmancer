defmodule Agentmancer.Repo.Migrations.MoveToRepoDrivenSkills do
  use Ecto.Migration

  def up do
    alter table(:projects) do
      add :default_runtime_profile_id,
          references(:runtime_profiles, type: :binary_id, on_delete: :nilify_all)
    end

    alter table(:workflow_definitions) do
      add :runtime_profile_id,
          references(:runtime_profiles, type: :binary_id, on_delete: :nilify_all)
    end

    alter table(:workflow_bindings) do
      add :skill_source, :string
      add :skill_slug, :string
    end

    execute("""
    UPDATE workflow_bindings AS wb
    SET skill_source = 'global',
        skill_slug = COALESCE(NULLIF(ad.template_slug, ''), ad.slug)
    FROM agent_definitions AS ad
    WHERE wb.agent_definition_id = ad.id
    """)

    execute("""
    UPDATE workflow_definitions AS wd
    SET runtime_profile_id = binding_profile.runtime_profile_id
    FROM (
      SELECT DISTINCT ON (wb.workflow_definition_id)
        wb.workflow_definition_id,
        ad.runtime_profile_id
      FROM workflow_bindings AS wb
      JOIN agent_definitions AS ad ON ad.id = wb.agent_definition_id
      WHERE ad.runtime_profile_id IS NOT NULL
      ORDER BY wb.workflow_definition_id, wb.position NULLS LAST, wb.inserted_at
    ) AS binding_profile
    WHERE wd.id = binding_profile.workflow_definition_id
      AND wd.runtime_profile_id IS NULL
    """)

    execute("""
    UPDATE projects AS p
    SET default_runtime_profile_id = (
      SELECT rp.id
      FROM runtime_profiles AS rp
      WHERE rp.project_id = p.id
      ORDER BY CASE WHEN rp.name = 'claude-default' THEN 0 ELSE 1 END, rp.inserted_at
      LIMIT 1
    )
    WHERE p.default_runtime_profile_id IS NULL
    """)

    alter table(:runs) do
      add :skill_source, :string
      add :skill_slug, :string
      add :skill_name, :string
      add :skill_body, :text
      add :skill_metadata, :map, default: %{}, null: false
    end

    execute("""
    UPDATE runs AS r
    SET skill_source = 'global',
        skill_slug = COALESCE(NULLIF(ad.template_slug, ''), ad.slug),
        skill_name = ad.name,
        skill_body = (
          SELECT av.system_prompt
          FROM agent_versions AS av
          WHERE av.id = r.agent_version_id
        ),
        skill_metadata = jsonb_strip_nulls(
          jsonb_build_object(
            'description', ad.description,
            'kind', ad.kind,
            'category', ad.category,
            'template_slug', ad.template_slug,
            'output_schema', (
              SELECT av.output_schema
              FROM agent_versions AS av
              WHERE av.id = r.agent_version_id
            )
          )
        )
    FROM agent_definitions AS ad
    WHERE r.agent_definition_id = ad.id
    """)

    alter table(:workflow_bindings) do
      modify :skill_source, :string, null: false
      modify :skill_slug, :string, null: false
    end

    alter table(:runs) do
      modify :skill_source, :string, null: false
      modify :skill_slug, :string, null: false
    end

    drop_if_exists index(:workflow_bindings, [
                     :workflow_definition_id,
                     :agent_definition_id,
                     :repository_id
                   ])

    create unique_index(:workflow_bindings, [
             :workflow_definition_id,
             :skill_source,
             :skill_slug,
             :repository_id
           ])

    alter table(:workflow_bindings) do
      remove :agent_definition_id
    end

    alter table(:runs) do
      remove :agent_definition_id
      remove :agent_version_id
    end

    execute("DROP TABLE IF EXISTS agent_tool_bindings CASCADE")
    execute("DROP TABLE IF EXISTS catalog_entries CASCADE")
    execute("DROP TABLE IF EXISTS mcp_servers CASCADE")
    execute("DROP TABLE IF EXISTS agent_versions CASCADE")
    execute("DROP TABLE IF EXISTS agent_definitions CASCADE")
  end

  def down do
    raise "This migration is irreversible"
  end
end
