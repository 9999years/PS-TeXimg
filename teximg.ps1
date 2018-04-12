function New-TeXimg {
	[CmdletBinding()]
	Param(
		[Parameter(
			Mandatory = $True,
			Position = 0,
			ValueFromPipeline = $True,
			HelpMessage = "The LaTeX formula to render"
		)]
		[String]$Formula,
		[Switch]$Stix,
		[Int]$Resolution = 600,
		[Int]$Border = 10,
		[String[]]$Packages,
		[Switch]$NoDefaultPackages,
		[Switch]$NoDefaultArgs,
		[String]$Directory = "~\Pictures\Screenshots",
		[String]$FileNameFormat = "yyyy-MM-ddTHH-mm-ss_\texi\m\g",
		[String]$HashType = "SHA256",
		[String]$LaTeX = "xelatex",
		[String]$ExtraPreamble,
		[Collections.ArrayList]$ExtraArgs =
			[Collections.ArrayList]::New(),
		[Switch]$KeepTemp,
		[Switch]$Open,
		[Switch]$NoSave,
		[Switch]$NoClipboard,
		[Switch]$NotMath,
		[Switch]$Hard,
		[Switch]$Soft
	)
	Process {
		$originalDir = Convert-Path (Get-Location)
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

		If($Border -lt 0) {
			Write-Warning "Invalid border (<0), changing to 0"
			$Border = 0
		}

		$code = " `
		\documentclass[
			border=$($Border)pt,
			varwidth=true
		]{standalone}
		\errorcontextlines=10
		$(ForEach($package in $Packages) { "\usepackage{$package}" })
		$(If($Stix) {"\usepackage{stix}" })
		$(If(!$NoDefaultPackages) { "`
		\usepackage{amsmath}
		\usepackage{amssymb}
		\usepackage{mathtools}" })
		$ExtraPreamble
		\begin{document}
		$body
		\end{document}"

		Write-Verbose "LaTeX code:`n=====`n$code`n====="

		# annoying af to write no-bom utf8 but whatever
		[IO.Directory]::SetCurrentDirectory($originalDir)
		[IO.File]::WriteAllLines("$texname.tex", $code)

		$ExtraArgs.Add("$texname.tex") | Out-Null
		$ExtraArgs.Add("-job-name=`"$texname`"") | Out-Null
		If(!$NoDefaultArgs) {
			$ExtraArgs.Add("-interaction=nonstopmode") | Out-Null
			$ExtraArgs.Add("-halt-on-error") | Out-Null
			$ExtraArgs.Add("-include-directory=$originalDir") | Out-Null
		}

		"Running $LaTeX $($ExtraArgs.ToArray())" | Write-Verbose
		& $LaTeX $ExtraArgs | Tee-Object -Variable latexOutput | Write-Verbose

		If((Test-Path "$tmp_folder\$texname.pdf") -eq $False) {
			Pop-Location
			"$LaTeX output:"
			$latexOutput
			Write-Error "pdflatex produced no PDF output!`
			Something must have gone severely wrong.`
			Check $tmp_folder\$texname.log for more details."
		}

		If($Soft) {
			$Resolution *= 2
		}

		If($Resolution -lt 2) {
			Write-Warning "Invalid resolution (<2), changing to 2"
			$Resolution = 2
		}

		Write-Output "Rendering PDF as PNG"

		$gsArgs = @{
			FilePath="$texname.pdf"
			OutFile="$prename.png"
			Resolution=$Resolution
		}

		If($Hard) {
			$gsArgs.Add('Hard', $True)
		}

		$gs_output = Convert-PDFtoPNG @gsArgs
		Write-Verbose ($gs_output -join "`n")

		If((Test-Path "$tmp_folder\$prename.png") -eq $False) {
			Pop-Location
			Write-Error "Ghost Script produced no PNG output!`
			Something must have gone severely wrong.`
			GS wrote:`n$($gs_output -join "`n")"
		}

		Write-Output "Trimming PNG"

		$magick_output = magick "$prename.png" -resize "$(If($Soft) { "50%" } Else { "100%" })" "$fname.png"
		Write-Verbose ($magick_output -join "`n")

		If((Test-Path "$tmp_folder\$fname.png") -eq $False) {
			Pop-Location
			Write-Error "Image Magick produced no PNG output!  Something must have gone severely wrong."
		}

		$diff = New-Timespan -Start $now -End ([DateTime]::Now)
		$diffstr = "$($diff.ToString("hh\:mm\:\:ss")).$($diff.Milliseconds)"
		$finalpath = ""
		If($NoSave) {
			$finalpath = "$tmp_folder\$fname.png"
		} Else {
			$finalpath = "$Directory\$fname.png"
		}
		If(!$NoSave) {
			Move-Item "$fname.png" $finalpath
			Write-Output "Image written to ``$finalpath`` in $diffstr"
			If($Open) {
				Invoke-Item $finalpath
				Write-Output "Image opened"
			}
		} Else {
			Write-Output "Completed in $diffstr"
			If($Open) {
				Write-Warning "-Open is not supported with -NoSave (what file could be opened?) and will be ignored"
			}
		}
		If(!$NoClipboard) {
			[Windows.Forms.Clipboard]::SetImage(
				[Drawing.Image]::Fromfile(
					(Resolve-Path $finalpath)
				)
			)
			Write-Output "Image copied to clipboard"
		}
		# get out of the old folder so we can delete it
		Set-Location ../ > $Null
		[IO.Directory]::SetCurrentDirectory($originalDir)
		If(!$KeepTemp) {
			Try {
				Remove-Item $tmp_folder -Recurse -Force > $Null
			} Catch [IO.IOException] {
				Write-Warning "Access error deleting the temp folder; Check if it's open in another window/process?"
			}
		}

		Pop-Location
	}
}

# for using the clipboard
Add-Type -AssemblyName System.Windows.Forms

New-Alias teximg New-TeXimg -ErrorAction SilentlyContinue

function Convert-PDFtoPNG {
	[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipeline=$true,
			Mandatory=$True)]
		[String]$FilePath,
		[String]$OutFile="",
		[Switch]$Hard,
		[Int]$Resolution=1000,
		[String]$GhostScript="gs"
	)

	Process {
		# throws if FP not found
		$truePath = Resolve-Path $FilePath

		If($truePath.Length -gt 1) {
			throw "Multiple files matching $FilePath found!"
		} Else {
			$truePath = $truePath[0]
		}

		If(!$truePath.Path.EndsWith(".pdf")) {
			Write-Warning "$truePath doesn't end with ``.pdf``"
		}

		If($OutFile -eq "") {
			$OutFile = Join-Path `
				(Split-Path $truePath) `
				((Split-Path $truePath -Leaf) -Replace "\.pdf", ".png")
			Write-Verbose "OutFile set to $Outfile"
		}

		Write-Verbose "Converting $truePath to $OutFile"

		$gsArgs = [Collections.ArrayList]::new(10)
		$gsArgs.AddRange((
			"-sDEVICE=png16m",
			"-sPageList=1",
			"-r$Resolution",
			"-o", $OutFile,
			$truePath
		))

		If(!$Hard) {
			$gsArgs.AddRange((
				"-dTextAlphaBits=4",
				"-dGraphicsAlphaBits=4"
			))
		}

		& $GhostScript $gsArgs

		If(!(Test-Path $OutFile)) {
			throw "GhostScript wrote no output to $OutFile"
		}
	}
}
