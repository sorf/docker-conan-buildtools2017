# Based on:
#   https://docs.microsoft.com/en-us/visualstudio/install/advanced-build-tools-container
#   https://github.com/docker-library/python/blob/master/3.6/windows/windowsservercore-ltsc2016/Dockerfile
# 
# Build with (for 4GB memory):
#   docker build -t conanbuildtools2017:ltsc2016 -m 4GB .

FROM microsoft/windowsservercore:ltsc2016

# Use PowerShell commands to download, validate hashes, etc.
SHELL ["powershell.exe", "-ExecutionPolicy", "Bypass", "-Command", "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; $VerbosePreference = 'Continue';"]

# Download Build Tools 15.4.27004.2005 and other useful tools.
ENV VS_BUILDTOOLS_URI=https://aka.ms/vs/15/release/6e8971476/vs_buildtools.exe \
    VS_BUILDTOOLS_SHA256=D482171C7F2872B6B9D29B116257C6102DBE6ABA481FAE4983659E7BF67C0F88 \
    NUGET_URI=https://dist.nuget.org/win-x86-commandline/v4.1.0/nuget.exe \
    NUGET_SHA256=4C1DE9B026E0C4AB087302FF75240885742C0FAA62BD2554F913BBE1F6CB63A0

# Download tools to C:\Bin and install Build Tools excluding workloads and components with known issues.
RUN New-Item -Path C:\Bin, C:\TEMP -Type Directory | Out-Null; \
    [System.Environment]::SetEnvironmentVariable('PATH', "\"${env:PATH};C:\Bin\"", 'Machine'); \
    function Fetch ([string] $Uri, [string] $Path, [string] $Hash) { \
      Invoke-RestMethod -Uri $Uri -OutFile $Path; \
      if ($Hash -and ((Get-FileHash -Path $Path -Algorithm SHA256).Hash -ne $Hash)) { \
        throw "\"Download hash for '$Path' incorrect\""; \
      } \
    }; \
    Fetch -Uri $env:NUGET_URI -Path C:\Bin\nuget.exe -Hash $env:NUGET_SHA256; \
    Fetch -Uri $env:VS_BUILDTOOLS_URI -Path C:\TEMP\vs_buildtools.exe -Hash $env:VS_BUILDTOOLS_SHA256; \
    Fetch -Uri 'https://aka.ms/vscollect.exe' -Path C:\TEMP\collect.exe; \
    \
    Write-Host 'Installing vs_buildtools.exe...'; \
    $p = Start-Process -Wait -PassThru -FilePath C:\TEMP\vs_buildtools.exe -ArgumentList '--quiet --wait --norestart --nocache --installPath C:\BuildTools --all --remove Microsoft.VisualStudio.Component.Windows10SDK.10240 --remove Microsoft.VisualStudio.Component.Windows10SDK.10586 --remove Microsoft.VisualStudio.Component.Windows10SDK.14393 --remove Microsoft.VisualStudio.Component.Windows81SDK'; \
    if (($ret = $p.ExitCode) -and ($ret -ne 3010)) { C:\TEMP\collect.exe; throw ('Install failed with exit code 0x{0:x}' -f $ret) }


ENV PYTHON_VERSION 3.6.4
ENV PYTHON_RELEASE 3.6.4

RUN $url = ('https://www.python.org/ftp/python/{0}/python-{1}-amd64.exe' -f $env:PYTHON_RELEASE, $env:PYTHON_VERSION); \
    Write-Host ('Downloading {0} ...' -f $url); \
    Invoke-WebRequest -Uri $url -OutFile 'python.exe'; \
    \
    Write-Host 'Installing ...'; \
# https://docs.python.org/3.5/using/windows.html#installing-without-ui
    Start-Process python.exe -Wait \
        -ArgumentList @( \
            '/quiet', \
            'InstallAllUsers=1', \
            'TargetDir=C:\Python', \
            'PrependPath=1', \
            'Shortcuts=0', \
            'Include_doc=0', \
            'Include_pip=0', \
            'Include_test=0' \
        ); \
    \
# the installer updated PATH, so we should refresh our local value
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::Machine); \
    \
    Write-Host 'Verifying install ...'; \
    Write-Host '  python --version'; python --version; \
    \
    Write-Host 'Removing ...'; \
    Remove-Item python.exe -Force; \
    \
    Write-Host 'Complete.';

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 9.0.2

RUN Write-Host ('Installing pip=={0} ...' -f $env:PYTHON_PIP_VERSION); \
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
    Invoke-WebRequest -Uri 'https://bootstrap.pypa.io/get-pip.py' -OutFile 'get-pip.py'; \
    python get-pip.py \
        --disable-pip-version-check \
        --no-cache-dir \
        ('pip=={0}' -f $env:PYTHON_PIP_VERSION) \
    ; \
    Remove-Item get-pip.py -Force; \
    \
    Write-Host 'Verifying pip install ...'; \
    pip --version; \
    \
    Write-Host 'Complete.';

ENV CMAKE_VERSION="3.11.0-rc3-win64-x64"
ENV CMAKE_SHA256=236513BBF024AD5E1594DC918A220A181C641A8722A252CA75C9569D59189029

RUN Write-Host ('Installing cmake=={0} ...' -f $env:CMAKE_VERSION); \
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
    Invoke-WebRequest -Uri https://cmake.org/files/v3.11/cmake-$env:CMAKE_VERSION.zip -OutFile 'cmake.zip'; \
    if ((Get-FileHash -Path cmake.zip -Algorithm SHA256).Hash -ne $env:CMAKE_SHA256) { throw 'cmake: Download hash does not match' }; \
    Expand-Archive cmake.zip c: ; \
    Remove-Item cmake.zip -Force; \
    [System.Environment]::SetEnvironmentVariable('PATH', "\"${env:PATH};C:\cmake-$env:CMAKE_VERSION\bin\"", 'Machine'); \
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::Machine); \
    \
    cmake --version; \
    \
    Write-Host 'Complete.';

ENV JAVA_VERSION 9.0.4-1
ENV JAVA_ZIP_VERSION 9-openjdk-9.0.4-1.b11
ENV JAVA_SHA256 1333ab5bccc20e9043f0593b001825cbfa141f0e0c850d877af6b8e2c990cb47
ENV JAVA_HOME C:\\java-${JAVA_ZIP_VERSION}.ojdkbuild.windows.x86_64

RUN Write-Host ('Installing java=={0} ...' -f $env:JAVA_VERSION); \
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
    Invoke-WebRequest -Uri https://github.com/ojdkbuild/ojdkbuild/releases/download/$env:JAVA_VERSION/java-$env:JAVA_ZIP_VERSION.ojdkbuild.windows.x86_64.zip -OutFile 'openjdk.zip'; \
    if ((Get-FileHash -Path openjdk.zip -Algorithm SHA256).Hash -ne $env:JAVA_SHA256) { throw 'java: Download hash does not match' }; \
    Expand-Archive openjdk.zip c: ; \
    Remove-Item openjdk.zip -Force; \
    [System.Environment]::SetEnvironmentVariable('PATH', "\"${env:PATH};$env:JAVA_HOME\bin\"", 'Machine'); \
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::Machine); \
    \
    java --version; \
    \
    Write-Host 'Complete.';


RUN Write-Host ('Installing virtualenv ...'); \
    pip install -U virtualenv; \
    \
    virtualenv --version; \
    \
    Write-Host 'Complete.';


RUN Write-Host ('Installing conan ...'); \
    pip install -U conan; \
    \
    conan --version; \
    \
    Write-Host 'Complete.';



# Restore default shell for Windows containers.
SHELL ["cmd.exe", "/s", "/c"]

# Start developer command prompt with any other commands specified.
ENTRYPOINT C:\BuildTools\Common7\Tools\VsDevCmd.bat &&

# Default to PowerShell if no other command specified.
CMD ["powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass"]