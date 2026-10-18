import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/drills.dart' as data;
import '../model/model.dart';
import '../services/reminder_scheduler.dart';
import '../state/playlists.dart';
import '../state/reminders.dart';
import '../util/colors.dart';
import '../widgets/arcade.dart';
import '../widgets/drill_card.dart';
import '../widgets/hud_controls.dart';
import '../widgets/hud_layout.dart';
import 'configure_playlist_entry_screen.dart';
import 'playlist_run_screen.dart';
import 'select_drill_for_playlist_screen.dart';

/// One playlist (reached at `/playlists/<id>`, including from a reminder's notification): PLAY and
/// SHUFFLE buttons to run through its drills in order or in a random one (see
/// [PlaylistRunScreen]), the drills as cards (drag the handle to reorder, tap to edit -- deleting
/// a drill happens from the edit screen, not here), a button to add another drill, and buttons to
/// rename or delete the playlist.
class PlaylistScreen extends StatelessWidget {
  final String playlistId;

  const PlaylistScreen({super.key, required this.playlistId});

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  void _play(BuildContext context, Playlist playlist, {required bool shuffle}) {
    final entries = [...playlist.entries];
    if (shuffle) entries.shuffle(math.Random());
    _push(context, PlaylistRunScreen(title: playlist.name, entries: entries));
  }

  Future<void> _rename(BuildContext context, Playlist playlist) async {
    final name = await promptForName(
      context,
      title: 'Rename playlist',
      initial: playlist.name,
      confirmLabel: 'SAVE',
    );
    if (name != null) playlists.rename(playlist.id, name);
  }

  Future<void> _delete(BuildContext context, Playlist playlist) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete playlist?',
      message: 'Delete "${playlist.name}" and the drills in it?',
    );
    if (!confirmed || !context.mounted) return;
    Navigator.of(context).pop();
    playlists.delete(playlist.id);
    // Reminders that opened it go back to just opening the app.
    if (reminders.entries.any((r) => r.playlistId == playlist.id)) {
      reminders.unlinkPlaylist(playlist.id);
      unawaited(refreshScheduledReminders());
    }
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return ListenableBuilder(
      listenable: playlists,
      builder: (context, _) {
        final playlist = playlists.byId(playlistId);
        // (Just deleted, and on its way out.)
        if (playlist == null) return const CreamScreen(title: '', child: SizedBox());
        final entries = playlist.entries;
        return CreamScreen(
          title: playlist.name,
          actions: [
            RoundIconButton(
              icon: Icons.edit_rounded,
              tooltip: 'Rename playlist',
              onPressed: () => _rename(context, playlist),
            ),
          ],
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(safe.left + 16, 8, safe.right + 16, safe.bottom + 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (entries.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: StartButton(
                              label: 'PLAY',
                              time: formatDrillClock(playlistSeconds(entries)),
                              onPressed: () => _play(context, playlist, shuffle: false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: CandyButton(
                              label: 'SHUFFLE',
                              icon: Icons.shuffle_rounded,
                              colors: AppColors.candyBlue,
                              height: 76,
                              fontSize: 17,
                              onPressed: () => _play(context, playlist, shuffle: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                    ],
                    const SectionHeading('Drills', AppColors.bannerOrange),
                    if (entries.isEmpty)
                      const EmptyCard('No drills in this playlist yet. Add one to get started!')
                    else
                      _EntryList(playlistId: playlist.id, entries: entries),
                    const SizedBox(height: 14),
                    CandyButton(
                      label: 'ADD DRILL',
                      icon: Icons.add_rounded,
                      colors: AppColors.candyBlue,
                      height: 50,
                      fontSize: 17,
                      onPressed: () =>
                          _push(context, SelectDrillForPlaylistScreen(playlistId: playlist.id)),
                    ),
                    const SizedBox(height: 30),
                    CandyButton(
                      label: 'DELETE PLAYLIST',
                      icon: Icons.delete_rounded,
                      colors: AppColors.candyRed,
                      height: 50,
                      fontSize: 17,
                      onPressed: () => _delete(context, playlist),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The playlist's drills as cards, reorderable by dragging their handles.
class _EntryList extends StatelessWidget {
  final String playlistId;
  final List<PlaylistEntry> entries;

  const _EntryList({required this.playlistId, required this.entries});

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // The default drag handle only shows up on desktop platforms -- on iOS/Android there'd be no
      // visible affordance at all (just an undiscoverable long-press-anywhere gesture). An explicit
      // handle works the same, visibly, everywhere.
      buildDefaultDragHandles: false,
      // Keep the card looking like itself (rather than gaining a Material elevation shadow) while
      // it's being dragged.
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        child: ScaleTransition(
          scale: Tween(begin: 1.0, end: 1.03).animate(animation),
          child: child,
        ),
      ),
      itemCount: entries.length,
      onReorderItem: (oldIndex, newIndex) =>
          playlists.reorderEntries(playlistId, oldIndex, newIndex),
      itemBuilder: (context, i) {
        final entry = entries[i];
        final drill = data.findDrillById(entry.drillId);
        final title = drill?.title ?? entry.drillId;
        void edit() => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ConfigurePlaylistEntryScreen(
              playlistId: playlistId,
              drillId: entry.drillId,
              drillTitle: title,
              initialConfig: entry.config,
              editIndex: i,
            ),
          ),
        );
        return Padding(
          key: ObjectKey(entry),
          padding: EdgeInsets.only(bottom: i == entries.length - 1 ? 0 : 12),
          child: drill == null
              ? GestureDetector(onTap: edit, child: EmptyCard('"$title" is no longer available.'))
              : SizedBox(
                  height: 146,
                  child: DrillCard(
                    number: i + 1,
                    drill: drill,
                    config: entry.config,
                    trailing: ReorderableDragStartListener(
                      index: i,
                      child: const Tooltip(
                        message: 'Drag to reorder',
                        child: Icon(Icons.drag_indicator_rounded, color: AppColors.inkMuted),
                      ),
                    ),
                    onTap: edit,
                  ),
                ),
        );
      },
    );
  }
}
