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
		[String[]]$Formulas,
		[Switch]$Stix,
		[Int]$Resolution = 150,
                [Int]$Border = 50,
		[String[]]$Packages,
                [String]$Directory = "~\Pictures\Screenshots",
		[Switch]$KeepTemp,
                [Switch]$Open,
		[Switch]$NotMath,
		[String]$FileNameFormat = "yyyy-MM-ddTHH-mm-ss_\texi\m\g",
		[String]$HashType = "SHA256"
	)
	Process {
	ForEach($Formula in $Formulas) {
		Write-Verbose "Saving current directory, making temp folder"
		Push-Location
		$tmp_folder = "~\.teximg_tmp"
		Try {
			New-Item $tmp_folder -Type Directory > $Null
		} Catch [IO.IOException] {
			# there should be a less verbose way 
			Write-Warning "Temp folder already exists!"
			$message  = "Continuing may overwrite previous files in $tmp_folder"
			$question = "Continue?"

			$choices = [Management.Automation.Host.ChoiceDescription[]] `
				("&Yes", "&No")

			$decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)
			If($choices[$decision].Label -eq "&No") {
				Write-Output "Exiting!"
				return
			} Else {
				Write-Output "Continuing"
			}

			# remove temp files in case of errors (we use test path
			# to check for errors)
			If((Test-Path "$texname.tex") -eq $True) { Remove-Item "$texname.tex" }
			If((Test-Path "$texname.pdf") -eq $True) { Remove-Item "$texname.pdf" }
			If((Test-Path "$prename.png") -eq $True) { Remove-Item "$prename.png" }
		}
		# make tmp folder hidden
		(Get-Item $tmp_folder -Force).Attributes = "Directory", "Hidden"
		Set-Location $tmp_folder

		$now = [DateTime]::Now
		$fname = $now.ToString($FileNameFormat)
		$texname = "formula"
		$prename = "teximg_out_pre"

		Write-Output "Rendering LaTeX"

		$body = "\( \displaystyle
			$Formula
		\)"

		If($NotMath) {
			$body = $Formula
		}

		$code = " `
		\documentclass{article}
		\nonstopmode
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
		$(If($Stix) {"\usepackage{stix}" })
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
				$body
			}}%
		\end{document}"

		Write-Verbose "LaTeX code:`n=====`n$code`n====="

		# annoying af to write no-bom utf8 but whatever
		[IO.Directory]::SetCurrentDirectory($PWD)
		[IO.File]::WriteAllLines("$texname.tex", $code)

		pdflatex "$texname.tex" -job-name="$texname" | Write-Verbose

		If((Test-Path "$tmp_folder\$texname.pdf") -eq $False) {
			Pop-Location
			Write-Error "pdflatex produced no PDF output!`
			Something must have gone severely wrong.`
			Check $tmp_folder\$texname.log for more details."
		}

		If($Resolution -lt 2) {
			Write-Warning "Invalid resolution (<2), changing to 2"
			$Resolution = 2
		}

		If($Border -lt 0) {
			Write-Warning "Invalid border (<0), changing to 0"
			$Border = 0
		}

		Write-Output "Rendering PDF as PNG"

		$gs_output = (gs `
			-sDEVICE=png16m `
			-dTextAlphaBits=4 `
			-dGraphicsAlphaBits=4 `
			-sPageList=1 `
			-r"$Resolution" `
			-o "$prename.png" `
			"$texname.pdf")
		Write-Verbose ($gs_output -join "`n")

		If((Test-Path "$tmp_folder\$prename.png") -eq $False) {
			Pop-Location
			Write-Error "Ghost Script produced no PNG output!`
			Something must have gone severely wrong.`
			GS wrote:`n$($gs_output -join "`n")"
		}

		Write-Output "Trimming PNG"

		$magick_output = magick "$prename.png" -trim -bordercolor white -border $Border "$fname.png"
		Write-Verbose ($magick_output -join "`n")

		If((Test-Path "$tmp_folder\$fname.png") -eq $False) {
			Pop-Location
			Write-Error "Image Magick produced no PNG output!`
			Something must have gone severely wrong."
		}

		Move-Item "$fname.png" "$Directory/$fname.png"
		# get out of the old folder so we can delete it
		Set-Location ../ > $Null
		[IO.Directory]::SetCurrentDirectory($PWD)
		If(!$KeepTemp) {
			Try {
				Remove-Item $tmp_folder -Recurse -Force > $Null
			} Catch [IO.IOException] {
				Write-Warning "Access error deleting the temp folder; Check if it's open in another window/process?"
			}
		}
		$diff = New-Timespan -Start $now -End ([DateTime]::Now)
		Write-Output "Image written to ``$Directory\$fname.png in $($diff.ToString("hh\:mm\:\:ss")).$($diff.Milliseconds)"
		
		If($Open) {
			Invoke-Item "$Directory\$fname.png"
			Write-Output "Image opened"
		}
		If(!$DontCopy) {
			[Windows.Forms.Clipboard]::SetImage(
				[Drawing.Image]::Fromfile((Resolve-Path "$Directory\$fname.png"))
			)
			Write-Output "Image copied to clipboard"
		}

		Pop-Location
	}
	}
}
