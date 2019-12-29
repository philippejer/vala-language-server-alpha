namespace Vls
{
  public enum ErrorCodes
  {
    // Defined by JSON RPC
    ParseError = -32700,
    InvalidRequest = -32600,
    MethodNotFound = -32601,
    InvalidParams = -32602,
    InternalError = -32603,
    ServerErrorStart = -32099,
    ServerErrorEnd = -32000,
    ServerNotInitialized = -32002,
    UnknownErrorCode = -32001,

    // Defined by the protocol.
    RequestCancelled = -32800,
    ContentModified = -32801,
  }

  public class InitializeParams : AbstractJsonSerializableObject
  {
    /**
     * The process Id of the parent process that started
     * the server. Is null if the process has not been started by another process.
     * If the parent process is not alive then the server should exit (see exit notification) its process.
     */
    //  int processId;

    /**
     * The rootPath of the workspace. Is null
     * if no folder is open.
     *
     * @deprecated in favour of rootUri.
     */
    //  string rootPath;

    /**
     * The rootUri of the workspace. Is null if no
     * folder is open. If both `rootPath` and `rootUri` are set
     * `rootUri` wins.
     */
    public string rootUri { get; set; }

    /**
     * User provided initialization options.
     */
    public ServerConfig? initializationOptions { get; set; }

    /**
     * The capabilities provided by the client (editor or tool)
     */
    //  capabilities: ClientCapabilities;

    /**
     * The initial trace setting. If omitted trace is disabled ('off').
     */
    //  trace?: 'off' | 'messages' | 'verbose';

    /**
     * The workspace folders configured in the client when the server starts.
     * This property is only available if the client supports workspace folders.
     * It can be `null` if the client supports workspace folders but none are
     * configured.
     *
     * Since 3.6.0
     */
    //  workspaceFolders?: WorkspaceFolder[] | null;
  }

  public class InitializeResult : AbstractJsonSerializableObject
  {
    /**
     * The capabilities the language server provides.
     */
    public ServerCapabilities capabilities { get; set; }
  }

  public class ServerCapabilities : AbstractJsonSerializableObject
  {
    /**
     * Defines how text documents are synced. Is either a detailed structure defining each notification or
     * for backwards compatibility the TextDocumentSyncKind number. If omitted it defaults to `TextDocumentSyncKind.None`.
     */
    public TextDocumentSyncOptions textDocumentSync { get; set; }
    /**
     * The server provides hover support.
     */
    public bool hoverProvider { get; set; }
    /**
     * The server provides completion support.
     */
    public CompletionOptions completionProvider { get; set; }
    /**
     * The server provides signature help support.
     */
    public SignatureHelpOptions signatureHelpProvider  { get; set; }
    /**
     * The server provides goto definition support.
     */
    public bool definitionProvider { get; set; }
    /**
     * The server provides Goto Type Definition support.
     *
     * Since 3.6.0
     */
    //  typeDefinitionProvider : boolean | (TextDocumentRegistrationOptions & StaticRegistrationOptions);
    /**
     * The server provides Goto Implementation support.
     *
     * Since 3.6.0
     */
    //  implementationProvider : boolean | (TextDocumentRegistrationOptions & StaticRegistrationOptions);
    /**
     * The server provides find references support.
     */
    public bool referencesProvider { get; set; }
    /**
     * The server provides document highlight support.
     */
    //  documentHighlightProvider : boolean;
    /**
     * The server provides document symbol support.
     */
    public bool documentSymbolProvider { get; set; }
    /**
     * The server provides workspace symbol support.
     */
    //  workspaceSymbolProvider : boolean;
    /**
     * The server provides code actions. The `CodeActionOptions` return type is only
     * valid if the client signals code action literal support via the property
     * `textDocument.codeAction.codeActionLiteralSupport`.
     */
    public CodeActionOptions codeActionProvider { get; set; }
    /**
     * The server provides code lens.
     */
    public CodeLensOptions codeLensProvider { get; set; }
    /**
     * The server provides document formatting.
     */
    //  documentFormattingProvider : boolean;
    /**
     * The server provides document range formatting.
     */
    //  documentRangeFormattingProvider : boolean;
    /**
     * The server provides document formatting on typing.
     */
    //  documentOnTypeFormattingProvider : DocumentOnTypeFormattingOptions;
    /**
     * The server provides rename support. RenameOptions may only be
     * specified if the client states that it supports
     * `prepareSupport` in its initial `initialize` request.
     */
    public RenameOptions renameProvider { get; set; }
    /**
     * The server provides document link support.
     */
    //  documentLinkProvider : DocumentLinkOptions;
    /**
     * The server provides color provider support.
     *
     * Since 3.6.0
     */
    //  colorProvider : boolean | ColorProviderOptions | (ColorProviderOptions & TextDocumentRegistrationOptions & StaticRegistrationOptions);
    /**
     * The server provides folding provider support.
     *
     * Since 3.10.0
     */
    //  foldingRangeProvider : boolean | FoldingRangeProviderOptions | (FoldingRangeProviderOptions & TextDocumentRegistrationOptions & StaticRegistrationOptions);
    /**
     * The server provides go to declaration support.
     *
     * Since 3.14.0
     */
    //  declarationProvider : boolean | (TextDocumentRegistrationOptions & StaticRegistrationOptions);
    /**
     * The server provides execute command support.
     */
    //  executeCommandProvider : ExecuteCommandOptions;
    /**
     * Workspace specific server capabilities
     */
    //  workspace : {
    //    /**
    //     * The server supports workspace folder.
    //     *
    //     * Since 3.6.0
    //     */
    //    workspaceFolders : {
    //      /**
    //       * The server has support for workspace folders
    //       */
    //      supported : boolean;
    //      /**
    //       * Whether the server wants to receive workspace folder
    //       * change notifications.
    //       *
    //       * If a strings is provided the string is treated as a ID
    //       * under which the notification is registered on the client
    //       * side. The ID can be used to unregister for these events
    //       * using the `client/unregisterCapability` request.
    //       */
    //      changeNotifications : string | boolean;
    //    }
    //  }
    /**
     * Experimental server capabilities.
     */
    //  experimental : any;
  }

  /**
   * Signature help options.
   */
  public class SignatureHelpOptions : AbstractJsonSerializableObject
  {
    /**
     * The characters that trigger signature help
     * automatically.
     */
    public JsonSerializableCollection<string> triggerCharacters { get; set; }
  }

  /**
   * Rename options
   */
  public class RenameOptions : AbstractJsonSerializableObject
  {
    /**
     * Renames should be checked and tested before being executed.
     */
    public bool prepareProvider { get; set; }
  }

  /**
   * Code Action options.
   */
  public class CodeActionOptions : AbstractJsonSerializableObject
  {
    /**
     * CodeActionKinds that this server may return.
     *
     * The list of kinds may be generic, such as `CodeActionKind.Refactor`, or the server
     * may list out every specific kind they provide.
     */
    public JsonSerializableCollection<CodeActionKind> codeActionKinds { get; set; }

    protected override JsonSerializableCollection? create_collection(string property_name)
    {
      switch (property_name)
      {
      case "codeActionKinds":
        return new JsonArrayList<CodeActionKind>();
      }
      return base.create_collection(property_name);
    }
  }

  public class TextDocumentRegistrationOptions : AbstractJsonSerializableObject
  {
    /**
     * A document selector to identify the scope of the registration. If set to null
     * the document selector provided on the client side will be used.
     */
    public JsonSerializableCollection<DocumentFilter> documentSelector { get; set; }
  }

  public class DocumentFilter : AbstractJsonSerializableObject
  {
    /**
     * A language id, like `typescript`.
     */
    public string language { get; set; }

    /**
     * A Uri [scheme](#Uri.scheme), like `file` or `untitled`.
     */
    public string scheme { get; set; }

    /**
     * A glob pattern, like `*.{ts,js}`.
     *
     * Glob patterns can have the following syntax:
     * - `*` to match one or more characters in a path segment
     * - `?` to match on one character in a path segment
     * - `**` to match any number of path segments, including none
     * - `{}` to group conditions (e.g. `**​/*.{ts,js}` matches all TypeScript and JavaScript files)
     * - `[]` to declare a range of characters to match in a path segment (e.g., `example.[0-9]` to match on `example.0`, `example.1`, …)
     * - `[!...]` to negate a range of characters to match in a path segment (e.g., `example.[!0-9]` to match on `example.a`, `example.b`, but not `example.0`)
     */
    public string pattern { get; set; }
  }

  public class CodeLensRegistrationOptions : TextDocumentRegistrationOptions
  {
    /**
     * Code lens has a resolve provider as well.
     */
    public bool resolveProvider { get; set; }
  }

  public class CodeLensOptions : TextDocumentRegistrationOptions
  {
    /**
     * Code lens has a resolve provider as well.
     */
    public bool resolveProvider { get; set; }
  }

  public class DidOpenTextDocumentParams : AbstractJsonSerializableObject
  {
    /**
     * The document that was opened.
     */
    public TextDocumentItem textDocument { get; set; }
  }

  public class TextDocumentItem : AbstractJsonSerializableObject
  {
    /**
     * The text document's URI.
     */
    public string uri { get; set; }

    /**
     * The text document's language identifier.
     */
    public string languageId { get; set; }

    /**
     * The version number of this document (it will increase after each
     * change, including undo/redo).
     */
    public int version { get; set; }

    /**
     * The content of the opened text document.
     */
    public string text { get; set; }
  }

  public class DidCloseTextDocumentParams : AbstractJsonSerializableObject
  {
    /**
     * The document that was closed.
     */
    public TextDocumentIdentifier textDocument { get; set; }
  }

  public class DidChangeTextDocumentParams : AbstractJsonSerializableObject
  {
    /**
     * The document that did change. The version number points
     * to the version after all provided content changes have
     * been applied.
     */
    public VersionedTextDocumentIdentifier textDocument { get; set; }

    /**
     * The actual content changes. The content changes describe single state changes
     * to the document. So if there are two content changes c1 and c2 for a document
     * in state S then c1 move the document to S' and c2 to S''.
     */
    public JsonSerializableCollection<TextDocumentContentChangeEvent> contentChanges { get; set; }

    protected override JsonSerializableCollection? create_collection(string property_name)
    {
      switch (property_name)
      {
      case "contentChanges":
        return new JsonArrayList<TextDocumentContentChangeEvent>();
      }
      return base.create_collection(property_name);
    }
  }

  /**
   * An event describing a change to a text document. If range and rangeLength are omitted
   * the new text is considered to be the full content of the document.
   */
  public class TextDocumentContentChangeEvent : AbstractJsonSerializableObject
  {
    /**
     * The range of the document that changed.
     */
    public Range? range { get; set; }

    /**
     * The length of the range that got replaced.
     */
    public int rangeLength { get; set; }

    /**
     * The new text of the range/document.
     */
    public string text { get; set; }
  }

  public class Range : AbstractJsonSerializableObject
  {
    /**
     * The range's start position.
     */
    public Position start { get; set; }

    /**
     * The range's end position.
     */
    public Position end { get; set; }
  }

  public class Position : AbstractJsonSerializableObject
  {
    /**
     * Line position in a document (zero-based).
     */
    public uint line { get; set; default = -1; }

    /**
     * Character offset on a line in a document (zero-based). Assuming that the line is
     * represented as a string, the `character` value represents the gap between the
     * `character` and `character + 1`.
     *
     * If the character value is greater than the line length it defaults back to the
     * line length.
     */
    public uint character { get; set; default = -1; }
  }

  public class TextDocumentPositionParams : AbstractJsonSerializableObject
  {
    /**
     * The text document.
     */
    public TextDocumentIdentifier textDocument { get; set; }
    /**
     * The position inside the text document.
     */
    public Position position { get; set; }
  }

  public class TextDocumentIdentifier : AbstractJsonSerializableObject
  {
    /**
     * The text document's URI.
     */
    public string uri { get; set; }
  }

  public class VersionedTextDocumentIdentifier : TextDocumentIdentifier
  {
    /**
     * The version number of this document. If a versioned text document identifier
     * is sent from the server to the client and the file is not open in the editor
     * (the server has not received an open notification before) the server can send
     * `null` to indicate that the version is known and the content on disk is the
     * truth (as speced with document content ownership).
     *
     * The version number of a document will increase after each change, including
     * undo/redo. The number doesn't need to be consecutive.
     */
    public int version { get; set; default = -1; }
  }

  public class Location : AbstractJsonSerializableObject
  {
    public string uri { get; set; }
    public Range range { get; set; }
  }

  public class RenameParams : AbstractJsonSerializableObject
  {
    /**
     * The document to rename.
     */
    public TextDocumentIdentifier textDocument { get; set; }

    /**
     * The position at which this request was sent.
     */
    public Position position { get; set; }

    /**
     * The new name of the symbol. If the given name is not valid the
     * request must return a [ResponseError](#ResponseError) with an
     * appropriate message set.
     */
    public string newName { get; set; }
  }

  public class WorkspaceEdit : AbstractJsonSerializableObject
  {
    /**
     * Holds changes to existing resources.
     */
    public JsonSerializableMap<JsonSerializableCollection<TextEdit>> changes { get; set; }
  }

  /**
   * Defines how the host (editor) should sync document changes to the language server.
   */
  public enum TextDocumentSyncKind
  {
    Unset = -1,
    /**
     * Documents should not be synced at all.
     */
    None = 0,
    /**
     * Documents are synced by always sending the full content of the document.
     */
    Full = 1,
    /**
     * Documents are synced by sending the full content on open. After that only incremental
     * updates to the document are sent.
     */
    Incremental = 2
  }

  public class SaveOptions : AbstractJsonSerializableObject
  {
    /**
     * The client is supposed to include the content on save.
     */
    public bool includeText { get; set; }
  }

  public class TextDocumentSyncOptions : AbstractJsonSerializableObject
  {
    /**
     * Open and close notifications are sent to the server. If omitted open close notification should not
     * be sent.
     */
    public bool openClose { get; set; }
    /**
     * Change notifications are sent to the server. See TextDocumentSyncKind.None, TextDocumentSyncKind.Full
     * and TextDocumentSyncKind.Incremental. If omitted it defaults to TextDocumentSyncKind.None.
     */
    public TextDocumentSyncKind change { get; set; default = TextDocumentSyncKind.Unset; }
    /**
     * If present will save notifications are sent to the server. If omitted the notification should not be
     * sent.
     */
    public bool willSave { get; set; }
    /**
     * If present will save wait until requests are sent to the server. If omitted the request should not be
     * sent.
     */
    public bool willSaveWaitUntil { get; set; }
    /**
     * If present save notifications are sent to the server. If omitted the notification should not be
     * sent.
     */
    public SaveOptions save { get; set; }
  }

  /**
   * Completion options.
   */
  public class CompletionOptions : AbstractJsonSerializableObject
  {
    /**
     * The server provides support to resolve additional
     * information for a completion item.
     */
    public bool resolveProvider { get; set; }

    /**
     * The characters that trigger completion automatically.
     */
    public JsonSerializableCollection<string> triggerCharacters { get; set; }
  }

  public class PublishDiagnosticsParams : AbstractJsonSerializableObject
  {
    /**
     * The URI for which diagnostic information is reported.
     */
    public string uri { get; set; }

    /**
     * An array of diagnostic information items.
     */
    public JsonSerializableCollection<Diagnostic> diagnostics { get; set; }
  }

  public class Diagnostic : AbstractJsonSerializableObject
  {
    /**
     * The range at which the message applies.
     */
    public Range range { get; set; }

    /**
     * The diagnostic's severity. Can be omitted. If omitted it is up to the
     * client to interpret diagnostics as error, warning, info or hint.
     */
    public DiagnosticSeverity severity { get; set; default = DiagnosticSeverity.Unset; }

    /**
     * The diagnostic's code. Can be omitted.
     */
    public string code { get; set; }

    /**
     * A human-readable string describing the source of this
     * diagnostic, e.g. 'typescript' or 'super lint'.
     */
    public string source { get; set; }

    /**
     * The diagnostic's message.
     */
    public string message { get; set; }
  }

  public enum DiagnosticSeverity
  {
    Unset = -1,

    /**
     * Reports an error.
     */
    Error = 1,
    /**
     * Reports a warning.
     */
    Warning = 2,
    /**
     * Reports an information.
     */
    Information = 3,
    /**
     * Reports a hint.
     */
    Hint = 4
  }

  /**
   * The result of a hover request.
   */
  public class Hover : AbstractJsonSerializableObject
  {
    /**
     * The hover's content
     */
    public MarkupContent contents { get; set; }
    /**
     * An optional range is a range inside a text document
     * that is used to visualize a hover, e.g. by changing the background color.
     */
    public Range range { get; set; }
  }

  /**
   * A `MarkupContent` literal represents a string value which content is interpreted base on its
   * kind flag. Currently the protocol supports `plaintext` and `markdown` as markup kinds.
   *
   * If the kind is `markdown` then the value can contain fenced code blocks like in GitHub issues.
   * See https://help.github.com/articles/creating-and-highlighting-code-blocks/#syntax-highlighting
   *
   * Here is an example how such a string can be constructed using JavaScript / TypeScript:
   * ```typescript
   * let markdown: MarkdownContent = {
   *  kind: MarkupKind.Markdown,
   *	value: [
   *		'# Header',
   *		'Some text',
   *		'```typescript',
   *		'someCode();',
   *		'```'
   *	].join('\n')
   * };
   * ```
   *
   * *Please Note* that clients might sanitize the return markdown. A client could decide to
   * remove HTML from the markdown to avoid script execution.
   */
  public class MarkupContent : AbstractJsonSerializableObject
  {
    public const string KIND_PLAIN_TEXT = "plaintext";
    public const string KIND_MARKDOWN = "markdown";

    public string kind { get; set; }
    public string value { get; set; }
  }

  public class CompletionParams : TextDocumentPositionParams
  {
    /**
     * The completion context. This is only available if the client specifies
     * to send this using `ClientCapabilities.textDocument.completion.contextSupport === true`
     */
    public CompletionContext context { get; set; }
  }

  public class CompletionContext : AbstractJsonSerializableObject
  {
    /**
     * How the completion was triggered.
     */
    public CompletionTriggerKind triggerKind { get; set; default = CompletionTriggerKind.Unset; }
    /**
     * The trigger character (a single character) that has trigger code complete.
     * Is undefined if `triggerKind !== CompletionTriggerKind.TriggerCharacter`
     */
    public string triggerCharacter { get; set; }
  }

  public enum CompletionTriggerKind
  {
    Unset = -1,
    /**
     * Completion was triggered by typing an identifier (24x7 code
     * complete), manual invocation (e.g Ctrl+Space) or via API.
     */
    Invoked = 1,
    /**
     * Completion was triggered by a trigger character specified by
     * the `triggerCharacters` properties of the `CompletionRegistrationOptions`.
     */
    TriggerCharacter = 2,
    /**
     * Completion was re-triggered as the current completion list is incomplete.
     */
    TriggerForIncompleteCompletions = 3
  }

  /**
   * Represents a collection of [completion items](#CompletionItem) to be presented
   * in the editor.
   */
  public class CompletionList : AbstractJsonSerializableObject
  {
    /**
     * This list is not complete. Further typing should result in recomputing
     * this list.
     */
    public bool isIncomplete { get; set; }
    /**
     * The completion items.
     */
    public JsonSerializableCollection<CompletionItem> items { get; set; }
  }

  public class CompletionItem : AbstractJsonSerializableObject
  {
    /**
     * The label of this completion item. By default
     * also the text that is inserted when selecting
     * this completion.
     */
    public string label { get; set; }
    /**
     * The kind of this completion item. Based of the kind
     * an icon is chosen by the editor. The standardized set
     * of available values is defined in `CompletionItemKind`.
     */
    public CompletionItemKind kind { get; set; default = CompletionItemKind.Unset; }

    /**
     * A human-readable string with additional information
     * about this item, like type or symbol information.
     */
    public string detail { get; set; }

    /**
     * A human-readable string that represents a doc-comment.
     */
    public MarkupContent documentation { get; set; }

    /**
     * Indicates if this item is deprecated.
     */
    public bool deprecated { get; set; }

    /**
     * Select this item when showing.
     *
     * *Note* that only one completion item can be selected and that the
     * tool / client decides which item that is. The rule is that the *first*
     * item of those that match best is selected.
     */
    public bool preselect { get; set; }

    /**
     * A string that should be used when comparing this item
     * with other items. When `falsy` the label is used.
     */
    public string sortText { get; set; }

    /**
     * A string that should be used when filtering a set of
     * completion items. When `falsy` the label is used.
     */
    public string filterText { get; set; }

    /**
     * A string that should be inserted into a document when selecting
     * this completion. When `falsy` the label is used.
     *
     * The `insertText` is subject to interpretation by the client side.
     * Some tools might not take the string literally. For example
     * VS Code when code complete is requested in this example `con<cursor position>`
     * and a completion item with an `insertText` of `console` is provided it
     * will only insert `sole`. Therefore it is recommended to use `textEdit` instead
     * since it avoids additional client side interpretation.
     */
    public string insertText { get; set; }

    /**
     * The format of the insert text. The format applies to both the `insertText` property
     * and the `newText` property of a provided `textEdit`.
     */
    public InsertTextFormat insertTextFormat { get; set; default = InsertTextFormat.Unset; }

    /**
     * An edit which is applied to a document when selecting this completion. When an edit is provided the value of
     * `insertText` is ignored.
     *
     * *Note:* The range of the edit must be a single line range and it must contain the position at which completion
     * has been requested.
     */
    public TextEdit textEdit { get; set; }

    /**
     * An optional array of additional text edits that are applied when
     * selecting this completion. Edits must not overlap (including the same insert position)
     * with the main edit nor with themselves.
     *
     * Additional text edits should be used to change text unrelated to the current cursor position
     * (for example adding an import statement at the top of the file if the completion item will
     * insert an unqualified type).
     */
    public JsonSerializableCollection<TextEdit> additionalTextEdits { get; set; }

    /**
     * An optional set of characters that when pressed while this completion is active will accept it first and
     * then type that character. *Note* that all commit characters should have `length=1` and that superfluous
     * characters will be ignored.
     */
    public JsonSerializableCollection<string> commitCharacters { get; set; }

    /**
     * An optional command that is executed *after* inserting this completion. *Note* that
     * additional modifications to the current document should be described with the
     * additionalTextEdits-property.
     */
    public Command command { get; set; }
  }

  /**
   * The kind of a completion entry.
   */
  public enum CompletionItemKind
  {
    Unset = -1,
    Text = 1,
    Method = 2,
    Function = 3,
    Constructor = 4,
    Field = 5,
    Variable = 6,
    Class = 7,
    Interface = 8,
    Module = 9,
    Property = 10,
    Unit = 11,
    Value = 12,
    Enum = 13,
    Keyword = 14,
    Snippet = 15,
    Color = 16,
    File = 17,
    Reference = 18,
    Folder = 19,
    EnumMember = 20,
    Constant = 21,
    Struct = 22,
    Event = 23,
    Operator = 24,
    TypeParameter = 25
  }

  public class DocumentSymbolParams : AbstractJsonSerializableObject
  {
    /**
     * The text document.
     */
    public TextDocumentIdentifier textDocument { get; set; }
  }

  /**
   * Represents programming constructs like variables, classes, interfaces etc. that appear in a document. Document symbols can be
   * hierarchical and they have two ranges: one that encloses its definition and one that points to its most interesting range,
   * e.g. the range of an identifier.
   */
  public class DocumentSymbol : AbstractJsonSerializableObject
  {
    /**
     * The name of this symbol. Will be displayed in the user interface and therefore must not be
     * an empty string or a string only consisting of white spaces.
     */
    public string? name { get; set; }

    /**
     * More detail for this symbol, e.g the signature of a function.
     */
    public string? detail { get; set; }

    /**
     * The kind of this symbol.
     */
    public SymbolKind kind { get; set; default = SymbolKind.Unset; }

    /**
     * Indicates if this symbol is deprecated.
     */
    public bool deprecated { get; set; }

    /**
     * The range enclosing this symbol not including leading/trailing whitespace but everything else
     * like comments. This information is typically used to determine if the clients cursor is
     * inside the symbol to reveal in the symbol in the UI.
     */
    public Range? range { get; set; }

    /**
     * The range that should be selected and revealed when this symbol is being picked, e.g the name of a function.
     * Must be contained by the `range`.
     */
    public Range? selectionRange { get; set; }

    /**
     * Children of this symbol, e.g. properties of a class.
     */
    public JsonSerializableCollection<DocumentSymbol> children { get; set; }
  }

  /**
   * A symbol kind.
   */
  public enum SymbolKind
  {
    Unset = -1,
    File = 1,
    Module = 2,
    Namespace = 3,
    Package = 4,
    Class = 5,
    Method = 6,
    Property = 7,
    Field = 8,
    Constructor = 9,
    Enum = 10,
    Interface = 11,
    Function = 12,
    Variable = 13,
    Constant = 14,
    String = 15,
    Number = 16,
    Boolean = 17,
    Array = 18,
    Object = 19,
    Key = 20,
    Null = 21,
    EnumMember = 22,
    Struct = 23,
    Event = 24,
    Operator = 25,
    TypeParameter = 26
  }

  public class TextEdit : AbstractJsonSerializableObject
  {
    /**
     * The range of the text document to be manipulated. To insert
     * text into a document create a range where start === end.
     */
    public Range range { get; set; }

    /**
     * The string to be inserted. For delete operations use an
     * empty string.
     */
    public string newText { get; set; }
  }

  public class Command : AbstractJsonSerializableObject
  {
    /**
     * Title of the command, like `save`.
     */
    public string title { get; set; }
    /**
     * The identifier of the actual command handler.
     */
    public string command { get; set; }
    /**
     * Arguments that the command handler should be
     * invoked with.
     */
    public JsonSerializableCollection<string> arguments { get; set; }
  }

  /**
   * Defines whether the insert text in a completion item should be interpreted as
   * plain text or a snippet.
   */
  public enum InsertTextFormat
  {
    Unset = -1,
    /**
     * The primary text to be inserted is treated as a plain string.
     */
    PlainText = 1,
    /**
     * The primary text to be inserted is treated as a snippet.
     *
     * A snippet can define tab stops and placeholders with `$1`, `$2`
     * and `${3:foo}`. `$0` defines the final tab stop, it defaults to
     * the end of the snippet. Placeholders with equal identifiers are linked,
     * that is typing in one will update others too.
     */
    Snippet = 2
  }

  /**
   * Signature help represents the signature of something
   * callable. There can be multiple signature but only one
   * active and only one active parameter.
   */
  public class SignatureHelp : AbstractJsonSerializableObject
  {
    /**
     * One or more signatures.
     */
    public JsonSerializableCollection<SignatureInformation> signatures { get; set; }

    /**
     * The active signature. If omitted or the value lies outside the
     * range of `signatures` the value defaults to zero or is ignored if
     * `signatures.length === 0`. Whenever possible implementors should
     * make an active decision about the active signature and shouldn't
     * rely on a default value.
     * In future version of the protocol this property might become
     * mandatory to better express this.
     */
    public int activeSignature { get; set; }

    /**
     * The active parameter of the active signature. If omitted or the value
     * lies outside the range of `signatures[activeSignature].parameters`
     * defaults to 0 if the active signature has parameters. If
     * the active signature has no parameters it is ignored.
     * In future version of the protocol this property might become
     * mandatory to better express the active parameter if the
     * active signature does have any.
     */
    public int activeParameter { get; set; }

    protected override JsonSerializableCollection? create_collection(string property_name)
    {
      switch (property_name)
      {
      case "signatures":
        return new JsonArrayList<SignatureInformation>();
      }
      return base.create_collection(property_name);
    }
  }

  /**
   * Represents the signature of something callable. A signature
   * can have a label, like a function-name, a doc-comment, and
   * a set of parameters.
   */
  public class SignatureInformation : AbstractJsonSerializableObject
  {
    /**
     * The label of this signature. Will be shown in
     * the UI.
     */
    public string label { get; set; }

    /**
     * The human-readable doc-comment of this signature. Will be shown
     * in the UI but can be omitted.
     */
    public MarkupContent documentation { get; set; }

    /**
     * The parameters of this signature.
     */
    public JsonSerializableCollection<ParameterInformation> parameters { get; set; }

    protected override JsonSerializableCollection? create_collection(string property_name)
    {
      switch (property_name)
      {
      case "parameters":
        return new JsonArrayList<ParameterInformation>();
      }
      return base.create_collection(property_name);
    }
  }

  /**
   * Represents a parameter of a callable-signature. A parameter can
   * have a label and a doc-comment.
   */
  public class ParameterInformation : AbstractJsonSerializableObject
  {
    /**
     * The label of this parameter information.
     *
     * Either a string or an inclusive start and exclusive end offsets within its containing
     * signature label. (see SignatureInformation.label). The offsets are based on a UTF-16
     * string representation as `Position` and `Range` does.
     *
     * *Note*: a label of type string should be a substring of its containing signature label.
     * Its intended use case is to highlight the parameter label part in the `SignatureInformation.label`.
     */
    public string label { get; set; }

    /**
     * The human-readable doc-comment of this parameter. Will be shown
     * in the UI but can be omitted.
     */
    public MarkupContent documentation { get; set; }
  }

  public class ReferenceParams : TextDocumentPositionParams
  {
    public ReferenceContext context { get; set; }
  }

  public class ReferenceContext : AbstractJsonSerializableObject
  {
    /**
     * Include the declaration of the current symbol.
     */
    public bool includeDeclaration { get; set; }
  }

  /**
  * Params for the CodeActionRequest
  */
  public class CodeActionParams : AbstractJsonSerializableObject
  {
    /**
    * The document in which the command was invoked.
    */
    public TextDocumentIdentifier textDocument { get; set; }

    /**
    * The range for which the command was invoked.
    */
    public Range range { get; set; }

    /**
    * Context carrying additional information.
    */
    public CodeActionContext context { get; set; }
  }

  public enum CodeActionKindEnum
  {
    Unset = -1,
    /**
    * Empty kind.
    */
    Empty,

    /**
    * Base kind for quickfix actions: 'quickfix'
    */
    QuickFix,

    /**
    * Base kind for refactoring actions: 'refactor'
    */
    Refactor,

    /**
    * Base kind for refactoring extraction actions: 'refactor.extract'
    *
    * Example extract actions:
    *
    * - Extract method
    * - Extract function
    * - Extract variable
    * - Extract interface from class
    * - ...
    */
    RefactorExtract,

    /**
    * Base kind for refactoring inline actions: 'refactor.inline'
    *
    * Example inline actions:
    *
    * - Inline function
    * - Inline variable
    * - Inline constant
    * - ...
    */
    RefactorInline,

    /**
    * Base kind for refactoring rewrite actions: 'refactor.rewrite'
    *
    * Example rewrite actions:
    *
    * - Convert JavaScript function to class
    * - Add or remove parameter
    * - Encapsulate field
    * - Make method static
    * - Move method to base class
    * - ...
    */
    RefactorRewrite,

    /**
    * Base kind for source actions: `source`
    *
    * Source code actions apply to the entire file.
    */
    Source,

    /**
    * Base kind for an organize imports source action: `source.organizeImports`
    */
    SourceOrganizeImports;

    public static CodeActionKindEnum? from_json(string? value)
    {
      if (value == null)
      {
        return null;
      }

      switch ((string)value)
      {
      case "": return CodeActionKindEnum.Empty;
      case "quickfix": return CodeActionKindEnum.QuickFix;
      case "refactor": return CodeActionKindEnum.Refactor;
      case "refactor.extract": return CodeActionKindEnum.RefactorExtract;
      case "refactor.inline": return CodeActionKindEnum.RefactorInline;
      case "refactor.rewrite": return CodeActionKindEnum.RefactorRewrite;
      case "source": return CodeActionKindEnum.Source;
      case "source.organizeImports": return CodeActionKindEnum.SourceOrganizeImports;
      default: return CodeActionKindEnum.Unset;
      }
    }

    public string to_json()
    {
      switch (this)
      {
      case CodeActionKindEnum.Empty: return "";
      case CodeActionKindEnum.QuickFix: return "quickfix";
      case CodeActionKindEnum.Refactor: return "refactor";
      case CodeActionKindEnum.RefactorExtract: return "refactor.extract";
      case CodeActionKindEnum.RefactorInline: return "refactor.inline";
      case CodeActionKindEnum.RefactorRewrite: return "refactor.rewrite";
      case CodeActionKindEnum.Source: return "source";
      case CodeActionKindEnum.SourceOrganizeImports: return "source.organizeImports";
      default: return "???";
      }
    }
  }

  public class CodeActionKind : Object, JsonSerializableValue
  {
    public CodeActionKindEnum value { get; set; }

    public CodeActionKind(CodeActionKindEnum value)
    {
      this.value = value;
    }

    public Json.Node serialize()
    {
      Json.Node node = new Json.Node(Json.NodeType.VALUE);
      node.set_string(value.to_json());
      return node;
    }

    public bool deserialize(Json.Node node)
    {
      if (node.get_node_type() != Json.NodeType.VALUE)
      {
        return false;
      }

      CodeActionKindEnum? value = CodeActionKindEnum.from_json(node.get_string());
      if (value == null)
      {
        return false;
      }

      this.value = value;
      return true;
    }
  }

  /**
   * Contains additional diagnostic information about the context in which
   * a code action is run.
   */
  public class CodeActionContext : AbstractJsonSerializableObject
  {
    /**
     * An array of diagnostics.
     */
    public JsonSerializableCollection<Diagnostic> diagnostics { get; set; }

    /**
     * Requested kind of actions to return.
     *
     * Actions not of this kind are filtered out by the client before being shown. So servers
     * can omit computing them.
     */
    public JsonSerializableCollection<CodeActionKind> only { get; set; }

    protected override JsonSerializableCollection? create_collection(string property_name)
    {
      switch (property_name)
      {
      case "diagnostics":
        return new JsonArrayList<Diagnostic>();
      case "only":
        return new JsonArrayList<CodeActionKind>();
      }
      return base.create_collection(property_name);
    }
  }

  /**
   * A code action represents a change that can be performed in code, e.g. to fix a problem or
   * to refactor code.
   *
   * A CodeAction must set either `edit` and/or a `command`. If both are supplied, the `edit` is applied first, then the `command` is executed.
   */
  public class CodeAction : AbstractJsonSerializableObject
  {
    /**
     * A short, human-readable, title for this code action.
     */
    public string title { get; set; }

    /**
     * The kind of the code action.
     *
     * Used to filter code actions.
     */
    public CodeActionKind kind { get; set; }

    /**
     * The diagnostics that this code action resolves.
     */
    public JsonSerializableCollection<Diagnostic> diagnostics { get; set; }

    /**
     * The workspace edit this code action performs.
     */
    public WorkspaceEdit edit { get; set; }

    /**
     * A command this code action executes. If a code action
     * provides an edit and a command, first the edit is
     * executed and then the command.
     */
    public Command command { get; set; }

    protected override JsonSerializableCollection? create_collection(string property_name)
    {
      switch (property_name)
      {
      case "diagnostics":
        return new JsonArrayList<Diagnostic>();
      }
      return base.create_collection(property_name);
    }
  }

  public class CodeLensParams : AbstractJsonSerializableObject
  {
    /**
     * The document to request code lens for.
     */
    public TextDocumentIdentifier textDocument { get; set; }
  }

  /**
   * A code lens represents a command that should be shown along with
   * source text, like the number of references, a way to run tests, etc.
   *
   * A code lens is _unresolved_ when no command is associated to it. For performance
   * reasons the creation of a code lens and resolving should be done in two stages.
   */
   public class CodeLens : AbstractJsonSerializableObject
   {
     /**
      * The range in which this code lens is valid. Should only span a single line.
      */
     public Range range { get; set; }

     /**
      * The command this code lens represents.
      */
     public Command command { get; set; }

     /**
      * A data entry field that is preserved on a code lens item between
      * a code lens and a code lens resolve request.
      */
     public CodeLensData data { get; set; }
   }

   public class CodeLensData : AbstractJsonSerializableObject
   {
     public TextDocumentIdentifier textDocument { get; set; }
   }

  //  public class ShowMessageParams : AbstractJsonSerializableObject
  //  {
  //    /**
  //     * The message type. See {@link MessageType}.
  //     */
  //    public MessageType @type { get, set; default = MessageType.Unset; }

  //    /**
  //     * The actual message.
  //     */
  //    public string message { get; set; }
  //  }

  //  public enum MessageType
  //  {
  //    Unset = -1,
  //    /**
  //     * An error message.
  //     */
  //    Error = 1,
  //    /**
  //     * A warning message.
  //     */
  //    Warning = 2,
  //    /**
  //     * An information message.
  //     */
  //    Info = 3,
  //    /**
  //     * A log message.
  //     */
  //    Log = 4
  //  }
}
