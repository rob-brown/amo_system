import Config

target = System.get_env("MIX_TARGET", "host") |> String.to_atom()

config :rabbit_driver, :target, target
