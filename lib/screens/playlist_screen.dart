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

  Widget _playButton(BuildContext context, Playlist playlist) => StartButton(
    label: 'PLAY',
    time: formatDrillClock(playlistSeconds(playlist.entries)),
    onPressed: () => _play(context, playlist, shuffle: false),
  );

  /// [fontSize] defaults to the ADD DRILL and DELETE buttons' size.
  Widget _shuffleButton(
    BuildContext context,
    Playlist playlist, {
    required double height,
    double fontSize = 17,
  }) => CandyButton(
    label: 'SHUFFLE',
    icon: Icons.shuffle_rounded,
    colors: AppColors.candyBlue,
    height: height,
    fontSize: fontSize,
    onPressed: () => _play(context, playlist, shuffle: true),
  );

  Widget _addButton(BuildContext context, Playlist playlist) => CandyButton(
    label: 'ADD DRILL',
    icon: Icons.add_rounded,
    colors: AppColors.candyBlue,
    height: 50,
    fontSize: 17,
    onPressed: () => _push(context, SelectDrillForPlaylistScreen(playlistId: playlist.id)),
  );

  Widget _deleteButton(BuildContext context, Playlist playlist) => CandyButton(
    label: 'DELETE PLAYLIST',
    icon: Icons.delete_rounded,
    colors: AppColors.candyRed,
    height: 50,
    fontSize: 17,
    onPressed: () => _delete(context, playlist),
  );

  static const _emptyMessage = 'No drills in this playlist yet. Add one to get started!';

  /// Everything in one scrolling column: PLAY and SHUFFLE, the drills, then ADD DRILL and DELETE.
  Widget _narrow(BuildContext context, Playlist playlist, EdgeInsets safe) {
    final entries = playlist.entries;
    return SingleChildScrollView(
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
                    Expanded(child: _playButton(context, playlist)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _shuffleButton(
                        context,
                        playlist,
                        height: 76,
                        // Matching PLAY's label beside it (see StartButton).
                        fontSize: 76 * 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
              ],
              const SectionHeading('Drills', AppColors.bannerOrange),
              if (entries.isEmpty)
                const EmptyCard(_emptyMessage)
              else
                _EntryList(playlistId: playlist.id, entries: entries),
              const SizedBox(height: 14),
              _addButton(context, playlist),
              const SizedBox(height: 30),
              _deleteButton(context, playlist),
            ],
          ),
        ),
      ),
    );
  }

  /// The drills scrolling on their own on the left, and the buttons in a column on the right.
  Widget _wide(BuildContext context, Playlist playlist, EdgeInsets safe) {
    final entries = playlist.entries;
    const heading = SectionHeading('Drills', AppColors.bannerOrange);
    return Padding(
      padding: EdgeInsets.only(left: safe.left, right: safe.right),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Two thirds of the width for the drills and one for the buttons, each centered in its
          // share.
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: entries.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [heading, EmptyCard(_emptyMessage)],
                        ),
                      )
                    : _EntryList(
                        playlistId: playlist.id,
                        entries: entries,
                        header: heading,
                        padding: EdgeInsets.fromLTRB(16, 8, 16, safe.bottom + 32),
                      ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, safe.bottom + 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (entries.isNotEmpty) ...[
                        _playButton(context, playlist),
                        const SizedBox(height: 12),
                        _shuffleButton(context, playlist, height: 50),
                        const SizedBox(height: 22),
                      ],
                      _addButton(context, playlist),
                      const SizedBox(height: 30),
                      _deleteButton(context, playlist),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Side by side on a phone held sideways, and on anything wide enough (tablets, desktop).
    final wide = media.size.width > media.size.height || media.size.width >= 700;
    return ListenableBuilder(
      listenable: playlists,
      builder: (context, _) {
        final playlist = playlists.byId(playlistId);
        // (Just deleted, and on its way out.)
        if (playlist == null) return const CreamScreen(title: '', child: SizedBox());
        return CreamScreen(
          title: playlist.name,
          actions: [
            RoundIconButton(
              icon: Icons.edit_rounded,
              tooltip: 'Rename playlist',
              onPressed: () => _rename(context, playlist),
            ),
          ],
          child: wide
              ? _wide(context, playlist, media.padding)
              : _narrow(context, playlist, media.padding),
        );
      },
    );
  }
}

/// The playlist's drills as cards, reorderable by dragging their handles. Laid out in full within
/// an enclosing scroll view, or, given a [padding], scrolling on its own (with [header] at the top).
class _EntryList extends StatelessWidget {
  final String playlistId;
  final List<PlaylistEntry> entries;
  final Widget? header;
  final EdgeInsets? padding;

  const _EntryList({required this.playlistId, required this.entries, this.header, this.padding});

  @override
  Widget build(BuildContext context) {
    final scrolls = padding != null;
    return ReorderableListView.builder(
      shrinkWrap: !scrolls,
      physics: scrolls ? null : const NeverScrollableScrollPhysics(),
      padding: padding,
      header: header,
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
