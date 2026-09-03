import 'dart:convert';

import '../../../core/database/database_helper.dart';
import '../../../shared/constants/app_constants.dart';
import '../models/institute_profile_model.dart';
import '../models/master_data_model.dart';

/// Centralized service for Institute Profile & Master Data management.
/// Reads and writes to SQLite `app_settings` table.
class InstituteConfigService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Key Constants
  static const String keyInstName = 'inst_name';
  static const String keyInstAddress = 'inst_address';
  static const String keyInstPhone = 'inst_phone';
  static const String keyInstEmail = 'inst_email';
  static const String keyPrincipalName = 'principal_name';
  static const String keyAcademicYear = 'academic_year';
  static const String keyInstLogo = 'inst_logo';

  // ── Institute Profile Settings ──────────────────────────────────────────

  /// Fetches current Institute Profile settings with default fallback values.
  Future<InstituteProfileModel> getInstituteProfile() async {
    final Map<String, String?> settingsMap = {
      keyInstName: await _dbHelper.getSetting(keyInstName),
      keyInstAddress: await _dbHelper.getSetting(keyInstAddress),
      keyInstPhone: await _dbHelper.getSetting(keyInstPhone),
      keyInstEmail: await _dbHelper.getSetting(keyInstEmail),
      keyPrincipalName: await _dbHelper.getSetting(keyPrincipalName),
      keyAcademicYear: await _dbHelper.getSetting(keyAcademicYear),
      keyInstLogo: await _dbHelper.getSetting(keyInstLogo),
    };

    return InstituteProfileModel.fromMap(settingsMap);
  }

  /// Saves updated Institute Profile settings.
  Future<void> saveInstituteProfile(InstituteProfileModel profile) async {
    final map = profile.toMap();
    for (final entry in map.entries) {
      await _dbHelper.setSetting(entry.key, entry.value);
    }
  }

  /// Gets current active Academic Year string (e.g. "2026-27").
  Future<String> getAcademicYear() async {
    final profile = await getInstituteProfile();
    return profile.academicYear;
  }

  /// Updates active Academic Year string.
  Future<void> saveAcademicYear(String newAcademicYear) async {
    await _dbHelper.setSetting(keyAcademicYear, newAcademicYear.trim());
  }

  // ── Master Data Management ──────────────────────────────────────────────

  /// Retrieves list of master data items for a category. Seeds defaults if not yet created.
  Future<List<MasterDataItemModel>> getMasterItems(MasterCategory category) async {
    final String? jsonStr = await _dbHelper.getSetting(category.keyName);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      final defaultItems = _getDefaultMasterItems(category);
      await saveMasterItems(category, defaultItems);
      return defaultItems;
    }

    try {
      final List<dynamic> decoded = jsonDecode(jsonStr) as List<dynamic>;
      return decoded
          .map((item) => MasterDataItemModel.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      final defaultItems = _getDefaultMasterItems(category);
      await saveMasterItems(category, defaultItems);
      return defaultItems;
    }
  }

  /// Saves master data items for a category.
  Future<void> saveMasterItems(MasterCategory category, List<MasterDataItemModel> items) async {
    final jsonList = items.map((i) => i.toMap()).toList();
    await _dbHelper.setSetting(category.keyName, jsonEncode(jsonList));
  }

  /// Returns active item names for UI forms (filtering out deactivated items).
  Future<List<String>> getActiveMasterNames(MasterCategory category) async {
    final items = await getMasterItems(category);
    return items.where((i) => i.isActive).map((i) => i.name).toList();
  }

  /// Returns active item names, plus [currentValue] if provided (to preserve historical record displays).
  Future<List<String>> getActiveMasterNamesWithHistorical(MasterCategory category, String? currentValue) async {
    final activeNames = await getActiveMasterNames(category);
    if (currentValue != null && currentValue.isNotEmpty && !activeNames.contains(currentValue)) {
      return [currentValue, ...activeNames];
    }
    return activeNames;
  }

  /// Adds a new master item to a category.
  Future<void> addMasterItem(MasterCategory category, String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    final items = await getMasterItems(category);
    if (items.any((i) => i.name.toLowerCase() == trimmedName.toLowerCase())) {
      // If item already exists but is inactive, reactivate it
      final updated = items.map((i) {
        if (i.name.toLowerCase() == trimmedName.toLowerCase()) {
          return i.copyWith(isActive: true);
        }
        return i;
      }).toList();
      await saveMasterItems(category, updated);
      return;
    }

    final newItem = MasterDataItemModel(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}',
      category: category.name,
      name: trimmedName,
      isActive: true,
      sortOrder: items.length + 1,
    );

    items.add(newItem);
    await saveMasterItems(category, items);
  }

  /// Updates an existing master item's name or active state.
  Future<void> updateMasterItem(MasterCategory category, MasterDataItemModel updatedItem) async {
    final items = await getMasterItems(category);
    final updatedList = items.map((i) => i.id == updatedItem.id ? updatedItem : i).toList();
    await saveMasterItems(category, updatedList);
  }

  /// Toggles active/deactive status for a master item.
  Future<void> toggleMasterItemActive(MasterCategory category, String id, bool isActive) async {
    final items = await getMasterItems(category);
    final updatedList = items.map((i) {
      if (i.id == id) {
        return i.copyWith(isActive: isActive);
      }
      return i;
    }).toList();
    await saveMasterItems(category, updatedList);
  }

  // ── Default Fallback Lists ─────────────────────────────────────────────

  List<MasterDataItemModel> _getDefaultMasterItems(MasterCategory category) {
    List<String> rawDefaults;
    switch (category) {
      case MasterCategory.studentClass:
        rawDefaults = AppConstants.classes;
        break;
      case MasterCategory.board:
        rawDefaults = AppConstants.boards;
        break;
      case MasterCategory.batch:
        rawDefaults = ['Morning Batch A', 'Evening Batch B', 'Target Batch 2026', 'Foundation Batch'];
        break;
      case MasterCategory.subject:
        rawDefaults = AppConstants.subjects;
        break;
      case MasterCategory.examType:
        rawDefaults = ['Monthly Test', 'Unit Test', 'Mid-Term Exam', 'Final Exam', 'Weekly Quiz'];
        break;
    }

    int idx = 0;
    return rawDefaults.map((name) {
      idx++;
      return MasterDataItemModel(
        id: '${category.name}_$idx',
        category: category.name,
        name: name,
        isActive: true,
        sortOrder: idx,
      );
    }).toList();
  }
}
