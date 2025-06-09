(SiigoEndpointTable as table, tableID as text) =>
let
    Result = Table.SelectRows(SiigoEndpointTable, each ([ID] = tableID)){0}
in
    Result
