(SiigoParamTable as table, filterName as text) =>
let
    Source = SiigoParamTable,
    FilterName = Table.SelectRows(Source, each ([name] = filterName)),
    GetValue = FilterName{0}[value]
in
    GetValue
