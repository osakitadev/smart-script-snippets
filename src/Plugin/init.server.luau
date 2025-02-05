--[=[
    MIT License

    Copyright (c) isaac010901 (Osakota) 2025

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
]=]

local ScriptEditorService = game:GetService('ScriptEditorService')
local StudioService = game:GetService('StudioService')
local ServerStorage = game:GetService('ServerStorage')

local PLUGIN_VERSION = '1.1.0'
local PLUGIN_NAME = 'Smart Script Snippets ' .. PLUGIN_VERSION
local USER_SNIPPETS_MODULE = 'ProjectSnippets'
local SNIPPET_ARGUMENT_DELIMETER = '#'

local MARKER_NAME_EXPRESSION = '@%s*(.-)%s*{'
local MARKER_VALID_STRUCTURE = '^%-%-%@%s*.-%s*%b{}$'
local MARKER_GET_ARGUMENTS = '{(.-)}'
local MARKER_ARGUMENTS = '#%s*([%w_]+)%s*=%s*([^#]+)' -- I don't know how to read this, but it works
local SNIPPET_TEMPLATE_REPLACEMENT = '{{%s*(.-)%s*}}'

--[[ VARIABLES ]]
local toolbar = plugin:CreateToolbar(PLUGIN_NAME)

local createProjectSnippetsButton = toolbar:CreateButton(
    'Create Project Snippets',
    'Create a project snippets ModuleScript',
    'rbxassetid://120171915312901'
)

local triggerSnippetsButton = toolbar:CreateButton(
    'Trigger Snippets',
    'Trigger all snippets markers in the current script',
    'rbxassetid://120171915312901'
)

local refreshSnippetsButton = toolbar:CreateButton(
    'Refresh Snippets',
    'Refreshes snippets intellisense',
    'rbxassetid://120171915312901'
)

local triggerSnippetsAction = plugin:CreatePluginAction(
    PLUGIN_NAME,
    'Trigger SmartScript Snippets',
    'Replace the snippets comments with the actual code of those snippets'
)

--[[ FUNCTIONS ]]
local function getUserSnippets()
    if ServerStorage:FindFirstChild(USER_SNIPPETS_MODULE) then
        return require(ServerStorage[USER_SNIPPETS_MODULE]:Clone()) -- For some reason I have to clone the module?????????????
    end

    return {}
end

local function getSnippetTextReplacementBySnippetTable(snippet)
    local argsString = ''

    for argName, argData in pairs(snippet.Args) do
        argsString ..= SNIPPET_ARGUMENT_DELIMETER .. argName .. '=' .. argData.Default .. ' '
    end

    return '--@' .. snippet.Name .. '{' .. argsString:sub(1, #argsString - 1) .. '}' -- argsString:sub(1, #argsString - 1) to remove trailing whitespaces
end

local function refreshSnippetsAutocompleteCallbacks()
    local snippets = getUserSnippets()

    for priority, snippet in ipairs(snippets) do
        pcall(
            ScriptEditorService.DeregisterAutocompleteCallback,
            ScriptEditorService,
            snippet.Name
        )

        ScriptEditorService:RegisterAutocompleteCallback(
            snippet.Name,
            priority,
            function(request, response)
                table.insert(response.items, {
                    label = '@' .. snippet.Name,
                    preselect = true,
                    kind = Enum.CompletionItemKind.Snippet,
                    codeSample = table.concat(snippet.Body or {}, '\n'),
                    documentation = {
                        value = snippet.Description,
                    },
                    textEdit = {
                        newText = getSnippetTextReplacementBySnippetTable(snippet),
                        replace = {
                            ['start'] = {
                                line = request.position.line,
                                character = 1,
                            },
                            ['end'] = {
                                line = request.position.line,
                                character = request.position.character,
                            },
                        },
                    },
                })

                return response
            end
        )
    end
end

local function getSnippetByName(name)
    for _, snippet in ipairs(getUserSnippets()) do
        if snippet.Name == name then
            return snippet
        end
    end

    return nil
end

local function parseMarkerArguments(arguments: string)
    local map = {}

    for argName, argValue in arguments:gmatch(MARKER_ARGUMENTS) do
        map[argName] = argValue
    end

    return map
end

local function canSnippetBeReplaced(snippet, lineNumber)
    return snippet.BeforeReplace
        and type(snippet.BeforeReplace) == 'function'
        and snippet.BeforeReplace(StudioService.ActiveScript, lineNumber) == true
end

local function getSnippetMarkerReplacement(
    snippet,
    markerArgs,
    lineNumber
): ({ string }, boolean)
    markerArgs = parseMarkerArguments(markerArgs)

    local replacementStringTable = {}

    local snippetArguments = snippet.Args
    local snippetBody = snippet.Body

    if not canSnippetBeReplaced(snippet, lineNumber) then
        return {}, false
    end

    for _, lineContent in ipairs(snippetBody) do
        local currentLineReplacement = lineContent:gsub(
            SNIPPET_TEMPLATE_REPLACEMENT,
            function(match)
                if markerArgs[match] then
                    return markerArgs[match]
                end

                if snippetArguments[match] then
                    return snippetArguments[match].Default
                end

                return ''
            end
        )

        table.insert(replacementStringTable, currentLineReplacement)
    end

    return replacementStringTable, true
end

local function replaceSnippetsMarker()
    local currentDocument = StudioService.ActiveScript

    local scriptContent = currentDocument.Source:split('\n')
    local newScriptContent = {}

    for lineNumber, lineContent in ipairs(scriptContent) do
        if not lineContent:match(MARKER_VALID_STRUCTURE) then
            table.insert(newScriptContent, lineContent)
            continue
        end

        local snippetMarkerName = lineContent:match(MARKER_NAME_EXPRESSION)
        local snippetMarkerArgs = lineContent:match(MARKER_GET_ARGUMENTS)
        local snippetContent = getSnippetByName(snippetMarkerName)

        if not snippetMarkerArgs or not snippetMarkerName or not snippetContent then
            table.insert(newScriptContent, lineContent)
            continue
        end

        local replacement, didReplace =
            getSnippetMarkerReplacement(snippetContent, snippetMarkerArgs, lineNumber)

        if not didReplace then
            table.insert(newScriptContent, lineContent) -- Don't delete the snippet marker
            continue
        end

        for _, v in ipairs(replacement) do
            table.insert(newScriptContent, v)
        end

        if
            snippetContent.AfterReplace
            and type(snippetContent.AfterReplace) == 'function'
        then
            snippetContent.AfterReplace(currentDocument, lineNumber)
        end
    end

    ScriptEditorService:UpdateSourceAsync(currentDocument, function()
        return table.concat(newScriptContent, '\n')
    end)
end

-- [[ STARTUP ]]
triggerSnippetsButton.ClickableWhenViewportHidden = true
createProjectSnippetsButton.ClickableWhenViewportHidden = true

refreshSnippetsAutocompleteCallbacks()

--[[ CONNECTION BINDING ]]
triggerSnippetsAction.Triggered:Connect(function()
    replaceSnippetsMarker()
end)

triggerSnippetsButton.Click:Connect(function()
    replaceSnippetsMarker()
end)

refreshSnippetsButton.Click:Connect(function()
    refreshSnippetsAutocompleteCallbacks()
end)

createProjectSnippetsButton.Click:Connect(function()
    if ServerStorage:FindFirstChild(USER_SNIPPETS_MODULE) then
        return print('Project snippets already created.')
    end

    local projectSnippets = Instance.new('ModuleScript')
    projectSnippets.Name = USER_SNIPPETS_MODULE
    projectSnippets.Parent = ServerStorage

    projectSnippets.Source = script.Templates.ProjectSnippets.Source
end)
