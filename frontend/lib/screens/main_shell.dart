import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/folder.dart';
import '../services/auth_service.dart';
import '../services/folder_service.dart';
import '../theme/app_theme.dart';
import 'folder_screen.dart';
import 'home_screen.dart';
import 'recording_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  void _openRecording() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const RecordingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _HomeTab(onViewMeetings: () => setState(() => _currentIndex = 1)),
      HomeScreen(
        onSearchTap: () => setState(() => _currentIndex = 2),
        onNewMeetingTap: _openRecording,
      ),
      const SearchScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: screens[_currentIndex],
      floatingActionButton: GestureDetector(
        onTap: _openRecording,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                Color(0xFF8D6736),
                Color(0xFFB18850),
              ],
              stops: [0.0, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8D6736).withOpacity(0.5),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.add, size: 28, color: Color(0xFF121215)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF121215),
        elevation: 8,
        shadowColor: AppTheme.cardShadow,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'Home',
              selected: _currentIndex == 0,
              onTap: () => setState(() => _currentIndex = 0),
            ),
            _NavItem(
              icon: Icons.groups_outlined,
              selectedIcon: Icons.groups,
              label: 'Meetings',
              selected: _currentIndex == 1,
              onTap: () => setState(() => _currentIndex = 1),
            ),
            const SizedBox(width: 48),
            _NavItem(
              icon: Icons.task_alt_outlined,
              selectedIcon: Icons.task_alt,
              label: 'Actions',
              selected: _currentIndex == 2,
              onTap: () => setState(() => _currentIndex = 2),
            ),
            _NavItem(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings,
              label: 'Settings',
              selected: _currentIndex == 3,
              onTap: () => setState(() => _currentIndex = 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab({required this.onViewMeetings});

  final VoidCallback onViewMeetings;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  List<Folder> _folders = [];

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final folders = await FolderService.instance.loadAll();
    if (mounted) setState(() => _folders = folders);
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Folder'),
        content: SizedBox(
          width: 240,
          child: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (v) => Navigator.pop(ctx, v),
            decoration: const InputDecoration(
              hintText: 'Folder name',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD4B276),
            ),
            child: const Text('Cancel'),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, controller.text),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8D6736), Color(0xFFB18850)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Create',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await FolderService.instance.create(name);
    _loadFolders();
  }

  Future<void> _deleteFolder(Folder folder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete folder?'),
        content: const Text(
            'This removes the folder. Recordings inside will not be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.priorityHigh)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await FolderService.instance.delete(folder.id);
    _loadFolders();
  }

  @override
  Widget build(BuildContext context) {
    final username =
        AuthService.instance.user?.displayName ?? 'User';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        children: [
          // ── Greeting header ──────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // '>' navigation arrow
              GestureDetector(
                onTap: widget.onViewMeetings,
                child: Container(
                  margin: const EdgeInsets.only(top: 2, right: 10),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    username,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlack,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── AI Assistant card ────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Assistant',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Record meetings, get transcripts, and generate structured minutes automatically.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppTheme.secondaryGray,
                  ),
                ),
                const SizedBox(height: 16),
                // Gradient metallic golden yellow button
                GestureDetector(
                  onTap: widget.onViewMeetings,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF8D6736),
                          Color(0xFFB18850),
                        ],
                        stops: [0.0, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8D6736).withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      'View Meetings',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Folders section ──────────────────────────────────────────
          const Text(
            'FOLDERS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.secondaryGray,
            ),
          ),
          const SizedBox(height: 12),

          // Folder list — one per row
          ..._folders.map(
            (folder) => _FolderCard(
              folder: folder,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FolderScreen(folder: folder),
                  ),
                );
                _loadFolders();
              },
              onDelete: () => _deleteFolder(folder),
            ),
          ),

          // Add Folder button — always visible below the list
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _showCreateFolderDialog,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.fillGray,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderGray),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.create_new_folder_outlined,
                      size: 20, color: AppTheme.accentBlue),
                  SizedBox(width: 8),
                  Text(
                    'Add Folder',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.accentBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Folder card ───────────────────────────────────────────────────────────────

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.folder,
    required this.onTap,
    required this.onDelete,
  });

  final Folder folder;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final count = folder.meetingIds.length;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Container(
        width: double.infinity,
        height: 96,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.fillGray,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderGray),
        ),
        child: Row(
          children: [
            const Icon(Icons.folder_rounded,
                size: 26, color: AppTheme.accentBlue),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$count item${count == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.secondaryGray,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                size: 18, color: AppTheme.secondaryGray),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _goldGradient = LinearGradient(
    colors: [
      Color(0xFF8D6736),
      Color(0xFFB18850),
    ],
    stops: [0.0, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              ShaderMask(
                shaderCallback: (bounds) =>
                    _goldGradient.createShader(bounds),
                child: Icon(selectedIcon, color: Colors.white, size: 24),
              )
            else
              Icon(icon, color: AppTheme.secondaryGray, size: 24),
            const SizedBox(height: 2),
            if (selected)
              ShaderMask(
                shaderCallback: (bounds) =>
                    _goldGradient.createShader(bounds),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              )
            else
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.secondaryGray,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
