// =============================================
// Function: Siigo.getApiData
// Description:
//   Llama un endpoint de Siigo identificado por su ID en la tabla de endpoints.
// Parameters:
//   - EndPointData (table): tabla de endpoints (Name, ID, endpointUrl, Type)
//   - ApiConnInfo (table | record):
//       * table  → tabla de parámetros Name/Value; se pide un token nuevo
//       * record → headers ya construidos con Siigo.getApiConnInfo (recomendado
//                  cuando se hacen varias llamadas: un solo token)
//   - EndPointID (text): ID del endpoint, p. ej. "FV", "Producto", "BPT"
//   - params, pageNum, pageSize: ver Api.getApiResult
// Returns:
//   - El JSON de la respuesta.
// History:
//   - 2026-11-17: ApiConnInfo acepta también un record de headers.
//     Versión anterior en OlderVersions/Siigo.getApiData.20261117.pq
// =============================================

(EndPointData as table,
 ApiConnInfo as any,
 EndPointID as text,
 optional params as nullable text,
 optional pageNum as nullable text,
 optional pageSize as nullable text) =>
let
    endPointData = LibPQ("Siigo.getEndpointData")(EndPointData, EndPointID),
    apiHeaders   = if ApiConnInfo is record
                   then ApiConnInfo
                   else LibPQ("Siigo.getApiConnInfo")(ApiConnInfo),
    Source = LibPQ("Api.getApiResult")(
                 endPointData[endpointUrl], endPointData[Type], apiHeaders,
                 params, pageNum, pageSize)
in
    Source
