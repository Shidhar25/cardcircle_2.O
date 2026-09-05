import 'package:flutter/foundation.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/logger_service.dart';
import '../../../shared/models/spend_category.dart';

/// The spend categories, loaded once and shared.
///
/// Three screens need this list — Select Tags (pick them), Benefits (filter
/// by them) and Profile (show the ones you picked). Each used to own its
/// own copy, and only Select Tags actually asked the backend; the other two
/// were hardcoded strings that did not match the server's categories. This
/// holds the single fetched copy.
class CategoryState extends ChangeNotifier {
  List<SpendCategory> _all = const [];
  List<SpendCategory> get all => _all;

  /// The categories this user tagged, from `GET /category/user`.
  List<SpendCategory> _mine = const [];
  List<SpendCategory> get mine => _mine;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// True once a fetch has completed, successfully or not. Screens use it to
  /// tell "still loading" from "genuinely empty".
  bool _hasLoaded = false;
  bool get hasLoaded => _hasLoaded;

  /// Loads the full catalogue.
  ///
  /// [force] re-fetches even when the list is already populated; without it
  /// repeated visits to a tab reuse what is in memory.
  Future<void> loadAll({bool force = false}) async {
    if (_isLoading) return;
    if (_all.isNotEmpty && !force) return;

    _isLoading = true;
    notifyListeners();

    final rows = await ApiService.getCategories();
    if (rows != null) {
      _all = rows.map(SpendCategory.tryParse).nonNulls.toList();
      LoggerService.info('Loaded ${_all.length} spend categories.');
    }

    _isLoading = false;
    _hasLoaded = true;
    notifyListeners();
  }

  /// Loads the categories this user has tagged. Requires auth.
  Future<void> loadMine() async {
    final rows = await ApiService.getUserCategories();
    if (rows == null) return;
    _mine = rows.map(SpendCategory.tryParse).nonNulls.toList();
    notifyListeners();
  }

  /// Replaces the tagged set locally, so Profile reflects a change made in
  /// Select Tags without waiting for a round trip.
  void setMine(Iterable<SpendCategory> categories) {
    _mine = List.unmodifiable(categories);
    notifyListeners();
  }

  /// The category [text] refers to, by machine name, display name or id.
  SpendCategory? resolve(String? text) {
    for (final c in _all) {
      if (c.matches(text)) return c;
    }
    return null;
  }

  void clear() {
    _all = const [];
    _mine = const [];
    _hasLoaded = false;
    notifyListeners();
  }
}
