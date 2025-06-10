import Config

config :logger, :console,
  format: {Loomex.Logger, :log},
  metadata: [:module, :function, :application, :pid, :subfunc, :socket, :socket_ref, :reason]

import_config "#{config_env()}.exs"