let
    // Define the URL to load the code from
    SourceUrl = "https://example.com/m-code",

    // Fetch the content from the URL
    WebContent = Web.Contents(SourceUrl),

    // Convert the content to text
    CodeText = Text.FromBinary(WebContent),

    // Evaluate the M code dynamically
    EvaluatedCode = Expression.Evaluate(CodeText, #shared)
in
    EvaluatedCode