import 'package:flutter/material.dart';

import 'configure_playlist_entry_screen.dart';
import 'drill_picker_screen.dart';

/// First step of adding a drill to the playlist [playlistId]: pick which drill, then move on to
/// [ConfigurePlaylistEntryScreen] to set its bpm/increase/repeat before it's actually added.
class SelectDrillForPlaylistScreen extends StatelessWidget {
  final String playlistId;

  const SelectDrillForPlaylistScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    return DrillPickerScreen(
      title: 'Add a Drill',
      showSettings: false,
      onDrillTap: (context, drill) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConfigurePlaylistEntryScreen(
            playlistId: playlistId,
            drillId: drill.id,
            drillTitle: drill.title,
          ),
        ),
      ),
    );
  }
}
