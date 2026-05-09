import 'package:flutter/material.dart';

import 'screens/post_list_screen.dart';

void main() {
  runApp(const MyCampusBlogApp());
}

class MyCampusBlogApp extends StatelessWidget {
  const MyCampusBlogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Campus Blog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const PostListScreen(),
    );
  }
}
