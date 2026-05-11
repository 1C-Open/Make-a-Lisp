// =============================================================================
// MaL (Make-a-Lisp) Interpreter - Step 3: Environments
// =============================================================================
// This module upgrades the interpreter with hierarchical scope management:
// 1. Environment: Implements a linked structure with 'Outer' pointers for scope chaining.
// 2. Scope Resolution: Implements recursive symbol lookup (lexical scoping).
// 3. Special Forms: Implements 'def!' for environment mutation and 'let*' for nested lexical scope.
// 4. Global Context: Establishes the global environment for base arithmetic operators.
// =============================================================================

// Main entry point for Step 3 of the Make-a-Lisp interpreter.
// Evaluates the abstract syntax tree in a basic environment.
//
// Parameters:
//   Input - String - The raw Lisp code entered by the user.
//   Debug - String - An output parameter containing the execution trace.
//
// Returns:
//   String - The final result of the REPL pipeline (serialized string representation).
Function MaL_Step_3(Input, Debug) Export
    AST = Read(Input, Debug);
    Environment = CreateGlobalEnvironment();
    Output = "";
    For Each Expression In AST.Value Do
        Result = Exec(Expression, Environment, Debug);
        Output = Output + Print(Result, Debug) + Chars.CR;
    EndDo;
    Return Output;
EndFunction

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
    Debug = "TOKENS: " + Chars.CR;
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
			ElsIf NodesArray[1].Value.Count() % 2 <> 0 Then
    			Return CreateError("Exec", "let* bindings must have an even number of elements");
			EndIf;
            LocalEnvironment = CreateEnvironment(Environment); // Create a new child environment
            BindingsArray = NodesArray[1].Value; // Get the array of bindings (list of pairs)
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
        Else
            // Evaluate all elements recursively
            EvaluatedList = New Array;
            For Each Item In NodesArray Do
                EvaluatedItem = Exec(Item, Environment, Debug);
                If IsError(EvaluatedItem) Then Return EvaluatedItem; EndIf;
                EvaluatedList.Add(EvaluatedItem);
            EndDo;
            
            Operator = EvaluatedList[0]; // The first element is the function identifier
            Args = New Array; // Create an array of arguments (everything except the first element)
            For i = 1 To EvaluatedList.Count() - 1 Do
                Args.Add(EvaluatedList[i]);
            EndDo;
            
            Return Apply(Operator, Args); // Apply the operator to the arguments
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
//
// Parameters:
//   SymbolName - String - The symbol representing the macro (e.g., "quote", "deref").
//   Form - Structure - The AST node to wrap.
//
// Returns:
//   Structure - A new List node containing the Symbol and the Form.
Function WrapInList(SymbolName, Form)
    // Create a list: (SymbolName Form)
    Elements = New Array;
    Elements.Add(New Structure("Type, Value", "Symbol", SymbolName));
    Elements.Add(Form);
    
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

// Universal environment constructor
Function CreateEnvironment(Outer = Undefined)
    Environment = New Structure("Data, Outer");
    Environment.Data = New Map;
    Environment.Outer = Outer; // Reference to the parent environment
    Return Environment;
EndFunction

// Inserts a Key-Value pair into the environment's Data map
Procedure SetEnvironment(Environment, Symbol, Value)
    Environment.Data.Insert(Symbol, Value);
EndProcedure

// Initializes the global environment with base arithmetic operations.
//
// Returns:
//   Map - A lookup table where symbols (e.g., "+") are mapped to
//         internal operator identifiers (e.g., "ADD").
Function CreateGlobalEnvironment()
    // Create the top-level environment (it has no parent, so Undefined)
    GlobalEnvironment = CreateEnvironment(Undefined);
    // We register the base arithmetic operations
    SetEnvironment(GlobalEnvironment, "/", "DIV");
    SetEnvironment(GlobalEnvironment, "*", "MUL");
    SetEnvironment(GlobalEnvironment, "-", "SUB");
    SetEnvironment(GlobalEnvironment, "+", "ADD");
    Return GlobalEnvironment;
EndFunction

// Recursive search for a variable in the environment chain
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

// Executes the mathematical function associated with the operator identifier.
//
// Parameters:
//   Operator - String - The internal identifier of the function (e.g., "ADD", "MUL").
//   Args     - Array  - A list of already evaluated arguments.
//
// Returns:
//   Number - The result of the operation.
// Raises:
//   Exception - If the operator is unknown.
Function Apply(Operator, Args)
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
    Else
        Return CreateError("Apply", "Unknown function %1", Operator);
    EndIf;
EndFunction