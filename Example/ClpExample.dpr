{
  This example show how to use command line parser.

  https://github.com/wanips7/clp
}

program ClpExample;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  uClp in '..\..\clp\uClp.pas';

const
  PARAM_SHOW_HELLO: TArray<string> = ['s', 'sh', 'showhello'];
  PARAM_HOW_ARE_YOU: TArray<string> = ['ha', 'hau'];
  PARAM_TEST_INT: TArray<string> = ['t', 'tint'];
  PARAM_TEST_VALUES: TArray<string> = ['tv'];
  PARAM_HELP: TArray<string> = ['h', 'help'];


var
  Clp: TCommandLineParser;
  AppPath: string = '';

procedure Deinit;
begin
  Clp.Free;
end;

function ConsoleEventProc(CtrlType: DWORD): BOOL; stdcall;
begin
  if (CtrlType = CTRL_CLOSE_EVENT) then
  begin
    Deinit;
  end;

  Result := True;
end;

procedure Init;
begin
  SetConsoleCtrlHandler(@ConsoleEventProc, True);
  AppPath := ParamStr(0);

  Clp := TCommandLineParser.Create;

end;

procedure ExecCommand;
var
  Param: TParam;
  i: Integer;
  s: string;
begin
  if Clp.Params.Contains(PARAM_SHOW_HELLO) then
  begin
    Writeln('Hello!');
  end
    else
  if Clp.Params.Contains(PARAM_HOW_ARE_YOU, Param) then
  begin
    Writeln('Value is: ' + Param.Values[0].Text);

  end
    else
  if Clp.Params.Contains(PARAM_TEST_INT, Param) then
  begin
    Writeln('Int value is: ', Param.Values[0].AsInteger);

  end
    else
  if Clp.Params.Contains(PARAM_TEST_VALUES, Param) then
  begin
    if Param.HasValues then
    begin
      Writeln('Value list:');

      for i := 0 to Param.Values.Count - 1 do
        Writeln(Format('Value %d: %s', [i + 1, Param.Values[i].Text]));
    end
      else
    Writeln('There is no values.');
  end
    else
  if Clp.Params.Contains(PARAM_HELP) then
  begin
    Writeln('Help screen:');
    Writeln(Clp.GetHelpText);

  end
    else
  begin
    Writeln('No parameters found.');
  end;

end;

procedure RegisterSyntaxRules;
var
  Rule: TSyntaxRule;
begin
  Clp.SyntaxRules.Clear;

  { values is not allowed }
  Rule := TSyntaxRule.Create(PARAM_SHOW_HELLO, rcOptional);
  Rule.Description := 'Show hello.';
  Clp.SyntaxRules.Add(Rule);

  { fixed values }
  Rule := TSyntaxRule.Create(PARAM_HOW_ARE_YOU, rcOptional);
  Rule.Values.New(['fine', 'ok'], 1, vtAny);
  Rule.Description := 'Show how are you.';
  Clp.SyntaxRules.Add(Rule);

  { only one integer value allowed }
  Rule := TSyntaxRule.Create(PARAM_TEST_INT, rcOptional);
  Rule.Values.New([], 1, vtInteger);
  Rule.Description := 'Integer test.';
  Clp.SyntaxRules.Add(Rule);

  { test values }
  Rule := TSyntaxRule.Create(PARAM_TEST_VALUES, rcOptional);
  Rule.Values.New([], ANY_VALUE_COUNT, vtAny);
  Rule.Description := 'Test values.';
  Clp.SyntaxRules.Add(Rule);

  { help }
  Rule := TSyntaxRule.Create(PARAM_HELP, rcOptional);
  Rule.Description := 'Show help.';
  Clp.SyntaxRules.Add(Rule);
end;

begin
  Init;

  RegisterSyntaxRules;

  if Clp.Parse then
  begin
    ExecCommand;

  end
    else
  begin
    Writeln('Error: ' + Clp.ErrorMsg);
  end;

  Readln;



end.
