defmodule Agentmancer.Vault.EncryptedBinary do
  use Cloak.Ecto.Binary, vault: Agentmancer.Vault.Cipher
end
