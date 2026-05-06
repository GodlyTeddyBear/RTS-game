# Building Plugin

Personal Roblox Studio building plugin source.

## Build

Run:

```powershell
rojo build StudioPlugins/BuildingPlugin.project.json -o StudioPlugins/BuildingPlugin.rbxm
```

Then place `StudioPlugins/BuildingPlugin.rbxm` into your Roblox Studio plugins folder, or open it in Studio and save it as a local plugin.

## Features

- Browse and insert models from `ReplicatedStorage.__Assets__`
- Save the current selection into `ReplicatedStorage.__Assets__`
- Wrap the current selection into a new folder
- Organize selected parent children by name into folders
- Create nested folder structures from labeled preset groups
- Duplicate the current selection
- Bulk property shortcuts for build-focused part properties
- Editable labeled folder preset groups stored in plugin settings
