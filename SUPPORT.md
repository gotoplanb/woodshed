# Support — Hermit Jam

## Get Help

If you have questions, run into a bug, or need help with the app, here's how to reach us:

### Report a Bug or Request a Feature

Open an issue on GitHub:
[github.com/gotoplanb/woodshed/issues](https://github.com/gotoplanb/woodshed/issues)

### Contact the Developer

Email: **davestanton.us@gmail.com**

We typically respond within 48 hours.

## Common Questions

**How do I create a setlist?**
Create a playlist in your music app, then open Hermit Jam and tap the Import button to bring it in.

**How do I edit section timestamps?**
Setlist data is stored as JSON files in iCloud Drive (look for the "Hermit Jam" folder). Open any setlist file in a text editor, adjust the `startTime` and `endTime` values, and save. The app picks up changes automatically.

**Why can't I change the playback speed?**
Speed control requires locally downloaded tracks. Purchase and download the song to your device, and the speed picker will activate.

**The wrong version of a song is playing.**
The app searches by song title and artist. You can pin a specific version by replacing the `appleMusicID` in the JSON file with an exact catalog ID. See the [README](https://github.com/gotoplanb/woodshed#editing-sections) for details.

## More Information

- [README & How-To Guide](https://github.com/gotoplanb/woodshed)
- [Privacy Policy](https://github.com/gotoplanb/woodshed/blob/main/PRIVACY.md)
- [Source Code](https://github.com/gotoplanb/woodshed)
