__DIR__
|> Path.join("../test_support/**/*.exs")
|> Path.expand()
|> Path.wildcard()
|> Enum.sort()
|> Enum.each(&Code.require_file/1)

ExUnit.start()
