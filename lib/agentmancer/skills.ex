defmodule Agentmancer.Skills do
  alias Agentmancer.Projects.Repository
  alias Agentmancer.Skills.Skill
  alias Agentmancer.Workspace.{Git, Paths}

  @skill_filename "SKILL.md"
  @metadata_filename "skill.json"
  @global_skills_path ["priv", "skills"]

  def list_global_skills do
    global_skills_root()
    |> File.ls!()
    |> Enum.sort()
    |> Enum.map(&build_global_skill/1)
    |> Enum.reject(&is_nil/1)
  end

  def fetch_global_skill(slug) when is_binary(slug) do
    case build_global_skill(slug) do
      nil -> {:error, :not_found}
      skill -> {:ok, skill}
    end
  end

  def list_seedable_global_skills do
    list_global_skills()
    |> Enum.filter(& &1.seed_default_workflow)
  end

  def list_repository_skills(%Repository{} = repo, opts \\ []) do
    ref = Keyword.get(opts, :ref, repo.default_branch || "main")

    with :ok <- Git.ensure_mirror(repo.id, repo.clone_url),
         {:ok, files} <- Git.list_files(Paths.mirror_path(repo.id), ref, "skills") do
      files
      |> repository_skill_slugs()
      |> Enum.map(&build_repository_skill(repo, ref, &1))
      |> Enum.reject(&match?({:error, _}, &1))
      |> Enum.map(fn {:ok, skill} -> skill end)
      |> Enum.sort_by(& &1.name)
    else
      _ -> []
    end
  end

  def fetch_repository_skill(%Repository{} = repo, slug, opts \\ []) when is_binary(slug) do
    ref = Keyword.get(opts, :ref, repo.default_branch || "main")

    with :ok <- Git.ensure_mirror(repo.id, repo.clone_url),
         {:ok, skill} <- build_repository_skill(repo, ref, slug) do
      {:ok, skill}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :not_found}
    end
  end

  def fetch_repository_skill_from_worktree(worktree_path, slug, repo \\ nil)
      when is_binary(slug) do
    skill_path = Path.join([worktree_path, "skills", slug, @skill_filename])

    if File.exists?(skill_path) do
      metadata_path = Path.join([worktree_path, "skills", slug, @metadata_filename])

      with {:ok, body} <- File.read(skill_path) do
        metadata = load_metadata_file(metadata_path)

        {:ok,
         build_skill(
           :repository,
           slug,
           body,
           metadata,
           skill_path,
           repo
         )}
      end
    else
      {:error, :not_found}
    end
  end

  def titleize_slug(slug) do
    slug
    |> String.split("-")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp build_global_skill(slug) do
    skill_dir = Path.join(global_skills_root(), slug)
    skill_path = Path.join(skill_dir, @skill_filename)

    if File.dir?(skill_dir) and File.exists?(skill_path) do
      body = File.read!(skill_path)
      metadata = load_metadata_file(Path.join(skill_dir, @metadata_filename))

      build_skill(:global, slug, body, metadata, skill_path, nil)
    end
  end

  defp build_repository_skill(%Repository{} = repo, ref, slug) do
    mirror_path = Paths.mirror_path(repo.id)
    skill_rel_path = Path.join(["skills", slug, @skill_filename])
    metadata_rel_path = Path.join(["skills", slug, @metadata_filename])

    with {:ok, body} <- Git.read_file(mirror_path, ref, skill_rel_path) do
      metadata =
        case Git.read_file(mirror_path, ref, metadata_rel_path) do
          {:ok, json} -> decode_metadata(json)
          {:error, _} -> %{}
        end

      {:ok,
       build_skill(
         :repository,
         slug,
         body,
         metadata,
         "#{repo.name}:#{ref}/#{skill_rel_path}",
         repo
       )}
    end
  end

  defp build_skill(source, slug, body, metadata, path, repo) do
    normalized = normalize_metadata(metadata)

    %Skill{
      source: source,
      slug: slug,
      name: normalized["name"] || titleize_slug(slug),
      description: normalized["description"],
      kind: normalized["kind"] || "custom",
      tags: normalized["tags"] || [],
      icon: normalized["icon"] || "hero-cpu-chip",
      body: body,
      path: path,
      repository_id: repo && repo.id,
      repository_name: repo && repo.name,
      output_schema: normalized["output_schema"],
      suggested_trigger: normalized["suggested_trigger"] || %{},
      seed_default_workflow: normalized["seed_default_workflow"] || false,
      metadata: normalized
    }
  end

  defp repository_skill_slugs(files) do
    files
    |> Enum.flat_map(fn path ->
      case String.split(path, "/", parts: 3) do
        ["skills", slug, file] when file in [@skill_filename, @metadata_filename] -> [slug]
        _ -> []
      end
    end)
    |> Enum.uniq()
  end

  defp global_skills_root do
    Application.app_dir(:agentmancer, @global_skills_path)
  end

  defp load_metadata_file(path) do
    if File.exists?(path) do
      path |> File.read!() |> decode_metadata()
    else
      %{}
    end
  end

  defp decode_metadata(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, metadata} when is_map(metadata) -> metadata
      _ -> %{}
    end
  end

  defp normalize_metadata(metadata) when is_map(metadata) do
    metadata
    |> Enum.into(%{}, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      pair -> pair
    end)
    |> Map.update("tags", [], fn
      tags when is_list(tags) -> tags
      _ -> []
    end)
    |> Map.update("suggested_trigger", %{}, fn
      trigger when is_map(trigger) -> trigger
      _ -> %{}
    end)
    |> Map.update("seed_default_workflow", false, &(&1 == true))
    |> Map.update("output_schema", nil, fn
      schema when is_map(schema) -> schema
      _ -> nil
    end)
  end
end
