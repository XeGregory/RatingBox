unit URatingBox;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls,
  Winapi.GDIPAPI, Winapi.GDIPOBJ, System.Math;

type
  TForm1 = class(TForm)
    PaintBox1: TPaintBox;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure PaintBox1Paint(Sender: TObject);
    procedure PaintBox1MouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure PaintBox1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PaintBox1MouseLeave(Sender: TObject);

  private
    FGdiPlusToken: ULONG_PTR;
    FMaxStars: Integer;
    FStarSize: Integer;
    FStarSpacing: Integer;
    FAvgValue: Double;
    FCountVotes: Integer;
    FHoverValue: Double;
    FSnapStep: Double;

    function StarPolygon(const CX, CY, ROuter, RInner: Single;
      PointsCount: Integer): TGPGraphicsPath;
    function ValueFromPosRaw(X: Integer): Double;
    function SnapValue(const AValue: Double): Double;
    function ValueFromPos(X: Integer): Double;
    procedure AddVote(ClickedValue: Double);
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

type
  TGPPointFArrayLocal = array of TGPPointF;

procedure TForm1.FormCreate(Sender: TObject);
var
  StartupInput: TGdiplusStartupInput;
  Status: TStatus;
begin
  StartupInput.GdiplusVersion := 1;
  StartupInput.DebugEventCallback := nil;
  StartupInput.SuppressBackgroundThread := False;
  StartupInput.SuppressExternalCodecs := False;
  FGdiPlusToken := 0;
  Status := GdiplusStartup(FGdiPlusToken, @StartupInput, nil);
  if Status <> Ok then
    raise Exception.CreateFmt('GDI+ initialization failed (code %d)',
      [Integer(Status)]);

  // Paramètres par défaut
  FMaxStars := 5;
  FStarSize := 70;
  FStarSpacing := 8;
  FAvgValue := 0;
  FCountVotes := 0;
  FHoverValue := 0.0;

  FSnapStep := 0.5;

  PaintBox1.OnPaint := PaintBox1Paint;
  PaintBox1.OnMouseMove := PaintBox1MouseMove;
  PaintBox1.OnMouseDown := PaintBox1MouseDown;
  PaintBox1.OnMouseLeave := PaintBox1MouseLeave;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  if FGdiPlusToken <> 0 then
    GdiplusShutdown(FGdiPlusToken);
end;

function TForm1.StarPolygon(const CX, CY, ROuter, RInner: Single;
  PointsCount: Integer): TGPGraphicsPath;
var
  I: Integer;
  Angle, Step: Double;
  Pts: TGPPointFArrayLocal;
begin
  Step := Pi / PointsCount;
  SetLength(Pts, PointsCount * 2);
  Angle := -Pi / 2;
  for I := 0 to (PointsCount * 2 - 1) do
  begin
    if Odd(I) then
    begin
      Pts[I].X := CX + RInner * Cos(Angle);
      Pts[I].Y := CY + RInner * Sin(Angle);
    end
    else
    begin
      Pts[I].X := CX + ROuter * Cos(Angle);
      Pts[I].Y := CY + ROuter * Sin(Angle);
    end;
    Angle := Angle + Step;
  end;

  Result := TGPGraphicsPath.Create;
  if Length(Pts) > 0 then
    Result.AddPolygon(PGPPointF(@Pts[0]), Length(Pts));
end;

function TForm1.ValueFromPosRaw(X: Integer): Double;
var
  TotalWidth, StartX: Integer;
  StarW: Integer;
  RelX: Integer;
  Idx: Integer;
  Frac: Double;
begin
  StarW := FStarSize;
  TotalWidth := FMaxStars * StarW + (FMaxStars - 1) * FStarSpacing;
  StartX := Max(0, (PaintBox1.Width - TotalWidth) div 2);
  if X < StartX then
    Exit(0.0);
  RelX := X - StartX;
  Idx := RelX div (StarW + FStarSpacing);
  if Idx >= FMaxStars then
    Exit(FMaxStars);
  Frac := (RelX - Idx * (StarW + FStarSpacing)) / StarW;
  Frac := EnsureRange(Frac, 0.0, 1.0);
  Result := Idx + Frac;
  if Result < 0 then
    Result := 0;
  if Result > FMaxStars then
    Result := FMaxStars;
end;

function TForm1.SnapValue(const AValue: Double): Double;
var
  Step, Inv: Double;
begin
  Step := FSnapStep;
  if (Step <= 0) then
    Exit(AValue);

  if AValue <= 0 then
    Exit(0);
  if AValue >= FMaxStars then
    Exit(FMaxStars);
  Inv := 1.0 / Step;

  Result := Round(AValue * Inv) / Inv;
  Result := EnsureRange(Result, 0.0, FMaxStars);
end;

function TForm1.ValueFromPos(X: Integer): Double;
begin
  Result := SnapValue(ValueFromPosRaw(X));
end;

procedure TForm1.AddVote(ClickedValue: Double);
begin
  FAvgValue := (FAvgValue * FCountVotes + ClickedValue) / (FCountVotes + 1);
  Inc(FCountVotes);
  PaintBox1.Invalidate;
end;

procedure TForm1.PaintBox1Paint(Sender: TObject);
var
  G: TGPGraphics;
  I: Integer;
  StarW, TotalWidth, StartX, CX, cyInt: Integer;
  OuterR, InnerR: Single;
  Path: TGPGraphicsPath;
  GoldBrush, GrayBrush: TGPSolidBrush;
  OutlinePen: TGPPen;
  UseValue: Double;
  StarRectLeft, starRectTop: Single;
  FillPercent: Double;
  Txt: string;
  TxtW, txtH: Integer;
begin
  PaintBox1.Canvas.Brush.Color := PaintBox1.Color;
  PaintBox1.Canvas.FillRect(PaintBox1.ClientRect);

  G := TGPGraphics.Create(PaintBox1.Canvas.Handle);
  try
    G.SetSmoothingMode(SmoothingModeAntiAlias);

    StarW := FStarSize;
    TotalWidth := FMaxStars * StarW + (FMaxStars - 1) * FStarSpacing;
    StartX := Max(0, (PaintBox1.Width - TotalWidth) div 2);
    cyInt := (PaintBox1.Height + 8) div 2 + 8;

    OuterR := StarW / 2;
    InnerR := OuterR * 0.45;

    GoldBrush := TGPSolidBrush.Create(MakeColor(255, 255, 200, 0));
    GrayBrush := TGPSolidBrush.Create(MakeColor(255, 230, 230, 230));
    OutlinePen := TGPPen.Create(MakeColor(255, 80, 80, 80), 1.0);

    try
      if FHoverValue > 0 then
        UseValue := FHoverValue
      else
        UseValue := FAvgValue;

      for I := 0 to FMaxStars - 1 do
      begin
        StarRectLeft := StartX + I * (StarW + FStarSpacing);
        starRectTop := cyInt - OuterR;
        CX := Round(StarRectLeft + OuterR);

        Path := StarPolygon(CX, cyInt, OuterR, InnerR, 5);
        try
          G.FillPath(GrayBrush, Path);

          FillPercent := EnsureRange(UseValue - I, 0.0, 1.0);
          if FillPercent > 0 then
          begin
            G.SetClip(Path, CombineModeReplace);
            G.FillRectangle(GoldBrush, StarRectLeft, starRectTop,
              StarW * FillPercent, StarW);
            G.ResetClip;
          end;

          G.DrawPath(OutlinePen, Path);
        finally
          Path.Free;
        end;
      end;

      Txt := Format('%.2f (%d votes)', [FAvgValue, FCountVotes]);
      with PaintBox1.Canvas do
      begin
        Font.Name := 'Segoe UI';
        Font.Size := 16;
        Font.Color := clBlack;
        TxtW := TextWidth(Txt);
        txtH := TextHeight(Txt);
        TextOut((PaintBox1.Width - TxtW) div 2, cyInt - Round(OuterR) - txtH
          - 6, Txt);
      end;

    finally
      GoldBrush.Free;
      GrayBrush.Free;
      OutlinePen.Free;
    end;

  finally
    G.Free;
  end;
end;

procedure TForm1.PaintBox1MouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
  NewHover: Double;
begin
  NewHover := ValueFromPos(X);
  if Abs(NewHover - FHoverValue) > 0.001 then
  begin
    FHoverValue := NewHover;
    PaintBox1.Invalidate;
  end;
end;

procedure TForm1.PaintBox1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  ClickedVal: Double;
begin
  ClickedVal := ValueFromPos(X);
  if ClickedVal > 0 then
  begin
    AddVote(ClickedVal);
    FHoverValue := 0;
  end;
end;

procedure TForm1.PaintBox1MouseLeave(Sender: TObject);
begin
  if FHoverValue <> 0 then
  begin
    FHoverValue := 0;
    PaintBox1.Invalidate;
  end;
end;

end.
