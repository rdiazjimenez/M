(EndPointData as table,
 ApiConnInfo as table,
 EndPointID as text,
 optional params as text,
 optional pageNum as text,
 optional pageSize as text) =>
let
    endPointData = LibPQ("Siigo.getEndpointData")(EndPointData, EndPointID),
    siigoApiConnInfo = LibPQ("Siigo.getApiConnInfo")(ApiConnInfo),
    Source =  LibPQ("Api.getApiResult")(endPointData[endpointUrl], endPointData[Type], siigoApiConnInfo[api_headers], params, pageNum, pageSize),
    results = Source[results]
in
    results
