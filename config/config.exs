import Config

port =case config_env() do
  :test -> 4001
  _     -> 4000
end

config :dort, :port, port
