%{
  configs: [
    %{
      name: "default",
      files: %{
        included: [
          "lib/",
          "test/"
        ],
        excluded: [
          ~r"/_build/",
          ~r"/deps/"
        ]
      },
      strict: false,
      checks: %{
        disabled: [
          {Credo.Check.Readability.ModuleDoc, false},
          {Credo.Check.Readability.PredicateFunctionNames, false},
          {Credo.Check.Readability.Specs, false},
          {Credo.Check.Refactor.CondStatements, false},
          {Credo.Check.Refactor.CyclomaticComplexity, false},
          {Credo.Check.Refactor.MapJoin, false},
          {Credo.Check.Refactor.Nesting, false}
        ]
      }
    }
  ]
}
