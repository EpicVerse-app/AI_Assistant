import 'package:shared_preferences/shared_preferences.dart';

import '../models/folder.dart';

class FolderService {
  FolderService._();
  static final FolderService instance = FolderService._();

  static const _key = 'folders_v1';

  Future<List<Folder>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return Folder.listFromJson(raw);
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveAll(List<Folder> folders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, Folder.listToJson(folders));
  }

  Future<Folder> create(String name) async {
    final folders = await loadAll();
    final folder = Folder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      createdAt: DateTime.now(),
    );
    folders.insert(0, folder);
    await _saveAll(folders);
    return folder;
  }

  Future<void> rename(String folderId, String newName) async {
    final folders = await loadAll();
    final idx = folders.indexWhere((f) => f.id == folderId);
    if (idx == -1) return;
    folders[idx] = folders[idx].copyWith(name: newName.trim());
    await _saveAll(folders);
  }

  Future<void> delete(String folderId) async {
    final folders = await loadAll();
    folders.removeWhere((f) => f.id == folderId);
    await _saveAll(folders);
  }

  Future<void> addMeeting(String folderId, String meetingId) async {
    final folders = await loadAll();
    final idx = folders.indexWhere((f) => f.id == folderId);
    if (idx == -1) return;
    final ids = List<String>.from(folders[idx].meetingIds);
    if (!ids.contains(meetingId)) ids.insert(0, meetingId);
    folders[idx] = folders[idx].copyWith(meetingIds: ids);
    await _saveAll(folders);
  }

  Future<void> removeMeeting(String folderId, String meetingId) async {
    final folders = await loadAll();
    final idx = folders.indexWhere((f) => f.id == folderId);
    if (idx == -1) return;
    final ids = List<String>.from(folders[idx].meetingIds)
      ..remove(meetingId);
    folders[idx] = folders[idx].copyWith(meetingIds: ids);
    await _saveAll(folders);
  }
}
