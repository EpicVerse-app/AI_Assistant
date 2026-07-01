import 'package:flutter/material.dart';

import '../models/folder.dart';
import '../services/api_service.dart';
import '../services/folder_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_time_utils.dart';
import 'mom_result_screen.dart';
import 'processing_screen.dart';
import 'recording_screen.dart';

class FolderScreen extends StatefulWidget {
  const FolderScreen({super.key, required this.folder});

  final Folder folder;

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  late Folder _folder;
  List<Map<String, dynamic>> _allMeetings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _folder = widget.folder;
    _loadMeetings();
  }

  Future<void> _loadMeetings() async {
    setState(() => _loading = true);
    try {
      final meetings = await ApiService.getMeetings();
      if (mounted) setState(() => _allMeetings = meetings);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _folderMeetings => _allMeetings
      .where((m) => _folder.meetingIds.contains(m['meeting_id'] as String))
      .toList()
    ..sort((a, b) {
      final ai = _folder.meetingIds.indexOf(a['meeting_id'] as String);
      final bi = _folder.meetingIds.indexOf(b['meeting_id'] as String);
      return ai.compareTo(bi);
    });

  List<Map<String, dynamic>> get _availableMeetings => _allMeetings
      .where((m) => !_folder.meetingIds.contains(m['meeting_id'] as String))
      .toList();

  Future<void> _showAddRecordingDialog() async {
    final available = _availableMeetings;
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recordings available to add.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddRecordingSheet(
        meetings: available,
        onAdd: (meetingId) async {
          await FolderService.instance.addMeeting(_folder.id, meetingId);
          final updated = await FolderService.instance.loadAll();
          final refreshed = updated.firstWhere(
            (f) => f.id == _folder.id,
            orElse: () => _folder,
          );
          if (mounted) setState(() => _folder = refreshed);
        },
      ),
    );
  }

  Future<void> _removeFromFolder(String meetingId) async {
    await FolderService.instance.removeMeeting(_folder.id, meetingId);
    final updated = await FolderService.instance.loadAll();
    final refreshed = updated.firstWhere(
      (f) => f.id == _folder.id,
      orElse: () => _folder,
    );
    if (mounted) setState(() => _folder = refreshed);
  }

  Future<void> _openMeeting(Map<String, dynamic> m) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final meeting =
          await ApiService.getMeetingDetail(m['meeting_id'] as String);
      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MomResultScreen(meeting: meeting),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load meeting: $e')),
        );
      }
    }
  }

  void _openProcessing(Map<String, dynamic> m) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ProcessingScreen(meetingId: m['meeting_id'] as String),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meetings = _folderMeetings;

    return Scaffold(
      appBar: AppBar(
        title: Text(_folder.name),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add meeting',
            onPressed: _showAddRecordingDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : meetings.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open_outlined,
                          size: 56, color: AppTheme.secondaryGray),
                      SizedBox(height: 16),
                      Text(
                        'Tap + to add a meeting.',
                        style: TextStyle(
                            color: AppTheme.secondaryGray, fontSize: 15),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: meetings.length,
                  itemBuilder: (_, i) {
                    final m = meetings[i];
                    final status = m['status'] as String? ?? '';
                    final isDone = status == 'done';
                    final topic = m['meeting_topic'] as String?;
                    final preview = m['summary_preview'] as String? ??
                        m['transcript_preview'] as String?;
                    final dateStr = DateTimeUtils.formatCardDateTime(
                      m['created_at'] as String?,
                      epochMs: DateTimeUtils.epochMsFromJson(m),
                    );

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.fillGray,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderGray),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        onTap: isDone
                            ? () => _openMeeting(m)
                            : status == 'processing' || status == 'uploaded'
                                ? () => _openProcessing(m)
                                : null,
                        title: Text(
                          topic != null && topic != 'Not mentioned'
                              ? topic
                              : dateStr,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: preview != null && preview.isNotEmpty
                            ? Text(
                                preview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.secondaryGray),
                              )
                            : Text(
                                dateStr,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.secondaryGray),
                              ),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: AppTheme.secondaryGray),
                          tooltip: 'Remove from folder',
                          onPressed: () =>
                              _removeFromFolder(m['meeting_id'] as String),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: GestureDetector(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RecordingScreen(folderId: _folder.id),
            ),
          );
          _loadMeetings();
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF8D6736), Color(0xFFB18850)],
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
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              label: 'Home',
              onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
            _NavItem(
              icon: Icons.groups_outlined,
              label: 'Meetings',
              onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
            const SizedBox(width: 48),
            _NavItem(
              icon: Icons.task_alt_outlined,
              label: 'Actions',
              onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
            _NavItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

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
            Icon(icon, color: AppTheme.secondaryGray, size: 24),
            const SizedBox(height: 2),
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

// ── Bottom sheet for picking recordings to add ────────────────────────────────

class _AddRecordingSheet extends StatefulWidget {
  const _AddRecordingSheet({
    required this.meetings,
    required this.onAdd,
  });

  final List<Map<String, dynamic>> meetings;
  final Future<void> Function(String meetingId) onAdd;

  @override
  State<_AddRecordingSheet> createState() => _AddRecordingSheetState();
}

class _AddRecordingSheetState extends State<_AddRecordingSheet> {
  final Set<String> _adding = {};

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, controller) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderGray,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add Recording',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: widget.meetings.length,
              itemBuilder: (_, i) {
                final m = widget.meetings[i];
                final meetingId = m['meeting_id'] as String;
                final topic = m['meeting_topic'] as String?;
                final dateStr = DateTimeUtils.formatCardDateTime(
                  m['created_at'] as String?,
                  epochMs: DateTimeUtils.epochMsFromJson(m),
                );
                final isAdding = _adding.contains(meetingId);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.fillGray,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderGray),
                  ),
                  child: ListTile(
                    title: Text(
                      topic != null && topic != 'Not mentioned'
                          ? topic
                          : dateStr,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      dateStr,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.secondaryGray),
                    ),
                    trailing: isAdding
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : GestureDetector(
                            onTap: () async {
                              setState(() => _adding.add(meetingId));
                              await widget.onAdd(meetingId);
                              if (mounted) {
                                setState(() => _adding.remove(meetingId));
                                Navigator.of(context).pop();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF8D6736),
                                    Color(0xFFB18850),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: const Text(
                                'Add',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
