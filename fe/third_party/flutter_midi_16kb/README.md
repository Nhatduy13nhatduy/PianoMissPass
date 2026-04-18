# FlutterMidi16kb

A lightweight Flutter plugin that provides MIDI playback using the TinySoundFont synthesizer. Ideal for piano apps, educational apps, and other music-related projects where you need custom SF2 soundfonts.

## Features

* Load and play custom SF2 soundfonts
* Play MIDI notes with velocity
* Stop notes programmatically
* Works entirely offline
* Small and efficient

## Getting Started

### Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_midi_16kb: ^0.0.3
```

### Usage

```dart
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_midi_16kb/flutter_midi_16kb.dart';

Future<void> loadSf2() async {
  // Load SF2 asset and copy to temp file
  final data = await rootBundle.load("assets/soundfonts/Piano.sf2");
  final dir = await getTemporaryDirectory();
  final file = File("${dir.path}/Piano.sf2");
  await file.writeAsBytes(data.buffer.asUint8List());

  // Load soundfont into the plugin
  await FlutterMidi16kb.loadSoundfont(file.path);
}

// Play a note
FlutterMidi16kb.playNote(60); // Middle C

// Stop a note
FlutterMidi16kb.stopNote(60);

```

### Asset Setup

Place your `.sf2` files in `assets/sf2/` and declare them in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/sf2/Piano.sf2
```

## Example

Check the `example` directory for a working demo app.

## Roadmap

* [ ] iOS implementation
* [ ] Advanced MIDI file playback
* [ ] Load soundfont from App Storage

## Contributing

Pull requests are welcome! Please open an issue first to discuss what you’d like to change.

## License

MIT License. See [LICENSE](LICENSE) for details.
