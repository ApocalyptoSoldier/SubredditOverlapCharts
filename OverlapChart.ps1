# Written by u/ApocalyptoSoldier
# Based on https://social.technet.microsoft.com/Forums/en-US/bc6af53d-b392-49f3-80d0-0b36157c87be/charting-with-powershell?forum=winserverpowershell

Add-Type -AssemblyName System.Windows.Forms.DataVisualization

# Region enums
$ChartTypes 				= [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]
$ChartColorPalettes 		= [System.Windows.Forms.DataVisualization.Charting.ChartColorPalette]
$ChartValueTypes 			= [System.Windows.Forms.DataVisualization.Charting.ChartValueType]
$AntiAliasingStyles 		= [System.Windows.Forms.DataVisualization.Charting.AntiAliasingStyles]
$LabelOutsidePlotAreaStyle 	= [System.Windows.Forms.DataVisualization.Charting.LabelOutsidePlotAreaStyle]
# Endregion enums

function MakeBarSeries {
    Param (
		[System.Windows.Forms.DataVisualization.Charting.Chart]$Chart,
        [string]$Name,
        [double]$Value
    )
    Try
	{
        $series 					= $Chart.Series.Add($Name)
        $series.ChartType 			= $ChartTypes::Bar
        $series.Label 				= "$Name $Value"
		$Series.BorderWidth 		= 10
		$Series.YValueType			= $ChartValueTypes::Double
		$Series["PointWidth"]  		= 2
		$Series["GapWidth"] 		= 0.5
		$Series["BarLabelStyle"] 	= "Left"
		$Series.SmartLabelStyle.Enabled = $true
		$Series.SmartLabelStyle.IsMarkerOverlappingAllowed = $true
		$Series.SmartLabelStyle.AllowOutsidePlotArea = $LabelOutsidePlotAreaStyle::Yes
        $series.Font 				= 'Arial, 14pt'
        [void]$series.Points.AddY($Value)
	
    }
    Catch 
	{
        Throw $_
    }
}

# TODO: Look into adding logarithmic or similar scaling
Try 
{
	$Overlap = Import-CliXMl .\Overlap.xml
	
	$Max = ($Overlap | Measure -Max Probability).Maximum
	
    # Build the chart container and add initial area
    $Chart 			 	= [System.Windows.Forms.DataVisualization.Charting.Chart]::New()
	$Chart.Palette 	 	= $ChartColorPalettes::EarthTones
    $Chart.Size 		= '1200,800'
	
	$Chart.Width  = $Max * 200
	$Chart.Height = ($Overlap.Length * 45)
	
	$Chart.AntiAliasing	= $AntiAliasingStyles::All
	
	
    $ChartArea = New-Object -TypeName System.Windows.Forms.DataVisualization.Charting.ChartArea
	
	$ChartArea.AxisX.LabelStyle.Enabled 	= $false
	$ChartArea.AxisX.MajorGrid.Enabled 		= $false;  
	$ChartArea.AxisX.MinorGrid.Enabled		= $false
	$ChartArea.AxisX.MajorTickMark.Enabled	= $false
	$ChartArea.AxisX.MinorTickMark.Enabled	= $false

	# $ChartArea.AxisY.Title 					= 'Overlap probability'
	$ChartArea.AxisY.LabelStyle.Enabled 	= $false
	$ChartArea.AxisY.MajorGrid.Enabled 		= $false;  
	$ChartArea.AxisY.MinorGrid.Enabled 		= $false;  
	$ChartArea.AxisY.MajorTickMark.Enabled	= $false
	$ChartArea.AxisY.MinorTickMark.Enabled	= $false
	$ChartArea.AxisY.Interval 				= 0.1
	$ChartArea.AxisY.Maximum 				= $Max
	
	$Chart.ChartAreas.Add($ChartArea)
	
	foreach ($entry in $Overlap)
	{
		MakeBarSeries -Chart $Chart -Name $entry.Name -Value $entry.Probability
	}

    # Save the image and then display it
    $imageFile = "$pwd\Overlap.png"
    $Chart.SaveImage($imageFile,'PNG')
    Start-Process $imageFile
}
Catch 
{
    Throw $_
}