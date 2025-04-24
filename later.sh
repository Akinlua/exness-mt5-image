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
venv_path="/config/venv"
venv_python="$venv_path/bin/python3"
venv_pip="$venv_path/bin/pip"

# Function to display a graphical message
show_message() {
    echo "$1"
}

# Function to check if a dependency is installed
check_dependency() {
    if ! command -v $1 &> /dev/null; then
        echo "$1 is not installed. Attempting to continue without it."
        return 1
    fi
    return 0
}

# Function to create Python virtual environment
create_virtualenv() {
    # Try different approaches to create a virtual environment
    if command -v python3 -m venv &> /dev/null; then
        show_message "Creating Python virtual environment using venv..."
        python3 -m venv $venv_path
    elif command -v virtualenv &> /dev/null; then
        show_message "Creating Python virtual environment using virtualenv..."
        virtualenv $venv_path
    else
        # Use system Python as fallback
        show_message "No virtual environment tools available. Using system Python..."
        # Create directories to simulate venv structure
        mkdir -p $venv_path/bin
        ln -sf $(which python3) $venv_path/bin/python3
        ln -sf $(which pip3) $venv_path/bin/pip
        return 1
    fi
    return 0
}

# Function to install Python packages with fallback
install_package() {
    package_name=$1
    version=$2
    
    if [ -x "$venv_pip" ]; then
        # Try installing in virtual environment first
        if [ -n "$version" ]; then
            $venv_pip install --upgrade --no-cache-dir $package_name==$version
        else
            $venv_pip install --upgrade --no-cache-dir $package_name
        fi
    else
        # Fall back to system pip with --user flag
        if [ -n "$version" ]; then
            pip3 install --user --upgrade --no-cache-dir $package_name==$version
        else
            pip3 install --user --upgrade --no-cache-dir $package_name
        fi
    fi
}

# Function to check if a Python package is installed
is_python_package_installed() {
    if [ -x "$venv_python" ]; then
        $venv_python -c "import importlib.util; exit(not importlib.util.find_spec('$1'))" 2>/dev/null
    else
        python3 -c "import importlib.util; exit(not importlib.util.find_spec('$1'))" 2>/dev/null
    fi
    return $?
}

# Function to check if a Python package is installed in Wine
is_wine_python_package_installed() {
    $wine_executable python -c "import importlib.util; exit(not importlib.util.find_spec('$1'))" 2>/dev/null
    return $?
}

# Check for necessary dependencies
check_dependency "curl" || true
check_dependency "$wine_executable" || true
check_dependency "python3" || true

# Try to fix permission issues
show_message "Fixing permissions..."
mkdir -p /config/.cache/openbox/sessions 2>/dev/null || true
chmod -R 777 /config/.cache 2>/dev/null || true
mkdir -p /tmp/.X11-unix 2>/dev/null || true
chmod 1777 /tmp/.X11-unix 2>/dev/null || true

# Create virtual environment if it doesn't exist
if [ ! -d "$venv_path" ]; then
    create_virtualenv
fi

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

# Upgrade pip and install required packages in Wine
show_message "[6/7] Installing Python libraries in Wine"
$wine_executable python -m pip install --upgrade --no-cache-dir pip

# Install MetaTrader5 library in Windows if not installed
show_message "[6/7] Installing MetaTrader5 library in Windows"
if ! is_wine_python_package_installed "MetaTrader5"; then
    $wine_executable python -m pip install --no-cache-dir MetaTrader5==$metatrader_version
fi

# Install mt5linux library in Windows if not installed
show_message "[6/7] Checking and installing mt5linux library in Windows if necessary"
if ! is_wine_python_package_installed "mt5linux"; then
    $wine_executable python -m pip install --no-cache-dir mt5linux
fi

# Install mt5linux library in Linux if not installed
show_message "[6/7] Checking and installing mt5linux library in Linux if necessary"
if ! is_python_package_installed "mt5linux"; then
    install_package "mt5linux"
fi

# Install pyxdg library in Linux if not installed
show_message "[6/7] Checking and installing pyxdg library in Linux if necessary"
if ! is_python_package_installed "pyxdg"; then
    install_package "pyxdg"
fi

# Start the MT5 server on Linux - use venv if available, otherwise fallback to system python
show_message "[7/7] Starting the mt5linux server..."
if [ -x "$venv_python" ]; then
    $venv_python -m mt5linux --host 0.0.0.0 -p $mt5server_port -w $wine_executable python.exe &
    PYTHON_CMD="$venv_python"
else
    # Try system Python with --user packages
    export PYTHONPATH=$HOME/.local/lib/python3.*/site-packages:$PYTHONPATH
    python3 -m mt5linux --host 0.0.0.0 -p $mt5server_port -w $wine_executable python.exe &
    PYTHON_CMD="python3"
fi

# Give the server some time to start
sleep 5

# Check if the server is running
if ss -tuln | grep ":$mt5server_port" > /dev/null; then
    show_message "[7/7] The mt5linux server is running on port $mt5server_port."
else
    show_message "[7/7] Failed to start the mt5linux server on port $mt5server_port."
    show_message "Trying alternative approach to install packages..."
    
    # Try installing directly with --user
    pip3 install --user --no-cache-dir mt5linux pyxdg
    
    # Try starting server again
    python3 -m mt5linux --host 0.0.0.0 -p $mt5server_port -w $wine_executable python.exe &
    
    # Check again
    sleep 5
    if ss -tuln | grep ":$mt5server_port" > /dev/null; then
        show_message "[7/7] The mt5linux server is now running on port $mt5server_port."
    else
        show_message "[7/7] Still failed to start the mt5linux server. Please check system requirements."
    fi
fi

# Keep the script running
tail -f /dev/null
