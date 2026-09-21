import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';

class BackendDiagnosticPage extends StatefulWidget {
  const BackendDiagnosticPage({super.key});

  @override
  State<BackendDiagnosticPage> createState() => _BackendDiagnosticPageState();
}

class _BackendDiagnosticPageState extends State<BackendDiagnosticPage> {
  Map<String, dynamic>? _results;
  bool _isLoading = false;

  void _runDiagnostic() async {
    setState(() {
      _isLoading = true;
      _results = null;
    });

    try {
      final results = await SupabaseService().testConnection();
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _results = {'status': 'Fatal Error', 'error': e.toString()};
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backend Diagnostic'),
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Diagnostic Tool',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use this to verify if Supabase, Firebase, and the Identity Bridge are working correctly.',
              style: TextStyle(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _runDiagnostic,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run Test'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_results != null)
              Expanded(
                child: ListView(
                  children: _results!.entries.map((e) {
                    final bool isError = e.key == 'error' || e.value == 'Error' || e.value == false;
                    return Card(
                      child: ListTile(
                        title: Text(e.key),
                        subtitle: Text(e.value.toString()),
                        trailing: Icon(
                          isError ? Icons.error_outline : Icons.check_circle_outline,
                          color: isError ? Colors.red : Colors.green,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
