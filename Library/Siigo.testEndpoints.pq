// =============================================
// Function: Siigo.testEndpoints
// Description:
//   Prueba de conexión: pide un token y llama la página 1 (page_size 1) de cada
//   endpoint GET de la tabla de endpoints. No descarga datos completos.
// Parameters:
//   - EndpointData (table): tabla de endpoints (Name, ID, endpointUrl, Type)
//   - ApiConnInfo (table | record): tabla de parámetros o headers ya construidos
// Returns:
//   - Tabla de endpoints + Estado ("OK" o el mensaje de error de Siigo) y
//     Total (total_results, o número de elementos si la respuesta es una lista).
// Usage:
//   = LibPQ("Siigo.testEndpoints")(SiigoEndpoint, TablaSIIGOParam)
// Notes:
//   - document-types (ID "TCC") exige el parámetro type; se prueba con type=FV.
//   - Los endpoints POST (p. ej. BPT) no se prueban: generan un reporte.
// History:
//   - 2026-11-17: creada.
// =============================================

(EndpointData as table, ApiConnInfo as any) as table =>
let
    apiHeaders = if ApiConnInfo is record
                 then ApiConnInfo
                 else LibPQ("Siigo.getApiConnInfo")(ApiConnInfo),
    extraParams = [TCC = "type=FV"],

    gets   = Table.SelectRows(EndpointData, each Text.Upper([Type]) = "GET"),
    tested = Table.AddColumn(gets, "R", each try LibPQ("Siigo.getApiData")(
                 EndpointData, apiHeaders, [ID],
                 Record.FieldOrDefault(extraParams, [ID], null), "1", "1")),
    estado = Table.AddColumn(tested, "Estado", each
                 if [R][HasError] then "ERROR: " & [R][Error][Message] else "OK", type text),
    total  = Table.AddColumn(estado, "Total", each
                 if [R][HasError] then null
                 else try [R][Value][pagination][total_results]
                 otherwise try List.Count([R][Value]) otherwise null, Int64.Type)
in
    Table.RemoveColumns(total, {"R"})
