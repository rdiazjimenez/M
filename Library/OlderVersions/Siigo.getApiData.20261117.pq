(EndPointData as table,
 ApiConnInfo as table,
 EndPointID as text,
 optional params as text,
 optional pageNum as text,
 optional pageSize as text) =>
let
    endPointData = LibPQ("Siigo.getEndpointData")(EndPointData, EndPointID),
    apiHeaders = LibPQ("Siigo.getApiConnInfo")(ApiConnInfo),
    Source =  LibPQ("Api.getApiResult")(endPointData[endpointUrl], endPointData[Type], apiHeaders, params, pageNum, pageSize)
in
    Source
