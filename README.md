# PeerPower
> ### When the grid goes down, PeerPower stays up.

![AppIcon-PeerPower](Resources/AppIcon.svg)

- [Gawain Marti](https://github.com/Cryptric)
- [Ilija Pejic](https://github.com/To-Ye)
- [Alexander Eggerth](https://github.com/AlexTheTallCoder)
- [Samuel Kreyenbühl](https://github.com/SamKry)

Im Rahmen vom **HACKATHON THURGAU 2023** haben wir PeerPower entwickelt.

PeerPower ermöglicht ein Offline Kommunikations-Netzwerk mittels BLE (Bluetooth Low Energy). 

Dabei Stehen folgende Punkte im Zetrum:

+ Offline Kommunikation
+ Das Nutzen bestehender Hardware
+ Kostengünstige Implementation
+ Tiefen Energieverbrauch durch SOS-Protokoll und BLE (Bluetooth Low Energy) + Skalierbarkeit
+ Vielzahl von Erweiterungsmöglichkeiten
+ Erhöhte Widerstandsfähigkeit
+ Plattformunabhängige Applikation (Flutter)

Für weitere Informationen sehen Sie sich gerne die Präsentation an: 
[Präsentation (PDF)](Resources/PeerPower_ppt.pdf)

## PeerPower App

![Screenshot PeerPower-App](Resources/PeerPower-App.jpeg)

An Android-Application that acts as a client interface and repeat device for a BLE based P2P-Network. The PeerPower-Network
helps to enforce the ressilience of people that have to deal with emergencies by enableing mass-participation in a SOS-Network.

### Getting Started
#### Prerequisites
##### Flutter
Flutter 3.0.2 • channel stable • https://github.com/flutter/flutter.git

Dart 2.17.3

DevTools 2.12.2
##### Android Studio
[How to install Android Studio](https://developer.android.com/studio/install)


(Application can also be built without Android Studio but it is not guaranteed to fully work)

#### Installing
Clone this repository with submodules
```
git clone https://github.com/To-Ye/PeerPower.git
cd path/to/repo/mobile_application
git pull
```

Open Android-Studio and build apk


[How to build application with Android Studio](https://developer.android.com/studio/run/)

Install built .apk un your android device.

> The application can also be installed directly by Android Studio (USB-Debugging needs to be enabled on the target device)

### Build With
* [Dart](https://dart.dev/) -  Dart is a client-optimized language for fast apps on any platform 
* [Flutter](https://flutter.dev/) - Open Source framework by Google for building beautiful, natively compiled, multi-platform applications from a single codebase.



## Erweiterung durch ESP-32 Repeaters

Mittels kostengünstigen ESP-32 Mikrocontrollern kann das Netzwerk weiter ausgebaut und verstärkt werden.

- [ESP32 code](ESP32/Sandbox) 

NOTE: Aktuell steht noch keine direkte Kommunikation mit der PeerPower App. 