object Form1: TForm1
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  Caption = 'RatingBox'
  ClientHeight = 164
  ClientWidth = 389
  Color = clBtnFace
  DoubleBuffered = True
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poDesktopCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object PaintBox1: TPaintBox
    Left = 0
    Top = 0
    Width = 389
    Height = 164
    Align = alClient
    OnMouseDown = PaintBox1MouseDown
    OnMouseLeave = PaintBox1MouseLeave
    OnMouseMove = PaintBox1MouseMove
    OnPaint = PaintBox1Paint
    ExplicitLeft = 112
    ExplicitTop = 72
    ExplicitWidth = 105
    ExplicitHeight = 105
  end
end
