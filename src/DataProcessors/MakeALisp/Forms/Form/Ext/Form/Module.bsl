
&AtClient
Procedure Run(Command) 
	CallLispInterpreter();
EndProcedure 

&AtServer
Procedure CallLispInterpreter()
	
	If Step = "0" Then
		Output = Step0.MaL_Step_0(Input, DebugLog);
	ElsIf Step = "1" Then
//		Output = Step1.MaL_Step_1(Input, DebugLog);
	ElsIf Step = "2" Then
//		Output = Step2.MaL_Step_2(Input, DebugLog);
	ElsIf Step = "3" Then
//		Output = Step3.MaL_Step_3(Input, DebugLog);
	ElsIf Step = "4" Then
//		Output = Step4.MaL_Step_4(Input, DebugLog);
	ElsIf Step = "5" Then
//		Output = Step5.MaL_Step_5(Input, DebugLog);
	ElsIf Step = "6" Then
//		Output = Step6.MaL_Step_6(Input, DebugLog);
	ElsIf Step = "7" Then
//		Output = Step7.MaL_Step_7(Input, DebugLog);
	ElsIf Step = "8" Then
//		Output = Step8.MaL_Step_8(Input, DebugLog);
	ElsIf Step = "9" Then
//		Output = Step9.MaL_Step_9(Input, DebugLog);
	ElsIf Step = "A" Then
//		Output = StepA.MaL_Step_A(Input, DebugLog);
	EndIf;
EndProcedure

&AtClient
Async Procedure Load(Command)
    Dialog = New FileDialog(FileDialogMode.Open);
    Dialog.Title = "Open program text";
    Dialog.Filter = "Text files (*.txt)|*.txt";
    Dialog.DefaultExt = "txt";

    ChooseResult = Await Dialog.ChooseAsync();

    If ChooseResult <> Undefined Then
        Reader = New TextReader(Dialog.FullFileName, TextEncoding.UTF8);
        Input = Reader.Read();
        Reader.Close();

        Message("Loaded: " + Dialog.FullFileName);
    EndIf;
EndProcedure

&AtClient
Async Procedure Save(Command)

    Dialog = New FileDialog(FileDialogMode.Save);
    Dialog.Title = "Save program text";
    Dialog.Filter = "Text files (*.txt)|*.txt";
    Dialog.DefaultExt = "txt";
    Dialog.FullFileName = "program.txt";

    ChooseResult = Await Dialog.ChooseAsync();

    If ChooseResult <> Undefined Then
        Writer = New TextWriter(Dialog.FullFileName, TextEncoding.UTF8);
        Writer.Write(Input);
        Writer.Close();

        Message("Saved: " + Dialog.FullFileName);
    EndIf;
EndProcedure

&AtClient
Procedure Debug(Command)
	Items.DebugLog.Visible = Not Items.DebugLog.Visible;
EndProcedure

&AtClient
Procedure StepOnChange(Item)

	Input = GetStepTemplateText(Step);

EndProcedure

&AtServer
Function GetStepTemplateText(StepCode)
	Try
		Template = DataProcessors.MakeALisp.GetTemplate("Test" + StepCode);
		Return Template.GetText();
	Except
		Return "ERROR reading template TEST" + StepCode + ": " + ErrorDescription();
	EndTry;
EndFunction

&AtClient
Procedure ShowPicture(Command)
		OpenForm("DataProcessor.MakeALisp.Form.Picture"+Step);
EndProcedure
