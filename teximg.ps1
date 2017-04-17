function TeXImg {
	[CmdletBinding()]
	Param(
		[Parameter(
			Mandatory = $True,
			Position = 0,
			ValueFromPipeline = $True,
			ValueFromRemainingArguments = $True,
			HelpMessage = "The LaTeX formula to render"
		)]
		$Formula
	)
	Process {
		Push-Location
		$tmp_folder = "~\.latex_tmp"
		New-Item $tmp_folder
		(Get-Item $tmp_folder).Attributes = "Archive", "Hidden"
		Pop-Location
	}
}
