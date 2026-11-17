// =============================================
// Function: Siigo.getFV
// Description:
//   Descarga todos los registros del endpoint "FV" entre dos fechas.
// Parameters:
//   - fechaInicio, fechaFin (date)
//   - EndpointData (table): tabla de endpoints
//   - ApiConnInfo (table | record): tabla de parámetros o headers ya construidos
// Returns:
//   - Tabla con una columna "results" (un record por registro).
// History:
//   - 2026-11-17: usa Siigo.getAllPages (un solo token, sin pedir dos veces la página 1).
//     Versión anterior en OlderVersions/Siigo.getFV.20261117.pq
// =============================================

(fechaInicio as date,
 fechaFin as date,
 EndpointData as table,
 ApiConnInfo as any) =>
let
    endpointID = "FV",
    getParams = "date_start=" & Date.ToText(fechaInicio, "yyyy-MM-dd") & "&date_end=" & Date.ToText(Date.AddDays(fechaFin, 1), "yyyy-MM-dd"),
    Result = LibPQ("Siigo.getAllPages")(EndpointData, ApiConnInfo, endpointID, getParams, "100")
in
    Result
