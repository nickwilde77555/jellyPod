# jellyPod

An iPod style music player for Jellyfin, made in Processing 4. Only for android.

## How to use

Download the app from releases, install it (play protect will warn you about it being an older app, it isn't it just isnt compiled for the most recent version, and it uses a self signed certificate). Upon launching, allow notifications (the app has a persistent notification that shows the song info, which I believe helps it not die in the background. Then, input your jellyfin server information, and play some music!

## Features

The app currently can:
 - Fetch songs from a Jellyfin server
 - Allow the user to choose a song
 - Clickwheel functionality is implemented
 - Now playing screen with track info and album art is implemented
 - Shuffle functionality (hold the center button in the click wheel)

## Concerns about using the app

As already mentioned, play protect does not like my app. But that's why the code is open source. 

Something that may be concerning to the most security consious of you, the server credentials are stored in plaintext. I do not know how to safely store the data. 

The app does request notifications, but I promise the only time notifications are used are to display current song info.

If the app remains black when starting, it means the app couldn't connect to the jellyfin server. If you entered your credentials incorrectly you will need to clear the app's data in settings. Note the app only stores the server info, you will not lose anything else.

## Features I want to implement

 - Artist, album, and playlist views, instead of only tracks
 - Some kind of queue system.

## A.I. Disclosure

Generative A.I. (Gemini) was used to write portions of the app's backend. I am not familiar with networking in Java or Processing, but I did look at the code and ensure there wasnt anything like a hidden rm -rf in there. If it being AI assisted is enough to make you not want to use the app, fair. I did however write the entirety of the UI myself.

## Building from source

Simply download the source, add it to your Processing 4 sketchbook, connect your Android device, and run it!

## Preview Images

![Song selection](https://github.com/user-attachments/assets/bd5acb10-c0a1-4718-8b0c-35da0de880f0)

![Now Playing](https://github.com/user-attachments/assets/93755ec7-ba4d-430a-9b1d-c5b7ddbc1b28)

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

