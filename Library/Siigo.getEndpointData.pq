(EndPointData as table,
 ApiConnInfo as table,
 EndPointID as text,
 optional params as text,
 optional pageNum as text,
 optional pageSize as text) =>
let
    endPointData = LibPQ("Siigo.getEndpointData")(EndPointData, EndPointID),
    siigoApiConnInfo = LibPQ("Siigo.GetApiConnInfo")(EndPointData),
    Source = getApiResult(endPointData[endpointUrl], endPointData[Type], siigoApiConnInfo[api_headers], params, pageNum, pageSize),
    results = Source[results]
in
    results
