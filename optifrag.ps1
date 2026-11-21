# =====================================================================
#  OPTIFRAG - Optimizador de Windows
#  Uso (PowerShell):  irm https://raw.githubusercontent.com/JuaniUTU2009/veltrix/main/optifrag.ps1 | iex
#  Necesita una licencia: email + codigo de compra de Hotmart.
# =====================================================================

$OF_URL = 'https://raw.githubusercontent.com/JuaniUTU2009/veltrix/main/optifrag.ps1'
$OF_LIC = 'https://script.google.com/macros/s/AKfycbwTzL9dk315_KunmQ8yCLgbpChvseqEga2Avc_XV7lFDV7JXaV9cI3RtYiaW-9-bKgoNw/exec'
$OF_DIR = Join-Path $env:ProgramData 'OptiFrag'
$OF_FILE = Join-Path $OF_DIR 'licencia.json'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

function OF-Admin {
    try { return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
    catch { fltmc.exe *> $null; return ($LASTEXITCODE -eq 0) }
}

function OF-Hw {
    $g = ''
    try { $g = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Cryptography' -ErrorAction Stop).MachineGuid } catch {}
    try { $g += '|' + (Get-CimInstance Win32_ComputerSystemProduct -ErrorAction Stop).UUID } catch {}
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $b = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes("optifrag|$g"))
    return (($b | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 40)
}

function OF-Get {
    param([hashtable]$q)
    $s = ($q.GetEnumerator() | ForEach-Object { $_.Key + '=' + [uri]::EscapeDataString([string]$_.Value) }) -join '&'
    return Invoke-RestMethod -Uri ($OF_LIC + '?' + $s) -UseBasicParsing -TimeoutSec 60
}

function OF-Leer { if (Test-Path $OF_FILE) { try { return (Get-Content $OF_FILE -Raw | ConvertFrom-Json) } catch {} }; return $null }

function OF-Guardar {
    param($lic)
    if (-not (Test-Path $OF_DIR)) { New-Item -ItemType Directory -Path $OF_DIR -Force | Out-Null }
    $lic | ConvertTo-Json | Set-Content -Path $OF_FILE -Encoding UTF8
}

function OF-App {
    param($lic, $hw)
    try {
        $codigo = OF-Get @{ a = 'app'; tx = $lic.tx; hw = $hw; t = $lic.t }
        $codigo = [string]$codigo
        if ($codigo.StartsWith('#OPTIFRAG_ERROR')) { return @{ ok = $false; msg = $codigo.Substring(16) } }
        if ($codigo.Length -lt 1000) { return @{ ok = $false; msg = 'No se pudo descargar OptiFrag. Revisa tu internet.' } }
        return @{ ok = $true; codigo = $codigo }
    } catch {
        return @{ ok = $false; msg = 'No se pudo conectar con el servidor de licencias. Revisa tu internet y proba de nuevo.' }
    }
}

function OF-Ventana {
    param($hw, $msgInicial)
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
    $xaml = '<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="OptiFrag" WindowStyle="None" AllowsTransparency="True" Background="Transparent" ResizeMode="NoResize" SizeToContent="WidthAndHeight" WindowStartupLocation="CenterScreen" FontFamily="Segoe UI" Topmost="True">
  <Border Margin="24" Background="#120C12" BorderBrush="#3D2230" BorderThickness="1" CornerRadius="20" Padding="34,30" Width="480">
    <Border.Effect><DropShadowEffect Color="#000000" BlurRadius="34" ShadowDepth="6" Opacity="0.75"/></Border.Effect>
    <StackPanel>
      <DockPanel>
        <Button x:Name="BX" DockPanel.Dock="Right" Content="&#xE8BB;" FontFamily="Segoe MDL2 Assets" Width="34" Height="34" Foreground="#B9A8B2" Cursor="Hand" VerticalAlignment="Top">
          <Button.Template><ControlTemplate TargetType="Button"><Border x:Name="b" Background="Transparent" CornerRadius="8"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#3A1A1A"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Button.Template>
        </Button>
        <StackPanel Orientation="Horizontal">
          <Viewbox Width="34" Height="34"><Viewbox.Effect><DropShadowEffect Color="#FF5A36" BlurRadius="16" ShadowDepth="0" Opacity="0.8"/></Viewbox.Effect>
            <Canvas Width="44" Height="44">
              <Ellipse Canvas.Left="7" Canvas.Top="7" Width="30" Height="30" Stroke="#FF5A36" StrokeThickness="4"/>
              <Line X1="22" Y1="1" X2="22" Y2="13" Stroke="#FF5A36" StrokeThickness="4" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
              <Line X1="22" Y1="31" X2="22" Y2="43" Stroke="#FF5A36" StrokeThickness="4" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
              <Line X1="1" Y1="22" X2="13" Y2="22" Stroke="#FF5A36" StrokeThickness="4" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
              <Line X1="31" Y1="22" X2="43" Y2="22" Stroke="#FF5A36" StrokeThickness="4" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
              <Ellipse Canvas.Left="18.5" Canvas.Top="18.5" Width="7" Height="7" Fill="#FFC83D"/>
            </Canvas>
          </Viewbox>
          <TextBlock FontSize="28" FontWeight="Black" Margin="12,0,0,0" VerticalAlignment="Center"><Run Text="OPTI" Foreground="#FFFFFF"/><Run Text="FRAG" Foreground="#FF5A36"/></TextBlock>
        </StackPanel>
      </DockPanel>
      <TextBlock x:Name="Tit" Foreground="White" FontSize="20" FontWeight="Bold" Margin="0,22,0,4"/>
      <TextBlock x:Name="Sub" Foreground="#B9A8B2" FontSize="13" TextWrapping="Wrap" LineHeight="19"/>
      <TextBlock x:Name="L1" Foreground="#E2D6DC" FontSize="12" FontWeight="SemiBold" Margin="0,20,0,6"/>
      <Border Background="#1A1219" BorderBrush="#3D2230" BorderThickness="1" CornerRadius="10" Height="44">
        <TextBox x:Name="Email" Background="Transparent" BorderThickness="0" Foreground="White" CaretBrush="#FF5A36" FontSize="14" VerticalAlignment="Center" Margin="12,0"/>
      </Border>
      <TextBlock x:Name="L2" Foreground="#E2D6DC" FontSize="12" FontWeight="SemiBold" Margin="0,14,0,6"/>
      <Border Background="#1A1219" BorderBrush="#3D2230" BorderThickness="1" CornerRadius="10" Height="44">
        <TextBox x:Name="Codigo" Background="Transparent" BorderThickness="0" Foreground="White" CaretBrush="#FF5A36" FontSize="14" VerticalAlignment="Center" Margin="12,0" CharacterCasing="Upper"/>
      </Border>
      <TextBlock x:Name="Ayuda" Foreground="#8A7480" FontSize="11" TextWrapping="Wrap" Margin="0,8,0,0"/>
      <Border x:Name="MsgBox" Background="#3A1A14" CornerRadius="10" Padding="12,10" Margin="0,16,0,0" Visibility="Collapsed">
        <TextBlock x:Name="Msg" Foreground="#FFB199" FontSize="13" TextWrapping="Wrap"/>
      </Border>
      <Button x:Name="BA" Height="48" Margin="0,20,0,0" Cursor="Hand" Foreground="#1A0A06" FontWeight="Bold" FontSize="15">
        <Button.Effect><DropShadowEffect Color="#FF5A36" BlurRadius="22" ShadowDepth="0" Opacity="0.45"/></Button.Effect>
        <Button.Template><ControlTemplate TargetType="Button"><Border x:Name="b" Background="#FF5A36" CornerRadius="12"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#FF8A6B"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.6"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Button.Template>
      </Button>
    </StackPanel>
  </Border>
</Window>'
    [xml]$x = $xaml
    $w = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $x))
    $D = [System.Net.WebUtility]
    $w.FindName('Tit').Text = $D::HtmlDecode('Activ&aacute; tu licencia')
    $w.FindName('Sub').Text = $D::HtmlDecode('Pon&eacute; el email con el que compraste y tu c&oacute;digo de compra. Se activa una sola vez por PC.')
    $w.FindName('L1').Text = 'Email de la compra'
    $w.FindName('L2').Text = $D::HtmlDecode('C&oacute;digo de compra')
    $w.FindName('Ayuda').Text = $D::HtmlDecode('Lo encontr&aacute;s en el mail de confirmaci&oacute;n de Hotmart o en consumer.hotmart.com &gt; Mis compras. Empieza con HP.')
    $w.FindName('BA').Content = 'Activar OptiFrag'
    $script:OF_Res = $null
    $mostrar = {
        param($t)
        $w.FindName('Msg').Text = $t
        $w.FindName('MsgBox').Visibility = 'Visible'
    }
    if ($msgInicial) { & $mostrar $msgInicial }
    $w.Add_MouseLeftButtonDown({ try { $w.DragMove() } catch {} })
    $w.FindName('BX').Add_Click({ $w.Close() })
    $w.FindName('BA').Add_Click({
        $email = $w.FindName('Email').Text.Trim()
        $cod = $w.FindName('Codigo').Text.Trim()
        if (-not $email -or -not $cod) { & $mostrar ($D::HtmlDecode('Complet&aacute; los dos campos.')); return }
        $btn = $w.FindName('BA'); $btn.IsEnabled = $false; $btn.Content = 'Verificando la compra...'
        $w.Dispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
        try {
            $r = OF-Get @{ a = 'activar'; email = $email; tx = $cod; hw = $hw }
            if ($r.ok) {
                $script:OF_Res = @{ tx = $r.tx; email = $email.ToLower(); t = $r.token }
                $btn.Content = 'Licencia activada'
                $w.Close()
                return
            }
            & $mostrar ([string]$r.msg)
        } catch {
            & $mostrar ($D::HtmlDecode('No se pudo conectar con el servidor de licencias. Revis&aacute; tu internet y prob&aacute; de nuevo.'))
        }
        $btn.IsEnabled = $true; $btn.Content = 'Activar OptiFrag'
    })
    $w.Add_ContentRendered({ $w.FindName('Email').Focus() | Out-Null })
    [void]$w.ShowDialog()
    return $script:OF_Res
}

# ------------------------------------------------------------------ flujo principal
$ofPreview = ($env:VX_PREVIEW -eq '1')
$ofDespues = ($env:VX_MODO -eq 'despues')

if (-not $ofDespues -and -not $ofPreview -and -not (OF-Admin)) {
    Write-Host ''
    Write-Host '  OPTIFRAG: pidiendo permisos de administrador... (toca "Si")' -ForegroundColor Red
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm '$OF_URL' | iex`"" -ErrorAction Stop
    } catch {
        Write-Host '  No se pudieron pedir los permisos automaticamente.' -ForegroundColor Yellow
        Write-Host '  Clic derecho en Inicio > "Terminal (Administrador)" y pega el comando de nuevo.' -ForegroundColor Yellow
    }
}
else {
    $hw = OF-Hw
    $lic = OF-Leer
    $res = $null
    if ($lic -and $lic.t) { $res = OF-App $lic $hw }
    if ($ofDespues) {
        # Informe DESPUES (tarea programada): sin ventanas
        if ($res -and $res.ok) { Invoke-Expression $res.codigo }
    }
    else {
        $intentoMsg = $null
        if ($res -and -not $res.ok) { $intentoMsg = $res.msg }
        while (-not ($res -and $res.ok)) {
            Write-Host ''
            Write-Host '  OPTIFRAG: activa tu licencia en la ventana que se abrio.' -ForegroundColor Red
            $nueva = OF-Ventana $hw $intentoMsg
            if (-not $nueva) { Write-Host '  Activacion cancelada.' -ForegroundColor Yellow; break }
            OF-Guardar $nueva
            $res = OF-App ([pscustomobject]$nueva) $hw
            if (-not $res.ok) { $intentoMsg = $res.msg }
        }
        if ($res -and $res.ok) {
            Write-Host '  Licencia OK. Abriendo OptiFrag...' -ForegroundColor Red
            Invoke-Expression $res.codigo
        }
    }
}
