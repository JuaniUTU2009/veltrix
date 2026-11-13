# =====================================================================
#  VELTRIX - Optimizador de Windows
#  Uso (PowerShell):   irm <URL de este archivo> | iex
#  Instagram: @veltrix.fps
# =====================================================================

function Invoke-Veltrix {

$URL = 'https://raw.githubusercontent.com/JuaniUTU2009/veltrix/main/veltrix.ps1'
$VER = '3.0'

# ---------- Permisos de administrador ----------
$esAdmin = $false
try {
    $esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch {
    fltmc.exe *> $null
    $esAdmin = ($LASTEXITCODE -eq 0)
}
if (-not $esAdmin) {
    Write-Host ''
    Write-Host '  Pidiendo permisos de administrador... (toca "Si")' -ForegroundColor Yellow
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm '$URL' | iex`"" -ErrorAction Stop
    } catch {
        Write-Host ''
        Write-Host '  No se pudieron pedir los permisos automaticamente.' -ForegroundColor Red
        Write-Host '  Hace clic derecho en Inicio > "Terminal (Administrador)" y pega el comando de nuevo.' -ForegroundColor Yellow
        Write-Host ''
    }
    return
}

# ---------- Ayudantes ----------
function Set-Reg    { param($Path, $Name, $Type, $Data) reg.exe add $Path /v $Name /t $Type /d $Data /f *> $null }
function Remove-Reg { param($Path, $Name) reg.exe delete $Path /v $Name /f *> $null }
function Paso {
    param($t)
    Write-Host ''
    if ($global:VxTotal -gt 0) {
        $global:VxStep++
        Write-Host ("  [{0}/{1}] {2}" -f $global:VxStep, $global:VxTotal, $t) -ForegroundColor Cyan
    } else {
        Write-Host "  > $t" -ForegroundColor Cyan
    }
}
function Listo { param($t) Write-Host "        [OK] $t" -ForegroundColor Green }
function Aviso { param($t) Write-Host "        [!]  $t" -ForegroundColor Yellow }
function Info  { param($t) Write-Host "        $t" -ForegroundColor DarkGray }
function Pausa { Write-Host ''; Read-Host '  Enter para volver al menu' | Out-Null }
function Confirmar { param($t) return ((Read-Host "  $t (S/N)") -match '^[sS]') }
function Libre-GB { $d = Get-PSDrive -Name ($env:SystemDrive -replace ':', '') -ErrorAction SilentlyContinue; if ($d) { return $d.Free / 1GB } else { return 0 } }
function Titulo {
    param($t, $color = 'White')
    Banner
    Write-Host "  $t" -ForegroundColor $color
    Write-Host '  ------------------------------------------------------' -ForegroundColor DarkGray
}

$global:VxStep = 0
$global:VxTotal = 0

$PLAN_VELTRIX = '7e1f5a00-0000-4000-8000-00000000f9a5'
$CDM = 'HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
$CDM_VALS = 'SilentInstalledAppsEnabled', 'SystemPaneSuggestionsEnabled', 'SoftLandingEnabled', 'PreInstalledAppsEnabled', 'OemPreInstalledAppsEnabled', 'RotatingLockScreenOverlayEnabled', 'SubscribedContent-310093Enabled', 'SubscribedContent-338387Enabled', 'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled', 'SubscribedContent-338393Enabled', 'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled', 'SubscribedContent-353698Enabled'
$TAREAS = '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser', '\Microsoft\Windows\Application Experience\ProgramDataUpdater', '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator', '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip', '\Microsoft\Windows\Autochk\Proxy'
$MM = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
$NIC_KEYS = '*EEE', '*InterruptModeration', 'AdvancedEEE', 'EnableGreenEthernet', 'PowerSavingMode', 'GigaLite'
$IFACES = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
$HVCI = 'HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'
$BACKUP_DIR = Join-Path $env:ProgramData 'Veltrix'

function Banner {
    Clear-Host
    Write-Host ''
    Write-Host '   __     __ _____  _     _____  ____   ___ __  __' -ForegroundColor Cyan
    Write-Host '   \ \   / /| ____|| |   |_   _||  _ \ |_ _|\ \/ /' -ForegroundColor Cyan
    Write-Host '    \ \ / / |  _|  | |     | |  | |_) | | |  \  / ' -ForegroundColor DarkCyan
    Write-Host '     \ V /  | |___ | |___  | |  |  _ <  | |  /  \ ' -ForegroundColor DarkCyan
    Write-Host '      \_/   |_____||_____| |_|  |_| \_\|___|/_/\_\' -ForegroundColor Blue
    Write-Host ''
    Write-Host "      Optimizador de Windows  v$VER   |   @veltrix.fps" -ForegroundColor DarkGray
    Write-Host ''
}

# =====================================================================
#  MODULOS DE OPTIMIZACION
# =====================================================================

function M-Restauracion {
    Paso 'Punto de restauracion de seguridad'
    Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' 'SystemRestorePointCreationFrequency' REG_DWORD 0
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
        Checkpoint-Computer -Description 'Veltrix - antes de optimizar' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Listo 'Punto de restauracion creado'
    } catch {
        Aviso 'No se pudo crear (igual se puede revertir desde el menu)'
    }
}

function M-Visual {
    Paso 'Efectos visuales'
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' REG_DWORD 3
    Set-Reg 'HKCU\Control Panel\Desktop' 'UserPreferencesMask' REG_BINARY '9012038010000000'
    Set-Reg 'HKCU\Control Panel\Desktop' 'FontSmoothing' REG_SZ 2
    Set-Reg 'HKCU\Control Panel\Desktop' 'MenuShowDelay' REG_SZ 100
    Set-Reg 'HKCU\Control Panel\Desktop\WindowMetrics' 'MinAnimate' REG_SZ 0
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' REG_DWORD 0
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ListviewShadow' REG_DWORD 0
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' REG_DWORD 0
    Set-Reg 'HKCU\Software\Microsoft\Windows\DWM' 'EnableAeroPeek' REG_DWORD 0
    Listo 'Modo rendimiento (letras nitidas y miniaturas se mantienen)'
}

function M-SegundoPlano {
    Paso 'Publicidad y procesos en segundo plano'
    foreach ($v in $CDM_VALS) { Set-Reg $CDM $v REG_DWORD 0 }
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSyncProviderNotifications' REG_DWORD 0
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_IrisRecommendations' REG_DWORD 0
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' REG_DWORD 0
    Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' REG_DWORD 0
    Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' 'EnableFeeds' REG_DWORD 0
    Set-Reg 'HKCU\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' REG_DWORD 1
    Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled' REG_DWORD 0
    Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled' REG_DWORD 0
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' REG_DWORD 0
    Listo 'Sin anuncios, tips, widgets, Bing en el Inicio ni Edge en segundo plano'
}

function M-Telemetria {
    Paso 'Telemetria y privacidad'
    Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' REG_DWORD 0
    foreach ($s in 'DiagTrack', 'dmwappushservice') {
        sc.exe stop $s *> $null
        sc.exe config $s start= disabled *> $null
    }
    foreach ($t in $TAREAS) { schtasks.exe /Change /TN $t /Disable *> $null }
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' REG_DWORD 0
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' REG_DWORD 0
    Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' REG_DWORD 0
    Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities' REG_DWORD 0
    Set-Reg 'HKCU\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' REG_DWORD 0
    Set-Reg 'HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' REG_DWORD 1
    Set-Reg 'HKCU\Software\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' REG_DWORD 1
    Listo 'Telemetria al minimo, sin Copilot ni capturas de Recall'
}

function M-EnergiaPC {
    Paso 'Energia en maximo rendimiento'
    powercfg.exe -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 $PLAN_VELTRIX *> $null
    powercfg.exe -changename $PLAN_VELTRIX 'Veltrix Rendimiento' *> $null
    powercfg.exe -setactive $PLAN_VELTRIX *> $null
    if ($LASTEXITCODE -ne 0) { powercfg.exe -setactive SCHEME_MIN *> $null }
    powercfg.exe -h off *> $null
    Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' REG_DWORD 1
    Listo 'Plan "Veltrix Rendimiento", sin hibernacion ni limites de CPU'
}

function M-EnergiaLaptop {
    Paso 'Energia inteligente para laptop'
    powercfg.exe -setactive SCHEME_BALANCED *> $null
    $p = '54533251-82be-4824-96c1-47b60b740d00'
    powercfg.exe -setacvalueindex SCHEME_BALANCED $p be337238-0d82-4146-a960-4f3749d470c7 2 *> $null
    powercfg.exe -setacvalueindex SCHEME_BALANCED $p bc5038f7-23e0-4960-96da-33abaf5935ec 100 *> $null
    powercfg.exe -setacvalueindex SCHEME_BALANCED 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0 *> $null
    powercfg.exe -setacvalueindex SCHEME_BALANCED 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 *> $null
    powercfg.exe -setactive SCHEME_BALANCED *> $null
    Listo 'Enchufada: maximo rendimiento. A bateria: ahorro normal'
}

function M-Juegos {
    Paso 'Optimizacion para juegos'
    Set-Reg 'HKCU\Software\Microsoft\GameBar' 'AutoGameModeEnabled' REG_DWORD 1
    Set-Reg 'HKCU\Software\Microsoft\GameBar' 'AllowAutoGameMode' REG_DWORD 1
    Set-Reg 'HKCU\System\GameConfigStore' 'GameDVR_Enabled' REG_DWORD 0
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' REG_DWORD 0
    Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' REG_DWORD 0
    Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' REG_DWORD 2
    Set-Reg $MM 'SystemResponsiveness' REG_DWORD 10
    Set-Reg $MM 'NetworkThrottlingIndex' REG_DWORD 0xffffffff
    Set-Reg "$MM\Tasks\Games" 'GPU Priority' REG_DWORD 8
    Set-Reg "$MM\Tasks\Games" 'Priority' REG_DWORD 6
    Set-Reg "$MM\Tasks\Games" 'Scheduling Category' REG_SZ 'High'
    Set-Reg "$MM\Tasks\Games" 'SFIO Priority' REG_SZ 'High'
    Set-Reg 'HKCU\Control Panel\Mouse' 'MouseSpeed' REG_SZ 0
    Set-Reg 'HKCU\Control Panel\Mouse' 'MouseThreshold1' REG_SZ 0
    Set-Reg 'HKCU\Control Panel\Mouse' 'MouseThreshold2' REG_SZ 0
    # Sin ventanas de "Teclas especiales" al apretar Shift 5 veces en pleno juego
    Set-Reg 'HKCU\Control Panel\Accessibility\StickyKeys' 'Flags' REG_SZ 506
    Set-Reg 'HKCU\Control Panel\Accessibility\ToggleKeys' 'Flags' REG_SZ 58
    Set-Reg 'HKCU\Control Panel\Accessibility\Keyboard Response' 'Flags' REG_SZ 122
    Listo 'Modo juego, sin grabacion Xbox, prioridad a juegos, mouse 1:1'
    Listo 'Sin carteles de Teclas especiales al apretar Shift en juegos'
}

function M-Latencia {
    param([bool]$Laptop)
    Paso 'Latencia y respuesta del sistema'
    Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' REG_DWORD 38
    Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'GlobalTimerResolutionRequests' REG_DWORD 1
    Set-Reg 'HKCU\Software\Microsoft\DirectX\UserGpuPreferences' 'DirectXUserGlobalSettings' REG_SZ 'SwapEffectUpgradeEnable=1;'
    bcdedit.exe /deletevalue useplatformclock *> $null
    bcdedit.exe /deletevalue useplatformtick *> $null
    if (-not $Laptop) {
        powercfg.exe -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 100 *> $null
        powercfg.exe -setactive SCHEME_CURRENT *> $null
    }
    Listo 'Prioridad a la ventana activa, timers precisos, menos input lag'
}

function M-Red {
    param([bool]$Laptop)
    Paso 'Red para juegos online'
    Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' REG_DWORD 0
    Get-ChildItem $IFACES -ErrorAction SilentlyContinue | ForEach-Object {
        New-ItemProperty -Path $_.PSPath -Name 'TcpAckFrequency' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
        New-ItemProperty -Path $_.PSPath -Name 'TCPNoDelay' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
    }
    netsh.exe int tcp set global autotuninglevel=normal *> $null
    netsh.exe int tcp set global rss=enabled *> $null
    if (-not $Laptop) {
        foreach ($n in (Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up')) {
            Disable-NetAdapterPowerManagement -Name $n.Name -NoRestart -ErrorAction SilentlyContinue | Out-Null
            foreach ($k in $NIC_KEYS) {
                Set-NetAdapterAdvancedProperty -Name $n.Name -RegistryKeyword $k -RegistryValue 0 -NoRestart -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }
    Listo 'Nagle desactivado, sin subidas ocultas de Windows Update, TCP sano'
}

function M-Avanzado {
    Paso 'Disco, memoria y servicios'
    fsutil.exe behavior set disablelastaccess 1 *> $null
    fsutil.exe behavior set disable8dot3 1 *> $null
    fsutil.exe behavior set DisableDeleteNotify 0 *> $null
    foreach ($s in 'Fax', 'RetailDemo') {
        sc.exe stop $s *> $null
        sc.exe config $s start= disabled *> $null
    }
    sc.exe config MapsBroker start= demand *> $null
    $ram = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    if ($ram -ge 31) {
        Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
        Listo ("RAM {0:N0} GB: compresion de memoria desactivada (ahorra CPU)" -f $ram)
    } else {
        Listo ("RAM {0:N0} GB: compresion de memoria se mantiene (recomendado)" -f $ram)
    }
    Listo 'NTFS sin escrituras extra, TRIM asegurado, servicios inutiles apagados'
}

function M-Limpieza {
    Paso 'Limpieza de archivos basura'
    Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Stop-Service wuauserv, bits -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service bits, wuauserv -ErrorAction SilentlyContinue
    ipconfig.exe /flushdns *> $null
    Info 'Limpiando componentes viejos de Windows (5 a 15 min, es normal)...'
    Dism.exe /Online /Cleanup-Image /StartComponentCleanup /Quiet *> $null
    Listo 'Temporales, cache de Windows Update y componentes viejos limpios'
}

function M-Diagnostico {
    param([string]$Etiqueta = 'DIAGNOSTICO', [bool]$Abrir = $true)
    Paso "Informe $Etiqueta del equipo"
    $desk = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders' -ErrorAction SilentlyContinue).Desktop
    if (-not $desk) { $desk = Join-Path $env:USERPROFILE 'Desktop' }
    $file = Join-Path $desk ("Veltrix_" + $Etiqueta + "_" + (Get-Date -Format 'yyyy-MM-dd_HH-mm') + ".txt")

    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $gpus = Get-CimInstance Win32_VideoController
    $ramT = $cs.TotalPhysicalMemory / 1GB
    $ramL = $os.FreePhysicalMemory / 1MB
    $ramU = $ramT - $ramL
    $up = (Get-Date) - $os.LastBootUpTime
    $procs = @(Get-Process).Count
    $servs = @(Get-Service | Where-Object Status -eq 'Running').Count
    $tempB = (Get-ChildItem $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    $plan = (powercfg.exe /getactivescheme) -replace '^.*\(', '' -replace '\)\s*$', ''
    $dg = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
    $hvci = if ($dg -and ($dg.SecurityServicesRunning -contains 2)) { 'ACTIVA' } else { 'desactivada' }
    $inicio = @(Get-Inicio | Where-Object Activo)
    $discos = @(Get-PhysicalDisk -ErrorAction SilentlyContinue)
    $dns = (Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddresses } | Select-Object -First 1).ServerAddresses -join ', '

    $L = @()
    $L += '=================================================='
    $L += "   VELTRIX - INFORME $Etiqueta"
    $L += "   $(Get-Date -Format 'dd/MM/yyyy HH:mm')   Equipo: $env:COMPUTERNAME"
    $L += '=================================================='
    $L += ''
    $L += "Windows ........ $($os.Caption) (build $($os.BuildNumber))"
    $L += "Procesador ..... $($cpu.Name)"
    foreach ($g in $gpus) {
        $f = if ($g.DriverDate) { Get-Date $g.DriverDate -Format 'dd/MM/yyyy' } else { '?' }
        $L += "Placa de video . $($g.Name)  (driver $($g.DriverVersion), del $f)"
    }
    $L += ("RAM ............ {0:N1} GB total, {1:N1} GB en uso ({2:N0}%)" -f $ramT, $ramU, (($ramU / $ramT) * 100))
    $L += ''
    $L += '--- DISCOS ---'
    foreach ($d in $discos) { $L += ("  {0}  |  {1}  |  {2:N0} GB" -f $d.FriendlyName, $d.MediaType, ($d.Size / 1GB)) }
    foreach ($v in (Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -and $_.Size -gt 0 })) {
        $pct = ($v.SizeRemaining / $v.Size) * 100
        $av = if ($pct -lt 15) { '  <-- POCO ESPACIO' } else { '' }
        $L += ("  Unidad {0}:  {1:N1} GB libres de {2:N0} GB ({3:N0}%){4}" -f $v.DriveLetter, ($v.SizeRemaining / 1GB), ($v.Size / 1GB), $pct, $av)
    }
    $L += ''
    $L += '--- CARGA DEL SISTEMA ---'
    $L += "Procesos abiertos ........ $procs"
    $L += "Servicios corriendo ...... $servs"
    $L += ("Archivos temporales ...... {0:N0} MB" -f ($tempB / 1MB))
    $L += "Plan de energia .......... $plan"
    $L += "Servidores DNS ........... $dns"
    $L += "Integridad de memoria .... $hvci"
    $L += "Encendido hace ........... $($up.Days) dias, $($up.Hours) horas"
    $L += ''
    $L += "--- PROGRAMAS ACTIVOS AL INICIO ($($inicio.Count)) ---"
    foreach ($s in $inicio) { $L += "  - $($s.Nombre)" }
    $L += ''
    $L += '--- RECOMENDACIONES ---'
    if ($ramT -lt 7.5) { $L += '  * Menos de 8 GB de RAM: ampliar memoria es la mejora mas grande posible.' }
    if (($discos | Where-Object MediaType -eq 'HDD') -and -not ($discos | Where-Object MediaType -eq 'SSD')) { $L += '  * Windows en disco mecanico (HDD): pasar a SSD cambia la PC por completo.' }
    if ($up.Days -ge 7) { $L += '  * Hace mas de una semana que no se reinicia: reiniciar seguido ayuda.' }
    if ($inicio.Count -gt 8) { $L += '  * Muchos programas al inicio: usar la opcion "Programas de inicio" de Veltrix.' }
    foreach ($g in $gpus) { if ($g.DriverDate -and (((Get-Date) - $g.DriverDate).Days -gt 180)) { $L += "  * Driver de $($g.Name) con mas de 6 meses: actualizarlo." } }
    $L += ''
    $L += 'Veltrix - Instagram @veltrix.fps'

    $L | Out-File -FilePath $file -Encoding UTF8
    Listo "Informe guardado en el Escritorio: Veltrix_$Etiqueta"
    if ($Abrir) { Start-Process notepad.exe $file }
}

# =====================================================================
#  HERRAMIENTAS
# =====================================================================

# ---------- Limpieza profunda ----------
function T-LimpiezaProfunda {
    Titulo 'LIMPIEZA PROFUNDA' 'Cyan'
    Write-Host '  Borra solo basura: temporales, caches y reportes de error.'
    Write-Host '  NO toca archivos personales, contrasenas ni sesiones abiertas.'
    Write-Host ''
    if (-not (Confirmar 'Empezar?')) { return }
    $antes = Libre-GB

    Paso 'Temporales de Windows y del usuario'
    Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\Prefetch\*.tmp" -Force -ErrorAction SilentlyContinue
    Listo 'Listo'

    Paso 'Cache de Windows Update y de Optimizacion de distribucion'
    Stop-Service wuauserv, bits -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service bits, wuauserv -ErrorAction SilentlyContinue
    Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue
    Listo 'Listo'

    Paso 'Reportes de errores y logs viejos'
    Remove-Item "$env:ProgramData\Microsoft\Windows\WER\ReportArchive\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:ProgramData\Microsoft\Windows\WER\ReportQueue\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:LOCALAPPDATA\CrashDumps\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\Minidump\*" -Force -ErrorAction SilentlyContinue
    Listo 'Listo'

    Paso 'Cache de navegadores y Discord (solo cache, no sesiones)'
    $apps = @(
        @{ N = 'Chrome';  P = 'chrome';  D = "$env:LOCALAPPDATA\Google\Chrome\User Data" },
        @{ N = 'Edge';    P = 'msedge';  D = "$env:LOCALAPPDATA\Microsoft\Edge\User Data" },
        @{ N = 'Brave';   P = 'brave';   D = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data" },
        @{ N = 'Opera';   P = 'opera';   D = "$env:LOCALAPPDATA\Opera Software" },
        @{ N = 'Firefox'; P = 'firefox'; D = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles" },
        @{ N = 'Discord'; P = 'Discord'; D = "$env:APPDATA\discord" }
    )
    foreach ($a in $apps) {
        if (-not (Test-Path $a.D)) { continue }
        if (Get-Process -Name $a.P -ErrorAction SilentlyContinue) { Aviso "$($a.N) esta abierto: se saltea (cerralo y volve a correr la limpieza)"; continue }
        foreach ($sub in 'Cache', 'Code Cache', 'GPUCache', 'cache2', 'Service Worker\CacheStorage') {
            Get-ChildItem $a.D -Directory -Recurse -Depth 3 -Filter ($sub -replace '^.*\\', '') -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -like "*\$sub" } |
                ForEach-Object { Remove-Item "$($_.FullName)\*" -Recurse -Force -ErrorAction SilentlyContinue }
        }
        Listo "$($a.N) limpio"
    }

    Write-Host ''
    if (Confirmar 'Vaciar tambien la Papelera de reciclaje?') {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        Listo 'Papelera vaciada'
    }

    $despues = Libre-GB
    $lib = $despues - $antes
    if ($lib -lt 0) { $lib = 0 }
    Write-Host ''
    Write-Host '  ======================================================' -ForegroundColor DarkCyan
    Write-Host ("    LIBERASTE {0:N2} GB  (ahora tenes {1:N1} GB libres)" -f $lib, $despues) -ForegroundColor Green
    Write-Host '  ======================================================' -ForegroundColor DarkCyan
    Pausa
}

# ---------- Programas de inicio ----------
function Get-Inicio {
    $fuentes = @(
        @{ Run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Ap = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Quien = 'usuario' },
        @{ Run = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Ap = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Quien = 'todos' },
        @{ Run = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Ap = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32'; Quien = 'todos' }
    )
    $lista = @()
    foreach ($f in $fuentes) {
        $props = Get-ItemProperty $f.Run -ErrorAction SilentlyContinue
        if (-not $props) { continue }
        $apr = Get-ItemProperty ('Registry::' + $f.Ap) -ErrorAction SilentlyContinue
        foreach ($p in $props.PSObject.Properties) {
            if ($p.Name -like 'PS*') { continue }
            $activo = $true
            if ($apr -and $apr.($p.Name)) { $activo = (($apr.($p.Name)[0] % 2) -eq 0) }
            $lista += [pscustomobject]@{ Nombre = $p.Name; Ap = $f.Ap; Quien = $f.Quien; Activo = $activo }
        }
    }
    $carpetas = @(
        @{ D = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"; Ap = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'; Quien = 'usuario' },
        @{ D = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"; Ap = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'; Quien = 'todos' }
    )
    foreach ($c in $carpetas) {
        $apr = Get-ItemProperty ('Registry::' + $c.Ap) -ErrorAction SilentlyContinue
        foreach ($f in (Get-ChildItem $c.D -File -ErrorAction SilentlyContinue | Where-Object Name -ne 'desktop.ini')) {
            $activo = $true
            if ($apr -and $apr.($f.Name)) { $activo = (($apr.($f.Name)[0] % 2) -eq 0) }
            $lista += [pscustomobject]@{ Nombre = $f.Name; Ap = $c.Ap; Quien = $c.Quien; Activo = $activo }
        }
    }
    return $lista
}

function T-Inicio {
    while ($true) {
        Titulo 'PROGRAMAS QUE ARRANCAN CON WINDOWS' 'Cyan'
        Write-Host '  Desactivar programas de inicio hace que Windows arranque mas rapido'
        Write-Host '  y deje mas RAM libre. Es lo mismo que el Administrador de tareas, y'
        Write-Host '  se puede volver a activar cuando quieras.'
        Write-Host ''
        $lista = @(Get-Inicio)
        if ($lista.Count -eq 0) { Info 'No hay programas de inicio.'; Pausa; return }
        for ($i = 0; $i -lt $lista.Count; $i++) {
            $e = $lista[$i]
            if ($e.Activo) { Write-Host ("   [{0,2}]  ACTIVO      {1}" -f ($i + 1), $e.Nombre) -ForegroundColor White }
            else { Write-Host ("   [{0,2}]  desactivado {1}" -f ($i + 1), $e.Nombre) -ForegroundColor DarkGray }
        }
        Write-Host ''
        Info 'Recomendado desactivar: launchers de juegos, Spotify, Teams, OneDrive (si no lo usas),'
        Info 'actualizadores. NO desactivar: drivers de audio/video, antivirus, touchpad.'
        Write-Host ''
        $in = Read-Host '  Numeros para activar/desactivar (ej: 1,3,5) o Enter para volver'
        if (-not $in) { return }
        foreach ($n in ($in -split '[,\s]+' | Where-Object { $_ -match '^\d+$' })) {
            $idx = [int]$n - 1
            if ($idx -lt 0 -or $idx -ge $lista.Count) { continue }
            $e = $lista[$idx]
            $val = if ($e.Activo) { '030000000000000000000000' } else { '020000000000000000000000' }
            Set-Reg $e.Ap $e.Nombre REG_BINARY $val
        }
    }
}

# ---------- Apps basura ----------
function T-Bloat {
    Titulo 'QUITAR APPS BASURA PREINSTALADAS' 'Cyan'
    $patrones = 'Microsoft.BingNews', 'Microsoft.BingSearch', 'Microsoft.GetHelp', 'Microsoft.Getstarted', 'Microsoft.MicrosoftSolitaireCollection',
        'Microsoft.People', 'Microsoft.WindowsFeedbackHub', 'Microsoft.MicrosoftOfficeHub', 'Microsoft.SkypeApp', 'Microsoft.Todos',
        'Clipchamp.Clipchamp', 'Microsoft.549981C3F5F10', 'Microsoft.WindowsMaps', 'Microsoft.MixedReality.Portal', 'Microsoft.3DBuilder',
        'Microsoft.Microsoft3DViewer', 'Microsoft.Print3D', 'Microsoft.OneConnect', 'Microsoft.Messaging', 'Microsoft.ZuneVideo',
        'Microsoft.PowerAutomateDesktop', 'MicrosoftTeams', 'Microsoft.MicrosoftJournal', '*CandyCrush*', '*king.com*', '*Disney*',
        '*TikTok*', '*Facebook*', '*AmazonPrime*', '*BubbleWitch*', '*MarchofEmpires*', '*HiddenCity*', '*Dolby*Access*'
    $encontradas = @()
    foreach ($p in $patrones) { $encontradas += @(Get-AppxPackage -Name $p -ErrorAction SilentlyContinue) }
    $encontradas = @($encontradas | Sort-Object Name -Unique)
    if ($encontradas.Count -eq 0) { Listo 'Este equipo no tiene apps basura conocidas.'; Pausa; return }
    Write-Host "  Se encontraron $($encontradas.Count) apps que casi nadie usa:" -ForegroundColor White
    Write-Host ''
    foreach ($a in $encontradas) { Write-Host "   - $($a.Name)" }
    Write-Host ''
    Info 'No se tocan: Microsoft Store, Xbox, Calculadora, Fotos, Camara, Notas, Enlace Movil.'
    Info 'Cualquier app se puede volver a instalar gratis desde Microsoft Store.'
    Write-Host ''
    if (-not (Confirmar 'Quitar todas estas apps?')) { return }
    foreach ($a in $encontradas) {
        Remove-AppxPackage -Package $a.PackageFullName -ErrorAction SilentlyContinue
        if ($?) { Listo $a.Name } else { Aviso "$($a.Name) (no se pudo quitar)" }
    }
    Pausa
}

# ---------- DNS mas rapido ----------
function T-DNS {
    Titulo 'DNS MAS RAPIDO (TEST AUTOMATICO)' 'Cyan'
    Write-Host '  El DNS traduce nombres de paginas a direcciones. Uno rapido hace que'
    Write-Host '  las paginas, launchers y descargas arranquen antes.'
    Write-Host ''
    $actual = (Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddresses } | Select-Object -First 1).ServerAddresses
    $cands = @(
        @{ N = 'Actual (tu proveedor)'; A = @($actual) },
        @{ N = 'Cloudflare'; A = @('1.1.1.1', '1.0.0.1') },
        @{ N = 'Google'; A = @('8.8.8.8', '8.8.4.4') },
        @{ N = 'Quad9'; A = @('9.9.9.9', '149.112.112.112') }
    )
    $dominios = 'google.com', 'youtube.com', 'riotgames.com', 'steampowered.com', 'epicgames.com', 'discord.com', 'instagram.com', 'microsoft.com'
    Info 'Probando cada DNS con 8 sitios... (unos segundos)'
    Write-Host ''
    $res = @()
    foreach ($c in $cands) {
        if (-not $c.A -or -not $c.A[0]) { continue }
        $tot = 0; $ok = 0
        foreach ($d in $dominios) {
            $t1 = Get-Date
            $r = Resolve-DnsName $d -Server $c.A[0] -DnsOnly -NoHostsFile -QuickTimeout -ErrorAction SilentlyContinue
            $ms = ((Get-Date) - $t1).TotalMilliseconds
            if ($r) { $tot += $ms; $ok++ }
        }
        if ($ok -gt 0) {
            $prom = $tot / $ok
            $res += [pscustomobject]@{ N = $c.N; A = $c.A; Ms = $prom }
            Write-Host ("   {0,-24} {1,6:N0} ms" -f $c.N, $prom)
        } else {
            Write-Host ("   {0,-24}  sin respuesta" -f $c.N) -ForegroundColor DarkGray
        }
    }
    if ($res.Count -eq 0) { Aviso 'No se pudo probar (sin internet?)'; Pausa; return }
    $mejor = $res | Sort-Object Ms | Select-Object -First 1
    Write-Host ''
    if ($mejor.N -like 'Actual*') {
        Listo 'Tu DNS actual ya es el mas rapido. No hace falta cambiar nada.'
        Pausa; return
    }
    Write-Host ("  El mas rapido es {0} ({1:N0} ms)." -f $mejor.N, $mejor.Ms) -ForegroundColor Green
    if (-not (Confirmar "Usar $($mejor.N)?")) { return }
    foreach ($n in (Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up')) {
        Set-DnsClientServerAddress -InterfaceIndex $n.ifIndex -ServerAddresses $mejor.A -ErrorAction SilentlyContinue
    }
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Listo "DNS cambiado a $($mejor.N). Se puede volver al original con 'Revertir'."
    Pausa
}

# ---------- Game Booster ----------
function T-Booster {
    $sistema = 'System', 'Idle', 'Registry', 'Memory Compression', 'smss', 'csrss', 'wininit', 'winlogon', 'services', 'lsass', 'svchost',
        'dwm', 'explorer', 'fontdrvhost', 'sihost', 'ctfmon', 'conhost', 'OpenConsole', 'WindowsTerminal', 'powershell', 'pwsh', 'audiodg',
        'MsMpEng', 'NisSrv', 'SecurityHealthService', 'SecurityHealthSystray', 'StartMenuExperienceHost', 'ShellExperienceHost', 'SearchHost',
        'TextInputHost', 'RuntimeBroker', 'dllhost', 'taskhostw', 'spoolsv', 'WmiPrvSE', 'LsaIso', 'NVDisplay.Container', 'atiesrxx', 'atieclxx',
        'RtkAudUService64', 'igfxEM', 'vgc', 'vgtray', 'Claude', 'MpDefenderCoreService', 'SgrmBroker', 'WUDFHost', 'dasHost', 'unsecapp'
    while ($true) {
        Titulo 'GAME BOOSTER - LIBERAR RAM ANTES DE JUGAR' 'Cyan'
        $grupos = Get-Process -ErrorAction SilentlyContinue | Where-Object { $sistema -notcontains $_.ProcessName } |
            Group-Object ProcessName | ForEach-Object {
                [pscustomobject]@{ Nombre = $_.Name; MB = (($_.Group | Measure-Object WorkingSet64 -Sum).Sum / 1MB); Cant = $_.Count }
            } | Sort-Object MB -Descending | Select-Object -First 15
        $grupos = @($grupos)
        $os = Get-CimInstance Win32_OperatingSystem
        Write-Host ("  RAM libre ahora: {0:N1} GB de {1:N1} GB" -f ($os.FreePhysicalMemory / 1MB), ($os.TotalVisibleMemorySize / 1MB)) -ForegroundColor Green
        Write-Host ''
        Write-Host '  Programas que mas memoria estan usando:'
        Write-Host ''
        for ($i = 0; $i -lt $grupos.Count; $i++) {
            $g = $grupos[$i]
            Write-Host ("   [{0,2}]  {1,-28} {2,7:N0} MB  ({3} proc.)" -f ($i + 1), $g.Nombre, $g.MB, $g.Cant)
        }
        Write-Host ''
        Aviso 'Guarda lo que estes haciendo: los programas que cierres se cierran sin preguntar.'
        Write-Host ''
        $in = Read-Host '  Numeros a cerrar (ej: 1,2,4) o Enter para volver'
        if (-not $in) { return }
        foreach ($n in ($in -split '[,\s]+' | Where-Object { $_ -match '^\d+$' })) {
            $idx = [int]$n - 1
            if ($idx -lt 0 -or $idx -ge $grupos.Count) { continue }
            Stop-Process -Name $grupos[$idx].Nombre -Force -ErrorAction SilentlyContinue
            Listo ("Cerrado {0} ({1:N0} MB liberados)" -f $grupos[$idx].Nombre, $grupos[$idx].MB)
        }
        Start-Sleep -Seconds 2
    }
}

# ---------- Actualizar programas ----------
function T-Actualizar {
    Titulo 'ACTUALIZAR TODOS LOS PROGRAMAS' 'Cyan'
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Aviso 'Este Windows no tiene "winget". Instala "Instalador de aplicacion" desde Microsoft Store.'
        Pausa; return
    }
    Info 'Buscando actualizaciones...'
    Write-Host ''
    winget.exe upgrade --accept-source-agreements
    Write-Host ''
    Info 'Los programas abiertos que se actualicen se pueden cerrar solos.'
    if (-not (Confirmar 'Actualizar todo lo de la lista?')) { return }
    winget.exe upgrade --all --silent --accept-source-agreements --accept-package-agreements --disable-interactivity
    Listo 'Actualizacion terminada'
    Pausa
}

# ---------- Reparar Windows ----------
function T-Reparar {
    Titulo 'REPARAR WINDOWS (DISM + SFC)' 'Cyan'
    Write-Host '  Revisa y repara archivos danados de Windows. Sirve para errores raros,'
    Write-Host '  pantallazos azules, menus que no abren o Windows Update trabado.'
    Write-Host ''
    Info 'Tarda entre 10 y 30 minutos. No apagues la PC mientras corre.'
    Write-Host ''
    if (-not (Confirmar 'Empezar reparacion?')) { return }
    Paso 'Reparando la imagen de Windows (DISM)...'
    Dism.exe /Online /Cleanup-Image /RestoreHealth
    Paso 'Revisando archivos del sistema (SFC)...'
    sfc.exe /scannow
    Write-Host ''
    Listo 'Reparacion terminada. Reinicia la PC para completar.'
    Pausa
}

# =====================================================================
#  EXTRAS
# =====================================================================

function M-Competitivo {
    Titulo 'MODO COMPETITIVO (EXTRA)' 'Magenta'
    Write-Host '  Desactiva la "Integridad de memoria" (HVCI) de Windows.'
    Write-Host '  En muchas PCs da entre 5% y 10% mas de FPS.'
    Write-Host ''
    Write-Host '  IMPORTANTE: es una capa de seguridad extra contra malware avanzado.' -ForegroundColor Yellow
    Write-Host '  Windows Defender sigue funcionando igual. Recomendado solo para PCs de juego.' -ForegroundColor Yellow
    if ((Test-Path "$env:ProgramFiles\Riot Vanguard") -or (Get-Service vgc -ErrorAction SilentlyContinue)) {
        Write-Host ''
        Write-Host '  ATENCION: esta PC tiene VALORANT (Vanguard). Vanguard puede exigir que' -ForegroundColor Red
        Write-Host '  esta proteccion este activada. Si VALORANT no abre, usa "Revertir".' -ForegroundColor Red
    }
    Write-Host ''
    if (-not (Confirmar 'Aplicar?')) { return }
    New-Item -ItemType Directory -Path $BACKUP_DIR -Force -ErrorAction SilentlyContinue | Out-Null
    $bk = Join-Path $BACKUP_DIR 'hvci_backup.reg'
    if (-not (Test-Path $bk)) { reg.exe export 'HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard' $bk /y *> $null }
    Set-Reg $HVCI 'Enabled' REG_DWORD 0
    Listo 'Modo competitivo aplicado'
    Reiniciar
}

function M-Revertir {
    Titulo 'REVERTIR TODOS LOS CAMBIOS' 'Yellow'
    Write-Host '  Deja Windows como estaba de fabrica en todo lo que toco Veltrix.'
    Info '(Las apps basura quitadas se reinstalan desde Microsoft Store, y los'
    Info ' programas de inicio se reactivan desde la opcion "Programas de inicio".)'
    Write-Host ''
    if (-not (Confirmar 'Continuar?')) { return }

    Paso 'Efectos visuales'
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' REG_DWORD 0
    Set-Reg 'HKCU\Control Panel\Desktop' 'UserPreferencesMask' REG_BINARY '9E1E078012000000'
    Set-Reg 'HKCU\Control Panel\Desktop' 'MenuShowDelay' REG_SZ 400
    Set-Reg 'HKCU\Control Panel\Desktop\WindowMetrics' 'MinAnimate' REG_SZ 1
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' REG_DWORD 1
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ListviewShadow' REG_DWORD 1
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' REG_DWORD 1
    Set-Reg 'HKCU\Software\Microsoft\Windows\DWM' 'EnableAeroPeek' REG_DWORD 1

    Paso 'Segundo plano y sugerencias'
    foreach ($v in $CDM_VALS) { Set-Reg $CDM $v REG_DWORD 1 }
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSyncProviderNotifications' REG_DWORD 1
    Remove-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_IrisRecommendations'
    Remove-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled'
    Remove-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests'
    Remove-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' 'EnableFeeds'
    Remove-Reg 'HKCU\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions'
    Remove-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled'
    Remove-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled'
    Remove-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec'

    Paso 'Telemetria y privacidad'
    Remove-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry'
    sc.exe config DiagTrack start= auto *> $null
    sc.exe start DiagTrack *> $null
    sc.exe config dmwappushservice start= demand *> $null
    foreach ($t in $TAREAS) { schtasks.exe /Change /TN $t /Enable *> $null }
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' REG_DWORD 1
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' REG_DWORD 1
    Remove-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities'
    Remove-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities'
    Remove-Reg 'HKCU\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod'
    Remove-Reg 'HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot'
    Remove-Reg 'HKCU\Software\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis'

    Paso 'Energia'
    powercfg.exe -setactive SCHEME_BALANCED *> $null
    powercfg.exe -delete $PLAN_VELTRIX *> $null
    powercfg.exe -restoredefaultschemes *> $null
    powercfg.exe -h on *> $null
    Remove-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff'

    Paso 'Juegos, latencia, mouse y teclado'
    Remove-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled'
    Set-Reg 'HKCU\System\GameConfigStore' 'GameDVR_Enabled' REG_DWORD 1
    Remove-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR'
    Remove-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode'
    Set-Reg $MM 'SystemResponsiveness' REG_DWORD 20
    Set-Reg $MM 'NetworkThrottlingIndex' REG_DWORD 10
    Set-Reg "$MM\Tasks\Games" 'GPU Priority' REG_DWORD 8
    Set-Reg "$MM\Tasks\Games" 'Priority' REG_DWORD 2
    Set-Reg "$MM\Tasks\Games" 'Scheduling Category' REG_SZ 'Medium'
    Set-Reg "$MM\Tasks\Games" 'SFIO Priority' REG_SZ 'Normal'
    Set-Reg 'HKCU\Control Panel\Mouse' 'MouseSpeed' REG_SZ 1
    Set-Reg 'HKCU\Control Panel\Mouse' 'MouseThreshold1' REG_SZ 6
    Set-Reg 'HKCU\Control Panel\Mouse' 'MouseThreshold2' REG_SZ 10
    Set-Reg 'HKCU\Control Panel\Accessibility\StickyKeys' 'Flags' REG_SZ 510
    Set-Reg 'HKCU\Control Panel\Accessibility\ToggleKeys' 'Flags' REG_SZ 62
    Set-Reg 'HKCU\Control Panel\Accessibility\Keyboard Response' 'Flags' REG_SZ 126
    Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' REG_DWORD 2
    Remove-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'GlobalTimerResolutionRequests'
    Remove-Reg 'HKCU\Software\Microsoft\DirectX\UserGpuPreferences' 'DirectXUserGlobalSettings'

    Paso 'Red y DNS'
    Remove-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode'
    Get-ChildItem $IFACES -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-ItemProperty -Path $_.PSPath -Name 'TcpAckFrequency' -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $_.PSPath -Name 'TCPNoDelay' -Force -ErrorAction SilentlyContinue
    }
    foreach ($n in (Get-NetAdapter -Physical -ErrorAction SilentlyContinue)) {
        Enable-NetAdapterPowerManagement -Name $n.Name -NoRestart -ErrorAction SilentlyContinue | Out-Null
        foreach ($k in $NIC_KEYS) { Reset-NetAdapterAdvancedProperty -Name $n.Name -RegistryKeyword $k -NoRestart -ErrorAction SilentlyContinue | Out-Null }
        Set-DnsClientServerAddress -InterfaceIndex $n.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue
    }

    Paso 'Disco, memoria y servicios'
    fsutil.exe behavior set disablelastaccess 2 *> $null
    fsutil.exe behavior set disable8dot3 2 *> $null
    sc.exe config Fax start= demand *> $null
    sc.exe config RetailDemo start= demand *> $null
    sc.exe config MapsBroker start= delayed-auto *> $null
    Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue

    $bk = Join-Path $BACKUP_DIR 'hvci_backup.reg'
    if (Test-Path $bk) {
        Paso 'Integridad de memoria'
        Remove-Reg $HVCI 'Enabled'
        reg.exe import $bk *> $null
        Remove-Item $bk -Force -ErrorAction SilentlyContinue
    }

    Write-Host ''
    Listo 'Todo revertido'
    Reiniciar
}

function Reiniciar {
    Write-Host ''
    Write-Host '  ======================================================' -ForegroundColor DarkCyan
    Write-Host '    LISTO. Hay que reiniciar para aplicar los cambios.' -ForegroundColor Green
    Write-Host '  ======================================================' -ForegroundColor DarkCyan
    Write-Host ''
    if (Confirmar 'Reiniciar ahora?') {
        shutdown.exe /r /t 5 /c "Veltrix: reiniciando para aplicar los cambios"
        exit
    }
}

function Optimizar {
    param([bool]$Laptop)
    $tipo = if ($Laptop) { 'LAPTOP' } else { 'PC DE ESCRITORIO' }
    Titulo "OPTIMIZACION COMPLETA - $tipo" 'Green'
    Write-Host '   - Punto de restauracion + informe ANTES en el Escritorio'
    Write-Host '   - Efectos visuales, publicidad y procesos en segundo plano'
    Write-Host '   - Telemetria y privacidad'
    Write-Host '   - Energia, juegos y latencia'
    Write-Host '   - Red, disco, memoria y servicios'
    Write-Host '   - Limpieza de archivos basura'
    Write-Host ''
    if ($Laptop) { Aviso 'Conecta el cargador y cerra los programas abiertos.' }
    else { Aviso 'Cerra los programas abiertos.' }
    Write-Host ''
    if (-not (Confirmar 'Empezar?')) { return }

    $t0 = Get-Date
    $libre0 = Libre-GB
    $global:VxStep = 0
    $global:VxTotal = 11

    M-Diagnostico -Etiqueta 'ANTES' -Abrir $false
    M-Restauracion
    M-Visual
    M-SegundoPlano
    M-Telemetria
    if ($Laptop) { M-EnergiaLaptop } else { M-EnergiaPC }
    M-Juegos
    M-Latencia -Laptop $Laptop
    M-Red -Laptop $Laptop
    M-Avanzado
    M-Limpieza

    $global:VxTotal = 0
    $dur = (Get-Date) - $t0
    $lib = (Libre-GB) - $libre0
    if ($lib -lt 0) { $lib = 0 }

    Write-Host ''
    Write-Host '  ======================================================' -ForegroundColor DarkCyan
    Write-Host '    OPTIMIZACION COMPLETA' -ForegroundColor Green
    Write-Host ("    Tiempo: {0} min {1} s   |   Espacio liberado: {2:N2} GB" -f ($dur.Hours * 60 + $dur.Minutes), $dur.Seconds, $lib) -ForegroundColor Green
    Write-Host '  ======================================================' -ForegroundColor DarkCyan
    Write-Host ''
    Info 'Para ir mas alla, en el menu tenes: Programas de inicio, Apps basura,'
    Info 'DNS mas rapido y Game Booster.'
    Info 'Despues de reiniciar, usa "Diagnostico" para comparar con el informe ANTES.'
    Reiniciar
}

# =====================================================================
#  MENU
# =====================================================================
while ($true) {
    Banner
    Write-Host '   OPTIMIZACION' -ForegroundColor DarkCyan
    Write-Host '    [1]  Optimizar PC de escritorio' -ForegroundColor White
    Write-Host '    [2]  Optimizar Laptop / Notebook' -ForegroundColor White
    Write-Host ''
    Write-Host '   HERRAMIENTAS' -ForegroundColor DarkCyan
    Write-Host '    [3]  Diagnostico del equipo (antes / despues)' -ForegroundColor White
    Write-Host '    [4]  Limpieza profunda (te dice cuantos GB liberaste)' -ForegroundColor White
    Write-Host '    [5]  Programas que arrancan con Windows' -ForegroundColor White
    Write-Host '    [6]  Quitar apps basura preinstaladas' -ForegroundColor White
    Write-Host '    [7]  DNS mas rapido (test automatico)' -ForegroundColor White
    Write-Host '    [8]  Game Booster (liberar RAM antes de jugar)' -ForegroundColor White
    Write-Host '    [9]  Actualizar todos los programas' -ForegroundColor White
    Write-Host '   [10]  Reparar Windows (archivos danados)' -ForegroundColor White
    Write-Host ''
    Write-Host '   EXTRAS' -ForegroundColor DarkCyan
    Write-Host '   [11]  Modo competitivo (+FPS)' -ForegroundColor Magenta
    Write-Host '   [12]  Revertir todos los cambios' -ForegroundColor Yellow
    Write-Host '    [0]  Salir' -ForegroundColor DarkGray
    Write-Host ''
    $op = (Read-Host '  Elegi una opcion').Trim()
    switch ($op) {
        '1'  { Optimizar -Laptop $false }
        '2'  { Optimizar -Laptop $true }
        '3'  { Titulo 'DIAGNOSTICO' 'Cyan'; M-Diagnostico -Etiqueta 'DIAGNOSTICO' -Abrir $true; Pausa }
        '4'  { T-LimpiezaProfunda }
        '5'  { T-Inicio }
        '6'  { T-Bloat }
        '7'  { T-DNS }
        '8'  { T-Booster }
        '9'  { T-Actualizar }
        '10' { T-Reparar }
        '11' { M-Competitivo }
        '12' { M-Revertir }
        '0'  { return }
    }
}

}

Invoke-Veltrix
