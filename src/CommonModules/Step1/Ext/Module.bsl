// =============================================================================
// MaL (Make-a-Lisp) Interpreter - Step 1: Read and Print
// =============================================================================
// This module implements the foundational layer of the Lisp interpreter:
// 1. Tokenization: Converting raw string input into a list of tokens.
// 2. Reading: Parsing tokens into Abstract Syntax Tree (AST) structures.
// 3. Printing: Serializing AST back to string representation (pr_str)
//    and debugging format.
// =============================================================================

// Main entry point for Step 1 of the Make-a-Lisp interpreter.
// Executes the Read-Eval-Print Loop for a given input string.
//
// Parameters:
//   Input - String - The raw Lisp code entered by the user.
//   Debug - String - An output parameter containing the execution trace.
//
// Returns:
//   String - The final result of the REPL pipeline (serialized string representation).
Function MaL_Step_1( Input, Debug ) Export
	AST = Read(Input, Debug);
	Result = Exec(AST, Debug);
	Output = "";
	For Each Form In Result.Value Do
		Output = Output + PrintForm(Form) + Chars.CR;	
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
//   String - The processed input string.
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

// Orchestrates the evaluation of the read input. 
// In future stages, this function will contain the central logic for interpreting 
// Lisp S-expressions. It calls 'Read' to initialize the data and populates 
// the debug info.
// 
// Parameters:
//   AST   - Array  - Abstract Syntax Tree (AST) structures.
//   Debug - String - An output parameter used to store execution trace details.
//
// Returns:
//   AST - The result of the evaluation (currently delegates to 'Read').
Function Exec(AST, Debug) 
	Return AST;
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
	Length = StrLen( InputText );
	Pos = 1;
	
	While Pos <= Length Do
		Char = Mid(InputText,Pos,1);
		// 1. Skip spaces and commas
		If StrFind(Delimiters,Char) > 0 Then
			Pos = Pos + 1;
		    Continue;
		EndIf;
        // 2. Skip comments (everything after ;)
		If Char = ";" Then
			While Pos <= Length AND Mid(InputText,Pos,1) <> Chars.LF Do
				Pos = Pos + 1;
			EndDo;
			Pos = Pos + 1;
		    Continue;
		EndIf;
		// 3. Handle special single-character tokens
		// according to MaL standard: ~@ () [] {} ' ` ^ @
		If StrFind("()[]{}'`^~@", Char) > 0 Then
		// Special case for ~@
			NextChar = ?(Pos+1 <= Length, Mid(InputText,Pos+1,1), "");
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
				If Char="""" Then String = String + Char; FlagOpenString = FALSE; Break; EndIf;
				If Char="\" Then 
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
			Tokens.Add(?(FlagOpenString,"Tokenize: Unbalanced String: "+String, String));
			Pos = Pos + 1;
			Continue;
		EndIf;	
		// 5. Handle atoms		
		Start = Pos;	
		While Pos <= Length Do
			NextChar = Mid(InputText, Pos, 1);
			If StrFind(Delimiters+" ,;()[]{}'`^~@""", NextChar) > 0 Then
				Break;
			EndIf;
			Pos = Pos + 1;
		EndDo;
		Tokens.Add(Mid(InputText, Start, Pos-Start));
	EndDo;
	
	Return Tokens;
EndFunction

// Dispatches parsing to either List or Atom handlers based on the current token.
Function ReadForm(Reader)
    Token = Peek(Reader);
	If    Token = "(" Then Return ReadList(Reader);
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
        Meta = ReadForm(Reader);   // Read metadata
        Data = ReadForm(Reader);   // Read the object itself (list, symbol, etc.)
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
        If NodesArray.Count() % 2 <> 0 And NodesArray[NodesArray.Count()-1].Type <> "Error" Then
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
	ElsIf Left(Token,1)="""" Then
		Return New Structure("Type, Value", "String", Mid(Token,2,StrLen(Token)-2))	
	Else
	// Default: everything else is a Symbol
        Return New Structure("Type, Value", "Symbol", Lower(Token));
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
	If    Char = "-" Then Sign = -1; Position = 2;
	ElsIf Char = "+" Then            Position = 2;
	EndIf;
	//Main parsing loop
	While Position <= StrLen(Token) Do
		Char = Mid(Token, Position, 1);
		If Char = "." Then
			If DotEcountered Then
				Return FALSE; // Second dot
			EndIf;
			DotEcountered = TRUE;
		ElsIf Find("0123456789",Char) > 0 Then
			Digit = Number(Char);
			If NOT DotEcountered Then
				IntegerPart = IntegerPart*10 + Digit;
			Else 	
		        FractionalPart = FractionalPart*10 + Digit;
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

// Constructs a structured error message
// Format: <Function Name>: <Description> <Value>
Function CreateError(FunctionName, Message, Value=Undefined)
    // Convert value to string (handle AST nodes)
    StringValue = "";
    If TypeOf(Value) = Type("Structure") AND Value.Property("Value") Then
        StringValue = String(Value.Value);
    Else
        StringValue = String(Value);
    EndIf;
    ErrorText = FunctionName + ": " + ?(StrFind(Message,"%1"),StrTemplate(Message, " '" + StringValue + "'"),Message);
    Return New Structure("Type, Value", "Error", ErrorText);
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
			StringValue = StrReplace(StringValue,"""", "\""");
  			StringValue = StrReplace(StringValue,Chars.LF, "\n");
  		// Return the string wrapped in double quotes
    		Return """" + StringValue + """";			
		ElsIf Node.Type = "Number" Then
            // Format numeric values (NZ= clears grouping, NDS='.' sets decimal separator)
            Return Format(Node.Value, "NZ=;NGS='"+Chars.NBSp+"';NDS='.'");
            
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
        If Node.Type = "List" Or Node.Type = "Vector" Then
            // Choose brackets based on the collection type
            OpenBracket  = ?(Node.Type = "List", "(", "[");
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