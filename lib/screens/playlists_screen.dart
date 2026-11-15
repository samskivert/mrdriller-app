import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../model/model.dart';
import '../state/playlists.dart';
import '../util/colors.dart';
import '../widgets/arcade.dart';
import '../widgets/hud_controls.dart';
import '../widgets/hud_layout.dart';

/// The user's playlists, as cards (tap one to open it -- see [PlaylistScreen]), and buttons to
/// create another, which asks for its name and then opens it, or import one exported from another
/// copy of the app (see [encodePlaylistExport]), which then opens it.
class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  Future<void> _create(BuildContext context) async {
    final name = await promptForName(context, title: 'New playlist', confirmLabel: 'CREATE');
    if (name == null || !context.mounted) return;
    final playlist = playlists.create(name);
    Navigator.of(context).pushNamed('/playlists/${playlist.id}');
  }

  Future<void> _import(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    void say(String message) => messenger.showSnackBar(SnackBar(content: Text(message)));
    final PlaylistImport imported;
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
      if (file == null) return;
      imported = decodePlaylistExport(utf8.decode(await file.readAsBytes()));
    } on FormatException {
      say("That file isn't an exported playlist.");
      return;
    } catch (e) {
      say("Couldn't read that file: $e");
      return;
    }
    final playlist = playlists.create(imported.name, entries: imported.entries);
    final missing = imported.missing;
    if (missing > 0) {
      say(
        missing == 1
            ? "Left out 1 drill that this version of the app doesn't have."
            : "Left out $missing drills that this version of the app doesn't have.",
      );
    }
    if (context.mounted) Navigator.of(context).pushNamed('/playlists/${playlist.id}');
  }

  /// NEW PLAYLIST and IMPORT PLAYLIST side by side, or one above the other where they'd be
  /// squeezed (on a phone held upright).
  Widget _buttons(BuildContext context) {
    final create = CandyButton(
      label: 'NEW PLAYLIST',
      icon: Icons.add_rounded,
      colors: AppColors.candyOrange,
      height: 50,
      fontSize: 17,
      onPressed: () => _create(context),
    );
    final import = CandyButton(
      label: 'IMPORT PLAYLIST',
      icon: Icons.file_open_rounded,
      colors: AppColors.candyGreen,
      height: 50,
      fontSize: 17,
      onPressed: () => _import(context),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 440
          ? Row(
              children: [
                Expanded(child: create),
                const SizedBox(width: 10),
                Expanded(child: import),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [create, const SizedBox(height: 12), import],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return CreamScreen(
      title: 'Playlists',
      child: ListenableBuilder(
        listenable: playlists,
        builder: (context, _) {
          final all = playlists.playlists;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(safe.left + 16, 8, safe.right + 16, safe.bottom + 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (all.isEmpty)
                      const EmptyCard('No playlists. Make one and fill it with drills!')
                    else
                      for (var i = 0; i < all.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        _PlaylistCard(
                          number: i + 1,
                          playlist: all[i],
                          onTap: () => Navigator.of(context).pushNamed('/playlists/${all[i].id}'),
                        ),
                      ],
                    const SizedBox(height: 14),
                    _buttons(context),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A playlist as a card: its [number] on a banner, its name, and how many drills it has and how
/// long they take to play.
class _PlaylistCard extends StatelessWidget {
  final int number;
  final Playlist playlist;
  final VoidCallback onTap;

  const _PlaylistCard({required this.number, required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final count = playlist.entries.length;
    final drills = count == 1 ? '1 drill' : '$count drills';
    final summary = count == 0
        ? 'No drills yet'
        : '$drills · ${formatDrillDuration(playlistSeconds(playlist.entries))}';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.creamShadow, width: 3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HudBanner(
                label: number.toString().padLeft(2, '0'),
                color: AppColors.banner(number - 1),
                fontSize: 14,
                padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 17,
                          height: 1.1,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        summary,
                        style: const TextStyle(
                          fontFamily: AppFonts.body,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 16, 10, 0),
                child: Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
