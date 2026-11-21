# =====================================================================
#  VELTRIX - Optimizador de Windows
#  Uso (PowerShell):   irm <URL de este archivo> | iex
#  Instagram: @veltrix.fps
# =====================================================================

function Invoke-Veltrix {

$URL = 'https://raw.githubusercontent.com/JuaniUTU2009/veltrix/main/veltrix-consola.ps1'
$VER = '4.2'

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

$VX_DIAG = @'
$VXDIR = Join-Path $env:ProgramData 'Veltrix'

function Esc { param($s) return ("$s" -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;') }

function Get-Escritorio {
    $d = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders' -ErrorAction SilentlyContinue).Desktop
    if (-not $d) { $d = Join-Path $env:USERPROFILE 'Desktop' }
    return $d
}

function Get-Inicio {
    $fuentes = @(
        @{ Run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Ap = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' },
        @{ Run = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Ap = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' },
        @{ Run = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Ap = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32' }
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
            $lista += [pscustomobject]@{ Nombre = $p.Name; Ap = $f.Ap; Activo = $activo }
        }
    }
    $carpetas = @(
        @{ D = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"; Ap = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder' },
        @{ D = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"; Ap = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder' }
    )
    foreach ($c in $carpetas) {
        $apr = Get-ItemProperty ('Registry::' + $c.Ap) -ErrorAction SilentlyContinue
        foreach ($f in (Get-ChildItem $c.D -File -ErrorAction SilentlyContinue | Where-Object Name -ne 'desktop.ini')) {
            $activo = $true
            if ($apr -and $apr.($f.Name)) { $activo = (($apr.($f.Name)[0] % 2) -eq 0) }
            $lista += [pscustomobject]@{ Nombre = $f.Name; Ap = $c.Ap; Activo = $activo }
        }
    }
    return $lista
}

function Get-VxDiscoSistema {
    try {
        $num = (Get-Partition -DriveLetter ($env:SystemDrive.Substring(0, 1)) -ErrorAction Stop).DiskNumber
        $pd = Get-PhysicalDisk -ErrorAction Stop | Where-Object { "$($_.DeviceId)" -eq "$num" } | Select-Object -First 1
        if ($pd) { return "$($pd.MediaType)" }
    } catch {}
    return 'Desconocido'
}

function Get-VxArranque {
    param([int]$EsperarSeg = 0)
    $os = Get-CimInstance Win32_OperatingSystem
    $limite = (Get-Date).AddSeconds($EsperarSeg)
    do {
        $e = Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-Diagnostics-Performance/Operational'; Id = 100 } -MaxEvents 1 -ErrorAction SilentlyContinue
        if ($e -and ($EsperarSeg -eq 0 -or $e.TimeCreated -gt $os.LastBootUpTime)) {
            $ms = (([xml]$e.ToXml()).Event.EventData.Data | Where-Object { $_.Name -eq 'BootTime' }).'#text'
            if ($ms) { return [math]::Round([double]$ms / 1000, 1) }
            return $null
        }
        if ($EsperarSeg -gt 0) { Start-Sleep -Seconds 20 }
    } while ((Get-Date) -lt $limite)
    return $null
}

function Get-VxBateria {
    try {
        $b = @(Get-CimInstance Win32_Battery -ErrorAction Stop)
        if ($b.Count -eq 0) { return $null }
        $x = Join-Path $env:TEMP 'vx_bateria.xml'
        powercfg.exe /batteryreport /xml /output $x *> $null
        if (-not (Test-Path $x)) { return $null }
        [xml]$r = Get-Content $x -Raw
        Remove-Item $x -Force -ErrorAction SilentlyContinue
        $bat = @($r.BatteryReport.Batteries.Battery)[0]
        $dis = [double]$bat.DesignCapacity; $act = [double]$bat.FullChargeCapacity
        if ($dis -gt 0) { return [math]::Round($act / $dis * 100) }
    } catch {}
    return $null
}

function Get-VxAnticheat {
    $l = @()
    if ((Get-Service vgc -ErrorAction SilentlyContinue) -or (Test-Path "$env:ProgramFiles\Riot Vanguard")) { $l += 'Vanguard (VALORANT)' }
    if ((Get-Service FACEIT -ErrorAction SilentlyContinue) -or (Test-Path "$env:ProgramFiles\FACEIT AC")) { $l += 'FACEIT' }
    return $l
}

function Get-VxJuegosComp {
    $j = @()
    if ((Test-Path 'C:\Riot Games\VALORANT') -or (Test-Path "$env:ProgramFiles\Riot Games\VALORANT")) { $j += 'VALORANT' }
    $libs = @()
    $sp = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if ($sp) {
        $libs += ($sp -replace '/', '\')
        $vdf = Join-Path ($sp -replace '/', '\') 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) { foreach ($mt in (Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' -ErrorAction SilentlyContinue)) { $libs += ($mt.Matches[0].Groups[1].Value -replace '\\\\', '\') } }
    }
    foreach ($l in $libs) { if (Test-Path (Join-Path $l 'steamapps\common\Counter-Strike Global Offensive')) { $j += 'CS2'; break } }
    $fn = $false
    foreach ($it in (Get-ChildItem "$env:ProgramData\Epic\EpicGamesLauncher\Data\Manifests" -Filter '*.item' -ErrorAction SilentlyContinue)) {
        if ((Get-Content $it.FullName -Raw -ErrorAction SilentlyContinue) -match '"DisplayName"\s*:\s*"Fortnite"') { $fn = $true }
    }
    if ($fn -or (Test-Path "$env:ProgramFiles\Epic Games\Fortnite")) { $j += 'Fortnite' }
    return $j
}

function Get-VxMetricas {
    param([int]$EsperarArranque = 0)
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $gpus = @(Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Remote|Virtual|Parsec|Meta Virtual|Microsoft Basic' })
    $m = [ordered]@{}
    $m.Fecha = (Get-Date).ToString('dd/MM/yyyy HH:mm')
    $m.Equipo = $env:COMPUTERNAME
    $m.Windows = "$($os.Caption) (build $($os.BuildNumber))"
    $m.CPU = "$($cpu.Name)".Trim()
    $m.GPU = (@($gpus | ForEach-Object { $_.Name }) -join ' + ')
    $gdias = 0
    foreach ($g in $gpus) { if ($g.DriverDate) { $d = ((Get-Date) - $g.DriverDate).Days; if ($d -gt $gdias) { $gdias = $d } } }
    $m.GpuDriverDias = $gdias
    $m.Laptop = [bool](@(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue).Count -gt 0)
    $m.Fabricante = "$($cs.Manufacturer)".Trim()
    $m.Build = [int]$os.BuildNumber
    $m.ReBAR = $null; $m.GpuTemp = $null
    $nsmi = Join-Path $env:SystemRoot 'System32\nvidia-smi.exe'
    if (Test-Path $nsmi) {
        $q = (& $nsmi -q -d 'MEMORY,TEMPERATURE' 2>$null) -join "`n"
        if ($q -match 'BAR1 Memory Usage\s+Total\s*:\s*(\d+)\s*MiB') { $m.ReBAR = ([int]$Matches[1] -gt 256) }
        if ($q -match 'GPU Current Temp\s*:\s*(\d+)') { $m.GpuTemp = [int]$Matches[1] }
    }
    $m.Hz = 0; $m.HzMax = 0
    foreach ($g in $gpus) { if ($g.CurrentRefreshRate -gt $m.Hz) { $m.Hz = [int]$g.CurrentRefreshRate; $m.HzMax = [int]$g.MaxRefreshRate } }
    $m.RamTotal = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    $libre = $os.FreePhysicalMemory / 1MB
    $m.RamUso = [math]::Round($m.RamTotal - $libre, 1)
    $m.RamPct = [math]::Round(($m.RamTotal - $libre) / $m.RamTotal * 100)
    $mods = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue)
    $m.RamModulos = $mods.Count
    $m.RamVel = 0; $m.RamVelMax = 0
    if ($mods.Count -gt 0) { $m.RamVel = [int]($mods | Measure-Object ConfiguredClockSpeed -Minimum).Minimum; $m.RamVelMax = [int]($mods | Measure-Object Speed -Minimum).Minimum }
    $m.Procesos = @(Get-Process).Count
    $m.Servicios = @(Get-Service | Where-Object Status -eq 'Running').Count
    $ini = @(Get-Inicio | Where-Object Activo)
    $m.Inicio = $ini.Count
    $m.InicioLista = @($ini | ForEach-Object { $_.Nombre })
    $tb = 0
    foreach ($p in @($env:TEMP, "$env:SystemRoot\Temp", "$env:SystemRoot\SoftwareDistribution\Download")) {
        $s = (Get-ChildItem $p -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        if ($s) { $tb += $s }
    }
    $m.BasuraMB = [math]::Round($tb / 1MB)
    $v = Get-Volume -DriveLetter ($env:SystemDrive.Substring(0, 1)) -ErrorAction SilentlyContinue
    $m.LibreGB = if ($v) { [math]::Round($v.SizeRemaining / 1GB, 1) } else { 0 }
    $m.TotalGB = if ($v) { [math]::Round($v.Size / 1GB) } else { 0 }
    $m.LibrePct = if ($v -and $v.Size -gt 0) { [math]::Round($v.SizeRemaining / $v.Size * 100) } else { 0 }
    $m.Disco = Get-VxDiscoSistema
    $m.DiscosSalud = @(Get-PhysicalDisk -ErrorAction SilentlyContinue | ForEach-Object {
        $rc = $_ | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
        $extra = ''
        if ($rc -and $rc.Wear -ne $null) { $extra += " | desgaste $($rc.Wear)%" }
        if ($rc -and $rc.Temperature) { $extra += " | $($rc.Temperature) C" }
        "$($_.FriendlyName) ($($_.MediaType), $([math]::Round($_.Size / 1GB)) GB): $($_.HealthStatus)$extra"
    })
    $m.DiscoProblema = [bool](Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.HealthStatus -and "$($_.HealthStatus)" -ne 'Healthy' })
    $m.Plan = ((powercfg.exe /getactivescheme) -replace '^.*\(', '' -replace '\)\s*$', '').Trim()
    $m.UptimeDias = ((Get-Date) - $os.LastBootUpTime).Days
    $m.Arranque = Get-VxArranque -EsperarSeg $EsperarArranque
    $m.Bateria = Get-VxBateria
    $dg = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
    $m.HVCI = [bool]($dg -and ($dg.SecurityServicesRunning -contains 2))
    $m.Juegos = @(Get-VxJuegosComp)
    $m.Anticheat = @(Get-VxAnticheat)
    $m.Indice = Get-VxIndice $m
    return [pscustomobject]$m
}

function Get-VxIndice {
    param($m)
    $p = 100.0
    if ($m.RamPct -gt 45) { $p -= [math]::Min(25, ($m.RamPct - 45) * 0.6) }
    if ($m.Procesos -gt 110) { $p -= [math]::Min(15, ($m.Procesos - 110) * 0.12) }
    if ($m.Inicio -gt 3) { $p -= [math]::Min(15, ($m.Inicio - 3) * 2.5) }
    $p -= [math]::Min(10, $m.BasuraMB / 1024 * 4)
    if ($m.LibrePct -lt 20) { $p -= [math]::Min(15, (20 - $m.LibrePct) * 0.9) }
    if ($m.Disco -eq 'HDD') { $p -= 10 }
    if ($m.Plan -match 'ahorro|saver') { $p -= 5 }
    if ($m.UptimeDias -ge 7) { $p -= 5 }
    return [int][math]::Max(5, [math]::Round($p))
}

function Get-VxRecomendaciones {
    param($m)
    $r = @()
    if ($m.RamTotal -lt 7.5) { $r += 'Tiene menos de 8 GB de RAM: ampliar la memoria es la mejora m&aacute;s grande posible.' }
    if ($m.RamModulos -eq 1 -and $m.RamTotal -ge 7.5) { $r += 'La RAM est&aacute; en un solo m&oacute;dulo. Con dos m&oacute;dulos iguales (dual channel) los juegos suelen rendir bastante m&aacute;s.' }
    if ($m.RamVelMax -gt 0 -and $m.RamVel -gt 0 -and $m.RamVel -lt ($m.RamVelMax - 100)) { $r += "La RAM funciona a $($m.RamVel) MHz pero soporta $($m.RamVelMax) MHz: se puede activar el perfil XMP/EXPO en la BIOS." }
    if ($m.Disco -eq 'HDD') { $r += 'Windows est&aacute; en un disco mec&aacute;nico (HDD). Pasar a un SSD cambia la PC por completo.' }
    if ($m.LibrePct -lt 15) { $r += "Queda poco espacio en el disco ($($m.LibrePct)% libre). Conviene liberar espacio o sumar un disco." }
    if ($m.Hz -gt 0 -and $m.HzMax -gt $m.Hz -and $m.HzMax -le 500 -and $m.Hz -le 75) { $r += "La pantalla est&aacute; a $($m.Hz) Hz y podr&iacute;a soportar m&aacute;s. Revisalo en Configuraci&oacute;n &gt; Pantalla &gt; Pantalla avanzada." }
    if ($m.GpuDriverDias -gt 180) { $r += 'El driver de la placa de video tiene m&aacute;s de 6 meses: actualizarlo puede dar m&aacute;s FPS.' }
    if ($m.Bateria -ne $null -and $m.Bateria -lt 70) { $r += "La bater&iacute;a conserva el $($m.Bateria)% de su capacidad original: dura bastante menos que nueva." }
    if ($m.DiscoProblema) { $r += 'Un disco reporta problemas de salud: hac&eacute; una copia de seguridad de tus archivos cuanto antes.' }
    if ($m.Inicio -gt 6) { $r += "Arrancan $($m.Inicio) programas con Windows. Desde Veltrix &gt; Programas de inicio se pueden apagar los que no uses." }
    if ($m.UptimeDias -ge 7) { $r += 'Hace m&aacute;s de una semana que no se reinicia. Reiniciar seguido mantiene Windows fluido.' }
    if ($m.HVCI) { $r += 'La Integridad de memoria est&aacute; activa. En PCs de juego, el Modo competitivo de Veltrix puede dar algunos FPS extra.' }
    if ($m.ReBAR -eq $false -and $m.GPU -match 'RTX [3-9]0\d\d') { $r += 'Resizable BAR est&aacute; apagado. Si la placa madre lo soporta, activarlo en la BIOS (Above 4G Decoding + Resizable BAR) puede dar FPS extra.' }
    if ($m.GpuTemp -ne $null -and $m.GpuTemp -ge 85) { $r += "La placa de video est&aacute; a $($m.GpuTemp) C: conviene una limpieza interna y cambio de pasta t&eacute;rmica." }
    if ($m.Laptop -and $m.GPU -match 'NVIDIA|GeForce|Radeon RX') {
        $app = switch -Regex ($m.Fabricante) { 'ASUS' { 'Armoury Crate' } 'LENOVO' { 'Legion Space / Lenovo Vantage' } 'HP' { 'OMEN Gaming Hub' } 'Micro-Star|MSI' { 'MSI Center' } 'Acer' { 'NitroSense / PredatorSense' } 'Dell|Alienware' { 'Alienware Command Center' } default { 'la app del fabricante' } }
        $r += "Laptop gamer: para jugar, en $app pon&eacute; el modo Turbo/Rendimiento y, si existe, el modo de GPU dedicada (MUX). Puede dar mucho m&aacute;s FPS."
    }
    if ($m.Juegos -contains 'VALORANT') { $r += 'VALORANT: pantalla completa, NVIDIA Reflex en &quot;Activado + Boost&quot;, V-Sync apagado, Renderizado multihilo activado y Vi&ntilde;eta, Bloom y Distorsi&oacute;n apagados.' }
    if ($m.Juegos -contains 'CS2') { $r += 'CS2: pantalla completa, NVIDIA Reflex activado, &quot;Aumentar contraste de jugadores&quot; activado y V-Sync apagado. Un l&iacute;mite de FPS estable (fps_max) reduce los tirones.' }
    if ($m.Juegos -contains 'Fortnite') { $r += 'Fortnite: en PCs de pocos recursos us&aacute; el modo de renderizado &quot;Rendimiento&quot;; con buena placa, DirectX 12. NVIDIA Reflex &quot;Activado + Boost&quot; y V-Sync apagado.' }
    if ($m.Juegos.Count -gt 0) { $r += 'Antes de jugar competitivo, us&aacute; el Modo Partida de Veltrix: es compatible con Vanguard y FACEIT.' }
    if ($m.Build -ge 26100) { $r += 'Tip: el modo Xbox de Windows 11 (Win+G &gt; Configuraci&oacute;n) libera RAM mientras jug&aacute;s, si est&aacute; disponible en tu PC.' }
    if ($r.Count -eq 0) { $r += 'No encontramos problemas importantes en el hardware. &iexcl;Equipo en buen estado!' }
    return $r
}

function Write-VxInforme {
    param($M, $Antes = $null, [string]$Etiqueta = 'DIAGNOSTICO', [bool]$Abrir = $false)
    $titulos = @{ 'ANTES' = 'Informe ANTES de la optimizaci&oacute;n'; 'DESPUES' = 'Informe DESPU&Eacute;S de la optimizaci&oacute;n'; 'DIAGNOSTICO' = 'Diagn&oacute;stico del equipo' }
    $titulo = $titulos[$Etiqueta]
    $col = if ($M.Indice -ge 80) { '#22E58B' } elseif ($M.Indice -ge 55) { '#FFB020' } else { '#FF4D6A' }
    $deg = [int]($M.Indice * 3.6)

    $comp = ''
    if ($Antes) {
        $filas = @(
            @('&Iacute;ndice Veltrix', $Antes.Indice, $M.Indice, 'mas', ''),
            @('RAM en uso', $Antes.RamUso, $M.RamUso, 'menos', ' GB'),
            @('Procesos abiertos', $Antes.Procesos, $M.Procesos, 'menos', ''),
            @('Servicios corriendo', $Antes.Servicios, $M.Servicios, 'menos', ''),
            @('Programas al inicio', $Antes.Inicio, $M.Inicio, 'menos', ''),
            @('Archivos basura', $Antes.BasuraMB, $M.BasuraMB, 'menos', ' MB'),
            @('Espacio libre en el disco', $Antes.LibreGB, $M.LibreGB, 'mas', ' GB'),
            @('Arranque de Windows', $Antes.Arranque, $M.Arranque, 'menos', ' s')
        )
        $rows = ''
        foreach ($f in $filas) {
            $a = $f[1]; $d = $f[2]
            if ($a -eq $null -or $d -eq $null -or "$a" -eq '' -or "$d" -eq '') { continue }
            $diff = [math]::Round([double]$d - [double]$a, 1)
            $mejor = if ($f[3] -eq 'menos') { $diff -lt 0 } else { $diff -gt 0 }
            $signo = if ($diff -gt 0) { '+' } else { '' }
            $cls = if ($diff -eq 0) { 'igual' } elseif ($mejor) { 'mejor' } else { 'peor' }
            $flecha = if ($diff -eq 0) { '=' } elseif ($mejor) { '&#9650; mejor&oacute;' } else { '&#9660;' }
            $rows += "<tr><td>$($f[0])</td><td>$a$($f[4])</td><td><b>$d$($f[4])</b></td><td class='$cls'>$signo$diff$($f[4]) &nbsp;$flecha</td></tr>"
        }
        $sub = if ($Etiqueta -eq 'DESPUES') { 'Medido unos minutos despu&eacute;s de reiniciar, con Windows ya iniciado.' } else { 'Comparado con el informe ANTES.' }
        $comp = "<section><h2>Antes vs. ahora</h2><p class='muted'>$sub</p><table><tr><th></th><th>Antes</th><th>Ahora</th><th>Cambio</th></tr>$rows</table></section>"
    }

    $salud = ''
    foreach ($s in $M.DiscosSalud) { $salud += "<li>$(Esc $s)</li>" }
    $bat = if ($M.Bateria -ne $null) { "<li>Bater&iacute;a: conserva el <b>$($M.Bateria)%</b> de su capacidad original</li>" } else { '' }
    $ini = ''
    foreach ($s in $M.InicioLista) { $ini += "<li>$(Esc $s)</li>" }
    if (-not $ini) { $ini = '<li>Ninguno</li>' }
    $rec = ''
    foreach ($s in (Get-VxRecomendaciones $M)) { $rec += "<li>$s</li>" }
    $arr = if ($M.Arranque) { "$($M.Arranque) s" } else { 's/d' }
    $delta = ''
    if ($Antes -and $Antes.Indice -ne $null) {
        $dd = $M.Indice - $Antes.Indice
        $sg = if ($dd -gt 0) { '+' } else { '' }
        $delta = "<div class='delta'>Antes: $($Antes.Indice) &rarr; Ahora: $($M.Indice) <span>($sg$dd)</span></div>"
    }

    $html = @"
<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Veltrix - $Etiqueta</title>
<style>
body{margin:0;background:#04172F;color:#fff;font-family:'Segoe UI',Inter,Arial,sans-serif}
.wrap{max-width:880px;margin:0 auto;padding:40px 28px 60px}
header{display:flex;justify-content:space-between;align-items:center}
.logo{font-weight:900;font-size:30px;letter-spacing:2px;color:#2EE6FF}
.muted{color:#9FB3C8}
h1{font-size:40px;margin:28px 0 6px}
h2{font-size:24px;margin:0 0 8px;color:#2EE6FF}
section{background:#0A2547;border:1px solid #17406B;border-radius:22px;padding:24px 26px;margin-top:22px}
.score{display:flex;gap:30px;align-items:center}
.ring{width:170px;height:170px;border-radius:50%;background:conic-gradient($col ${deg}deg,#17406B 0);display:flex;align-items:center;justify-content:center;flex-shrink:0}
.ring div{width:132px;height:132px;border-radius:50%;background:#0A2547;display:flex;flex-direction:column;align-items:center;justify-content:center}
.ring b{font-size:54px;color:$col;line-height:1}
.ring span{font-size:13px;color:#9FB3C8}
.delta{margin-top:10px;font-size:20px;font-weight:700}.delta span{color:#22E58B}
table{width:100%;border-collapse:collapse;font-size:17px}
td,th{padding:11px 8px;border-bottom:1px solid #17406B;text-align:left}th{color:#9FB3C8;font-weight:600}
.mejor{color:#22E58B;font-weight:700}.peor{color:#FFB020}.igual{color:#9FB3C8}
ul{margin:6px 0 0;padding-left:22px;line-height:1.6}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:6px 24px;font-size:16px}
.grid div span{color:#9FB3C8}
footer{margin-top:30px;color:#9FB3C8;font-size:13px;line-height:1.5}
</style></head><body><div class="wrap">
<header><div class="logo">&#9889; VELTRIX</div><div class="muted">$($M.Fecha) &middot; $(Esc $M.Equipo)</div></header>
<h1>$titulo</h1>
<section class="score"><div class="ring"><div><b>$($M.Indice)</b><span>de 100</span></div></div>
<div><h2>&Iacute;ndice Veltrix</h2><div class="muted">Resume la carga del sistema (RAM, procesos, programas de inicio), la basura acumulada, el espacio libre y el tipo de disco.</div>$delta</div></section>
$comp
<section><h2>Estado actual</h2><div class="grid">
<div><span>RAM en uso:</span> $($M.RamUso) de $($M.RamTotal) GB ($($M.RamPct)%)</div>
<div><span>Procesos abiertos:</span> $($M.Procesos)</div>
<div><span>Servicios corriendo:</span> $($M.Servicios)</div>
<div><span>Programas al inicio:</span> $($M.Inicio)</div>
<div><span>Archivos basura:</span> $($M.BasuraMB) MB</div>
<div><span>Espacio libre:</span> $($M.LibreGB) de $($M.TotalGB) GB</div>
<div><span>Arranque de Windows:</span> $arr</div>
<div><span>Plan de energ&iacute;a:</span> $(Esc $M.Plan)</div>
</div></section>
<section><h2>Equipo</h2><div class="grid">
<div><span>Windows:</span> $(Esc $M.Windows)</div>
<div><span>Procesador:</span> $(Esc $M.CPU)</div>
<div><span>Placa de video:</span> $(Esc $M.GPU)</div>
<div><span>RAM:</span> $($M.RamTotal) GB en $($M.RamModulos) m&oacute;dulo(s), $($M.RamVel) MHz</div>
<div><span>Disco de Windows:</span> $(Esc $M.Disco)</div>
<div><span>Pantalla:</span> $($M.Hz) Hz</div>
$(if ($M.GpuTemp -ne $null) { "<div><span>Temp. placa de video:</span> $($M.GpuTemp) C</div>" })
$(if ($M.ReBAR -ne $null) { "<div><span>Resizable BAR:</span> $(if ($M.ReBAR) { 'activado' } else { 'apagado' })</div>" })
</div><h2 style="margin-top:18px">Salud</h2><ul>$salud$bat</ul></section>
<section><h2>Recomendaciones</h2><ul>$rec</ul></section>
<section><h2>Programas que arrancan con Windows</h2><ul>$ini</ul></section>
<footer>Informe generado por Veltrix &middot; Instagram @veltrix.fps<br>Los valores pueden variar seg&uacute;n los programas abiertos en el momento de la medici&oacute;n.</footer>
</div></body></html>
"@
    $file = Join-Path (Get-Escritorio) ("Veltrix_" + $Etiqueta + "_" + (Get-Date -Format 'yyyy-MM-dd_HH-mm') + ".html")
    $html | Out-File -FilePath $file -Encoding UTF8
    if ($Abrir) { Start-Process $file }
    return $file
}
'@

$VX_DESPUES = @'
$ErrorActionPreference = 'SilentlyContinue'
$antes = $null
$fa = Join-Path $VXDIR 'antes.json'
if (Test-Path $fa) { $antes = Get-Content $fa -Raw | ConvertFrom-Json }
$m = Get-VxMetricas -EsperarArranque 240
Write-VxInforme -M $m -Antes $antes -Etiqueta 'DESPUES' -Abrir $false | Out-Null
$m | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $VXDIR 'despues.json') -Encoding UTF8
Unregister-ScheduledTask -TaskName 'Veltrix Despues' -Confirm:$false
'@

Invoke-Expression $VX_DIAG

# Modo automatico: informe DESPUES (lo lanza la tarea programada al iniciar sesion)
if ($env:VX_MODO -eq 'despues') {
    $env:VX_MODO = $null
    Invoke-Expression $VX_DESPUES
    return
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

function Test-AmdDobleCCD {
    # AMD pide plan Equilibrado + core parking en estos procesadores (si no, los juegos rinden menos)
    $n = "$((Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1).Name)"
    return ($n -match '7900X3D|7950X3D|9900X3D|9950X3D|7945HX3D|9955HX3D|9900X(?!3D)|9950X(?!3D)')
}

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
    # Letras siempre nitidas: suavizado de fuentes + ClearType forzados
    Set-Reg 'HKCU\Control Panel\Desktop' 'FontSmoothing' REG_SZ 2
    Set-Reg 'HKCU\Control Panel\Desktop' 'FontSmoothingType' REG_DWORD 2
    Set-Reg 'HKCU\Control Panel\Desktop' 'MenuShowDelay' REG_SZ 100
    Set-Reg 'HKCU\Control Panel\Desktop\WindowMetrics' 'MinAnimate' REG_SZ 0
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' REG_DWORD 0
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ListviewShadow' REG_DWORD 1
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' REG_DWORD 0
    Set-Reg 'HKCU\Software\Microsoft\Windows\DWM' 'EnableAeroPeek' REG_DWORD 0
    Listo 'Animaciones y transparencias fuera; letras nitidas (ClearType) y sombras de iconos se mantienen'
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
    Remove-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled'
    Remove-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled'
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' REG_DWORD 0
    Listo 'Sin anuncios, tips, widgets ni Bing en el menu Inicio'
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
    if (Test-AmdDobleCCD) {
        powercfg.exe -setactive SCHEME_BALANCED *> $null
        powercfg.exe -h off *> $null
        Listo 'Procesador AMD de doble CCD: se deja el plan Equilibrado, como exige AMD'
        Listo '(asi los juegos usan los nucleos correctos; con Maximo rendimiento rinden menos)'
        return
    }
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
    # HAGS: solo en placas donde mejora (RTX / GTX 16 / Radeon RX 6000+ / Intel Arc); en las viejas puede empeorar
    $gn = (@(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }) -join ' ')
    if ($gn -match 'RTX|GTX 16|RX [6-9]\d{3}|Arc') { Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' REG_DWORD 2 }
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
    if (-not $Laptop -and -not (Test-AmdDobleCCD)) {
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
    $dc = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' -ErrorAction SilentlyContinue).DisabledComponents
    if (-not $dc) { Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' 'DisabledComponents' REG_DWORD 32 }
    if (-not $Laptop) {
        foreach ($n in (Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up')) {
            Disable-NetAdapterPowerManagement -Name $n.Name -NoRestart -ErrorAction SilentlyContinue | Out-Null
            foreach ($k in $NIC_KEYS) {
                Set-NetAdapterAdvancedProperty -Name $n.Name -RegistryKeyword $k -RegistryValue 0 -NoRestart -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }
    Listo 'Nagle desactivado, IPv4 preferido, sin subidas ocultas de Windows Update, TCP sano'
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
    # Windows Update no reinicia la PC entre las 9:00 y las 3:00 (maximo que permite Windows)
    Set-Reg 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'SmartActiveHoursState' REG_DWORD 0
    Set-Reg 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'ActiveHoursStart' REG_DWORD 9
    Set-Reg 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'ActiveHoursEnd' REG_DWORD 3
    Listo 'NTFS sin escrituras extra, TRIM asegurado, servicios inutiles apagados'
    Listo 'Windows Update no te reinicia la PC entre las 9:00 y las 3:00'
    # Busqueda en modo Clasico: no indexa todo el disco (menos escrituras en el SSD y menos CPU)
    Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows Search' 'EnableFindMyFiles' REG_DWORD 0
    Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows Search\Gather\Windows\SystemIndex' 'EnableFindMyFiles' REG_DWORD 0
    # Utilidades: "Finalizar tarea" con clic derecho en la barra y extensiones de archivo visibles
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' 'TaskbarEndTask' REG_DWORD 1
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt' REG_DWORD 0
    Listo 'Busqueda de Windows en modo Clasico (sin indexar todo el disco)'
    Listo 'Clic derecho en la barra de tareas > Finalizar tarea (para juegos colgados)'
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
    if ((Get-VxDiscoSistema) -ne 'HDD') {
        Optimize-Volume -DriveLetter ($env:SystemDrive.Substring(0, 1)) -ReTrim -ErrorAction SilentlyContinue *> $null
        Listo 'TRIM aplicado al SSD (escrituras mas rapidas)'
    } else {
        Info 'Disco HDD: para desfragmentarlo usa "Optimizar discos" en el menu.'
    }
}

function Html-Texto {
    param($s)
    return ("$s" -replace '&aacute;', 'a' -replace '&eacute;', 'e' -replace '&iacute;', 'i' -replace '&oacute;', 'o' -replace '&uacute;', 'u' -replace '&Eacute;', 'E' -replace '&Iacute;', 'I' -replace '&iexcl;', '!' -replace '&gt;', '>' -replace '&lt;', '<' -replace '&amp;', '&' -replace '&quot;', '"' -replace '&ntilde;', 'n')
}

function M-InformeAntes {
    Paso 'Informe ANTES (queda en tu Escritorio)'
    New-Item -ItemType Directory -Path $VXDIR -Force -ErrorAction SilentlyContinue | Out-Null
    Info 'Midiendo el equipo...'
    $m = Get-VxMetricas
    $m | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $VXDIR 'antes.json') -Encoding UTF8
    $f = Write-VxInforme -M $m -Etiqueta 'ANTES'
    Listo ("Indice Veltrix ANTES: {0}/100   ({1})" -f $m.Indice, (Split-Path $f -Leaf))
}

function Find-Juegos {
    $l = @()
    $fijos = @(
        'C:\Riot Games\VALORANT\live\ShooterGame\Binaries\Win64\VALORANT-Win64-Shipping.exe',
        "$env:ProgramFiles\Riot Games\VALORANT\live\ShooterGame\Binaries\Win64\VALORANT-Win64-Shipping.exe",
        'C:\Riot Games\League of Legends\Game\League of Legends.exe',
        "$env:ProgramFiles\Epic Games\Fortnite\FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping.exe"
    )
    $l += @($fijos | Where-Object { Test-Path $_ })
    $l += @(Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions" -Recurse -Filter 'RobloxPlayerBeta.exe' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    # Epic Games
    foreach ($it in (Get-ChildItem "$env:ProgramData\Epic\EpicGamesLauncher\Data\Manifests" -Filter '*.item' -ErrorAction SilentlyContinue)) {
        try {
            $j = Get-Content $it.FullName -Raw | ConvertFrom-Json
            $p = Join-Path $j.InstallLocation $j.LaunchExecutable
            if (Test-Path $p) { $l += $p }
        } catch {}
    }
    # Steam (todas las bibliotecas)
    $sp = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if ($sp) {
        $libs = @($sp -replace '/', '\')
        $vdf = Join-Path $libs[0] 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            foreach ($mt in (Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' -ErrorAction SilentlyContinue)) { $libs += ($mt.Matches[0].Groups[1].Value -replace '\\\\', '\') }
        }
        $excluir = 'setup|unins|redist|crash|install|vc_|dotnet|directx|dxsetup|report|helper|server|editor|benchmark|easyanticheat|battleye|ue4prereq|launcher'
        foreach ($lib in ($libs | Sort-Object -Unique)) {
            foreach ($g in (Get-ChildItem (Join-Path $lib 'steamapps\common') -Directory -ErrorAction SilentlyContinue)) {
                $exes = @(Get-ChildItem $g.FullName -Recurse -Depth 4 -Filter '*.exe' -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch $excluir })
                $raiz = @($exes | Where-Object { $_.DirectoryName -eq $g.FullName })
                $grandes = @($exes | Where-Object { $_.Length -gt 15MB })
                $l += @(($raiz + $grandes) | ForEach-Object { $_.FullName })
            }
        }
    }
    return @($l | Sort-Object -Unique)
}

function M-GPU {
    Paso 'Juegos en la placa de video dedicada'
    $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch 'Remote|Virtual|Parsec|Meta|Microsoft Basic' })
    $ded = @($gpus | Where-Object { $_.Name -match 'NVIDIA|GeForce|Radeon RX|Radeon Pro|Arc\(TM\) A\d|Arc A\d' })
    if ($gpus.Count -lt 2 -or $ded.Count -eq 0) {
        Listo 'El equipo usa una sola placa de video: no hace falta'
        return
    }
    $clave = 'HKCU\Software\Microsoft\DirectX\UserGpuPreferences'
    $exist = Get-ItemProperty ('Registry::' + $clave) -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $VXDIR -Force -ErrorAction SilentlyContinue | Out-Null
    $reg = Join-Path $VXDIR 'gpu_juegos.txt'
    $n = 0
    foreach ($exe in (Find-Juegos)) {
        if ($exist -and $exist.$exe) { continue }
        Set-Reg $clave $exe REG_SZ 'GpuPreference=2;'
        Add-Content -Path $reg -Value $exe
        $n++
    }
    if ($n -gt 0) { Listo "$n juego(s) van a usar siempre la $($ded[0].Name) en vez del grafico integrado" }
    else { Listo 'No se encontraron juegos instalados para asignar' }
}

function M-ProgramarDespues {
    Paso 'Informe DESPUES automatico al reiniciar'
    try {
        $user = "$env:USERDOMAIN\$env:USERNAME"
        $arg = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command "$env:VX_MODO=''despues''; irm ''' + $URL + ''' | iex"'
        $act = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
        $trg = New-ScheduledTaskTrigger -AtLogOn -User $user
        $trg.Delay = 'PT90S'
        $pri = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
        $set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 20) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
        Register-ScheduledTask -TaskName 'Veltrix Despues' -Action $act -Trigger $trg -Principal $pri -Settings $set -Force -ErrorAction Stop | Out-Null
        Listo 'Despues de reiniciar, en 2 a 5 minutos aparece Veltrix_DESPUES en tu Escritorio'
    } catch {
        Aviso 'No se pudo programar: despues de reiniciar usa la opcion "Diagnostico" del menu.'
    }
}

function T-Diagnostico {
    Titulo 'DIAGNOSTICO E INDICE VELTRIX' 'Cyan'
    Info 'Midiendo el equipo... (unos segundos)'
    $a = $null
    $fa = Join-Path $VXDIR 'antes.json'
    if (Test-Path $fa) { $a = Get-Content $fa -Raw | ConvertFrom-Json }
    $m = Get-VxMetricas
    Write-VxInforme -M $m -Antes $a -Etiqueta 'DIAGNOSTICO' -Abrir $true | Out-Null
    Listo ("Indice Veltrix: {0}/100. El informe se abrio y quedo en tu Escritorio." -f $m.Indice)
    if ($a) { Info ("Antes de optimizar era {0}/100." -f $a.Indice) }
    Pausa
}

function T-Salud {
    Titulo 'CHEQUEO DE HARDWARE' 'Cyan'
    Info 'Analizando... (unos segundos)'
    $m = Get-VxMetricas
    Write-Host ''
    Write-Host ("   Indice Veltrix ....... {0}/100" -f $m.Indice) -ForegroundColor Cyan
    Write-Host "   Procesador ........... $($m.CPU)"
    Write-Host "   Placa de video ....... $($m.GPU)"
    Write-Host ("   RAM .................. {0} GB en {1} modulo(s), a {2} MHz (soporta {3} MHz)" -f $m.RamTotal, $m.RamModulos, $m.RamVel, $m.RamVelMax)
    Write-Host "   Disco de Windows ..... $($m.Disco), $($m.LibreGB) GB libres de $($m.TotalGB) GB"
    foreach ($s in $m.DiscosSalud) { Write-Host "   Salud de disco ....... $s" }
    if ($m.Bateria -ne $null) { Write-Host "   Bateria .............. conserva el $($m.Bateria)% de su capacidad original" }
    Write-Host "   Pantalla ............. $($m.Hz) Hz"
    if ($m.GpuTemp -ne $null) { Write-Host "   Temp. placa de video . $($m.GpuTemp) C" }
    if ($m.ReBAR -ne $null) { Write-Host ("   Resizable BAR ........ " + $(if ($m.ReBAR) { 'activado' } else { 'apagado' })) }
    if ($m.Arranque) { Write-Host "   Ultimo arranque ...... $($m.Arranque) segundos" }
    Write-Host ''
    Write-Host '   RECOMENDACIONES' -ForegroundColor DarkCyan
    foreach ($r in (Get-VxRecomendaciones $m)) { Write-Host ('   - ' + (Html-Texto $r)) }
    Pausa
}

function T-MPO {
    Titulo 'ARREGLAR PARPADEOS / PANTALLAZOS NEGROS (MPO)' 'Cyan'
    $k = 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm'
    $actual = (Get-ItemProperty $k -ErrorAction SilentlyContinue).OverlayTestMode
    if ($actual -eq 5) {
        Write-Host '  El arreglo de MPO ya esta aplicado en esta PC.'
        Write-Host ''
        if (Confirmar 'Quitarlo y volver a como viene Windows?') {
            Remove-Reg 'HKLM\SOFTWARE\Microsoft\Windows\Dwm' 'OverlayTestMode'
            Remove-Item (Join-Path $VXDIR 'mpo_desactivado.txt') -Force -ErrorAction SilentlyContinue
            Listo 'Listo. Reinicia para aplicar.'
        }
        Pausa; return
    }
    Write-Host '  Usalo SOLO si tenes alguno de estos problemas:'
    Write-Host '   - la pantalla parpadea o se pone negra un segundo'
    Write-Host '   - tirones en juegos con G-Sync/FreeSync o con dos monitores'
    Write-Host '   - parpadeos en Chrome/Discord mientras jugas'
    Write-Host ''
    Info 'Desactiva "Multiplane Overlay" (MPO), el mismo arreglo que publica NVIDIA.'
    Info 'Si no tenes esos problemas, no hace falta: dejalo como esta.'
    Write-Host ''
    if (-not (Confirmar 'Aplicar el arreglo?')) { return }
    New-Item -ItemType Directory -Path $VXDIR -Force -ErrorAction SilentlyContinue | Out-Null
    Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\Dwm' 'OverlayTestMode' REG_DWORD 5
    Set-Content -Path (Join-Path $VXDIR 'mpo_desactivado.txt') -Value 'veltrix'
    Listo 'Arreglo aplicado. Reinicia la PC. Si no cambia nada, volve a esta opcion y quitalo.'
    Pausa
}

function T-ModoPartida {
    $est = Join-Path $VXDIR 'partida.json'
    if (Test-Path $est) {
        Titulo 'MODO PARTIDA: ACTIVO' 'Green'
        if (-not (Confirmar 'Desactivar el Modo Partida y volver a la normalidad?')) { return }
        $s = Get-Content $est -Raw | ConvertFrom-Json
        if ($s.Plan) { powercfg.exe -setactive $s.Plan *> $null }
        foreach ($sv in @($s.Servicios)) { Start-Service $sv -ErrorAction SilentlyContinue }
        if ($s.OneDrive -and (Test-Path $s.OneDrive)) { Start-Process $s.OneDrive -ArgumentList '/background' -ErrorAction SilentlyContinue }
        Remove-Item $est -Force -ErrorAction SilentlyContinue
        Listo 'Modo Partida desactivado: todo volvio a la normalidad'
        Pausa; return
    }
    Titulo 'MODO PARTIDA (ANTES DE JUGAR)' 'Green'
    Write-Host '  Deja la PC enfocada en el juego mientras jugas:'
    Write-Host '   - energia al maximo (respetando AMD de doble CCD)'
    Write-Host '   - pausa indexado de busqueda, SysMain, descargas de Windows Update y OneDrive'
    Write-Host '   - limpia la cache DNS y te deja cerrar lo que mas RAM consume'
    Write-Host ''
    Write-Host '  Compatible con Vanguard (VALORANT), FACEIT, Easy Anti-Cheat y BattlEye:' -ForegroundColor Cyan
    Write-Host '  no toca juegos, procesos de juegos ni la seguridad de Windows.' -ForegroundColor Cyan
    Info 'Al terminar de jugar, volve a esta opcion para desactivarlo (o reinicia la PC).'
    Write-Host ''
    if (-not (Confirmar 'Activar Modo Partida?')) { return }
    New-Item -ItemType Directory -Path $VXDIR -Force -ErrorAction SilentlyContinue | Out-Null
    $plan = ''
    if ((powercfg.exe /getactivescheme) -match '([0-9a-fA-F-]{36})') { $plan = $Matches[1] }
    if (-not (Test-AmdDobleCCD)) {
        powercfg.exe -setactive $PLAN_VELTRIX *> $null
        if ($LASTEXITCODE -ne 0) { powercfg.exe -setactive SCHEME_MIN *> $null }
        Listo 'Energia al maximo'
    } else { Listo 'AMD de doble CCD: se mantiene Equilibrado (es lo que mas rinde en tu procesador)' }
    $parados = @()
    foreach ($sv in 'WSearch', 'SysMain', 'wuauserv', 'BITS', 'DoSvc') {
        $o = Get-Service $sv -ErrorAction SilentlyContinue
        if ($o -and "$($o.Status)" -eq 'Running') { Stop-Service $sv -Force -ErrorAction SilentlyContinue; $parados += $sv }
    }
    Listo "Pausados: indexado, SysMain y descargas de Windows Update ($($parados.Count) servicios)"
    $od = $null
    $p = Get-Process OneDrive -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($p) { $od = $p.Path; Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue; Listo 'OneDrive en pausa (se reanuda al desactivar)' }
    ipconfig.exe /flushdns *> $null
    Set-Reg 'HKCU\Software\Microsoft\GameBar' 'AutoGameModeEnabled' REG_DWORD 1
    @{ Plan = $plan; Servicios = $parados; OneDrive = $od } | ConvertTo-Json | Set-Content $est -Encoding UTF8
    Listo 'Cache DNS limpia y Modo juego de Windows activado'
    Write-Host ''
    Write-Host '  MODO PARTIDA ACTIVADO' -ForegroundColor Green
    Write-Host ''
    if (Confirmar 'Ver los programas que mas RAM usan para cerrarlos (Game Booster)?') { T-Booster }
}

function T-Discos {
    Titulo 'OPTIMIZAR DISCOS' 'Cyan'
    Write-Host '  SSD: aplica TRIM para que siga rapido (unos segundos).'
    Write-Host '  HDD: desfragmenta si hace falta (puede tardar bastante).'
    Write-Host ''
    if (-not (Confirmar 'Empezar?')) { return }
    foreach ($v in (Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -and "$($_.DriveType)" -eq 'Fixed' -and $_.FileSystem -eq 'NTFS' })) {
        $tipo = 'SSD'
        try {
            $num = (Get-Partition -DriveLetter $v.DriveLetter -ErrorAction Stop).DiskNumber
            $tipo = "$((Get-PhysicalDisk | Where-Object { "$($_.DeviceId)" -eq "$num" } | Select-Object -First 1).MediaType)"
        } catch {}
        Paso "Unidad $($v.DriveLetter): ($tipo)"
        if ($tipo -eq 'HDD') { Optimize-Volume -DriveLetter $v.DriveLetter -Defrag -Verbose -ErrorAction SilentlyContinue }
        else { Optimize-Volume -DriveLetter $v.DriveLetter -ReTrim -ErrorAction SilentlyContinue }
        Listo 'Listo'
    }
    Pausa
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
    Titulo 'MODO COMPETITIVO EXTREMO' 'Magenta'
    $ac = @(Get-VxAnticheat)
    if ($ac.Count -gt 0) {
        Write-Host "  Esta PC tiene $($ac -join ' y ')." -ForegroundColor Yellow
        Write-Host '  Estos anticheats necesitan las protecciones de Windows que este modo apaga,'
        Write-Host '  asi que Veltrix NO lo aplica para que tus juegos sigan funcionando.'
        Write-Host ''
        Write-Host '  Para jugar competitivo usa el MODO PARTIDA (opcion 9): es 100% compatible.' -ForegroundColor Green
        Pausa; return
    }
    Write-Host '  Desactiva la "Integridad de memoria" (HVCI) y, si no la usas, la'
    Write-Host '  "Plataforma de maquina virtual". Microsoft mismo indica que estas dos'
    Write-Host '  funciones pueden bajar el rendimiento en juegos. En muchas PCs da 5-10% mas FPS.'
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
    Listo 'Integridad de memoria desactivada'
    # Plataforma de maquina virtual: Microsoft recomienda apagarla para jugar, solo si no se usa
    $vmp = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue
    $usa = (Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' -ErrorAction SilentlyContinue) -or
           (Get-AppxPackage -Name '*WindowsSubsystemForAndroid*' -ErrorAction SilentlyContinue) -or
           (Test-Path "$env:ProgramFiles\BlueStacks_nxt") -or (Test-Path "$env:ProgramFiles\Docker") -or
           ((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue).State -eq 'Enabled')
    if ($vmp -and "$($vmp.State)" -eq 'Enabled') {
        if ($usa) { Info 'Plataforma de maquina virtual: se deja activada porque la usa WSL, Android, BlueStacks, Docker o Hyper-V.' }
        else {
            Disable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -ErrorAction SilentlyContinue | Out-Null
            Set-Content -Path (Join-Path $BACKUP_DIR 'vmp_desactivada.txt') -Value 'veltrix'
            Listo 'Plataforma de maquina virtual desactivada (no se estaba usando)'
        }
    }
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

    Paso 'Extras de Veltrix'
    if ((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' -ErrorAction SilentlyContinue).DisabledComponents -eq 32) { Remove-Reg 'HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' 'DisabledComponents' }
    Remove-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' 'TaskbarEndTask'
    Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt' REG_DWORD 1
    if (Test-Path (Join-Path $VXDIR 'mpo_desactivado.txt')) { Remove-Reg 'HKLM\SOFTWARE\Microsoft\Windows\Dwm' 'OverlayTestMode'; Remove-Item (Join-Path $VXDIR 'mpo_desactivado.txt') -Force }
    if (Test-Path (Join-Path $VXDIR 'vmp_desactivada.txt')) {
        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -ErrorAction SilentlyContinue | Out-Null
        Remove-Item (Join-Path $VXDIR 'vmp_desactivada.txt') -Force
    }
    foreach ($v in 'SmartActiveHoursState', 'ActiveHoursStart', 'ActiveHoursEnd') { Remove-Reg 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' $v }
    $gf = Join-Path $VXDIR 'gpu_juegos.txt'
    if (Test-Path $gf) {
        foreach ($e in (Get-Content $gf)) { if ($e) { Remove-Reg 'HKCU\Software\Microsoft\DirectX\UserGpuPreferences' $e } }
        Remove-Item $gf -Force -ErrorAction SilentlyContinue
    }
    Unregister-ScheduledTask -TaskName 'Veltrix Despues' -Confirm:$false -ErrorAction SilentlyContinue

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
    Write-Host '   - Informe ANTES con Indice Veltrix en tu Escritorio'
    Write-Host '   - Punto de restauracion de seguridad'
    Write-Host '   - Efectos visuales, publicidad y procesos en segundo plano'
    Write-Host '   - Telemetria y privacidad'
    Write-Host '   - Energia, juegos, placa de video dedicada y latencia'
    Write-Host '   - Red, disco, memoria, servicios y Windows Update'
    Write-Host '   - Limpieza de archivos basura y TRIM del SSD'
    Write-Host '   - Informe DESPUES automatico al reiniciar'
    Write-Host ''
    if ($Laptop) { Aviso 'Conecta el cargador y cerra los programas abiertos.' }
    else { Aviso 'Cerra los programas abiertos.' }
    Write-Host ''
    if (-not (Confirmar 'Empezar?')) { return }

    $t0 = Get-Date
    $libre0 = Libre-GB
    $global:VxStep = 0
    $global:VxTotal = 13

    M-InformeAntes
    M-Restauracion
    M-Visual
    M-SegundoPlano
    M-Telemetria
    if ($Laptop) { M-EnergiaLaptop } else { M-EnergiaPC }
    M-Juegos
    M-GPU
    M-Latencia -Laptop $Laptop
    M-Red -Laptop $Laptop
    M-Avanzado
    M-Limpieza
    M-ProgramarDespues

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
    Info 'En tu Escritorio quedo el informe ANTES. Al reiniciar, en unos minutos'
    Info 'aparece el informe DESPUES con la comparacion.'
    Info 'Para ir mas alla: Programas de inicio, Apps basura, DNS y Game Booster.'
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
    Write-Host '   ANALISIS' -ForegroundColor DarkCyan
    Write-Host '    [3]  Diagnostico + Indice Veltrix (informe en el Escritorio)' -ForegroundColor White
    Write-Host '    [4]  Chequeo de hardware (bateria, discos, RAM, pantalla)' -ForegroundColor White
    Write-Host ''
    Write-Host '   HERRAMIENTAS' -ForegroundColor DarkCyan
    Write-Host '    [5]  Limpieza profunda (te dice cuantos GB liberaste)' -ForegroundColor White
    Write-Host '    [6]  Programas que arrancan con Windows' -ForegroundColor White
    Write-Host '    [7]  Quitar apps basura preinstaladas' -ForegroundColor White
    Write-Host '    [8]  DNS mas rapido (test automatico)' -ForegroundColor White
    Write-Host '    [9]  MODO PARTIDA antes de jugar (compatible Valorant/FACEIT)' -ForegroundColor Green
    Write-Host '   [10]  Optimizar discos (TRIM / desfragmentar)' -ForegroundColor White
    Write-Host '   [11]  Actualizar todos los programas' -ForegroundColor White
    Write-Host '   [12]  Reparar Windows (archivos danados)' -ForegroundColor White
    Write-Host '   [13]  Arreglar parpadeos / pantallazos negros (MPO)' -ForegroundColor White
    Write-Host ''
    Write-Host '   EXTRAS' -ForegroundColor DarkCyan
    Write-Host '   [14]  Modo competitivo extremo (NO para Valorant/FACEIT)' -ForegroundColor Magenta
    Write-Host '   [15]  Revertir todos los cambios' -ForegroundColor Yellow
    Write-Host '    [0]  Salir' -ForegroundColor DarkGray
    Write-Host ''
    $op = "$(Read-Host '  Elegi una opcion')".Trim()
    switch ($op) {
        '1'  { Optimizar -Laptop $false }
        '2'  { Optimizar -Laptop $true }
        '3'  { T-Diagnostico }
        '4'  { T-Salud }
        '5'  { T-LimpiezaProfunda }
        '6'  { T-Inicio }
        '7'  { T-Bloat }
        '8'  { T-DNS }
        '9'  { T-ModoPartida }
        '10' { T-Discos }
        '11' { T-Actualizar }
        '12' { T-Reparar }
        '13' { T-MPO }
        '14' { M-Competitivo }
        '15' { M-Revertir }
        '0'  { return }
    }
}

}

Invoke-Veltrix
