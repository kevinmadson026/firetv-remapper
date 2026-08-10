How to install:

don't need to install but need enable ADB on FireTv Stick previously and change Ip address on file run.bat: 

set IP_ADDRESS=192.168.1.7:5555

How to run:

execute run.bat and you are ready to go.

Functions:

- Remap the “Prime Video” and “Netflix” buttons on the remote control to open the Smartube and LazerPlay apps instead.

You can edit this by entering the name of the package you want to open in the firetv-remapper.sh file.

On the line:

APP01_PACKAGE="org.smarttube.stable"
APP02_PACKAGE="com.lazerplayer.app"

replace these with the package names you want.

To do:

- Add Disney+ and Hulu buttons
