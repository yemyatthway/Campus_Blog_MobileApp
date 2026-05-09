import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../config/post_options.dart';
import '../database/database_helper.dart';
import '../models/post.dart';
import 'add_edit_post_screen.dart';
import 'post_detail_screen.dart';

class PostListScreen extends StatefulWidget {
  const PostListScreen({super.key});

  @override
  State<PostListScreen> createState() => _PostListScreenState();
}

class _PostListScreenState extends State<PostListScreen> {
  static const _searchDelay = Duration(milliseconds: 300);

  final _searchController = TextEditingController();
  final Set<int> _selectedPostIds = {};
  List<Post> _posts = [];
  Timer? _searchDebounce;
  PostSortOption _sortOption = PostSortOption.newest;
  String _selectedCategory = allCategoriesLabel;
  bool _isLoading = true;

  bool get _isSelecting => _selectedPostIds.isNotEmpty;
  String? get _categoryFilter =>
      _selectedCategory == allCategoriesLabel ? null : _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _queueSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDelay, _loadPosts);
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });

    final posts = await DatabaseHelper.instance.getPosts(
      query: _searchController.text,
      category: _categoryFilter,
      sortOption: _sortOption,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _posts = posts;
      _selectedPostIds.removeWhere(
        (id) => !_posts.any((post) => post.id == id),
      );
      _isLoading = false;
    });
  }

  Future<void> _openEditor({Post? post}) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => AddEditPostScreen(post: post)),
    );

    if (result == null) {
      return;
    }

    await _loadPosts();

    if (!mounted) {
      return;
    }

    final message = result == 'updated'
        ? 'Post updated successfully.'
        : 'Post saved to SQLite.';
    _showSnackBar(message);
  }

  Future<void> _openDetails(Post post) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post.id!)),
    );

    if (result == null) {
      return;
    }

    await _loadPosts();

    if (!mounted) {
      return;
    }

    if (result == 'deleted') {
      _showSnackBar('Post deleted.');
    } else if (result == 'updated') {
      _showSnackBar('Post updated successfully.');
    }
  }

  void _toggleSelection(Post post) {
    final id = post.id;
    if (id == null) {
      return;
    }

    setState(() {
      if (_selectedPostIds.contains(id)) {
        _selectedPostIds.remove(id);
      } else {
        _selectedPostIds.add(id);
      }
    });
  }

  Future<void> _deleteSelectedPosts() async {
    final count = _selectedPostIds.length;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count selected post${count == 1 ? '' : 's'}?'),
        content: const Text('This removes the selected posts from SQLite.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    await DatabaseHelper.instance.deletePosts(_selectedPostIds.toList());

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedPostIds.clear();
    });
    await _loadPosts();

    if (!mounted) {
      return;
    }

    _showSnackBar('$count post${count == 1 ? '' : 's'} deleted.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectCategory(String category) {
    if (_selectedCategory == category) {
      return;
    }
    setState(() {
      _selectedCategory = category;
      _selectedPostIds.clear();
    });
    _loadPosts();
  }

  void _selectSort(PostSortOption sortOption) {
    if (_sortOption == sortOption) {
      return;
    }
    setState(() {
      _sortOption = sortOption;
    });
    _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    final hasSearch = _searchController.text.trim().isNotEmpty;
    final hasFilter = _selectedCategory != allCategoriesLabel;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelecting
              ? '${_selectedPostIds.length} selected'
              : 'My Campus Blog',
        ),
        actions: [
          if (_isSelecting)
            IconButton(
              tooltip: 'Cancel selection',
              onPressed: () => setState(_selectedPostIds.clear),
              icon: const Icon(Icons.close),
            ),
          if (_isSelecting)
            IconButton(
              tooltip: 'Delete selected',
              onPressed: _deleteSelectedPosts,
              icon: const Icon(Icons.delete),
            )
          else
            PopupMenuButton<PostSortOption>(
              tooltip: 'Sort posts',
              icon: const Icon(Icons.sort),
              initialValue: _sortOption,
              onSelected: _selectSort,
              itemBuilder: (context) => PostSortOption.values
                  .map(
                    (option) => PopupMenuItem(
                      value: option,
                      child: Row(
                        children: [
                          Icon(
                            option == _sortOption
                                ? Icons.check
                                : Icons.sort_by_alpha,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(option.label),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                totalPosts: _posts.length,
                sortLabel: _sortOption.label,
                selectedCategory: _selectedCategory,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search title or message',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              _loadPosts();
                            },
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _queueSearch();
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _CategoryFilter(
                selectedCategory: _selectedCategory,
                onSelected: _selectCategory,
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_posts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  hasSearch: hasSearch,
                  hasFilter: hasFilter,
                  onCreate: () => _openEditor(),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
                sliver: SliverList.separated(
                  itemCount: _posts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final post = _posts[index];
                    final isSelected = _selectedPostIds.contains(post.id);
                    return _PostListTile(
                      post: post,
                      isSelected: isSelected,
                      onTap: () {
                        if (_isSelecting) {
                          _toggleSelection(post);
                        } else {
                          _openDetails(post);
                        }
                      },
                      onLongPress: () => _toggleSelection(post),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New post'),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.totalPosts,
    required this.sortLabel,
    required this.selectedCategory,
  });

  final int totalPosts;
  final String sortLabel;
  final String selectedCategory;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, const Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Offline blog workspace',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Write, store, search and share campus posts.',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderChip(icon: Icons.storage, label: '$totalPosts saved'),
              _HeaderChip(icon: Icons.sell_outlined, label: selectedCategory),
              _HeaderChip(icon: Icons.sort, label: sortLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.selectedCategory,
    required this.onSelected,
  });

  final String selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final categories = [
      allCategoriesLabel,
      ...postCategories.map((e) => e.name),
    ];

    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final categoryName = categories[index];
          final isAll = categoryName == allCategoriesLabel;
          final icon = isAll ? Icons.apps : categoryForName(categoryName).icon;
          final color = isAll ? null : categoryForName(categoryName).color;

          return ChoiceChip(
            selected: selectedCategory == categoryName,
            avatar: Icon(icon, size: 18, color: color),
            label: Text(categoryName),
            onSelected: (_) => onSelected(categoryName),
          );
        },
      ),
    );
  }
}

class _PostListTile extends StatelessWidget {
  const _PostListTile({
    required this.post,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  final Post post;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final imagePath = post.imagePath;
    final category = categoryForName(post.category);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: isSelected ? colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PostThumbnail(imagePath: imagePath, isSelected: isSelected),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _CategoryPill(category: category),
                        const Spacer(),
                        Text(
                          _formatShortDate(post.updatedAt),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      post.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      post.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                isSelected ? Icons.check_circle : Icons.chevron_right,
                color: isSelected ? colorScheme.primary : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatShortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }
}

class _PostThumbnail extends StatelessWidget {
  const _PostThumbnail({required this.imagePath, required this.isSelected});

  final String? imagePath;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 74,
            height: 74,
            child: imagePath == null
                ? ColoredBox(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Icon(
                      Icons.article,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  )
                : Image.file(File(imagePath!), fit: BoxFit.cover),
          ),
        ),
        if (isSelected)
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check, color: Colors.white),
          ),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category});

  final PostCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 14, color: category.color),
          const SizedBox(width: 4),
          Text(
            category.name,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: category.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasSearch,
    required this.hasFilter,
    required this.onCreate,
  });

  final bool hasSearch;
  final bool hasFilter;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final isFiltered = hasSearch || hasFilter;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFiltered ? Icons.search_off : Icons.note_add,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              isFiltered ? 'No matching posts' : 'No posts yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'Try another search word or category.'
                  : 'Create your first campus blog message.',
              textAlign: TextAlign.center,
            ),
            if (!isFiltered) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Create post'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
