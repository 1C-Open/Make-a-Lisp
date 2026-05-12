// =============================================================================
// MaL (Make-a-Lisp) Interpreter - Step 4: If Fn Do
// =============================================================================
// This module implements the control flow and I/O core of the interpreter:
// 1. Implements core special forms ('if', 'do', 'fn*') for branching,
//    sequencing, and function definition with lexical closures.
// 2. Provides I/O primitives ('prn', 'println', 'str', 'pr-str') with
//    robust string escaping support for consistent data serialization.
// =============================================================================

// Main entry point for Step 4 of the Make-a-Lisp interpreter.
// Evaluates the abstract syntax tree in a basic environment.
//
// Parameters:
//   Input - String - The raw Lisp code entered by the user.
//   Debug - String - An output parameter containing the execution trace.
//
// Returns:
//   String - The final result of the REPL pipeline (serialized string representation).
Function MaL_Step_4(Input, Debug) Export
    AST = Read(Input, Debug);
    GlobalEnvironment = CreateGlobalEnvironment();
    InitializeCore(GlobalEnvironment);
    Output = "";
    For Each Expression In AST.Value Do
        Result = Exec(Expression, GlobalEnvironment, Debug);
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
            //Else
            //    // Evaluate all elements recursively
            //    EvaluatedList = New Array;
            //    For Each Item In NodesArray Do
            //        EvaluatedItem = Exec(Item, Environment, Debug);
            //        If IsError(EvaluatedItem) Then Return EvaluatedItem; EndIf;
            //        EvaluatedList.Add(EvaluatedItem);
            //    EndDo;
            //
            //    Operator = EvaluatedList[0]; // The first element is the function identifier
            //    Args = New Array; // Create an array of arguments (everything except the first element)
            //    For i = 1 To EvaluatedList.Count() - 1 Do
            //        Args.Add(EvaluatedList[i]);
            //    EndDo;
            //
            //    Return Apply(Operator, Args); // Apply the operator to the arguments
            //EndIf;
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
        Else
            Operator = Exec(AST.Value[0], Environment, Debug);
            // Check: is it a structure, and does it have a 'Type' property?
            If TypeOf(Operator) = Type("Structure") AND Operator.Property("Type") Then
                // Check if this is an 'fn*' function
                If Operator.Type = "Function" Then
                    LocalEnvironment = CreateEnvironment(Operator.Environment);
                    Params = Operator.Params.Value;
                    ArgsCount = AST.Value.Count() - 1;
                    For i = 0 To Params.Count() - 1 Do
                        ParamName = Params[i].Value;
                        If ParamName = "&" Then
                            // Check if there is a variable name after '&'
                            If i + 1 < Params.Count() Then
                                RestSymbol = Params[i + 1].Value;
                                RestArgs = New Array;
                                // Collect all remaining arguments into an array
                                For j = i + 1 To ArgsCount Do
                                    RestArgs.Add(Exec(AST.Value[j], Environment, Debug));
                                EndDo;
                                // Wrap in a List (as required by MaL for & more)
                                ListNode = New Structure("Type, Value", "List", RestArgs);
                                SetEnvironment(LocalEnvironment, RestSymbol, ListNode);
                                Break; // Stop binding arguments
                            EndIf;
                        Else
                            // Standard argument binding
                            If i < ArgsCount Then
                                ArgValue = Exec(AST.Value[i + 1], Environment, Debug); // Evaluate arguments
                                SetEnvironment(LocalEnvironment, ParamName, ArgValue); // Store in the local environment
                            EndIf;
                        EndIf;
                    EndDo;
                    Return Exec(Operator.Body, LocalEnvironment, Debug);
                EndIf;
            EndIf;
            
            // Check if the operator is valid
            // Assuming "Operator" should be a function or a built-in symbol
            If IsError(Operator) Then
                // This is where we catch your specific case (abc 1 2)
                Debug = Debug + Operator.Value + Chars.CR;
                Return Operator;
            EndIf;
            
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
            
            Return Apply(Operator, Args, Debug); // Apply the operator to the arguments
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

// Initializes the global environment with base arithmetic operations.
//
// Returns:
//   Map - A lookup table where symbols (e.g., "+") are mapped to
//         internal operator identifiers (e.g., "ADD").
Function CreateGlobalEnvironment()
    // Create the top-level environment (it has no parent, so Undefined)
    Return CreateEnvironment(Undefined);
EndFunction

// Inserts a Key-Value pair into the environment's Data map
Procedure SetEnvironment(Environment, Symbol, Value)
    Environment.Data.Insert(Symbol, Value);
EndProcedure

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
    // I/O and String manipulation
    SetEnvironment(Environment, "prn", "PRINT");
    SetEnvironment(Environment, "println", "PRINTLN");
    SetEnvironment(Environment, "pr-str", "PRSTR");
    SetEnvironment(Environment, "str", "STR");
EndProcedure

// Executes the mathematical function associated with the operator identifier.
//
// Parameters:
//   Operator - String - The internal identifier of the function (e.g., "ADD", "MUL").
//   Args     - Array  - A list of already evaluated arguments.
//   Debug    - String - Output parameter for tracing.
//
// Returns:
//   Number - The result of the operation.
// Raises:
//   Exception - If the operator is unknown.
Function Apply(Operator, Args, Debug)
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
    // 1. Extract types for comparison
    Type1 = Node1.Type;
    Type2 = Node2.Type;
    
    // In MaL, Lists and Vectors are considered equivalent if they contain the same elements
    If Type1 <> Type2 Then
        // Check if both nodes are sequential collections
        IsSeq1 = (Type1 = "List" OR Type1 = "Vector");
        IsSeq2 = (Type2 = "List" OR Type2 = "Vector");
        
        // If one is a sequence and the other is not, they cannot be equal
        If NOT (IsSeq1 AND IsSeq2) Then
            Return New Structure("Type, Value", "Boolean", FALSE);
        EndIf;
    EndIf;
    
    // 2. Compare sequential collections (Lists and Vectors)
    If Type1 = "List" OR Type1 = "Vector" OR Type2 = "List" OR Type2 = "Vector" Then
        // Compare the number of elements first for efficiency
        If Node1.Value.Count() <> Node2.Value.Count() Then
            Return New Structure("Type, Value", "Boolean", FALSE);
        EndIf;
        
        // Compare each element pair recursively
        For i = 0 To Node1.Value.Count() - 1 Do
            SubEqual = IsEqual(Node1.Value[i], Node2.Value[i]);
            If NOT SubEqual.Value Then
                // Return immediately if any pair of elements does not match
                Return New Structure("Type, Value", "Boolean", FALSE);
            EndIf;
        EndDo;
        
        // All elements matched in order
        Return New Structure("Type, Value", "Boolean", TRUE);
    EndIf;
    
    // 3. Handle HashMap equality (Step 9/Optional)
    If Type1 = "HashMap" Then
        // HashMaps must have the same number of elements
        If Node1.Value.Count() <> Node2.Value.Count() Then
            Return New Structure("Type, Value", "Boolean", FALSE);
        EndIf;
        
        // Note: For full HashMap support, you should compare keys/values
        // regardless of their order in the flat array[cite: 105, 106].
        // Implementing this requires a way to look up keys in the other map.
    EndIf;
    
    // 4. Atomic types comparison (Number, String, Symbol, Boolean, Nil)
    // BSL's "=" operator works correctly for these basic types
    Return New Structure("Type, Value", "Boolean", (Node1.Value = Node2.Value));
EndFunction