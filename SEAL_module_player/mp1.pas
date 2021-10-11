unit mp1;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Menus, Buttons, ExtCtrls, Audio, StdCtrls, IniFiles;

type
  TPlayerState = (psIdle, psPlaying, psPaused);
  
  TMainForm = class(TForm)
    MainMenu: TMainMenu;
    FileMenu: TMenuItem;
    HelpMenu: TMenuItem;
    OpenMenuItem: TMenuItem;
    CloseMenuItem: TMenuItem;
    PropertiesMenuItem: TMenuItem;
    ExitMenuItem: TMenuItem;
    AboutMenuItem: TMenuItem;
    N1: TMenuItem;
    N2: TMenuItem;
    MainPanel: TPanel;
    PlayButton: TSpeedButton;
    StopButton: TSpeedButton;
    RewindButton: TSpeedButton;
    ForwardButton: TSpeedButton;
    OpenDialog: TOpenDialog;
    Timer: TTimer;
    DisplayPanel: TPanel;
    PositionLabel: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure PlayButtonClick(Sender: TObject);
    procedure StopButtonClick(Sender: TObject);
    procedure OpenMenuItemClick(Sender: TObject);
    procedure CloseMenuItemClick(Sender: TObject);
    procedure ExitMenuItemClick(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    procedure RewindButtonMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure RewindButtonMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure AboutMenuItemClick(Sender: TObject);
    procedure PropertiesMenuItemClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    Module: PAudioModule;
    Info: TAudioInfo;
    State: TPlayerState;
    Looping: Boolean;
    AutoPlay: Boolean;
    FileName: String;
    InfoModified: Boolean;
    procedure SetState(AState: TPlayerState);
    procedure MovePosition(Step: Integer);
    procedure AppIdle(Sender: TObject; var Done: Boolean);
  end;

var
  MainForm: TMainForm;

implementation

uses mp2, mp3;

{$R *.DFM}

procedure TMainForm.FormCreate(Sender: TObject);
var
  IniFile: TIniFile;
begin
  Module := nil;
  InfoModified := False;
  Looping := True;
  AutoPlay := True;
  FileName := '';

  Info.nDeviceId := AUDIO_DEVICE_MAPPER;
  Info.wFormat := AUDIO_FORMAT_8BITS or AUDIO_FORMAT_MONO;
  Info.nSampleRate := 22050;
  IniFile := TIniFile.Create('MP.INI');
  try
    if IniFile.ReadInteger('SEAL Module Player', 'SampleSize', 16) = 16 then
      Info.wFormat := Info.wFormat or AUDIO_FORMAT_16BITS;
    if IniFile.ReadInteger('SEAL Module Player', 'Channels', 2) = 2 then
      Info.wFormat := Info.wFormat or AUDIO_FORMAT_STEREO;
    Info.nSampleRate := IniFile.ReadInteger('SEAL Module Player', 'SampleRate', 44100);
    if IniFile.ReadBool('SEAL Module Player', 'Filtering', True) = True then
      Info.wFormat := Info.wFormat or AUDIO_FORMAT_FILTER;
    Looping := IniFile.ReadBool('SEAL Module Player', 'Looping', True);
    AutoPlay := IniFile.ReadBool('SEAL Module Player', 'AutoPlay', True);
    FileName := IniFile.ReadString('SEAL Module Player', 'FileName', ''); 
  finally
    IniFile.Free;
  end;

  State := psIdle;
  SetState(State);
  AOpenAudio(Info);
  Application.OnIdle := AppIdle;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
var
  IniFile: TIniFile;
begin
  ACloseAudio;
  SetState(psIdle);
  if InfoModified then
  begin
    IniFile := TIniFile.Create('MP.INI');
    try
      if Info.wFormat and AUDIO_FORMAT_16BITS <> 0 then
        IniFile.WriteInteger('SEAL Module Player', 'SampleSize', 16)
      else
        IniFile.WriteInteger('SEAL Module Player', 'SampleSize', 8);
      if Info.wFormat and AUDIO_FORMAT_STEREO <> 0 then
        IniFile.WriteInteger('SEAL Module Player', 'Channels', 2)
      else
        IniFile.WriteInteger('SEAL Module Player', 'Channels', 1);
      IniFile.WriteInteger('SEAL Module Player', 'SampleRate', Info.nSampleRate);
      IniFile.WriteBool('SEAL Module Player', 'Filtering',
        Info.wFormat and AUDIO_FORMAT_FILTER <> 0);
      IniFile.WriteBool('SEAL Module Player', 'Looping', Looping);
      IniFile.WriteBool('SEAL Module Player', 'AutoPlay', AutoPlay);
      IniFile.WriteString('SEAL Module Player', 'FileName', FileName);
    finally
      IniFile.Free;
    end;
  end;
end;

procedure TMainForm.SetState(AState: TPlayerState);
begin
  if (State = psIdle) and (AState = psPaused) and Assigned(Module) then
  begin
    AOpenVoices(Module^.nTracks);
    APlayModule(Module);
    APauseModule;
    State := psPaused;
  end
  else if (State = psPaused) and (AState = psPlaying) then
  begin
    AResumeModule;
    State := psPlaying;
  end
  else if (State = psPlaying) and (AState = psPaused) then
  begin
    APauseModule;
    State := psPaused;
  end
  else if (State <> psIdle) and (AState = psIdle) then
  begin
    AStopModule;
    ACloseVoices;
    AFreeModuleFile(Module);
    Module := nil;
    State := psIdle;
  end;
  case State of
    psIdle:
      begin
        Self.Caption := 'SEAL Module Player';
        PlayButton.Enabled := False;
        StopButton.Enabled := False;
        RewindButton.Enabled := False;
        ForwardButton.Enabled := False;
        CloseMenuItem.Enabled := False;
        PropertiesMenuItem.Enabled := True;
      end;
    psPlaying:
      begin
        Self.Caption := StrPas(Module^.szModuleName);
        PlayButton.Enabled := False;
        StopButton.Enabled := True;
        RewindButton.Enabled := True;
        ForwardButton.Enabled := True;
        CloseMenuItem.Enabled := True;
        PropertiesMenuItem.Enabled := False;
      end;
    psPaused:
      begin
        Self.Caption := StrPas(Module^.szModuleName);
        PlayButton.Enabled := True;
        StopButton.Enabled := False;
        RewindButton.Enabled := False;
        ForwardButton.Enabled := False;
        CloseMenuItem.Enabled := True;
        PropertiesMenuItem.Enabled := False;
      end;
  end;
end;

procedure TMainForm.MovePosition(Step: Integer);
var
  Order, Row, Pos: Integer;
begin
  if State <> psIdle then
  begin
    AGetModulePosition(Order, Row);
    Pos := Order * 64 + Row;
    Inc(Pos, Step);
    if Pos >= 64 * Module^.nOrders then
      Pos := Pred(64 * Module^.nOrders)
    else if Pos < 0 then
      Pos := 0;
    Order := Pos div 64;
    Row := Pos mod 64;
    ASetModulePosition(Order, Row);
  end;
end;


procedure TMainForm.PlayButtonClick(Sender: TObject);
begin
  SetState(psPlaying);
end;

procedure TMainForm.StopButtonClick(Sender: TObject);
begin
  SetState(psPaused);
end;

procedure TMainForm.RewindButtonMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  (Sender as TSpeedButton).Tag := GetTickCount;
  if Sender = RewindButton then MovePosition(-64) else MovePosition(+64);
end;

procedure TMainForm.RewindButtonMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  (Sender as TSpeedButton).Tag := 0;
end;


procedure TMainForm.OpenMenuItemClick(Sender: TObject);
var
  szFileName: Array [0..256] of Char;
begin
  OpenDialog.FileName := FileName;
  if OpenDialog.Execute then
  begin
    if FileName <> OpenDialog.FileName then
    begin
      FileName := OpenDialog.FileName;
      InfoModified := True;
    end;
    SetState(psIdle);
    if ALoadModuleFile(StrPCopy(szFileName, OpenDialog.FileName),
        Module) = AUDIO_ERROR_NONE then
    begin
      if not Looping then
      begin
        Module^.nReStart := AUDIO_MAX_ORDERS;
      end
      else
      begin
        if Module^.nRestart >= Module^.nOrders then
          Module^.nRestart := 0;
      end;
      SetState(psPaused);
      if AutoPlay then SetState(psPlaying);
    end;
  end;
end;

procedure TMainForm.CloseMenuItemClick(Sender: TObject);
begin
  SetState(psIdle);
end;

procedure TMainForm.ExitMenuItemClick(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.TimerTimer(Sender: TObject);
const
  DelayTime = 500;
var
  Ticks: Integer;
begin
  if State <> psIdle then
  begin
    Ticks := GetTickCount;
    if (RewindButton.Tag <> 0) and (RewindButton.Tag + DelayTime < Ticks) then
      MovePosition(-16);
    if (ForwardButton.Tag <> 0) and (ForwardButton.Tag + DelayTime < Ticks) then
      MovePosition(+16);
  end;
end;

procedure TMainForm.AppIdle(Sender: TObject; var Done: Boolean);
var
  Order, Row: Integer;
begin
  if State <> psIdle then
  begin
    AGetModulePosition(Order, Row);
    PositionLabel.Caption := Format('%.2d:%.2d', [Order mod 100, Row mod 100]);
  end
  else
  begin
    PositionLabel.Caption := '00:00';
  end;
end;

procedure TMainForm.AboutMenuItemClick(Sender: TObject);
begin
  AboutBox.ShowModal;
end;

procedure TMainForm.PropertiesMenuItemClick(Sender: TObject);
begin
  if Info.wFormat and AUDIO_FORMAT_16BITS <> 0 then
    PropertiesForm.SixteenBitRadioButton.Checked := True
  else
    PropertiesForm.EightBitRadioButton.Checked := True;
    
  if Info.wFormat and AUDIO_FORMAT_STEREO <> 0 then
    PropertiesForm.StereoRadioButton.Checked := True
  else
    PropertiesForm.MonoRadioButton.Checked := True;

  PropertiesForm.FilteringCheckBox.Checked :=Info.wFormat and AUDIO_FORMAT_FILTER <> 0;
  PropertiesForm.LoopingCheckBox.Checked := Looping;
  PropertiesForm.AutoPlayCheckBox.Checked := AutoPlay;
  
  if Info.nSampleRate <= 11025 then
    PropertiesForm.LowRateRadioButton.Checked := True
  else if Info.nSampleRate <= 22050 then
    PropertiesForm.MedRateRadioButton.Checked := True
  else
    PropertiesForm.HighRateRadioButton.Checked := True;

  if PropertiesForm.ShowModal = mrOk then
  begin
    Info.nDeviceId := AUDIO_DEVICE_MAPPER;
    Info.wFormat := AUDIO_FORMAT_8BITS or AUDIO_FORMAT_MONO;
    Info.nSampleRate := 44100;
    if PropertiesForm.SixteenBitRadioButton.Checked then
      Info.wFormat := Info.wFormat or AUDIO_FORMAT_16BITS;
    if PropertiesForm.StereoRadioButton.Checked then
      Info.wFormat := Info.wFormat or AUDIO_FORMAT_STEREO;
    if PropertiesForm.FilteringCheckBox.Checked then
      Info.wFormat := Info.wFormat or AUDIO_FORMAT_FILTER;
    if PropertiesForm.LowRateRadioButton.Checked then
      Info.nSampleRate := 11025;
    if PropertiesForm.MedRateRadioButton.Checked then
      Info.nSampleRate := 22050;
    if PropertiesForm.HighRateRadioButton.Checked then
      Info.nSampleRate := 44100;
    Looping := PropertiesForm.LoopingCheckBox.Checked;
    AutoPlay := PropertiesForm.AutoPlayCheckBox.Checked;
    if State = psIdle then
    begin
      ACloseAudio;
      AOpenAudio(Info);
    end;
    InfoModified := True;
  end;
end;

end.
