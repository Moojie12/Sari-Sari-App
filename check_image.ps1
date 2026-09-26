Add-Type -AssemblyName System.Drawing

$img = [System.Drawing.Bitmap]::new('C:/Users/Gamboa/AndroidStudioProjects/Sari-Sari-App/assets/images/logo.png')
$width = $img.Width
$height = $img.Height

$transparentCount = 0
$opaqueCount = 0

for ($y = 0; $y -lt $height; $y++) {
    for ($x = 0; $x -lt $width; $x++) {
        $c = $img.GetPixel($x, $y)
        if ($c.A -eq 0) {
            $transparentCount++
        } else {
            $opaqueCount++
        }
    }
}

Write-Host "Total pixels: $($width * $height)"
Write-Host "Transparent pixels (A=0): $transparentCount"
Write-Host "Opaque/Subject pixels: $opaqueCount"

# Check awning stripe at (150, 80)
$cStripe1 = $img.GetPixel(150, 80)
Write-Host "Awning stripe at (150, 80): A=$($cStripe1.A), R=$($cStripe1.R), G=$($cStripe1.G), B=$($cStripe1.B)"

$cStripe2 = $img.GetPixel(200, 80)
Write-Host "Awning stripe at (200, 80): A=$($cStripe2.A), R=$($cStripe2.R), G=$($cStripe2.G), B=$($cStripe2.B)"

# Check vinegar bottle label at (118, 270)
$cVinegar = $img.GetPixel(118, 270)
Write-Host "Vinegar bottle label at (118, 270): A=$($cVinegar.A), R=$($cVinegar.R), G=$($cVinegar.G), B=$($cVinegar.B)"

# Check corner (0,0)
$c0 = $img.GetPixel(0, 0)
Write-Host "Corner (0,0): A=$($c0.A)"

# Check top background (250, 10)
$cTop = $img.GetPixel(250, 10)
Write-Host "Top background (250,10): A=$($cTop.A)"

$img.Dispose()
