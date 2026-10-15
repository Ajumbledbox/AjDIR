; (c) 2013-2026 David Groeling / Ajumbledbox. All rights reserved.
; Project: Ajumbledbox Data Integrity Retention (AjDIR)
; Ownership: AjDIR and the project files created for this project are owned by
; Ajumbledbox / David Groeling unless otherwise stated in a specific file.
; Liability: AjDIR project files, plans, instructions, and future outputs
; are provided "AS IS" without warranty of any kind unless a later project document
; states otherwise.
; Third-party tooling: Third-party tooling, libraries, frameworks, and their outputs
; retain their own ownership, copyright, and licensing. AjDIR does not claim
; ownership over third-party tooling.

#define AjDIRName "Ajumbledbox Data Integrity Retention (AjDIR)"
#define AjDIRVersion "PR 0.01.00"
#define AjDIRFileVersion "0.1.0.0"

[Setup]
AppId=AjDIR.Public.Release
AppName={#AjDIRName}
AppVersion={#AjDIRVersion}
AppPublisher=Ajumbledbox / David Groeling
AppCopyright=(c) 2013-2026 David Groeling / Ajumbledbox. All rights reserved.
DefaultDirName={src}\AjDIR
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
Uninstallable=no
CreateAppDir=yes
OutputDir=.
OutputBaseFilename=AjDIR.Public.Release.PR.0.01.00
SetupIconFile=assets\AjDIR.ico
Compression=lzma2/ultra64
SolidCompression=yes
ArchiveExtraction=full
WizardStyle=modern
SetupArchitecture=x64
ArchitecturesAllowed=x64compatible
UseSetupLdr=x64
CloseApplications=no
RestartApplications=no
VersionInfoCompany=Ajumbledbox / David Groeling
VersionInfoCopyright=(c) 2013-2026 David Groeling / Ajumbledbox. All rights reserved.
VersionInfoDescription=AjDIR Public Release
VersionInfoProductName={#AjDIRName}
VersionInfoProductVersion={#AjDIRFileVersion}
VersionInfoVersion={#AjDIRFileVersion}
VersionInfoTextVersion={#AjDIRVersion}

[Files]
Source: "AjDIR.Dashboard.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "AjDIR.Dashboard.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "AjDIR.Form.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "AjDIR.Readme.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "AjDIR.Viewer.Form.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "application\*"; DestDir: "{app}\application"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "runtime\*"; DestDir: "{app}\runtime"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "components\AjFI\*"; DestDir: "{app}\components\AjFI"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "components\AjFI.2.file\*"; DestDir: "{app}\components\AjFI.2.file"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "components\book\*"; DestDir: "{app}\components\book"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "docs\*"; DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "assets\AjDIR.ico"; DestDir: "{app}\assets"; Flags: ignoreversion
Source: "assets\VeraCrypt.Portable.1.26.29.exe"; DestDir: "{app}\components\VeraCrypt"; Flags: ignoreversion
Source: "assets\AjUST.7z"; Flags: dontcopy noencryption
Source: "assets\npp.8.9.8.1.portable.x64.zip"; Flags: dontcopy noencryption
Source: "assets\SDelete.zip"; Flags: dontcopy noencryption
Source: "assets\SumatraPDF-3.6.1-64.zip"; Flags: dontcopy noencryption

[Code]
procedure ExtractPortableComponents;
begin
  ForceDirectories(ExpandConstant('{app}\components\AjUST'));
  ForceDirectories(ExpandConstant('{app}\components\notepad.plus.plus'));
  ForceDirectories(ExpandConstant('{app}\components\SDelete'));
  ForceDirectories(ExpandConstant('{app}\components\SumatraPDF.portable'));

  ExtractTemporaryFile('AjUST.7z');
  ExtractArchive(
    ExpandConstant('{tmp}\AjUST.7z'),
    ExpandConstant('{app}\components\AjUST'),
    '', True, nil);

  ExtractTemporaryFile('npp.8.9.8.1.portable.x64.zip');
  ExtractArchive(
    ExpandConstant('{tmp}\npp.8.9.8.1.portable.x64.zip'),
    ExpandConstant('{app}\components\notepad.plus.plus'),
    '', True, nil);

  ExtractTemporaryFile('SDelete.zip');
  ExtractArchive(
    ExpandConstant('{tmp}\SDelete.zip'),
    ExpandConstant('{app}\components\SDelete'),
    '', True, nil);

  ExtractTemporaryFile('SumatraPDF-3.6.1-64.zip');
  ExtractArchive(
    ExpandConstant('{tmp}\SumatraPDF-3.6.1-64.zip'),
    ExpandConstant('{app}\components\SumatraPDF.portable'),
    '', True, nil);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
    ExtractPortableComponents;
end;
