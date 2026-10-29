unit Worby.DllApi;

interface

type
  TWorbyDll = class
  private
    FHandle: NativeUInt;
  public
    constructor Create;
    destructor Destroy; override;
    function StartAll: Boolean;
    function StopAll: Boolean;
    function RestartAll: Boolean;
    function StartItem(Index: Integer): Boolean;
    function StopItem(Index: Integer): Boolean;
    function RestartItem(Index: Integer): Boolean;
    function IsRunning(Index: Integer): Boolean;
  end;

implementation

uses Winapi.Windows, System.SysUtils;

type TAllProc = function: LongBool; stdcall;
type TItemProc = function(Index: Integer): LongBool; stdcall;

constructor TWorbyDll.Create;
begin
  inherited;
  FHandle := LoadLibrary(PChar(IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'WorbyServicesLib.dll'));
  if FHandle = 0 then RaiseLastOSError;
end;

destructor TWorbyDll.Destroy;
begin if FHandle <> 0 then FreeLibrary(FHandle); inherited; end;

function TWorbyDll.StartAll: Boolean; begin Result := TAllProc(GetProcAddress(FHandle, 'WSStartAll'))(); end;
function TWorbyDll.StopAll: Boolean; begin Result := TAllProc(GetProcAddress(FHandle, 'WSStopAll'))(); end;
function TWorbyDll.RestartAll: Boolean; begin Result := TAllProc(GetProcAddress(FHandle, 'WSRestartAll'))(); end;
function TWorbyDll.StartItem(Index: Integer): Boolean; begin Result := TItemProc(GetProcAddress(FHandle, 'WSStartItem'))(Index); end;
function TWorbyDll.StopItem(Index: Integer): Boolean; begin Result := TItemProc(GetProcAddress(FHandle, 'WSStopItem'))(Index); end;
function TWorbyDll.RestartItem(Index: Integer): Boolean; begin Result := TItemProc(GetProcAddress(FHandle, 'WSRestartItem'))(Index); end;
function TWorbyDll.IsRunning(Index: Integer): Boolean; begin Result := TItemProc(GetProcAddress(FHandle, 'WSIsRunning'))(Index); end;

end.
