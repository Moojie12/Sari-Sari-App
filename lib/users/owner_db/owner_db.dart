import 'package:flutter/material.dart';

class OwnerDb extends StatelessWidget {
  const OwnerDb({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard'),
        backgroundColor: const Color(0xFFFFA733),
      ),
      body: const Center(
        child: Text('Welcome, Owner!'),
      ),
    );
  }
}
