import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_models.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../users/employee_db/profile/employee_profile_controller.dart';

/// Service for handling audit log operations using Supabase as the data source
class AdminAuditService extends ChangeNotifier {
  AdminAuditService._internal({
    SupabaseService? supabaseService,
  }) : _supabaseService = supabaseService ?? SupabaseService() {
    initialize();
  }

  static final AdminAuditService _instance = AdminAuditService._internal();

  factory AdminAuditService({SupabaseService? supabaseService}) {
    if (supabaseService != null) {
      _instance._supabaseService = supabaseService;
    }
    return _instance;
  }

  SupabaseService _supabaseService;
  RealtimeChannel? _realtimeChannel;
  Timer? _pollingTimer;

  // Cached data
  List<AdminAuditLog> _auditLogs = [];

  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  // ==================== GETTERS ====================

  List<AdminAuditLog> get allAuditLogs => List.unmodifiable(_auditLogs);

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ==================== INITIALIZATION ====================

  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _loadAuditLogs();
      _subscribeToRealtime();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  void _subscribeToRealtime() {
    if (_realtimeChannel != null) return;
    try {
      _realtimeChannel = _supabaseService.client
          .channel('public:audit_logs')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'audit_logs',
            callback: (payload) {
              _loadAuditLogsSilently();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Failed to subscribe to realtime audit logs: $e');
    }

    _pollingTimer ??= Timer.periodic(const Duration(seconds: 4), (_) {
      _loadAuditLogsSilently();
    });
  }

  Future<void> _loadAuditLogsSilently() async {
    try {
      final supabaseAuditLogs = await _supabaseService.getAuditLogs();
      final fresh = supabaseAuditLogs.map(_fromSupabaseAuditLog).toList();

      // Merge local recent entries so fresh additions aren't lost if Supabase polling is pending/offline
      final freshIds = fresh.map((l) => l.id).toSet();
      for (final localLog in _auditLogs) {
        if (!freshIds.contains(localLog.id)) {
          if (DateTime.now().difference(localLog.timestamp).inMinutes < 10) {
            fresh.add(localLog);
          }
        }
      }

      fresh.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (_hasChanged(fresh)) {
        _auditLogs = fresh;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error silently loading audit logs: $e');
    }
  }

  bool _hasChanged(List<AdminAuditLog> fresh) {
    if (fresh.length != _auditLogs.length) return true;
    if (fresh.isEmpty) return false;
    return fresh.first.id != _auditLogs.first.id ||
        fresh.first.timestamp != _auditLogs.first.timestamp;
  }

  Future<void> _loadAuditLogs() async {
    try {
      final supabaseAuditLogs = await _supabaseService.getAuditLogs();
      _auditLogs = supabaseAuditLogs.map(_fromSupabaseAuditLog).toList();
      _auditLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      _error = 'Failed to load audit logs: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await _loadAuditLogs();
  }

  String _resolvePerformer(String? provided) {
    String? name;
    String? role;

    // 1. Check provided parameter
    if (provided != null &&
        provided.trim().isNotEmpty &&
        provided != 'System' &&
        provided != 'Unknown') {
      final p = provided.trim();
      final lowerP = p.toLowerCase();
      if (lowerP.contains('owner')) {
        return p.contains('(Owner)') ? p : '$p (Owner)';
      }
      if (lowerP.contains('employee') || lowerP.contains('cashier') || lowerP.contains('staff') || lowerP.contains('rider')) {
        return (p.contains('(Employee)') || p.contains('(Cashier)') || p.contains('(Staff)') || p.contains('(Rider)')) ? p : '$p (Employee)';
      }
      if (lowerP.contains('admin')) {
        return p.contains('(Admin)') ? p : '$p (Admin)';
      }
      name = p;
    }

    // 2. Check EmployeeProfileController
    try {
      final profile = EmployeeProfileController.instance.profile;
      if (profile.userId.isNotEmpty && (profile.firstName.isNotEmpty || profile.lastName.isNotEmpty || profile.email.isNotEmpty)) {
        if (name == null || name.isEmpty) {
          name = profile.fullName.trim().isNotEmpty ? profile.fullName.trim() : (profile.email.isNotEmpty ? profile.email.split('@').first : '');
        }
        role = profile.role.isNotEmpty ? profile.role : 'Employee';
      }
    } catch (_) {}

    // 3. Fallback to AuthService
    final user = AuthService().currentUser;
    if (user != null) {
      if (name == null || name.isEmpty) {
        final dName = user.displayName?.trim();
        final email = user.email?.trim();
        if (dName != null && dName.isNotEmpty) {
          name = dName;
        } else if (email != null && email.isNotEmpty) {
          name = email.split('@').first;
        }
      }
      if (role == null) {
        final lowerEmail = (user.email ?? '').toLowerCase();
        if (lowerEmail.contains('owner')) {
          role = 'Owner';
        } else if (lowerEmail.contains('admin')) {
          role = 'Admin';
        } else {
          role = 'Employee';
        }
      }
    }

    name = (name != null && name.trim().isNotEmpty) ? name.trim() : 'Employee';
    role = (role != null && role.trim().isNotEmpty) ? role.trim() : 'Employee';

    final lowerName = name.toLowerCase();
    final lowerRole = role.toLowerCase();
    if (!lowerName.contains(lowerRole)) {
      return '$name ($role)';
    }
    return name;
  }

  // ==================== AUDIT LOG OPERATIONS ====================

  AdminAuditLog auditLogById(String id) =>
      _auditLogs.firstWhere((log) => log.id == id,
          orElse: () => throw StateError('Audit log with id $id not found'));

  Future<void> logAction({
    required AuditAction action,
    required String entityType,
    required String entityId,
    required String entityName,
    String? performedBy,
    String? previousStatus,
    String? newStatus,
    String? note,
  }) async {
    try {
      final actor = _resolvePerformer(performedBy);
      final now = DateTime.now();

      final logData = {
        'action': action.name,
        'entity_type': entityType,
        'entity_id': entityId,
        'entity_name': entityName,
        'performed_by': actor,
        'timestamp': now.toUtc().toIso8601String(),
        'previous_status': previousStatus ?? '—',
        'new_status': newStatus ?? '—',
        'note': note,
      };

      // Insert in Supabase DB
      final result = await _supabaseService.insertAuditLog(logData);

      final newLog = AdminAuditLog(
        id: result?['id']?.toString() ?? 'L${now.millisecondsSinceEpoch}',
        action: action,
        entityType: entityType,
        entityId: entityId,
        entityName: entityName,
        performedBy: actor,
        timestamp: now,
        previousStatus: previousStatus ?? '—',
        newStatus: newStatus ?? '—',
        note: note,
      );

      _auditLogs.removeWhere((l) => l.id == newLog.id);
      _auditLogs.insert(0, newLog);
      notifyListeners();
    } catch (e) {
      debugPrint('Error in logAction: $e');
    }
  }

  Future<void> logCreate(String entityType, String entityId, String entityName,
      [String? performedBy, String? note]) async {
    await logAction(
      action: AuditAction.create,
      entityType: entityType,
      entityId: entityId,
      entityName: entityName,
      performedBy: performedBy,
      previousStatus: '—',
      newStatus: 'Active',
      note: note,
    );
  }

  Future<void> logUpdate(String entityType, String entityId, String entityName,
      [String? performedBy,
      String? previousStatus,
      String? newStatus,
      String? note]) async {
    await logAction(
      action: AuditAction.update,
      entityType: entityType,
      entityId: entityId,
      entityName: entityName,
      performedBy: performedBy,
      previousStatus: previousStatus ?? 'Active',
      newStatus: newStatus ?? 'Active',
      note: note,
    );
  }

  Future<void> logArchive(String entityType, String entityId, String entityName,
      [String? performedBy, String? note]) async {
    await logAction(
      action: AuditAction.archive,
      entityType: entityType,
      entityId: entityId,
      entityName: entityName,
      performedBy: performedBy,
      previousStatus: 'Active',
      newStatus: 'Archived',
      note: note,
    );
  }

  Future<void> logRestore(String entityType, String entityId, String entityName,
      [String? performedBy, String? note]) async {
    await logAction(
      action: AuditAction.restore,
      entityType: entityType,
      entityId: entityId,
      entityName: entityName,
      performedBy: performedBy,
      previousStatus: 'Archived',
      newStatus: 'Active',
      note: note,
    );
  }

  Future<void> logDelete(String entityType, String entityId, String entityName,
      [String? performedBy, String? note]) async {
    await logAction(
      action: AuditAction.permanentDelete,
      entityType: entityType,
      entityId: entityId,
      entityName: entityName,
      performedBy: performedBy,
      previousStatus: 'Archived',
      newStatus: 'Deleted',
      note: note,
    );
  }

  Future<void> logVoidSale(
      String entityId, String entityName, String? performedBy, String reason) async {
    await logAction(
      action: AuditAction.voidSale,
      entityType: 'Sale',
      entityId: entityId,
      entityName: entityName,
      performedBy: performedBy,
      previousStatus: 'Completed',
      newStatus: 'Voided',
      note: reason,
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  // ==================== DATA TRANSFORMATION ====================

  AdminAuditLog _fromSupabaseAuditLog(Map<String, dynamic> data) {
    AuditAction action = AuditAction.create;
    try {
      final actionString = data['action']?.toString() ?? 'create';
      switch (actionString.toLowerCase()) {
        case 'create':
        case 'created':
          action = AuditAction.create;
          break;
        case 'update':
        case 'updated':
          action = AuditAction.update;
          break;
        case 'archive':
        case 'archived':
          action = AuditAction.archive;
          break;
        case 'restore':
        case 'restored':
          action = AuditAction.restore;
          break;
        case 'permanentdelete':
        case 'delete':
        case 'deleted':
          action = AuditAction.permanentDelete;
          break;
        case 'voidsale':
        case 'voided':
        case 'void':
          action = AuditAction.voidSale;
          break;
        default:
          action = AuditAction.update;
      }
    } catch (e) {
      action = AuditAction.create;
    }

    return AdminAuditLog(
      id: data['id']?.toString() ?? '',
      action: action,
      entityType: data['entity_type']?.toString() ?? 'Entity',
      entityId: data['entity_id']?.toString() ?? '',
      entityName: data['entity_name']?.toString() ?? '',
      performedBy: data['performed_by']?.toString() ?? 'System',
      timestamp: (data['timestamp'] != null || data['created_at'] != null)
          ? DateTime.tryParse((data['timestamp'] ?? data['created_at']).toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      previousStatus: data['previous_status']?.toString() ?? '—',
      newStatus: data['new_status']?.toString() ?? '—',
      note: data['note']?.toString(),
    );
  }
}
