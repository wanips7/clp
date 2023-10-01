{
  This is a command line parser.
  Supported prefixes: '--', '-', '/', '@'.
  Supported delimeters - any combination of: ' ', ':', '='.

  Features:
   - Parameter position does not matter.
   - Checking for parameters that must be specified.
   - Checking of type values and required count.
   - Collecting values from identical parameters.
   - Parameter description generation.
   - Syntax checking.

  Version: 0.5

  https://github.com/wanips7/clp

}

unit uClp;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Generics.Collections;

const
  CRLF = sLineBreak;
  ANY_VALUE_COUNT = -1;

type
  TSwitchType = (stName, stValue);
  TValueType = (vtAny, vtInteger, vtCardinal, vtFloat, vtBoolean);
  TRequiredCondition = (rcRequired, rcOptional);

type
  TStringArray = TArray<string>;

type
  ECLPError = class(Exception);
  ESyntaxError = class(Exception);
  EParseError = class(Exception);

type
  TSwitch = record
  strict private
    FText: string;
    FPos: Integer;
    FType: TSwitchType;
  public
    property &Type: TSwitchType read FType;
    property Pos: Integer read FPos;
    property Text: string read FText;
    constructor Create(const Text: string; Pos: Integer; SwitchType: TSwitchType);
    function AsBoolean: Boolean;
    function AsCardinal: Cardinal;
    function AsInteger: Integer;
    function AsFloat: Double;
    function IsParamName: Boolean;
    function IsBoolean: Boolean;
    function IsInteger: Boolean;
    function IsCardinal: Boolean;
    function IsFloat: Boolean;
    function IsMatchType(const Value: TValueType): Boolean;
  end;

type
  TParamValues = class (TList<TSwitch>)
  public
    function AsStrings: TStringArray;
    function IsMatchTypes(const Value: TValueType; out Mismatched: TSwitch): Boolean;
    function Contains(const Value: string): Boolean; overload;
    function Contains(const Value: string; out Index: Integer): Boolean; overload;
    function Contains(const Values: TStringArray): Boolean; overload;
    function Contains(const Values: TStringArray; out Index: Integer): Boolean; overload;
  protected
    procedure TryAdd(const Value: TSwitch);
  end;

type
  TValuesRule = record
  strict private
    FList: TStringArray;
    FType: TValueType;
    FRequiredCount: Integer;
  private
    procedure Disallow;
  public
    property List: TStringArray read FList;
    property RequiredCount: Integer read FRequiredCount;
    property &Type: TValueType read FType;
    procedure New(const Values: TStringArray = []; RequiredCount: Integer = ANY_VALUE_COUNT; ValueType: TValueType = vtAny);
    function IsFixed: Boolean;
  end;

type
  TSyntaxRule = record
  strict private
    FNames: TStringArray;
    FIsNameRequired: Boolean;
    FValues: TValuesRule;
    FDescription: string;
    procedure SetNames(const Names: TStringArray; RequiredCondition: TRequiredCondition = rcOptional);
  public
    property IsNameRequired: Boolean read FIsNameRequired;
    property Description: string read FDescription write FDescription;
    property Names: TStringArray read FNames;
    property Values: TValuesRule read FValues;
    constructor Create(const Names: TStringArray; RequiredCondition: TRequiredCondition = rcOptional);
  end;

type
  TSyntaxRules = class (TList<TSyntaxRule>)
  strict private
    function IsUnique(const Value: TSyntaxRule): Boolean;
  public
    procedure Add(const Value: TSyntaxRule);
    function Contains(const Name: string): Boolean;
    function IsEmpty: Boolean;
  end;

type
  TParam = class
  strict private
    FName: TSwitch;
    FValues: TParamValues;
  public
    property Name: TSwitch read FName;
    property Values: TParamValues read FValues;
    constructor Create(const Switch: TSwitch);
    destructor Destroy; override;
    function HasValues: Boolean;
  end;

type
  TParams = class (TList<TParam>)
  strict private
  protected
    function IsMatchRule(const Rule: TSyntaxRule): Boolean;
    function GetParamByRule(const Rule: TSyntaxRule; out Param: TParam): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function IsEmpty: Boolean;
    procedure TryAdd(const Param: TParam);
    procedure Clear;
    function GetByIndex(const Index: Integer; out Param: TParam): Boolean;
    function Contains(const Name: string): Boolean; overload;
    function Contains(const Names: TStringArray; out Param: TParam): Boolean; overload;
    function Contains(const Names: TStringArray): Boolean; overload;
    function Contains(const Name: string; out Param: TParam): Boolean; overload;
    function Contains(const Name: string; out Index: Integer; out Param: TParam): Boolean; overload;
  end;

type
  TSwitchReader = class
  strict private
    FPos: Integer;
    FPreviousPos: Integer;
    FSource: string;
    function IsEnd: Boolean;
    function GetCurrentChar: Char;
    function InDelimeter: Boolean;
    function InQuote: Boolean;
    procedure SkipDelimeters;
    procedure SkipNonDelimeters;
    procedure SkipQuotes;
    function HasPrefix(const Value: string; out Prefix: string): Boolean;
    function RemovePrefix(const Value: string): string;
  public
    constructor Create(const Source: string);
    procedure Back;
    procedure Reset;
    function GetNext(out Switch: TSwitch): Boolean;
  end;
  
type  
  TCommandLineParser = class
  strict private
    FSyntaxCheck: Boolean;
    FHasErrors: Boolean;
    FErrorMsg: string;
    FParams: TParams;
    FSyntaxRules: TSyntaxRules;
    FSwitchReader: TSwitchReader;
    procedure CollectParams;
    function HasUnknownParams: Boolean;
    function IsParamsMatchRules: Boolean;
    procedure CheckSyntax;
  public
    property HasErrors: Boolean read FHasErrors;
    property ErrorMsg: string read FErrorMsg;
    property Params: TParams read FParams;
    property SyntaxCheck: Boolean read FSyntaxCheck write FSyntaxCheck;
    property SyntaxRules: TSyntaxRules read FSyntaxRules;
    constructor Create; overload;
    constructor Create(const CommandLine: string); overload;
    destructor Destroy; override;
    function Parse: Boolean;
    function GetHelpText: string;
  end;

implementation

const
  PARAM_PREFIX_LIST: TArray<String> = ['--', '-', '/', '@'];
  DELIMETERS: TArray<Char> = [' ', ':', '='];
  BOOLEAN_VALUES_TRUE: TArray<String> = ['true', '1'];
  BOOLEAN_VALUES_FALSE: TArray<String> = ['false', '0'];
  VALUE_TYPES_STRING: array [TValueType] of String = ('any', 'integer', 'cardinal', 'float', 'boolean');

resourcestring
  SHelpHeader =
    '[ Parameter names ] : Description' + CRLF +
    '  - Required value count, Required values type';
  SNoDescription = 'No description';
  SIsRequiredParameter = '* is a required parameter';
  SAnyCount = 'Any count';
  SType = 'type';

  SRequiredValues = 'Required values count cannot be less %d.';
  SSyntaxRulesNotFound = 'Syntax rules not found';
  SNoNameNotAllowed = 'A syntax rule without names is not allowed.';
  SNamesMustBeUnique = 'Names must be unique.';

  SConvertError = '"%s" is not a valid %s value.';

  SCloseQuoteMissing = '[%d] Close quote is missing.';
  SParameterNameExpected = '[%d] Parameter name expected.';

  SParameterIsMissing = 'Parameter "%s" is missing.';
  SUnknownValueFound = '[%d] Unknown value is found "%s".';
  SUnknownValueType = '[%d] Unknown value type found.';
  SValuesNotAllowed = '[%d] Values are not allowed for parameter "%s".';
  SExpectedValues = '[%d] Expected %d values for parameter "%s".';
  SUnknownParameterFound = '[%d] Unknown parameter found "%s".';

function StringInArray(const Value: String; const StringArray: TStringArray): Boolean;
var
  s: String;
begin
  for s in StringArray do
    if Value = s then
      Exit(True);

  Result := False;
end;

function TryStrToBoolean(Source: string; out Value: Boolean): Boolean;
begin
  Result := False;
  Source := LowerCase(Source);

  if StringInArray(Source, BOOLEAN_VALUES_TRUE) then
  begin
    Value := True;
    Result := True;
  end
    else
  if StringInArray(Source, BOOLEAN_VALUES_FALSE) then
  begin
    Value := False;
    Result := True;
  end
end;

function ValueTypeToStr(const Value: TValueType): string;
begin
  Result := VALUE_TYPES_STRING[Value];
end;

function IsUniqueStrings(const Value: TStringArray): Boolean;
var
  i: Integer;
  s, c: string;
begin
  i := 0;
  for s in Value do
    for c in Value do
      if c = s then
        Inc(i);

  Result := i = Length(Value);
end;

{ TSwitch }

function TSwitch.AsBoolean: Boolean;
begin
  if not TryStrToBoolean(Text, Result) then
    raise EConvertError.CreateFmt(SConvertError, [Text, ValueTypeToStr(vtBoolean)]);
end;

function TSwitch.AsCardinal: Cardinal;
begin
  if not TryStrToUInt(Text, Result) then
    raise EConvertError.CreateFmt(SConvertError, [Text, ValueTypeToStr(vtCardinal)]);
end;

function TSwitch.AsFloat: Double;
begin
  if not TryStrToFloat(Text, Result) then
    raise EConvertError.CreateFmt(SConvertError, [Text, ValueTypeToStr(vtFloat)]);
end;

function TSwitch.AsInteger: Integer;
begin
  if not TryStrToInt(Text, Result) then
    raise EConvertError.CreateFmt(SConvertError, [Text, ValueTypeToStr(vtInteger)]);
end;

constructor TSwitch.Create(const Text: string; Pos: Integer; SwitchType: TSwitchType);
begin
  FText := Text;
  FPos := Pos;
  FType := SwitchType;
end;

function TSwitch.IsBoolean: Boolean;
var
  b: Boolean;
begin
  Result := TryStrToBoolean(FText, b);
end;

function TSwitch.IsCardinal: Boolean;
var
  i: Cardinal;
begin
  Result := TryStrToUInt(FText, i);
end;

function TSwitch.IsInteger: Boolean;
var
  i: Integer;
begin
  Result := TryStrToInt(FText, i);
end;

function TSwitch.IsFloat: Boolean;
var
  e: Extended;
begin
  Result := TryStrToFloat(FText, e);
end;

function TSwitch.IsMatchType(const Value: TValueType): Boolean;
begin
  case Value of
    vtInteger:
      Result := IsInteger;

    vtCardinal:
      Result := IsCardinal;

    vtFloat:
      Result := IsFloat;

    vtBoolean:
      Result := IsBoolean;

    vtAny:
      Result := True;

    else
      Result := False;
  end;
end;

function TSwitch.IsParamName: Boolean;
begin
  Result := FType = stName;
end;

{ TSwitchReader }

procedure TSwitchReader.Back;
begin
  FPos := FPreviousPos;
end;

constructor TSwitchReader.Create(const Source: string);
begin
  Reset;
  FSource := Source;
end;

function TSwitchReader.GetCurrentChar: Char;
begin
  Result := FSource[FPos];
end;

function TSwitchReader.GetNext(out Switch: TSwitch): Boolean;
var
  StartPos, EndPos: Integer;
  SwitchText: string;
  SwitchType: TSwitchType;
  Prefix: string;
  HasQuotes: Boolean;
begin
  Result := False;
  HasQuotes := False;

  if not IsEnd then
  begin
    SkipDelimeters;

    StartPos := FPos;
    FPreviousPos := FPos;

    if InQuote then
    begin
      SkipQuotes;
      Inc(StartPos);
      HasQuotes := True;
    end
      else
    begin
      SkipNonDelimeters;
    end;

    EndPos := FPos;

    SwitchText := Copy(FSource, StartPos, EndPos - StartPos);

    if HasPrefix(SwitchText, Prefix) and not HasQuotes then
    begin
      SwitchText := RemovePrefix(SwitchText);
      SwitchText := SwitchText.ToLower;
      SwitchType := stName;
      Inc(StartPos, Prefix.Length);
    end
      else
    SwitchType := stValue;

    Switch := TSwitch.Create(SwitchText, StartPos, SwitchType);

    Inc(FPos);

    Result := not Switch.Text.IsEmpty;
  end;
end;

function TSwitchReader.InDelimeter: Boolean;
var
  c: Char;
begin
  for c in DELIMETERS do
    if c = GetCurrentChar then
      Exit(True);

  Result := False;
end;

function TSwitchReader.InQuote: Boolean;
begin
  Result := GetCurrentChar = '"';
end;

function TSwitchReader.IsEnd: Boolean;
begin
  Result := FPos > FSource.Length;
end;

procedure TSwitchReader.Reset;
begin
  FPos := 1;
  FPreviousPos := FPos;
end;

procedure TSwitchReader.SkipDelimeters;
begin
  while not IsEnd and InDelimeter do
  begin
    Inc(FPos);
  end;
end;

procedure TSwitchReader.SkipNonDelimeters;
begin
  while not IsEnd and not InDelimeter do
  begin
    Inc(FPos);
  end;
end;

procedure TSwitchReader.SkipQuotes;
var
  i: Integer;
begin
  if InQuote then
  begin
    i := FPos;
    FPos := Pos('"', FSource, FPos + 1);

    if FPos = 0 then
      raise EParseError.CreateFmt(SCloseQuoteMissing, [i]);
  end;
end;

function TSwitchReader.HasPrefix(const Value: string; out Prefix: string): Boolean;
var
  s: string;
begin
  if not Value.IsEmpty then
    for s in PARAM_PREFIX_LIST do
      if Value.StartsWith(s) then
      begin
        Prefix := s;
        Exit(True);
      end;

  Result := False;
end;

function TSwitchReader.RemovePrefix(const Value: string): string;
var
  Prefix: string;
begin
  Result := Value;

  if HasPrefix(Value, Prefix) then
  begin
    Result := Value.Remove(0, Prefix.Length);
  end;
end;

{ TParams }

procedure TParams.TryAdd(const Param: TParam);
var
  ExistParam: TParam;
  ParamValue: TSwitch;
begin
  if Contains(Param.Name.Text, ExistParam) then
  begin
    for ParamValue in Param.Values.List do
      ExistParam.Values.TryAdd(ParamValue);
  end
    else
  Add(Param);

  TrimExcess;
end;

procedure TParams.Clear;
var
  Param: TParam;
begin
  for Param in List do
    FreeAndNil(Param);

  inherited Clear;
end;

function TParams.Contains(const Name: string; out Index: Integer; out Param: TParam): Boolean;
var
  i: Integer;
begin
  Result := False;
  Index := -1;

  if not IsEmpty and not Name.IsEmpty then
    for i := 0 to Count - 1 do
    begin
      if List[i].Name.Text = Name then
      begin
        Index := i;
        Param := List[i];
        Result := True;
        Break;
      end;
    end;
end;

function TParams.Contains(const Name: string; out Param: TParam): Boolean;
var
  Index: Integer;
begin
  Result := Contains(Name, Index, Param);
end;

function TParams.Contains(const Names: TStringArray; out Param: TParam): Boolean;
var
  Name: string;
begin
  for Name in Names do
    if Contains(Name, Param) then
      Exit(True);

  Result := False;
end;

function TParams.Contains(const Names: TStringArray): Boolean;
var
  Param: TParam;
begin
  Result := Contains(Names, Param);
end;

function TParams.Contains(const Name: string): Boolean;
var
  Param: TParam;
begin
  Result := Contains(Name, Param);
end;

constructor TParams.Create;
begin
  inherited;
  Clear;
end;

destructor TParams.Destroy;
begin
  Clear;
  inherited;
end;

function TParams.IsEmpty: Boolean;
begin
  Result := Count = 0
end;

function TParams.GetByIndex(const Index: Integer; out Param: TParam): Boolean;
begin
  Result := False;

  if (Index >= 0) and (Index < Count) then
  begin
    Param := List[Index];
    Result := True;
  end;
end;

function TParams.GetParamByRule(const Rule: TSyntaxRule; out Param: TParam): Boolean;
var
  Name: string;
begin
  for Name in Rule.Names do
    if Contains(Name, Param) then
    begin
      Exit(True);
    end;

  Result := False;
end;

function TParams.IsMatchRule(const Rule: TSyntaxRule): Boolean;
var
  Param: TParam;
  ParamValue: TSwitch;
  Mismatched: TSwitch;
  Names: string;
begin
  Result := False;

  if GetParamByRule(Rule, Param) then
  begin
    { check required values count }
    if Rule.Values.RequiredCount <> ANY_VALUE_COUNT then
    begin
      if Param.HasValues and (Rule.Values.RequiredCount = 0) then
        raise ESyntaxError.CreateFmt(SValuesNotAllowed,
          [Param.Name.Pos, Param.Name.Text]);

      if Rule.Values.RequiredCount <> Param.Values.Count then
        raise ESyntaxError.CreateFmt(SExpectedValues,
          [Param.Name.Pos, Rule.Values.RequiredCount, Param.Name.Text]);
    end;

    if Param.HasValues then
    begin
      { check values types }
      if not Param.Values.IsMatchTypes(Rule.Values.&Type, Mismatched) then
        raise ESyntaxError.CreateFmt(SUnknownValueType, [Mismatched.Pos, Mismatched.Text]);

      { check fixed values }
      if Rule.Values.IsFixed then
      begin
        for ParamValue in Param.Values.List do
        begin
          if not StringInArray(ParamValue.Text, Rule.Values.List) then
            raise ESyntaxError.CreateFmt(SUnknownValueFound, [ParamValue.Pos, ParamValue.Text]);
        end;
      end;
    end;

  end
    else
  if Rule.IsNameRequired then
  begin
    Names := '[ ' + string.Join(' | ', Rule.Names) + ' ]';
    raise ESyntaxError.CreateFmt(SParameterIsMissing, [Names]);
  end;

  Result := True;
end;

{ TRules }

procedure TSyntaxRules.Add(const Value: TSyntaxRule);
begin
  if Length(Value.Names) > 0 then
  begin
    if IsUnique(Value) then
    begin
      inherited Add(Value);
      TrimExcess;
    end
      else
    raise ECLPError.Create(SNamesMustBeUnique);

  end
    else
  raise ECLPError.Create(SNoNameNotAllowed);
end;

function TSyntaxRules.IsUnique(const Value: TSyntaxRule): Boolean;
var
  Name: string;
begin
  for Name in Value.Names do
    if Contains(Name) then
      Exit(False);

  Result := True;
end;

function TSyntaxRules.Contains(const Name: string): Boolean;
var
  Rule: TSyntaxRule;
begin
  if not Name.IsEmpty then
    for Rule in List do
      if StringInArray(Name, Rule.Names) then
        Exit(True);

  Result := False;
end;

function TSyntaxRules.IsEmpty: Boolean;
begin
  Result := Count = 0
end;

{ TCommandLineParser }

function TCommandLineParser.HasUnknownParams: Boolean;
var
  Param: TParam;
begin
  for Param in FParams do
    if not FSyntaxRules.Contains(Param.Name.Text) then
    begin
      Result := True;
      raise ESyntaxError.CreateFmt(SUnknownParameterFound, [Param.Name.Pos, Param.Name.Text]);
    end;

  Result := False;
end;

function TCommandLineParser.IsParamsMatchRules: Boolean;
var
  Rule: TSyntaxRule;
begin
  for Rule in FSyntaxRules.List do
    if not FParams.IsMatchRule(Rule) then
    begin
      Exit(False);
    end;

  Result := True;
end;

function TCommandLineParser.Parse: Boolean;
begin
  Result := False;
  FHasErrors := False;

  try
    CollectParams;

    if FSyntaxCheck then
      CheckSyntax;
  except
    on E: EParseError do
    begin
      FHasErrors := True;
      FErrorMsg := E.Message;
    end;

    on E: ESyntaxError do
    begin
      FHasErrors := True;
      FErrorMsg := E.Message;
    end;
  end;

  Result := not FHasErrors;
end;

procedure TCommandLineParser.CheckSyntax;
begin
  if FSyntaxRules.IsEmpty then
    raise ECLPError.Create(SSyntaxRulesNotFound)
  else
    if not HasUnknownParams then
      IsParamsMatchRules;
end;

procedure TCommandLineParser.CollectParams;
var
  Param: TParam;
  Switch: TSwitch;
begin
  FParams.Clear;
  FSwitchReader.Reset;

  { Skip app path }
  FSwitchReader.GetNext(Switch);

  while FSwitchReader.GetNext(Switch) do
  begin
    if Switch.IsParamName then
    begin
      Param := TParam.Create(Switch);

      while FSwitchReader.GetNext(Switch) do
      begin
        if Switch.IsParamName then
        begin
          FSwitchReader.Back;
          Break;
        end
          else
        begin
          Param.Values.TryAdd(Switch);
        end;
      end;

      FParams.TryAdd(Param);
    end
      else
    raise EParseError.CreateFmt(SParameterNameExpected, [Switch.Pos]);
  end;

end;

constructor TCommandLineParser.Create;
begin
  Create(GetCommandLine);
end;

constructor TCommandLineParser.Create(const CommandLine: string);
begin
  FSwitchReader := TSwitchReader.Create(CommandLine);
  FParams := TParams.Create;
  FSyntaxRules := TSyntaxRules.Create;
  FSyntaxCheck := True;
  FHasErrors := False;
  FErrorMsg := '';
end;

destructor TCommandLineParser.Destroy;
begin
  FSwitchReader.Free;
  FParams.Free;
  FSyntaxRules.Free;
  inherited;
end;

function TCommandLineParser.GetHelpText: string;
var
  Rule: TSyntaxRule;
  Names: string;
  Values: string;
begin
  Result := SHelpHeader + CRLF + CRLF;

  for Rule in FSyntaxRules.List do
  begin
    Names := '';

    Result := Result + '[ ' + Names.Join(' | ', Rule.Names) + ' ]';

    if Rule.IsNameRequired then
      Result := Result + '*';

    Result := Result + ' : ' + Rule.Description + CRLF;

    if Rule.Values.RequiredCount <> 0 then
    begin
      Values := '  - ';

      if Rule.Values.RequiredCount = ANY_VALUE_COUNT then
        Values := Values + SAnyCount + ', '
      else
        Values := Values + Rule.Values.RequiredCount.ToString + ', ';

      if Rule.Values.IsFixed then
        Values := Values + '( ' + Values.Join(' | ', Rule.Values.List) + ' )'
      else
        Values := Values + ValueTypeToStr(Rule.Values.&Type) + ' ' + SType;

      Result := Result + Values + CRLF;
    end;
  end;

  Result := Result + CRLF + SIsRequiredParameter;
end;

{ TRuleValues }

procedure TValuesRule.New(const Values: TStringArray; RequiredCount: Integer; ValueType: TValueType);
begin
  if RequiredCount >= ANY_VALUE_COUNT then
  begin
    FList := Values;
    FRequiredCount := RequiredCount;
    FType := ValueType;
  end
    else
  raise ECLPError.Create(SRequiredValues + ' ' + ANY_VALUE_COUNT.ToString);
end;

function TValuesRule.IsFixed: Boolean;
begin
  Result := Length(FList) > 0;
end;

procedure TValuesRule.Disallow;
begin
  New([], 0, vtAny);
end;

{ TParamRule }

constructor TSyntaxRule.Create(const Names: TStringArray; RequiredCondition: TRequiredCondition);
begin
  SetNames(Names, RequiredCondition);
  Description := SNoDescription;
  FValues.Disallow;
end;

procedure TSyntaxRule.SetNames(const Names: TStringArray; RequiredCondition: TRequiredCondition = rcOptional);
begin
  FNames := Names;
  FIsNameRequired := RequiredCondition = rcRequired;
end;

{ TParam }

constructor TParam.Create(const Switch: TSwitch);
begin
  FValues := TParamValues.Create;
  FName := Switch;
end;

destructor TParam.Destroy;
begin
  FreeAndNil(FValues);
  inherited;
end;

function TParam.HasValues: Boolean;
begin
  Result := Values.Count > 0;
end;

{ TParamValues }

procedure TParamValues.TryAdd(const Value: TSwitch);
begin
  if not Contains(Value.Text) then
  begin
    Add(Value);
    TrimExcess;
  end;
end;

function TParamValues.AsStrings: TStringArray;
var
  Switch: TSwitch;
begin
  Result := [];
  for Switch in List do
    Result := Result + [Switch.Text];
end;

function TParamValues.Contains(const Value: string): Boolean;
var
  i: Integer;
begin
  Result := Contains([Value], i);
end;

function TParamValues.Contains(const Values: TStringArray; out Index: Integer): Boolean;
var
  s: string;
  i: Integer;
begin
  Index := -1;
  Result := False;

  if Length(List) > 0 then
  for i := 0 to High(List) do
    for s in Values do
      if s = List[i].Text then
      begin
        Index := i;
        Exit(True);
      end;
end;

function TParamValues.Contains(const Value: string; out Index: Integer): Boolean;
begin
  Result := Contains(Value, Index);
end;

function TParamValues.Contains(const Values: TStringArray): Boolean;
var
  i: Integer;
begin
  Result := Contains(Values, i);
end;

function TParamValues.IsMatchTypes(const Value: TValueType; out Mismatched: TSwitch): Boolean;
var
  Switch: TSwitch;
begin
  Result := True;

  for Switch in List do
    if not Switch.IsMatchType(Value) then
    begin
      Mismatched := Switch;
      Exit(False);
    end;
end;

end.
