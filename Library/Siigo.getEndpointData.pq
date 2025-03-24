(tableID as text) =>
let
    Source = SiigoEndpoint,
    Result = Table.SelectRows(Source, each ([ID] = tableID)){0}
in
    Result