## Get Fairy-Stockfish engine files

**To play against the AI,** you need to provide the **Fairy-Stockfish** engine binary files:

1. Download the **Fairy-Stockfish** engine files: [Fairy-Stockfish 14 Release Page](https://github.com/fairy-stockfish/Fairy-Stockfish/releases/tag/fairy_sf_14)

    *(You can only download files for your build target platform)*
    * for Linux
      - `fairy-stockfish_x86-64-bmi2`
      - `fairy-stockfish_x86-64-modern`
      - `fairy-stockfish_x86-64`
    * for Windows
      - `fairy-stockfish_x86-64-bmi2.exe`
      - `fairy-stockfish_x86-64-modern.exe`
      - `fairy-stockfish_x86-64.exe`

2. Place the downloaded executables inside the `PROJECT_ROOT/bin/` folder.

<br>

***Note:** you should not download **largeboard** versions, because this game only supports 8x8 board variants*

You should download all **BMI2**, **modern** and **64-bit** versions (The game picks the right one at runtime based on your CPU)

<br>

## Direct Download links
- [fairy-stockfish_x86-64-bmi2](https://github.com/fairy-stockfish/Fairy-Stockfish/releases/download/fairy_sf_14/fairy-stockfish_x86-64-bmi2)
- [fairy-stockfish_x86-64-bmi2.exe](https://github.com/fairy-stockfish/Fairy-Stockfish/releases/download/fairy_sf_14/fairy-stockfish_x86-64-bmi2.exe)
- [fairy-stockfish_x86-64-modern](https://github.com/fairy-stockfish/Fairy-Stockfish/releases/download/fairy_sf_14/fairy-stockfish_x86-64-modern)
- [fairy-stockfish_x86-64-modern.exe](https://github.com/fairy-stockfish/Fairy-Stockfish/releases/download/fairy_sf_14/fairy-stockfish_x86-64-modern.exe)
- [fairy-stockfish_x86-64](https://github.com/fairy-stockfish/Fairy-Stockfish/releases/download/fairy_sf_14/fairy-stockfish_x86-64)
- [fairy-stockfish_x86-64.exe](https://github.com/fairy-stockfish/Fairy-Stockfish/releases/download/fairy_sf_14/fairy-stockfish_x86-64.exe)

<br>

You can use [get_engine_files.sh](get_engine_files.sh) shell script to download all engine files.
(the script automatically downloads the engine files into the `PROJECT_ROOT/bin/` folder)

<br>

## Ready
Folder structure must look like this when the downloads are finished:

```
chessmaty (PROJECT_ROOT)
├── bin
│   ├── fairy-stockfish_x86-64
│   ├── fairy-stockfish_x86-64-bmi2
│   ├── fairy-stockfish_x86-64-bmi2.exe
│   ├── fairy-stockfish_x86-64-modern
│   ├── fairy-stockfish_x86-64-modern.exe
│   ├── fairy-stockfish_x86-64.exe
│   ├── get_engine_files.sh
│   └── README.md
├── godot
├── rust
└── ...
```