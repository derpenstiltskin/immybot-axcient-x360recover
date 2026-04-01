# Usage

## Prerequisites

**Axcient API Key:** Following the [instructions provided by Axcient](https://help.axcient.com/360001190313-Axcient-x360Portal-/generating-and-managing-api-keys), generate an API key.

**Axcient Vault ID:** Grab the ID of your Axcient vault ID (number) from the x360Recover vault or from the API.

**Axcient Logo:** Get a logo for Axcient to use in the integration.

## Install Integration

### Integration Script

In the Script Editor, create a new script with the following settings:

| | |
|---|---|
| **Name:**              | Axcient x360Recover |
| **Type:**              | Integration         |
| **Execution Content:** | Cloud Script        |
| **Language:**          | PowerShell          |

Copy the contents of [src/Integration.ps1](src/Integration.ps1) to the script and save.

### Module Script

In the Script Editor, create a new script with the following settings:

| | |
|---|---|
| **Name:**              | AxcientX360RecoverAPI |
| **Type:**              | Module.               |
| **Execution Content:** | Cloud Script          |
| **Language:**          | PowerShell            |

Copy the contents of [src/Module.ps1](src/Module.ps1) to the script and save.

### Download Script

In the Script Editor, create a new script with the following settings:

| | |
|---|---|
| **Name:**              | Axcient x360Recover (Integration) Download Installer Script |
| **Type:**              | Download Installer                                          |
| **Execution Content:** | MetaScript                                                  |
| **Language:**          | PowerShell                                                  |

Copy the contents of [src/Download.ps1](src/Download.ps1) to the script and save.

### Installation Script

In the Script Editor, create a new script with the following settings:

| | |
|---|---|
| **Name:**              | Axcient x360Recover (Integration) Installation Script |
| **Type:**              | Software Version Action                               |
| **Execution Content:** | MetaScript                                            |
| **Language:**          | PowerShell                                            |

Copy the contents of [src/Download.ps1](src/Install.ps1) to the script and save.

### Configuration Task

In Tasks, create a new task with the following settings:

**Task Info**

| | |
|---|---|
| **Name:**         | Axcient x360Recover (Integration) Configuration Task |
| **Icon:**         | The Axcient logo you obtained in the prerequisites   |
| **Runs Against:** | Software (Configuration Task)                        |

**Authorization**

Everything in this section is up to you.

**Integration**

Don't choose an integration type.

**Parameters**

| | |
|---|---|
| **Use Param Block:** | Unchecked |

Add the following parameters:

| | |
|---|---|
| **Name:**           | ApplianceIPAddress |
| **Data Type:**      | Text               |
| **Requires Input:** | Unchecked          |
| **Hidden:**         | Unchecked          |
| **Description:**    | Optional           |
| **Default Value:**  | None               |

| | |
|---|---|
| **Name:**           | ShowTrayIcon |
| **Data Type:**      | Boolean      |
| **Requires Input:** | Unchecked    |
| **Hidden:**         | Unchecked    |
| **Description:**    | Optional     |
| **Default Value:**  | False        |

**Script**

| | |
|---|---|
| **Combined or Separate Scripts:** | Separate  |
| **Test:**                         | Disabled  |
| **Get:**                          | Unchecked |
| **Set:**                          | Unchecked |

### Integration Type

In Integration Types, create a new type with the following settings:

| | |
|---|---|
| **Logo:**                | Choose the logo you added to the media library for the configuration task |
| **Name:**                | Axcient x360Recover                                                       |
| **Documentation URL:**   | Optional, if you want to fill it out use the URL for this page            |
| **Integration Type ID:** | Click Generate                                                            |
| **Integration Script:**  | Choose Axcient x360Recover                                                |
| **Release Tag:**         | Alpha                                                                     |
| **Enabled:**             | False                                                                     |

### Software

In Library, create a new software with the following settings:

#### Installer

| | |
|---|---|
| **Installer Type:** | None |

#### Software

Choose "Add Software to New Software"

**Software Info**

| | |
|---|---|
| **Name:**            | Axcient x360Recover (Integration)                                         |
| **Icon:**            | Choose the logo you added to the media library for the configuration task |
| **Notes:**           | Optional                                                                  |
| **Reboot Required:** | Unchecked                                                                 |
| **Recommended:**     | Optional                                                                  |

**Licensing**

| | |
|---|---|
| **Licensing:** | None |

**Version Detection**

| | |
|---|---|
| **Detection Method:** | Display Name            |
| **Display Name:**     | Regex                   |
| **Search Filters:**   | ^Replibit Backup Agent$ |

| | |
|---|---|
| **Installation:**               | Axcient x360Recover (Integration) Installation Script         |
| **Installation Prerequisites:** | Regex                                                         |
| **Uninstallation:**             | Uninstall Multiple Versions - RegEx Detection String Required |
| **Upgrade Strategy:**           | None                                                          |
| **Configuration Task:**         | Axcient x360Recover (Integration) Configuration Task          |

| | |
|---|---|
| **Advanced Settings:** | Show All          |
| **Dynamic Versions:**  | Unchecked         |
| **Agent Integration:** | Agent x360Recover |

| | |
|---|---|
| **Repair Strategy:**  | None               |
| **Hideen:**           | Unchecked          |

| | |
|---|---|
| **Post-Installation:**   | None                                                        |
| **Post-Uninstallation:** | None                                                        |
| **Test-Required:**       | Unchecked                                                   |
| **Post-Uninstallation:** | None                                                        |
| **Download Installer:**  | Axcient x360Recover (Integration) Download Installer Script |

# Activate Integration

In Integrations, click Reload Integration Types, then Add Integration. Choose the Axcient x360Recover integration. Fill out the form with the information you gathered in the prerequisites and the options you want.