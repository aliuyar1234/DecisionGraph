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
      checks: %{
        enabled: [
          {Credo.Check.Refactor.CyclomaticComplexity,
           max_complexity: 15,
           files: %{excluded: ["apps/dg_api/lib/decision_graph/api/console.ex"]}},
          {Credo.Check.Refactor.FunctionArity, max_arity: 9},
          {Credo.Check.Refactor.Nesting,
           max_nesting: 3,
           files: %{
             excluded: [
               "apps/dg_projector/lib/decision_graph/projector/query.ex",
               "apps/dg_projector/test/decision_graph/projector/query_parity_test.exs"
             ]
           }}
        ],
        disabled: [
          {Credo.Check.Design.AliasUsage, []},
          {Credo.Check.Readability.ModuleDoc, []},
          {Credo.Check.Readability.PreferImplicitTry, []},
          {Credo.Check.Refactor.MatchInCondition, []},
          {Credo.Check.Warning.RaiseInsideRescue, []}
        ]
      }
    }
  ]
}
