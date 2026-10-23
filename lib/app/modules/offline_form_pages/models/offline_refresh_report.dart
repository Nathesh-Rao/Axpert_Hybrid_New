/// A snapshot of one refresh. This is notification data, not sync state.
class OfflineRefreshReport {
  final List<OfflineRefreshFormResult> forms;
  OfflineRefreshReport(this.forms);
  int get updatedForms => forms.where((form) => form.formUpdated).length;
  int get failedForms => forms.where((form) => form.formError != null).length;
  Map<String, dynamic> toMap() => {
    'forms': forms.map((form) => form.toMap()).toList(),
  };
  factory OfflineRefreshReport.fromMap(Map<String, dynamic> map) =>
      OfflineRefreshReport(
        (map['forms'] as List)
            .map(
              (form) => OfflineRefreshFormResult.fromMap(
                Map<String, dynamic>.from(form as Map),
              ),
            )
            .toList(),
      );
}

class OfflineRefreshFormResult {
  final String transId, caption;
  bool formUpdated;
  String? formError;
  bool lookupsCompleted;
  int updatedLookups, failedLookups;
  final List<OfflineLookupError> lookupErrors;
  OfflineRefreshFormResult({
    required this.transId,
    required this.caption,
    this.formUpdated = false,
    this.formError,
    this.lookupsCompleted = false,
    this.updatedLookups = 0,
    this.failedLookups = 0,
    List<OfflineLookupError>? lookupErrors,
  }) : lookupErrors = lookupErrors ?? [];
  int get totalLookups => updatedLookups + failedLookups;
  Map<String, dynamic> toMap() => {
    'trans_id': transId,
    'caption': caption,
    'form_updated': formUpdated,
    'form_error': formError,
    'lookups_completed': lookupsCompleted,
    'updated_lookups': updatedLookups,
    'failed_lookups': failedLookups,
    'lookup_errors': lookupErrors.map((error) => error.toMap()).toList(),
  };
  factory OfflineRefreshFormResult.fromMap(Map<String, dynamic> map) =>
      OfflineRefreshFormResult(
        transId: map['trans_id'] as String,
        caption: map['caption'] as String,
        formUpdated: map['form_updated'] == true,
        formError: map['form_error'] as String?,
        lookupsCompleted: map['lookups_completed'] == true,
        updatedLookups: map['updated_lookups'] as int? ?? 0,
        failedLookups: map['failed_lookups'] as int? ?? 0,
        lookupErrors: (map['lookup_errors'] as List? ?? [])
            .map(
              (error) => OfflineLookupError.fromMap(
                Map<String, dynamic>.from(error as Map),
              ),
            )
            .toList(),
      );
}

class OfflineLookupError {
  final String datasource, caption, message;
  const OfflineLookupError({
    required this.datasource,
    required this.caption,
    required this.message,
  });
  Map<String, dynamic> toMap() => {
    'datasource': datasource,
    'caption': caption,
    'message': message,
  };
  factory OfflineLookupError.fromMap(Map<String, dynamic> map) =>
      OfflineLookupError(
        datasource: map['datasource'] as String,
        caption: map['caption'] as String,
        message: map['message'] as String,
      );
}
