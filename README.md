# IMinidrone controller

This project is new controller interface for Parrot minidrones.

It contains three controllers:
- a common example with text buttons,
- a multitouch interface for 3D motions, and
- a motion sensor-based controlling.


# Screenshots

## Main screen

![alt main screen](https://github.com/loki04/minidrone-swift/blob/master/screenshots/MainPage.jpg)

You can select your desired controller mode in the segmented control. After the drone can be discovered the name of the drone will be in the table. To start flying jut tap the name of the drone.

Note: After you selected the drone, the controller page will be displayed with and alert window. In this alert will be on the screen until the connection to the drone is established successfully.

## Button-based controller

![alt button-based screen](https://github.com/loki04/minidrone-swift/blob/master/screenshots/ControllerButtonBased.jpg)

This controller is button-based which means you have to tap the buttons to make the drone to do any action. Until you release any of the flying button, the drone will do the same command. So, for example if you tap and release the "forward" button once the drone will move forward a bit. If you want to move forward continuously, do not release the button.

Note: The "emergency" button turn off the motors and the drone will fall down.

## Multitouch controller

![alt multitouch screen](https://github.com/loki04/minidrone-swift/blob/master/screenshots/ControllerMultiTouchBased.jpg)

This controller is similar for the button-based one, but there is no buttons for flying commands. You can press and release the screen any time and any position over the flying images. In addition you can move your touch around the images to change to a different flying commands.

Note: The "take-off", "landing", "emergency" actions still a button to avoid accidental press of them.

## Motion sensor-based controller

![alt motion sensor screen](https://github.com/loki04/minidrone-swift/blob/master/screenshots/ControllerMotionBased.jpg)

This controller is based on accelerometer and location services. The controller design is changed a bit to the previous ones. The "up", and "down" commands are at the left side of the controller which works like in the Multitouch controller interface. There is a new controller image for yaw. The "360" image is about to recognize one finger drawn circles. You can draw clockwise or counter-clockwise circles to turn the drone to the same direction.

In addition the remaining controls are the following:
- First of all you have to hold your phone in a landscape mode.
- If you tilt your phone forward or backward, the drone will follow your action in its face direction.
- If you tilt your phone left or right, the drone moves sideways
- You can also rotate your phone (yaw) around the Z axis. This will also make your drone to follow your yaw changes.

In additional your forward, backward, left, right actions can be seen in the phone screen as well (with appearing and disappearing icons).

Note: The sudden flying actions are limited. And very gently yaw actions are omitted.


# General troubleshooting

iPhones has some issues with BLE. It happens to cache some connections in a wrong state. If this happens restart your phone.


# Resources

- Basic SDK: https://developer.parrot.com/docs/SDK3/#ios
- How to connect: https://developer.parrot.com/docs/SDK3/#start-coding
- Firmwares: 
  - Updated ones: https://www.parrot.com/global/firmware-airborne-cargo-v268-uk
  - Old ones: https://github.com/SteveClement/airborne-cargo-drone/tree/master/fw
  - Hacking guide: https://github.com/SteveClement/airborne-cargo-drone/blob/master/parrot-minidrone-airborne-hacking.md
