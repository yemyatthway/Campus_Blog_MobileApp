import 'package:flutter/material.dart';

enum PostSortOption {
  newest('Newest first', 'updatedAt DESC'),
  oldest('Oldest first', 'updatedAt ASC'),
  titleAZ('Title A-Z', 'title COLLATE NOCASE ASC'),
  titleZA('Title Z-A', 'title COLLATE NOCASE DESC');

  const PostSortOption(this.label, this.orderBy);

  final String label;
  final String orderBy;
}

class PostCategory {
  const PostCategory({
    required this.name,
    required this.icon,
    required this.color,
  });

  final String name;
  final IconData icon;
  final Color color;
}

const List<PostCategory> postCategories = [
  PostCategory(name: 'General', icon: Icons.article, color: Color(0xFF4F46E5)),
  PostCategory(name: 'Study', icon: Icons.school, color: Color(0xFF2563EB)),
  PostCategory(name: 'Events', icon: Icons.event, color: Color(0xFF7C3AED)),
  PostCategory(name: 'Food', icon: Icons.restaurant, color: Color(0xFFEA580C)),
  PostCategory(name: 'Travel', icon: Icons.place, color: Color(0xFF059669)),
  PostCategory(name: 'Personal', icon: Icons.person, color: Color(0xFFDB2777)),
];

const String allCategoriesLabel = 'All';

PostCategory categoryForName(String name) {
  return postCategories.firstWhere(
    (category) => category.name == name,
    orElse: () => postCategories.first,
  );
}
