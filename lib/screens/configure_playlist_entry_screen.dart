import 'package:flutter/material.dart';

import '../data/drills.dart' as data;
import '../model/model.dart';
import '../state/drill_config.dart';
import '../state/playlists.dart';
import '../util/colors.dart';
import '../widgets/arcade.dart';
import '../widgets/drill_config_layout.dart';
import '../widgets/hud_controls.dart';
import '../widgets/hud_layout.dart';

/// The last step of adding a drill to the playlist [playlistId] (reached from
/// [SelectDrillForPlaylistScreen]), or the sole screen for editing an existing entry in place, laid
/// out like the drill overview (see [DrillConfigLayout]): set the starting bpm/bpm-increase/
/// repeat-count/swap-hands, then ADD TO PLAYLIST (or SAVE, when editing). When adding, CANCEL backs
/// out without creating an entry; when editing, that slot is instead a DELETE button (with a
/// confirmation) that removes the entry from the playlist. The drill itself can't be changed here
/// -- editing only ever touches the config. Either way, it returns to the playlist's screen.
///
/// [editIndex]/[initialConfig] being non-null means this is editing an existing entry rather than
/// adding a new one.
class ConfigurePlaylistEntryScreen extends StatefulWidget {
  final String playlistId;
  final String drillId;
  final String drillTitle;
  final DrillConfig? initialConfig;
  final int? editIndex;

  const ConfigurePlaylistEntryScreen({
    super.key,
    required this.playlistId,
    required this.drillId,
    required this.drillTitle,
    this.initialConfig,
    this.editIndex,
  });

  @override
  State<ConfigurePlaylistEntryScreen> createState() => _ConfigurePlaylistEntryScreenState();
}

class _ConfigurePlaylistEntryScreenState extends State<ConfigurePlaylistEntryScreen> {
  late DrillConfig _config;

  bool get _isEditing => widget.editIndex != null;

  Drill? get _drill => data.findDrillById(widget.drillId);

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig ?? const DrillConfig();
  }

  void _returnToPlaylist() {
    final name = '/playlists/${widget.playlistId}';
    Navigator.of(context).popUntil((route) => route.settings.name == name);
  }

  void _save() {
    final entry = PlaylistEntry(drillId: widget.drillId, config: _config);
    if (_isEditing) {
      playlists.updateEntry(widget.playlistId, widget.editIndex!, entry);
    } else {
      playlists.addEntry(widget.playlistId, entry);
    }
    _returnToPlaylist();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete drill?',
      message: 'Remove "${widget.drillTitle}" from this playlist?',
    );
    if (!confirmed || !mounted) return;
    playlists.removeEntry(widget.playlistId, widget.editIndex!);
    _returnToPlaylist();
  }

  // CANCEL (or DELETE), the drill's [time], and ADD TO PLAYLIST (or SAVE): in a row across a portrait
  // HUD, or stacked in a landscape sidebar.
  Widget _actions(Widget time, bool sidebar) {
    final save = StartButton(
      // There isn't room for all of ADD TO PLAYLIST in half a phone's width.
      label: _isEditing ? 'SAVE' : (sidebar ? 'ADD TO PLAYLIST' : 'ADD'),
      icon: _isEditing ? Icons.check_rounded : Icons.add_rounded,
      height: 56,
      onPressed: _save,
    );
    final other = CandyButton(
      label: _isEditing ? 'DELETE' : 'CANCEL',
      icon: _isEditing ? Icons.delete_rounded : Icons.close_rounded,
      colors: _isEditing ? AppColors.candyRed : AppColors.candyGray,
      height: sidebar ? 46 : 56,
      fontSize: sidebar ? 15 : 17,
      onPressed: _isEditing ? _confirmDelete : _returnToPlaylist,
    );
    if (sidebar) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: time),
          const SizedBox(height: 10),
          save,
          const SizedBox(height: 10),
          other,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: other),
        const SizedBox(width: 10),
        time,
        const SizedBox(width: 10),
        Expanded(child: save),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final drill = _drill;
    if (drill == null) {
      // The drill no longer exists (see PlaylistRunScreen._goToIndex); all that's left to do
      // with its entry is remove it.
      return CreamScreen(
        title: widget.drillTitle,
        showSettings: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _isEditing
                ? CandyButton(
                    label: 'DELETE',
                    icon: Icons.delete_rounded,
                    colors: AppColors.candyRed,
                    onPressed: _confirmDelete,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      );
    }
    return DrillConfigLayout(
      drill: drill,
      config: _config,
      onConfigUpdate: (update) => setState(() => _config = update(_config)),
      title: widget.drillTitle,
      buildActions: (context, time, sidebar) => _actions(time, sidebar),
    );
  }
}
