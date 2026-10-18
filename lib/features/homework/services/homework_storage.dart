import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/atomic_storage_helper.dart';
import '../../cloudisk/services/cloud_backup_manager.dart';
import '../models/homework_model.dart';

class HomeworkStorage {
  static const String _fileName = 'homework_list.json';

  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<void> saveHomeworkList(List<HomeworkModel> homeworks) async {
    try {
      final file = await _getFile();
      final jsonList = homeworks.map((h) => h.toJson()).toList();
      await AtomicStorageHelper.atomicWriteString(file, jsonEncode(jsonList));
      CloudBackupManager.instance.markDirty();
    } catch (e) {
      // 忽略
    }
  }

  Future<List<HomeworkModel>> readHomeworkList() async {
    try {
      final file = await _getFile();
      final decoded = await AtomicStorageHelper.readJsonWithRecovery(file,
          logTag: 'HomeworkStorage');
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((j) => HomeworkModel.fromJson(Map<String, dynamic>.from(j)))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> deleteHomeworkList() async {
    try {
      final file = await _getFile();
      await AtomicStorageHelper.deleteWithBackups(file);
    } catch (e) {
      // 忽略
    }
  }
}
