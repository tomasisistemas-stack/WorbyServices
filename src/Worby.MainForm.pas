unit Worby.MainForm;

interface

uses
  System.Classes, System.SysUtils, FMX.Types, FMX.Controls, FMX.Forms,
  FMX.StdCtrls, FMX.Layouts, FMX.ListBox, Worby.DllApi;

type
  TMainForm = class(TForm)
  private
    FApi: TWorbyDll;
    FList: TListBox;
    FStatus: TLabel;
    procedure BuildUi;
    procedure RefreshList;
    procedure StartClick(Sender: TObject);
    procedure StopClick(Sender: TObject);
    procedure RestartClick(Sender: TObject);
    procedure RefreshClick(Sender: TObject);
    function SelectedIndex: Integer;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

const
  Names: array[0..6] of string = ('WorbyRepRest - Plasfan',
    'WorbyRepRest - Filho Criador', 'OrbiAPI - Filho Criador', 'OrbiAPI - Plasfan',
    'EmissorFila - Plasfan', 'EmissorFila - Filho Criador', 'WorbyScannerRest');

constructor TMainForm.Create(AOwner: TComponent);
begin
  // A tela e criada integralmente em codigo e nao possui arquivo .fmx.
  // CreateNew impede o FireMonkey de procurar o recurso TMainForm.
  inherited CreateNew(AOwner);
  Caption := 'Worby Services'; Width := 820; Height := 520;
  FApi := TWorbyDll.Create;
  BuildUi;
  RefreshList;
end;

destructor TMainForm.Destroy;
begin FApi.Free; inherited; end;

procedure TMainForm.BuildUi;
var
  Top, Buttons: TLayout;
  Title: TLabel;
  procedure AddButton(const Text: string; Handler: TNotifyEvent);
  var B: TButton;
  begin
    B := TButton.Create(Self); B.Parent := Buttons; B.Align := TAlignLayout.Left;
    B.Width := 145; B.Margins.Right := 8; B.Text := Text; B.OnClick := Handler;
  end;
begin
  Top := TLayout.Create(Self); Top.Parent := Self; Top.Align := TAlignLayout.Top; Top.Height := 72;
  Title := TLabel.Create(Self); Title.Parent := Top; Title.Align := TAlignLayout.Client;
  Title.Text := 'Gerenciador de servicos Worby'; Title.TextSettings.Font.Size := 24;
  Title.Margins.Left := 20; Title.VertTextAlign := TTextAlign.Center;
  FList := TListBox.Create(Self); FList.Parent := Self; FList.Align := TAlignLayout.Client;
  FList.Margins.Left := 20; FList.Margins.Right := 20;
  Buttons := TLayout.Create(Self); Buttons.Parent := Self; Buttons.Align := TAlignLayout.Bottom;
  Buttons.Height := 72; Buttons.Padding.Left := 20; Buttons.Padding.Top := 12;
  AddButton('Iniciar', StartClick); AddButton('Parar', StopClick);
  AddButton('Reiniciar', RestartClick); AddButton('Atualizar', RefreshClick);
  FStatus := TLabel.Create(Self); FStatus.Parent := Self; FStatus.Align := TAlignLayout.Bottom;
  FStatus.Height := 32; FStatus.Margins.Left := 20; FStatus.Text := 'Selecione um item ou use sem selecao para todos.';
end;

function TMainForm.SelectedIndex: Integer;
begin Result := FList.ItemIndex; end;

procedure TMainForm.RefreshList;
var I: Integer; Mark: string;
begin
  FList.BeginUpdate;
  try
    FList.Clear;
    for I := 0 to High(Names) do
    begin
      if FApi.IsRunning(I) then Mark := '[EM EXECUCAO] ' else Mark := '[PARADO] ';
      FList.Items.Add(Mark + Names[I]);
    end;
  finally FList.EndUpdate; end;
end;

procedure TMainForm.StartClick(Sender: TObject);
begin if SelectedIndex < 0 then FApi.StartAll else FApi.StartItem(SelectedIndex); RefreshList; end;
procedure TMainForm.StopClick(Sender: TObject);
begin if SelectedIndex < 0 then FApi.StopAll else FApi.StopItem(SelectedIndex); RefreshList; end;
procedure TMainForm.RestartClick(Sender: TObject);
begin if SelectedIndex < 0 then FApi.RestartAll else FApi.RestartItem(SelectedIndex); RefreshList; end;
procedure TMainForm.RefreshClick(Sender: TObject); begin RefreshList; end;

end.
