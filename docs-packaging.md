---
title: Prismatic Packaging 
subtitle: Instructions for creating Prismatic packages from source
---


## Mac OS X

*Currently, Macs do not contain NVIDIA GPUs, so there is only a CPU version of the application bundle*


#### Building Mac OS X bundle with Qt

##### Building with Qt frameworks
In more recent version of Prismatic, CMake is configured to generate an app bundle. After you have built this, run the script "mac_build.sh" from within the build directory (i.e. run `../mac_build.sh`). This script handles the complicated process of copying the necessary Frameworks into the app bundle and reconfiguring the names of their library paths to point to the bundled version.

##### Building with static Qt (outdated)
Deploying on Mac requires a statically built version of the Qt libraries with `./configure -static` (see [here](http://doc.qt.io/qt-5/osx-deployment.html)). You will then build `prismatic-gui` through the Qt project `Qt/prismatic-gui.app` by invoking `qmake` (from the statically build version of Qt5). For example on my system I would invoke `/Users/ajpryor/Qt5/qtbase/bin/qmake` followed by `make -j8`, which results in `prismatic-gui.app` within the `Qt` folder. You can check that the binary is statically linked with `otool -L prismatic.gui.app/Contents/MacOS/prismatic-gui`. If the output from this command does not contain any Qt libraries, then you have successfully statically linked them.

From an existing version of the prismatic-gui.app bundle, simply copy the latest `prismatic-gui` into Contents/MacOS and the rest of the bundle configuration (such as the icons) should be taken care of

Should you need to remake the bundle, it should contain the following directory structure  

Contents/  
&nbsp;&nbsp;&nbsp;&nbsp;Info.plist  
&nbsp;&nbsp;&nbsp;&nbsp;MacOS/  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;prismatic-gui  
&nbsp;&nbsp;&nbsp;&nbsp;Resources/  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;prismatic-gui.icns

Where prismatic-gui.icns was made following [this blog post](https://blog.macsales.com/28492-create-your-own-custom-icons-in-10-7-5-or-later) using Inkscape to generate the images and `iconutil` to convert the iconset to a .icns.  

 Info.plist is a basic XML file with the following contents


~~~
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>prismatic-gui</string>
  <key>CFBundleName</key>
  <string>prismatic-gui</string>
  <key>CFBundleIconFile</key>
  <string>prismatic-gui.icns</string>
</dict>
</plist>
~~~

To distribute the package as a .dmg volume, copy the package to a new, empty folder, open Disk Utility and select `File -> New Image -> Image from folder`, select the folder containing the app, and set privileges to read/write. Mount the drive by double-clicking the image file, and then right click and select `Show View Options`. From here you can customize the size of the icons and change the background. To make a drag-and-drop installer, add a link to /Applications by opening a terminal, navigating to the mounted .dmg (likely in /Volumes/) and invoking the following command

~~~
ln -s /Applications Applications
~~~

You should then see the app and the Applications folder in the volume. 

## Windows 10

Configure/compile with `PRISMATIC_ENABLE_GUI=1` with CMake + Visual Studio (I use MSVS 2015) 64-bit. Set to Release mode and build the solution. Then you must copy the following .dll files into the Release directory containing prismatic-gui.exe

* libfftw3f-3.dll
* Qt5Core.dll
* Qt5Widgets.dll
* Qt5Gui.dll

Colin indicated that it may also be necessary to include the plugins/platforms/ folder from within Qt 5. I did not need this folder when compiling and running on machines all using Windows 10, but maybe this folder is necessary when distributing to older versions, so I include it to be safe.

To add the icon to the executable, open the solution in Visual Studio. Open the resources view `view -> Other Windows -> Resources View`, right click `prismatic-gui` and select `Add -> Resource` highlight Icon and click `Import`, choose the ".ico" file, and recompile. The ".ico" file was generated from a .png image using the online resource [convertIcon!](www.converticon.com). Sometimes this process is very finicky and you may need to manually edit the .rc and resource.h files to have lines `MAINICON ICON /path/to/ico` and `#define MAINICON 101` -- the compiler will use the lowest-numbered icon as the main application icon.

To create a deployment package, create a new Visual Studio project `File -> New -> Project -> Other Project Types -> Visual Studio Installer`. The first time I did this I did not see this option available and had to install an external plugin to make this option appear. Next, add all of the files in the bundle (including the platforms folder) to "Application Folder", and then edit the metadata for the project such as the company name, version number, target platform (change to x64), etc by selecting `View -> Solution Explorer` and editing the fields in Project Properties. Right click `prismatic-gui.exe` and create a shortcut and copy it into Users Desktop. Repeat for User's Program menu. Then right click the Application Folder, make a shortcut, and drag that to User's program menu. Left click each of these and set the Icon in the properties tab. This will install a desktop shortcut to the GUI and links in the start menu. Then build the solution to produce the .msi installer that may be distributed. Set the application icon under the Properties tab of the solution with `AddRemoveProgramsIcon` and set `AlwaysCreate` to True for the Application Folder.
