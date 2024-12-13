# powershell-scripts
Some useful scripts to manage Windows for development. I suggest putting them into a Scripts folder inside your home and then adding into user $PATH Environment variable the path to the folder (eg: c:\Users\your_user\Scripts)

## reload_path.ps1
Used to reload PATH Environment variable outside, inside a PowerShell session without exit

## reload_environment.ps1
Used to reload all environment variables if changed outside the session

# Python and jupyter helpers
## mypythonutils.ps1
Based on the assumption you have a specific environment variable for each Python installation like PYTHON_HOME_3_10 for 3.10.x and PYTHON_HOME_3_13 for 3.13.x,
the script provides 3 features:
1. Set current **Python version** choosing among installed (es: 3.10, 3.11 etc)
2. Show available **venv** and choose which you want to load among the available for the current folder 
3. Create a specific **venv** based on a specific python installation in the current folder and load it

## start_jupyter.ps1
This script moves to jupyter folder, lists available **venv**, loads chosen, and **starts jupyter lab** inside.

## python_poweshell_profile.ps1
If copied into *$PROFILE* file, this script realises if you enter a folder with some __.venv* python venv__ folders and asks you which one you want to **activate**.
