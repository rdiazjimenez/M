(SiigoAPIResult as any) =>
let
    Source = SiigoAPIResult,
    file_url = try Excel.Workbook(AzureStorage.BlobContents(Source[file_url]), null, true) otherwise "Error getting file from URL"
    
in
    file_url