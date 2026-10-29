library WorbyServicesLib;

uses
  System.SysUtils,
  Worby.Manager in 'scr\Worby.Manager.pas';

var Manager: TWorbyManager;

function WSStartAll: LongBool; stdcall;
begin try Manager.StartAll; Result := True; except Result := False; end; end;
function WSStopAll: LongBool; stdcall;
begin try Manager.StopAll; Result := True; except Result := False; end; end;
function WSRestartAll: LongBool; stdcall;
begin try Manager.RestartAll; Result := True; except Result := False; end; end;
function WSStartItem(Index: Integer): LongBool; stdcall;
begin try Result := Manager.StartItem(Index); except Result := False; end; end;
function WSStopItem(Index: Integer): LongBool; stdcall;
begin try Result := Manager.StopItem(Index); except Result := False; end; end;
function WSRestartItem(Index: Integer): LongBool; stdcall;
begin try Result := Manager.RestartItem(Index); except Result := False; end; end;
function WSIsRunning(Index: Integer): LongBool; stdcall;
begin try Result := Manager.IsRunning(Index); except Result := False; end; end;
function WSGetStatus(Buffer: PWideChar; BufferChars: Integer): Integer; stdcall;
var S: string;
begin
  try
    S := Manager.StatusText;
    Result := Length(S) + 1;
    if (Buffer <> nil) and (BufferChars > 0) then
      StringToWideChar(S, Buffer, BufferChars);
  except Result := 0; end;
end;

exports WSStartAll, WSStopAll, WSRestartAll, WSStartItem, WSStopItem,
  WSRestartItem, WSIsRunning, WSGetStatus;

begin
  Manager := TWorbyManager.Create;
end.
