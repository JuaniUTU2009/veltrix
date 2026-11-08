# =====================================================================
#  VELTRIX - Optimizador de Windows
#  Uso (PowerShell):   irm <URL de este archivo> | iex
#  Instagram: @veltrix.fps
# =====================================================================

function Invoke-Veltrix {

# >>> CAMBIAR TU_USUARIO POR TU USUARIO DE GITHUB <<<
$URL = 'https://raw.githubusercontent.com/JuaniUTU2009/veltrix/main/veltrix.ps1'
$VER = '2.0'

# ---------- Permisos de administrador ----------
net session *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host '  Pidiendo permisos de administrador... (toca "Si")' -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm '$URL' | iex`""
    return
}

# ---------- Ayudantes ----------
function R  { param($Path, $Name, $Type, $Data) reg.exe add $Path /v $Name /t $Type /d $Data /f *> $null }
function RD { param($Path, $Name) reg.exe delete $Path /v $Name /f *> $null }
function Paso { param($t) Write-Host ''; Write-Host "  > $t" -ForegroundColor Cyan }
function Listo { param($t) Write-Host "    [OK] $t" -ForegroundColor Green }
function Aviso { param($t) Write-Host "    [!] $t" -ForegroundColor Yellow }

$PLAN_VELTRIX = '7e1f5a00-0000-4000-8000-00000000f9a5'
$CDM = 'HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
$CDM_VALS = 'SilentInstalledAppsEnabled', 'SystemPaneSuggestionsEnabled', 'SoftLandingEnabled', 'PreInstalledAppsEnabled', 'OemPreInstalledAppsEnabled', 'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled', 'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled'
$TAREAS = '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser', '\Microsoft\Windows\Application Experience\ProgramDataUpdater', '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator', '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip', '\Microsoft\Windows\Autochk\Proxy'
$MM = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
$NIC_KEYS = '*EEE', '*InterruptModeration', 'AdvancedEEE', 'EnableGreenEthernet', 'PowerSavingMode', 'GigaLite'
$IFACES = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
$HVCI = 'HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'
$BACKUP_DIR = Join-Path $env:ProgramData 'Veltrix'

function Banner {
    Clear-Host
    Write-Host ''
    Write-Host '  ======================================================' -ForegroundColor DarkCyan
    Write-Host '        V E L T R I X   -   Optimizador de Windows' -ForegroundColor Cyan
    Write-Host "                         v$VER   |   @veltrix.fps" -ForegroundColor DarkGray
    Write-Host '  ======================================================' -ForegroundColor DarkCyan
    Write-Host ''
}

# =====================================================================
#  MODULOS
# =====================================================================

function M-Restauracion {
    Paso 'Creando punto de restauracion (puede tardar 1-2 minutos)...'
    R 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' 'SystemRestorePointCreationFrequency' REG_DWORD 0
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
        Checkpoint-Computer -Description 'Veltrix - antes de optimizar' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Listo 'Punto de restauracion creado'
    } catch {
        Aviso 'No se pudo crear el punto de restauracion (igual se puede revertir desde el menu)'
    }
}

function M-Visual {
    Paso 'Efectos visuales en modo rendimiento...'
    R 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' REG_DWORD 3
    R 'HKCU\Control Panel\Desktop' 'UserPreferencesMask' REG_BINARY '9012038010000000'
    R 'HKCU\Control Panel\Desktop' 'FontSmoothing' REG_SZ 2
    R 'HKCU\Control Panel\Desktop' 'MenuShowDelay' REG_SZ 100
    R 'HKCU\Control Panel\Desktop\WindowMetrics' 'MinAnimate' REG_SZ 0
    R 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' REG_DWORD 0
    R 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ListviewShadow' REG_DWORD 0
    R 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' REG_DWORD 0
    R 'HKCU\Software\Microsoft\Windows\DWM' 'EnableAeroPeek' REG_DWORD 0
    Listo 'Efectos visuales optimizados (letras nitidas y miniaturas se mantienen)'
}

function M-SegundoPlano {
    Paso 'Quitando publicidad y procesos innecesarios en segundo plano...'
    foreach ($v in $CDM_VALS) { R $CDM $v REG_DWORD 0 }
    R 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSyncProviderNotifications' REG_DWORD 0
    R 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_IrisRecommendations' REG_DWORD 0
    R 'HKLM\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' REG_DWORD 0
    R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' 'EnableFeeds' REG_DWORD 0
    R 'HKCU\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' REG_DWORD 1
    R 'HKLM\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled' REG_DWORD 0
    R 'HKLM\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled' REG_DWORD 0
    R 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' REG_DWORD 0
    Listo 'Sin anuncios, widgets, Bing en el Inicio ni Edge en segundo plano'
}

function M-Telemetria {
    Paso 'Reduciendo telemetria y recoleccion de datos...'
    R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' REG_DWORD 0
    foreach ($s in 'DiagTrack', 'dmwappushservice') {
        sc.exe stop $s *> $null
        sc.exe config $s start= disabled *> $null
    }
    foreach ($t in $TAREAS) { schtasks.exe /Change /TN $t /Disable *> $null }
    R 'HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' REG_DWORD 0
    R 'HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' REG_DWORD 0
    R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' REG_DWORD 0
    R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities' REG_DWORD 0
    R 'HKCU\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' REG_DWORD 0
    R 'HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' REG_DWORD 1
    Listo 'Telemetria al minimo'
}

function M-EnergiaPC {
    Paso 'Energia en maximo rendimiento (PC)...'
    powercfg.exe -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 $PLAN_VELTRIX *> $null
    powercfg.exe -changename $PLAN_VELTRIX 'Veltrix Rendimiento' *> $null
    powercfg.exe -setactive $PLAN_VELTRIX *> $null
    if ($LASTEXITCODE -ne 0) { powercfg.exe -setactive SCHEME_MIN *> $null }
    powercfg.exe -h off *> $null
    R 'HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' REG_DWORD 1
    Listo 'Plan "Veltrix Rendimiento" activo, sin hibernacion ni limites de CPU'
}

function M-EnergiaLaptop {
    Paso 'Energia para laptop (rendimiento enchufada, ahorro a bateria)...'
    powercfg.exe -setactive SCHEME_BALANCED *> $null
    $p = '54533251-82be-4824-96c1-47b60b740d00'
    powercfg.exe -setacvalueindex SCHEME_BALANCED $p be337238-0d82-4146-a960-4f3749d470c7 2 *> $null
    powercfg.exe -setacvalueindex SCHEME_BALANCED $p bc5038f7-23e0-4960-96da-33abaf5935ec 100 *> $null
    powercfg.exe -setacvalueindex SCHEME_BALANCED 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0 *> $null
    powercfg.exe -setacvalueindex SCHEME_BALANCED 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 *> $null
    powercfg.exe -setactive SCHEME_BALANCED *> $null
    Listo 'Enchufada: turbo agresivo, sin ahorro en PCIe/USB. Bateria: sin cambios'
}

function M-Juegos {
    Paso 'Optimizacion para juegos...'
    R 'HKCU\Software\Microsoft\GameBar' 'AutoGameModeEnabled' REG_DWORD 1
    R 'HKCU\Software\Microsoft\GameBar' 'AllowAutoGameMode' REG_DWORD 1
    R 'HKCU\System\GameConfigStore' 'GameDVR_Enabled' REG_DWORD 0
    R 'HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' REG_DWORD 0
    R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' REG_DWORD 0
    R 'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' REG_DWORD 2
    R $MM 'SystemResponsiveness' REG_DWORD 10
    R $MM 'NetworkThrottlingIndex' REG_DWORD 0xffffffff
    R "$MM\Tasks\Games" 'GPU Priority' REG_DWORD 8
    R "$MM\Tasks\Games" 'Priority' REG_DWORD 6
    R "$MM\Tasks\Games" 'Scheduling Category' REG_SZ 'High'
    R "$MM\Tasks\Games" 'SFIO Priority' REG_SZ 'High'
    R 'HKCU\Control Panel\Mouse' 'MouseSpeed' REG_SZ 0
    R 'HKCU\Control Panel\Mouse' 'MouseThreshold1' REG_SZ 0
    R 'HKCU\Control Panel\Mouse' 'MouseThreshold2' REG_SZ 0
    Listo 'Modo juego, sin grabacion Xbox, prioridad a juegos, mouse 1:1'
}

function M-Latencia {
    param([bool]$Laptop)
    Paso 'Latencia y respuesta del sistema...'
    R 'HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' REG_DWORD 38
    R 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'GlobalTimerResolutionRequests' REG_DWORD 1
    R 'HKCU\Software\Microsoft\DirectX\UserGpuPreferences' 'DirectXUserGlobalSettings' REG_SZ 'SwapEffectUpgradeEnable=1;'
    bcdedit.exe /deletevalue useplatformclock *> $null
    bcdedit.exe /deletevalue useplatformtick *> $null
    if (-not $Laptop) {
        powercfg.exe -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 100 *> $null
        powercfg.exe -setactive SCHEME_CURRENT *> $null
    }
    Listo 'Prioridad a la ventana activa, timers precisos, menos input lag en ventana'
}

function M-Red {
    param([bool]$Laptop)
    Paso 'Red para juegos online...'
    R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' REG_DWORD 0
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
    Paso 'Disco, memoria y servicios...'
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
    Paso 'Limpiando archivos basura...'
    Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Stop-Service wuauserv, bits -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service bits, wuauserv -ErrorAction SilentlyContinue
    ipconfig.exe /flushdns *> $null
    Write-Host '    Limpiando componentes viejos de Windows (5 a 15 min, es normal)...' -ForegroundColor DarkGray
    Dism.exe /Online /Cleanup-Image /StartComponentCleanup /Quiet *> $null
    Listo 'Limpieza terminada (la papelera NO se toca)'
}

function M-Diagnostico {
    param([string]$Etiqueta = 'DIAGNOSTICO', [bool]$Abrir = $true)
    Paso "Generando informe $Etiqueta..."
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
    $startup = @(Get-CimInstance Win32_StartupCommand | Select-Object -ExpandProperty Name)
    $discos = @(Get-PhysicalDisk -ErrorAction SilentlyContinue)

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
    $L += "Integridad de memoria .... $hvci"
    $L += "Encendido hace ........... $($up.Days) dias, $($up.Hours) horas"
    $L += ''
    $L += "--- PROGRAMAS QUE ARRANCAN CON WINDOWS ($($startup.Count)) ---"
    foreach ($s in $startup) { $L += "  - $s" }
    $L += ''
    $L += '--- RECOMENDACIONES ---'
    if ($ramT -lt 7.5) { $L += '  * Menos de 8 GB de RAM: ampliar memoria es la mejora mas grande posible.' }
    if (($discos | Where-Object MediaType -eq 'HDD') -and -not ($discos | Where-Object MediaType -eq 'SSD')) { $L += '  * Windows en disco mecanico (HDD): pasar a SSD cambia la PC por completo.' }
    if ($up.Days -ge 7) { $L += '  * Hace mas de una semana que no se reinicia: reiniciar seguido ayuda.' }
    if ($startup.Count -gt 8) { $L += '  * Muchos programas al inicio: desactivar los que no se usan (Administrador de tareas > Inicio).' }
    foreach ($g in $gpus) { if ($g.DriverDate -and (((Get-Date) - $g.DriverDate).Days -gt 180)) { $L += "  * Driver de $($g.Name) con mas de 6 meses: actualizarlo." } }
    $L += ''
    $L += 'Veltrix - Instagram @veltrix.fps'

    $L | Out-File -FilePath $file -Encoding UTF8
    Listo "Informe guardado en el Escritorio: Veltrix_$Etiqueta"
    if ($Abrir) { Start-Process notepad.exe $file }
}

function M-Competitivo {
    Banner
    Write-Host '  MODO COMPETITIVO (EXTRA)' -ForegroundColor Magenta
    Write-Host ''
    Write-Host '  Desactiva la "Integridad de memoria" (HVCI) de Windows.'
    Write-Host '  En muchas PCs da entre 5% y 10% mas de FPS.'
    Write-Host ''
    Write-Host '  IMPORTANTE: es una capa de seguridad extra contra malware avanzado.' -ForegroundColor Yellow
    Write-Host '  Windows Defender sigue funcionando igual. Recomendado solo para PCs de juego.' -ForegroundColor Yellow
    Write-Host '  Algunos anticheats (Valorant, FACEIT) pueden pedir que este activada:' -ForegroundColor Yellow
    Write-Host '  si pasa, se deshace con la opcion "Revertir" del menu.' -ForegroundColor Yellow
    Write-Host ''
    if ((Read-Host '  Aplicar? (S/N)') -notmatch '^[sS]') { return }
    New-Item -ItemType Directory -Path $BACKUP_DIR -Force -ErrorAction SilentlyContinue | Out-Null
    $bk = Join-Path $BACKUP_DIR 'hvci_backup.reg'
    if (-not (Test-Path $bk)) { reg.exe export 'HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard' $bk /y *> $null }
    R $HVCI 'Enabled' REG_DWORD 0
    Listo 'Modo competitivo aplicado'
    Reiniciar
}

function M-Revertir {
    Banner
    Write-Host '  REVERTIR: deja Windows como estaba de fabrica en todo lo que toco Veltrix.' -ForegroundColor Yellow
    Write-Host ''
    if ((Read-Host '  Continuar? (S/N)') -notmatch '^[sS]') { return }

    Paso 'Efectos visuales...'
    R 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' REG_DWORD 0
    R 'HKCU\Control Panel\Desktop' 'UserPreferencesMask' REG_BINARY '9E1E078012000000'
    R 'HKCU\Control Panel\Desktop' 'MenuShowDelay' REG_SZ 400
    R 'HKCU\Control Panel\Desktop\WindowMetrics' 'MinAnimate' REG_SZ 1
    R 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' REG_DWORD 1
    R 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ListviewShadow' REG_DWORD 1
    R 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' REG_DWORD 1
    R 'HKCU\Software\Microsoft\Windows\DWM' 'EnableAeroPeek' REG_DWORD 1

    Paso 'Segundo plano y sugerencias...'
    foreach ($v in $CDM_VALS) { R $CDM $v REG_DWORD 1 }
    R 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSyncProviderNotifications' REG_DWORD 1
    RD 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_IrisRecommendations'
    RD 'HKLM\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests'
    RD 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' 'EnableFeeds'
    RD 'HKCU\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions'
    RD 'HKLM\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled'
    RD 'HKLM\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled'
    RD 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec'

    Paso 'Telemetria y privacidad...'
    RD 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry'
    sc.exe config DiagTrack start= auto *> $null
    sc.exe start DiagTrack *> $null
    sc.exe config dmwappushservice start= demand *> $null
    foreach ($t in $TAREAS) { schtasks.exe /Change /TN $t /Enable *> $null }
    R 'HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' REG_DWORD 1
    R 'HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' REG_DWORD 1
    RD 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities'
    RD 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities'
    RD 'HKCU\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod'
    RD 'HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot'

    Paso 'Energia...'
    powercfg.exe -setactive SCHEME_BALANCED *> $null
    powercfg.exe -delete $PLAN_VELTRIX *> $null
    powercfg.exe -restoredefaultschemes *> $null
    powercfg.exe -h on *> $null
    RD 'HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff'

    Paso 'Juegos, latencia y mouse...'
    RD 'HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled'
    R 'HKCU\System\GameConfigStore' 'GameDVR_Enabled' REG_DWORD 1
    RD 'HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR'
    RD 'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode'
    R $MM 'SystemResponsiveness' REG_DWORD 20
    R $MM 'NetworkThrottlingIndex' REG_DWORD 10
    R "$MM\Tasks\Games" 'GPU Priority' REG_DWORD 8
    R "$MM\Tasks\Games" 'Priority' REG_DWORD 2
    R "$MM\Tasks\Games" 'Scheduling Category' REG_SZ 'Medium'
    R "$MM\Tasks\Games" 'SFIO Priority' REG_SZ 'Normal'
    R 'HKCU\Control Panel\Mouse' 'MouseSpeed' REG_SZ 1
    R 'HKCU\Control Panel\Mouse' 'MouseThreshold1' REG_SZ 6
    R 'HKCU\Control Panel\Mouse' 'MouseThreshold2' REG_SZ 10
    R 'HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' REG_DWORD 2
    RD 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'GlobalTimerResolutionRequests'
    RD 'HKCU\Software\Microsoft\DirectX\UserGpuPreferences' 'DirectXUserGlobalSettings'

    Paso 'Red...'
    RD 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode'
    Get-ChildItem $IFACES -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-ItemProperty -Path $_.PSPath -Name 'TcpAckFrequency' -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $_.PSPath -Name 'TCPNoDelay' -Force -ErrorAction SilentlyContinue
    }
    foreach ($n in (Get-NetAdapter -Physical -ErrorAction SilentlyContinue)) {
        Enable-NetAdapterPowerManagement -Name $n.Name -NoRestart -ErrorAction SilentlyContinue | Out-Null
        foreach ($k in $NIC_KEYS) { Reset-NetAdapterAdvancedProperty -Name $n.Name -RegistryKeyword $k -NoRestart -ErrorAction SilentlyContinue | Out-Null }
    }

    Paso 'Disco, memoria y servicios...'
    fsutil.exe behavior set disablelastaccess 2 *> $null
    fsutil.exe behavior set disable8dot3 2 *> $null
    sc.exe config Fax start= demand *> $null
    sc.exe config RetailDemo start= demand *> $null
    sc.exe config MapsBroker start= delayed-auto *> $null
    Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue

    $bk = Join-Path $BACKUP_DIR 'hvci_backup.reg'
    if (Test-Path $bk) {
        Paso 'Integridad de memoria...'
        RD $HVCI 'Enabled'
        reg.exe import $bk *> $null
        Remove-Item $bk -Force -ErrorAction SilentlyContinue
    }

    Listo 'Todo revertido'
    Reiniciar
}

function Reiniciar {
    Write-Host ''
    Write-Host '  ======================================================' -ForegroundColor DarkCyan
    Write-Host '    LISTO. Hay que reiniciar para aplicar los cambios.' -ForegroundColor Green
    Write-Host '  ======================================================' -ForegroundColor DarkCyan
    Write-Host ''
    if ((Read-Host '  Reiniciar ahora? (S/N)') -match '^[sS]') {
        shutdown.exe /r /t 5 /c "Veltrix: reiniciando para aplicar los cambios"
        exit
    }
}

function Optimizar {
    param([bool]$Laptop)
    Banner
    $tipo = if ($Laptop) { 'LAPTOP' } else { 'PC DE ESCRITORIO' }
    Write-Host "  Se va a optimizar este equipo como: $tipo" -ForegroundColor White
    Write-Host ''
    Write-Host '   - Punto de restauracion + informe ANTES en el Escritorio'
    Write-Host '   - Efectos visuales, publicidad y procesos en segundo plano'
    Write-Host '   - Telemetria y privacidad'
    Write-Host '   - Energia, juegos y latencia'
    Write-Host '   - Red, disco, memoria y servicios'
    Write-Host '   - Limpieza de archivos basura'
    Write-Host ''
    if ($Laptop) { Write-Host '  Conecta el cargador y cerra los programas abiertos.' -ForegroundColor Yellow }
    else { Write-Host '  Cerra los programas abiertos.' -ForegroundColor Yellow }
    Write-Host ''
    if ((Read-Host '  Empezar? (S/N)') -notmatch '^[sS]') { return }

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

    Write-Host ''
    Write-Host '  Despues de reiniciar, volve a abrir Veltrix y elegi "Diagnostico"' -ForegroundColor Cyan
    Write-Host '  para comparar con el informe ANTES que quedo en el Escritorio.' -ForegroundColor Cyan
    Reiniciar
}

# =====================================================================
#  MENU
# =====================================================================
while ($true) {
    Banner
    Write-Host '   [1]  Optimizar PC de escritorio' -ForegroundColor White
    Write-Host '   [2]  Optimizar Laptop / Notebook' -ForegroundColor White
    Write-Host '   [3]  Diagnostico del equipo (antes / despues)' -ForegroundColor White
    Write-Host '   [4]  EXTRA: Modo competitivo' -ForegroundColor Magenta
    Write-Host '   [5]  Revertir todos los cambios' -ForegroundColor Yellow
    Write-Host '   [0]  Salir' -ForegroundColor DarkGray
    Write-Host ''
    $op = Read-Host '  Elegi una opcion'
    switch ($op) {
        '1' { Optimizar -Laptop $false }
        '2' { Optimizar -Laptop $true }
        '3' { Banner; M-Diagnostico -Etiqueta 'DIAGNOSTICO' -Abrir $true; Write-Host ''; Read-Host '  Enter para volver al menu' | Out-Null }
        '4' { M-Competitivo }
        '5' { M-Revertir }
        '0' { return }
    }
}

}

Invoke-Veltrix
