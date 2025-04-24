#!/bin/bash

# Configuration variables
mt5file='/config/.wine/drive_c/Program Files/MetaTrader 5 EXNESS/terminal64.exe'
WINEPREFIX='/config/.wine'
wine_executable="wine"
metatrader_version="5.0.36"
mt5server_port="8001"
mono_url="https://dl.winehq.org/wine/wine-mono/8.0.0/wine-mono-8.0.0-x86.msi"
python_url="https://www.python.org/ftp/python/3.9.0/python-3.9.0.exe"
mt5setup_url="https://download.mql5.com/cdn/web/exness.technologies.ltd/mt5/exness5setup.exe"
git_win_url="https://github.com/git-for-windows/git/releases/download/v2.40.1.windows.1/Git-2.40.1-32-bit.exe"
mt5linux_zip_url="https://github.com/lucas-campagna/mt5linux/archive/refs/heads/master.zip"

# Function to display a graphical message
show_message() {
    echo $1
}

# Function to check if a dependency is installed
check_dependency() {
    if ! command -v $1 &> /dev/null; then
        echo "$1 is not installed. Please install it to continue."
        return 1
    fi
    return 0
}

# Function to install a package
install_package() {
    package=$1
    if command -v apt-get &> /dev/null; then
        show_message "Installing $package using apt-get..."
        apt-get update && apt-get install -y $package
    elif command -v apt &> /dev/null; then
        show_message "Installing $package using apt..."
        apt update && apt install -y $package
    elif command -v yum &> /dev/null; then
        show_message "Installing $package using yum..."
        yum install -y $package
    elif command -v dnf &> /dev/null; then
        show_message "Installing $package using dnf..."
        dnf install -y $package
    elif command -v apk &> /dev/null; then
        show_message "Installing $package using apk..."
        apk add --no-cache $package
    else
        echo "Could not install $package. No supported package manager found."
        return 1
    fi
    return 0
}

# Function to check if Git is installed in Wine
is_git_installed_in_wine() {
    $wine_executable "C:\\Program Files\\Git\\bin\\git.exe" --version &> /dev/null
    return $?
}

# Function to download and extract mt5linux from GitHub
download_mt5linux_zip() {
    show_message "Downloading mt5linux ZIP from GitHub..."
    
    # Create temporary directory
    mkdir -p /tmp/mt5linux
    
    # Download the ZIP file
    if check_dependency "curl"; then
        curl -L $mt5linux_zip_url -o /tmp/mt5linux.zip
    elif check_dependency "wget"; then
        wget -q $mt5linux_zip_url -O /tmp/mt5linux.zip
    else
        echo "Neither curl nor wget is available. Cannot download mt5linux."
        return 1
    fi
    
    # Extract the ZIP file
    if check_dependency "unzip"; then
        unzip -q /tmp/mt5linux.zip -d /tmp
        mv /tmp/mt5linux-master/* /tmp/mt5linux/
        rm -rf /tmp/mt5linux-master
    else
        show_message "unzip not found, using Python for extraction..."
        python3 -c "
import zipfile
import os
import shutil
with zipfile.ZipFile('/tmp/mt5linux.zip', 'r') as zip_ref:
    zip_ref.extractall('/tmp')
if os.path.exists('/tmp/mt5linux-master'):
    for item in os.listdir('/tmp/mt5linux-master'):
        s = os.path.join('/tmp/mt5linux-master', item)
        d = os.path.join('/tmp/mt5linux', item)
        if os.path.isdir(s):
            shutil.copytree(s, d)
        else:
            shutil.copy2(s, d)
    shutil.rmtree('/tmp/mt5linux-master')
"
    fi
    
    # Clean up
    rm -f /tmp/mt5linux.zip
    return 0
}

# Function to check if a Python package is installed
is_python_package_installed() {
    python3 -c "import importlib.util; exit(0 if importlib.util.find_spec('$1') else 1)" 2>/dev/null
    return $?
}

# Function to check if a Python package is installed in Wine
is_wine_python_package_installed() {
    $wine_executable python -c "import importlib.util; exit(0 if importlib.util.find_spec('$1') else 1)" 2>/dev/null
    return $?
}

# Check for necessary dependencies
check_dependency "curl" || install_package "curl"
check_dependency "$wine_executable" || { echo "Wine must be installed manually."; exit 1; }

# Try to fix permission issues
show_message "Fixing permissions..."
mkdir -p /config/.cache/openbox/sessions 2>/dev/null || true
chmod -R 777 /config/.cache 2>/dev/null || true
mkdir -p /tmp/.X11-unix 2>/dev/null || true
chmod 1777 /tmp/.X11-unix 2>/dev/null || true

# Install Mono if not present
if [ ! -e "/config/.wine/drive_c/windows/mono" ]; then
    show_message "[1/7] Downloading and installing Mono..."
    curl -o /config/.wine/drive_c/mono.msi $mono_url
    WINEDLLOVERRIDES=mscoree=d $wine_executable msiexec /i /config/.wine/drive_c/mono.msi /qn
    rm /config/.wine/drive_c/mono.msi
    show_message "[1/7] Mono installed."
else
    show_message "[1/7] Mono is already installed."
fi

# Check if MetaTrader 5 is already installed
if [ -e "$mt5file" ]; then
    show_message "[2/7] File $mt5file already exists."
else
    show_message "[2/7] File $mt5file is not installed. Installing..."

    # Set Windows 10 mode in Wine and download and install MT5
    $wine_executable reg add "HKEY_CURRENT_USER\\Software\\Wine" /v Version /t REG_SZ /d "win10" /f
    show_message "[3/7] Downloading EXNESS MT5 installer..."
    curl -o /config/.wine/drive_c/exness5setup.exe $mt5setup_url
    show_message "[3/7] Installing EXNESS MT5..."
    $wine_executable "/config/.wine/drive_c/exness5setup.exe" "/auto" &
    wait
    rm -f /config/.wine/drive_c/exness5setup.exe
fi

# Recheck if MetaTrader 5 is installed
if [ -e "$mt5file" ]; then
    show_message "[4/7] File $mt5file is installed. Running MT5..."
    $wine_executable "$mt5file" &
else
    show_message "[4/7] File $mt5file is not installed. MT5 cannot be run."
fi

# Install Python in Wine if not present
if ! $wine_executable python --version 2>/dev/null; then
    show_message "[5/7] Installing Python in Wine..."
    curl -L $python_url -o /tmp/python-installer.exe
    $wine_executable /tmp/python-installer.exe /quiet InstallAllUsers=1 PrependPath=1
    rm /tmp/python-installer.exe
    show_message "[5/7] Python installed in Wine."
else
    show_message "[5/7] Python is already installed in Wine."
fi

# Install Git for Windows in Wine if not present
if ! is_git_installed_in_wine; then
    show_message "[5/7] Installing Git for Windows in Wine..."
    # Download Git installer
    curl -L $git_win_url -o /tmp/git-installer.exe
    
    # Disable Wine debug messages temporarily
    WINEDEBUG="-all"
    export WINEDEBUG
    
    # Run installer silently
    $wine_executable /tmp/git-installer.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS
    
    # Wait for installation to complete
    sleep 10
    
    # Reset Wine debug messages
    unset WINEDEBUG
    
    # Clean up
    rm -f /tmp/git-installer.exe
    
    # Add Git to the Windows PATH if needed
    $wine_executable reg add "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment" /v PATH /t REG_EXPAND_SZ /d "%PATH%;C:\\Program Files\\Git\\cmd" /f
    
    show_message "[5/7] Git for Windows installed in Wine."
else
    show_message "[5/7] Git for Windows is already installed in Wine."
fi

# Upgrade pip and install required packages
show_message "[6/7] Installing Python libraries"
$wine_executable python -m pip install --upgrade --no-cache-dir pip

# Install MetaTrader5 library in Windows if not installed
show_message "[6/7] Installing MetaTrader5 library in Windows"
if ! is_wine_python_package_installed "MetaTrader5"; then
    $wine_executable python -m pip install --no-cache-dir --break-system-packages MetaTrader5==$metatrader_version
fi

# Install mt5linux library in Windows if not installed
show_message "[6/7] Checking and installing mt5linux library in Windows if necessary"
if ! is_wine_python_package_installed "mt5linux"; then
    # Download mt5linux to Windows via Python script
    cat > /tmp/install_mt5linux.py << EOF
import os
import urllib.request
import zipfile
import subprocess
import shutil

# Create temp directory
os.makedirs("C:\\\\mt5linux", exist_ok=True)

# Download zip file
zip_url = "$mt5linux_zip_url"
zip_file = "C:\\\\mt5linux.zip"
urllib.request.urlretrieve(zip_url, zip_file)

# Extract zip file
with zipfile.ZipFile(zip_file, "r") as zip_ref:
    zip_ref.extractall("C:\\\\")

# Create empty requirements.txt
with open("C:\\\\mt5linux-master\\\\requirements.txt", "w") as f:
    pass

# Install the package
os.chdir("C:\\\\mt5linux-master")
subprocess.call(["pip", "install", "--break-system-packages", "."])
subprocess.call(["pip", "install", "--break-system-packages", "rpyc"])

# Clean up
os.chdir("C:\\\\")
os.remove(zip_file)
shutil.rmtree("C:\\\\mt5linux-master")
EOF
    
    # Run the Python script in Wine
    $wine_executable python /tmp/install_mt5linux.py
    rm -f /tmp/install_mt5linux.py
fi

# Install mt5linux in Linux if not installed
show_message "[6/7] Installing mt5linux in Linux if necessary"
if ! is_python_package_installed "mt5linux"; then
    # Download and extract mt5linux
    download_mt5linux_zip
    
    # Install mt5linux from the extracted directory
    cd /tmp/mt5linux
    touch requirements.txt
    
    # Install mt5linux and rpyc
    python3 -m pip install --user --break-system-packages .
    python3 -m pip install --user --break-system-packages rpyc
    
    cd -
    rm -rf /tmp/mt5linux
fi

# Install pyxdg library in Linux if not installed
show_message "[6/7] Checking and installing pyxdg library in Linux if necessary"
if ! is_python_package_installed "pyxdg"; then
    pip install --user --upgrade --break-system-packages pyxdg
fi

# Start the MT5 server on Linux
show_message "[7/7] Starting the mt5linux server..."
export PYTHONPATH=$HOME/.local/lib/python3*/site-packages:$PYTHONPATH
python3 -m mt5linux --host 0.0.0.0 -p $mt5server_port -w $wine_executable python.exe &

# Give the server some time to start
sleep 5

# Check if the server is running
if ss -tuln | grep ":$mt5server_port" > /dev/null; then
    show_message "[7/7] The mt5linux server is running on port $mt5server_port."
else
    show_message "[7/7] Failed to start the mt5linux server on port $mt5server_port."
    # Show more information about possible failure
    show_message "Checking if mt5linux module is installed correctly..."
    python3 -c "import mt5linux; print('mt5linux is installed at:', mt5linux.__file__)" || echo "mt5linux is not properly installed"
fi

# Keep the script running to prevent container exit
tail -f /dev/null
