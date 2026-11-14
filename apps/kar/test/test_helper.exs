private_files = ["AMIIBO_KEY_PATH", "AMIIBO_V3_DUMP_DIR"]

if Enum.all?(private_files, &System.get_env/1) do
  ExUnit.start()
else
  ExUnit.start(exclude: [:private_dumps])
end
