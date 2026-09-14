import 'package:shared_preferences/shared_preferences.dart';

class PreferredBranchStore {
  static const _storageKey = 'drapemind_selected_branch_id';

  Future<int?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_storageKey);
  }

  Future<void> save(int branchId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_storageKey, branchId);
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }
}
