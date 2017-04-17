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
		[String]$Formula,
		[String[]]$Packages,
		[Switch]$NotMath
	)
	Process {
		Push-Location
		$tmp_folder = "~\.latex_tmp"
		New-Item $tmp_folder
		(Get-Item $tmp_folder).Attributes = "Archive", "Hidden"

		$body = "\( \displaystyle
			$Formula
		\)"

		If($NotMath) {
		}

		$code = "
\documentclass{article}
\usepackage[
	paperwidth  = 20cm,
	paperheight = 10cm,
	top         = 0.5cm,
	bottom      = 0.5cm,
	margin      = 0.5cm,
	scale       = 1,
	offset      = 0in,
	noheadfoot,
	nomarginpar,
	]{geometry}
\usepackage{adjustbox}
\usepackage{pbox}
\usepackage{amsmath}
\usepackage{amssymb}
\usepackage{mathtools}
$(ForEach($package in $Packages) { "\usepackage{$package}" })
\pagestyle{empty}
\parindent=0em
\parskip=0em
\begin{document}
	\maxsizebox*{0.99\textwidth}{0.99\textheight}{%
	\minsizebox*{0.99\textwidth}{0.99\textheight}{%
	}}%
\end{document}"

		Pop-Location
	}
}
