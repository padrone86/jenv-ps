$jenvDir = $Env:JENV_DIR

if(  $jenvDir -le $null) {
  $jenvDir="c:\jenv"
}
$os="Windows"
$osArch="x86"

function Update-Path([string]$candidate, [string]$candidateHome){ 
    $tempPath=$Env:Path
	if($tempPath.Contains("$jenvDir\candidates\$candidate")) {
	   $regex="$jenvDir\candidates\$candidate".Replace('\',"\\");
	   $tempPath = $tempPath -replace "$regex[^;]*;", ""
	}
    $Env:Path = $candidateHome +"\bin;"+$tempPath
    [environment]::SetEnvironmentVariable($candidate.ToUpper()+"_HOME", $candidateHome,"Process")
}

function Start-Jenv() {
   $OSArchitecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
   if ( $OSArchitecture.Contains("64")) {
     $osArch="x64"
   }
   $shell = New-Object -COM WScript.Shell
   $files = dir "$jenvDir\candidates"
   for($i=0;$i –lt $files.Length;$i++){
     $candidate=$files[$i].Name
	 $candidateLink="$jenvDir\candidates\$candidate\current.lnk"
	 if ( Test-Path "$jenvDir\candidates\$candidate\current.lnk") {
	     $link = $shell.CreateShortcut("$jenvDir\candidates\$candidate\current.lnk")
		 if( Test-Path $link.TargetPath ) {
		   Update-Path $candidate $link.TargetPath
		 }
	 }
   }
}

function jenv([string]$Command, [string]$Candidate, [string]$Versiond)
{
     try {
        switch -regex ($Command) {
            'help'          { Show-Help }
			'install'       { Install-Candidate $Candidate $Versiond }
			'default'       { Select-Candidate $Candidate $Versiond }
			'uninstall'     { Uninstall-Candidate $Candidate $Versiond }
			'use'           { Use-Candidate $Candidate $Versiond }
            default         { Write-Warning "Invalid command: $Command"; Show-Help }
        }
    } catch {
        Jenv-Help
    }
}

function Install-Candidate([string]$candidate, [string]$version){
    $jenvArchives="$jenvDir\archives"
	if ( !(Test-Path $jenvArchives )) {
      New-Item $jenvArchives -ItemType Directory
    }
	$candidateFileName=$candidate+"-"+$version+".zip"
	$candidateHome="$jenvDir\candidates\$candidate\$version"
	$candidateUrl="http://get.jenv.mvnsearch.org/download/$candidate/$candidateFileName"
	if ( !(Test-Path "$jenvDir\candidates\$candidate" )) {
	   New-Item "$jenvDir\candidates\$candidate" -ItemType directory
	}
	if ( !(Test-Path $candidateHome )) { 
		if ( !(Test-Path "$jenvArchives\$candidateFileName")) {
		  $webClient = (New-Object Net.WebClient)
		  $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
		  $webClient.DownloadFile($candidateUrl, "$jenvArchives\$candidateFileName")
		}
		# unzip archive
		$shell = New-Object -com shell.application
		$shell.namespace($jenvArchives).copyhere($shell.namespace("$jenvArchives\$candidateFileName").items(), 0x14)
		Move-Item ("$jenvArchives\"+$candidate+"-"+$version) ($candidateHome)
	}
}

function Select-Candidate([string]$candidate, [string]$version){ 
    $shell = New-Object -COM WScript.Shell
	$candidateHome="$jenvDir\candidates\$candidate\$version"
	$candidateLink="$jenvDir\candidates\$candidate\current.lnk"
	if ( Test-Path $candidateHome) { 
		if ( Test-Path $candidateLink) { 
		    Remove-Item $candidateLink
		}
		$link = $shell.CreateShortcut("$jenvDir\candidates\$candidate\current.lnk")
		$link.TargetPath=$candidateHome
	    $link.Save()
		Update-Path $candidate $candidateHome
	}else {
	    Write-Output "$candidate($version) not installed on local host"
	}
}

function Use-Candidate([string]$candidate, [string]$version){
	$candidateHome="$jenvDir\candidates\$candidate\$version"
	if ( Test-Path $candidateHome) { 
		Update-Path $candidate $candidateHome
	}else {
	    Write-Output "$candidate($version) not installed on local host"
	}
}

function Uninstall-Candidate([string]$candidate, [string]$version){  
   $candidateHome="$jenvDir\candidates\$candidate\$version"
   if ( Test-Path $candidateHome) {
       Remove-Item -Recurse -Force $candidateHome
   }
}

function Enter-Candidate([string]$candidate, [string]$version){  
   $candidateHome="$jenvDir\candidates\$candidate\$version"
   if(  $version -le $null) {
        $candidateLink="$jenvDir\candidates\$candidate\current.lnk"
		if ( Test-Path $candidateLink) { 
		     $link = $shell.CreateShortcut("$jenvDir\candidates\$candidate\current.lnk")
			 $candidateHome=$link.TargetPath
		}
   }
   if ( Test-Path $candidateHome) {
       cd $candidateHome
   }
}

function Get-CandidateVersion([string]$candidate, [string]$version){  
   $candidateHome="$jenvDir\candidates\$candidate\$version"
   if(  $version -le $null) {
        $candidateLink="$jenvDir\candidates\$candidate\current.lnk"
		if ( Test-Path $candidateLink) { 
		     $link = $shell.CreateShortcut("$jenvDir\candidates\$candidate\current.lnk")
			 $candidateHome=$link.TargetPath
		}
   }
   if ( Test-Path $candidateHome) {
       cd $candidateHome
   }
}

function Show-Help() {
    Write-Output @"
Usage: jenv <command> <candidate> [version]

    commands:
        install       <candidate> [version]
        uninstall     <candidate> <version>
        use           <candidate> [version]
        default       <candidate> [version]
        current       [candidate]
        version 
        help 
        selfupdate        [-Force]

eg: jenv install maven 3.2.1
"@
}

Start-Jenv
Export-ModuleMember -Function jenv
Export-ModuleMember -function Start-Jenv
