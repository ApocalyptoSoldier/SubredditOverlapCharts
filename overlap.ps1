# Written by u/ApocalyptoSoldier
# Using data from subredditstats.com
# Also some of the code is transpiled from their javascript
# I did not ask their permission, let's hope they either don't find out or don't care

# TODO: Set correct data types for variables and parameters

function Get-Dist
{
	param([string]$Uri)
	
	# Get the history data
	$json = ConvertFrom-Json (Invoke-WebRequest -Uri $Uri).Content
	
	# Convert the history data to a dictionary
	[System.Collections.Generic.Dictionary[int,int]]$histDict = @{}
	
	$json.PSObject.Properties | Foreach { $histDict[$_.Name] = $_.Value }
	
	# Calculate the distance dictionary from the history dictionary
	[System.Collections.Generic.Dictionary[int,double]]$distDict = @{};
	
	$Sum = ($histDict.Values | Measure -Sum).Sum
	
	foreach ($sub in $histDict.Keys)
	{
		$distDict[$sub] = [Math]::Round(($histDict[$sub] / $Sum), 5)
	}
	
	# Return the distance dictionary
	return $distDict
}

function Get-Multipliers
{
	param(
			[System.Collections.Generic.Dictionary[int,double]]
			$subredditsIdDist,
			
			[System.Collections.Generic.Dictionary[int,double]]
			$globalSubredditsIdDist
		)
	
	[System.Collections.Generic.Dictionary[int,double]]$subredditsProbMultipliers = @{};
	
	foreach ($sub in $subredditsIdDist.Keys)
	{
		$globalDist = $globalSubredditsIdDist[$sub]
		$prob 	    = $subredditsIdDist[$sub]
		
		# ignore super rare subreddits (<0.1% chance that average user has visited)
		if ($globalDist -lt 0.0001)
		{
			continue;
		}
		
		$multiplier = $prob / $globalDist;
		
		# This means that users are actually less likely than the average user to visit
		# TODO: Decide if I want to move this threshold to the config file
		if ($multiplier -lt 1)
		{
			continue;
		}
		
		$subredditsProbMultipliers[$sub] = $multiplier
	}
	
	return $subredditsProbMultipliers
}
	
# TODO: See if I can return a dictionary of ids to names
function Get-NamesFromIds
{
	param([System.Collections.ArrayList]$Ids)
	
	$body = @{
		subredditIds = $Ids
	}

	$names = Invoke-RestMethod -Uri "https://subredditstats.com/api/specificSubredditIdsToNames" `
		-Method 'POST' `
		-Headers @{ "Content-Type" = "text/plain" } `
		-Body ($body | ConvertTo-Json)
		
	return $names
}

# Start Process Data


. .\config.ps1

# Start Get Data
$encoded = [uri]::EscapeDataString($subredditToCheck)
$delay   = (Get-Random -Min 0 -Max 0.99).ToString() -replace ',', '.'

$globalSubredditsIdDist = Get-Dist -Uri "https://subredditstats.com/api/globalSubredditsIdHist?v=$delay}"
$subredditsIdDist		= Get-Dist -Uri "https://subredditstats.com/api/subredditNameToSubredditsHist?subredditName=$encoded&v=$delay"
# End Get data


# Start Process Data
[System.Collections.Generic.Dictionary[int,double]]$subredditsProbMultipliers = Get-Multipliers $subredditsIdDist $globalSubredditsIdDist

$names = Get-NamesFromIds -Ids $subredditsProbMultipliers.Keys

$Results = [System.Collections.ArrayList]@()

[System.Collections.ArrayList]$ids = $subredditsProbMultipliers.Keys

foreach ($idx in 1..$names.Count)
{	
	$name = $names[$idx]
	$sub  = $ids[$idx]

	if ($subredditsProbMultipliers.ContainsKey($sub))
	{
		$prob = $subredditsProbMultipliers[$sub]
		$Results.Add(
			[PSCustomObject]@{
				Name = $name
				Probability = [Math]::Round($prob, 2)
			}
		) | Out-Null
	}
}

# Start Filter Results

$FilteredResults = $Results

if ($subsToInclude)
{
	$subsToInclude = $subsToInclude | ForEach { $_.ToLower() }
	
	$FilteredResults = $FilteredResults | Where { $_.Name.ToLower() -in $subsToInclude }
}

if ($subsToExclude)
{
	$subsToExclude = $subsToExclude | ForEach { $_.ToLower() }
	
	$FilteredResults = $FilteredResults | Where { -not ($_.Name.ToLower() -in $subsToExclude) }
}

# End Filter Results

# It doesn't like having to draw too many bars, let's use 25 at most
# TODO: maybe also put this in the config file
$FilteredResults = $FilteredResults | Sort Probability -Desc | Select -First 25

$FilteredResults | Export-CliXml Overlap.xml

# Start Display Results

# Generate a markdown table, optionally
if ($generateMarkdown)
{
	. .\ConvertTo-Markdown.ps1

	$FilteredResults | Select `
		@{ Name='subreddit'; Expression={"r/$($_.Name)"}}, `
		@{ Name='probability multiplier'; Expression={$_.Probability}} `
		| ConvertTo-Markdown | Out-File table.md
}
if ($generateChart)
{
	.\OverlapChart.ps1
}

# End Display Results


# TODO post to dataisbeautiful
