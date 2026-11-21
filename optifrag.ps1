# =====================================================================
#  OPTIFRAG - Optimizador de Windows con interfaz grafica
#  Uso (PowerShell):  irm https://raw.githubusercontent.com/JuaniUTU2009/veltrix/main/optifrag.ps1 | iex
#  Instagram: @optifrag
# =====================================================================

$VX_DIAG = @'
$VXDIR = Join-Path $env:ProgramData 'OptiFrag'

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
    if ($m.Inicio -gt 6) { $r += "Arrancan $($m.Inicio) programas con Windows. Desde OptiFrag &gt; Programas de inicio se pueden apagar los que no uses." }
    if ($m.UptimeDias -ge 7) { $r += 'Hace m&aacute;s de una semana que no se reinicia. Reiniciar seguido mantiene Windows fluido.' }
    if ($m.HVCI) { $r += 'La Integridad de memoria est&aacute; activa. En PCs de juego, el Modo competitivo de OptiFrag puede dar algunos FPS extra.' }
    if ($m.ReBAR -eq $false -and $m.GPU -match 'RTX [3-9]0\d\d') { $r += 'Resizable BAR est&aacute; apagado. Si la placa madre lo soporta, activarlo en la BIOS (Above 4G Decoding + Resizable BAR) puede dar FPS extra.' }
    if ($m.GpuTemp -ne $null -and $m.GpuTemp -ge 85) { $r += "La placa de video est&aacute; a $($m.GpuTemp) C: conviene una limpieza interna y cambio de pasta t&eacute;rmica." }
    if ($m.Laptop -and $m.GPU -match 'NVIDIA|GeForce|Radeon RX') {
        $app = switch -Regex ($m.Fabricante) { 'ASUS' { 'Armoury Crate' } 'LENOVO' { 'Legion Space / Lenovo Vantage' } 'HP' { 'OMEN Gaming Hub' } 'Micro-Star|MSI' { 'MSI Center' } 'Acer' { 'NitroSense / PredatorSense' } 'Dell|Alienware' { 'Alienware Command Center' } default { 'la app del fabricante' } }
        $r += "Laptop gamer: para jugar, en $app pon&eacute; el modo Turbo/Rendimiento y, si existe, el modo de GPU dedicada (MUX). Puede dar mucho m&aacute;s FPS."
    }
    if ($m.Juegos -contains 'VALORANT') { $r += 'VALORANT: pantalla completa, NVIDIA Reflex en &quot;Activado&quot; (el modo + Boost a veces baja FPS), Raw Input Buffer activado, Renderizado multihilo activado y sombras en bajo.' }
    if ($m.Juegos -contains 'CS2') { $r += 'CS2: pantalla completa, NVIDIA Reflex activado, &quot;Aumentar contraste de jugadores&quot; activado y V-Sync apagado. Un l&iacute;mite de FPS estable (fps_max) reduce los tirones.' }
    if ($m.Juegos -contains 'Fortnite') { $r += 'Fortnite: en PCs de pocos recursos us&aacute; el modo de renderizado &quot;Rendimiento&quot;; con buena placa, DirectX 12. NVIDIA Reflex activado y V-Sync apagado.' }
    if ($m.Juegos.Count -gt 0) { $r += 'Antes de jugar competitivo, us&aacute; el Modo Partida de OptiFrag: es compatible con Vanguard y FACEIT.' }
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
            @('&Iacute;ndice OptiFrag', $Antes.Indice, $M.Indice, 'mas', ''),
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
<!doctype html><html lang="es"><head><meta charset="utf-8"><title>OptiFrag - $Etiqueta</title>
<style>
body{margin:0;background:#1A0A06;color:#fff;font-family:'Segoe UI',Inter,Arial,sans-serif}
.wrap{max-width:880px;margin:0 auto;padding:40px 28px 60px}
header{display:flex;justify-content:space-between;align-items:center}
.logo{font-weight:900;font-size:30px;letter-spacing:2px;color:#FF5A36}
.muted{color:#B9A8B2}
h1{font-size:40px;margin:28px 0 6px}
h2{font-size:24px;margin:0 0 8px;color:#FF5A36}
section{background:#1C1219;border:1px solid #3D2230;border-radius:22px;padding:24px 26px;margin-top:22px}
.score{display:flex;gap:30px;align-items:center}
.ring{width:170px;height:170px;border-radius:50%;background:conic-gradient($col ${deg}deg,#3D2230 0);display:flex;align-items:center;justify-content:center;flex-shrink:0}
.ring div{width:132px;height:132px;border-radius:50%;background:#1C1219;display:flex;flex-direction:column;align-items:center;justify-content:center}
.ring b{font-size:54px;color:$col;line-height:1}
.ring span{font-size:13px;color:#B9A8B2}
.delta{margin-top:10px;font-size:20px;font-weight:700}.delta span{color:#22E58B}
table{width:100%;border-collapse:collapse;font-size:17px}
td,th{padding:11px 8px;border-bottom:1px solid #3D2230;text-align:left}th{color:#B9A8B2;font-weight:600}
.mejor{color:#22E58B;font-weight:700}.peor{color:#FFB020}.igual{color:#B9A8B2}
ul{margin:6px 0 0;padding-left:22px;line-height:1.6}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:6px 24px;font-size:16px}
.grid div span{color:#B9A8B2}
footer{margin-top:30px;color:#B9A8B2;font-size:13px;line-height:1.5}
</style></head><body><div class="wrap">
<header><div class="logo">&#127919; OPTI<span style="color:#FFFFFF">FRAG</span></div><div class="muted">$($M.Fecha) &middot; $(Esc $M.Equipo)</div></header>
<h1>$titulo</h1>
<section class="score"><div class="ring"><div><b>$($M.Indice)</b><span>de 100</span></div></div>
<div><h2>&Iacute;ndice OptiFrag</h2><div class="muted">Resume la carga del sistema (RAM, procesos, programas de inicio), la basura acumulada, el espacio libre y el tipo de disco.</div>$delta</div></section>
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
<footer>Informe generado por OptiFrag &middot; Instagram @optifrag<br>Los valores pueden variar seg&uacute;n los programas abiertos en el momento de la medici&oacute;n.</footer>
</div></body></html>
"@
    $file = Join-Path (Get-Escritorio) ("OptiFrag_" + $Etiqueta + "_" + (Get-Date -Format 'yyyy-MM-dd_HH-mm') + ".html")
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
Unregister-ScheduledTask -TaskName 'OptiFrag Despues' -Confirm:$false
'@

$VX_CORE = @'
$URL = 'https://raw.githubusercontent.com/JuaniUTU2009/veltrix/main/optifrag.ps1'
$VER = '1.1'
$PLAN_OPTIFRAG = '0f7a6f00-0000-4000-8000-00000000f7a6'
$CDM = 'HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
$CDM_VALS = 'SilentInstalledAppsEnabled', 'SystemPaneSuggestionsEnabled', 'SoftLandingEnabled', 'PreInstalledAppsEnabled', 'OemPreInstalledAppsEnabled', 'RotatingLockScreenOverlayEnabled', 'SubscribedContent-310093Enabled', 'SubscribedContent-338387Enabled', 'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled', 'SubscribedContent-338393Enabled', 'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled', 'SubscribedContent-353698Enabled'
$TAREAS = '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser', '\Microsoft\Windows\Application Experience\ProgramDataUpdater', '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator', '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip', '\Microsoft\Windows\Autochk\Proxy'
$MM = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
$NIC_KEYS = '*EEE', '*InterruptModeration', 'AdvancedEEE', 'EnableGreenEthernet', 'PowerSavingMode', 'GigaLite'
$IFACES = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
$HVCI = 'HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'
$BACKUP_DIR = Join-Path $env:ProgramData 'OptiFrag'

function Set-Reg    { param($Path, $Name, $Type, $Data) reg.exe add $Path /v $Name /t $Type /d $Data /f *> $null }

function Remove-Reg { param($Path, $Name) reg.exe delete $Path /v $Name /f *> $null }

function Libre-GB { $d = Get-PSDrive -Name ($env:SystemDrive -replace ':', '') -ErrorAction SilentlyContinue; if ($d) { return $d.Free / 1GB } else { return 0 } }

function Test-AmdDobleCCD {
    # AMD pide plan Equilibrado + core parking en estos procesadores (si no, los juegos rinden menos)
    $n = "$((Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1).Name)"
    return ($n -match '7900X3D|7950X3D|9900X3D|9950X3D|7945HX3D|9955HX3D|9900X(?!3D)|9950X(?!3D)')
}

function Html-Texto {
    param($s)
    return ("$s" -replace '&aacute;', 'a' -replace '&eacute;', 'e' -replace '&iacute;', 'i' -replace '&oacute;', 'o' -replace '&uacute;', 'u' -replace '&Eacute;', 'E' -replace '&Iacute;', 'I' -replace '&iexcl;', '!' -replace '&gt;', '>' -replace '&lt;', '<' -replace '&amp;', '&' -replace '&quot;', '"' -replace '&ntilde;', 'n')
}

function M-Restauracion {
    Paso 'Punto de restauracion de seguridad'
    Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' 'SystemRestorePointCreationFrequency' REG_DWORD 0
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
        Checkpoint-Computer -Description 'OptiFrag - antes de optimizar' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
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
    powercfg.exe -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 $PLAN_OPTIFRAG *> $null
    powercfg.exe -changename $PLAN_OPTIFRAG 'OptiFrag Rendimiento' *> $null
    powercfg.exe -setactive $PLAN_OPTIFRAG *> $null
    if ($LASTEXITCODE -ne 0) { powercfg.exe -setactive SCHEME_MIN *> $null }
    powercfg.exe -h off *> $null
    Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' REG_DWORD 1
    Listo 'Plan "OptiFrag Rendimiento", sin hibernacion ni limites de CPU'
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

function M-InformeAntes {
    Paso 'Informe ANTES (queda en tu Escritorio)'
    New-Item -ItemType Directory -Path $VXDIR -Force -ErrorAction SilentlyContinue | Out-Null
    Info 'Midiendo el equipo...'
    $m = Get-VxMetricas
    $m | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $VXDIR 'antes.json') -Encoding UTF8
    $f = Write-VxInforme -M $m -Etiqueta 'ANTES'
    Listo ("Indice OptiFrag ANTES: {0}/100   ({1})" -f $m.Indice, (Split-Path $f -Leaf))
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
        Register-ScheduledTask -TaskName 'OptiFrag Despues' -Action $act -Trigger $trg -Principal $pri -Settings $set -Force -ErrorAction Stop | Out-Null
        Listo 'Despues de reiniciar, en 2 a 5 minutos aparece OptiFrag_DESPUES en tu Escritorio'
    } catch {
        Aviso 'No se pudo programar: despues de reiniciar usa la opcion "Diagnostico" del menu.'
    }
}


function Job-Revertir {

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
    powercfg.exe -delete $PLAN_OPTIFRAG *> $null
    powercfg.exe -restoredefaultschemes *> $null
    powercfg.exe -h on *> $null
    Remove-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff'
    Remove-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled'
    Remove-Reg 'HKCU\Software\Microsoft\Lighting' 'AmbientLightingEnabled'
    Remove-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata' 'PreventDeviceMetadataFromNetwork'
    Remove-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager' 'DisableWpbtExecution'
    Remove-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' 'POWERSHELL_TELEMETRY_OPTOUT'

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

    Paso 'Extras de OptiFrag'
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
    Unregister-ScheduledTask -TaskName 'OptiFrag Despues' -Confirm:$false -ErrorAction SilentlyContinue

    $bk = Join-Path $BACKUP_DIR 'hvci_backup.reg'
    if (Test-Path $bk) {
        Paso 'Integridad de memoria'
        Remove-Reg $HVCI 'Enabled'
        reg.exe import $bk *> $null
        Remove-Item $bk -Force -ErrorAction SilentlyContinue
    }

    Listo 'Todo revertido'
}


# ---------------------------------------------------------------- registro de actividad
function VxLog {
    param($t, $k = 'info')
    if ($global:VxSync) { $global:VxSync.Log.Enqueue(@($k, "$t")) } else { Write-Host $t }
}
function Paso {
    param($t)
    if ($global:VxTotal -gt 0) {
        $global:VxStep++
        if ($global:VxSync) { $global:VxSync.Progress = [int](100 * ($global:VxStep - 1) / $global:VxTotal) }
        VxLog ("[{0}/{1}] {2}" -f $global:VxStep, $global:VxTotal, $t) 'step'
    } else { VxLog $t 'step' }
}
function Listo { param($t) VxLog $t 'ok' }
function Aviso { param($t) $global:VxUltimoAviso = $t; VxLog $t 'warn' }
function Info  { param($t) VxLog $t 'info' }
function Get-RegVal {
    param($Path, $Name)
    try { return (Get-ItemProperty ('Registry::' + $Path) -Name $Name -ErrorAction Stop).$Name } catch { return $null }
}

# ---------------------------------------------------------------- optimizacion completa
function Job-Optimizar {
    param([bool]$Laptop, [string[]]$Modulos)
    $global:VxStep = 0
    $global:VxTotal = $Modulos.Count
    $t0 = Get-Date
    $libre0 = Libre-GB
    foreach ($mo in $Modulos) {
        switch ($mo) {
            'antes'      { M-InformeAntes }
            'restaurar'  { M-Restauracion }
            'visual'     { M-Visual }
            'fondo'      { M-SegundoPlano }
            'telemetria' { M-Telemetria }
            'energia'    { if ($Laptop) { M-EnergiaLaptop } else { M-EnergiaPC } }
            'juegos'     { M-Juegos }
            'gpu'        { M-GPU }
            'latencia'   { M-Latencia -Laptop $Laptop }
            'red'        { M-Red -Laptop $Laptop }
            'avanzado'   { M-Avanzado }
            'limpieza'   { M-Limpieza }
            'despues'    { M-ProgramarDespues }
        }
    }
    $global:VxTotal = 0
    if ($global:VxSync) { $global:VxSync.Progress = 100 }
    $dur = (Get-Date) - $t0
    $lib = (Libre-GB) - $libre0
    if ($lib -lt 0) { $lib = 0 }
    Listo ("OPTIMIZACION COMPLETA en {0} min {1} s. Espacio liberado: {2:N2} GB" -f ($dur.Hours * 60 + $dur.Minutes), $dur.Seconds, $lib)
    return @{ Minutos = ($dur.Hours * 60 + $dur.Minutes); GB = [math]::Round($lib, 2) }
}

# ---------------------------------------------------------------- limpieza profunda
function Job-LimpiezaProfunda {
    param([bool]$Papelera)
    $antes = Libre-GB
    Paso 'Temporales de Windows y del usuario'
    Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Paso 'Cache de Windows Update y de Optimizacion de distribucion'
    Stop-Service wuauserv, bits -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service bits, wuauserv -ErrorAction SilentlyContinue
    Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue
    Paso 'Reportes de errores y volcados de memoria'
    Remove-Item "$env:ProgramData\Microsoft\Windows\WER\ReportArchive\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:ProgramData\Microsoft\Windows\WER\ReportQueue\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:LOCALAPPDATA\CrashDumps\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\Minidump\*" -Force -ErrorAction SilentlyContinue
    Paso 'Cache de navegadores y Discord (solo cache, no sesiones ni contrasenas)'
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
        if (Get-Process -Name $a.P -ErrorAction SilentlyContinue) { Aviso "$($a.N) esta abierto: se saltea (cerralo y volve a limpiar)"; continue }
        foreach ($sub in 'Cache', 'Code Cache', 'GPUCache', 'cache2', 'Service Worker\CacheStorage') {
            Get-ChildItem $a.D -Directory -Recurse -Depth 3 -Filter ($sub -replace '^.*\\', '') -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -like "*\$sub" } |
                ForEach-Object { Remove-Item "$($_.FullName)\*" -Recurse -Force -ErrorAction SilentlyContinue }
        }
        Listo "$($a.N) limpio"
    }
    if ($Papelera) {
        Paso 'Papelera de reciclaje'
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    }
    $lib = (Libre-GB) - $antes
    if ($lib -lt 0) { $lib = 0 }
    Listo ("Limpieza terminada: liberaste {0:N2} GB" -f $lib)
    return [math]::Round($lib, 2)
}

# ---------------------------------------------------------------- programas de inicio
function Set-InicioEstado {
    param($Ap, $Nombre, [bool]$Activo)
    $val = if ($Activo) { '020000000000000000000000' } else { '030000000000000000000000' }
    Set-Reg $Ap $Nombre REG_BINARY $val
}

# ---------------------------------------------------------------- apps basura
$VX_BLOAT = 'Microsoft.BingNews', 'Microsoft.BingSearch', 'Microsoft.GetHelp', 'Microsoft.Getstarted', 'Microsoft.MicrosoftSolitaireCollection',
    'Microsoft.People', 'Microsoft.WindowsFeedbackHub', 'Microsoft.MicrosoftOfficeHub', 'Microsoft.SkypeApp', 'Microsoft.Todos',
    'Clipchamp.Clipchamp', 'Microsoft.549981C3F5F10', 'Microsoft.WindowsMaps', 'Microsoft.MixedReality.Portal', 'Microsoft.3DBuilder',
    'Microsoft.Microsoft3DViewer', 'Microsoft.Print3D', 'Microsoft.OneConnect', 'Microsoft.Messaging', 'Microsoft.ZuneVideo',
    'Microsoft.PowerAutomateDesktop', 'MicrosoftTeams', 'Microsoft.MicrosoftJournal', '*CandyCrush*', '*king.com*', '*Disney*',
    '*TikTok*', '*Facebook*', '*AmazonPrime*', '*BubbleWitch*', '*MarchofEmpires*', '*HiddenCity*', '*Dolby*Access*'
function Get-Bloat {
    $l = @()
    foreach ($p in $VX_BLOAT) { $l += @(Get-AppxPackage -Name $p -ErrorAction SilentlyContinue) }
    return @($l | Sort-Object Name -Unique | ForEach-Object { [pscustomobject]@{ Nombre = $_.Name; Full = $_.PackageFullName } })
}
function Remove-Bloat {
    param([string[]]$Full)
    foreach ($f in $Full) {
        Remove-AppxPackage -Package $f -ErrorAction SilentlyContinue
        if ($?) { Listo "Quitada: $($f -replace '_.*$', '')" } else { Aviso "No se pudo quitar: $($f -replace '_.*$', '')" }
    }
}

# ---------------------------------------------------------------- DNS
function Test-DNSOptiFrag {
    $actual = (Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddresses } | Select-Object -First 1).ServerAddresses
    $cands = @(
        @{ N = 'Actual (tu proveedor)'; A = @($actual) },
        @{ N = 'Cloudflare'; A = @('1.1.1.1', '1.0.0.1') },
        @{ N = 'Google'; A = @('8.8.8.8', '8.8.4.4') },
        @{ N = 'Quad9'; A = @('9.9.9.9', '149.112.112.112') }
    )
    $dominios = 'google.com', 'youtube.com', 'riotgames.com', 'steampowered.com', 'epicgames.com', 'discord.com', 'instagram.com', 'microsoft.com'
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
            $res += [pscustomobject]@{ N = $c.N; A = $c.A; Ms = [math]::Round($tot / $ok) }
            VxLog ("{0}: {1} ms" -f $c.N, [math]::Round($tot / $ok)) 'info'
        }
    }
    return @($res | Sort-Object Ms)
}
function Set-DNSOptiFrag {
    param([string[]]$Direcciones)
    foreach ($n in (Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up')) {
        if ($Direcciones) { Set-DnsClientServerAddress -InterfaceIndex $n.ifIndex -ServerAddresses $Direcciones -ErrorAction SilentlyContinue }
        else { Set-DnsClientServerAddress -InterfaceIndex $n.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue }
    }
    Clear-DnsClientCache -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------- game booster
$VX_SISTEMA = 'System', 'Idle', 'Registry', 'Memory Compression', 'smss', 'csrss', 'wininit', 'winlogon', 'services', 'lsass', 'svchost',
    'dwm', 'explorer', 'fontdrvhost', 'sihost', 'ctfmon', 'conhost', 'OpenConsole', 'WindowsTerminal', 'powershell', 'pwsh', 'audiodg',
    'MsMpEng', 'NisSrv', 'SecurityHealthService', 'SecurityHealthSystray', 'StartMenuExperienceHost', 'ShellExperienceHost', 'SearchHost',
    'TextInputHost', 'RuntimeBroker', 'dllhost', 'taskhostw', 'spoolsv', 'WmiPrvSE', 'LsaIso', 'NVDisplay.Container', 'atiesrxx', 'atieclxx',
    'RtkAudUService64', 'igfxEM', 'vgc', 'vgtray', 'Claude', 'MpDefenderCoreService', 'SgrmBroker', 'WUDFHost', 'dasHost', 'unsecapp',
    'FACEIT', 'faceitservice', 'EasyAntiCheat', 'EasyAntiCheat_EOS', 'BEService', 'Secure System', 'Interrupts', 'smartscreen'
function Get-TopProcesos {
    return @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $VX_SISTEMA -notcontains $_.ProcessName } |
        Group-Object ProcessName | ForEach-Object {
            [pscustomobject]@{ Nombre = $_.Name; MB = [math]::Round((($_.Group | Measure-Object WorkingSet64 -Sum).Sum / 1MB)); Cant = $_.Count }
        } | Sort-Object MB -Descending | Select-Object -First 15)
}
function Stop-Procesos {
    param([string[]]$Nombres)
    foreach ($n in $Nombres) { Stop-Process -Name $n -Force -ErrorAction SilentlyContinue; Listo "Cerrado: $n" }
}

# ---------------------------------------------------------------- modo partida
function Test-Partida { return (Test-Path (Join-Path $VXDIR 'partida.json')) }
function Partida-On {
    New-Item -ItemType Directory -Path $VXDIR -Force -ErrorAction SilentlyContinue | Out-Null
    $plan = ''
    if ((powercfg.exe /getactivescheme) -match '([0-9a-fA-F-]{36})') { $plan = $Matches[1] }
    if (-not (Test-AmdDobleCCD)) {
        powercfg.exe -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 $PLAN_OPTIFRAG *> $null
        powercfg.exe -setactive $PLAN_OPTIFRAG *> $null
        if ($LASTEXITCODE -ne 0) { powercfg.exe -setactive SCHEME_MIN *> $null }
        Listo 'Energia al maximo'
    } else { Listo 'AMD de doble CCD: se mantiene Equilibrado (es lo que mas rinde en ese procesador)' }
    $parados = @()
    foreach ($sv in 'WSearch', 'SysMain', 'wuauserv', 'BITS', 'DoSvc') {
        $o = Get-Service $sv -ErrorAction SilentlyContinue
        if ($o -and "$($o.Status)" -eq 'Running') { Stop-Service $sv -Force -ErrorAction SilentlyContinue; $parados += $sv }
    }
    Listo "Pausados: indexado, SysMain y descargas de Windows Update ($($parados.Count) servicios)"
    $od = $null
    $p = Get-Process OneDrive -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($p) { $od = $p.Path; Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue; Listo 'OneDrive en pausa' }
    ipconfig.exe /flushdns *> $null
    Set-Reg 'HKCU\Software\Microsoft\GameBar' 'AutoGameModeEnabled' REG_DWORD 1
    @{ Plan = $plan; Servicios = $parados; OneDrive = $od } | ConvertTo-Json | Set-Content (Join-Path $VXDIR 'partida.json') -Encoding UTF8
    Listo 'MODO PARTIDA ACTIVADO (compatible con Vanguard, FACEIT, EAC y BattlEye)'
}
function Partida-Off {
    $est = Join-Path $VXDIR 'partida.json'
    if (-not (Test-Path $est)) { return }
    $s = Get-Content $est -Raw | ConvertFrom-Json
    if ($s.Plan) { powercfg.exe -setactive $s.Plan *> $null }
    foreach ($sv in @($s.Servicios)) { if ($sv) { Start-Service $sv -ErrorAction SilentlyContinue } }
    if ($s.OneDrive -and (Test-Path $s.OneDrive)) { Start-Process $s.OneDrive -ArgumentList '/background' -ErrorAction SilentlyContinue }
    Remove-Item $est -Force -ErrorAction SilentlyContinue
    Listo 'Modo Partida desactivado: todo volvio a la normalidad'
}

# ---------------------------------------------------------------- MPO, discos, actualizar, reparar
function Test-MPOFix { return ((Get-RegVal 'HKLM\SOFTWARE\Microsoft\Windows\Dwm' 'OverlayTestMode') -eq 5) }
function Set-MPOFix {
    param([bool]$On)
    New-Item -ItemType Directory -Path $VXDIR -Force -ErrorAction SilentlyContinue | Out-Null
    if ($On) {
        Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\Dwm' 'OverlayTestMode' REG_DWORD 5
        Set-Content -Path (Join-Path $VXDIR 'mpo_desactivado.txt') -Value 'optifrag'
        Listo 'Arreglo de parpadeos (MPO) aplicado. Reinicia la PC.'
    } else {
        Remove-Reg 'HKLM\SOFTWARE\Microsoft\Windows\Dwm' 'OverlayTestMode'
        Remove-Item (Join-Path $VXDIR 'mpo_desactivado.txt') -Force -ErrorAction SilentlyContinue
        Listo 'MPO restaurado como viene en Windows. Reinicia la PC.'
    }
}
function Job-Discos {
    foreach ($v in (Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -and "$($_.DriveType)" -eq 'Fixed' -and $_.FileSystem -eq 'NTFS' })) {
        $tipo = 'SSD'
        try {
            $num = (Get-Partition -DriveLetter $v.DriveLetter -ErrorAction Stop).DiskNumber
            $tipo = "$((Get-PhysicalDisk | Where-Object { "$($_.DeviceId)" -eq "$num" } | Select-Object -First 1).MediaType)"
        } catch {}
        Paso "Unidad $($v.DriveLetter): ($tipo)"
        if ($tipo -eq 'HDD') { Optimize-Volume -DriveLetter $v.DriveLetter -Defrag -ErrorAction SilentlyContinue; Listo 'Desfragmentada' }
        else { Optimize-Volume -DriveLetter $v.DriveLetter -ReTrim -ErrorAction SilentlyContinue; Listo 'TRIM aplicado' }
    }
}
function Out-Limpio {
    process {
        $l = ("$_" -replace "`0", '' -replace '[\r\b]', '').Trim()
        if ($l.Length -gt 3 -and $l -notmatch '^[\s\-\\|/=\.\d%]+$') { VxLog $l 'info' }
    }
}
function Job-Actualizar {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) { Aviso 'Este Windows no tiene winget: instala "Instalador de aplicacion" desde Microsoft Store.'; return }
    Paso 'Buscando y actualizando programas (puede tardar)'
    winget.exe upgrade --all --silent --accept-source-agreements --accept-package-agreements --disable-interactivity 2>&1 | Out-Limpio
    Listo 'Actualizacion terminada'
}
function Job-Reparar {
    Paso 'Reparando la imagen de Windows (DISM)'
    Dism.exe /Online /Cleanup-Image /RestoreHealth 2>&1 | Out-Limpio
    Paso 'Revisando archivos del sistema (SFC)'
    sfc.exe /scannow 2>&1 | Out-Limpio
    Listo 'Reparacion terminada. Reinicia la PC para completar.'
}
function Job-PuntoRestauracion {
    Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' 'SystemRestorePointCreationFrequency' REG_DWORD 0
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
        Checkpoint-Computer -Description ("OptiFrag - manual " + (Get-Date -Format 'dd/MM HH:mm')) -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Listo 'Punto de restauracion creado'
    } catch { Aviso 'No se pudo crear el punto de restauracion' }
}

# ---------------------------------------------------------------- modo competitivo extremo (sin anticheat)
function Job-Competitivo {
    if (@(Get-VxAnticheat).Count -gt 0) { Aviso 'Hay Vanguard o FACEIT instalado: no se aplica.'; return }
    New-Item -ItemType Directory -Path $BACKUP_DIR -Force -ErrorAction SilentlyContinue | Out-Null
    $bk = Join-Path $BACKUP_DIR 'hvci_backup.reg'
    if (-not (Test-Path $bk)) { reg.exe export 'HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard' $bk /y *> $null }
    Set-Reg $HVCI 'Enabled' REG_DWORD 0
    Listo 'Integridad de memoria desactivada'
    $vmp = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue
    $usa = (Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' -ErrorAction SilentlyContinue) -or
           (Get-AppxPackage -Name '*WindowsSubsystemForAndroid*' -ErrorAction SilentlyContinue) -or
           (Test-Path "$env:ProgramFiles\BlueStacks_nxt") -or (Test-Path "$env:ProgramFiles\Docker") -or
           ((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue).State -eq 'Enabled')
    if ($vmp -and "$($vmp.State)" -eq 'Enabled') {
        if ($usa) { Info 'Plataforma de maquina virtual: se deja activada porque se usa (WSL, Android, BlueStacks, Docker o Hyper-V).' }
        else {
            Disable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -ErrorAction SilentlyContinue | Out-Null
            Set-Content -Path (Join-Path $BACKUP_DIR 'vmp_desactivada.txt') -Value 'optifrag'
            Listo 'Plataforma de maquina virtual desactivada (no se estaba usando)'
        }
    }
    Listo 'Modo competitivo extremo aplicado. Reinicia para que tome efecto.'
}

# ---------------------------------------------------------------- catalogo de tweaks (interruptores)
$VX_TWEAKS = @(
    @{ Id = 'plan'; Cat = 'Rendimiento'; Nombre = 'Plan de energ&iacute;a OptiFrag'; Imp = 'Alto'; Solo = 'PC'
       Desc = 'Procesador siempre listo para rendir. En AMD de doble CCD respeta el plan Equilibrado, que es lo que pide AMD.'
       State = { [bool]((powercfg.exe /getactivescheme) -match $PLAN_OPTIFRAG) }
       On = { M-EnergiaPC }; Off = { powercfg.exe -setactive SCHEME_BALANCED *> $null } },
    @{ Id = 'throttle'; Cat = 'Rendimiento'; Nombre = 'Sin freno de CPU en segundo plano'; Imp = 'Medio'; Solo = 'PC'
       Desc = 'Windows no limita el procesador de los programas que no est&aacute;n al frente (Power Throttling).'
       State = { (Get-RegVal 'HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff') -eq 1 }
       On = { Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' REG_DWORD 1 }
       Off = { Remove-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' } },
    @{ Id = 'prio'; Cat = 'Rendimiento'; Nombre = 'Prioridad a la ventana activa'; Imp = 'Medio'; Solo = ''
       Desc = 'El planificador de CPU le da turnos m&aacute;s cortos y m&aacute;s prioridad al juego o programa que est&aacute;s usando.'
       State = { (Get-RegVal 'HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation') -eq 38 }
       On = { Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' REG_DWORD 38 }
       Off = { Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' REG_DWORD 2 } },
    @{ Id = 'visual'; Cat = 'Rendimiento'; Nombre = 'Efectos visuales en modo rendimiento'; Imp = 'Medio'; Solo = ''
       Desc = 'Sin animaciones al abrir, minimizar ni en la barra de tareas. Las letras siguen n&iacute;tidas (ClearType).'
       State = { "$(Get-RegVal 'HKCU\Control Panel\Desktop\WindowMetrics' 'MinAnimate')" -eq '0' }
       On = { M-Visual }
       Off = {
           Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' REG_DWORD 0
           Set-Reg 'HKCU\Control Panel\Desktop' 'MenuShowDelay' REG_SZ 400
           Set-Reg 'HKCU\Control Panel\Desktop\WindowMetrics' 'MinAnimate' REG_SZ 1
           Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' REG_DWORD 1
           Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' REG_DWORD 1
           Set-Reg 'HKCU\Software\Microsoft\Windows\DWM' 'EnableAeroPeek' REG_DWORD 1 } },
    @{ Id = 'startdelay'; Cat = 'Rendimiento'; Nombre = 'Inicio de Windows sin demora'; Imp = 'Bajo'; Solo = ''
       Desc = 'Windows deja de esperar unos segundos antes de abrir los programas de inicio.'
       State = { (Get-RegVal 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec') -eq 0 }
       On = { Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' REG_DWORD 0 }
       Off = { Remove-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' } },
    @{ Id = 'bgapps'; Cat = 'Rendimiento'; Nombre = 'Apps de la tienda sin correr en segundo plano'; Imp = 'Medio'; Solo = ''
       Desc = 'Correo, Xbox, Vincular tel&eacute;fono y otras apps dejan de funcionar escondidas. Menos RAM y procesos. Se abren normal cuando las us&aacute;s.'
       State = { (Get-RegVal 'HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled') -eq 1 }
       On = { Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' REG_DWORD 1 }
       Off = { Remove-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' } },
    @{ Id = 'luces'; Cat = 'Rendimiento'; Nombre = 'Iluminaci&oacute;n din&aacute;mica de Windows apagada'; Imp = 'Bajo'; Solo = ''
       Desc = 'Windows deja de controlar las luces RGB de teclado y mouse. Si us&aacute;s el programa de tu marca (Razer, Logitech...) sigue funcionando igual.'
       State = { (Get-RegVal 'HKCU\Software\Microsoft\Lighting' 'AmbientLightingEnabled') -eq 0 }
       On = { Set-Reg 'HKCU\Software\Microsoft\Lighting' 'AmbientLightingEnabled' REG_DWORD 0 }
       Off = { Remove-Reg 'HKCU\Software\Microsoft\Lighting' 'AmbientLightingEnabled' } },
    @{ Id = 'gamemode'; Cat = 'Juegos'; Nombre = 'Modo juego de Windows'; Imp = 'Medio'; Solo = ''
       Desc = 'Windows prioriza el juego y no instala actualizaciones ni drivers mientras jug&aacute;s.'
       State = { (Get-RegVal 'HKCU\Software\Microsoft\GameBar' 'AutoGameModeEnabled') -ne 0 }
       On = { Set-Reg 'HKCU\Software\Microsoft\GameBar' 'AutoGameModeEnabled' REG_DWORD 1; Set-Reg 'HKCU\Software\Microsoft\GameBar' 'AllowAutoGameMode' REG_DWORD 1 }
       Off = { Set-Reg 'HKCU\Software\Microsoft\GameBar' 'AutoGameModeEnabled' REG_DWORD 0 } },
    @{ Id = 'hags'; Cat = 'Juegos'; Nombre = 'Programaci&oacute;n de GPU por hardware (HAGS)'; Imp = 'Alto'; Solo = ''
       Desc = 'La placa de video organiza sus propios cuadros. Solo se activa en placas donde ayuda (RTX, GTX 16, RX 6000+, Arc).'
       State = { (Get-RegVal 'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode') -eq 2 }
       On = {
           $gn = (@(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }) -join ' ')
           if ($gn -match 'RTX|GTX 16|RX [6-9]\d{3}|Arc') { Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' REG_DWORD 2; Listo 'HAGS activado (reinicia la PC)' }
           else { Aviso 'Tu placa de video no se beneficia de HAGS: se deja como esta.' } }
       Off = { Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' REG_DWORD 1 } },
    @{ Id = 'timer'; Cat = 'Juegos'; Nombre = 'Timers de alta precisi&oacute;n para juegos'; Imp = 'Medio'; Solo = ''
       Desc = 'En Windows 11 los juegos vuelven a poder pedir timers precisos: frametimes m&aacute;s estables, menos micro-tirones.'
       State = { (Get-RegVal 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'GlobalTimerResolutionRequests') -eq 1 }
       On = { Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'GlobalTimerResolutionRequests' REG_DWORD 1 }
       Off = { Remove-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'GlobalTimerResolutionRequests' } },
    @{ Id = 'ventana'; Cat = 'Juegos'; Nombre = 'Optimizaciones para juegos en ventana'; Imp = 'Medio'; Solo = ''
       Desc = 'Juegos DX10/DX11 en ventana o sin bordes usan el modelo moderno de Windows: menos input lag.'
       State = { "$(Get-RegVal 'HKCU\Software\Microsoft\DirectX\UserGpuPreferences' 'DirectXUserGlobalSettings')" -match 'SwapEffectUpgradeEnable=1' }
       On = { Set-Reg 'HKCU\Software\Microsoft\DirectX\UserGpuPreferences' 'DirectXUserGlobalSettings' REG_SZ 'SwapEffectUpgradeEnable=1;' }
       Off = { Remove-Reg 'HKCU\Software\Microsoft\DirectX\UserGpuPreferences' 'DirectXUserGlobalSettings' } },
    @{ Id = 'dvr'; Cat = 'Juegos'; Nombre = 'Sin grabaci&oacute;n de Xbox en segundo plano'; Imp = 'Medio'; Solo = ''
       Desc = 'Apaga la grabaci&oacute;n autom&aacute;tica de partidas de la Xbox Game Bar, que consume FPS aunque no la uses.'
       State = { (Get-RegVal 'HKCU\System\GameConfigStore' 'GameDVR_Enabled') -eq 0 }
       On = { Set-Reg 'HKCU\System\GameConfigStore' 'GameDVR_Enabled' REG_DWORD 0; Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' REG_DWORD 0; Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' REG_DWORD 0 }
       Off = { Set-Reg 'HKCU\System\GameConfigStore' 'GameDVR_Enabled' REG_DWORD 1; Remove-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled'; Remove-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' } },
    @{ Id = 'mmcss'; Cat = 'Juegos'; Nombre = 'Prioridad de CPU y GPU para juegos'; Imp = 'Medio'; Solo = ''
       Desc = 'El programador multimedia de Windows reserva m&aacute;s recursos para los juegos.'
       State = { (Get-RegVal "$MM\Tasks\Games" 'Priority') -eq 6 }
       On = { Set-Reg $MM 'SystemResponsiveness' REG_DWORD 10; Set-Reg "$MM\Tasks\Games" 'GPU Priority' REG_DWORD 8; Set-Reg "$MM\Tasks\Games" 'Priority' REG_DWORD 6; Set-Reg "$MM\Tasks\Games" 'Scheduling Category' REG_SZ 'High'; Set-Reg "$MM\Tasks\Games" 'SFIO Priority' REG_SZ 'High' }
       Off = { Set-Reg $MM 'SystemResponsiveness' REG_DWORD 20; Set-Reg "$MM\Tasks\Games" 'Priority' REG_DWORD 2; Set-Reg "$MM\Tasks\Games" 'Scheduling Category' REG_SZ 'Medium'; Set-Reg "$MM\Tasks\Games" 'SFIO Priority' REG_SZ 'Normal' } },
    @{ Id = 'mouse'; Cat = 'Juegos'; Nombre = 'Mouse 1:1 sin aceleraci&oacute;n'; Imp = 'Medio'; Solo = ''
       Desc = 'Apaga "Mejorar precisi&oacute;n del puntero": el movimiento es siempre igual, ideal para apuntar.'
       State = { "$(Get-RegVal 'HKCU\Control Panel\Mouse' 'MouseSpeed')" -eq '0' }
       On = { Set-Reg 'HKCU\Control Panel\Mouse' 'MouseSpeed' REG_SZ 0; Set-Reg 'HKCU\Control Panel\Mouse' 'MouseThreshold1' REG_SZ 0; Set-Reg 'HKCU\Control Panel\Mouse' 'MouseThreshold2' REG_SZ 0 }
       Off = { Set-Reg 'HKCU\Control Panel\Mouse' 'MouseSpeed' REG_SZ 1; Set-Reg 'HKCU\Control Panel\Mouse' 'MouseThreshold1' REG_SZ 6; Set-Reg 'HKCU\Control Panel\Mouse' 'MouseThreshold2' REG_SZ 10 } },
    @{ Id = 'sticky'; Cat = 'Juegos'; Nombre = 'Sin carteles de Teclas especiales'; Imp = 'Bajo'; Solo = ''
       Desc = 'No aparece m&aacute;s la ventana de Teclas especiales al apretar Shift varias veces en pleno juego.'
       State = { "$(Get-RegVal 'HKCU\Control Panel\Accessibility\StickyKeys' 'Flags')" -eq '506' }
       On = { Set-Reg 'HKCU\Control Panel\Accessibility\StickyKeys' 'Flags' REG_SZ 506; Set-Reg 'HKCU\Control Panel\Accessibility\ToggleKeys' 'Flags' REG_SZ 58; Set-Reg 'HKCU\Control Panel\Accessibility\Keyboard Response' 'Flags' REG_SZ 122 }
       Off = { Set-Reg 'HKCU\Control Panel\Accessibility\StickyKeys' 'Flags' REG_SZ 510; Set-Reg 'HKCU\Control Panel\Accessibility\ToggleKeys' 'Flags' REG_SZ 62; Set-Reg 'HKCU\Control Panel\Accessibility\Keyboard Response' 'Flags' REG_SZ 126 } },
    @{ Id = 'nagle'; Cat = 'Red'; Nombre = 'Paquetes chicos al instante (sin Nagle)'; Imp = 'Bajo'; Solo = ''
       Desc = 'Los paquetes TCP chicos salen sin esperar a agruparse. Ayuda en juegos y chats que usan TCP.'
       State = { [bool](Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' -ErrorAction SilentlyContinue | Where-Object { (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).TCPNoDelay -eq 1 } | Select-Object -First 1) }
       On = { Get-ChildItem $IFACES -ErrorAction SilentlyContinue | ForEach-Object { New-ItemProperty -Path $_.PSPath -Name 'TcpAckFrequency' -Value 1 -PropertyType DWord -Force | Out-Null; New-ItemProperty -Path $_.PSPath -Name 'TCPNoDelay' -Value 1 -PropertyType DWord -Force | Out-Null } }
       Off = { Get-ChildItem $IFACES -ErrorAction SilentlyContinue | ForEach-Object { Remove-ItemProperty -Path $_.PSPath -Name 'TcpAckFrequency' -Force -ErrorAction SilentlyContinue; Remove-ItemProperty -Path $_.PSPath -Name 'TCPNoDelay' -Force -ErrorAction SilentlyContinue } } },
    @{ Id = 'ipv4'; Cat = 'Red'; Nombre = 'Preferir IPv4 (sin apagar IPv6)'; Imp = 'Bajo'; Solo = ''
       Desc = 'Lo que recomienda Microsoft en vez de desactivar IPv6. Evita demoras con rutas IPv6 lentas.'
       State = { (Get-RegVal 'HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' 'DisabledComponents') -eq 32 }
       On = { $dc = Get-RegVal 'HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' 'DisabledComponents'; if (-not $dc) { Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' 'DisabledComponents' REG_DWORD 32 } else { Aviso 'IPv6 ya tiene una configuracion personalizada: no se toca.' } }
       Off = { if ((Get-RegVal 'HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' 'DisabledComponents') -eq 32) { Remove-Reg 'HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' 'DisabledComponents' } } },
    @{ Id = 'do'; Cat = 'Red'; Nombre = 'Sin subidas ocultas de Windows Update'; Imp = 'Medio'; Solo = ''
       Desc = 'Windows deja de usar tu internet para mandar actualizaciones a otras computadoras.'
       State = { (Get-RegVal 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode') -eq 0 }
       On = { Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' REG_DWORD 0 }
       Off = { Remove-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' } },
    @{ Id = 'telemetria'; Cat = 'Privacidad'; Nombre = 'Telemetr&iacute;a al m&iacute;nimo'; Imp = 'Bajo'; Solo = ''
       Desc = 'Menos datos enviados a Microsoft y menos tareas de diagn&oacute;stico en segundo plano.'
       State = { (Get-RegVal 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry') -eq 0 }
       On = { M-Telemetria }
       Off = { Remove-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry'; sc.exe config DiagTrack start= auto *> $null; sc.exe start DiagTrack *> $null; foreach ($t in $TAREAS) { schtasks.exe /Change /TN $t /Enable *> $null } } },
    @{ Id = 'ads'; Cat = 'Privacidad'; Nombre = 'Sin publicidad ni apps sugeridas'; Imp = 'Bajo'; Solo = ''
       Desc = 'Windows no instala apps solas ni muestra anuncios en Inicio, Configuraci&oacute;n ni la pantalla de bloqueo.'
       State = { (Get-RegVal $CDM 'SilentInstalledAppsEnabled') -eq 0 }
       On = { foreach ($v in $CDM_VALS) { Set-Reg $CDM $v REG_DWORD 0 }; Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_IrisRecommendations' REG_DWORD 0 }
       Off = { foreach ($v in $CDM_VALS) { Set-Reg $CDM $v REG_DWORD 1 }; Remove-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_IrisRecommendations' } },
    @{ Id = 'widgets'; Cat = 'Privacidad'; Nombre = 'Sin widgets ni noticias'; Imp = 'Medio'; Solo = ''
       Desc = 'Los widgets consumen RAM e internet todo el tiempo aunque no los mires.'
       State = { (Get-RegVal 'HKLM\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests') -eq 0 }
       On = { Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' REG_DWORD 0; Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' 'EnableFeeds' REG_DWORD 0 }
       Off = { Remove-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests'; Remove-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' 'EnableFeeds' } },
    @{ Id = 'bing'; Cat = 'Privacidad'; Nombre = 'B&uacute;squeda del Inicio sin Bing'; Imp = 'Bajo'; Solo = ''
       Desc = 'El men&uacute; Inicio busca solo en tu PC: resultados m&aacute;s r&aacute;pidos y sin publicidad web.'
       State = { (Get-RegVal 'HKCU\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions') -eq 1 }
       On = { Set-Reg 'HKCU\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' REG_DWORD 1 }
       Off = { Remove-Reg 'HKCU\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' } },
    @{ Id = 'copilot'; Cat = 'Privacidad'; Nombre = 'Sin Copilot ni capturas de Recall'; Imp = 'Bajo'; Solo = ''
       Desc = 'Apaga Copilot de Windows y las capturas automaticas de pantalla de Recall.'
       State = { (Get-RegVal 'HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot') -eq 1 }
       On = { Set-Reg 'HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' REG_DWORD 1; Set-Reg 'HKCU\Software\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' REG_DWORD 1 }
       Off = { Remove-Reg 'HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot'; Remove-Reg 'HKCU\Software\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' } },
    @{ Id = 'adid'; Cat = 'Privacidad'; Nombre = 'Sin ID de publicidad'; Imp = 'Bajo'; Solo = ''
       Desc = 'Las apps no pueden usar un identificador tuyo para mostrarte anuncios personalizados.'
       State = { (Get-RegVal 'HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled') -eq 0 }
       On = { Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' REG_DWORD 0; Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' REG_DWORD 0 }
       Off = { Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' REG_DWORD 1; Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' REG_DWORD 1 } },
    @{ Id = 'pstele'; Cat = 'Privacidad'; Nombre = 'Telemetr&iacute;a de PowerShell apagada'; Imp = 'Bajo'; Solo = ''
       Desc = 'PowerShell deja de mandar datos de uso a Microsoft cada vez que se abre.'
       State = { (Get-RegVal 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' 'POWERSHELL_TELEMETRY_OPTOUT') -eq '1' }
       On = { Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' 'POWERSHELL_TELEMETRY_OPTOUT' REG_SZ '1' }
       Off = { Remove-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' 'POWERSHELL_TELEMETRY_OPTOUT' } },
    @{ Id = 'fabricantes'; Cat = 'Sistema'; Nombre = 'Bloquear programas que instalan solos los fabricantes'; Imp = 'Bajo'; Solo = ''
       Desc = 'Evita que al conectar un mouse o teclado se instale solo el programa de la marca, y que la placa madre meta programas desde el firmware. Los drivers siguen llegando por Windows Update.'
       State = { ((Get-RegVal 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata' 'PreventDeviceMetadataFromNetwork') -eq 1) -and ((Get-RegVal 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager' 'DisableWpbtExecution') -eq 1) }
       On = { Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata' 'PreventDeviceMetadataFromNetwork' REG_DWORD 1; Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager' 'DisableWpbtExecution' REG_DWORD 1 }
       Off = { Remove-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata' 'PreventDeviceMetadataFromNetwork'; Remove-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager' 'DisableWpbtExecution' } },
    @{ Id = 'search'; Cat = 'Sistema'; Nombre = 'B&uacute;squeda de Windows en modo Cl&aacute;sico'; Imp = 'Bajo'; Solo = ''
       Desc = 'No indexa todo el disco: menos escrituras en el SSD y menos CPU. Tus carpetas principales se siguen buscando.'
       State = { (Get-RegVal 'HKLM\SOFTWARE\Microsoft\Windows Search' 'EnableFindMyFiles') -ne 1 }
       On = { Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows Search' 'EnableFindMyFiles' REG_DWORD 0; Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows Search\Gather\Windows\SystemIndex' 'EnableFindMyFiles' REG_DWORD 0 }
       Off = { Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows Search' 'EnableFindMyFiles' REG_DWORD 1; Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows Search\Gather\Windows\SystemIndex' 'EnableFindMyFiles' REG_DWORD 1 } },
    @{ Id = 'activehours'; Cat = 'Sistema'; Nombre = 'Windows Update no reinicia de 9 a 3'; Imp = 'Medio'; Solo = ''
       Desc = 'Se actualiza igual, pero nunca te reinicia la PC entre las 9:00 y las 3:00.'
       State = { (Get-RegVal 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'ActiveHoursStart') -eq 9 }
       On = { Set-Reg 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'SmartActiveHoursState' REG_DWORD 0; Set-Reg 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'ActiveHoursStart' REG_DWORD 9; Set-Reg 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'ActiveHoursEnd' REG_DWORD 3 }
       Off = { foreach ($v in 'SmartActiveHoursState', 'ActiveHoursStart', 'ActiveHoursEnd') { Remove-Reg 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' $v } } },
    @{ Id = 'endtask'; Cat = 'Sistema'; Nombre = 'Finalizar tarea con clic derecho'; Imp = 'Bajo'; Solo = ''
       Desc = 'Clic derecho en un programa de la barra de tareas > Finalizar tarea. Ideal para juegos colgados.'
       State = { (Get-RegVal 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' 'TaskbarEndTask') -eq 1 }
       On = { Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' 'TaskbarEndTask' REG_DWORD 1 }
       Off = { Remove-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' 'TaskbarEndTask' } },
    @{ Id = 'ext'; Cat = 'Sistema'; Nombre = 'Mostrar extensiones de archivo'; Imp = 'Bajo'; Solo = ''
       Desc = 'Ves si un archivo es .exe, .pdf o .mp4. Ayuda a detectar virus disfrazados.'
       State = { (Get-RegVal 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt') -eq 0 }
       On = { Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt' REG_DWORD 0 }
       Off = { Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt' REG_DWORD 1 } },
    @{ Id = 'hiber'; Cat = 'Sistema'; Nombre = 'Sin hibernaci&oacute;n ni inicio r&aacute;pido'; Imp = 'Bajo'; Solo = 'PC'
       Desc = 'Libera varios GB del disco y hace que cada reinicio sea un arranque limpio.'
       State = { (Get-RegVal 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled') -eq 0 }
       On = { powercfg.exe -h off *> $null }; Off = { powercfg.exe -h on *> $null } },
    @{ Id = 'ntfs'; Cat = 'Sistema'; Nombre = 'Disco sin escrituras innecesarias'; Imp = 'Bajo'; Solo = ''
       Desc = 'NTFS deja de anotar la fecha de &uacute;ltimo acceso cada vez que se lee un archivo.'
       State = { [bool]((fsutil.exe behavior query disablelastaccess) -match '=\s*[13]') }
       On = { fsutil.exe behavior set disablelastaccess 1 *> $null }; Off = { fsutil.exe behavior set disablelastaccess 2 *> $null } }
)
'@

$VX_XAML = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="OptiFrag" Width="1220" Height="800" MinWidth="940" MinHeight="560"
        WindowStartupLocation="CenterScreen" WindowStyle="None" ResizeMode="CanMinimize"
        Background="#0B080C" FontFamily="Segoe UI" Foreground="White" UseLayoutRounding="True">
  <Window.Resources>
    <Style x:Key="Card" TargetType="Border">
      <Setter Property="Background" Value="#1A1219"/>
      <Setter Property="BorderBrush" Value="#3D2230"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="16"/>
      <Setter Property="Padding" Value="20"/>
    </Style>
    <Style x:Key="H1" TargetType="TextBlock">
      <Setter Property="FontSize" Value="30"/>
      <Setter Property="FontWeight" Value="Bold"/>
    </Style>
    <Style x:Key="Sub" TargetType="TextBlock">
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Foreground" Value="#B9A8B2"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
    </Style>
    <Style x:Key="H2" TargetType="TextBlock">
      <Setter Property="FontSize" Value="18"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style x:Key="Accent" TargetType="Button">
      <Setter Property="Foreground" Value="#1A0A06"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Height" Value="42"/>
      <Setter Property="Padding" Value="22,0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="#FF5A36" CornerRadius="10" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#FF8A6B"/></Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="b" Property="Background" Value="#D9431F"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.4"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="Lime" TargetType="Button" BasedOn="{StaticResource Accent}">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="#FFC83D" CornerRadius="10" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#FFDB7A"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.4"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="Ghost" TargetType="Button">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Height" Value="38"/>
      <Setter Property="Padding" Value="16,0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="Transparent" BorderBrush="#5A3040" BorderThickness="1" CornerRadius="10" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="#FF5A36"/><Setter TargetName="b" Property="Background" Value="#2A1820"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.4"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="Warn" TargetType="Button" BasedOn="{StaticResource Accent}">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="#FFB020" CornerRadius="10" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#FFC85A"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.4"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="Nav" TargetType="RadioButton">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="GroupName" Value="nav"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RadioButton">
            <Border x:Name="b" CornerRadius="10" Padding="14,11" Margin="0,2" Background="Transparent">
              <Grid>
                <Border x:Name="bar" Width="3" CornerRadius="2" Background="#FF5A36" HorizontalAlignment="Left" Margin="-14,0,0,0" Visibility="Collapsed"/>
                <StackPanel Orientation="Horizontal">
                  <TextBlock x:Name="i" Text="{TemplateBinding Tag}" FontFamily="Segoe MDL2 Assets" FontSize="16" Foreground="#B9A8B2" VerticalAlignment="Center"/>
                  <ContentPresenter Margin="14,0,0,0" VerticalAlignment="Center"/>
                </StackPanel>
              </Grid>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#1A1117"/></Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="b" Property="Background" Value="#2A1820"/>
                <Setter TargetName="i" Property="Foreground" Value="#FF5A36"/>
                <Setter TargetName="bar" Property="Visibility" Value="Visible"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="Choice" TargetType="RadioButton">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="GroupName" Value="tipo"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RadioButton">
            <Border x:Name="b" Background="#1A1219" BorderBrush="#3D2230" BorderThickness="2" CornerRadius="16" Padding="22,18" Margin="0,0,12,0">
              <StackPanel Orientation="Horizontal">
                <TextBlock x:Name="i" Text="{TemplateBinding Tag}" FontFamily="Segoe MDL2 Assets" FontSize="34" Foreground="#B9A8B2" VerticalAlignment="Center"/>
                <ContentPresenter Margin="18,0,0,0" VerticalAlignment="Center"/>
              </StackPanel>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="#5A3040"/></Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="b" Property="BorderBrush" Value="#FF5A36"/>
                <Setter TargetName="b" Property="Background" Value="#2A1820"/>
                <Setter TargetName="i" Property="Foreground" Value="#FF5A36"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="Switch" TargetType="CheckBox">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Grid Width="48" Height="26" Background="Transparent">
              <Border x:Name="t" CornerRadius="13" BorderThickness="1" BorderBrush="#5A3040">
                <Border.Background><SolidColorBrush x:Name="tb" Color="#3A2430"/></Border.Background>
              </Border>
              <Ellipse x:Name="k" Width="20" Height="20" HorizontalAlignment="Left" Margin="3,0,0,0">
                <Ellipse.Fill><SolidColorBrush x:Name="kb" Color="#E2D6DC"/></Ellipse.Fill>
                <Ellipse.RenderTransform><TranslateTransform x:Name="kt" X="0"/></Ellipse.RenderTransform>
              </Ellipse>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="t" Property="BorderBrush" Value="#FF5A36"/>
                <Trigger.EnterActions>
                  <BeginStoryboard>
                    <Storyboard>
                      <DoubleAnimation Storyboard.TargetName="kt" Storyboard.TargetProperty="X" To="22" Duration="0:0:0.18"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation>
                      <ColorAnimation Storyboard.TargetName="tb" Storyboard.TargetProperty="Color" To="#FF5A36" Duration="0:0:0.18"/>
                      <ColorAnimation Storyboard.TargetName="kb" Storyboard.TargetProperty="Color" To="#1A0A06" Duration="0:0:0.18"/>
                    </Storyboard>
                  </BeginStoryboard>
                </Trigger.EnterActions>
                <Trigger.ExitActions>
                  <BeginStoryboard>
                    <Storyboard>
                      <DoubleAnimation Storyboard.TargetName="kt" Storyboard.TargetProperty="X" To="0" Duration="0:0:0.18"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation>
                      <ColorAnimation Storyboard.TargetName="tb" Storyboard.TargetProperty="Color" To="#3A2430" Duration="0:0:0.18"/>
                      <ColorAnimation Storyboard.TargetName="kb" Storyboard.TargetProperty="Color" To="#E2D6DC" Duration="0:0:0.18"/>
                    </Storyboard>
                  </BeginStoryboard>
                </Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="t" Property="Opacity" Value="0.9"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.55"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="Check" TargetType="CheckBox">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <StackPanel Orientation="Horizontal" Background="Transparent">
              <Border x:Name="box" Width="20" Height="20" CornerRadius="5" BorderBrush="#5A3040" BorderThickness="2" Background="Transparent" VerticalAlignment="Top" Margin="0,1,0,0">
                <TextBlock x:Name="tick" Text="&#xE73E;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="#1A0A06" HorizontalAlignment="Center" VerticalAlignment="Center" Visibility="Collapsed"/>
              </Border>
              <ContentPresenter Margin="12,0,0,0" VerticalAlignment="Top"/>
            </StackPanel>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="box" Property="Background" Value="#FF5A36"/>
                <Setter TargetName="box" Property="BorderBrush" Value="#FF5A36"/>
                <Setter TargetName="tick" Property="Visibility" Value="Visible"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="WinBtn" TargetType="Button">
      <Setter Property="Foreground" Value="#B9A8B2"/>
      <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="Width" Value="48"/>
      <Setter Property="Height" Value="40"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="Transparent"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#2A1820"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="WinClose" TargetType="Button" BasedOn="{StaticResource WinBtn}">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="Transparent"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#E81123"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Border BorderBrush="#3D2230" BorderThickness="1">
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="240"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>

      <!-- ===================== MENU LATERAL ===================== -->
      <Border Grid.Column="0" Background="#120C12" x:Name="Sidebar">
        <DockPanel LastChildFill="False">
          <StackPanel DockPanel.Dock="Top" Margin="24,26,20,6">
            <StackPanel Orientation="Horizontal">
              <Viewbox Width="30" Height="30" VerticalAlignment="Center">
                <Canvas Width="44" Height="44">
                  <Ellipse Canvas.Left="7" Canvas.Top="7" Width="30" Height="30" Stroke="#FF5A36" StrokeThickness="4"/>
                  <Line X1="22" Y1="1" X2="22" Y2="13" Stroke="#FF5A36" StrokeThickness="4" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
                  <Line X1="22" Y1="31" X2="22" Y2="43" Stroke="#FF5A36" StrokeThickness="4" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
                  <Line X1="1" Y1="22" X2="13" Y2="22" Stroke="#FF5A36" StrokeThickness="4" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
                  <Line X1="31" Y1="22" X2="43" Y2="22" Stroke="#FF5A36" StrokeThickness="4" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
                  <Ellipse Canvas.Left="18.5" Canvas.Top="18.5" Width="7" Height="7" Fill="#FFC83D"/>
                </Canvas>
              </Viewbox>
              <TextBlock FontSize="27" FontWeight="Black" Margin="10,0,0,0" VerticalAlignment="Center"><Run Text="OPTI" Foreground="#FFFFFF"/><Run Text="FRAG" Foreground="#FF5A36"/></TextBlock>
            </StackPanel>
            <TextBlock x:Name="TxtVersion" Text="Optimizador de Windows" Foreground="#B9A8B2" FontSize="12" Margin="2,6,0,0"/>
          </StackPanel>
          <StackPanel DockPanel.Dock="Top" Margin="12,22,12,0">
            <RadioButton x:Name="NavInicio" Style="{StaticResource Nav}" Tag="&#xE80F;" Content="Inicio" IsChecked="True"/>
            <RadioButton x:Name="NavOptimizar" Style="{StaticResource Nav}" Tag="&#xE945;" Content="Optimizar"/>
            <RadioButton x:Name="NavTweaks" Style="{StaticResource Nav}" Tag="&#xE713;" Content="Tweaks"/>
            <RadioButton x:Name="NavJuegos" Style="{StaticResource Nav}" Tag="&#xE7FC;" Content="Juegos"/>
            <RadioButton x:Name="NavHerramientas" Style="{StaticResource Nav}" Tag="&#xE90F;" Content="Herramientas"/>
            <RadioButton x:Name="NavInformes" Style="{StaticResource Nav}" Tag="&#xE9D9;" Content="Informes"/>
            <RadioButton x:Name="NavRevertir" Style="{StaticResource Nav}" Tag="&#xE7A7;" Content="Revertir"/>
          </StackPanel>
          <StackPanel DockPanel.Dock="Bottom" Margin="24,0,20,22">
            <Border x:Name="BadgeModo" Background="#2A1820" CornerRadius="8" Padding="10,6" HorizontalAlignment="Left">
              <StackPanel Orientation="Horizontal">
                <TextBlock x:Name="BadgeIcon" Text="&#xE83D;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="#22E58B" VerticalAlignment="Center"/>
                <TextBlock x:Name="TxtModo" Text="Administrador" FontSize="12" Foreground="#E2D6DC" Margin="8,0,0,0"/>
              </StackPanel>
            </Border>
            <TextBlock Text="@optifrag" Foreground="#B9A8B2" FontSize="12" Margin="2,12,0,0"/>
          </StackPanel>
        </DockPanel>
      </Border>

      <!-- ===================== CONTENIDO ===================== -->
      <Grid Grid.Column="1">
        <Grid.RowDefinitions>
          <RowDefinition Height="40"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="160"/>
        </Grid.RowDefinitions>

        <Grid x:Name="TitleBar" Grid.Row="0" Background="#0B080C">
          <TextBlock x:Name="TxtPagina" Text="Inicio" Margin="30,12,0,0" Foreground="#8A7480" FontSize="12"/>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="BtnMin" Style="{StaticResource WinBtn}" Content="&#xE921;"/>
            <Button x:Name="BtnClose" Style="{StaticResource WinClose}" Content="&#xE8BB;"/>
          </StackPanel>
        </Grid>

        <Grid Grid.Row="1" Margin="30,0,18,10">

          <!-- ============ INICIO ============ -->
          <ScrollViewer x:Name="PgInicio" VerticalScrollBarVisibility="Auto" Padding="0,0,12,0">
            <StackPanel>
              <TextBlock Text="Tu PC" Style="{StaticResource H1}"/>
              <TextBlock x:Name="TxtSaludo" Text="Analizando tu equipo..." Style="{StaticResource Sub}" Margin="0,4,0,18"/>
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="300"/>
                  <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Border Style="{StaticResource Card}" Grid.Column="0">
                  <StackPanel>
                    <Grid Width="200" Height="200" HorizontalAlignment="Center">
                      <Ellipse Stroke="#3D2230" StrokeThickness="16"/>
                      <Ellipse x:Name="Ring" Stroke="#FF5A36" StrokeThickness="16" StrokeDashCap="Round" StrokeDashArray="0 100" RenderTransformOrigin="0.5,0.5">
                        <Ellipse.RenderTransform><RotateTransform Angle="-90"/></Ellipse.RenderTransform>
                      </Ellipse>
                      <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                        <TextBlock x:Name="TxtIndice" Text="--" FontSize="58" FontWeight="Black" HorizontalAlignment="Center"/>
                        <TextBlock Text="&#205;ndice OptiFrag" Foreground="#B9A8B2" FontSize="13" HorizontalAlignment="Center"/>
                      </StackPanel>
                    </Grid>
                    <TextBlock x:Name="TxtIndiceDesc" Text="Midiendo RAM, procesos, programas de inicio, basura y disco..." Style="{StaticResource Sub}" FontSize="13" TextAlignment="Center" Margin="0,14,0,0"/>
                    <Button x:Name="BtnIrOptimizar" Style="{StaticResource Accent}" Content="Optimizar ahora" Margin="0,16,0,0"/>
                    <Button x:Name="BtnReanalizar" Style="{StaticResource Ghost}" Content="Analizar de nuevo" Margin="0,10,0,0"/>
                  </StackPanel>
                </Border>
                <UniformGrid Grid.Column="1" Columns="2" Margin="16,0,0,0">
                  <Border Style="{StaticResource Card}" Margin="0,0,8,8"><StackPanel><TextBlock Foreground="#FF5A36" FontSize="13"><Run Text="&#xE950;" FontFamily="Segoe MDL2 Assets"/><Run Text="   Procesador"/></TextBlock><TextBlock x:Name="InfoCPU" Text="..." FontSize="15" FontWeight="SemiBold" TextWrapping="Wrap" Margin="0,8,0,0"/></StackPanel></Border>
                  <Border Style="{StaticResource Card}" Margin="8,0,0,8"><StackPanel><TextBlock Foreground="#FF5A36" FontSize="13"><Run Text="&#xE7F4;" FontFamily="Segoe MDL2 Assets"/><Run Text="   Placa de video"/></TextBlock><TextBlock x:Name="InfoGPU" Text="..." FontSize="15" FontWeight="SemiBold" TextWrapping="Wrap" Margin="0,8,0,0"/></StackPanel></Border>
                  <Border Style="{StaticResource Card}" Margin="0,8,8,8"><StackPanel><TextBlock Foreground="#FF5A36" FontSize="13"><Run Text="&#xE964;" FontFamily="Segoe MDL2 Assets"/><Run Text="   Memoria RAM"/></TextBlock><TextBlock x:Name="InfoRAM" Text="..." FontSize="15" FontWeight="SemiBold" TextWrapping="Wrap" Margin="0,8,0,0"/></StackPanel></Border>
                  <Border Style="{StaticResource Card}" Margin="8,8,0,8"><StackPanel><TextBlock Foreground="#FF5A36" FontSize="13"><Run Text="&#xEDA2;" FontFamily="Segoe MDL2 Assets"/><Run Text="   Disco de Windows"/></TextBlock><TextBlock x:Name="InfoDisco" Text="..." FontSize="15" FontWeight="SemiBold" TextWrapping="Wrap" Margin="0,8,0,0"/></StackPanel></Border>
                  <Border Style="{StaticResource Card}" Margin="0,8,8,0"><StackPanel><TextBlock Foreground="#FF5A36" FontSize="13"><Run Text="&#xE7F8;" FontFamily="Segoe MDL2 Assets"/><Run Text="   Pantalla y salud"/></TextBlock><TextBlock x:Name="InfoPantalla" Text="..." FontSize="15" FontWeight="SemiBold" TextWrapping="Wrap" Margin="0,8,0,0"/></StackPanel></Border>
                  <Border Style="{StaticResource Card}" Margin="8,8,0,0"><StackPanel><TextBlock Foreground="#FF5A36" FontSize="13"><Run Text="&#xE770;" FontFamily="Segoe MDL2 Assets"/><Run Text="   Sistema"/></TextBlock><TextBlock x:Name="InfoWin" Text="..." FontSize="15" FontWeight="SemiBold" TextWrapping="Wrap" Margin="0,8,0,0"/></StackPanel></Border>
                </UniformGrid>
              </Grid>
              <Border Style="{StaticResource Card}" Margin="0,16,0,8">
                <StackPanel>
                  <TextBlock Text="Recomendaciones para tu equipo" Style="{StaticResource H2}"/>
                  <StackPanel x:Name="ListaRec" Margin="0,10,0,0"/>
                </StackPanel>
              </Border>
            </StackPanel>
          </ScrollViewer>

          <!-- ============ OPTIMIZAR ============ -->
          <ScrollViewer x:Name="PgOptimizar" VerticalScrollBarVisibility="Auto" Visibility="Collapsed" Padding="0,0,12,0">
            <StackPanel>
              <TextBlock Text="Optimizaci&#243;n completa" Style="{StaticResource H1}"/>
              <TextBlock Text="Eleg&#237; el tipo de equipo, revis&#225; los pasos y toc&#225; Optimizar. Antes de tocar nada se crea un punto de restauraci&#243;n y todo se puede deshacer." Style="{StaticResource Sub}" Margin="0,4,0,18"/>
              <UniformGrid Columns="2">
                <RadioButton x:Name="OptPC" Style="{StaticResource Choice}" Tag="&#xE7F4;">
                  <StackPanel><TextBlock Text="PC de escritorio" FontSize="18" FontWeight="SemiBold"/><TextBlock Text="M&#225;ximo rendimiento todo el tiempo" Foreground="#B9A8B2" FontSize="13"/></StackPanel>
                </RadioButton>
                <RadioButton x:Name="OptLaptop" Style="{StaticResource Choice}" Tag="&#xE7F8;">
                  <StackPanel><TextBlock Text="Laptop / Notebook" FontSize="18" FontWeight="SemiBold"/><TextBlock Text="Rendimiento enchufada, ahorro a bater&#237;a" Foreground="#B9A8B2" FontSize="13"/></StackPanel>
                </RadioButton>
              </UniformGrid>
              <Border Style="{StaticResource Card}" Margin="0,16,12,0">
                <StackPanel>
                  <TextBlock Text="Pasos de la optimizaci&#243;n" Style="{StaticResource H2}"/>
                  <TextBlock Text="Todos vienen marcados. Pod&#233;s desmarcar los que no quieras." Style="{StaticResource Sub}" FontSize="13" Margin="0,2,0,12"/>
                  <WrapPanel x:Name="ListaModulos"/>
                </StackPanel>
              </Border>
              <StackPanel Orientation="Horizontal" Margin="0,18,0,8">
                <Button x:Name="BtnOptimizar" Style="{StaticResource Accent}" Content="Optimizar ahora" Width="230" Height="50" FontSize="16"/>
                <TextBlock VerticalAlignment="Center" Margin="18,0,0,0" Style="{StaticResource Sub}" FontSize="13" Text="Tarda entre 5 y 20 minutos. Al terminar te pide reiniciar y despu&#233;s aparece el informe DESPU&#201;S."/>
              </StackPanel>
            </StackPanel>
          </ScrollViewer>

          <!-- ============ TWEAKS ============ -->
          <ScrollViewer x:Name="PgTweaks" VerticalScrollBarVisibility="Auto" Visibility="Collapsed" Padding="0,0,12,0">
            <StackPanel>
              <DockPanel>
                <Button x:Name="BtnTweaksRec" DockPanel.Dock="Right" Style="{StaticResource Lime}" Content="Activar todos los recomendados" VerticalAlignment="Top"/>
                <StackPanel>
                  <TextBlock Text="Tweaks" Style="{StaticResource H1}"/>
                  <TextBlock Text="Cada ajuste por separado. Se aplica al instante y lo pod&#233;s apagar cuando quieras: vuelve a como viene Windows." Style="{StaticResource Sub}" Margin="0,4,20,14"/>
                </StackPanel>
              </DockPanel>
              <StackPanel x:Name="ListaTweaks"/>
            </StackPanel>
          </ScrollViewer>

          <!-- ============ JUEGOS ============ -->
          <ScrollViewer x:Name="PgJuegos" VerticalScrollBarVisibility="Auto" Visibility="Collapsed" Padding="0,0,12,0">
            <StackPanel>
              <TextBlock Text="Juegos" Style="{StaticResource H1}"/>
              <TextBlock Text="Herramientas para jugar competitivo. Todo es compatible con Vanguard (VALORANT), FACEIT, Easy Anti-Cheat y BattlEye, salvo el Modo extremo." Style="{StaticResource Sub}" Margin="0,4,0,18"/>
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                <Border Style="{StaticResource Card}" Margin="0,0,8,0" x:Name="CardPartida">
                  <StackPanel>
                    <StackPanel Orientation="Horizontal">
                      <TextBlock Text="&#xE7FC;" FontFamily="Segoe MDL2 Assets" FontSize="22" Foreground="#FFC83D" VerticalAlignment="Center"/>
                      <TextBlock Text="Modo Partida" Style="{StaticResource H2}" FontSize="22" Margin="12,0,0,0"/>
                    </StackPanel>
                    <TextBlock x:Name="TxtPartida" Text="Desactivado" Foreground="#B9A8B2" FontWeight="SemiBold" Margin="0,8,0,0"/>
                    <TextBlock Text="Activalo antes de jugar: energ&#237;a al m&#225;ximo, pausa el indexado, SysMain, las descargas de Windows Update y OneDrive, y limpia la cach&#233; DNS. Al terminar, desactivalo y todo vuelve a la normalidad." Style="{StaticResource Sub}" FontSize="13" Margin="0,8,0,14"/>
                    <Button x:Name="BtnPartida" Style="{StaticResource Lime}" Content="Activar Modo Partida" Height="46"/>
                  </StackPanel>
                </Border>
                <Border Style="{StaticResource Card}" Grid.Column="1" Margin="8,0,0,0">
                  <StackPanel>
                    <TextBlock Text="Configuraci&#243;n recomendada en tus juegos" Style="{StaticResource H2}"/>
                    <StackPanel x:Name="ListaJuegos" Margin="0,10,0,0"/>
                  </StackPanel>
                </Border>
              </Grid>
              <Border Style="{StaticResource Card}" Margin="0,16,0,0">
                <StackPanel>
                  <DockPanel>
                    <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
                      <Button x:Name="BtnBoosterCargar" Style="{StaticResource Ghost}" Content="Actualizar lista" Margin="0,0,8,0"/>
                      <Button x:Name="BtnBoosterCerrar" Style="{StaticResource Accent}" Content="Cerrar seleccionados" Height="38"/>
                    </StackPanel>
                    <StackPanel>
                      <TextBlock Text="Game Booster" Style="{StaticResource H2}"/>
                      <TextBlock x:Name="TxtBooster" Text="Los programas que m&#225;s RAM usan. Marc&#225; los que quieras cerrar antes de jugar (guard&#225; lo que est&#233;s haciendo)." Style="{StaticResource Sub}" FontSize="13" Margin="0,2,16,0"/>
                    </StackPanel>
                  </DockPanel>
                  <WrapPanel x:Name="ListaBooster" Margin="0,14,0,0"/>
                </StackPanel>
              </Border>
              <UniformGrid Columns="3" Margin="0,16,0,8">
                <Border Style="{StaticResource Card}" Margin="0,0,8,0">
                  <StackPanel>
                    <TextBlock Text="Juegos en la placa dedicada" Style="{StaticResource H2}" FontSize="16"/>
                    <TextBlock Text="En laptops con dos placas de video, fuerza a tus juegos (Steam, Epic, Riot, Roblox) a usar la potente." Style="{StaticResource Sub}" FontSize="12" Margin="0,6,0,12"/>
                    <Button x:Name="BtnGPU" Style="{StaticResource Ghost}" Content="Asignar juegos"/>
                  </StackPanel>
                </Border>
                <Border Style="{StaticResource Card}" Margin="8,0,8,0">
                  <StackPanel>
                    <TextBlock Text="Arreglar parpadeos (MPO)" Style="{StaticResource H2}" FontSize="16"/>
                    <TextBlock x:Name="TxtMPO" Text="Solo si la pantalla parpadea, se pone negra un segundo o hay tirones con G-Sync. Es el arreglo que publica NVIDIA." Style="{StaticResource Sub}" FontSize="12" Margin="0,6,0,12"/>
                    <Button x:Name="BtnMPO" Style="{StaticResource Ghost}" Content="Aplicar arreglo"/>
                  </StackPanel>
                </Border>
                <Border Style="{StaticResource Card}" Margin="8,0,0,0">
                  <StackPanel>
                    <TextBlock Text="Modo competitivo extremo" Style="{StaticResource H2}" FontSize="16" Foreground="#FF8AD8"/>
                    <TextBlock x:Name="TxtComp" Text="Apaga la Integridad de memoria y la Plataforma de m&#225;quina virtual. NO compatible con VALORANT ni FACEIT." Style="{StaticResource Sub}" FontSize="12" Margin="0,6,0,12"/>
                    <Button x:Name="BtnComp" Style="{StaticResource Ghost}" Content="Aplicar"/>
                  </StackPanel>
                </Border>
              </UniformGrid>
            </StackPanel>
          </ScrollViewer>

          <!-- ============ HERRAMIENTAS ============ -->
          <ScrollViewer x:Name="PgHerramientas" VerticalScrollBarVisibility="Auto" Visibility="Collapsed" Padding="0,0,12,0">
            <StackPanel>
              <TextBlock Text="Herramientas" Style="{StaticResource H1}"/>
              <TextBlock Text="Mantenimiento y arreglos. Nada de esto toca tus archivos personales ni contrase&#241;as." Style="{StaticResource Sub}" Margin="0,4,0,18"/>
              <UniformGrid Columns="3">
                <Border Style="{StaticResource Card}" Margin="0,0,8,16">
                  <StackPanel>
                    <TextBlock Text="&#xE74D;" FontFamily="Segoe MDL2 Assets" FontSize="22" Foreground="#FF5A36"/>
                    <TextBlock Text="Limpieza profunda" Style="{StaticResource H2}" FontSize="16" Margin="0,8,0,0"/>
                    <TextBlock Text="Temporales, cach&#233; de Windows Update, reportes de error y cach&#233; de navegadores y Discord." Style="{StaticResource Sub}" FontSize="12" Margin="0,6,0,10" Height="48"/>
                    <CheckBox x:Name="ChkPapelera" Style="{StaticResource Check}" Margin="0,0,0,12"><TextBlock Text="Vaciar tambi&#233;n la Papelera" Foreground="#E2D6DC" FontSize="13"/></CheckBox>
                    <Button x:Name="BtnLimpieza" Style="{StaticResource Accent}" Content="Limpiar"/>
                  </StackPanel>
                </Border>
                <Border Style="{StaticResource Card}" Margin="8,0,8,16">
                  <StackPanel>
                    <TextBlock Text="&#xE774;" FontFamily="Segoe MDL2 Assets" FontSize="22" Foreground="#FF5A36"/>
                    <TextBlock Text="DNS m&#225;s r&#225;pido" Style="{StaticResource H2}" FontSize="16" Margin="0,8,0,0"/>
                    <TextBlock x:Name="TxtDNS" Text="Prueba Cloudflare, Google, Quad9 y el tuyo con 8 sitios y te dice cu&#225;l responde m&#225;s r&#225;pido." Style="{StaticResource Sub}" FontSize="12" Margin="0,6,0,10" Height="48"/>
                    <Button x:Name="BtnDNS" Style="{StaticResource Ghost}" Content="Probar DNS" Margin="0,0,0,8"/>
                    <Button x:Name="BtnDNSAplicar" Style="{StaticResource Accent}" Content="Usar el m&#225;s r&#225;pido" IsEnabled="False"/>
                  </StackPanel>
                </Border>
                <Border Style="{StaticResource Card}" Margin="8,0,0,16">
                  <StackPanel>
                    <TextBlock Text="&#xEDA2;" FontFamily="Segoe MDL2 Assets" FontSize="22" Foreground="#FF5A36"/>
                    <TextBlock Text="Optimizar discos" Style="{StaticResource H2}" FontSize="16" Margin="0,8,0,0"/>
                    <TextBlock Text="SSD: aplica TRIM para que siga r&#225;pido. HDD: desfragmenta si hace falta." Style="{StaticResource Sub}" FontSize="12" Margin="0,6,0,10" Height="48"/>
                    <Button x:Name="BtnDiscos" Style="{StaticResource Accent}" Content="Optimizar discos"/>
                  </StackPanel>
                </Border>
                <Border Style="{StaticResource Card}" Margin="0,0,8,16">
                  <StackPanel>
                    <TextBlock Text="&#xE895;" FontFamily="Segoe MDL2 Assets" FontSize="22" Foreground="#FF5A36"/>
                    <TextBlock Text="Actualizar programas" Style="{StaticResource H2}" FontSize="16" Margin="0,8,0,0"/>
                    <TextBlock Text="Actualiza de una vez todos los programas instalados (Chrome, Discord, Steam...)." Style="{StaticResource Sub}" FontSize="12" Margin="0,6,0,10" Height="48"/>
                    <Button x:Name="BtnActualizar" Style="{StaticResource Accent}" Content="Actualizar todo"/>
                  </StackPanel>
                </Border>
                <Border Style="{StaticResource Card}" Margin="8,0,8,16">
                  <StackPanel>
                    <TextBlock Text="&#xE90F;" FontFamily="Segoe MDL2 Assets" FontSize="22" Foreground="#FF5A36"/>
                    <TextBlock Text="Reparar Windows" Style="{StaticResource H2}" FontSize="16" Margin="0,8,0,0"/>
                    <TextBlock Text="DISM + SFC: repara archivos da&#241;ados de Windows. Tarda 10 a 30 minutos." Style="{StaticResource Sub}" FontSize="12" Margin="0,6,0,10" Height="48"/>
                    <Button x:Name="BtnReparar" Style="{StaticResource Accent}" Content="Reparar"/>
                  </StackPanel>
                </Border>
                <Border Style="{StaticResource Card}" Margin="8,0,0,16">
                  <StackPanel>
                    <TextBlock Text="&#xE81C;" FontFamily="Segoe MDL2 Assets" FontSize="22" Foreground="#FF5A36"/>
                    <TextBlock Text="Punto de restauraci&#243;n" Style="{StaticResource H2}" FontSize="16" Margin="0,8,0,0"/>
                    <TextBlock Text="Guarda una copia de la configuraci&#243;n de Windows para volver atr&#225;s si algo sale mal." Style="{StaticResource Sub}" FontSize="12" Margin="0,6,0,10" Height="48"/>
                    <Button x:Name="BtnPunto" Style="{StaticResource Accent}" Content="Crear ahora"/>
                  </StackPanel>
                </Border>
              </UniformGrid>
              <Border Style="{StaticResource Card}" Margin="0,0,0,16">
                <StackPanel>
                  <DockPanel>
                    <Button x:Name="BtnInicioCargar" DockPanel.Dock="Right" Style="{StaticResource Ghost}" Content="Cargar lista"/>
                    <StackPanel>
                      <TextBlock Text="Programas que arrancan con Windows" Style="{StaticResource H2}"/>
                      <TextBlock Text="Apag&#225; los que no uses: Windows arranca m&#225;s r&#225;pido y queda m&#225;s RAM libre. No apagues drivers de audio, video, touchpad ni el antivirus." Style="{StaticResource Sub}" FontSize="13" Margin="0,2,16,0"/>
                    </StackPanel>
                  </DockPanel>
                  <WrapPanel x:Name="ListaInicio" Margin="0,12,0,0"/>
                </StackPanel>
              </Border>
              <Border Style="{StaticResource Card}" Margin="0,0,0,8">
                <StackPanel>
                  <DockPanel>
                    <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
                      <Button x:Name="BtnBloatBuscar" Style="{StaticResource Ghost}" Content="Buscar apps" Margin="0,0,8,0"/>
                      <Button x:Name="BtnBloatQuitar" Style="{StaticResource Accent}" Content="Quitar seleccionadas" Height="38" IsEnabled="False"/>
                    </StackPanel>
                    <StackPanel>
                      <TextBlock Text="Apps basura preinstaladas" Style="{StaticResource H2}"/>
                      <TextBlock Text="Candy Crush, TikTok, Clipchamp, Solitario y similares. No se tocan la Store, Xbox, Fotos ni la Calculadora. Se reinstalan gratis desde la Store." Style="{StaticResource Sub}" FontSize="13" Margin="0,2,16,0"/>
                    </StackPanel>
                  </DockPanel>
                  <WrapPanel x:Name="ListaBloat" Margin="0,12,0,0"/>
                </StackPanel>
              </Border>
            </StackPanel>
          </ScrollViewer>

          <!-- ============ INFORMES ============ -->
          <ScrollViewer x:Name="PgInformes" VerticalScrollBarVisibility="Auto" Visibility="Collapsed" Padding="0,0,12,0">
            <StackPanel>
              <TextBlock Text="Informes" Style="{StaticResource H1}"/>
              <TextBlock Text="Cada optimizaci&#243;n deja un informe ANTES y, al reiniciar, uno DESPU&#201;S en tu Escritorio. Ideales para mostrar el resultado." Style="{StaticResource Sub}" Margin="0,4,0,18"/>
              <UniformGrid Columns="3">
                <Border Style="{StaticResource Card}" Margin="0,0,8,0">
                  <StackPanel><TextBlock Text="&#205;ndice ANTES" Foreground="#B9A8B2"/><TextBlock x:Name="TxtIdxAntes" Text="--" FontSize="44" FontWeight="Black" Foreground="#FFB020"/></StackPanel>
                </Border>
                <Border Style="{StaticResource Card}" Margin="8,0,8,0">
                  <StackPanel><TextBlock Text="&#205;ndice DESPU&#201;S" Foreground="#B9A8B2"/><TextBlock x:Name="TxtIdxDespues" Text="--" FontSize="44" FontWeight="Black" Foreground="#22E58B"/></StackPanel>
                </Border>
                <Border Style="{StaticResource Card}" Margin="8,0,0,0">
                  <StackPanel><TextBlock Text="Mejora" Foreground="#B9A8B2"/><TextBlock x:Name="TxtIdxMejora" Text="--" FontSize="44" FontWeight="Black" Foreground="#FF5A36"/></StackPanel>
                </Border>
              </UniformGrid>
              <StackPanel Orientation="Horizontal" Margin="0,16,0,16">
                <Button x:Name="BtnDiag" Style="{StaticResource Accent}" Content="Generar diagn&#243;stico ahora" Margin="0,0,10,0"/>
                <Button x:Name="BtnInformesRefrescar" Style="{StaticResource Ghost}" Content="Actualizar lista"/>
              </StackPanel>
              <Border Style="{StaticResource Card}">
                <StackPanel>
                  <TextBlock Text="Informes en tu Escritorio" Style="{StaticResource H2}"/>
                  <StackPanel x:Name="ListaInformes" Margin="0,10,0,0"/>
                </StackPanel>
              </Border>
            </StackPanel>
          </ScrollViewer>

          <!-- ============ REVERTIR ============ -->
          <ScrollViewer x:Name="PgRevertir" VerticalScrollBarVisibility="Auto" Visibility="Collapsed" Padding="0,0,12,0">
            <StackPanel>
              <TextBlock Text="Revertir" Style="{StaticResource H1}"/>
              <TextBlock Text="Deja Windows como viene de f&#225;brica en todo lo que toc&#243; OptiFrag." Style="{StaticResource Sub}" Margin="0,4,0,18"/>
              <Border Style="{StaticResource Card}" Margin="0,0,0,16">
                <StackPanel>
                  <TextBlock Text="Revertir todos los cambios de OptiFrag" Style="{StaticResource H2}"/>
                  <TextBlock Text="Vuelve el plan de energ&#237;a, los efectos visuales, la telemetr&#237;a, la red, el DNS, los ajustes de juegos y el Modo competitivo. Las apps basura que quitaste se reinstalan desde la Microsoft Store y los programas de inicio se reactivan desde Herramientas." Style="{StaticResource Sub}" FontSize="13" Margin="0,6,0,14"/>
                  <Button x:Name="BtnRevertir" Style="{StaticResource Warn}" Content="Revertir todo" Width="200" HorizontalAlignment="Left"/>
                </StackPanel>
              </Border>
              <Border Style="{StaticResource Card}">
                <StackPanel>
                  <TextBlock Text="Volver a un punto de restauraci&#243;n" Style="{StaticResource H2}"/>
                  <TextBlock Text="Antes de cada optimizaci&#243;n OptiFrag guarda un punto llamado 'OptiFrag - antes de optimizar'. Desde ac&#225; abr&#237;s la herramienta de Windows para volver a &#233;l." Style="{StaticResource Sub}" FontSize="13" Margin="0,6,0,14"/>
                  <Button x:Name="BtnRstrui" Style="{StaticResource Ghost}" Content="Abrir Restaurar sistema" Width="220" HorizontalAlignment="Left"/>
                </StackPanel>
              </Border>
            </StackPanel>
          </ScrollViewer>
        </Grid>

        <!-- ===================== ACTIVIDAD ===================== -->
        <Border Grid.Row="2" Background="#120C12" BorderBrush="#3D2230" BorderThickness="0,1,0,0">
          <Grid Margin="30,12,30,12">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <DockPanel>
              <TextBlock x:Name="TxtPct" DockPanel.Dock="Right" Foreground="#B9A8B2" FontSize="12"/>
              <TextBlock x:Name="TxtEstado" Text="Listo" FontWeight="SemiBold" FontSize="13"/>
            </DockPanel>
            <ProgressBar x:Name="Barra" Grid.Row="1" Height="5" Margin="0,8,0,0" Minimum="0" Maximum="100" Value="0" Foreground="#FF5A36" Background="#3D2230" BorderThickness="0"/>
            <TextBox x:Name="TxtLog" Grid.Row="2" Margin="0,8,0,0" IsReadOnly="True" Background="Transparent" BorderThickness="0" Foreground="#E2D6DC" FontFamily="Consolas" FontSize="12" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap"/>
          </Grid>
        </Border>
      </Grid>
    </Grid>
  </Border>
</Window>
'@

$global:VX_ENGINE = $VX_DIAG + "`n" + $VX_CORE
$global:VxPreview = ($env:VX_PREVIEW -eq '1')
$VX_URL = 'https://raw.githubusercontent.com/JuaniUTU2009/veltrix/main/optifrag.ps1'
$VX_URL_CONSOLA = 'https://raw.githubusercontent.com/JuaniUTU2009/veltrix/main/optifrag-consola.ps1'

$esAdmin = $false
try {
    $esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch {
    fltmc.exe *> $null
    $esAdmin = ($LASTEXITCODE -eq 0)
}

if ($env:VX_MODO -eq 'despues') {
    $env:VX_MODO = $null
    Invoke-Expression $global:VX_ENGINE
    Invoke-Expression $VX_DESPUES
}
elseif (-not $esAdmin -and -not $global:VxPreview) {
    Write-Host ''
    Write-Host '  OPTIFRAG: pidiendo permisos de administrador... (toca "Si")' -ForegroundColor Cyan
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm '$VX_URL' | iex`"" -ErrorAction Stop
    } catch {
        Write-Host '  No se pudieron pedir los permisos automaticamente.' -ForegroundColor Red
        Write-Host '  Clic derecho en Inicio > "Terminal (Administrador)" y pega el comando de nuevo.' -ForegroundColor Yellow
    }
}
else {
    Invoke-Expression $global:VX_ENGINE
    $global:VxSync = [hashtable]::Synchronized(@{ Busy = $false; Done = $false; Progress = -1; Result = $null; Log = (New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]') })
    $wpfOk = $true
    try { Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction Stop } catch { $wpfOk = $false }
    if (-not $wpfOk) {
        Write-Host '  Este Windows no puede mostrar la ventana de OptiFrag: se abre la version de consola.' -ForegroundColor Yellow
        irm $VX_URL_CONSOLA | iex
    } else {
        Write-Host ''
        Write-Host '  OPTIFRAG se esta abriendo... (no cierres esta ventana)' -ForegroundColor Cyan
        try {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Web -ErrorAction SilentlyContinue

    function T { param($s) return [System.Net.WebUtility]::HtmlDecode("$s") }
    function C { param($hex) return [System.Windows.Media.BrushConverter]::new().ConvertFromString($hex) }

    [xml]$xml = $VX_XAML
    $win = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xml))
    $global:VX = @{ Win = $win }
    foreach ($n in $xml.SelectNodes('//*[@*[local-name()="Name"]]')) {
        $nm = $n.Attributes | Where-Object { $_.LocalName -eq 'Name' } | Select-Object -First 1
        if ($nm) { $global:VX[$nm.Value] = $win.FindName($nm.Value) }
    }
    $VX = $global:VX
    $wa = [System.Windows.SystemParameters]::WorkArea
    if ($win.Height -gt ($wa.Height - 16)) { $win.Height = [math]::Max(560, $wa.Height - 16) }
    if ($win.Width -gt ($wa.Width - 16)) { $win.Width = [math]::Max(940, $wa.Width - 16) }
    $win.Left = $wa.Left + ($wa.Width - $win.Width) / 2
    $win.Top = $wa.Top + ($wa.Height - $win.Height) / 2

    $VX.TxtVersion.Text = "Optimizador de Windows  v$VER"
    if ($global:VxPreview) {
        $VX.TxtModo.Text = 'Vista previa (no cambia nada)'
        $VX.BadgeIcon.Foreground = (C '#FFB020')
    }

    # ---------------------------------------------------------------- actividad (log + progreso)
    $global:VxLogLines = New-Object System.Collections.Generic.List[string]
    function Add-LogLine {
        param($k, $t)
        $p = switch ($k) { 'ok' { [char]0x2714 + ' ' } 'warn' { '! ' } 'step' { [char]0x25B6 + ' ' } default { '  ' } }
        $line = "[{0}] {1}{2}" -f (Get-Date -Format 'HH:mm:ss'), $p, $t
        $global:VxLogLines.Add($line)
        if ($global:VxLogLines.Count -gt 400) { $global:VxLogLines.RemoveAt(0) }
        $VX.TxtLog.Text = ($global:VxLogLines -join "`r`n")
        $VX.TxtLog.ScrollToEnd()
        if ($k -eq 'step') { $VX.TxtEstado.Text = $t }
    }

    function Show-Msg {
        param($texto, [switch]$Pregunta, [switch]$Alerta)
        $btn = if ($Pregunta) { 'YesNo' } else { 'OK' }
        $ico = if ($Alerta) { 'Warning' } elseif ($Pregunta) { 'Question' } else { 'Information' }
        $r = [System.Windows.MessageBox]::Show($win, (T $texto), 'OptiFrag', $btn, $ico)
        return ("$r" -eq 'Yes' -or "$r" -eq 'OK')
    }

    function Test-NoPreview {
        if ($global:VxPreview) {
            Show-Msg 'Est&aacute;s en modo vista previa: este bot&oacute;n no cambia nada. Abr&iacute; OptiFrag normalmente (como administrador) para aplicar cambios.' | Out-Null
            return $false
        }
        return $true
    }

    function Start-VxJob {
        param([string]$Titulo, [string]$Codigo, [scriptblock]$AlTerminar, [switch]$Lectura)
        if ($global:VxSync.Busy) { Show-Msg 'Esper&aacute; a que termine la tarea que est&aacute; en curso.' | Out-Null; return }
        if (-not $Lectura -and -not (Test-NoPreview)) { return }
        $global:VxSync.Busy = $true
        $global:VxSync.Done = $false
        $global:VxSync.Result = $null
        $global:VxSync.Progress = -1
        $global:VxOnDone = $AlTerminar
        $VX.TxtEstado.Text = $Titulo
        $VX.TxtPct.Text = ''
        $VX.Barra.IsIndeterminate = $true
        Add-LogLine 'step' $Titulo
        $rs = [runspacefactory]::CreateRunspace()
        $rs.ApartmentState = 'STA'
        $rs.ThreadOptions = 'ReuseThread'
        $rs.Open()
        $rs.SessionStateProxy.SetVariable('VxSync', $global:VxSync)
        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        $full = $global:VX_ENGINE + "`n`$global:VxSync = `$VxSync`n`$ErrorActionPreference = 'SilentlyContinue'`ntry {`n" + $Codigo + "`n} catch { VxLog ('Error: ' + `$_.Exception.Message) 'warn' } finally { `$VxSync.Done = `$true }"
        [void]$ps.AddScript($full)
        $global:VxSync.PS = $ps
        $global:VxSync.RS = $rs
        [void]$ps.BeginInvoke()
    }

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(120)
    $timer.Add_Tick({
        $item = $null; $n = 0
        while ($n -lt 300 -and $global:VxSync.Log.TryDequeue([ref]$item)) { Add-LogLine $item[0] $item[1]; $n++ }
        if ($global:VxSync.Busy -and -not $global:VxSync.Done) {
            if ($global:VxSync.Progress -ge 0) {
                $VX.Barra.IsIndeterminate = $false
                $VX.Barra.Value = $global:VxSync.Progress
                $VX.TxtPct.Text = "$($global:VxSync.Progress) %"
            }
        }
        if ($global:VxSync.Done) {
            $global:VxSync.Done = $false
            $global:VxSync.Busy = $false
            $VX.Barra.IsIndeterminate = $false
            $VX.Barra.Value = 0
            $VX.TxtPct.Text = ''
            $VX.TxtEstado.Text = 'Listo'
            try { $global:VxSync.PS.Dispose(); $global:VxSync.RS.Close(); $global:VxSync.RS.Dispose() } catch {}
            $cb = $global:VxOnDone
            $global:VxOnDone = $null
            if ($cb) { try { & $cb $global:VxSync.Result } catch { Add-LogLine 'warn' ("Error: " + $_.Exception.Message) } }
        }
    })

    # ---------------------------------------------------------------- navegacion
    $paginas = @{ NavInicio = 'PgInicio'; NavOptimizar = 'PgOptimizar'; NavTweaks = 'PgTweaks'; NavJuegos = 'PgJuegos'; NavHerramientas = 'PgHerramientas'; NavInformes = 'PgInformes'; NavRevertir = 'PgRevertir' }
    $global:VxPaginas = $paginas
    function Show-Page {
        param($nav)
        foreach ($k in $global:VxPaginas.Keys) { $VX[$global:VxPaginas[$k]].Visibility = 'Collapsed' }
        $VX[$global:VxPaginas[$nav]].Visibility = 'Visible'
        $VX.TxtPagina.Text = "OptiFrag  /  $($VX[$nav].Content)"
        switch ($nav) {
            'NavTweaks'   { Update-Tweaks }
            'NavJuegos'   { Update-Juegos }
            'NavInformes' { Update-Informes }
        }
    }
    foreach ($k in $paginas.Keys) { $VX[$k].Add_Checked({ Show-Page $this.Name }) }

    $VX.TitleBar.Add_MouseLeftButtonDown({ try { $win.DragMove() } catch {} })
    $VX.BtnMin.Add_Click({ $win.WindowState = 'Minimized' })
    $VX.BtnClose.Add_Click({ $win.Close() })
    $win.Add_Closing({
        param($s, $e)
        if ($global:VxSync.Busy) {
            if (-not (Show-Msg 'Hay una tarea en curso. Si cerr&aacute;s ahora puede quedar a medias. &iquest;Cerrar igual?' -Pregunta -Alerta)) { $e.Cancel = $true; return }
        }
        if ((-not $global:VxPreview) -and (Test-Partida)) {
            if (Show-Msg 'El Modo Partida sigue activo. &iquest;Lo desactivo antes de cerrar?' -Pregunta) { Partida-Off }
        }
        $timer.Stop()
    })

    # ---------------------------------------------------------------- inicio (diagnostico)
    function Set-Ring {
        param([int]$v)
        $c = [math]::PI * (200 - 16) / 16
        $dc = New-Object System.Windows.Media.DoubleCollection
        $dc.Add([double]($c * $v / 100)); $dc.Add([double]1000)
        $VX.Ring.StrokeDashArray = $dc
        $col = if ($v -ge 80) { '#22E58B' } elseif ($v -ge 55) { '#FFB020' } else { '#FF4D6A' }
        $VX.Ring.Stroke = (C $col)
        $VX.TxtIndice.Text = "$v"
        $VX.TxtIndice.Foreground = (C $col)
    }
    function New-RecItem {
        param($texto, $color = '#FF5A36')
        $g = New-Object System.Windows.Controls.DockPanel
        $g.Margin = '0,0,0,10'
        $dot = New-Object System.Windows.Controls.TextBlock
        $dot.Text = [string][char]0xE73E
        $dot.FontFamily = 'Segoe MDL2 Assets'; $dot.Foreground = (C $color); $dot.FontSize = 13; $dot.Margin = '0,3,12,0'
        [System.Windows.Controls.DockPanel]::SetDock($dot, 'Left')
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = (T $texto); $tb.TextWrapping = 'Wrap'; $tb.FontSize = 14; $tb.Foreground = (C '#F2EAEE')
        [void]$g.Children.Add($dot); [void]$g.Children.Add($tb)
        return $g
    }
    function Update-Inicio {
        $VX.TxtSaludo.Text = (T 'Analizando tu equipo... (unos segundos)')
        Start-VxJob -Lectura 'Analizando el equipo' '$VxSync.Result = Get-VxMetricas' {
            param($m)
            if (-not $m) { return }
            $global:VxMetricas = $m
            Add-LogLine 'ok' ("An&aacute;lisis listo: &Iacute;ndice OptiFrag $($m.Indice)/100" | ForEach-Object { T $_ })
            Set-Ring $m.Indice
            $estado = if ($m.Indice -ge 80) { 'Tu PC est&aacute; en muy buen estado.' } elseif ($m.Indice -ge 55) { 'Tu PC puede rendir bastante m&aacute;s.' } else { 'Tu PC necesita una optimizaci&oacute;n.' }
            $VX.TxtSaludo.Text = (T "$($m.Equipo)  &middot;  $estado")
            $VX.TxtIndiceDesc.Text = (T "RAM en uso $($m.RamPct)%, $($m.Procesos) procesos, $($m.Inicio) $(if ($m.Inicio -eq 1) { 'programa' } else { 'programas' }) al inicio y $($m.BasuraMB) MB de basura.")
            $VX.InfoCPU.Text = $m.CPU
            $VX.InfoGPU.Text = $m.GPU + $(if ($m.GpuTemp -ne $null) { "`n$($m.GpuTemp) C ahora" } else { '' })
            $VX.InfoRAM.Text = (T ("{0} GB  &middot;  {1} m&oacute;dulo(s)  &middot;  {2} MHz`n{3}% en uso" -f $m.RamTotal, $m.RamModulos, $m.RamVel, $m.RamPct))
            $VX.InfoDisco.Text = (T ("{0}  &middot;  {1} GB libres de {2} GB" -f $m.Disco, $m.LibreGB, $m.TotalGB))
            $bat = if ($m.Bateria -ne $null) { (T "  &middot;  bater&iacute;a $($m.Bateria)%") } else { '' }
            $VX.InfoPantalla.Text = "$($m.Hz) Hz$bat`n" + $(if ($m.DiscoProblema) { 'Un disco reporta problemas' } else { 'Discos en buen estado' })
            $arr = if ($m.Arranque) { (T "  &middot;  arranca en $($m.Arranque) s") } else { '' }
            $VX.InfoWin.Text = ($m.Windows -replace 'Microsoft ', '') + $arr
            $VX.ListaRec.Children.Clear()
            foreach ($r in (Get-VxRecomendaciones $m)) { [void]$VX.ListaRec.Children.Add((New-RecItem $r)) }
            if ($m.Laptop) { $VX.OptLaptop.IsChecked = $true } else { $VX.OptPC.IsChecked = $true }
            Update-JuegosTips
        }
    }
    $VX.BtnReanalizar.Add_Click({ Update-Inicio })
    $VX.BtnIrOptimizar.Add_Click({ $VX.NavOptimizar.IsChecked = $true })

    # ---------------------------------------------------------------- optimizar
    $global:VxModulos = @(
        @('antes', 'Informe ANTES en el Escritorio', 'Mide el equipo y guarda el &Iacute;ndice OptiFrag inicial.'),
        @('restaurar', 'Punto de restauraci&oacute;n', 'Copia de seguridad de la configuraci&oacute;n de Windows.'),
        @('visual', 'Efectos visuales', 'Sin animaciones ni transparencias. Letras siempre n&iacute;tidas.'),
        @('fondo', 'Publicidad y segundo plano', 'Sin anuncios, widgets, Bing en Inicio ni demoras al arrancar.'),
        @('telemetria', 'Telemetr&iacute;a y privacidad', 'Menos datos a Microsoft, sin Copilot ni Recall.'),
        @('energia', 'Energ&iacute;a', 'PC: m&aacute;ximo rendimiento. Laptop: rendimiento enchufada, ahorro a bater&iacute;a.'),
        @('juegos', 'Juegos', 'Modo juego, sin grabaci&oacute;n Xbox, HAGS, prioridad a juegos, mouse 1:1.'),
        @('gpu', 'Placa de video dedicada', 'En laptops con dos placas, tus juegos usan la potente.'),
        @('latencia', 'Latencia', 'Prioridad a la ventana activa, timers precisos, menos input lag.'),
        @('red', 'Red', 'Sin Nagle, IPv4 preferido, sin subidas ocultas, placa de red sin ahorro (PC).'),
        @('avanzado', 'Disco, memoria y sistema', 'TRIM, NTFS, servicios in&uacute;tiles, b&uacute;squeda cl&aacute;sica, Windows Update sin reinicios.'),
        @('limpieza', 'Limpieza', 'Temporales, cach&eacute; de Windows Update y componentes viejos.'),
        @('despues', 'Informe DESPU&Eacute;S autom&aacute;tico', 'Al reiniciar, aparece el informe con la comparaci&oacute;n en tu Escritorio.')
    )
    $global:VxChkModulos = @{}
    foreach ($mo in $global:VxModulos) {
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Style = $win.FindResource('Check')
        $cb.IsChecked = $true
        $cb.Width = 420
        $cb.Margin = '0,0,18,14'
        $sp = New-Object System.Windows.Controls.StackPanel
        $t1 = New-Object System.Windows.Controls.TextBlock; $t1.Text = (T $mo[1]); $t1.FontSize = 14; $t1.FontWeight = 'SemiBold'; $t1.Foreground = (C '#FFFFFF')
        $t2 = New-Object System.Windows.Controls.TextBlock; $t2.Text = (T $mo[2]); $t2.FontSize = 12; $t2.Foreground = (C '#B9A8B2'); $t2.TextWrapping = 'Wrap'; $t2.Width = 380
        [void]$sp.Children.Add($t1); [void]$sp.Children.Add($t2)
        $cb.Content = $sp
        [void]$VX.ListaModulos.Children.Add($cb)
        $global:VxChkModulos[$mo[0]] = $cb
    }
    $VX.OptPC.IsChecked = $true
    $VX.BtnOptimizar.Add_Click({
        if (-not (Test-NoPreview)) { return }
        $sel = @($global:VxModulos | Where-Object { $global:VxChkModulos[$_[0]].IsChecked } | ForEach-Object { $_[0] })
        if ($sel.Count -eq 0) { Show-Msg 'Marc&aacute; al menos un paso.' | Out-Null; return }
        $lap = [bool]$VX.OptLaptop.IsChecked
        $tipo = if ($lap) { 'LAPTOP' } else { 'PC DE ESCRITORIO' }
        if (-not (Show-Msg "Se va a optimizar este equipo como $tipo ($($sel.Count) pasos).`n`nCerr&aacute; los juegos y programas pesados. &iquest;Empezar?" -Pregunta)) { return }
        $lista = "'" + ($sel -join "','") + "'"
        Start-VxJob 'Optimizando el equipo' "`$VxSync.Result = Job-Optimizar -Laptop `$$lap -Modulos @($lista)" {
            param($r)
            $txt = 'Optimizaci&oacute;n completa'
            if ($r) { $txt += " en $($r.Minutos) min, con $($r.GB) GB liberados" }
            $txt += '.<br>'
            $txt = $txt -replace '<br>', "`n`n"
            if (Show-Msg ($txt + 'Hay que reiniciar para aplicar todo. En unos minutos despu&eacute;s del reinicio aparece el informe DESPU&Eacute;S en tu Escritorio.' + "`n`n" + '&iquest;Reiniciar ahora?') -Pregunta) {
                shutdown.exe /r /t 5 /c "OptiFrag: reiniciando para aplicar la optimizacion"
            }
        }
    })

    # ---------------------------------------------------------------- tweaks
    $global:VxTweakChk = @{}
    $global:VxTweakBusy = $false
    function New-Badge {
        param($txt, $bg, $fg)
        $b = New-Object System.Windows.Controls.Border
        $b.Background = (C $bg); $b.CornerRadius = '6'; $b.Padding = '8,2'; $b.Margin = '0,0,6,0'
        $t = New-Object System.Windows.Controls.TextBlock; $t.Text = $txt; $t.FontSize = 11; $t.FontWeight = 'SemiBold'; $t.Foreground = (C $fg)
        $b.Child = $t
        return $b
    }
    $cats = @(
        @('Rendimiento', '&#xE945;', 'Rendimiento general'),
        @('Juegos', '&#xE7FC;', 'Juegos y latencia'),
        @('Red', '&#xE774;', 'Red'),
        @('Privacidad', '&#xE72E;', 'Privacidad y publicidad'),
        @('Sistema', '&#xE713;', 'Sistema y utilidades')
    )
    foreach ($ct in $cats) {
        $h = New-Object System.Windows.Controls.TextBlock
        $h.FontSize = 17; $h.FontWeight = 'SemiBold'; $h.Foreground = (C '#FF5A36'); $h.Margin = '0,8,0,10'
        $r1 = New-Object System.Windows.Documents.Run (T $ct[1]); $r1.FontFamily = 'Segoe MDL2 Assets'
        $r2 = New-Object System.Windows.Documents.Run ('   ' + (T $ct[2]))
        $h.Inlines.Add($r1); $h.Inlines.Add($r2)
        [void]$VX.ListaTweaks.Children.Add($h)
        $wp = New-Object System.Windows.Controls.WrapPanel
        $wp.Margin = '0,0,0,10'
        foreach ($tw in ($VX_TWEAKS | Where-Object { $_.Cat -eq $ct[0] })) {
            $card = New-Object System.Windows.Controls.Border
            $card.Style = $win.FindResource('Card'); $card.Width = 430; $card.Margin = '0,0,12,12'; $card.Padding = '18,14'
            $dp = New-Object System.Windows.Controls.DockPanel
            $sw = New-Object System.Windows.Controls.CheckBox
            $sw.Style = $win.FindResource('Switch'); $sw.Tag = $tw.Id; $sw.VerticalAlignment = 'Center'; $sw.Margin = '14,0,0,0'
            [System.Windows.Controls.DockPanel]::SetDock($sw, 'Right')
            $sp = New-Object System.Windows.Controls.StackPanel
            $t1 = New-Object System.Windows.Controls.TextBlock; $t1.Text = (T $tw.Nombre); $t1.FontSize = 15; $t1.FontWeight = 'SemiBold'; $t1.TextWrapping = 'Wrap'
            $t2 = New-Object System.Windows.Controls.TextBlock; $t2.Text = (T $tw.Desc); $t2.FontSize = 12; $t2.Foreground = (C '#B9A8B2'); $t2.TextWrapping = 'Wrap'; $t2.Margin = '0,4,0,8'
            $bd = New-Object System.Windows.Controls.WrapPanel
            $impCol = switch ($tw.Imp) { 'Alto' { @('#12402C', '#22E58B') } 'Medio' { @('#3D3410', '#FFD25A') } default { @('#2A1A22', '#B9A8B2') } }
            [void]$bd.Children.Add((New-Badge ("Impacto " + $tw.Imp.ToLower()) $impCol[0] $impCol[1]))
            if ($tw.Solo -eq 'PC') { [void]$bd.Children.Add((New-Badge 'Solo PC de escritorio' '#2A1E44' '#C9B6FF')) }
            [void]$bd.Children.Add((New-Badge 'Reversible' '#2A1820' '#FFB199'))
            [void]$sp.Children.Add($t1); [void]$sp.Children.Add($t2); [void]$sp.Children.Add($bd)
            [void]$dp.Children.Add($sw); [void]$dp.Children.Add($sp)
            $card.Child = $dp
            [void]$wp.Children.Add($card)
            $global:VxTweakChk[$tw.Id] = $sw
            $sw.Add_Click({
                if ($global:VxTweakBusy) { return }
                $id = $this.Tag
                $tw2 = $VX_TWEAKS | Where-Object { $_.Id -eq $id } | Select-Object -First 1
                if ($global:VxPreview) { Test-NoPreview | Out-Null; Update-Tweaks; return }
                $on = [bool]$this.IsChecked
                Invoke-Tweak $tw2 $on $this
            })
        }
        [void]$VX.ListaTweaks.Children.Add($wp)
    }
    $global:VxTweakPedido = @{}
    function Get-TweakEstado {
        param($tw)
        $st = $false
        try { $st = [bool](& $tw.State) } catch {}
        if ($global:VxTweakPedido.ContainsKey($tw.Id)) {
            $p = $global:VxTweakPedido[$tw.Id]
            if ($p -eq $st) { $global:VxTweakPedido.Remove($tw.Id) } else { $st = $p }
        }
        return $st
    }
    function Invoke-Tweak {
        param($tw, [bool]$on, $sw)
        $global:VxTweakBusy = $true
        $sw.IsEnabled = $false
        $win.Dispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
        $global:VxUltimoAviso = $null
        $err = $null
        try { if ($on) { & $tw.On } else { & $tw.Off } } catch { $err = $_.Exception.Message }
        $st = $false
        try { $st = [bool](& $tw.State) } catch {}
        $nom = T $tw.Nombre
        if ($err) {
            Add-LogLine 'warn' ("$nom" + ': no se pudo cambiar (' + $err + ')')
            $sw.IsChecked = -not $on
        } elseif ($st -eq $on) {
            $global:VxTweakPedido.Remove($tw.Id)
            Add-LogLine 'ok' ($nom + $(if ($on) { ': activado' } else { ': desactivado (como viene Windows)' }))
            $sw.IsChecked = $on
        } elseif ($on -and $global:VxUltimoAviso) {
            $sw.IsChecked = $false
        } else {
            $global:VxTweakPedido[$tw.Id] = $on
            Add-LogLine 'ok' ($nom + $(if ($on) { ': activado' } else { ': desactivado' }) + (T ' (se termina de aplicar al reiniciar)'))
            $sw.IsChecked = $on
        }
        $sw.IsEnabled = $true
        $global:VxTweakBusy = $false
    }
    function Update-Tweaks {
        $global:VxTweakBusy = $true
        foreach ($tw in $VX_TWEAKS) { $global:VxTweakChk[$tw.Id].IsChecked = (Get-TweakEstado $tw) }
        $global:VxTweakBusy = $false
    }
    $VX.BtnTweaksRec.Add_Click({
        if (-not (Test-NoPreview)) { return }
        if (-not (Show-Msg 'Se activan todos los tweaks recomendados de esta p&aacute;gina (los de PC de escritorio solo si este equipo no es laptop). &iquest;Seguir?' -Pregunta)) { return }
        $lap = ($global:VxMetricas -and $global:VxMetricas.Laptop)
        foreach ($tw in $VX_TWEAKS) {
            if ($lap -and $tw.Solo -eq 'PC') { continue }
            if (-not (Get-TweakEstado $tw)) { Invoke-Tweak $tw $true $global:VxTweakChk[$tw.Id] }
        }
        Show-Msg 'Listo. Algunos cambios necesitan reiniciar la PC para notarse.' | Out-Null
    })

    # ---------------------------------------------------------------- juegos
    function Update-JuegosTips {
        $VX.ListaJuegos.Children.Clear()
        $m = $global:VxMetricas
        $tips = @()
        if ($m -and $m.Juegos -contains 'VALORANT') { $tips += 'VALORANT: pantalla completa, NVIDIA Reflex en &quot;Activado&quot; (el modo + Boost a veces baja FPS), Raw Input Buffer activado, Renderizado multihilo activado y sombras en bajo.' }
        if ($m -and $m.Juegos -contains 'CS2') { $tips += 'CS2: pantalla completa, NVIDIA Reflex activado, &quot;Aumentar contraste de jugadores&quot; activado, V-Sync apagado y un l&iacute;mite de FPS estable (fps_max).' }
        if ($m -and $m.Juegos -contains 'Fortnite') { $tips += 'Fortnite: en PCs de pocos recursos, modo de renderizado &quot;Rendimiento&quot;; con buena placa, DirectX 12. NVIDIA Reflex activado y V-Sync apagado.' }
        if ($tips.Count -eq 0) { $tips += 'No encontramos VALORANT, CS2 ni Fortnite instalados. En cualquier juego competitivo: pantalla completa, V-Sync apagado, NVIDIA Reflex activado y el monitor a su m&aacute;xima frecuencia (Hz).' }
        if ($m -and $m.GPU -match 'NVIDIA|GeForce|RTX|GTX') { $tips += 'Panel de control de NVIDIA &gt; Configuraci&oacute;n 3D: Modo de baja latencia en &quot;Activado&quot; (o &quot;Ultra&quot; en juegos sin Reflex), Administraci&oacute;n de energ&iacute;a en &quot;M&aacute;ximo rendimiento preferido&quot; y Sincronizaci&oacute;n vertical apagada.' }
        $tips += 'Mouse: 1000 Hz de polling rate alcanza. 4000 u 8000 Hz casi no se notan y en PCs justas pueden bajar FPS.'
        $tips += 'Siempre: la pantalla a su m&aacute;xima frecuencia en Configuraci&oacute;n &gt; Pantalla &gt; Pantalla avanzada, y drivers de la placa de video al d&iacute;a.'
        foreach ($t in $tips) { [void]$VX.ListaJuegos.Children.Add((New-RecItem $t '#FFC83D')) }
    }
    function Update-Juegos {
        $act = $false
        try { $act = Test-Partida } catch {}
        if ($act) {
            $VX.TxtPartida.Text = 'ACTIVADO'; $VX.TxtPartida.Foreground = (C '#FFC83D')
            $VX.BtnPartida.Content = 'Desactivar Modo Partida'
        } else {
            $VX.TxtPartida.Text = 'Desactivado'; $VX.TxtPartida.Foreground = (C '#B9A8B2')
            $VX.BtnPartida.Content = 'Activar Modo Partida'
        }
        $VX.BtnMPO.Content = if (Test-MPOFix) { 'Quitar arreglo' } else { 'Aplicar arreglo' }
        $ac = @(Get-VxAnticheat)
        if ($ac.Count -gt 0) {
            $VX.BtnComp.IsEnabled = $false
            $VX.TxtComp.Text = (T "Bloqueado: esta PC tiene $($ac -join ' y '). Ese anticheat necesita las protecciones que este modo apaga. Us&aacute; el Modo Partida.")
        }
        Update-JuegosTips
    }
    $VX.BtnPartida.Add_Click({
        if (-not (Test-NoPreview)) { return }
        if (Test-Partida) { Start-VxJob 'Desactivando Modo Partida' 'Partida-Off' { Update-Juegos } }
        else { Start-VxJob 'Activando Modo Partida' 'Partida-On' { Update-Juegos; Load-Booster } }
    })
    $global:VxBoostChk = @()
    function Load-Booster {
        Start-VxJob -Lectura 'Buscando programas que usan mucha RAM' '$VxSync.Result = Get-TopProcesos' {
            param($lst)
            $VX.ListaBooster.Children.Clear()
            $global:VxBoostChk = @()
            foreach ($p in @($lst)) {
                $cb = New-Object System.Windows.Controls.CheckBox
                $cb.Style = $win.FindResource('Check'); $cb.Tag = $p.Nombre; $cb.Width = 270; $cb.Margin = '0,0,14,12'
                $tb = New-Object System.Windows.Controls.TextBlock
                $tb.Text = ("{0}   {1:N0} MB" -f $p.Nombre, $p.MB); $tb.Foreground = (C '#F2EAEE'); $tb.FontSize = 13
                $cb.Content = $tb
                [void]$VX.ListaBooster.Children.Add($cb)
                $global:VxBoostChk += $cb
            }
        }
    }
    $VX.BtnBoosterCargar.Add_Click({ Load-Booster })
    $VX.BtnBoosterCerrar.Add_Click({
        $sel = @($global:VxBoostChk | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag })
        if ($sel.Count -eq 0) { Show-Msg 'Marc&aacute; los programas que quieras cerrar.' | Out-Null; return }
        if (-not (Show-Msg ("Se cierran sin preguntar: " + ($sel -join ', ') + ". &iquest;Seguir?") -Pregunta)) { return }
        $lista = "'" + (($sel | ForEach-Object { $_ -replace "'", "''" }) -join "','") + "'"
        Start-VxJob 'Cerrando programas' "Stop-Procesos -Nombres @($lista)" { Load-Booster }
    })
    $VX.BtnGPU.Add_Click({ Start-VxJob 'Asignando juegos a la placa dedicada' 'M-GPU' $null })
    $VX.BtnMPO.Add_Click({
        if (-not (Test-NoPreview)) { return }
        if (Test-MPOFix) { Start-VxJob 'Quitando arreglo de MPO' 'Set-MPOFix -On $false' { Update-Juegos } }
        else {
            if (-not (Show-Msg 'Us&aacute; este arreglo solo si ten&eacute;s parpadeos, pantallazos negros o tirones con G-Sync o dos monitores. &iquest;Aplicarlo?' -Pregunta)) { return }
            Start-VxJob 'Aplicando arreglo de MPO' 'Set-MPOFix -On $true' { Update-Juegos }
        }
    })
    $VX.BtnComp.Add_Click({
        if (-not (Test-NoPreview)) { return }
        if (-not (Show-Msg 'El Modo competitivo extremo apaga la Integridad de memoria (una capa extra de seguridad contra malware avanzado) y la Plataforma de m&aacute;quina virtual si no se usa. Windows Defender sigue funcionando. Recomendado solo para PCs de juego sin VALORANT ni FACEIT. &iquest;Aplicar?' -Pregunta -Alerta)) { return }
        Start-VxJob 'Aplicando modo competitivo extremo' 'Job-Competitivo' {
            if (Show-Msg 'Hay que reiniciar para que tome efecto. &iquest;Reiniciar ahora?' -Pregunta) { shutdown.exe /r /t 5 }
        }
    })

    # ---------------------------------------------------------------- herramientas
    $VX.BtnLimpieza.Add_Click({
        $pap = [bool]$VX.ChkPapelera.IsChecked
        Start-VxJob 'Limpieza profunda' "`$VxSync.Result = Job-LimpiezaProfunda -Papelera `$$pap" {
            param($gb)
            Show-Msg ("Limpieza terminada: liberaste {0} GB." -f $gb) | Out-Null
        }
    })
    $global:VxDNSMejor = $null
    $VX.BtnDNS.Add_Click({
        $VX.TxtDNS.Text = 'Probando...'
        Start-VxJob -Lectura 'Probando servidores DNS' '$VxSync.Result = Test-DNSOptiFrag' {
            param($res)
            $res = @($res)
            if ($res.Count -eq 0) { $VX.TxtDNS.Text = 'No se pudo probar (sin internet?)'; return }
            $VX.TxtDNS.Text = (($res | ForEach-Object { "{0}: {1} ms" -f $_.N, $_.Ms }) -join "`n")
            $mejor = $res[0]
            if ($mejor.N -like 'Actual*') { $global:VxDNSMejor = $null; $VX.BtnDNSAplicar.IsEnabled = $false; $VX.BtnDNSAplicar.Content = (T 'Tu DNS ya es el m&aacute;s r&aacute;pido') }
            else { $global:VxDNSMejor = $mejor; $VX.BtnDNSAplicar.IsEnabled = $true; $VX.BtnDNSAplicar.Content = "Usar $($mejor.N)" }
        }
    })
    $VX.BtnDNSAplicar.Add_Click({
        if (-not $global:VxDNSMejor) { return }
        $dirs = "'" + ($global:VxDNSMejor.A -join "','") + "'"
        $nom = $global:VxDNSMejor.N
        Start-VxJob "Cambiando DNS a $nom" "Set-DNSOptiFrag -Direcciones @($dirs); Listo 'DNS cambiado a $nom'" { $VX.BtnDNSAplicar.IsEnabled = $false }
    })
    $VX.BtnDiscos.Add_Click({ Start-VxJob 'Optimizando discos' 'Job-Discos' $null })
    $VX.BtnActualizar.Add_Click({
        if (-not (Show-Msg 'Se actualizan todos los programas. Los que est&eacute;n abiertos pueden cerrarse solos. &iquest;Seguir?' -Pregunta)) { return }
        Start-VxJob 'Actualizando programas' 'Job-Actualizar' $null
    })
    $VX.BtnReparar.Add_Click({
        if (-not (Show-Msg 'La reparaci&oacute;n tarda entre 10 y 30 minutos. No apagues la PC mientras corre. &iquest;Empezar?' -Pregunta)) { return }
        Start-VxJob 'Reparando Windows' 'Job-Reparar' { Show-Msg 'Reparaci&oacute;n terminada. Reinici&aacute; la PC para completar.' | Out-Null }
    })
    $VX.BtnPunto.Add_Click({ Start-VxJob 'Creando punto de restauracion' 'Job-PuntoRestauracion' $null })

    $VX.BtnInicioCargar.Add_Click({
        $VX.ListaInicio.Children.Clear()
        $lst = @()
        try { $lst = @(Get-Inicio) } catch {}
        if ($lst.Count -eq 0) {
            $tb = New-Object System.Windows.Controls.TextBlock; $tb.Text = 'No hay programas de inicio.'; $tb.Foreground = (C '#B9A8B2')
            [void]$VX.ListaInicio.Children.Add($tb); return
        }
        foreach ($e in $lst) {
            $row = New-Object System.Windows.Controls.Border
            $row.Background = (C '#2A1820'); $row.CornerRadius = '10'; $row.Padding = '14,10'; $row.Margin = '0,0,10,10'; $row.Width = 300
            $dp = New-Object System.Windows.Controls.DockPanel
            $sw = New-Object System.Windows.Controls.CheckBox
            $sw.Style = $win.FindResource('Switch'); $sw.IsChecked = $e.Activo; $sw.Tag = $e
            [System.Windows.Controls.DockPanel]::SetDock($sw, 'Right')
            $tb = New-Object System.Windows.Controls.TextBlock
            $tb.Text = $e.Nombre; $tb.VerticalAlignment = 'Center'; $tb.TextTrimming = 'CharacterEllipsis'; $tb.FontSize = 13
            [void]$dp.Children.Add($sw); [void]$dp.Children.Add($tb)
            $row.Child = $dp
            $sw.Add_Click({
                $e2 = $this.Tag
                if ($global:VxPreview) { Test-NoPreview | Out-Null; $this.IsChecked = $e2.Activo; return }
                $quiere = [bool]$this.IsChecked
                try {
                    Set-InicioEstado -Ap $e2.Ap -Nombre $e2.Nombre -Activo $quiere
                    $e2.Activo = $quiere
                    $this.IsChecked = $quiere
                    Add-LogLine 'ok' ("{0}: {1} al iniciar Windows" -f $e2.Nombre, $(if ($quiere) { 'se abre' } else { 'ya no se abre' }))
                } catch {
                    $this.IsChecked = $e2.Activo
                    Add-LogLine 'warn' ("{0}: no se pudo cambiar" -f $e2.Nombre)
                }
            })
            [void]$VX.ListaInicio.Children.Add($row)
        }
    })

    $global:VxBloatChk = @()
    $VX.BtnBloatBuscar.Add_Click({
        Start-VxJob -Lectura 'Buscando apps basura' '$VxSync.Result = Get-Bloat' {
            param($lst)
            $VX.ListaBloat.Children.Clear()
            $global:VxBloatChk = @()
            $lst = @($lst)
            if ($lst.Count -eq 0) {
                $tb = New-Object System.Windows.Controls.TextBlock; $tb.Text = 'Este equipo no tiene apps basura conocidas.'; $tb.Foreground = (C '#22E58B')
                [void]$VX.ListaBloat.Children.Add($tb); $VX.BtnBloatQuitar.IsEnabled = $false; return
            }
            foreach ($a in $lst) {
                $cb = New-Object System.Windows.Controls.CheckBox
                $cb.Style = $win.FindResource('Check'); $cb.Tag = $a.Full; $cb.IsChecked = $true; $cb.Width = 300; $cb.Margin = '0,0,12,12'
                $tb = New-Object System.Windows.Controls.TextBlock; $tb.Text = ($a.Nombre -replace '^Microsoft\.', ''); $tb.Foreground = (C '#F2EAEE'); $tb.FontSize = 13
                $cb.Content = $tb
                [void]$VX.ListaBloat.Children.Add($cb)
                $global:VxBloatChk += $cb
            }
            $VX.BtnBloatQuitar.IsEnabled = $true
        }
    })
    $VX.BtnBloatQuitar.Add_Click({
        $sel = @($global:VxBloatChk | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag })
        if ($sel.Count -eq 0) { return }
        if (-not (Show-Msg "Se quitan $($sel.Count) apps. Se pueden reinstalar gratis desde la Microsoft Store. &iquest;Seguir?" -Pregunta)) { return }
        $lista = "'" + ($sel -join "','") + "'"
        Start-VxJob 'Quitando apps basura' "Remove-Bloat -Full @($lista)" { $VX.ListaBloat.Children.Clear(); $VX.BtnBloatQuitar.IsEnabled = $false }
    })

    # ---------------------------------------------------------------- informes
    function Update-Informes {
        $fa = Join-Path $VXDIR 'antes.json'; $fd = Join-Path $VXDIR 'despues.json'
        $a = $null; $d = $null
        if (Test-Path $fa) { try { $a = Get-Content $fa -Raw | ConvertFrom-Json } catch {} }
        if (Test-Path $fd) { try { $d = Get-Content $fd -Raw | ConvertFrom-Json } catch {} }
        $VX.TxtIdxAntes.Text = if ($a) { "$($a.Indice)" } else { '--' }
        $VX.TxtIdxDespues.Text = if ($d) { "$($d.Indice)" } else { '--' }
        $VX.TxtIdxMejora.Text = if ($a -and $d) { $x = $d.Indice - $a.Indice; $(if ($x -gt 0) { "+$x" } else { "$x" }) } else { '--' }
        $VX.ListaInformes.Children.Clear()
        $fs = @(Get-ChildItem (Get-Escritorio) -Filter 'OptiFrag_*.html' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 12)
        if ($fs.Count -eq 0) {
            $tb = New-Object System.Windows.Controls.TextBlock; $tb.Text = 'Todav&iacute;a no hay informes. Gener&aacute; un diagn&oacute;stico o hac&eacute; una optimizaci&oacute;n.'; $tb.Text = (T $tb.Text); $tb.Foreground = (C '#B9A8B2')
            [void]$VX.ListaInformes.Children.Add($tb); return
        }
        foreach ($f in $fs) {
            $dp = New-Object System.Windows.Controls.DockPanel; $dp.Margin = '0,0,0,8'
            $b = New-Object System.Windows.Controls.Button; $b.Style = $win.FindResource('Ghost'); $b.Content = 'Abrir'; $b.Tag = $f.FullName; $b.Height = 32
            [System.Windows.Controls.DockPanel]::SetDock($b, 'Right')
            $b.Add_Click({ Start-Process $this.Tag })
            $tb = New-Object System.Windows.Controls.TextBlock; $tb.Text = ("{0}   ({1})" -f $f.BaseName, $f.LastWriteTime.ToString('dd/MM HH:mm')); $tb.VerticalAlignment = 'Center'; $tb.FontSize = 13
            [void]$dp.Children.Add($b); [void]$dp.Children.Add($tb)
            [void]$VX.ListaInformes.Children.Add($dp)
        }
    }
    $VX.BtnInformesRefrescar.Add_Click({ Update-Informes })
    $VX.BtnDiag.Add_Click({
        $codDiag = '$a = $null; $fa = Join-Path $VXDIR ''antes.json''; if (Test-Path $fa) { $a = Get-Content $fa -Raw | ConvertFrom-Json }; $m = Get-VxMetricas; $VxSync.Result = Write-VxInforme -M $m -Antes $a -Etiqueta ''DIAGNOSTICO'' -Abrir $false'
        Start-VxJob -Lectura 'Generando diagnostico' $codDiag {
            param($f)
            if ($f -and (Test-Path $f)) { Start-Process $f }
            Update-Informes
        }
    })

    # ---------------------------------------------------------------- revertir
    $VX.BtnRevertir.Add_Click({
        if (-not (Test-NoPreview)) { return }
        if (-not (Show-Msg 'Se deshacen todos los cambios de OptiFrag y Windows queda como viene de f&aacute;brica en esos ajustes. &iquest;Seguir?' -Pregunta -Alerta)) { return }
        Start-VxJob 'Revirtiendo cambios' 'Partida-Off; Job-Revertir' {
            if (Show-Msg 'Cambios revertidos. Hay que reiniciar para terminar. &iquest;Reiniciar ahora?' -Pregunta) { shutdown.exe /r /t 5 }
        }
    })
    $VX.BtnRstrui.Add_Click({ Start-Process rstrui.exe })

    # ---------------------------------------------------------------- arranque
    $win.Add_ContentRendered({
        $timer.Start()
        try {
            Add-Type -Namespace VxNat -Name Win -MemberDefinition '[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow(); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);' -ErrorAction Stop
            $hc = [VxNat.Win]::GetConsoleWindow()
            if ($hc -ne [IntPtr]::Zero) { [void][VxNat.Win]::ShowWindow($hc, 6) }
        } catch {}
        $win.Activate() | Out-Null
        Add-LogLine 'ok' "OptiFrag $VER listo"
        if ($global:VxPreview) { Add-LogLine 'warn' 'Modo vista previa: podes recorrer todo, pero los botones que cambian cosas estan bloqueados.' }
        Update-Inicio
    })
    [void]$win.ShowDialog()
        } catch {
            Write-Host ''
            Write-Host ('  Error al abrir la ventana: ' + $_.Exception.Message) -ForegroundColor Red
            Write-Host '  Se abre la version de consola.' -ForegroundColor Yellow
            irm $VX_URL_CONSOLA | iex
        }
    }
}
