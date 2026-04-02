Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# === НАСТРОЙКИ МАНИФЕСТА ===
$manifestUrl = "https://NEXTDROIDER.github.io/Manifest.json" # ССЫЛКА НА ТВОЙ ФАЙЛ
$tempPath = [System.IO.Path]::GetTempFileName()
$servers = [ordered]@{}

# === ОКНО ===
$form = New-Object System.Windows.Forms.Form
$form.Text = "Vienna Launcher"
$form.Size = "520,480"
$form.StartPosition = "CenterScreen"
$form.BackColor = "#1e1e1e"
$form.FormBorderStyle = "FixedDialog"

# === ЛОГИ ===
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ReadOnly = $true
$logBox.Size = "480,150"
$logBox.Location = "10,270"
$logBox.BackColor = "Black"
$logBox.ForeColor = "Lime"
$logBox.ScrollBars = "Vertical"
$form.Controls.Add($logBox)

# === ПРОГРЕСС-БАР ===
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Size = "480,20"
$progressBar.Location = "10,240"
$progressBar.Style = "Continuous"
$form.Controls.Add($progressBar)

# === ЗАГРУЗКА МАНИФЕСТА ===
$logBox.AppendText(">> Loading manifest...`r`n")
try {
    Invoke-WebRequest -Uri $manifestUrl -OutFile $tempPath -ErrorAction Stop
    $lines = Get-Content $tempPath
    foreach ($line in $lines) {
        if ($line -match "=") {
            $parts = $line.Split("=", 2)
            $servers[$parts[0].Trim()] = $parts[1].Trim()
        }
    }
    $logBox.AppendText(">> Manifest updated! Found $($servers.Count) versions.`r`n")
} catch {
    $logBox.AppendText("(!) Failed to load manifest. Using offline mode.`r`n")
    $servers["Offline Version"] = "http://localhost/error.zip"
}

# === ВЫБОР СЕРВЕРА ===
$combo = New-Object System.Windows.Forms.ComboBox
$combo.Size = "300,30"
$combo.Location = "100,20"
$combo.DropDownStyle = "DropDownList"
foreach ($key in $servers.Keys) { [void]$combo.Items.Add($key) }
$combo.SelectedIndex = 0
$form.Controls.Add($combo)

# === ПОЛЯ (PORT, DATA) ===
$l1 = New-Object System.Windows.Forms.Label
$l1.Text = "PORT:"; $l1.ForeColor = "White"; $l1.Location = "50,70"; $form.Controls.Add($l1)
$portBox = New-Object System.Windows.Forms.TextBox
$portBox.Text = "8080"; $portBox.Location = "150,70"; $form.Controls.Add($portBox)

$l2 = New-Object System.Windows.Forms.Label
$l2.Text = "DATA:"; $l2.ForeColor = "White"; $l2.Location = "50,110"; $form.Controls.Add($l2)
$dataBox = New-Object System.Windows.Forms.TextBox
$dataBox.Text = "./data"; $dataBox.Size = "250,20"; $dataBox.Location = "150,110"; $form.Controls.Add($dataBox)

# === КНОПКА СТАРТ ===
$startBtn = New-Object System.Windows.Forms.Button
$startBtn.Text = "START"; $startBtn.Size = "200,40"; $startBtn.Location = "150,200"; $startBtn.BackColor = "#3d3d3d"; $startBtn.ForeColor = "White"; $startBtn.FlatStyle = "Flat"
$form.Controls.Add($startBtn)

# === ОБРАБОТЧИК КНОПКИ START ===
$startBtn.Add_Click({
    $selected = $combo.SelectedItem
    $url = $servers[$selected]

    $zipName = ($selected -replace "[^a-zA-Z0-9]", "_").ToLower() + ".zip"
    $extractPath = Join-Path (Get-Location) ($selected -replace "[^a-zA-Z0-9]", "_").ToLower()

    $logBox.AppendText("`r`n>> Selected: $selected`r`n")

    # === СКАЧИВАНИЕ ZIP С ПРОГРЕСС-БАРОМ ===
    $wc = New-Object System.Net.WebClient

    $wc.DownloadProgressChanged += {
        $progressBar.Value = $_.ProgressPercentage
    }

    $wc.DownloadFileCompleted += {
        $progressBar.Value = 100
        $logBox.AppendText(">> Download complete!`r`n")
    }

    if (!(Test-Path $zipName)) {
        try {
            $logBox.AppendText(">> Downloading $zipName...`r`n")
            $wc.DownloadFileAsync([Uri]$url, (Resolve-Path $zipName))
            
            while ($wc.IsBusy) {
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 100
            }
        } catch {
            $logBox.AppendText(">> Download Error!`r`n")
            return
        }
    } else {
        $logBox.AppendText(">> ZIP already exists, skipping download.`r`n")
        $progressBar.Value = 100
    }

    # === РАСПАКОВКА ===
    if (!(Test-Path $extractPath)) {
        $logBox.AppendText(">> Extracting...`r`n")
        try {
            Expand-Archive -Path $zipName -DestinationPath $extractPath -Force
            $logBox.AppendText(">> Extracted!`r`n")
        } catch {
            $logBox.AppendText(">> Extraction Error!`r`n")
            return
        }
    } else {
        $logBox.AppendText(">> Already extracted, skipping.`r`n")
    }

    # === ПОИСК JAR ===
    $jarFile = Get-ChildItem -Path $extractPath -Recurse -Filter *.jar | Select-Object -First 1
    if (!$jarFile) {
        $logBox.AppendText(">> ERROR: No .jar found inside zip!`r`n")
        return
    }
    $logBox.AppendText(">> Found: $($jarFile.FullName)`r`n")

    # === ЗАПУСК JAR ===
    $args = @("-jar", "`"$($jarFile.FullName)`"", "--port", $portBox.Text, "--StaticData", "`"$($dataBox.Text)`"")
    $logBox.AppendText(">> Launching: java $($args -join ' ')`r`n")
    Start-Process -FilePath "java" -ArgumentList $args -WindowStyle Normal
})

[void]$form.ShowDialog()

# === УДАЛЕНИЕ ТЕМП-ФАЙЛА ===
if (Test-Path $tempPath) { Remove-Item $tempPath -Force }