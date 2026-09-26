Add-Type -AssemblyName System.Drawing

$inputPath = 'C:/Users/Gamboa/AndroidStudioProjects/Sari-Sari-App/assets/images/logo.png'
$img = [System.Drawing.Bitmap]::new($inputPath)
$width = $img.Width
$height = $img.Height

$out = [System.Drawing.Bitmap]::new($width, $height)
$visited = New-Object 'bool[,]' $width, $height
$queue = New-Object System.Collections.Generic.Queue[System.Drawing.Point]

# Copy original pixels
for ($y = 0; $y -lt $height; $y++) {
    for ($x = 0; $x -lt $width; $x++) {
        $out.SetPixel($x, $y, $img.GetPixel($x, $y))
    }
}

# Enqueue all border pixels
for ($x = 0; $x -lt $width; $x++) {
    $queue.Enqueue([System.Drawing.Point]::new($x, 0))
    $queue.Enqueue([System.Drawing.Point]::new($x, $height - 1))
}
for ($y = 0; $y -lt $height; $y++) {
    $queue.Enqueue([System.Drawing.Point]::new(0, $y))
    $queue.Enqueue([System.Drawing.Point]::new($width - 1, $y))
}

$filled = 0

while ($queue.Count -gt 0) {
    $pt = $queue.Dequeue()
    $x = $pt.X; $y = $pt.Y

    if ($x -lt 0 -or $x -ge $width -or $y -lt 0 -or $y -ge $height) { continue }
    if ($visited[$x, $y]) { continue }
    $visited[$x, $y] = $true

    $c = $out.GetPixel($x, $y)

    # Calculate color distance to background canvas (250, 243, 225)
    $dist = [Math]::Abs([int]$c.R - 250) + [Math]::Abs([int]$c.G - 243) + [Math]::Abs([int]$c.B - 225)

    # Background canvas condition: dist < 35 or A < 50
    $isBg = ($c.A -lt 50) -or ($dist -lt 35)

    if ($isBg) {
        $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
        $filled++

        $queue.Enqueue([System.Drawing.Point]::new($x + 1, $y))
        $queue.Enqueue([System.Drawing.Point]::new($x - 1, $y))
        $queue.Enqueue([System.Drawing.Point]::new($x, $y + 1))
        $queue.Enqueue([System.Drawing.Point]::new($x, $y - 1))
    }
}

Write-Host "Flood-filled ${filled} background pixels to transparent."

# Anti-aliased fringe cleaning along outer border
for ($pass = 0; $pass -lt 2; $pass++) {
    $fringe = 0
    for ($y = 1; $y -lt $height - 1; $y++) {
        for ($x = 1; $x -lt $width - 1; $x++) {
            $c = $out.GetPixel($x, $y)
            if ($c.A -gt 0) {
                $hasTrans = ($out.GetPixel($x+1, $y).A -eq 0) -or `
                            ($out.GetPixel($x-1, $y).A -eq 0) -or `
                            ($out.GetPixel($x, $y+1).A -eq 0) -or `
                            ($out.GetPixel($x, $y-1).A -eq 0)
                if ($hasTrans) {
                    $dist = [Math]::Abs([int]$c.R - 250) + [Math]::Abs([int]$c.G - 243) + [Math]::Abs([int]$c.B - 225)
                    if ($dist -lt 70 -or ($c.R -gt 220 -and $c.G -gt 210 -and $c.B -gt 190)) {
                        $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
                        $fringe++
                    }
                }
            }
        }
    }
    Write-Host "Pass ${pass} fringe cleaned: ${fringe} pixels."
}

$img.Dispose()
$out.Save($inputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$out.Dispose()

Write-Host "Successfully saved processed logo.png"
