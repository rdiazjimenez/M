// =============================================
// Function: Siigo.getEndpointData
// Description:
//   Devuelve la fila (record) de la tabla de endpoints con el ID indicado.
// History:
//   - 2026-11-17: error explícito si el ID no existe.
//     Versión anterior en OlderVersions/Siigo.getEndpointData.20261117.pq
// =============================================

(SiigoEndpointTable as table, tableID as text) as record =>
let
    Rows   = Table.SelectRows(SiigoEndpointTable, each [ID] = tableID),
    Result = if Table.RowCount(Rows) > 0 then Rows{0}
             else error Error.Record(
                 "Siigo.getEndpointData",
                 "No existe el endpoint con ID """ & tableID & """",
                 [IDsDisponibles = Text.Combine(List.Transform(SiigoEndpointTable[ID], Text.From), ", ")]
             )
in
    Result
