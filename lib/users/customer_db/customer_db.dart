import 'package:flutter/material.dart';

class CustomerDb extends StatelessWidget {
  const CustomerDb({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Portal'),
        backgroundColor: const Color(0xFFFFA733),
      ),
      body: const Center(
        child: Text('Welcome, Customer!'),
      ),
    );
  }
}
