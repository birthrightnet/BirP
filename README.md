# Birthright Preservation Patch

The Birthright Preservation Patch is an enhancement for the Windows version of Birthright: The Gorgon's Alliance. Its primary goal is to address bugs within the game while also enhancing existing features for a better overall experience.

## Installation

Before you install the Birthright Preservation Patch, make sure you have Birthright: The Gorgon's Alliance and Patch 1.4 already installed. You can refer to the [installation guide][kw-install].

To install the Birthright Preservation Patch, download the latest ZIP archive from the [ModDB][moddb-birp] page and extract the files into your installation folder.

## Changelog

Once we have our first build, this section will include a summary of the more significant changes. For the full list of changes, please see the [Changelog](./CHANGELOG.md).

## Compiling

### Prerequisites

In order to compile this project, you will need:

* [DirectX 5.0 SDK][archive-directx]
* [Watcom 10.6][winworld-watcom]
* [Windows 95 DDK][winworld-winddk]

Add the header files and compiler directories to your `INCLUDE` and `PATH` environment variables, respectively. For example:

```
SET PATH=C:\WATCOM\BINNT;C:\WATCOM\BINW;%PATH%
SET INCLUDE=C:\WATCOM\H;C:\WATCOM\H\NT;C:\DirectXSDK
```

### Compiling the game

You can compile the Windows 95 version of Birthright (which runs on operating systems up to Windows 11) by running:

`MAKE.BAT WIN95`

DOS will also compile (on versions of Windows up to Windows ME), but currently has some missing fonts.

### Updating Version Numbers

Internal version numbers are set in `VERSION.CPP`, while the version number for the Windows executable is set in `NOVA95.RC`.

## Contributing

Pull requests are welcome. For large changes or new features, please open an issue first to discuss what you would like to change.

## Disclaimer

This patch aims to enhance and fix bugs in **Birthright: The Gorgon's Alliance**, originally developed by **Synergistic Software** for **Sierra On-Line, Inc.** All rights to the original game and its assets remain with the original creators. The patch is not endorsed or supported by the original developers or the current license holders. The legality of using this source code may vary by jurisdiction.

This patch is provided free of charge and is not intended for commercial use. Any distribution of this patch must not be for profit. It is provided 'as-is' without any warranty. The creator(s) are not responsible for any issues that may arise from using this patch, including data loss, game crashes, or other unintended consequences.

The patch is developed as a community effort. The original developers retain their rights to the original source code. Where permissable by law, modifications to the original source code are provided under the MIT license. Feedback and contributions are welcome, but please honor the rights of the original creators.

[archive-directx]: https://archive.org/details/idx5sdk
[kw-install]: https://www.kiranwelle.com/birthright/
[moddb-birp]: https://www.moddb.com/mods/birthright-preservation-patch
[releases]: https://github.com/Shiryou/BirP/releases
[winworld-watcom]: https://winworldpc.com/product/watcom-c-c/106
[winworld-winddk]: https://winworldpc.com/product/windows-sdk-ddk/windows-95-ddk
