import 'package:flutter/material.dart';

class EmployeeDb extends StatelessWidget {
  const EmployeeDb({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Dashboard'),
        backgroundColor: const Color(0xFFFFA733),
      ),
      body: const Center(
        child: Text('Welcome, Employee!'),
      ),
    );
  }
}
