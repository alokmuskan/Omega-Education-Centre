import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/library/models/book_model.dart';
import '../../features/library/models/book_issue_model.dart';
import '../../features/library/repository/library_repository.dart';
import '../../features/transport/models/vehicle_model.dart';
import '../../features/transport/models/route_model.dart';
import '../../features/transport/repository/transport_repository.dart';

// ══════════════════════════════════════════════════════════════════════════
// REPOSITORY PROVIDERS
// ══════════════════════════════════════════════════════════════════════════

/// Library Repository Provider
///
/// Provides a singleton instance of LibraryRepository.
final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository();
});

/// Transport Repository Provider
///
/// Provides a singleton instance of TransportRepository.
final transportRepositoryProvider = Provider<TransportRepository>((ref) {
  return TransportRepository();
});

// ══════════════════════════════════════════════════════════════════════════
// LIBRARY BOOKS PROVIDERS
// ══════════════════════════════════════════════════════════════════════════

/// Books State Notifier
///
/// Manages the state of books list with loading, error, and data.
class BooksNotifier extends StateNotifier<AsyncValue<List<BookModel>>> {
  final LibraryRepository _repository;

  BooksNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadBooks();
  }

  /// Load all books from database
  Future<void> loadBooks({String? category, String? search}) async {
    state = const AsyncValue.loading();
    try {
      final books = await _repository.getBooks(category: category, search: search);
      state = AsyncValue.data(books);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Add a new book
  Future<void> addBook(BookModel book) async {
    try {
      await _repository.insertBook(book);
      await loadBooks();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Update an existing book
  Future<void> updateBook(BookModel book) async {
    try {
      await _repository.updateBook(book);
      await loadBooks();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Delete a book (soft delete)
  Future<void> deleteBook(int id) async {
    try {
      await _repository.deleteBook(id);
      await loadBooks();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Books Provider
///
/// Provides the BooksNotifier state.
final booksProvider = StateNotifierProvider<BooksNotifier, AsyncValue<List<BookModel>>>((ref) {
  final repository = ref.watch(libraryRepositoryProvider);
  return BooksNotifier(repository);
});

/// Books Search Provider
///
/// Manages search query for books.
final booksSearchProvider = StateProvider<String>((ref) => '');

/// Filtered Books Provider
///
/// Provides books filtered by search query.
final filteredBooksProvider = Provider<AsyncValue<List<BookModel>>>((ref) {
  final booksAsync = ref.watch(booksProvider);
  final searchQuery = ref.watch(booksSearchProvider);

  return booksAsync.whenData((books) {
    if (searchQuery.isEmpty) return books;
    return books.where((book) =>
        book.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
        (book.author?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
        (book.isbn?.contains(searchQuery) ?? false)
    ).toList();
  });
});

// ══════════════════════════════════════════════════════════════════════════
// LIBRARY ISSUES PROVIDERS
// ══════════════════════════════════════════════════════════════════════════

/// Book Issues State Notifier
class BookIssuesNotifier extends StateNotifier<AsyncValue<List<BookIssueModel>>> {
  final LibraryRepository _repository;

  BookIssuesNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadIssues();
  }

  /// Load all issues from database
  Future<void> loadIssues({String? status}) async {
    state = const AsyncValue.loading();
    try {
      final issues = await _repository.getIssues(status: status);
      state = AsyncValue.data(issues);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Issue a book to a student
  Future<void> issueBook(BookIssueModel issue) async {
    try {
      await _repository.issueBook(issue);
      await loadIssues();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Return a book
  Future<void> returnBook(int issueId, {double fine = 0}) async {
    try {
      await _repository.returnBook(issueId, fine: fine);
      await loadIssues();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Book Issues Provider
final bookIssuesProvider = StateNotifierProvider<BookIssuesNotifier, AsyncValue<List<BookIssueModel>>>((ref) {
  final repository = ref.watch(libraryRepositoryProvider);
  return BookIssuesNotifier(repository);
});

/// Overdue Issues Provider
final overdueIssuesProvider = FutureProvider<List<BookIssueModel>>((ref) async {
  final repository = ref.watch(libraryRepositoryProvider);
  return repository.getOverdueIssues();
});

// ══════════════════════════════════════════════════════════════════════════
// TRANSPORT VEHICLES PROVIDERS
// ══════════════════════════════════════════════════════════════════════════

/// Vehicles State Notifier
class VehiclesNotifier extends StateNotifier<AsyncValue<List<VehicleModel>>> {
  final TransportRepository _repository;

  VehiclesNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadVehicles();
  }

  /// Load all vehicles from database
  Future<void> loadVehicles() async {
    state = const AsyncValue.loading();
    try {
      final vehicles = await _repository.getVehicles();
      state = AsyncValue.data(vehicles);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Add a new vehicle
  Future<void> addVehicle(VehicleModel vehicle) async {
    try {
      await _repository.insertVehicle(vehicle);
      await loadVehicles();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Update a vehicle
  Future<void> updateVehicle(VehicleModel vehicle) async {
    try {
      await _repository.updateVehicle(vehicle);
      await loadVehicles();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Delete a vehicle (soft delete)
  Future<void> deleteVehicle(int id) async {
    try {
      await _repository.deleteVehicle(id);
      await loadVehicles();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Vehicles Provider
final vehiclesProvider = StateNotifierProvider<VehiclesNotifier, AsyncValue<List<VehicleModel>>>((ref) {
  final repository = ref.watch(transportRepositoryProvider);
  return VehiclesNotifier(repository);
});

// ══════════════════════════════════════════════════════════════════════════
// TRANSPORT ROUTES PROVIDERS
// ══════════════════════════════════════════════════════════════════════════

/// Routes State Notifier
class RoutesNotifier extends StateNotifier<AsyncValue<List<RouteModel>>> {
  final TransportRepository _repository;

  RoutesNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadRoutes();
  }

  /// Load all routes from database
  Future<void> loadRoutes() async {
    state = const AsyncValue.loading();
    try {
      final routes = await _repository.getRoutes();
      state = AsyncValue.data(routes);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Add a new route
  Future<void> addRoute(RouteModel route) async {
    try {
      await _repository.insertRoute(route);
      await loadRoutes();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Update a route
  Future<void> updateRoute(RouteModel route) async {
    try {
      await _repository.updateRoute(route);
      await loadRoutes();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Delete a route (soft delete)
  Future<void> deleteRoute(int id) async {
    try {
      await _repository.deleteRoute(id);
      await loadRoutes();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Routes Provider
final routesProvider = StateNotifierProvider<RoutesNotifier, AsyncValue<List<RouteModel>>>((ref) {
  final repository = ref.watch(transportRepositoryProvider);
  return RoutesNotifier(repository);
});

// ══════════════════════════════════════════════════════════════════════════
// STATS PROVIDERS
// ══════════════════════════════════════════════════════════════════════════

/// Library Stats Provider
final libraryStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(libraryRepositoryProvider);
  final bookCount = await repository.getBookCount();
  final copiesStats = await repository.getCopiesStats();
  final issueStats = await repository.getIssueStats();
  
  return {
    'totalBooks': bookCount,
    'totalCopies': copiesStats['total'] ?? 0,
    'availableCopies': copiesStats['available'] ?? 0,
    'issuedCopies': issueStats['Issued'] ?? 0,
    'returnedCopies': issueStats['Returned'] ?? 0,
  };
});

/// Transport Stats Provider
final transportStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(transportRepositoryProvider);
  final vehicleCount = await repository.getVehicleCount();
  final routeCount = await repository.getRouteCount();
  final studentCount = await repository.getTotalTransportStudents();
  
  return {
    'totalVehicles': vehicleCount,
    'totalRoutes': routeCount,
    'totalStudents': studentCount,
  };
});
