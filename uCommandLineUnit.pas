//{$WARNINGS OFF}
//=============================================================================
//  �p�C�v�����ɂ��R�}���h���s�ƌ��ʂ����_�C���N�g���邽�߂̃��j�b�g
//
//  ���p���@�͂��̃��j�b�g��t�����Ă���T���v���v���O�����Q��
//
//  Fusa�����
//  http://delfusa.main.jp/delfusafloor/opensource/delfusa_library_f.html
//  �ɂ���R�[�h��
//  (1) �D�݂̃X�^�C���ɃR�[�h�𐮌`
//  (2) �֐���1�ǉ�
//  (3) Delphi2009�ȍ~�Ή��̃R�[�h��ǉ�
//  (4) �G���[���e��W���o�͂Ƀ��_�C���N�g
//  (5) �e�֐��̐擪�ɃR�����g��ǉ�
//  (6) �R�}���h���C����͗p�̃R�[�h�͍폜
//
//  ���C�Z���X���ɂ��Ă͈ȉ����Q�Ƃ̂���
//  http://delfusa.main.jp/delfusafloor/opensource/first.shtml
//  Fusa����T���N�X�ł�
//
//-----------------------------------------------------------------------------
//
//  2010�N01��26��
//
//  2010�N02��09��
//    �E�Ԉ�������j�b�g�t�@�C����Y�t���Ă����̂ł��̃t�@�C���Y�t�ɏC��
//    �ECreateProcess�̈�����DETACHED_PROCESS��CREATE_NEW_CONSOLE�ɕύX
//    �ETerminateProcess(ProcessInfo.hProcess, 0);��ǉ�(Mr.XRAY)
//
//  2010�N03��17��
//    �EUniqueString(CommandLine);��ǉ�(�Q�ƃJ�E���^�΍�)
//
//
//  2010�N03��25��
//    �EResult := S;��Result := UnicodeString(S);�Ɩ����I�ɃL���X�g
//
//-----------------------------------------------------------------------------
//
//  �y����m�F���z
//
//  Windows XP(SP3)
//    Delphi6(UP2) Pro
//    Delphi7 Pro
//    Delphi2007-R2 Pro
//    Delphi2009(UP3) Pro
//    Delphi2010(UP5) Pro
//
//  Windows Vista
//    Delphi2009(UP3) Pro
//    Delphi2010(UP5) Pro
//
//  Presented by Mr.XRAY
//  http://mrxray.on.coocan.jp/
//=============================================================================
unit uCommandLineUnit;

interface

uses
  SysUtils, Windows, Classes, Forms;

type
  TCommandLineUnit = class
  private
    FLoopProcessMessages: Boolean;
//    function GrabStdOut(CommandLine: string; StdIn: TMemoryStream): TMemoryStream;
    function GetStringFromStream(const Stream: TStream): String;
  public
    constructor Create;
    function GrabStdOut(CommandLine: string; StdIn: TMemoryStream): TMemoryStream;
    function GrabStdOutText(CommandLine: string): String; overload;
    function GrabStdOutText(CommandLine: string; StdInput: TStrings):
      String; overload;
    property LoopProcessMessages: Boolean read FLoopProcessMessages
                                          write FLoopProcessMessages;
  end;

implementation

//-----------------------------------------------------------------------------
//  ���ۂɃR�}���h���C���̃R�}���h�����s���ă��_�C���N�g����֐�
//-----------------------------------------------------------------------------
function TCommandLineUnit.GrabStdOut(CommandLine: string;
  StdIn: TMemoryStream): TMemoryStream;
const
  BUFFER_SIZE = 8192;
var
  hReadPipe          : THandle;
  hWritePipe         : THandle;
  hStdInReadPipe     : THandle;
  hStdInWritePipe    : THandle;
  hStdInWritePipeDup : THandle;
  hErrReadPipe       : THandle;
  hErrWritePipe      : THandle;

  sa            : TSecurityAttributes;
  StartupInfo   : TStartupInfo;
  ProcessInfo   : TProcessInformation;
  bufStdOut     : array[0..BUFFER_SIZE] of Byte;
  bufErrOut     : array[0..BUFFER_SIZE] of Byte;
  bufStdIn      : array[0..BUFFER_SIZE] of Byte;
  dwStdOut      : DWord;
  dwErrOut      : DWord;
  dwRet         : DWord;
  StreamBufferSize : DWord;
  nWritten         : DWord;
begin
  Result := nil;

  with sa do
  begin
    nLength := sizeof(TSecurityAttributes);
    lpSecurityDescriptor := nil;
    bInheritHandle := true;
  end;

  hReadPipe     := 0;
  hWritePipe    := 0;
  hErrReadPipe  := 0;
  hErrWritePipe := 0;

  StdIn.Position := 0;

  CreatePipe(hStdInReadPipe, hStdInWritePipe, @sa, BUFFER_SIZE);
  DuplicateHandle(GetCurrentProcess(), hStdInWritePipe, GetCurrentProcess(),
                  @hStdInWritePipeDup, 0, false, DUPLICATE_SAME_ACCESS);
  CloseHandle(hStdInWritePipe);

  CreatePipe(hReadPipe, hWritePipe, @sa, BUFFER_SIZE);
  try
    CreatePipe(hErrReadPipe, hErrWritePipe, @sa, BUFFER_SIZE);
    try
      ZeroMemory(@StartupInfo, sizeof(TStartupInfo));
      with StartupInfo do
      begin
        cb := sizeof(TStartupInfo);
        dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
        // ���ꂪ�Ȃ��� DOS �����\������Ă��܂�
        wShowWindow := SW_HIDE;
        // �W�� IO �Ƀp�C�v�̒[�������w�肵�Ă��
        hStdInput  := hStdInReadPipe;
        hStdOutput := hWritePipe;
        hStdError  := hErrWritePipe;
      end;

      //�R���\�[���A�v���N��
      //DETACHED_PROCESS��CREATE_NEW_CONSOLE�ɕύX(Mr.XRAY)
      UniqueString(CommandLine);
      if CreateProcess(nil,
                       PChar(CommandLine),
                       @sa,
                       nil,
                       True,
                       CREATE_NEW_CONSOLE,
                       nil,
                       nil,
                       StartupInfo,
                       ProcessInfo) = True then
      begin
        // ���͑҂��ɂȂ�܂ő҂��Ă���C
        WaitForInputIdle(ProcessInfo.hProcess, 1000);
        StreamBufferSize := BUFFER_SIZE;
        while StreamBufferSize = BUFFER_SIZE do
        begin
          // ���͂�^����
          StreamBufferSize := StdIn.Read(bufStdIn, BUFFER_SIZE);
          WriteFile(hStdInWritePipeDup, bufStdIn, StreamBufferSize, nWritten, nil);
        end;
        // ���͂�^���I�����
        CloseHandle(hStdInWritePipeDup);

        Result := TMemoryStream.Create;
        Result.Clear;
        try
          repeat
            if FLoopProcessMessages then
            begin
              Application.ProcessMessages;
              Sleep(50);
            end;

            // �W���o�̓p�C�v�̓��e�𒲂ׂ�
            PeekNamedPipe(hReadPipe, nil, 0, nil, @dwStdOut, nil);
            if (dwStdOut <> 0) then
            begin
              // ���e�����݂���΁A�ǂݎ��
              ReadFile(hReadPipe, bufStdOut, Length(bufStdOut) - 1, dwStdOut, nil);
              Result.Write(bufStdOut, dwStdOut);
            end;

            // ���l�ɃG���[�o�͂̏���
            //GetExitCodeProcess(ProcessInfo.hProcess, dwRet);
            PeekNamedPipe(hErrReadPipe, nil, 0, nil, @dwErrOut, nil);
            if (dwErrOut <> 0) then
            begin
              ReadFile(hErrReadPipe, bufErrOut, Length(bufErrOut)-1,dwErrOut,nil);
              // ���̃f�[�^�͎g��Ȃ��i�o�b�t�@����f�������j
              // ���̃f�[�^���K�v�ł���΁CStdOut �̗�ɂȂ���ăR�[�h��ǉ�����

              //�G���[���e��W���o�͂ɏo��(2010/01/26 Mr.XRAY�ǉ�)
              //Result.Write(bufErrOut, dwStdOut);
            end;

            dwRet := WaitForSingleObject(ProcessInfo.hProcess, 0);
          // �R���\�[���A�v���̃v���Z�X�����݂��Ă����
          until (dwRet = WAIT_OBJECT_0); 
        finally
          CloseHandle(ProcessInfo.hProcess);
          CloseHandle(ProcessInfo.hThread);
          CloseHandle(hStdInReadPipe);
        end;
      end;
    finally
      TerminateProcess(ProcessInfo.hProcess, 0);  //�ǉ�(Mr.XRAY)
      CloseHandle(hErrReadPipe);
      CloseHandle(hErrWritePipe);
    end;
  finally
    CloseHandle(hReadPipe);
    CloseHandle(hWritePipe);
  end;
end;

//-----------------------------------------------------------------------------
constructor TCommandLineUnit.Create;
begin
  FLoopProcessMessages := False;
end;

//-----------------------------------------------------------------------------
//  Unicode(Delphi2009�ȍ~�ɑΉ�
//  �擾���������R�[�h��ύX���Ȃ��悤��RawByteString�Œ�`����������ɓǂ݂�
//  �񂾌�C���ʂ̕�����ɑ������(�Öق̌^�ϊ��̌x������)
//-----------------------------------------------------------------------------
function TCommandLineUnit.GetStringFromStream(const Stream: TStream): String;

//  Delphi6�`Delphi2007-R2�ȉ�
//  Delphi5�ȑO�ɂ�CompilerVersion�Ƃ����w�߂��Ȃ�

{$IF CompilerVersion <= 18.6}
begin
  SetLength(Result, Stream.Size);
  Stream.Position := 0;
  Stream.ReadBuffer(Result[1], Stream.Size);
end;

//  Delphi2009�ȍ~
{$ELSE}
var
  L : Integer;
  S : RawByteString;
begin
  Stream.Read(L, SizeOf(Integer));
  SetLength(S, L);
  Stream.Position := 0;
  Stream.Read(Pointer(S)^, L * SizeOf(Char));

  //��UTF-16�Ȃ̂Ń��X���X�ϊ��Ȃ̂�����ǂ�
  //�P���ɑ������ƃR���p�C�������[�j���O��f���̂ŃL���X�g
  Result := UnicodeString(S);
end;
{$IFEND}

//-----------------------------------------------------------------------------
//  �O�����痘�p������J�֐��@
//  �o�͐悾�������_�C���N�g����ꍇ
//-----------------------------------------------------------------------------
function TCommandLineUnit.GrabStdOutText(CommandLine: string): String;
var
  msin  : TMemoryStream;
  msout : TMemoryStream;
begin
  msin := TMemoryStream.Create;
  try
    msout := GrabStdOut(CommandLine, msin);

    if msout <> nil then
      Result := GetStringFromStream(msout);
  finally
    FreeAndNil(msout);
    FreeAndNil(msin);
  end;
end;

//-----------------------------------------------------------------------------
//  �O�����痘�p������J�֐��@
//  ���͂Əo�͂����_�C���N�g����ꍇ
//-----------------------------------------------------------------------------
function TCommandLineUnit.GrabStdOutText(CommandLine: string;
  StdInput: TStrings): String;
var
  msin  : TMemoryStream;
  msout : TMemoryStream;
begin
  msin := TMemoryStream.Create;
  StdInput.SaveToStream(msin);
  try
    msout := GrabStdOut(CommandLine, msin);

    if msout <> nil then
      Result := GetStringFromStream(msout);
  finally
    FreeAndNil(msout);
    FreeAndNil(msin);
  end;
end;

end.
