unit Worby.Manager;

interface

uses
  Winapi.Windows, Winapi.TlHelp32, System.SysUtils, System.Classes,
  System.IniFiles, System.SyncObjs;

const
  ITEM_COUNT = 8;

type
  TWorbyItem = record
    Name: string;
    Target: string;
    IsService: Boolean;
  end;

  TWorbyManager = class
  private
    FItems: array[0..ITEM_COUNT - 1] of TWorbyItem;
    FLock: TCriticalSection;
    FBaseDir: string;
    procedure LoadConfig;
    procedure Log(const S: string);
    function ServiceState(const Name: string): DWORD;
    function SetServiceState(const Name: string; StartIt: Boolean): Boolean;
    function FindProcess(const FileName: string; out PID: DWORD): Boolean;
    function StartProcess(const FileName: string): Boolean;
    function StopProcess(const FileName: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function StartItem(Index: Integer): Boolean;
    function StopItem(Index: Integer): Boolean;
    function RestartItem(Index: Integer): Boolean;
    function IsRunning(Index: Integer): Boolean;
    function StatusText: string;
    procedure StartAll;
    procedure StopAll;
    procedure RestartAll;
  end;

implementation

uses Winapi.WinSvc;

const
  PROCESS_QUERY_LIMITED_INFO = $1000;

function QueryFullProcessImageNameW(hProcess: THandle; dwFlags: DWORD;
  lpExeName: PWideChar; var lpdwSize: DWORD): BOOL; stdcall;
  external kernel32 name 'QueryFullProcessImageNameW';

constructor TWorbyManager.Create;
begin
  inherited;
  FLock := TCriticalSection.Create;
  FBaseDir := IncludeTrailingPathDelimiter(ExtractFilePath(GetModuleName(HInstance)));
  LoadConfig;
end;

destructor TWorbyManager.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TWorbyManager.LoadConfig;
const
  Defaults: array[0..ITEM_COUNT - 1] of string = (
    'C:\WorbyRepRest\Plasfan\WorbyRepRest.exe',
    'C:\WorbyRepRest\FilhoCriador\WorbyRepRest.exe',
    'C:\OrbiApi\FilhoCriador\OrbiAPI.exe',
    'C:\OrbiApi\Plasfan\OrbiAPI.exe',
    'C:\WorbyEmissor\Plasfan\EmissorFila.exe',
    'C:\WorbyEmissor\FilhoCriador\EmissorFila.exe',
    'C:\WorbyScannerRest\WorbyScannerRest.exe',
    'C:\WorbyIntegradorML\Plasfan\WorbyMLIntegrador.exe');
var
  Ini: TIniFile;
  I: Integer;
begin
  FItems[0].Name := 'WorbyRepRest - Plasfan';
  FItems[1].Name := 'WorbyRepRest - Filho Criador';
  FItems[2].Name := 'OrbiAPI - Filho Criador';
  FItems[3].Name := 'OrbiAPI - Plasfan';
  FItems[4].Name := 'EmissorFila - Plasfan';
  FItems[5].Name := 'EmissorFila - Filho Criador';
  FItems[6].Name := 'WorbyScannerRest';
  FItems[7].Name := 'WorbyMLIntegrador';
  Ini := TIniFile.Create(FBaseDir + 'WorbyServices.ini');
  try
    for I := 0 to ITEM_COUNT - 1 do
    begin
      FItems[I].Target := Ini.ReadString('Items', 'Item' + I.ToString, Defaults[I]);
      FItems[I].IsService := False;
    end;
  finally
    Ini.Free;
  end;
end;

procedure TWorbyManager.Log(const S: string);
var
  F: TextFile;
begin
  try
    AssignFile(F, FBaseDir + 'WorbyServices.log');
    if FileExists(FBaseDir + 'WorbyServices.log') then Append(F) else Rewrite(F);
    try Writeln(F, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' ' + S); finally CloseFile(F); end;
  except
    // Logging must never stop service control.
  end;
end;

function TWorbyManager.ServiceState(const Name: string): DWORD;
var
  SCM, Svc: SC_HANDLE;
  St: SERVICE_STATUS;
begin
  Result := 0;
  SCM := OpenSCManager(nil, nil, SC_MANAGER_CONNECT);
  if SCM = 0 then Exit;
  try
    Svc := OpenService(SCM, PChar(Name), SERVICE_QUERY_STATUS);
    if Svc = 0 then Exit;
    try if QueryServiceStatus(Svc, St) then Result := St.dwCurrentState; finally CloseServiceHandle(Svc); end;
  finally
    CloseServiceHandle(SCM);
  end;
end;

function TWorbyManager.SetServiceState(const Name: string; StartIt: Boolean): Boolean;
var
  SCM, Svc: SC_HANDLE;
  St: SERVICE_STATUS;
  Started: BOOL;
  UntilTick: UInt64;
  ServiceArgs: LPCWSTR;
begin
  Result := False;
  SCM := OpenSCManager(nil, nil, SC_MANAGER_CONNECT);
  if SCM = 0 then Exit;
  try
    Svc := OpenService(SCM, PChar(Name), SERVICE_START or SERVICE_STOP or SERVICE_QUERY_STATUS);
    if Svc = 0 then Exit;
    try
      ServiceArgs := nil;
      if StartIt then Started := StartService(Svc, 0, ServiceArgs)
      else Started := ControlService(Svc, SERVICE_CONTROL_STOP, St);
      if not Started and (GetLastError <> ERROR_SERVICE_ALREADY_RUNNING) and
        (GetLastError <> ERROR_SERVICE_NOT_ACTIVE) then Exit;
      UntilTick := GetTickCount64 + 30000;
      repeat
        if not QueryServiceStatus(Svc, St) then Exit;
        if StartIt and (St.dwCurrentState = SERVICE_RUNNING) then Exit(True);
        if (not StartIt) and (St.dwCurrentState = SERVICE_STOPPED) then Exit(True);
        Sleep(250);
      until GetTickCount64 >= UntilTick;
    finally
      CloseServiceHandle(Svc);
    end;
  finally
    CloseServiceHandle(SCM);
  end;
end;

function TWorbyManager.FindProcess(const FileName: string; out PID: DWORD): Boolean;
var
  Snap, Proc: THandle;
  E: TProcessEntry32;
  Buf: array[0..32767] of Char;
  FullName: string;
  N: DWORD;
begin
  Result := False; PID := 0;
  Snap := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if Snap = INVALID_HANDLE_VALUE then Exit;
  try
    E.dwSize := SizeOf(E);
    if Process32First(Snap, E) then repeat
      Proc := OpenProcess(PROCESS_QUERY_LIMITED_INFO, False, E.th32ProcessID);
      if Proc <> 0 then
      try
        N := Length(Buf);
        if QueryFullProcessImageNameW(Proc, 0, Buf, N) then
        begin
          SetString(FullName, Buf, N);
          if SameText(FullName, FileName) then begin PID := E.th32ProcessID; Exit(True); end;
        end;
      finally CloseHandle(Proc); end;
    until not Process32Next(Snap, E);
  finally CloseHandle(Snap); end;
end;

function TWorbyManager.StartProcess(const FileName: string): Boolean;
var
  SI: TStartupInfo;
  PI: TProcessInformation;
  Cmd, Dir: string;
  PID: DWORD;
begin
  if FindProcess(FileName, PID) then Exit(True);
  if not FileExists(FileName) then begin Log('Arquivo inexistente: ' + FileName); Exit(False); end;
  ZeroMemory(@SI, SizeOf(SI)); SI.cb := SizeOf(SI);
  ZeroMemory(@PI, SizeOf(PI));
  Cmd := '"' + FileName + '"'; Dir := ExtractFileDir(FileName);
  UniqueString(Cmd);
  Result := CreateProcess(nil, PChar(Cmd), nil, nil, False, CREATE_NEW_PROCESS_GROUP,
    nil, PChar(Dir), SI, PI);
  if Result then begin CloseHandle(PI.hThread); CloseHandle(PI.hProcess); end
  else Log(Format('Erro %d iniciando %s', [GetLastError, FileName]));
end;

function TWorbyManager.StopProcess(const FileName: string): Boolean;
var
  PID: DWORD;
  P: THandle;
begin
  if not FindProcess(FileName, PID) then Exit(True);
  P := OpenProcess(PROCESS_TERMINATE or SYNCHRONIZE, False, PID);
  if P = 0 then Exit(False);
  try
    Result := TerminateProcess(P, 0);
    if Result then WaitForSingleObject(P, 10000);
  finally CloseHandle(P); end;
end;

function TWorbyManager.StartItem(Index: Integer): Boolean;
begin
  Result := False;
  if (Index < 0) or (Index >= ITEM_COUNT) or (FItems[Index].Target = '') then Exit;
  FLock.Acquire;
  try
    if FItems[Index].IsService then Result := SetServiceState(FItems[Index].Target, True)
    else Result := StartProcess(FItems[Index].Target);
    Log('INICIAR ' + FItems[Index].Name + ': ' + BoolToStr(Result, True));
  finally FLock.Release; end;
end;

function TWorbyManager.StopItem(Index: Integer): Boolean;
begin
  Result := False;
  if (Index < 0) or (Index >= ITEM_COUNT) or (FItems[Index].Target = '') then Exit;
  FLock.Acquire;
  try
    if FItems[Index].IsService then Result := SetServiceState(FItems[Index].Target, False)
    else Result := StopProcess(FItems[Index].Target);
    Log('PARAR ' + FItems[Index].Name + ': ' + BoolToStr(Result, True));
  finally FLock.Release; end;
end;

function TWorbyManager.RestartItem(Index: Integer): Boolean;
begin
  Result := StopItem(Index);
  if Result then begin Sleep(500); Result := StartItem(Index); end;
end;

function TWorbyManager.IsRunning(Index: Integer): Boolean;
var PID: DWORD;
begin
  Result := False;
  if (Index < 0) or (Index >= ITEM_COUNT) or (FItems[Index].Target = '') then Exit;
  if FItems[Index].IsService then Result := ServiceState(FItems[Index].Target) = SERVICE_RUNNING
  else Result := FindProcess(FItems[Index].Target, PID);
end;

function TWorbyManager.StatusText: string;
var I: Integer;
begin
  Result := '';
  for I := 0 to ITEM_COUNT - 1 do
    if FItems[I].Target <> '' then
      Result := Result + FItems[I].Name + '=' + BoolToStr(IsRunning(I), True) + sLineBreak;
end;

procedure TWorbyManager.StartAll;
var I: Integer;
begin for I := 0 to ITEM_COUNT - 1 do if FItems[I].Target <> '' then StartItem(I); end;

procedure TWorbyManager.StopAll;
var I: Integer;
begin for I := ITEM_COUNT - 1 downto 0 do if FItems[I].Target <> '' then StopItem(I); end;

procedure TWorbyManager.RestartAll;
begin StopAll; Sleep(1000); StartAll; end;

end.
