import 'dart:io';

import 'package:flutter/material.dart';

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
  final _searchController = TextEditingController();
  final Set<int> _selectedPostIds = {};
  List<Post> _posts = [];
  bool _isLoading = true;

  bool get _isSelecting => _selectedPostIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });

    final posts = await DatabaseHelper.instance.getPosts(
      query: _searchController.text,
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
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddEditPostScreen(post: post)),
    );

    if (saved == true) {
      await _loadPosts();
    }
  }

  Future<void> _openDetails(Post post) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post.id!)),
    );

    if (changed == true) {
      await _loadPosts();
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
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
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
  }

  @override
  Widget build(BuildContext context) {
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
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search posts',
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
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => _loadPosts(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _posts.isEmpty
                ? _EmptyState(
                    hasSearch: _searchController.text.trim().isNotEmpty,
                    onCreate: () => _openEditor(),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                    itemCount: _posts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New post'),
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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: imagePath == null
            ? CircleAvatar(
                child: Icon(isSelected ? Icons.check : Icons.article),
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(backgroundImage: FileImage(File(imagePath))),
                  if (isSelected)
                    const CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.check, color: Colors.white),
                    ),
                ],
              ),
        title: Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          post.content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle)
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasSearch, required this.onCreate});

  final bool hasSearch;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch ? Icons.search_off : Icons.note_add,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              hasSearch ? 'No matching posts' : 'No posts yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Try a different search word.'
                  : 'Create your first campus blog message.',
              textAlign: TextAlign.center,
            ),
            if (!hasSearch) ...[
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
