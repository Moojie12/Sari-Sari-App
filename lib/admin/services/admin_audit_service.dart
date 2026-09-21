import 'package:flutter/foundation.dart';
import '../models/admin_models.dart';
import '../../core/services/supabase_service.dart';

/// Service for handling audit log operations using Supabase as the data source
class AdminAuditService extends ChangeNotifier {
  AdminAuditService({
    SupabaseService? supabaseService,
  }) : _supabaseService = supabaseService ?? SupabaseService() {
    initialize();
  }

  final SupabaseService _supabaseService;

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
      _isInitialized = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAuditLogs() async {
    try {
      // Try to get audit logs from Supabase
      // If the audit_logs table doesn't exist yet, we'll start with an empty list
      try {
        final supabaseAuditLogs = await _supabaseService.getAuditLogs();
        _auditLogs = supabaseAuditLogs.map(_fromSupabaseAuditLog).toList();
      } catch (e) {
        // If audit logs table doesn't exist, start empty
        // In a real app, we might want to create the table or log a warning
        _auditLogs = [];
      }
    } catch (e) {
      _error = 'Failed to load audit logs: $e';
      // Don't rethrow - allow service to work with empty logs
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await initialize();
  }

  // ==================== AUDIT LOG OPERATIONS ====================

  AdminAuditLog auditLogById(String id) =>
    _auditLogs.firstWhere((log) => log.id == id, orElse: () => throw StateError('Audit log with id $id not found'));

  // In a real implementation, we'd have methods to create audit logs
  // For now, we'll rely on the application to call logAction methods
  // when significant events occur

  Future<void> logAction({
    required AuditAction action,
    required String entityType,
    required String entityId,
    required String entityName,
    required String performedBy,
    String? previousStatus,
    String? newStatus,
    String? note,
  }) async {
    try {
      // In a real implementation, this would insert into audit_logs table
      // For now, we'll just add to local cache and notify
      final newLog = AdminAuditLog(
        id: 'L${(_auditLogs.length + 1).toString().padLeft(4, '0')}',
        action: action,
        entityType: entityType,
        entityId: entityId,
        entityName: entityName,
        performedBy: performedBy,
        timestamp: DateTime.now(),
        previousStatus: previousStatus ?? '—',
        newStatus: newStatus ?? '—',
        note: note,
      );

      _auditLogs.add(newLog);
      _auditLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // newest first
      notifyListeners();
    } catch (e) {
      // Don't fail the main operation if audit logging fails
    }
  }

  // Convenience methods for common actions
  Future<void> logCreate(String entityType, String entityId, String entityName, String performedBy,
      {String? note}) async {
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

  Future<void> logUpdate(String entityType, String entityId, String entityName, String performedBy,
      String previousStatus, String newStatus, {String? note}) async {
    await logAction(
      action: AuditAction.update,
      entityType: entityType,
      entityId: entityId,
      entityName: entityName,
      performedBy: performedBy,
      previousStatus: previousStatus,
      newStatus: newStatus,
      note: note,
    );
  }

  Future<void> logArchive(String entityType, String entityId, String entityName, String performedBy,
      {String? note}) async {
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

  Future<void> logRestore(String entityType, String entityId, String entityName, String performedBy,
      {String? note}) async {
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

  Future<void> logDelete(String entityType, String entityId, String entityName, String performedBy,
      {String? note}) async {
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

  Future<void> logVoidSale(String entityId, String entityName, String performedBy, String reason) async {
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

  // ==================== DATA TRANSFORMATION ====================

  AdminAuditLog _fromSupabaseAuditLog(Map<String, dynamic> data) {
    // Parse action from string
    AuditAction action = AuditAction.create; // default
    try {
      final actionString = data['action'] as String? ?? 'create';
      switch (actionString.toLowerCase()) {
        case 'create':
          action = AuditAction.create;
          break;
        case 'update':
          action = AuditAction.update;
          break;
        case 'archive':
          action = AuditAction.archive;
          break;
        case 'restore':
          action = AuditAction.restore;
          break;
        case 'permanentdelete':
        case 'delete':
          action = AuditAction.permanentDelete;
          break;
        case 'voidsale':
        case 'voided':
          action = AuditAction.voidSale;
          break;
        default:
          action = AuditAction.create;
      }
    } catch (e) {
      action = AuditAction.create;
    }

    return AdminAuditLog(
      id: data['id'] as String,
      action: action,
      entityType: data['entity_type'] as String,
      entityId: data['entity_id'] as String,
      entityName: data['entity_name'] as String,
      performedBy: data['performed_by'] as String,
      timestamp: data['timestamp'] != null
          ? DateTime.parse(data['timestamp'] as String)
          : DateTime.now(),
      previousStatus: data['previous_status'] as String? ?? '—',
      newStatus: data['new_status'] as String? ?? '—',
      note: data['note'] as String?,
    );
  }
}