program WorbyService;

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  Winapi.WinSvc,
  System.SysUtils,
  Worby.DllApi in 'scr\Worby.DllApi.pas';

const
  SERVICE_NAME = 'WorbyServices';
  DISPLAY_NAME = 'Worby Services Manager';
  SERVICE_DELETE_ACCESS = $00010000;

var
  StatusHandle: SERVICE_STATUS_HANDLE;
  Status: SERVICE_STATUS;
  StopEvent: THandle;
  Api: TWorbyDll;

procedure ReportStatus(State, ExitCode, WaitHint: DWORD);
begin
  Status.dwServiceType := SERVICE_WIN32_OWN_PROCESS;
  Status.dwCurrentState := State;
  Status.dwWin32ExitCode := ExitCode;
  Status.dwWaitHint := WaitHint;
  if State = SERVICE_START_PENDING then Status.dwControlsAccepted := 0
  else Status.dwControlsAccepted := SERVICE_ACCEPT_STOP or SERVICE_ACCEPT_SHUTDOWN;
  SetServiceStatus(StatusHandle, Status);
end;

function Handler(Control, EventType: DWORD; EventData, Context: Pointer): DWORD; stdcall;
begin
  Result := NO_ERROR;
  case Control of
    SERVICE_CONTROL_STOP, SERVICE_CONTROL_SHUTDOWN:
      begin ReportStatus(SERVICE_STOP_PENDING, NO_ERROR, 30000); SetEvent(StopEvent); end;
    SERVICE_CONTROL_INTERROGATE: SetServiceStatus(StatusHandle, Status);
  end;
end;

procedure ServiceMain(Argc: DWORD; Argv: PPWideChar); stdcall;
begin
  StatusHandle := RegisterServiceCtrlHandlerEx(SERVICE_NAME, @Handler, nil);
  if StatusHandle = 0 then Exit;
  ZeroMemory(@Status, SizeOf(Status));
  ReportStatus(SERVICE_START_PENDING, NO_ERROR, 30000);
  StopEvent := CreateEvent(nil, True, False, nil);
  try
    Api := TWorbyDll.Create;
    try
      Api.StartAll;
      ReportStatus(SERVICE_RUNNING, NO_ERROR, 0);
      WaitForSingleObject(StopEvent, INFINITE);
      Api.StopAll;
    finally Api.Free; end;
    ReportStatus(SERVICE_STOPPED, NO_ERROR, 0);
  except
    ReportStatus(SERVICE_STOPPED, ERROR_EXCEPTION_IN_SERVICE, 0);
  end;
  CloseHandle(StopEvent);
end;

procedure InstallService;
var SCM, Svc: SC_HANDLE; Path: string; Desc: SERVICE_DESCRIPTION;
begin
  Path := '"' + ParamStr(0) + '"';
  SCM := OpenSCManager(nil, nil, SC_MANAGER_CREATE_SERVICE);
  if SCM = 0 then RaiseLastOSError;
  try
    Svc := CreateService(SCM, SERVICE_NAME, DISPLAY_NAME, SERVICE_ALL_ACCESS,
      SERVICE_WIN32_OWN_PROCESS, SERVICE_AUTO_START, SERVICE_ERROR_NORMAL,
      PChar(Path), nil, nil, nil, nil, nil);
    if Svc = 0 then RaiseLastOSError;
    try
      Desc.lpDescription := 'Gerencia aplicativos Worby/Orbi';
      ChangeServiceConfig2(Svc, SERVICE_CONFIG_DESCRIPTION, @Desc);
      Writeln('Servico instalado com inicio automatico.');
    finally CloseServiceHandle(Svc); end;
  finally CloseServiceHandle(SCM); end;
end;

procedure UninstallService;
var SCM, Svc: SC_HANDLE; St: SERVICE_STATUS;
begin
  SCM := OpenSCManager(nil, nil, SC_MANAGER_CONNECT);
  if SCM = 0 then RaiseLastOSError;
  try
    Svc := OpenService(SCM, SERVICE_NAME, SERVICE_STOP or SERVICE_DELETE_ACCESS);
    if Svc = 0 then RaiseLastOSError;
    try
      ControlService(Svc, SERVICE_CONTROL_STOP, St);
      if not DeleteService(Svc) then RaiseLastOSError;
      Writeln('Servico removido.');
    finally CloseServiceHandle(Svc); end;
  finally CloseServiceHandle(SCM); end;
end;

var Table: array[0..1] of SERVICE_TABLE_ENTRY;
begin
  try
    if SameText(ParamStr(1), '/install') then InstallService
    else if SameText(ParamStr(1), '/uninstall') then UninstallService
    else
    begin
      Table[0].lpServiceName := SERVICE_NAME;
      Table[0].lpServiceProc := @ServiceMain;
      Table[1].lpServiceName := nil; Table[1].lpServiceProc := nil;
      if not StartServiceCtrlDispatcher(@Table[0]) then RaiseLastOSError;
    end;
  except
    on E: Exception do begin Writeln(E.Message); Halt(1); end;
  end;
end.
