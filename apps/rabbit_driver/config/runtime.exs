import Config

target = System.get_env("MIX_TARGET") || System.get_env("TARGET") || "host"
target = String.to_atom(target)

config :rabbit_driver, :target, target
