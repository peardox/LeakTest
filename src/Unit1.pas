unit Unit1;

interface

// {$define usex3d}
// {$define use2dview}

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, Fmx.CastleControl,
  CastleViewport, CastleUIControls, CastleScene, CastleVectors, CastleTransform
  ;

type
  { TCastleSceneHelper }
  TCastleSceneHelper = class helper for TCastleScene
    function Normalize: Boolean;
    { Fit the Scene in a 1x1x1 box }
  end;

  { TCastleSceneHelper }
  TCastleCameraHelper = class helper for TCastleCamera
    procedure ViewFromRadius(const ARadius: Single; const ACamPos: TVector3);
    { Position Camera ARadius from Origin pointing at Origin }
  end;

  { TCastleApp }
  TCastleApp = class(TCastleView)
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override; // TCastleUserInterface
    procedure Start; override; // TCastleView
    procedure Stop; override; // TCastleView
    procedure Resize; override; // TCastleUserInterface
  private
    ActiveScene: TCastleScene;
    Camera: TCastleCamera;
    CameraLight: TCastleDirectionalLight;
    Viewport: TCastleViewport;
  {$ifdef usebackimage} // Not done yet
    VPBackImage: TCastleImageControl;
  {$endif}
    function CreateDirectionalLight(LightPos: TVector3): TCastleDirectionalLight;
    function LoadScene(filename: String): TCastleScene;
    procedure LoadViewport;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

  { TForm }
  TForm1 = class(TForm)
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
    GLViewPort: TCastleControl;
    CastleApp: TCastleApp;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

uses Math, CastleProjection, CastleFilesUtils;

function TCastleSceneHelper.Normalize: Boolean;
var
  BBMax: Single;
begin
  Result := False;
  if not(RootNode = nil) then
    begin
    if not LocalBoundingBox.IsEmptyOrZero then
      begin
        if LocalBoundingBox.MaxSize > 0 then
          begin
            Center := Vector3(Min(LocalBoundingBox.Data[0].X, LocalBoundingBox.Data[1].X) + (LocalBoundingBox.SizeX / 2),
                              Min(LocalBoundingBox.Data[0].Y, LocalBoundingBox.Data[1].Y) + (LocalBoundingBox.SizeY / 2),
                              Min(LocalBoundingBox.Data[0].Z, LocalBoundingBox.Data[1].Z) + (LocalBoundingBox.SizeZ / 2));
            Translation := -Center;

            BBMax := 1 / LocalBoundingBox.MaxSize;
            Scale := Vector3(BBMax,
                             BBMax,
                             BBMax);
            Result := True;
          end;
      end;
    end;
end;

constructor TCastleApp.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
end;

destructor TCastleApp.Destroy;
begin
  inherited;
end;

procedure TCastleApp.Update(const SecondsPassed: Single; var HandleInput: Boolean);
begin
  inherited;
end;

procedure TCastleApp.Resize;
begin
  Viewport.Width := Container.Width;
  Viewport.Height := Container.Height;
{$ifdef use2dview}
  if Viewport.Width > Viewport.Height then
    Camera.Orthographic.Height := 1
  else
    Camera.Orthographic.Width := 1;
{$endif}
end;

procedure TCastleApp.Start;
var
 datadir: String;
{$ifdef debugbox} // Not done yet
  dbg: TDebugTransformBox;
{$endif}
begin
  inherited;
  // Kludgy castle-data finder
  if DirectoryExists('../../data/') then
    datadir := '../../data/'
  else if DirectoryExists('data/') then
    datadir := 'data/'
  else
    datadir := '';
  ApplicationDataOverride := datadir;

  LoadViewport;
{$ifdef usex3d}
  ActiveScene := LoadScene('castle-data:/knight.x3d');
{$else}
  ActiveScene := LoadScene('castle-data:/knight.gltf');
{$endif}
  ActiveScene.Normalize;
  if Assigned(ActiveScene) then
    Viewport.Items.Add(ActiveScene);
{$ifdef usedebugbox} // Not done yet
  dbg := TDebugTransformBox.Create(Self);
  dbg.Parent := ActiveScene;
  dbg.Exists := True;
{$endif}
end;

procedure TCastleApp.Stop;
begin
  inherited;
end;

function TCastleApp.CreateDirectionalLight(LightPos: TVector3): TCastleDirectionalLight;
var
  Light: TCastleDirectionalLight;
begin
  Light := TCastleDirectionalLight.Create(Self);

  Light.Direction := LightPos;
  Light.Color := Vector3(1, 1, 1);
  Light.Intensity := 1;

  Result := Light;
end;

procedure TCastleApp.LoadViewport;
begin
  Viewport := TCastleViewport.Create(Self);
  Viewport.FullSize := False;
  Viewport.Width := Container.Width;
  Viewport.Height := Container.Height;
  Viewport.Transparent := True;

{$ifdef usebackimage} // Not done yet
  VPBackImage := TCastleImageControl.Create(Viewport);
  VPBackImage.OwnsImage := True;
  VPBackImage.Url := SystemSettings.AppHome + '/wallpaper/WOE_1080p_en.jpg';
  VPBackImage.Stretch := True;

  InsertFront(VPBackImage);
{$endif}

  Camera := TCastleCamera.Create(Viewport);

{$ifdef use2dview}
  Viewport.Setup2D;
  Camera.ProjectionType := ptOrthographic;
  Camera.Orthographic.Width := 1;
  Camera.Orthographic.Origin := Vector2(0.5, 0.5);
{$else}
  Camera.ViewFromRadius(2, Vector3(1, 1, 1));
{$endif}

  CameraLight := CreateDirectionalLight(Vector3(0,0,1));
  Camera.Add(CameraLight);

  Viewport.Items.Add(Camera);
  Viewport.Camera := Camera;

  InsertFront(Viewport);
end;

function TCastleApp.LoadScene(filename: String): TCastleScene;
begin
  Result := Nil;
  try
    Result := TCastleScene.Create(Self);
    Result.Load(filename);
  except
    on E : Exception do
      begin
        ShowMessage('Error in LoadScene : ' + E.ClassName + ' - ' + E.Message);
       end;
  end;
end;

procedure TCastleCameraHelper.ViewFromRadius(const ARadius: Single; const ACamPos: TVector3);
var
  Spherical: TVector3;
begin
  Spherical := ACamPos.Normalize;
  Spherical := Spherical * ARadius;
  Up := Vector3(0, 1, 0);
  Direction := -ACamPos;
  Translation  := Spherical;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  GLViewPort := TCastleControl.Create(Self);
  GLViewport.Align := TAlignLayout.Client;
  GLViewport.Parent := Self;
  GLViewport.Align := TAlignLayout.Client;
  CastleApp := TCastleApp.Create(GLViewport);
  GLViewport.Container.View := CastleApp;
end;

end.
