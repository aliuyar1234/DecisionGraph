%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["apps/", "config/", "mix.exs"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      plugins: [],
      requires: [],
      strict: true,
      color: true,
      checks: [
        {Credo.Check.Consistency.ExceptionNames},
        {Credo.Check.Consistency.LineEndings},
        {Credo.Check.Consistency.ParameterPatternMatching},
        {Credo.Check.Readability.AliasOrder},
        {Credo.Check.Readability.ModuleDoc, false},
        {Credo.Check.Refactor.CyclomaticComplexity, max_complexity: 9},
        {Credo.Check.Refactor.Nesting, max_nesting: 2}
      ]
    }
  ]
}
