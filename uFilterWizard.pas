(* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is uFilterWizard.pas
 *
 * The Initial Developer of the Original Code is
 * Shinji Chikugi
 *
 * Portions created by the Initial Developer are Copyright (C) 2010-
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *
 * ***** END LICENSE BLOCK ***** *)


unit uFilterWizard;

interface

uses
  SysUtils, Classes, ToolsAPI, Forms, Menus, Dialogs,
  Controls, IOUtils, uFrmOption, uFormatterOption, uCommandLineUnit ;

type
  TFilterWizard = class(TDataModule)
    PopupMenu1: TPopupMenu;
    miOption: TMenuItem;
    procedure DataModuleCreate(Sender: TObject);
    procedure miOptionClick(Sender: TObject);
    procedure miExecFormatterClick(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
  private
    { Private �錾 }
    FFormatterOption: TFormatterOption;
    miExecFormatter: TMenuItem;
  public
    { Public �錾 }
  end;

var
  FilterWizard: TFilterWizard;
  SourceEditorNotifiers: TList = nil; // �\�[�X�G�f�B�^�̃m�[�e�B�t�@�C�A�I�u�W�F�N�g
  IDENotifierIndex: Integer = -1; // IDE�ɓo�^���Ă���m�[�e�B�t�@�C�A��
const
  EditReaderBufferSize = 1024 * 24;
procedure Register;

implementation

{$R *.dfm}

// IDE���g������E�C�U�[�h���W���[��
type
  TWizard = class(TInterfacedObject, IOTAWizard, IOTANotifier)
  public
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Execute;
    procedure Modified;
    function GetState: TWizardState;

    function GetIDString: string;
    function GetName: string;

    constructor Create;
    destructor Destroy; override;
end;

// IDE�̃m�[�e�B�t�@�C�A
type
  TIDENotifier = class(TNotifierObject, IOTANotifier, IOTAIDENotifier)
  private
    procedure FileNotification(NotifyCode: TOTAFileNotification; const FileName: string; var Cancel: Boolean);
    procedure BeforeCompile(const Project: IOTAProject; var Cancel: Boolean); overload;
    procedure AfterCompile(Succeeded: Boolean); overload;
end;

// �\�[�X�G�f�B�^�̃m�[�e�B�t�@�C�A
type
  TSourceEditorNotifier = class(TNotifierObject, IOTANotifier, IOTAEditorNotifier)
  private
    FEditor: IOTASourceEditor;
    FIndex: Integer;

    procedure Destroyed;
    procedure ViewActivated(const View: IOTAEditView);
    procedure ViewNotification(const View: IOTAEditView; Operation: TOperation);
  public
    constructor Create(AEditor: IOTASourceEditor);
    destructor Destroy; override;
end;


// �\�[�X�G�f�B�^�ɓo�^���Ă���m�[�e�B�t�@�C�A���폜
procedure ClearSourceEditorNotifiers;
var
  I: Integer;
begin
  if Assigned(SourceEditorNotifiers) then
    for I := SourceEditorNotifiers.Count - 1 downto 0 do
      TSourceEditorNotifier(SourceEditorNotifiers[I]).Destroyed;
end;

// �\�[�X�G�f�B�^�Ƀm�[�e�B�t�@�C�A��o�^
procedure InstallSourceEditorNotifiers(Module: IOTAModule);
var
  I: Integer;
  SourceEditor: IOTASourceEditor;
begin
  for I := 0 to Module.ModuleFileCount - 1 do
    if Supports(Module.ModuleFileEditors[I], IOTASourceEditor, SourceEditor) then
    begin
      SourceEditorNotifiers.Add(TSourceEditorNotifier.Create(SourceEditor));
      SourceEditor := nil;
    end;
end;


// IDE���g������p�b�P�[�W�̓o�^
procedure Register;
var
  Services: IOTAServices;
  ModuleServices: IOTAModuleServices;
  I: Integer;
begin
  // Wizard�̓o�^
  RegisterPackageWizard(TWizard.Create);

  // IDE�̃m�[�e�B�t�@�C�A�̓o�^
  Services := BorlandIDEServices as IOTAServices;
  Assert(Assigned(Services), 'IOTAServices not available');
  IDENotifierIndex := Services.AddNotifier(TIdeNotifier.Create);

  // �\�[�X�G�f�B�^�̃m�[�e�B�t�@�C�A�̓o�^
  SourceEditorNotifiers := TList.Create;
  ModuleServices := BorlandIDEServices as IOTAModuleServices;
  if ModuleServices.ModuleCount = 0 then
    Exit;
  for I := 0 to ModuleServices.ModuleCount - 1 do
    InstallSourceEditorNotifiers(ModuleServices.Modules[I]);

end;

// IDE�ɓo�^���Ă���m�[�e�B�t�@�C�A���폜����
procedure RemoveNotifier;
var
  Services: IOTAServices;
begin
  if IDENotifierIndex <> -1 then
  begin
    Services := BorlandIDEServices as IOTAServices;
    Assert(Assigned(Services), 'IOTAServices not available');
    Services.RemoveNotifier(IDENotifierIndex);
  end;
end;


(*
���̕ӂ�OTA�֌W�̊֐���GExperts�̃R�[�h��q�؁B
copyright 1996-2010 by Erik Berry and the GExperts Development Team
���̕����̃��C�Z���X�́Ahttp://www.gexperts.org/license.html
*)

function GxGetCurrentSourceEditor: IOTASourceEditor;
var
  i: Integer;
  Editor: IOTAEditor;
  ISourceEditor: IOTASourceEditor;
  CurrentModule: IOTAModule;
begin
  Result := nil;
  CurrentModule := (BorlandIDEServices as IOTAModuleServices).CurrentModule;

  for i := 0 to CurrentModule.GetModuleFileCount - 1 do
  begin
    Editor := CurrentModule.GetModuleFileEditor(i);

    if Supports(Editor, IOTASourceEditor, ISourceEditor) then
    begin
      Result := ISourceEditor;
      Break;
    end;
  end;
end;

procedure GxSaveReaderToStream(EditReader: IOTAEditReader; Stream: TStream;
  TrailingNull: Boolean);
const
  // Leave typed constant as is - needed for streaming code.
  TerminatingNullChar: AnsiChar = #0;
var
  EditReaderPos: Integer;
  ReadDataSize: Integer;
  Buffer: array [0 .. EditReaderBufferSize] of AnsiChar;
  // Array of bytes, might be UTF-8
begin
  Assert(EditReader <> nil);
  Assert(Stream <> nil);

  EditReaderPos := 0;
  ReadDataSize := EditReader.GetText(EditReaderPos, Buffer,
    EditReaderBufferSize);
  Inc(EditReaderPos, ReadDataSize);
  while ReadDataSize = EditReaderBufferSize do
  begin
    Stream.Write(Buffer, ReadDataSize);
    ReadDataSize := EditReader.GetText(EditReaderPos, Buffer,
      EditReaderBufferSize);
    Inc(EditReaderPos, ReadDataSize);
  end;
  Stream.Write(Buffer, ReadDataSize);
  if TrailingNull then
    Stream.Write(TerminatingNullChar, SizeOf(TerminatingNullChar));
  // The source parsers need this
end;

// �\�[�X�G�f�B�^�̒��g��TSTrings�Ƀ��[�h����
procedure GxLoadSourceEditorToUnicodeStrings(SourceEditor: IOTASourceEditor; Data: TStrings);
var
  MemStream: TMemoryStream;
begin
  Data.Clear;
  if not Assigned(SourceEditor) then
    raise Exception.Create
      ('No source editor in GxOtaLoadSourceEditorToUnicodeStrings');
  // TODO: Check stream format for forms as text (Ansi with escaped unicode, or UTF-8) in Delphi 2007/2009
  MemStream := TMemoryStream.Create;
  try
    GxSaveReaderToStream(SourceEditor.CreateReader, MemStream, False);
    MemStream.Position := 0;
{$IFDEF UNICODE}
    Data.LoadFromStream(MemStream, TEncoding.UTF8);
{$ELSE}
    if RunningDelphi8OrGreater then
      SynUnicode.LoadFromStream(Data, MemStream, seUTF8)
    else
      SynUnicode.LoadFromStream(Data, MemStream, seAnsi);
{$ENDIF}
  finally
    FreeAndNil(MemStream);
  end;
end;


procedure GxReplaceEditorText(SourceEditor: IOTASourceEditor; Text: string);
var
  Writer: IOTAEditWriter;
begin
  Assert(Assigned(SourceEditor));
  Writer := SourceEditor.CreateUndoableWriter;
  if not Assigned(Writer) then
    raise Exception.Create('No edit writer');
  Writer.DeleteTo(MaxLongint);
  Writer.Insert(PAnsiChar(AnsiToUtf8(Text)));
  Writer := nil;
end;

(*
GExperts�̃R�[�h��q�؂����̂͂����܂ŁB
*)


constructor TWizard.Create;
begin
  FilterWizard := TFilterWizard.Create(nil);
end;

destructor TWizard.Destroy;
begin
  FilterWizard.Free;
end;

function TWizard.GetIDString: string;
begin
  Result := 'DHS Uncrustify Filter Wizard';
end;

function TWizard.GetName: string;
begin
  Result := 'Uncrustify Filter Wizard';
end;

procedure TWizard.AfterSave;
begin
end;

procedure TWizard.BeforeSave;
begin
end;

procedure TWizard.Destroyed;
begin
end;

procedure TWizard.Execute;
begin
end;

function TWizard.GetState: TWizardState;
begin
  Result := [];
end;

procedure TWizard.Modified;
begin
end;

procedure TFilterWizard.DataModuleCreate(Sender: TObject);
var
  i: Integer;
  ItemIndex: Integer;
  InsertPosition: Integer;
  IDEMainMenu: TMainMenu;
  ToolsMenu: TMenuItem;
begin

  miExecFormatter := TMenuItem.Create(nil);
  with miExecFormatter do begin
    Caption := '�O�����`�c�[���Ń\�[�X�̐��`(&U)';
    OnClick := miExecFormatterClick;
  end;


  // ���C�����j���[��[�c�[��|�I�v�V����]��T��
  IDEMainMenu := (BorlandIDEServices as INTAServices).MainMenu;
  ToolsMenu := nil;
  with IDEMainMenu do begin
    for I := 0 to Items.Count - 1 do begin
      if AnsiSameText(Items[I].Name, 'ToolsMenu') then
        ToolsMenu := Items[I];
    end;
  end;

  InsertPosition := ToolsMenu.Count;
  for I := 0 to ToolsMenu.Count-1 do begin
    if AnsiSameText(ToolsMenu.Items[I].Name, 'ToolsOptionsItem') then
    begin
      InsertPosition := I;
      Break;
    end;
  end;

  // PopUpMenu����IDE��[�c�[��|�I�v�V����]��MenuItem���ړ�
  ItemIndex := PopupMenu1.Items.IndexOf(miOption);
  PopupMenu1.Items.Delete(ItemIndex);
  ToolsMenu.Insert(InsertPosition, miOption);

  // �I�v�V�������̎擾
  FFormatterOption := TFormatterOption.Create;
end;

procedure TIdeNotifier.AfterCompile(Succeeded: Boolean);
begin
end;

procedure TIdeNotifier.BeforeCompile(const Project: IOTAProject; var Cancel: Boolean);
begin
end;

// IDE�Ńt�@�C���ɂ��Ẳ��炩�̃C�x���g����������ƌĂяo�����
procedure TIdeNotifier.FileNotification(NotifyCode: TOTAFileNotification; const FileName: string; var Cancel: Boolean);
var
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
begin
  // �\�[�X�G�f�B�^�Ƀt�@�C�����ǂݍ��܂ꂽ��A�\�[�X�G�f�B�^�Ƀ��j���[�A�C�e����o�^����
  if NotifyCode =  ofnFileOpened then begin
    ModuleServices := BorlandIDEServices as IOTAModuleServices;
    Module := ModuleServices.FindModule(FileName);
    if Assigned(Module) then begin
      InstallSourceEditorNotifiers(Module);
    end;
  end;
end;

constructor TSourceEditorNotifier.Create(AEditor: IOTASourceEditor);
begin
  inherited Create;
  FEditor := AEditor;
  FIndex := FEditor.AddNotifier(Self);
end;

destructor TSourceEditorNotifier.Destroy;
begin
  SourceEditorNotifiers.Remove(Self);
  FEditor := nil;
  inherited Destroy;
end;

procedure TSourceEditorNotifier.Destroyed;
begin
  FEditor.RemoveNotifier(FIndex);
end;

// �\�[�X�G�f�B�^���A�N�e�B�u�ɂȂ�ƌĂяo�����
procedure TSourceEditorNotifier.ViewActivated(const View: IOTAEditView);
var
  EditWindow: INTAEditWindow;
  EditWindowForm: TCustomForm;
  EditorLocalMenu: TComponent;
  ParentMenu: TMenu;
begin
  EditWindow := View.GetEditWindow;
  if not Assigned(EditWindow) then
    Exit;

  EditWindowForm := EditWindow.Form;
  if not Assigned(EditWindowForm) then
    Exit;

  // �G�f�B�^�̃��j���[���擾
  EditorLocalMenu := EditWindowForm.FindComponent('EditorLocalMenu');
  if not Assigned(EditorLocalMenu) then
    Exit;

  try
    if (EditorLocalMenu is TMenu) then
    begin
      with FilterWizard do begin

        // �A�N�e�B�u�Ŗ����Ȃ����R�[�h�G�f�B�^���烁�j���[�A�C�e�����폜
        ParentMenu := miExecFormatter.GetParentMenu;
        if Assigned(ParentMenu) then
          ParentMenu.Items.Remove(miExecFormatter);

        // �A�N�e�B�u�ɂȂ����R�[�h�G�f�B�^�̃��j���[�Ƀ��j���[�A�C�e����o�^
        TMenu(EditorLocalMenu).Items.Add(miExecFormatter);
      end;
    end;
  except
    raise;
  end;
end;

procedure TSourceEditorNotifier.ViewNotification(const View: IOTAEditView; Operation: TOperation);
begin
end;

procedure TFilterWizard.DataModuleDestroy(Sender: TObject);
begin
  FreeAndNil(FFormatterOption);
end;

procedure TFilterWizard.miExecFormatterClick(Sender: TObject);
var
  Command: TCommandLineUnit;
  SourceEditor: IOTASourceEditor;
  Buffer: TStringList;
  CommandLine: string;
  Source: TMemoryStream;
  Output: TMemoryStream;
  Ext: string;
begin
  SourceEditor := GxGetCurrentSourceEditor;
  if SourceEditor = nil then
    Exit;

  // �g���q�Ńt�@�C����ނ��`�F�b�N
  Ext := LowerCase(Tpath.GetExtension(SourceEditor.FileName));
  if FFormatterOption.CheckExt(Ext) = false then begin
    MessageDlg('�ҏW���̃\�[�X�t�@�C����C/C++�ł͂Ȃ��̂Ő��`�ł��܂���B', mtInformation, [mbOK], 0);
    Exit;
  end;

  // �t�H�[�}�b�^�[�����s�\���`�F�b�N
  if (not TFile.Exists(FFormatterOption.FExePath)) then begin
    MessageDlg('�R�[�h�t�H�[�}�b�g�����s����A�v���P�[�V�������w�肵�Ă��������B', mtError, [mbOK], 0);
    Exit;
  end;

  if (not TFile.Exists(FFormatterOption.FConfigPath)) then begin
    MessageDlg('���`���s�����߂̐ݒ�t�@�C��������܂���B', mtError, [mbOK], 0);
    Exit;
  end;

  Buffer := TStringList.Create;
  Source := TMemoryStream.Create;
  Command := TCommandLineUnit.Create;

  // �\�[�X�G�f�B�^�̒��g���擾
  GxLoadSourceEditorToUnicodeStrings(SourceEditor, Buffer);
  Buffer.SaveToStream(Source, FFormatterOption.Encoding);

  // �R�[�h�t�H�[�}�b�^�[�̎��s
  CommandLine := FFormatterOption.BuildCommandLine();
  Output := Command.GrabStdOut(CommandLine, Source);
  if Output = nil then
    exit;

  // ���s���ʂ�ǂݍ���
  Output.Position := 0;
  Buffer.Clear;
  Buffer.LoadFromStream(Output, FFormatterOption.Encoding);

  // �\�[�X�G�f�B�^�̒��g��u��
  GxReplaceEditorText(SourceEditor, Buffer.Text);

  // ��n��
  FreeAndNil(Buffer);
  FreeAndNil(Source);
  FreeAndNil(Command);
  FreeAndNil(Output);
end;

procedure TFilterWizard.miOptionClick(Sender: TObject);
var
  f: TfrmOption;
begin
  f := TfrmOption.Create(nil);
  f.SetOption(FFormatterOption);
  if f.ShowModal = mrOk then begin
    f.GetOption(FFormatterOption);
    FFormatterOption.SaveOption();
  end;

  FreeAndNil(f);
end;

initialization

finalization
  RemoveNotifier;
  ClearSourceEditorNotifiers;
  FreeAndNil(SourceEditorNotifiers);

end.
