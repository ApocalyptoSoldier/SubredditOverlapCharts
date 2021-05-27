# Written by u/ApocalyptoSoldier
# Using data from subredditstats.com
# Also some of the code is transpiled from their javascript
# I did not ask their permission, let's hope they either don't find out or don't care

# TODO: Combine these two functions and Invoke-WebRequest to return the dist from a given url
function JsonToDict
{
	param($json)
	
	[System.Collections.Generic.Dictionary[int,int]]$dict = @{}
	
	(ConvertFrom-Json $json).PSObject.Properties | Foreach { $dict[$_.Name] = $_.Value }
	
	return $dict
}

function histToDist 
{
	param($Hist)
	
	$Sum = ($Hist.Values | Measure -Sum).Sum
	
	[System.Collections.Generic.Dictionary[int,double]]$returnDict = @{};
	
	foreach ($sub in $Hist.Keys)
	{
		$returnDict[$sub] = [Math]::Round(($Hist[$sub] / $sum), 5)
	}
	
	return $returnDict
}

. .\config.ps1

# Start Get Data
$encoded = [uri]::EscapeDataString($subredditToCheck)
$delay   = (Get-Random -Min 0 -Max 0.99).ToString() -replace ',', '.'

$globalSubredditsHist = JsonToDict (Invoke-WebRequest -Uri "https://subredditstats.com/api/globalSubredditsIdHist?v=$delay}").Content

$globalSubredditsDist = histToDist $globalSubredditsHist;

$subredditsIdHist = JsonToDict (Invoke-WebRequest -Uri "https://subredditstats.com/api/subredditNameToSubredditsHist?subredditName=$encoded&v=$delay").Content

$subredditsIdDist = histToDist $subredditsIdHist;
# End Get data


# Start Process Data
[System.Collections.Generic.Dictionary[int,double]]$subredditsProbMultipliers = @{};

foreach($sub in $subredditsIdDist.Keys) {
	$globalDist = $globalSubredditsDist[$sub]
	$prob = $subredditsIdDist[$sub]
	
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
# End Process Data


# Start Get Names
[System.Collections.ArrayList]$ids = $subredditsProbMultipliers.Keys

$body = @{
	subredditIds = $ids
}

$names = Invoke-RestMethod -Uri "https://subredditstats.com/api/specificSubredditIdsToNames" `
	-Method 'POST' `
	-Headers @{ "Content-Type" = "text/plain" } `
	-Body ($body | ConvertTo-Json)

# End Get Names

# Start Display Results
$Results = [System.Collections.ArrayList]@()	

foreach ($idx in 1..$names.Count)
{	
	$name = $names[$idx]
	$sub = $ids[$idx]

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


# Generate a markdown table, optionally
if ($generateMarkdown)
{
	. .\ConvertTo-Markdown

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
