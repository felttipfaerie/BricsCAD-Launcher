# BricsCAD Edition Launcher

Run `Install.cmd`. During installation, the operator chooses which shortcuts to
create: individual editions, all five, or none. The Start Menu matches the
Desktop selection:

| Shortcut | BricsCAD startup level | Workspace |
| --- | --- | --- |
| Lite | `lite` | 2D Drafting |
| Pro | `pro` | 2D Drafting |
| BIM | `bim` | BIM |
| Mech | `mechanical` | Mechanical |
| Ult | `ultimate` | Ultimate |

The installer detects `bricscad.exe` inside the standard V26 installation folder.
If BricsCAD is installed elsewhere, run PowerShell from this folder and use:

```powershell
.\Install-BricsCAD-Shortcuts.ps1 -BricscadExe 'D:\Apps\BricsCAD V26\bricscad.exe'
```

For unattended deployment, supply the shortcut selection explicitly:

```powershell
.\Install-BricsCAD-Shortcuts.ps1 -DesktopEditions Lite,BIM,Ult
# or: -DesktopEditions All
```

It installs only to the current user profile; administrator access is not needed.
It does **not** install, alter, activate, or bypass a BricsCAD license. The
`/pr` argument merely requests a run-as level that the existing entitlement
permits. A higher level than the licensed edition will be unavailable.

Each shortcut uses the installed BricsCAD icon plus a large, outlined colored
edition label: Lite (cyan), Pro (purple), BIM (light blue), Mech (orange), and
Ult (green). Re-run `Install.cmd` after an update
to refresh the generated icon files and shortcuts.

To uninstall, double-click `Uninstall.cmd`. It removes only the five shortcuts
created by this launcher plus its generated startup scripts and icons; it does
not remove or modify BricsCAD itself. `Uninstall-BricsCAD-Shortcuts.ps1`
is also available for PowerShell or managed deployments.

## Technical notes

BricsCAD V26 documents `/pr` as the startup switch for `lite`, `pro`, `bim`,
`mechanical`, and `ultimate`. The installer creates a separate BricsCAD user
profile for each shortcut, setting its `WSCURRENT`, `STARTUP`, and `GETSTARTED`
settings before BricsCAD launches. The shortcut therefore uses `/pr` and `/P`
only—no startup script is passed and no new drawing is opened. BricsCAD must
have been launched and closed once before installing, so its initial profile is
available as the template. The default workspace names are those shipped by
BricsCAD V26; if an organization has removed or renamed one, BricsCAD will
report that workspace as unavailable.

Sources: [V26 startup options](https://help.bricsys.com/en-us/document/bricscad/customization/startup-options) and [V26 workspaces](https://helpcenter.bricsys.com/en-us/document/bricscad/customization/workspaces?version=V26).
