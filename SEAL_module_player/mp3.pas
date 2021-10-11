unit mp3;

interface

uses
  SysUtils, Windows, Messages, Classes, Graphics, Controls,
  StdCtrls, ExtCtrls, Forms;

type
  TPropertiesForm = class(TForm)
    OkButton: TButton;
    CancelButton: TButton;
    SampleRateGroupBox: TGroupBox;
    LowRateRadioButton: TRadioButton;
    MedRateRadioButton: TRadioButton;
    HighRateRadioButton: TRadioButton;
    ChannelsGroupBox: TGroupBox;
    MonoRadioButton: TRadioButton;
    StereoRadioButton: TRadioButton;
    OptionsGroupBox: TGroupBox;
    FilteringCheckBox: TCheckBox;
    LoopingCheckBox: TCheckBox;
    SampleSizeGroupBox: TGroupBox;
    EightBitRadioButton: TRadioButton;
    SixteenBitRadioButton: TRadioButton;
    AutoPlayCheckBox: TCheckBox;
  end;

var
  PropertiesForm: TPropertiesForm;

implementation

{$R *.DFM}

end.
