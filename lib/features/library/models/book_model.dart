/// Book Model
///
/// Represents a book in the library inventory.
class BookModel {
  final int? id;
  final String title;
  final String? author;
  final String? isbn;
  final String? category;
  final int totalCopies;
  final int availableCopies;
  final String? shelfLocation;
  final String? description;
  final bool isActive;
  final String createdAt;
  final String? updatedAt;

  BookModel({
    this.id,
    required this.title,
    this.author,
    this.isbn,
    this.category,
    this.totalCopies = 1,
    this.availableCopies = 1,
    this.shelfLocation,
    this.description,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  /// Number of currently issued copies
  int get issuedCopies => totalCopies - availableCopies;

  /// Whether the book is available for issue
  bool get isAvailable => availableCopies > 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'isbn': isbn,
      'category': category,
      'totalCopies': totalCopies,
      'availableCopies': availableCopies,
      'shelfLocation': shelfLocation,
      'description': description,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory BookModel.fromMap(Map<String, dynamic> map) {
    return BookModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      author: map['author'] as String?,
      isbn: map['isbn'] as String?,
      category: map['category'] as String?,
      totalCopies: map['totalCopies'] as int? ?? 1,
      availableCopies: map['availableCopies'] as int? ?? 1,
      shelfLocation: map['shelfLocation'] as String?,
      description: map['description'] as String?,
      isActive: (map['isActive'] as int?) == 1,
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String?,
    );
  }

  BookModel copyWith({
    int? id,
    String? title,
    String? author,
    String? isbn,
    String? category,
    int? totalCopies,
    int? availableCopies,
    String? shelfLocation,
    String? description,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return BookModel(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      isbn: isbn ?? this.isbn,
      category: category ?? this.category,
      totalCopies: totalCopies ?? this.totalCopies,
      availableCopies: availableCopies ?? this.availableCopies,
      shelfLocation: shelfLocation ?? this.shelfLocation,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'BookModel(id: $id, title: $title, author: $author, available: $availableCopies/$totalCopies)';
}
