// =============================================================================
// MaL (Make-a-Lisp) Interpreter - Step 7: Quoting
// =============================================================================
//
// 1. DATA AS CODE: Implemented the core quoting mechanics that allow data
//    structures to be treated as executable code or protected from evaluation.
//
// 2. SPECIAL FORMS: Added 'quote' to return expressions unevaluated, and 
//    'quasiquote' to enable partial evaluation of syntax trees.
//
// 3. UNQUOTING MARKERS: Integrated 'unquote' (~) and 'splice-unquote' (~@) 
//    as internal directives to dynamically inject and flatten expressions 
//    inside a quasiquoted form.
//
// 4. CORE RESTRUCTURING: Introduced 'cons', 'concat', and 'vec' helper 
//    functions to programmatically build, merge, and convert Lisp lists 
//    and vectors during macroexpansion.
//
// =============================================================================

// Main entry point for Step 7 of the Make-a-Lisp interpreter.
// Evaluates the abstract syntax tree in a basic environment.
//
// Parameters:
//   Input - String - The raw Lisp code entered by the user.
//   Debug - String - An output parameter containing the execution trace.
//
// Returns:
//   String - The final result of the REPL pipeline (serialized string representation).
Function MaL_Step_7(Input, Debug) Export
    AST = Read(Input, Debug);
    GlobalEnvironment = CreateGlobalEnvironment();
    InitializeCore(GlobalEnvironment);
    // Initialize *ARGV* as an empty List
    SetEnvironment(GlobalEnvironment, "*ARGV*", New Structure("Type, Value", "List", New Array)); Output = "";
    For Each Expression In AST.Value Do
        Result = Exec(Expression, GlobalEnvironment, Debug);
        Output = Output + Print(Result, Debug) + Chars.CR;
    EndDo;
    Return Output;
EndFunction

#Region READ

// Reads the raw input string and prepares it for the Lisp execution pipeline.
// Currently acts as a stub that echoes the input with a "READ:" prefix.
//
// Parameters:
//   Input - String - The raw code or expression entered by the user.
//   Debug - String - An output parameter used to capture debugging information.
//
// Returns:
//   AST   - Array  - Abstract Syntax Tree (AST) structures.
Function Read(Input, Debug)
    // 1. Lexical analysis
    Tokens = Tokenize(Input);
    // Print tokens to Debug for tracking
    Debug = Debug + "TOKENS: " + Chars.CR;
    For Each Token In Tokens Do
        Debug = Debug + Token + Chars.CR;
    EndDo;
    
    // 2. Initializes the reader cursor structure
    Reader = New Structure("Tokens, Position", Tokens, 0);
    
    // 3. AST construction
    AST = New Structure("Type,Value", "List", New Array);
    
    // Process everything in the input string
    // Until the end of the tokens array is reached
    While Peek(Reader) <> Undefined Do
        AST.Value.Add(ReadForm(Reader));
    EndDo;
    
    Debug = Debug + "AST:" + Chars.CR + PrintDebug(AST) + Chars.CR;
    
    // 4. Return result
    Return AST;
EndFunction

// Converts an input string into a list of tokens.
// Handles whitespace, comments, special characters, and string literals.
Function Tokenize(InputText)
    Tokens = New Array;
    Delimiters = " ," + Chars.Tab + Chars.LF + Chars.CR;
    Length = StrLen(InputText);
    Pos = 1;
    
    While Pos <= Length Do
        Char = Mid(InputText, Pos, 1);
        // 1. Skip spaces and commas
        If StrFind(Delimiters, Char) > 0 Then
            Pos = Pos + 1;
            Continue;
        EndIf;
        // 2. Skip comments (everything after ;)
        If Char = ";" Then
            While Pos <= Length AND Mid(InputText, Pos, 1) <> Chars.LF Do
                Pos = Pos + 1;
            EndDo;
            Pos = Pos + 1;
            Continue;
        EndIf;
        // 3. Handle special single-character tokens
        // according to MaL standard: ~@ () [] {} ' ` ^ @
        If StrFind("()[]{}'`^~@", Char) > 0 Then
            // Special case for ~@
            NextChar = ?(Pos + 1 <= Length, Mid(InputText, Pos + 1, 1), "");
            If Char = "~" AND NextChar = "@" Then
                Tokens.Add("~@");
                Pos = Pos + 2;
            Else
                Tokens.Add(Char);
                Pos = Pos + 1;
            EndIf;
            Continue;
        EndIf;
        // 4. Handle string literals
        If Char = """" Then
            FlagOpenString = TRUE;
            String = Char;
            Pos = Pos + 1;
            While Pos <= Length Do
                Char = Mid(InputText, Pos, 1);
                If Char = """" Then String = String + Char; FlagOpenString = FALSE; Break; EndIf;
                If Char = "\" Then
                    Pos = Pos + 1;
                    EscapedChar = Mid(InputText, Pos, 1);
                    If EscapedChar = """" Then
                        Char = """";
                    ElsIf EscapedChar = "\" Then
                        Char = "\";
                    ElsIf EscapedChar = "n" Then
                        Char = Chars.LF;
                    Else
                        Raise "Tokenize: Invalid escape sequence: \" + EscapedChar;
                    EndIf;
                EndIf;
                String = String + Char;
                Pos = Pos + 1;
            EndDo;
            Tokens.Add(?(FlagOpenString, "Tokenize: Unbalanced String: " + String, String));
            Pos = Pos + 1;
            Continue;
        EndIf;
        // 5. Handle atoms
        Start = Pos;
        While Pos <= Length Do
            NextChar = Mid(InputText, Pos, 1);
            If StrFind(Delimiters + " ,;()[]{}'`^~@""", NextChar) > 0 Then
                Break;
            EndIf;
            Pos = Pos + 1;
        EndDo;
        Tokens.Add(Mid(InputText, Start, Pos - Start));
    EndDo;
    
    Return Tokens;
EndFunction

// Dispatches parsing to either List or Atom handlers based on the current token.
Function ReadForm(Reader)
    Token = Peek(Reader);
    If Token = "(" Then Return ReadList(Reader);
    ElsIf Token = "[" Then Return ReadVector(Reader);
    ElsIf Token = "{" Then Return ReadHashMap(Reader);
        // Handle Reader Macros
    ElsIf Token = "'" Then
        Next(Reader);
        Return WrapInList("quote", ReadForm(Reader));
    ElsIf Token = "`" Then
        Next(Reader);
        Return WrapInList("quasiquote", ReadForm(Reader));
    ElsIf Token = "~" Then
        Next(Reader);
        Return WrapInList("unquote", ReadForm(Reader));
    ElsIf Token = "~@" Then
        Next(Reader);
        Return WrapInList("splice-unquote", ReadForm(Reader));
    ElsIf Token = "@" Then
        Next(Reader);
        Return WrapInList("deref", ReadForm(Reader));
        // Handle metadata
    ElsIf Token = "^" Then
        Next(Reader);
        Meta = ReadForm(Reader); // Read metadata
        Data = ReadForm(Reader); // Read the object itself (list, symbol, etc.)
        Return WrapInMetadataList(Meta, Data);
        // Handle atoms
    Else Return ReadAtom(Reader);
    EndIf;
EndFunction

// Helper function to wrap a form into a specific reader macro list.
// For example, calling it with "quote" and 'x' creates '(quote x)'.
// Supports variable number of arguments.
//
// Parameters:
//   SymbolName - String - The symbol representing the macro (e.g., "quote", "deref").
//   Arg1,Arg2  - Structure - The AST node to wrap.
//
// Returns:
//   Structure - A new List node containing the Symbol and the Form.
Function WrapInList(SymbolName, Arg1 = Undefined, Arg2 = Undefined)
    Elements = New Array;
    Elements.Add(New Structure("Type, Value", "Symbol", SymbolName));
    
    If Arg1 <> Undefined Then
        Elements.Add(Arg1);
    EndIf;
    If Arg2 <> Undefined Then
        Elements.Add(Arg2);
    EndIf;
    
    Return New Structure("Type, Value", "List", Elements);
EndFunction

// Transforms ^meta data into (with-meta data meta).
// Note: In MaL, the argument order is (with-meta object metadata).
//
// Parameters:
//   Meta - Structure - The AST node representing the metadata.
//   Data - Structure - The AST node representing the object being decorated.
//
// Returns:
//   Structure - A new List node in the format (with-meta data meta).
Function WrapInMetadataList(Meta, Data)
    Elements = New Array;
    Elements.Add(New Structure("Type, Value", "Symbol", "with-meta"));
    Elements.Add(Data);
    Elements.Add(Meta);
    Return New Structure("Type, Value", "List", Elements);
EndFunction

// Parses a list by consuming tokens until the closing ")".
Function ReadList(Reader)
    // Skip the opening "("
    Next(Reader);
    // Initialize an array to collect the nodes (forms) within the list
    NodesArray = New Array;
    
    // Continue reading until we hit ")"
    While Peek(Reader) <> ")" Do
        // Check for Unexpected End of Input
        If Peek(Reader) = Undefined Then
            // Add the error structure as the last element of the list
            // This satisfies the test requirement to report "EOF" or "unbalanced"
            NodesArray.Add(CreateError("Readlist", "Unexpected EOF (missing closing parenthesis ')')"));
            // Critical: We must BREAK the loop because there are no more tokens to read
            Break;
        EndIf;
        // Read the next form recursively
        // If ReadForm returns an error node from a deeper level, it will just be added here
        NextForm = ReadForm(Reader);
        NodesArray.Add(NextForm);
        // If the form we just read is an Error, we might want to stop reading this list
        If NextForm.Type = "Error" Then
            Break;
        EndIf;
    EndDo;
    // Only skip closing ")" if it actually exists (we didn't exit by EOF)
    If Peek(Reader) = ")" Then
        Next(Reader);
    EndIf;
    // Return the list containing all read forms plus the error node at the end
    Return New Structure("Type, Value", "List", NodesArray);
EndFunction

// Parses a vector by consuming tokens until the closing "]".
Function ReadVector(Reader)
    // Skip the opening "["
    Next(Reader);
    // Initialize an array to collect the nodes (forms) within the vector
    NodesArray = New Array;
    // Continue reading until we hit "]"
    While Peek(Reader) <> "]" Do
        // Check for Unexpected End of Input
        If Peek(Reader) = Undefined Then
            // Add the error structure as the last element of the vector
            // This allows the printer to show the error without crashing the interpreter
            NodesArray.Add(CreateError("ReadVector", "Unexpected EOF (missing closing bracket ']')"));
            // Critical: We must BREAK the loop because there are no more tokens to read
            Break;
        EndIf;
        // Read the next form recursively
        // Every form (atom or nested structure) is parsed recursively
        NextForm = ReadForm(Reader);
        NodesArray.Add(NextForm);
        // If the form we just read is an Error (e.g., an unbalanced nested list),
        // we stop reading this vector further.
        If NextForm.Type = "Error" Then
            Break;
        EndIf;
    EndDo;
    // Only skip closing "]" if it actually exists (we didn't exit by EOF)
    If Peek(Reader) = "]" Then
        Next(Reader);
    EndIf;
    // Return the vector as a structured Node
    // This treats the vector as a first-class data type in our AST
    Return New Structure("Type, Value", "Vector", NodesArray);
EndFunction

// Parses a hash map by consuming tokens until the closing "}"
Function ReadHashMap(Reader)
    // Skip the opening "{"
    Next(Reader);
    // Initialize an array to store key-value pairs (stored as a flat list)
    NodesArray = New Array;
    // Continue reading until we hit "}"
    While Peek(Reader) <> "}" Do
        // Check for Unexpected End of Input
        If Peek(Reader) = Undefined Then
            // Add the error node to report unbalanced braces
            NodesArray.Add(CreateError("ReadHashMap", "Unexpected EOF (missing closing brace '}')"));
            // Critical: Break the loop as there are no more tokens
            Break;
        EndIf;
        // Read the next form (could be a key or a value)
        NextForm = ReadForm(Reader);
        NodesArray.Add(NextForm);
        // If an error occurred during recursive reading, stop here
        If NextForm.Type = "Error" Then
            Break;
        EndIf;
    EndDo;
    // Logic for successful closing brace
    If Peek(Reader) = "}" Then
        Next(Reader);
        // Check if we have an even number of elements (Key-Value pairs)
        // Only check this if no EOF error was already found
        If NodesArray.Count() % 2 <> 0 AND NodesArray[NodesArray.Count() - 1].Type <> "Error" Then
            NodesArray.Add(CreateError("ReadHashMap", "Syntax Error: Hash map must contain an even number of elements"));
        EndIf;
    EndIf;
    // Return the hash map as a structured Node with a flat array in Value
    Return New Structure("Type, Value", "HashMap", NodesArray);
EndFunction

// Factory function: Converts a token into a typed structure (Atom).
Function ReadAtom(Reader)
    Token = Next(Reader);
    
    // Try to determine the type
    If Token = "+" OR Token = "-" Then
        Return New Structure("Type, Value", "Symbol", Token);
    ElsIf IsNumeric(Token) Then
        Return New Structure("Type, Value", "Number", Token);
    ElsIf Upper(Token) = "NIL" Then
        Return New Structure("Type, Value", "Nil", Undefined);
    ElsIf Upper(Token) = "TRUE" Then
        Return New Structure("Type, Value", "Boolean", TRUE);
    ElsIf Upper(Token) = "FALSE" Then
        Return New Structure("Type, Value", "Boolean", FALSE);
    ElsIf Left(Token, 1) = ":" Then
        Return New Structure("Type, Value", "Keyword", Token);
    ElsIf Left(Token, 1) = """" Then
        Return New Structure("Type, Value", "String", Mid(Token, 2, StrLen(Token) - 2))
    Else
        // Default: everything else is a Symbol
        Return New Structure("Type, Value", "Symbol", Token);
    EndIf;
EndFunction

// Checks if the string can be treated as a number.
// Returns: Boolean - True if numeric, False otherwise.
// SIDE EFFECT: Modifies the passed parameter 'Token' by reference
Function IsNumeric(Token)
    Position = 1;
    Sign = 1;
    IntegerPart = 0;
    FractionalPart = 0;
    FractionalDivisor = 1;
    DotEcountered = FALSE;
    // Handle sign if present
    Char = Mid(Token, Position, 1);
    If Char = "-" Then Sign = -1; Position = 2;
    ElsIf Char = "+" Then Position = 2;
    EndIf;
    //Main parsing loop
    While Position <= StrLen(Token) Do
        Char = Mid(Token, Position, 1);
        If Char = "." Then
            If DotEcountered Then
                Return FALSE; // Second dot
            EndIf;
            DotEcountered = TRUE;
        ElsIf Find("0123456789", Char) > 0 Then
            Digit = Number(Char);
            If NOT DotEcountered Then
                IntegerPart = IntegerPart * 10 + Digit;
            Else
                FractionalPart = FractionalPart * 10 + Digit;
                FractionalDivisor = FractionalDivisor * 10;
            EndIf;
        Else
            Return FALSE; // Invalid character encountered
        EndIf;
        Position = Position + 1;
    EndDo;
    
    If DotEcountered Then
        Token = Sign * (IntegerPart + FractionalPart / FractionalDivisor);
    Else
        Token = Sign * IntegerPart;
    EndIf;
    Return TRUE;
EndFunction

// Returns the current token without advancing the cursor.
Function Peek(Reader)
    If Reader.Position < Reader.Tokens.Count() Then
        Return Reader.Tokens[Reader.Position];
    EndIf;
    Return Undefined;
EndFunction

// Returns the current token and advances the cursor.
Function Next(Reader)
    Token = Peek(Reader);
    Reader.Position = Reader.Position + 1;
    Return Token;
EndFunction

#EndRegion

#Region ENVIRONMENT

// Universal environment constructor.
// Creates a new execution context, optionally linked to a parent (Outer).
//
// Parameters:
//   Outer - Map|Undefined - The parent environment.
//
// Returns:
//   Structure - A new environment containing a Data map and Outer reference.
Function CreateEnvironment(Outer = Undefined)
    Environment = New Structure("Data, Outer");
    Environment.Data = New Map;
    Environment.Outer = Outer; // Reference to the parent environment
    Return Environment;
EndFunction

// Initializes the global environment with base arithmetic operations.
//
// Returns:
//   Map - A lookup table where symbols (e.g., "+") are mapped to
//         internal operator identifiers (e.g., "ADD").
Function CreateGlobalEnvironment()
    // Create the top-level environment (it has no parent, so Undefined)
    Return CreateEnvironment(Undefined);
EndFunction

// Traverses the environment chain upwards to find and return the global root environment.
//
// Parameters:
//   Environment - Structure - The starting environment.
//
// Returns:
//   Structure - The top-level global environment.
Function GetGlobalEnvironment(Environment)
    Current = Environment;
    While Current.Outer <> Undefined Do
        Current = Current.Outer;
    EndDo;
    Return Current;
EndFunction

// Inserts or updates a Key-Value pair in the specified environment's local Data map.
//
// Parameters:
//   Environment - Structure - The target environment.
//   Symbol      - String    - The variable name to bind.
//   Value       - Any       - The value to store.
Procedure SetEnvironment(Environment, Symbol, Value)
    Environment.Data.Insert(Symbol, Value);
EndProcedure

// Recursively searches for a variable symbol in the environment chain.
//
// Parameters:
//   Environment - Structure - The starting environment.
//   Symbol      - String    - The variable name to find.
//
// Returns:
//   Any - The value bound to the symbol, or an Error node if not found.
Function GetEnvironment(Environment, Symbol) Export
    // 1. Attempt to find the Symbol in the current environment
    If Environment.Data.Get(Symbol) <> Undefined Then
        Return Environment.Data.Get(Symbol);
    EndIf;
    
    // 2. If not found and a parent (Outer) exists, search there
    If Environment.Outer <> Undefined Then
        Return GetEnvironment(Environment.Outer, Symbol);
    EndIf;
    
    // 3. If reached the top and not found
    Return CreateError("GetEnvironment", "Symbol %1 not found", Symbol);
EndFunction

// Initializes the base environment with core functions and logical operators.
//
// Parameters:
//   Environment - Structure - The environment to populate.
Procedure InitializeCore(Environment)
    // Register the base arithmetic operations
    SetEnvironment(Environment, "+", "ADD");
    SetEnvironment(Environment, "-", "SUB");
    SetEnvironment(Environment, "*", "MUL");
    SetEnvironment(Environment, "/", "DIV");
    // Logic and Comparisons
    SetEnvironment(Environment, "=", "EQ");
    SetEnvironment(Environment, "<", "LT");
    SetEnvironment(Environment, "<=", "LE");
    SetEnvironment(Environment, ">", "GT");
    SetEnvironment(Environment, ">=", "GE");
    SetEnvironment(Environment, "<>", "NE");
    SetEnvironment(Environment, "not", "NOT");
    // List operations
    SetEnvironment(Environment, "list", "LIST");
    SetEnvironment(Environment, "list?", "LISTQ"); // 'Q' stands for Question mark (predicate)
    SetEnvironment(Environment, "empty?", "EMPTYQ");
    SetEnvironment(Environment, "count", "COUNT");
    SetEnvironment(Environment, "eval", "EVAL");
	SetEnvironment(Environment, "cons", "CONS");
	SetEnvironment(Environment, "concat", "CONCAT");
	SetEnvironment(Environment, "vec", "VEC");
	// Atom operations
    SetEnvironment(Environment, "atom", "ATOM");
    SetEnvironment(Environment, "atom?", "ATOMQ");
    SetEnvironment(Environment, "deref", "DEREF");
    SetEnvironment(Environment, "reset!", "RESET");
    SetEnvironment(Environment, "swap!", "SWAP");
    // I/O and String manipulation
    SetEnvironment(Environment, "prn", "PRINT");
    SetEnvironment(Environment, "println", "PRINTLN");
    SetEnvironment(Environment, "pr-str", "PRSTR");
    SetEnvironment(Environment, "str", "STR");
    SetEnvironment(Environment, "read-string", "READSTRING");
    SetEnvironment(Environment, "slurp", "SLURP");
    SetEnvironment(Environment, "load-file", "LOADFILE");
EndProcedure

#EndRegion

#Region EXEC // EVAL

// Recursively evaluates the AST (Abstract Syntax Tree).
// 1. Returns the raw value for Atoms (Number, Boolean, Nil).
// 2. Performs a lookup in the Environment for Symbols.
// 3. Handles List application: evaluates all items in the list,
//    then passes the operator and arguments to 'Apply'.
//
// Parameters:
//   AST         - Array|Structure - The node to evaluate.
//   Environment - Map             - The execution context for symbol lookups.
//   Debug       - String          - Output parameter for tracing.
//
// Returns:
//   Any - The result of the evaluation.
Function Exec(AST, Environment, Debug) Export
    
    // 1. If it's a SYMBOL, look it up in the Environment
    If AST.Type = "Symbol" Then
        Return GetEnvironment(Environment, AST.Value);
        
    // 2. If it's a List (Function application)
    ElsIf AST.Type = "List" Then
        // 2.1 Check if the list is empty
        If AST.Value.Count() = 0 Then
            // Empty lists evaluate to themselves (like numbers or strings)
            Return AST;
        EndIf;
        
        NodesArray = AST.Value; // The Value of a List Node is an Array of nodes (arguments)
        OperatorNode = NodesArray[0]; // Operator (first element of the list)
        
        // =====================================================================
        // SPECIAL FORMS SECTION
        // =====================================================================
        // 2.2 Check for Special Forms FIRST (def!)
        If OperatorNode.Type = "Symbol" AND OperatorNode.Value = "def!" Then
            // def! special form logic
            If NodesArray.Count() < 3 Then
                Return CreateError("Exec", "Wrong number of args passed to def!");
            ElsIf NodesArray[1].Type <> "Symbol" Then
                Return CreateError("Exec", "First argument to def! must be a symbol");
            EndIf;
            SymbolName = NodesArray[1].Value; // Get symbol name (unevaluated)
            ValueNode = Exec(NodesArray[2], Environment, Debug); // Evaluate expression
            If IsError(ValueNode) Then Return ValueNode; EndIf;
            SetEnvironment(Environment, SymbolName, ValueNode);
            Return ValueNode; // IMPORTANT: Bypass evaluation loop and return immediately
        // 2.3 Check for Special Forms (let*)
        ElsIf OperatorNode.Type = "Symbol" AND OperatorNode.Value = "let*" Then
            If NodesArray.Count() < 3 Then
                Return CreateError("Exec", "Wrong number of args passed to let*");
            ElsIf NodesArray[1].Type <> "List" AND NodesArray[1].Type <> "Vector" Then
                Return CreateError("Exec", "let* bindings must be a list or vector");
            EndIf;
            
            BindingsArray = NodesArray[1].Value; // Get the array of bindings (list of pairs)
            If BindingsArray.Count() % 2 <> 0 Then Return CreateError("Exec", "let* bindings must have an even number of elements"); EndIf;
            
            LocalEnvironment = CreateEnvironment(Environment); // Create a new child environment
            // Process bindings in pairs
            i = 0;
            While i < BindingsArray.Count() Do
                // Get variable name (even indices: 0, 2, 4...)
                SymbolName = BindingsArray[i].Value;
                // Get the expression to evaluate (odd indices: 1, 3, 5...)
                // Validate index existence to prevent out-of-bounds error
                ExpressionNode = BindingsArray[i + 1];
                ValueNode = Exec(ExpressionNode, LocalEnvironment, Debug); // Evaluate the value in the new environment
                If IsError(ValueNode) Then
                    Return ValueNode;
                Else
                    SetEnvironment(LocalEnvironment, SymbolName, ValueNode); // Add to the local environment
                EndIf;
                i = i + 2;
            EndDo;
            Return Exec(NodesArray[2], LocalEnvironment, Debug); // Evaluate the let* body
        // 2.4 Check for Special Forms (if)
        ElsIf OperatorNode.Value = "if" Then
            // 2.4.1 Evaluate only the condition
            Condition = Exec(NodesArray[1], Environment, Debug);
            // 2.4.2 Check truthiness
            // If the result is neither Nil nor False, it is considered true
            If NOT Condition.Type = "Nil" AND NOT (Condition.Type = "Boolean" AND Condition.Value = FALSE) Then
                // 2.4.3 If true, evaluate and return the 'then' branch
                Return Exec(NodesArray[2], Environment, Debug);
            Else
                // 2.4.4 If false, evaluate the 'else' branch if it exists
                If NodesArray.Count() > 3 Then
                    Return Exec(NodesArray[3], Environment, Debug);
                Else
                    // If no 'else' branch exists, return nil
                    Return New Structure("Type, Value", "Nil", Undefined);
                EndIf;
            EndIf;
        // 2.5 Check for Special Forms (fn*)
        ElsIf OperatorNode.Value = "fn*" Then
            // Create function structure
            FunctionStructure = New Structure;
            FunctionStructure.Insert("Type", "Function");
            FunctionStructure.Insert("Params", NodesArray[1]);
            FunctionStructure.Insert("Body", NodesArray[2]);
            FunctionStructure.Insert("Environment", Environment);
            Return FunctionStructure;
        // 2.6 Check for Special Forms (do)
        ElsIf OperatorNode.Value = "do" Then
            // 2.6.1 If 'do' is empty (e.g., (do)), return nil
            If AST.Value.Count() = 1 Then
                Return New Structure("Type, Value", "Nil", Undefined);
            EndIf;
            Result = New Structure("Type, Value", "Nil", Undefined);
            // Evaluate each expression sequentially (starting from the second element)
            For i = 1 To AST.Value.Count() - 1 Do
                Result = Exec(AST.Value[i], Environment, Debug);
            EndDo;
            // Return the result of the last expression
            Return Result;
		// 2.7 Check for Special Forms (quote)
        ElsIf OperatorNode.Type = "Symbol" AND OperatorNode.Value = "quote" Then
            If NodesArray.Count() < 2 Then
                Return CreateError("Exec.quote", "Wrong number of args passed to quote");
            EndIf;
            // Return the unevaluated argument directly
            Return NodesArray[1];
		// 2.8 Check for Special Forms (quasiquote)
        ElsIf OperatorNode.Type = "Symbol" AND OperatorNode.Value = "quasiquote" Then
            If NodesArray.Count() < 2 Then
                Return CreateError("Exec.quasiquote", "Wrong number of args passed to quasiquote");
            EndIf;
            // Step 1: Macroexpand the quasiquote into cons/concat pipeline
            ExpandedAST = Quasiquote(NodesArray[1]);
            If IsError(ExpandedAST) Then Return ExpandedAST; EndIf;
            // Step 2: Evaluate the resulting AST expansion in the current environment
            Return Exec(ExpandedAST, Environment, Debug);

        // =====================================================================
        // REGULAR EVALUATION SECTION (Evaluates functions and arguments)
        // =====================================================================
		Else
            // Evaluate all elements recursively
            EvaluatedList = New Array;
            For Each Item In NodesArray Do
                EvaluatedItem = Exec(Item, Environment, Debug);
                If IsError(EvaluatedItem) Then Return EvaluatedItem; EndIf;
                EvaluatedList.Add(EvaluatedItem);
            EndDo;
            Operator = EvaluatedList[0]; // The first element is the evaluated function identifier
            // Check if the operator is valid
            If IsError(Operator) Then
                Debug = Debug + Operator.Value + Chars.CR;
                Return Operator;
            EndIf;
            Args = New Array; // Create an array of evaluated arguments
            For i = 1 To EvaluatedList.Count() - 1 Do
                Args.Add(EvaluatedList[i]);
            EndDo;
            // Check if it's a user-defined function (fn*)
            If TypeOf(Operator) = Type("Structure") AND Operator.Property("Type") AND Operator.Type = "Function" Then
                Return InvokeFunction(Operator, Args, Debug);
            EndIf;
            // Apply built-in function
            Return Apply(Operator, Args, Environment, Debug); // Apply the operator to the arguments
        EndIf;
        
        // 3. Handle Vector: evaluate all elements within the vector
    ElsIf AST.Type = "Vector" Then
        // Initialize an array to store the evaluated elements
        EvaluatedValues = New Array;
        // Recursively evaluate each element in the vector
        For Each Element In AST.Value Do
            EvaluatedValues.Add(Exec(Element, Environment, Debug));
        EndDo;
        // Return a new Vector node containing the evaluated elements
        Return New Structure("Type, Value", "Vector", EvaluatedValues);
        
        // 4. Handle HashMap
    ElsIf AST.Type = "HashMap" Then
        NewValue = New Array;
        // Iterate through the flat array [k1, v1, k2, v2...]
        For Each Element In AST.Value Do
            // Evaluate the element (if it's a Keyword, it stays as is,
            // if it's an expression like (+ 1 2), it becomes 3)
            NewValue.Add(Exec(Element, Environment, Debug));
        EndDo;
        Return New Structure("Type, Value", "HashMap", NewValue);
        
        // 5. If it's an ATOM (Number, String, Boolean, Nil) — return the Node itself
        // Or, if you want to strictly return the raw value, you could return AST.Value
    Else
        Return AST;
    EndIf;
    
EndFunction

// Invokes a user-defined Lisp function (fn*) with evaluated arguments.
// Supports variable arguments via '& rest'.
Function InvokeFunction(FunctionNode, Args, Debug) Export
    LocalEnvironment = CreateEnvironment(FunctionNode.Environment);
    Params = FunctionNode.Params.Value;
    ArgsCount = Args.Count();
    
    For i = 0 To Params.Count() - 1 Do
        ParamName = Params[i].Value;
        If ParamName = "&" Then
            // Check if there is a variable name after '&'
            If i + 1 < Params.Count() Then
                RestSymbol = Params[i + 1].Value;
                RestArgs = New Array;
                // Collect all remaining arguments into an array
                For j = i To ArgsCount - 1 Do
                    RestArgs.Add(Args[j]);
                EndDo;
                // Wrap in a List (as required by MaL for & more)
                ListNode = New Structure("Type, Value", "List", RestArgs);
                SetEnvironment(LocalEnvironment, RestSymbol, ListNode);
                Break; // Stop binding arguments
            EndIf;
        Else
            // Standard argument binding
            If i < ArgsCount Then
                SetEnvironment(LocalEnvironment, ParamName, Args[i]);
            EndIf;
        EndIf;
    EndDo;
    
    Return Exec(FunctionNode.Body, LocalEnvironment, Debug);
EndFunction

// Recursively processes a quasiquoted form and transforms it
// into a sequence of 'cons' and 'concat' applications.
Function Quasiquote(Node)
    // Case 1: If it's not a pair (scalar, symbol, empty collection), just quote it
    If NOT IsPair(Node) Then
        Return WrapInList("quote", Node);
    Else
        Elements = Node.Value;
        FirstElement = Elements[0];
        
        // --- Case 2a: STRICT MATCH for real (unquote X) from Reader (~X)
        // It MUST be a List, start with "unquote", and have EXACTLY 2 elements!
        If Node.Type = "List" AND FirstElement.Type = "Symbol" AND FirstElement.Value = "unquote" AND Elements.Count() = 2 Then
            Return Elements[1];
            
        // --- Case 2c: Process standard elements and handle unquote/splice-unquote during iteration
        Else
            // Start with an empty list wrapped in a quote: (quote ())
            ResultExpression = WrapInList("quote", New Structure("Type, Value", "List", New Array));
            
            // Loop backwards to construct the execution tree
            For i = 0 To Elements.Count() - 1 Do
                Idx = Elements.Count() - 1 - i;
                CurrentElement = Elements[Idx];
                
                // 1. Check for regular UNQUOTE (~X) inside the collection
                If CurrentElement.Type = "List" AND CurrentElement.Value.Count() = 2 
                    AND CurrentElement.Value[0].Type = "Symbol" AND CurrentElement.Value[0].Value = "unquote" Then
                    
                    ProcessedNode = CurrentElement.Value[1];
                    ResultExpression = WrapInList("cons", ProcessedNode, ResultExpression);
                    
                // 2. Check for SPLICE-UNQUOTE (~@X) inside the collection
                ElsIf CurrentElement.Type = "List" AND CurrentElement.Value.Count() = 2 
                    AND CurrentElement.Value[0].Type = "Symbol" AND CurrentElement.Value[0].Value = "splice-unquote" Then
                    
                    ProcessedNode = CurrentElement.Value[1];
                    // Splice-unquote demands CONCAT instead of CONS to flatten the collection!
                    ResultExpression = WrapInList("concat", ProcessedNode, ResultExpression);
                    
                // 3. Normal elements (or nested vectors/structures)
                Else
                    ProcessedNode = Quasiquote(CurrentElement);
                    ResultExpression = WrapInList("cons", ProcessedNode, ResultExpression);
                EndIf;
            EndDo;
            
            // If the original container was a Vector, ensure the final result is converted back
            If Node.Type = "Vector" Then
                ResultExpression = WrapInList("vec", ResultExpression);
            EndIf;
            
            Return ResultExpression;
        EndIf;
    EndIf;
EndFunction

// Checks if the node is a non-empty List or Vector.
// Necessary for quasiquoting evaluation logic.
Function IsPair(Node)
    If TypeOf(Node) <> Type("Structure") Then
        Return False;
    EndIf;
    
    If Node.Type = "List" OR Node.Type = "Vector" Then
        Return Node.Value.Count() > 0;
    EndIf;
    
    Return False;
EndFunction

// Executes the function associated with the operator identifier.
//
// Parameters:
//   Operator    - String - The internal identifier of the function (e.g., "ADD", "MUL").
//   Args        - Array  - A list of already evaluated arguments.
//   Environment - Map    - The execution context.
//   Debug       - String - Output parameter for tracing.
//
// Returns:
//   Any - The result of the operation.
// Raises:
//   Exception - If the operator is unknown.
Function Apply(Operator, Args, Environment, Debug)
    If Operator = "ADD" Then Sum = 0;
        For Each Arg In Args Do
            Sum = Sum + Arg.Value;
        EndDo;
        Return New Structure("Type, Value", "Number", Sum);
    ElsIf Operator = "SUB" Then
        If Args.Count() = 0 Then Return CreateError("Apply", "Wrong number of args (0) passed to -"); EndIf;
        If Args.Count() = 1 Then Return New Structure("Type, Value", "Number", -Args[0].Value); EndIf;
        Result = Args[0].Value;
        For i = 1 To Args.UBound() Do
            Result = Result - Args[i].Value;
        EndDo;
        Return New Structure("Type, Value", "Number", Result);
    ElsIf Operator = "MUL" Then Product = 1;
        For Each Arg In Args Do
            Product = Product * Arg.Value;
        EndDo;
        Return New Structure("Type, Value", "Number", Product);
    ElsIf Operator = "DIV" Then
        If Args.Count() = 0 Then Return CreateError("Apply", "Wrong number of args (0) passed to /"); EndIf;
        If Args.Count() = 1 Then Return New Structure("Type, Value", "Number", 1 / Args[0].Value); EndIf;
        Result = Args[0].Value;
        For i = 1 To Args.UBound() Do
            Result = Result / Args[i].Value;
        EndDo;
        Return New Structure("Type, Value", "Number", Result);
    ElsIf Operator = "NOT" Then
        // If the argument is nil (or false), 'not' returns true
        // If the argument is anything else, 'not' returns false
        // Check if the argument is "false" and return the inverted result
        Return New Structure("Type, Value", "Boolean", (Args[0].Type = "Nil") OR (Args[0].Type = "Boolean" AND Args[0].Value = FALSE));
    ElsIf Operator = "EQ" Then
        Return IsEqual(Args[0], Args[1]);
    ElsIf Operator = "NE" Then
        Return New Structure("Type, Value", "Boolean", TypeOf(Args[0].Value) = TypeOf(Args[1].Value) AND Args[0].Value <> Args[1].Value);
    ElsIf Operator = "LT" Then
        Return New Structure("Type, Value", "Boolean", TypeOf(Args[0].Value) = TypeOf(Args[1].Value) AND Args[0].Value < Args[1].Value);
    ElsIf Operator = "LE" Then
        Return New Structure("Type, Value", "Boolean", TypeOf(Args[0].Value) = TypeOf(Args[1].Value) AND Args[0].Value <= Args[1].Value);
    ElsIf Operator = "GT" Then
        Return New Structure("Type, Value", "Boolean", TypeOf(Args[0].Value) = TypeOf(Args[1].Value) AND Args[0].Value > Args[1].Value);
    ElsIf Operator = "GE" Then
        Return New Structure("Type, Value", "Boolean", TypeOf(Args[0].Value) = TypeOf(Args[1].Value) AND Args[0].Value >= Args[1].Value);
    ElsIf Operator = "LIST" Then
        // The 'list' function collects all arguments into a list
        // Since 'Args' already holds the arguments, we simply return it as a list
        Return New Structure("Type, Value", "List", Args);
    ElsIf Operator = "LISTQ" Then
        // Check if the argument is a list
        Return New Structure("Type, Value", "Boolean", Args[0].Type = "List");
    ElsIf Operator = "EMPTYQ" Then
        // Check if the value array inside the node is empty
        Return New Structure("Type, Value", "Boolean", Args[0].Value.Count() = 0);
    ElsIf Operator = "COUNT" Then
        // If the argument is nil (or Undefined/Null), its size is 0
        If Args[0].Type = "Nil" OR Args[0].Value = Undefined Then
            Return New Structure("Type, Value", "Number", 0);
        ElsIf Args[0].Type = "List" OR Args[0].Type = "Vector" Then
            // Call Count() only if the type is 'List' or 'Vector'
            Return New Structure("Type, Value", "Number", Args[0].Value.Count());
        Else
            // Report an error: 'count' expects a list, but received a number or other type
            Return CreateError("Apply.COUNT", "Argument must be a list or nil, not %1", Args[0].Type);
        EndIf;
	ElsIf Operator = "CONS" Then
    	If Args.Count() <> 2 Then
        	Return CreateError("Apply.CONS", "Wrong number of args (%1) passed to cons", Args.Count());
    	EndIf;
    	ElementNode = Args[0];
    	CollectionNode = Args[1];
    	If CollectionNode.Type <> "List" AND CollectionNode.Type <> "Vector" Then
        	Return CreateError("Apply.CONS", "Second argument to cons must be a list or vector, not %1", CollectionNode.Type);
    	EndIf;
    	// Create a new array for the resulting List
   	 	NewArray = New Array;
    	// 1. Add the element to the beginning
    	NewArray.Add(ElementNode); 
    	// 2. Copy all elements from the original collection
    	For Each Item In CollectionNode.Value Do
        	NewArray.Add(Item);
    	EndDo;
    	// cons ALWAYS returns type "List", even if the input was a "Vector"
    	Return New Structure("Type, Value", "List", NewArray);
	ElsIf Operator = "CONCAT" Then
    	// Create the resulting array
    	ResultArray = New Array;
    	// Iterate through all passed lists/vectors
    	For Each CollectionNode In Args Do
        	If CollectionNode.Type <> "List" AND CollectionNode.Type <> "Vector" Then
            	Return CreateError("Apply.CONCAT", "Arguments to concat must be lists or vectors, not %1", CollectionNode.Type);
        	EndIf;
        	// Extract elements and add them to the common array
        	For Each Item In CollectionNode.Value Do
            	ResultArray.Add(Item);
        	EndDo;
    	EndDo;
    	// concat ALWAYS returns type "List"
    	Return New Structure("Type, Value", "List", ResultArray);
	ElsIf Operator = "VEC" Then
        If Args.Count() <> 1 Then
            Return CreateError("Apply.VEC", "Wrong number of args (%1) passed to vec", Args.Count());
        EndIf;
        CollectionNode = Args[0];
        If CollectionNode.Type = "Vector" Then
            Return CollectionNode;
        ElsIf CollectionNode.Type = "List" Then
            // Convert List to Vector by changing the Type tag 
            // but keeping the underlying BSL Array of values
            Return New Structure("Type, Value", "Vector", CollectionNode.Value);
        Else
            Return CreateError("Apply.VEC", "Argument to vec must be a list or vector, not %1", CollectionNode.Type);
		EndIf;
	ElsIf Operator = "ATOM" Then
        // Create a new atom (mutable container)
        If Args.Count() = 0 Then
            Return CreateError("Apply.ATOM", "Wrong number of args (0) passed to atom");
        EndIf;
        // Use a structure with a "Value" key as a technical container
        // This ensures mutability (pass by reference in 1C)
        Container = New Structure("Value", Args[0]);
        // Return an AST node of type "Atom"
        Return New Structure("Type, Value", "Atom", Container);
    ElsIf Operator = "ATOMQ" Then
        // Predicate atom?
        If Args.Count() = 0 Then
            Return CreateError("Apply.ATOMQ", "Wrong number of args (0) passed to atom?");
        EndIf;
        IsAtom = False;
        // Verify that it is an AST Structure and its Type is "Atom"
        If TypeOf(Args[0]) = Type("Structure") Then
            If Args[0].Property("Type") AND Args[0].Type = "Atom" Then
                IsAtom = True;
            EndIf;
        EndIf;
        Return New Structure("Type, Value", "Boolean", IsAtom);
    ElsIf Operator = "DEREF" Then
        // Extract the value from the container
        Return Args[0].Value.Value;
    ElsIf Operator = "RESET" Then
        // 1. Check that the first argument is indeed an atom
        If NOT (TypeOf(Args[0]) = Type("Structure") AND Args[0].Property("Type") AND Args[0].Type = "Atom") Then
            Return CreateError("Apply.RESET", "First argument must be an atom");
        EndIf;
        // 2. Change the value in the technical container
        Args[0].Value.Value = Args[1];
        // 3. reset! returns the new value according to the MaL standard
        Return Args[0].Value.Value;
    ElsIf Operator = "SWAP" Then
        // Args[0] - AtomNode, Args[1] - Function Node, Args[2...] - Remaining arguments for this function
        // 1. Validations
        If Args.Count() < 2 Then
            Return CreateError("Apply.SWAP", "Requires at least 2 arguments (atom and function)");
        EndIf;
        If Args[0].Type <> "Atom" Then
            Return CreateError("Apply.SWAP", "First argument must be an atom");
        EndIf;
        // 2. Prepare arguments for the function call
        // The new argument list will be: [CurrentAtomValue, AdditionalArg1, AdditionalArg2...]
        NewFuncArgs = New Array;
        NewFuncArgs.Add(Args[0].Value.Value); // Extract data from the container
        // Add the remaining arguments passed to swap!
        For i = 2 To Args.Count() - 1 Do
            NewFuncArgs.Add(Args[i]);
        EndDo;
        // 3. Compute the new value
        NewValue = Undefined;
        // CASE A: It's a built-in function (just a string in our system)
        If TypeOf(Args[1]) = Type("String") Then
            NewValue = Apply(Args[1], NewFuncArgs, Environment, Debug);
            // CASE B: It's a user-defined function (structure with type "Function")
		ElsIf TypeOf(Args[1]) = Type("Structure") AND Args[1].Property("Type") AND Args[1].Type = "Function" Then
			// For user-defined functions (fn*), we need to create an environment and execute the body
            // This repeats the logic from the Else block of our Exec function
			// We simply call the centralized function, passing the prepared arguments
        	NewValue = InvokeFunction(Args[1], NewFuncArgs, Debug);
		Else
            Return CreateError("Apply.SWAP", "Second argument must be a function");
        EndIf;
        // 4. Check for errors during computation
        If IsError(NewValue) Then Return NewValue; EndIf;
        // 5. Mutation: write the result back to the atom
        Args[0].Value.Value = NewValue;
        // 6. Return the new value
        Return Args[0].Value.Value;
    ElsIf Operator = "EVAL" Then
        GlobalEnvironment = GetGlobalEnvironment(Environment);
        Return Exec(Args[0], GlobalEnvironment, Debug);
    ElsIf Operator = "STR" Then
        // Concatenates the string representations of arguments. If an argument is a string, print it without quotes
        Result = "";
        For Each Arg In Args Do
            If Arg.Type = "String" Then
                Result = Result + Arg.Value;
            Else
                Result = Result + PrintForm(Arg);
            EndIf;
        EndDo;
        Return New Structure("Type, Value", "String", Result);
    ElsIf Operator = "PRSTR" Then
        // Uses PrintForm for each argument and joins them with spaces
        Result = "";
        For i = 0 To Args.Count() - 1 Do
            Result = Result + PrintForm(Args[i]);
            If i < Args.Count() - 1 Then Result = Result + " "; EndIf;
        EndDo;
        Return New Structure("Type, Value", "String", Result);
    ElsIf Operator = "PRINT" Then
        //Uses PrintForm for each argument, joins them with spaces, and prints with a newline
        // Returns nil and prints to Debug
        ResultString = "";
        For I = 0 To Args.Count() - 1 Do
            ResultString = ResultString + PrintForm(Args[I]);
            If I < Args.Count() - 1 Then ResultString = ResultString + " "; EndIf;
        EndDo;
        Debug = Debug + ResultString + Chars.CR;
        Return New Structure("Type, Value", "Nil", Undefined);
    ElsIf Operator = "PRINTLN" Then
        // Uses PrintForm for each argument, joins them with spaces, and prints with a newline to standard output.
        // Returns nil and prints to Debug
        ResultString = "";
        For I = 0 To Args.Count() - 1 Do
            Arg = Args[I];
            If Arg.Type = "String" Then
                ResultString = ResultString + Arg.Value;
            Else
                ResultString = ResultString + PrintForm(Arg);
            EndIf;
            If I < Args.Count() - 1 Then ResultString = ResultString + " "; EndIf;
        EndDo;
        Debug = Debug + ResultString + Chars.CR;
        Return New Structure("Type, Value", "Nil", Undefined);
    ElsIf Operator = "READSTRING" Then
        If Args.Count() = 0 Then
            Return CreateError("Apply.read-string", "Expected a string argument");
        EndIf;
        // Call the main reader
        // Important: Read usually returns a list of forms (since a file can have many expressions),
        // but read-string in MaL usually reads only the FIRST form.
        // If Read(Input) returns a Structure with an array of forms, we take the first one.
        AST = Read(Args[0].Value, Debug);
        // If Read returned a List of multiple forms, read-string takes only the first
        If AST.Type = "List" AND AST.Value.Count() > 0 Then
            Return AST.Value[0];
        Else
            Return AST;
        EndIf;
    ElsIf Operator = "SLURP" Then
        If Args.Count() = 0 Then
            Return CreateError("Apply.SLURP", "Expected a file path argument");
        EndIf;
        Try
            Reader = New TextReader(Args[0].Value, TextEncoding.UTF8);
            InputText = Reader.Read();
            Reader.Close();
            // Return the result as an AST node of type String
            Return New Structure("Type, Value", "String", InputText);
        Except
            Return CreateError("Apply.SLURP", "Could not read file: %1" + Chars.CR + ErrorDescription(), Args[0].Value);
        EndTry;
    ElsIf Operator = "LOADFILE" Then
        // 1. Read file content
        FileContentNode = Apply("SLURP", Args, Environment, Debug);
        If FileContentNode.Type = "Error" Then Return FileContentNode; EndIf;
        GlobalEnvironment = GetGlobalEnvironment(Environment);
        // 2. Parse content into an AST (which is a List containing all forms)
        AST = Read(FileContentNode.Value, Debug);
        // 3. IMPORTANT: Iterate through each form in the file and evaluate them individually
        // This matches the logic in MaL_Step_6
        Result = New Structure("Type, Value", "Nil", Undefined);
        For Each Expression In AST.Value Do
            Result = Exec(Expression, GlobalEnvironment, Debug);
            // If an error occurs during execution, stop and return it
            If IsError(Result) Then Return Result; EndIf;
        EndDo;
        // 4. Per your requirement, load-file should return nil after execution
        Return New Structure("Type, Value", "Nil", Undefined);
    Else
        Return CreateError("Apply", "Unknown function %1", Operator);
    EndIf;
EndFunction

// Recursively compares two AST nodes for structural and value equality.
//
// Parameters:
//   Node1 - Structure - The first node.
//   Node2 - Structure - The second node.
//
// Returns:
//   Structure - A Boolean Node containing the result.
Function IsEqual(Node1, Node2)
    // 1. First, compare the types
    If Node1.Type <> Node2.Type Then
        Return New Structure("Type, Value", "Boolean", FALSE);
    EndIf;
    
    // 2. If it is a list, compare its contents (recursively)
    If Node1.Type = "List" Then
        // Compare the number of elements
        If Node1.Value.Count() <> Node2.Value.Count() Then
            Return New Structure("Type, Value", "Boolean", FALSE);
        EndIf;
        // Compare each list element pairwise
        For i = 0 To Node1.Value.Count() - 1 Do
            If NOT IsEqual(Node1.Value[i], Node2.Value[i]).Value Then
                // If any element doesn't match, return
                Return New Structure("Type, Value", "Boolean", FALSE);
            EndIf;
        EndDo;
        //All elements match
        Return New Structure("Type, Value", "Boolean", TRUE);
    EndIf;
    
    // 3. For atomic types (Number, String, Boolean, Nil), simply compare their values
    Return New Structure("Type, Value", "Boolean", (Node1.Value = Node2.Value));
EndFunction

// Constructs a structured error message
// Format: <Function Name>: <Description> <Value>
Function CreateError(FunctionName, Message, Value = Undefined)
    // Convert value to string (handle AST nodes)
    StringValue = "";
    If TypeOf(Value) = Type("Structure") AND Value.Property("Value") Then
        StringValue = String(Value.Value);
    Else
        StringValue = String(Value);
    EndIf;
    ErrorText = FunctionName + ": " + ?(StrFind(Message, "%1"), StrTemplate(Message, " '" + StringValue + "'"), Message);
    Return New Structure("Type, Value", "Error", ErrorText);
EndFunction

// Checks if the given value is an error structure.
// Returns True if it is an error, False otherwise.
Function IsError(Result)
    If TypeOf(Result) <> Type("Structure") Then
        Return False;
    EndIf;
    
    If NOT Result.Property("Type") Then
        Return False;
    EndIf;
    
    Return Result.Type = "Error";
EndFunction

#EndRegion

#Region PRINT

// Finalizes the output by converting the result of 'Exec' into a string format
// suitable for the user interface.
//
// Parameters:
//   AST   - Array  - Abstract Syntax Tree (AST) structures.
//   Debug - String - The debugging trace collected during the 'Exec' phase.
//
// Returns:
//   String - The final string representation to be displayed in the UI.
Function Print(AST, Debug)
    Return PrintForm(AST);
EndFunction

// Recursive function to serialize AST back into S-expression string representation.
Function PrintForm(Node)
    // 1. If it's an Array (raw list content), process it recursively
    If TypeOf(Node) = Type("Array") Then
        Result = "(";
        
        For I = 0 To Node.Count() - 1 Do
            // Recurse into each element
            Result = Result + PrintForm(Node[I]);
            
            // Add space between elements, but not after the last one
            If I < Node.Count() - 1 Then
                Result = Result + " ";
            EndIf;
        EndDo;
        
        Result = Result + ")";
        Return Result;
        
        // 2. If it's a Node (Structure), dispatch based on Type
    ElsIf TypeOf(Node) = Type("Structure") Then
        
        If Node.Type = "List" Then
            // Recurse into the array stored inside the list node
            Return PrintForm(Node.Value);
            
        ElsIf Node.Type = "Vector" Then
            Result = "[";
            ArrayValue = Node.Value;
            For I = 0 To ArrayValue.Count() - 1 Do
                Result = Result + PrintForm(ArrayValue[I]);
                If I < ArrayValue.Count() - 1 Then
                    Result = Result + " ";
                EndIf;
            EndDo;
            Return Result + "]";
            
        ElsIf Node.Type = "HashMap" Then
            // Format the hash map with curly braces
            Result = "{";
            ArrayValue = Node.Value;
            For I = 0 To ArrayValue.Count() - 1 Do
                Result = Result + PrintForm(ArrayValue[I]);
                // Add a space between elements
                If I < ArrayValue.Count() - 1 Then
                    Result = Result + " ";
                EndIf;
            EndDo;
            Return Result + "}";
            
        ElsIf Node.Type = "String" Then
            StringValue = Node.Value;
            StringValue = StrReplace(StringValue, "\", "\\");
            StringValue = StrReplace(StringValue, """", "\""");
            StringValue = StrReplace(StringValue, Chars.LF, "\n");
            // Return the string wrapped in double quotes
            Return """" + StringValue + """";
        ElsIf Node.Type = "Number" Then
            // Format numeric values (NZ= clears grouping, NDS='.' sets decimal separator)
            Return Format(Node.Value, "NZ=;NGS='" + Chars.NBSp + "';NDS='.'");
            
        ElsIf Node.Type = "Keyword" Then
            // Just return ":a" as is
            Return Node.Value;
            
        ElsIf Node.Type = "Boolean" Then
            Return ?(Node.Value, "true", "false");
            
        ElsIf Node.Type = "Nil" Then
            Return "nil";
            
        ElsIf Node.Type = "Function" Then
            Return "<function>";
        ElsIf Node.Type = "Atom" Then
            // Extract the value from our technical container (Value.Value)
            // and recursively print it, wrapped in an (atom ...) structure
            Return "(atom " + PrintForm(Node.Value.Value) + ")";
        Else
            // Default: treat as Symbol
            Return Node.Value;
        EndIf;
        
    Else
        If Node.Property("Value") Then
            Return String(Node.Value);
        Else
            Return "<" + Node.Type + ">";
        EndIf;
    EndIf;
EndFunction

// Prints a hierarchical, multi-line representation of the AST for debugging.
Function PrintDebug(Node, Indent = 0)
    // Prepare indentation string
    IndentStr = "";
    For i = 1 To Indent Do IndentStr = IndentStr + "  "; EndDo;
    
    Result = "";
    
    // The function expects a Node (Structure)
    If TypeOf(Node) = Type("Structure") Then
        
        // Handle sequential collections: Lists and Vectors
        If Node.Type = "List" OR Node.Type = "Vector" Then
            // Choose brackets based on the collection type
            OpenBracket = ?(Node.Type = "List", "(", "[");
            CloseBracket = ?(Node.Type = "List", ")", "]");
            
            Result = IndentStr + Node.Type + " : " + OpenBracket + Chars.LF;
            
            // Node.Value for these types is a BSL Array
            // Iterate through the array and recurse for each item
            For Each Item In Node.Value Do
                Result = Result + PrintDebug(Item, Indent + 1);
            EndDo;
            
            Result = Result + IndentStr + CloseBracket + Chars.LF;
            
            // Handle associative collections: HashMaps
        ElsIf Node.Type = "HashMap" Then
            Result = IndentStr + "HashMap : {" + Chars.LF;
            
            // In your implementation, Node.Value is a flat Array [key1, val1, key2, val2...]
            // Both keys and values are Nodes (Structures)
            ArrayValue = Node.Value;
            For I = 0 To ArrayValue.Count() - 1 Do
                // Determine if the current element is a Key or a Value
                IsKey = (I % 2 = 0);
                Prefix = ?(IsKey, "  Key   ->", "  Value ->");
                
                // Print label and recurse for the element
                Result = Result + IndentStr + Prefix;
                Result = Result + PrintDebug(ArrayValue[I], Indent + 2);
            EndDo;
            
            Result = Result + IndentStr + "}" + Chars.LF;
            
            // Handle Atoms (mutable state containers from Step 6)
        ElsIf Node.Type = "Atom" Then
            Result = IndentStr + "Atom (Ref) ->" + Chars.LF;
            // Recursively print the current value contained within the atom
            Result = Result + PrintDebug(Node.Value, Indent + 1);
            
        Else
            // Handle basic scalar types (Number, Symbol, String, Boolean, Nil)
            // Ensure Lisp-style 'nil' is printed instead of empty string for Null values
            ValStr = ?(Node.Value = Null, "nil", String(Node.Value));
            Result = IndentStr + Node.Type + " : " + ValStr + Chars.LF;
        EndIf;
        
    Else
        // Fallback for cases where the input is not a valid Node structure
        Result = IndentStr + "ERROR (Not a Node structure): " + String(Node) + Chars.LF;
    EndIf;
    
    Return Result;
EndFunction

#EndRegion


