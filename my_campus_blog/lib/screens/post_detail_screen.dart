import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';
import '../models/post.dart';
import 'add_edit_post_screen.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final int postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Post? _post;
  bool _isLoading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  Future<void> _loadPost() async {
    final post = await DatabaseHelper.instance.getPost(widget.postId);

    if (!mounted) {
      return;
    }

    setState(() {
      _post = post;
      _isLoading = false;
    });
  }

  Future<void> _editPost() async {
    final post = _post;
    if (post == null) {
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddEditPostScreen(post: post)),
    );

    if (saved == true) {
      _changed = true;
      await _loadPost();
    }
  }

  Future<void> _deletePost() async {
    final post = _post;
    if (post == null) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: Text('Delete "${post.title}" from SQLite?'),
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

    await DatabaseHelper.instance.deletePost(post.id!);

    if (!mounted) {
      return;
    }

    Navigator.pop(context, true);
  }

  Future<void> _sharePost() async {
    final post = _post;
    if (post == null) {
      return;
    }

    final text = '${post.title}\n\n${post.content}';
    final imagePath = post.imagePath;

    if (imagePath == null) {
      await SharePlus.instance.share(ShareParams(text: text));
    } else {
      await SharePlus.instance.share(
        ShareParams(text: text, files: [XFile(imagePath)]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('View post'),
          actions: [
            IconButton(
              tooltip: 'Share post',
              onPressed: _post == null ? null : _sharePost,
              icon: const Icon(Icons.share),
            ),
            IconButton(
              tooltip: 'Edit post',
              onPressed: _post == null ? null : _editPost,
              icon: const Icon(Icons.edit),
            ),
            IconButton(
              tooltip: 'Delete post',
              onPressed: _post == null ? null : _deletePost,
              icon: const Icon(Icons.delete),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _post == null
            ? const Center(child: Text('Post not found'))
            : _PostDetail(post: _post!),
      ),
    );
  }
}

class _PostDetail extends StatelessWidget {
  const _PostDetail({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final imagePath = post.imagePath;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (imagePath != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(imagePath), height: 260, fit: BoxFit.cover),
          ),
          const SizedBox(height: 18),
        ],
        Text(post.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Updated ${_formatDate(post.updatedAt)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const Divider(height: 28),
        Text(post.content, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.year}-$month-$day $hour:$minute';
  }
}
