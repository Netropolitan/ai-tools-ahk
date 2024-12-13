# Set Up AI Tools with OpenAI 4o-mini API Integration

<a href="url"><img src="./res/AI-Tool-AHK.gif"></a><br></br>

### Table of Contents

- [What's this?](#whats-this)  
- [Installation](#installation)  
- [Usage](#usage)  
- [Options](#options)  
- [Credits](#credits)  
&nbsp;

## What's this?  

This is a Windows tool that enables running custom OpenAI prompts on text in any window using global hotkeys.

i.e. Low-friction AI text editing ("spicy autocomplete") anywhere in Windows.

**Where can it be used?**  

Almost anywhere in Windows where you can enter text.
&nbsp;  

## How To: Set Up AI Tools with OpenAI API Integration
**Creation Date: December 13, 2024**
**Gudie Created By:** [Netropolitan Academy](https://netropolitan.xyz) & [Jamie Bykov-Brett](https://bykovbrett.net/)
**Applications Required:** OpenAI API, AutoHotkey
This comprehensive guide walks you through the steps to install and configure AI Tools, integrating OpenAI API for enhanced functionality. Follow these instructions to get started with AI-powered automation on your system.

Whether you are new to automation or an experienced user, this guide ensures a smooth installation and setup process.


## Step-By-Step Guide

**1. Obtain an OpenAI API Key**

The script requires an OpenAI API key for full functionality. If you don’t already have one:

Navigate to [OpenAI’s API page](https://platform.openai.com/settings/organization/api-keys) 

Sign in or create an account.

Go to the API Key section and generate a new secret key.

Copy this key for use in the next steps. Keep a note of it somewhere because you will need it and you won't be able to see it again after you navivate away from the key

The script will prompt you to input your API key upon the first run. Alternatively, you can manually add it to the settings.ini file under the appropriate section.


**2. Download and Extract Files**

Navigate to the [AI Tools GitHub repository](https://github.com/Netropolitan/ai-tools-ahk) and download the latest release .zip file. Extract the contents to your desired directory.


**3. Install AutoHotkey**

If AutoHotkey is not already installed on your system:

[Visit the AutoHotkey website.](https://www.autohotkey.com/)

Download the latest version suitable for your system.

Follow the installation instructions on the site.

*Note: You can use the .exe version of the AI Tools script if you prefer not to install AutoHotkey. The script is portable and doesn’t require installation.*


**4. Run the Script**

- If AutoHotkey is installed, double-click the AI-Tools.ahk file to run the script.

- For users without AutoHotkey, double-click the .exe file in the extracted folder.

When the script runs for the first time, it will generate a settings.ini file in the same directory. This file contains configurable options such as hotkeys and prompts.


**5. Configure Start-Up Settings**

To ensure the script launches automatically when your computer starts:


*Option 1: From the Script Tray Icon*

Right-click the tray icon for the script.

Select "Start With Windows."


*Option 2: Manually Create a Shortcut**

Right-click the .exe or .ahk file and select "Create Shortcut."

Place the shortcut in the Startup folder:

Press Win+R, type shell:startup, and press Enter.

Drag and drop the shortcut into the Startup folder.


## Usage

The default hotkeys and prompts are:

Ctrl+Shift+J: Automatically select the current text (line or paragraph) and run the "Fix Spelling" prompt. Replaces text with the corrected version.

Ctrl+Shift+K: Automatically select the current text and open the prompt menu.

Ctrl+Alt+Shift+K: Manually select text, then open the prompt menu to pick a specific action.

You can modify these hotkeys or add your own in the settings.ini file.


## Advanced Configuration

The settings.ini file allows you to:

Change hotkey assignments.

Customise prompts.

Adjust the API mode and model.

Edit the file using any text editor and save changes before restarting the script.


## Options

The `settings.ini` file contains the settings for the script. You can edit this file to change the prompts, the API mode and model to use, and individual model settings.


## Supported OpenAI APIs and Models
OpenAI and Azure OpenAI API's are supported.

    API:
        /v1/chat/completions (Default - OpenAI)  
        /openai/deployments/*/chat/completions (Azure)

    Models:
        gpt4o-mini

## Compatibility
Tested on Windows 10 Pro 22H2 64-bit.

## Credits

ecornell (AHK), TheArkive (JXON_ahk2, M-ArkDown_ahk2), iseahound (SetSystemCursor), and the AHK community.

- https://github.com/ecornell/ai-tools-ahk
- https://github.com/iseahound/SetSystemCursor
- https://github.com/TheArkive/JXON_ahk2
- https://github.com/TheArkive/M-ArkDown_ahk2

