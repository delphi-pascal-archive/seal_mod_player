program mp;

uses
  Forms,
  mp1 in 'mp1.pas' {MainForm},
  Audio in 'Audio.pas',
  mp2 in 'mp2.pas' {AboutBox},
  mp3 in 'mp3.pas' {PropertiesForm};

{$R *.RES}

begin
  Application.Initialize;
  Application.Title := 'SEAL Module Player';
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TAboutBox, AboutBox);
  Application.CreateForm(TPropertiesForm, PropertiesForm);
  Application.Run;
end.
