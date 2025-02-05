--[[
    Current project's snippets.


    DOCUMENTATION:
        Syntax to execute a snippet: --@<snippet_name>{ <snippet_params> }
                            Example: --@Loop { num=5 }

        SNIPPET STRUCTURE
            - Name: Trigger word                                (string)

            - Body: Body of the snippet                         (table<string>)

            - Description: Description of the snippet           (string)

            - BeforeReplace: Function to execute
                             before replacing the
                             snippet markers with code          (function(Script, LineNumber) -> boolean) <optional>

            - AfterReplace: Function to execute
                             after  replacing the
                             snippet markers with code          (function(Script, LineNumber)) <optional>

            - Args: Arguments of the snippet                    (table)
                Default: Default value of the argument          (any)

    Example Snippet:

    ```lua
    {
        Name = "Loop",
        Body = {
            "for i = 0, {{Num}}, 1 do",
            "\t-- Code here",
            "end",
        },
        Description = "Makes a loop",
        Args = {
            ["Num"] = {
                Default = 10,
            },
        },
    }
    ```
]]

return {
    -- Snippets
}
