import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' show max;
import 'package:axpert/app/data/const/app_const.dart';
import 'package:axpert/app/data/services/api/api_endpoints.dart';
import 'package:axpert/app/data/services/api/api_manger.dart';
import 'package:axpert/app/data/services/storage/storage_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';

import '../../../core/common.dart';
import '../../../data/services/connectivity/internet_connectivity.dart';
import '../../../data/services/log/log_service.dart';
import '../../webview/controller/webview_controller.dart';
import '../auto_sync/offline_background_sync_service.dart';
import '../db/db.dart';
import '../db/offline_db_module.dart';
import '../models/cached_save_item_model.dart';
import '../models/models.dart';
import '../models/queue_resolve_result_model.dart';
import '../widgets/all_records_done_dialog.dart';
import '../widgets/cached_refresh_dialog.dart';
// import '../widgets/cached_save_dialog.dart'; // Previous modal retained below.
import '../widgets/session_validation__dialog.dart';
import '../widgets/widgets.dart';
import '../widgets/refresh_selection_dialog.dart';
import '../models/offline_notification_model.dart';
import '../models/offline_record_correction.dart';
import '../models/offline_update_messages.dart';
import '../models/offline_refresh_report.dart';
import '../models/offline_send_banner_state.dart';
import '../models/offline_batch_banner_updates.dart';
import '../pages/offline_notifications_page.dart';

class OfflineFormController extends GetxController {
  late OfflineFormPageModel page;

  final Map<String, OfflineFormFieldModel> fieldMap = {};
  List<Map<String, dynamic>> allRawPages = [];
  var isLoading = false.obs;

  RxList<OfflineFormPageModel> allPages = <OfflineFormPageModel>[].obs;

  RxList<OfflineAttachmentModel> attachments = <OfflineAttachmentModel>[].obs;

  final ImagePicker _imagePicker = ImagePicker();

  // ================= FROM LANDING PAGE =================

  // ================= OFFLINE DASHBOARD STATE =================

  var isConnected = false.obs;
  final unreadOfflineNotifications = 0.obs;
  Timer? _notificationTimer;
  bool _readingNotificationCount = false;
  bool _openingNotificationRecord = false;
  int? editingRecordId;
  int? _editingVersion;
  String? _editingUsername, _editingProject;
  Map<String, dynamic>? _originalRecordPayload;
  final Map<String, String> _loadedFieldValues = {};
  final correctionMessage = ''.obs;
  String? correctionField;
  bool get isCorrectingRecord => editingRecordId != null;

  Future<void> refreshNotificationCount() async {
    if (_readingNotificationCount) return;
    _readingNotificationCount = true;
    try {
      unreadOfflineNotifications.value =
          await OfflineNotifications.unreadCount();
      await refreshBatchResultBanner();
      if (isConnected.value)
        unawaited(OfflineNotifications.retryTriggeredResults());
    } catch (e) {
      LogService.writeLog(
        message: '[OFFLINE_NOTIFICATION] Badge refresh failed: $e',
      );
    } finally {
      _readingNotificationCount = false;
    }
  }

  Future<void> openOfflineNotifications() async {
    await Get.to(() => OfflineNotificationsPage(formController: this));
    await refreshNotificationCount();
  }

  Future<void> openNotificationRecord(
    OfflineNotificationModel notification,
  ) async {
    if (notification.recordId == null ||
        _openingNotificationRecord ||
        isLoading.value ||
        isFormPreparing.value)
      return;
    _openingNotificationRecord = true;
    try {
      final record = await OfflineNotifications.loadRecord(
        notification.recordId!,
      );
      final scope = await OfflineNotifications.store();
      if (record == null ||
          scope?.username != notification.username ||
          scope?.projectName != notification.projectName) {
        throw StateError(
          'This record is no longer available in the current project.',
        );
      }
      if (record['record_version'] != notification.recordVersion) {
        throw StateError(
          'This record has already been updated. Open its latest notification if it fails again.',
        );
      }
      if (record['status'] == OfflineDBConstants.RECORD_STATUS_QUEUED) {
        throw StateError(
          'This record is being processed. Please check submission status first.',
        );
      }
      if (record['status'] == OfflineDBConstants.RECORD_STATUS_SUCCESS) {
        throw StateError(
          'This record has already been submitted successfully.',
        );
      }
      if ((record['current_queue_id'] as String? ?? '').isNotEmpty &&
          record['current_queue_id'] != notification.queueId) {
        throw StateError(
          'A newer submission exists for this record. Open its latest notification.',
        );
      }
      final payload = record['payload'] as Map<String, dynamic>;
      final pages = await OfflineDbModule.getOfflinePages();
      final matches = pages
          .where((p) => p['transid'] == payload['transid'])
          .toList();
      if (matches.isEmpty)
        throw StateError(
          'This form is not available offline. Refresh the form and try again.',
        );
      await prepareForm(matches.first);
      editingRecordId = notification.recordId;
      _editingVersion = record['record_version'] as int? ?? 0;
      _editingUsername = notification.username;
      _editingProject = notification.projectName;
      _originalRecordPayload =
          jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
      final values = payload['submitdata']?['dc1']?['row1'] as Map? ?? {};
      // Hydrate controllers without dropping additional DCs, rows or attachments.
      for (final field in page.fields) {
        final stored = values[field.fldName];
        final text = stored == null
            ? ''
            : stored is String
            ? stored
            : stored.toString();
        textCtrls[field.fldName]?.text = text;
        dropdownCtrls[field.fldName]?.value = text;
        field.value = stored ?? '';
        _loadedFieldValues[field.fldName] =
            dropdownCtrls[field.fldName]?.value ??
            textCtrls[field.fldName]?.text.trim() ??
            text.trim();
      }
      correctionMessage.value =
          record['response']?.toString().isNotEmpty == true
          ? record['response'].toString()
          : notification.message;
      correctionField = matchOfflineErrorField(
        correctionMessage.value,
        (schema['fields'] as List)
            .map((f) => Map<String, dynamic>.from(f))
            .toList(),
      );
      if (correctionField != null)
        errors[correctionField!] = correctionMessage.value;
      LogService.writeLog(
        message:
            '[OFFLINE_NOTIFICATION] Open record=${notification.recordId} form=${page.transId} field=$correctionField',
      );
      update();
      await Get.toNamed(Routes.OFFLINE_FORM_PAGE);
    } catch (e) {
      LogService.writeLog(
        message: '[OFFLINE_NOTIFICATION] Open record failed: $e',
      );
      Get.snackbar(
        'Record unavailable',
        e.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _openingNotificationRecord = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    refreshPendingCount();
    listenInternetState();
    resetForm();
    refreshNotificationCount();
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => refreshNotificationCount(),
    );
  }

  @override
  void onClose() {
    _notificationTimer?.cancel();
    _sendBannerTimer?.cancel();
    super.onClose();
  }

  /////////////////////////////////////////////////////////////////////////////
  /////////////////////FROM INWRD ENTRY CONTROLLER////////////////////////////
  /////////////////////////////////////////////////////////////////////////////

  ///------------------------------------------------------------
  Map<String, dynamic> schema = {};
  var isFormPreparing = false.obs;
  final Map<String, TextEditingController> textCtrls = {};
  final Map<String, RxString> dropdownCtrls = {};
  final ScrollController scrollCtrl = ScrollController();
  final errors = <String, String>{}.obs;
  final Map<String, List<Map<String, dynamic>>> datasourceMap = {};
  Map<String, dynamic> dc1SubmitFormJson = {};

  ///------------------------------------------------------------
  TextEditingController getTextCtrl(String name) => textCtrls[name]!;
  RxString getDropdownCtrl(String name) => dropdownCtrls[name]!;

  ///------------------------------------------------------------

  ///////////////////////////////////////

  Future<void> prepareForm(
    Map<String, dynamic> newSchema, {
    bool reuseControllers = false,
  }) async {
    editingRecordId = null;
    _editingVersion = null;
    _originalRecordPayload = null;
    _loadedFieldValues.clear();
    correctionMessage.value = '';
    correctionField = null;
    isFormPreparing.value = true;
    page = OfflineFormPageModel.fromJson(newSchema);
    schema = newSchema;
    // 1. clear old stuff
    resetForm();
    // scrollCtrl.animateTo(
    //   0,
    //   duration: const Duration(milliseconds: 500),
    //   curve: Curves.easeInOut,
    // );
    // 2. Opening a different form replaces its controllers. Resetting the
    // current mounted form must keep both text and dropdown controller objects
    // alive: reactive field builders may run before this method finishes.
    if (!reuseControllers) {
      for (final c in textCtrls.values) {
        c.dispose();
      }
      textCtrls.clear();
      dropdownCtrls.clear();
    }

    // 3. Restore defaults using the existing schema builder. Reuse is only
    // requested for a new entry on this same form, never for a schema switch.
    _buildControllersFromSchema(reuseControllers: reuseControllers);

    // 4. A new entry keeps the current offline lookup data and subscriptions.
    // Clearing/reloading it mid-reset can temporarily invalidate dropdowns.
    if (!reuseControllers) {
      await loadDatasources();

      // 5. Attach business rules only to newly created controllers.
      _attachBusinessListeners();
    }

    // 6. scroll to top
    if (scrollCtrl.hasClients) {
      scrollCtrl.jumpTo(0);
    }

    isFormPreparing.value = false;
    update();
  }

  Future<void> onPopCalled() async {
    final bool confirm =
        await Get.dialog(
          AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.white,
            title: const Text(
              "Exit Form?",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            content: const Text(
              "Unsaved changes will be lost.\nAre you sure you want to go back?",
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: Text(
                  "Cancel",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                child: const Text(
                  "Exit",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      Get.back();
    }
  }

  void _buildControllersFromSchema({bool reuseControllers = false}) {
    final List fields = schema["fields"];

    for (final f in fields) {
      final String name = f["fld_name"];
      final String rawType = f["fld_type"];
      final String defValue = f["def_value"]?.toString() ?? "";
      final bool isUpper = rawType.endsWith("_upper");
      final String type = isUpper ? rawType.replaceAll("_upper", "") : rawType;
      if (type == "dd") {
        if (!reuseControllers || !dropdownCtrls.containsKey(name)) {
          dropdownCtrls[name] = "".obs;
        } else {
          dropdownCtrls[name]!.value = '';
        }

        if (defValue.isNotEmpty) {
          List<String> validOptions = getDropdownOptions(name);

          if (validOptions.contains(defValue)) {
            dropdownCtrls[name]!.value = defValue;
          }
        }
      } else {
        final existing = reuseControllers ? textCtrls[name] : null;
        final ctrl = existing ?? TextEditingController(text: defValue);
        if (existing != null) ctrl.text = defValue;

        // Reused controllers already have their uppercase/business listeners.
        if (isUpper && existing == null) {
          ctrl.addListener(() {
            final String text = ctrl.text;
            final String formatted = text.toUpperCase();

            if (text != formatted) {
              int cursorPosition = ctrl.selection.baseOffset;

              ctrl.value = TextEditingValue(
                text: formatted,
                selection: TextSelection.collapsed(offset: cursorPosition),
              );
            }
          });
        }

        textCtrls[name] = ctrl;
      }
    }
  }

  List<String> getDropdownOptions(String fieldName) {
    if (!isFieldEnabled(fieldName)) return [];

    final fieldDef = (schema['fields'] as List).firstWhere(
      (e) => e['fld_name'] == fieldName,
      orElse: () => null,
    );
    if (fieldDef == null) return [];

    final String? dsName = fieldDef['datasource'];
    if (dsName == null || !datasourceMap.containsKey(dsName)) return [];

    List<Map<String, dynamic>> filteredList = datasourceMap[dsName]!;

    final List deps = fieldDef['dep_field'] ?? [];
    if (deps.isNotEmpty) {
      filteredList = filteredList.where((row) {
        for (final parentKey in deps) {
          final parentSelected = dropdownCtrls[parentKey]?.value ?? "";

          // Data Match Logic
          String rowVal = row[parentKey]?.toString() ?? "";
          if (rowVal.endsWith(".0")) rowVal = rowVal.replaceAll(".0", "");

          String parentVal = parentSelected;
          if (parentVal.endsWith(".0"))
            parentVal = parentVal.replaceAll(".0", "");

          if (rowVal.toLowerCase() != parentVal.toLowerCase()) return false;
        }
        return true;
      }).toList();
    }

    final Set<String> uniqueValues = {};
    for (final row in filteredList) {
      final val = row[fieldName]?.toString();
      if (val != null && val.isNotEmpty) uniqueValues.add(val);
    }

    return uniqueValues.toList()..sort();
  }

  bool isFieldEnabled(String fieldName) {
    final fieldDef = (schema['fields'] as List).firstWhere(
      (e) => e['fld_name'] == fieldName,
      orElse: () => null,
    );

    if (fieldDef == null) return true;

    final List deps = fieldDef['dep_field'] ?? [];

    if (deps.isEmpty) return true;

    for (final parentKey in deps) {
      final parentValue = dropdownCtrls[parentKey]?.value ?? "";
      if (parentValue.isEmpty) {
        return false;
      }
    }

    return true;
  }

  Future<void> loadDatasources() async {
    datasourceMap.clear();

    final List fields = schema["fields"];
    final Set<String> needed = {};

    for (final f in fields) {
      if (f["datasource"] != null && f["datasource"].toString().isNotEmpty) {
        needed.add(f["datasource"]);
      }
    }

    for (final ds in needed) {
      final list = await OfflineDbModule.getDatasourceOptions(
        transId: schema["transid"],
        datasource: ds,
      );
      datasourceMap[ds] = List<Map<String, dynamic>>.from(list);
    }

    update();
  }

  void _attachBusinessListeners() {
    //ANY BSNS LOGICS GOES HERE
    // getTextCtrl("billed_qty_bags_crates").addListener(_onReceivedChanged);
    // ever(getTextCtrl("eceived_bags_crates"), (_){
    //   _onReceivedChanged();
    // });
    // getTextCtrl("bags_sample").addListener(_recheckMiniFab);
    // getTextCtrl("loaded_truck").addListener(_calculateNetWeight);
    // getTextCtrl("empty_truck").addListener(_calculateNetWeight);
    // getTextCtrl("received_bags_crates").addListener(_checkForBilledQty);
    // getTextCtrl("billed_qty_bags_crates").addListener(_checkForBilledQty);
    // getDropdownCtrl("packing").listen((_) {
    //   _onReceivedChanged();
    // });

    // ever(getDropdownCtrl("packing"), (_) {
    //   _onReceivedChanged();
    // });
  }

  /////////////////////////////////////////////////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////

  Future<void> onFormSubmit() async {
    if (isLoading.value) return;
    isLoading.value = true;

    try {
      if (!await validateForm()) {
        Get.snackbar(
          "Missing Fields",
          "Please fill all required fields before proceeding.",
          backgroundColor: AppColors.accentRed,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        );
        return;
      }
      final Map<String, dynamic> mainPayload =
          generateSubmitPayloadCachedSave();
      log(mainPayload.toString(), name: "mainpayload");
      final int mainRecId = await OfflineDbModule.savePayloadForQueue(
        payload: mainPayload,
        existingRecordId: editingRecordId,
        expectedVersion: _editingVersion,
        expectedUsername: _editingUsername,
        expectedProjectName: _editingProject,
      );

      if (mainRecId == -1) {
        throw Exception("Failed to save main form payload to queue.");
      }
      errors.clear();
      if (isCorrectingRecord) {
        // A notification correction updates the existing record and returns
        // to its results page, preserving that separate workflow.
        Get.back();
      } else {
        // Previously Get.back() closed every newly saved offline form.
        // Keep this route open and reuse the schema/default/lookup setup for
        // the next record only after the current record is safely stored.
        await startNewTransaction();
      }

      await refreshPendingCount();
      if (isCorrectingRecord) {
        // Show confirmation on the destination page after the form closes.
        final context = Get.context;
        if (context != null) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Record updated. Your changes are ready for sync.'),
            ),
          );
        }
      } else {
        final context = Get.context;
        if (context != null) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Record saved offline. Ready for a new entry.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      LogService.writeLog(
        message: '[OFFLINE_FORM_SAVE] Failed record=$editingRecordId: $e',
      );
      Get.snackbar(
        'Could not save',
        isCorrectingRecord
            ? 'The record may be syncing or has changed. Please check submission status and reopen it before saving again.'
            : 'Your record could not be saved. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> startNewTransaction() async {
    log("start new transaction clicked");
    try {
      isFormPreparing.value = true;

      // Release keyboard focus and clear only this entry's attachment list.
      // Saved files/queued records remain untouched.
      FocusManager.instance.primaryFocus?.unfocus();
      attachments.clear();

      // Keep mounted field controllers and lookup subscriptions alive while
      // restoring defaults. Normal form opening still builds fresh objects.
      await prepareForm(schema, reuseControllers: true);

      // Scroll to top
      if (scrollCtrl.hasClients) {
        scrollCtrl.jumpTo(0);
      }

      update();
    } catch (e, st) {
      LogService.writeLog(message: "startNewTransaction error => $e\n$st");
    } finally {
      isFormPreparing.value = false;
    }
  }

  Map<String, dynamic> generateSubmitPayloadCachedSave() {
    if (isCorrectingRecord && _originalRecordPayload != null) {
      // Merge changed controls into the original payload instead of rebuilding
      // it; unknown fields, attachment objects and additional rows stay intact.
      final payload =
          jsonDecode(jsonEncode(_originalRecordPayload))
              as Map<String, dynamic>;
      final row = payload['submitdata']['dc1']['row1'] as Map<String, dynamic>;
      for (final field in page.fields) {
        final value =
            dropdownCtrls[field.fldName]?.value ??
            textCtrls[field.fldName]?.text.trim() ??
            '';
        if (value != _loadedFieldValues[field.fldName])
          row[field.fldName] = value;
      }
      payload['axm_recid'] = editingRecordId.toString();
      return payload;
    }
    final Map<String, dynamic> dc1Data = {};
    final List fields = schema["fields"];

    for (final f in fields) {
      final String name = f["fld_name"];
      final String type = f["fld_type"];

      dynamic value;
      if (type == "dd") {
        value = dropdownCtrls[name]?.value ?? "";
      } else {
        value = textCtrls[name]?.text.trim() ?? "";
      }
      dc1Data[name] = value.toString();
    }

    return {
      "transid": page.transId,
      "axm_recid": "0", // placeholder — replaced by savePayloadForQueue()
      "action": "create",
      "submitdata": {
        "dc1": {"row1": dc1Data},
      },
    };
  }

  Future<void> refreshPendingCount() async {
    try {
      int count = await OfflineDbModule.getPendingCount();
      pendingCount.value = count;
      await refreshPendingQueuesCount();
    } catch (e) {
      print("Error fetching pending count: $e");
    }
  }

  Future<void> refreshPendingQueuesCount() async {
    try {
      var rows = await OfflineDbModule.getPendigQueuesToRefresh();
      pendingQueuesCount.value = formSubmissionQueues(rows).length;
    } catch (e) {
      print("Error fetching pending count: $e");
    }
  }

  /// Presentation filter only. Shared DB queries/resolvers must continue to
  /// include audit queues so manual/background processing remains unchanged.
  List<Map<String, dynamic>> formSubmissionQueues(
    Iterable<Map<String, dynamic>> rows,
  ) => rows.where((row) {
    // Older queue rows without a source belong to the original form queue.
    final source = row[OfflineDBConstants.COL_SOURCE_TABLE]?.toString() ?? '';
    return source.isEmpty ||
        source == OfflineDBConstants.TABLE_PENDING_REQUESTS;
  }).toList();

  void listenInternetState() async {
    final InternetConnectivity net = Get.find<InternetConnectivity>();

    isConnected.value = await net.check();

    ever<bool>(net.isConnected, (connected) {
      isConnected.value = connected;
    });
  }

  Map<String, dynamic>? offlineUser;
  var offlineFormsCount = 0.obs;
  var pendingCount = 0.obs;
  var pendingQueuesCount = 0.obs;

  bool isDashboardBusy = false;

  ///////////////////////////////////////

  // ---------------- LOAD ALL PAGES ----------------

  Future<void> getAllPages() async {
    const String tag = "[OFFLINE_PAGES_LOAD_001]";
    try {
      isLoading.value = true;

      final rawPages = allRawPages = await OfflineDbModule.getOfflinePages();

      if (rawPages.isEmpty) {
        LogService.writeLog(message: "$tag[INFO] No offline pages in DB");
        allPages.clear();
        return;
      }

      final pages = rawPages
          .map((e) => OfflineFormPageModel.fromJson(e))
          .where((p) => p.visible)
          .toList();

      allPages.value = pages;

      LogService.writeLog(
        message: "$tag[SUCCESS] Loaded ${pages.length} pages from DB",
      );
    } catch (e, st) {
      LogService.writeLog(
        message: "$tag[FAILED] Failed to load offline pages => $e",
      );
      LogService.writeLog(message: "$tag[STACK] $st");
    } finally {
      isLoading.value = false;
      refreshPendingCount();
    }
  }

  Future<void> loadPage(OfflineFormPageModel pageModel) async {
    var tempPage = await OfflineDbModule.mapDatasourceOptionsIntoPages(
      pages: [pageModel],
    );
    page = tempPage.first;
    fieldMap.clear();
    attachments.clear();

    final sortedFields = [...page.fields]
      ..sort((a, b) => a.order.compareTo(b.order));

    for (final field in sortedFields) {
      field.value = field.defValue;
      field.errorText = null;
      fieldMap[field.fldName] = field;
    }
    Get.toNamed(Routes.OFFLINE_FORM_PAGE);
  }

  void updateFieldValue(OfflineFormFieldModel field, dynamic newValue) {
    final bool isDs = field.datasource != null && field.datasource!.isNotEmpty;

    switch (field.fldType) {
      case 'cb':
        field.value =
            (newValue == true || newValue.toString().toLowerCase() == 'true')
                .toString();
        break;

      case 'cl':
        if (isDs) {
          // datasource checklist → store list of IDs
          if (newValue is List) {
            field.value = newValue;
          }
        } else {
          // normal checklist → old behavior
          if (newValue is List<String>) {
            field.value = newValue.join(',');
          }
        }
        break;

      case 'rb':
      case 'rl':
      case 'dd':
        if (isDs) {
          field.value = newValue;
        } else {
          field.value = newValue.toString();
        }
        break;

      case 'c':
      case 'n':
      case 'm':
      case 'd':
        field.value = newValue.toString();
        break;

      case 'image':
        field.value = newValue.toString();
        break;

      default:
        field.value = newValue;
        break;
    }

    field.errorText = null;
    fieldMap[field.fldName] = field;
    update([field.fldName]);
  }

  Future<bool> validateForm() async {
    errors.clear();

    final List fields = schema["fields"];

    for (final f in fields) {
      final String name = f["fld_name"];
      final String label = f["fld_caption"];
      final String allowEmpty = f["allowempty"] ?? "T";
      final String type = f["fld_type"];

      if (allowEmpty == "F") {
        String value = "";

        if (type == "dd") {
          value = dropdownCtrls[name]?.value ?? "";
        } else {
          value = textCtrls[name]?.text.trim() ?? "";
        }

        if (value.isEmpty) {
          errors[name] = "$label is required";
        }
      }

      // if (name == 'ub_ge_no') {
      //   await validateUbgeNo(
      //       textCtrls[name]!, textCtrls[name]?.text ?? '', name);
      //   // errors[name] = "duplicate ubge no, please update";
      // }
    }
    return errors.isEmpty;
  }

  bool validateFormOld() {
    bool isFormValid = true;

    for (final field in fieldMap.values) {
      final value = field.value.trim();
      bool isValid = true;

      /// allowempty = T means NOT mandatory
      if (field.allowEmpty) {
        field.errorText = null;
        continue;
      }

      switch (field.fldType) {
        case 'cb':
          isValid = value.toLowerCase() == 'true';
          break;

        case 'cl':
          isValid = value
              .split(',')
              .where((e) => e.trim().isNotEmpty)
              .isNotEmpty;
          break;

        default:
          isValid = value.isNotEmpty;
          break;
      }

      if (!isValid) {
        isFormValid = false;
        field.errorText = '${field.fldCaption} is required';
      } else {
        field.errorText = null;
      }

      fieldMap[field.fldName] = field;
      update([field.fldName]);
    }

    log(fieldMap.toString(), name: "fieldMap");
    return isFormValid;
  }

  void resetForm() {
    for (final c in textCtrls.values) {
      c.clear();
    }
    for (final d in dropdownCtrls.values) {
      d.value = "";
    }
    // clearSampleGrid();
    // showMiniFab.value = false;
    // sampleSummaryJson.clear();
    dc1SubmitFormJson.clear();
    errors.clear();
  }

  // ---------------- COLLECT DATA ----------------

  Map<String, dynamic> collectFormData() {
    final Map<String, dynamic> data = {};

    for (final field in fieldMap.values) {
      data[field.fldName] = field.value;
    }

    return data;
  }

  // ---------------- HELPERS ----------------

  OfflineFormFieldModel? getField(String fldName) {
    return fieldMap[fldName];
  }

  String getFieldValue(String fldName) {
    return fieldMap[fldName]?.value ?? '';
  }

  bool isFieldFilled(String fldName) {
    final v = fieldMap[fldName]?.value.trim() ?? '';
    return v.isNotEmpty;
  }

  Future<void> pickImage({
    required OfflineFormFieldModel field,
    required ImageSource source,
  }) async {
    if (field.readOnly) return;

    final XFile? file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 75,
    );

    if (file == null) {
      _showImageNotSelectedMsg();
      return;
    }

    final bytes = await File(file.path).readAsBytes();
    final base64 = base64Encode(bytes);

    updateFieldValue(field, base64);
  }

  void removeImage(OfflineFormFieldModel field) {
    if (field.readOnly) return;
    updateFieldValue(field, '');
  }

  void _showImageNotSelectedMsg() {
    Get.snackbar(
      'Image not selected',
      'Please select an image to continue',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> pickAttachment() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result == null || result.files.isEmpty) {
      Get.snackbar(
        'No file selected',
        'Please select a file to attach',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    for (final f in result.files) {
      if (f.path == null) continue;

      attachments.add(
        OfflineAttachmentModel(
          name: f.name,
          path: f.path!,
          extension: f.extension ?? '',
        ),
      );
    }
  }

  void removeAttachment(OfflineAttachmentModel file) {
    attachments.remove(file);
  }

  IconData getAttachmentIcon(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'mp4':
      case 'mov':
        return Icons.videocam;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color getAttachmentColor(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return Colors.redAccent;

      case 'jpg':
      case 'jpeg':
      case 'png':
        return Colors.blueAccent;

      case 'doc':
      case 'docx':
        return Colors.indigo;

      case 'xls':
      case 'xlsx':
        return Colors.green;

      case 'mp4':
      case 'mov':
        return Colors.deepPurple;

      default:
        return Colors.grey;
    }
  }

  String getAttachmentTypeSummary() {
    if (attachments.isEmpty) return '';

    int images = 0;
    int docs = 0;
    int videos = 0;
    int others = 0;

    for (final file in attachments) {
      final ext = file.extension.toLowerCase();

      if (['jpg', 'jpeg', 'png'].contains(ext)) {
        images++;
      } else if (['doc', 'docx', 'pdf', 'xls', 'xlsx'].contains(ext)) {
        docs++;
      } else if (['mp4', 'mov'].contains(ext)) {
        videos++;
      } else {
        others++;
      }
    }

    final List<String> parts = [];

    if (images > 0) parts.add('$images image${images > 1 ? 's' : ''}');
    if (docs > 0) parts.add('$docs doc${docs > 1 ? 's' : ''}');
    if (videos > 0) parts.add('$videos video${videos > 1 ? 's' : ''}');
    if (others > 0) parts.add('$others file${others > 1 ? 's' : ''}');

    return parts.join(', ');
  }

  Future<bool> guardOnlineOrShowDialog() async {
    final connectivity = Get.find<InternetConnectivity>();

    if (connectivity.isConnected.value) return true;

    await Get.dialog(
      AlertDialog(
        title: const Text("No Internet"),
        content: const Text("This action requires internet connection."),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("OK")),
        ],
      ),
    );

    return false;
  }

  Future<void> confirmAndRun({
    required String title,
    required String message,
    required Future<void> Function() action,
  }) async {
    if (isDashboardBusy) return;

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    isDashboardBusy = true;
    update();

    try {
      await action();
      // await loadOfflineDashboard();
    } finally {
      isDashboardBusy = false;
      update();
    }
  }
  // ================= DASHBOARD ACTIONS =================

  void goToOfflineForms() {
    Get.toNamed(Routes.OFFLINE_LISTING_PAGE);
  }

  // ---------- SYNC ----------

  Future<void> refetchAll() async {
    if (!await guardOnlineOrShowDialog()) return;

    await confirmAndRun(
      title: "Refetch Everything",
      message: "This will re-download all forms and datasources. Continue?",
      action: () async {
        await OfflineDbModule.syncAllData(isInternetAvailable: true);
      },
    );
  }

  Future<void> refetchForms() async {
    if (!await guardOnlineOrShowDialog()) return;

    await confirmAndRun(
      title: "Refetch Forms",
      message: "This will re-download all forms. Continue?",
      action: () async {
        await OfflineDbModule.refetchOnlyForms();
      },
    );
  }

  Future<void> refetchDatasources() async {
    if (!await guardOnlineOrShowDialog()) return;

    await confirmAndRun(
      title: "Refetch Datasources",
      message: "This will re-download all datasources. Continue?",
      action: () async {
        // await OfflineDbModule.refetchOnlyDatasources();
      },
    );
  }

  // ---------- CLEAR ----------

  Future<void> clearAllCache() async {
    await confirmAndRun(
      title: "Clear All Cache",
      message: "This will delete all offline data except user. Continue?",
      action: () async {
        // await OfflineDbModule.clearOfflineCache();
      },
    );
  }

  Future<void> clearForms() async {
    await confirmAndRun(
      title: "Clear Forms",
      message: "This will delete all offline forms. Continue?",
      action: () async {
        // await OfflineDbModule.deleteTable(
        //   OfflineDBConstants.TABLE_OFFLINE_PAGES,
        // );
      },
    );
  }

  Future<void> clearDatasources() async {
    await confirmAndRun(
      title: "Clear Datasources",
      message: "This will delete all cached datasources. Continue?",
      action: () async {
        // await OfflineDbModule.deleteTable(
        //   OfflineDBConstants.TABLE_DATASOURCE_DATA,
        // );
      },
    );
  }

  Future<void> clearPending() async {
    await confirmAndRun(
      title: "Clear Pending Uploads",
      message: "This will delete all pending uploads. Continue?",
      action: () async {
        refreshPendingCount();
      },
    );
  }

  Future<void> actionRefetchForms() async {
    const tag = "[OFFLINE_ACTION_REFETCH_FORMS_001]";

    if (!await _isInternetAvailable()) {
      _showNeedInternetDialog();
      return;
    }

    final ok = await _confirm(
      title: "Refetch Forms",
      message: "This will replace all offline forms. Continue?",
    );
    if (!ok) return;

    try {
      isLoading.value = true;

      await OfflineDbModule.fetchAndStoreOfflinePages();
      await getAllPages();
      // await loadOfflineDashboard();

      Get.snackbar("Success", "Forms refreshed");
      LogService.writeLog(message: "$tag[SUCCESS]");
    } catch (e, st) {
      LogService.writeLog(message: "$tag[FAILED] $e");
      LogService.writeLog(message: "$tag[STACK] $st");
      Get.snackbar("Error", "Failed to refetch forms");
    } finally {
      isLoading.value = false;
    }
  }

  void actionShowPending() {}
  Future<void> actionClearForms() async {
    const tag = "[OFFLINE_ACTION_CLEAR_FORMS_001]";

    final ok = await _confirm(
      title: "Clear Forms",
      message: "This will delete all offline forms. Continue?",
    );
    if (!ok) return;

    try {
      isLoading.value = true;

      await OfflineDbModule.clearOfflinePages();
      await getAllPages();
      // await loadOfflineDashboard();

      Get.snackbar("Done", "Offline forms cleared");
      LogService.writeLog(message: "$tag[SUCCESS]");
    } catch (e, st) {
      LogService.writeLog(message: "$tag[FAILED] $e");
      LogService.writeLog(message: "$tag[STACK] $st");
      Get.snackbar("Error", "Failed to clear forms");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> actionClearDatasources() async {
    const tag = "[OFFLINE_ACTION_CLEAR_DS_001]";

    final ok = await _confirm(
      title: "Clear Datasources",
      message: "This will delete all cached datasources. Continue?",
    );
    if (!ok) return;

    try {
      isLoading.value = true;

      await OfflineDbModule.clearDatasources();

      Get.snackbar("Done", "Datasources cleared");
      LogService.writeLog(message: "$tag[SUCCESS]");
    } catch (e, st) {
      LogService.writeLog(message: "$tag[FAILED] $e");
      LogService.writeLog(message: "$tag[STACK] $st");
      Get.snackbar("Error", "Failed to clear datasources");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> actionClearPending() async {
    const tag = "[OFFLINE_ACTION_CLEAR_PENDING_001]";

    final ok = await _confirm(
      title: "Clear Pending Queue",
      message: "This will delete all pending submissions. Continue?",
    );
    if (!ok) return;

    try {
      isLoading.value = true;

      await OfflineDbModule.clearPendingQueue();

      Get.snackbar("Done", "Pending queue cleared");
      LogService.writeLog(message: "$tag[SUCCESS]");
    } catch (e, st) {
      LogService.writeLog(message: "$tag[FAILED] $e");
      LogService.writeLog(message: "$tag[STACK] $st");
      Get.snackbar("Error", "Failed to clear pending queue");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> actionClearAll() async {
    const tag = "[OFFLINE_ACTION_CLEAR_ALL_001]";

    final ok = await _confirm(
      title: "Clear ALL Offline Data",
      message: "This will delete ALL offline data except user. Continue?",
      okText: "Yes, Delete",
    );
    if (!ok) return;

    try {
      isLoading.value = true;

      await OfflineDbModule.clearAllExceptUser();
      await getAllPages();
      // await loadOfflineDashboard();
      refreshPendingCount();
      Get.snackbar("Done", "All offline data cleared");
      LogService.writeLog(message: "$tag[SUCCESS]");
    } catch (e, st) {
      LogService.writeLog(message: "$tag[FAILED] $e");
      LogService.writeLog(message: "$tag[STACK] $st");
      Get.snackbar("Error", "Failed to clear all data");
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    String subtitle = '',
    String okText = "Yes",
    String cancelText = "Cancel",
    IconData icon = Icons.help_outline_rounded,
    Color confirmColor = const Color(0xFF2563EB),
    TextAlign? messageTextAlign,
    Color? highLightColor,
    Color? subtitleColor,
  }) async {
    bool result = false;

    Widget parseText(String text, TextStyle baseStyle, {TextAlign? align}) {
      if (!text.contains("**")) {
        return Text(
          text,
          textAlign: align ?? TextAlign.center,
          style: baseStyle,
        );
      }

      final parts = text.split("**");
      return Text.rich(
        TextSpan(
          children: parts.map((part) {
            final isBold = parts.indexOf(part) % 2 != 0;
            return TextSpan(
              text: part,
              style: isBold
                  ? baseStyle.copyWith(
                      fontWeight: FontWeight.bold,
                      color: highLightColor ?? Colors.grey[600],
                    )
                  : baseStyle,
            );
          }).toList(),
        ),
        textAlign: align ?? TextAlign.center,
      );
    }

    await Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: confirmColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: confirmColor),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              if (subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: parseText(
                    subtitle,
                    GoogleFonts.poppins(
                      fontSize: 14,
                      color: subtitleColor ?? Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              parseText(
                message,
                align: messageTextAlign,
                GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        result = false;
                        Get.back();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: Colors.grey[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Text(
                        cancelText,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        result = true;
                        Get.back();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        okText,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );

    return result;
  }

  Future<bool> _isInternetAvailable() async {
    try {
      final conn = Get.find<InternetConnectivity>();
      return await conn.check();
    } catch (_) {
      return false;
    }
  }

  void _showNeedInternetDialog() {
    Get.defaultDialog(
      title: "No Internet",
      middleText: "This action requires an internet connection.",
      textConfirm: "OK",
      onConfirm: Get.back,
    );
  }

  Future<void> actionPushPending() async {
    const tag = "[OFFLINE_ACTION_PUSH_PENDING]";

    if (!await _isInternetAvailable()) {
      _showNeedInternetDialog();
      return;
    }
    var pendingCount = await OfflineDbModule.getPendingCount();
    if (pendingCount == 0) {
      await _confirm(
        title: "No Pending Data",
        message:
            "There is no pending data available.\n\nYou can try saving new forms offline to use this feature",
        okText: "Okay",
        icon: Icons.indeterminate_check_box_outlined,
        confirmColor: const Color.fromARGB(255, 235, 103, 37),
      );
      return;
    }

    final ok = await _confirm(
      title: "Upload Pending Data",
      message:
          "This will upload $pendingCount locally saved records to the server.\n\nAre you sure you want to continue?",
      okText: "Upload Now",
      icon: Icons.cloud_upload_rounded,
      confirmColor: const Color(0xFF2563EB),
    );
    if (!ok) return;
    final progressModel = SyncProgressModel(initialTitle: "Uploading Data");
    Get.dialog(
      SyncProgressDialog(
        progressModel: progressModel,
        reTry: actionPushPending,
        showForcePush: true,
      ),
      barrierDismissible: false,
    );
    try {
      final resultMsg = await OfflineDbModule.processPendingQueue(
        isInternetAvailable: true,
        progress: progressModel,
      );
      log(resultMsg);
      // Get.back();

      // _showSimpleSuccessDialog(title: "Upload Complete", message: resultMsg);
      refreshPendingCount();
      // LogService.writeLog(message: "$tag[DONE] $resultMsg");
    } catch (e, st) {
      // Get.back(); // Ensure dialog closes
      LogService.writeLog(message: "$tag[FAILED] $e \n$st");
      refreshPendingCount();
      Get.snackbar(
        "Upload Error",
        "Failed to process queue. Check logs.",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        icon: const Icon(Icons.warning, color: Colors.white),
      );
    } finally {
      log("progress complete called here 4");
      isLoading.value = false;
      // progressModel.completeWithError(errorMsg: "errorMsg");
    }
  }

  Future<void> onForcePushClicked(SyncProgressModel model) async {
    final isOnline = await Get.find<InternetConnectivity>().check();
    final bool ok = await _confirm(
      title: "Confirm Force Push",
      subtitle:
          "**This action will upload failed records to the server log and delete them permanently from this device**.",
      message:
          "**Important Notes:**"
          "• You can only access this data via the **Web Instance**."
          "• Successfully forced records **cannot be retried** for normal syncing.\n\n"
          "**Are you sure you want to proceed?**",
      okText: "Yes, Force Push",
      confirmColor: Colors.redAccent,
      icon: Icons.warning_amber_rounded,
    );

    if (!ok) return;
    await OfflineDbModule.forcePushFailedRecords(
      isInternetAvailable: isOnline,
      progress: model,
    );
  }

  // Open a picker; refresh work stays in the existing parameterized action.
  Future<void> actionRefresh() async {
    final forms = allPages.where((page) => page.pageType == 'form').toList();
    final selected = await Get.dialog<String>(
      RefreshSelectionDialog(forms: forms),
      barrierColor: Colors.black.withValues(alpha: 0.45),
    );
    if (selected == null) return;
    if (selected.isEmpty) {
      await actionSyncAll();
    } else {
      final page = forms.firstWhere((page) => page.transId == selected);
      await actionSyncAll(transId: page.transId, caption: page.caption);
    }
  }

  Future<void> actionSyncAll({String? transId, String? caption}) async {
    const tag = "[OFFLINE_ACTION_SYNC_ALL]";
    final notifications = await OfflineNotifications.beginUpdate();
    final refreshCaption = transId == null ? 'Refresh All' : caption ?? transId;
    OfflineRefreshReport? refreshReport;
    OfflineRefreshReport reportForPages(
      List<Map<String, dynamic>> pages, {
      required bool downloaded,
    }) => OfflineRefreshReport(
      pages
          .where((page) => (page['page_type'] ?? 'form') == 'form')
          .map(
            (page) => OfflineRefreshFormResult(
              transId: page['transid']?.toString() ?? '',
              caption:
                  page['caption']?.toString() ??
                  page['transid']?.toString() ??
                  'Offline form',
              formUpdated: downloaded,
            ),
          )
          .toList(),
    );
    OfflineRefreshFormResult? formResult(String formId) {
      for (final form in refreshReport?.forms ?? <OfflineRefreshFormResult>[]) {
        if (form.transId == formId) return form;
      }
      return null;
    }

    void recordFormDownloadFailure() {
      for (final form in refreshReport?.forms ?? <OfflineRefreshFormResult>[]) {
        if (!form.formUpdated) {
          form.formError =
              '${form.caption} could not be downloaded. Please try refreshing this form again.';
        }
      }
    }

    Future<void> notice(
      String event,
      String type,
      String title,
      String message, {
      int updated = 0,
      int failed = 0,
    }) async {
      await notifications?.notify(
        event: event,
        type: type,
        title: title,
        message: message,
        caption: refreshCaption,
        transId: transId ?? '',
        successCount: updated,
        failedCount: failed,
        refreshReport: refreshReport,
      );
    }

    if (!await _isInternetAvailable()) {
      await notice(
        'start',
        'refresh_error',
        'Refresh could not start',
        'No internet connection. Connect to the internet and try Refresh again.',
      );
      _showNeedInternetDialog();
      return;
    }

    final ok = await _confirm(
      title: transId == null ? "Full Sync" : "Refresh $caption",
      message: transId == null
          ? "This will sync pending uploads, forms, and datasources.\n\nContinue?"
          : "Update this form and its lookup data?",
      okText: transId == null ? "Start Sync" : "Refresh",
    );
    if (!ok) return;

    // Coordinate selected refresh with background sync without blocking forms.
    final owner = 'form-refresh-${DateTime.now().microsecondsSinceEpoch}';
    bool lockAcquired = false;
    if (transId != null) {
      lockAcquired = await OfflineDbModule.tryAcquireCachedSaveLock(
        owner: owner,
      );
      if (!lockAcquired) {
        await notice(
          'start',
          'refresh_error',
          'Refresh is temporarily unavailable',
          'Another sync is running. Please try refreshing $refreshCaption again when it finishes.',
        );
        Get.snackbar(
          'Sync Busy',
          'Another sync is running. Please try again shortly.',
        );
        return;
      }
    }
    final progressModel = SyncProgressModel(
      initialTitle: transId == null ? "Full Sync" : "Refreshing $caption",
    );
    var stage = 'initializing';
    var lookupFailures = 0;

    try {
      progressModel.init(
        // Upload (Refresh All only) and form download are known up front.
        // Each actual per-form bulk lookup request adds another operation.
        total: transId == null ? 2 : 1,
        msg: "Initializing...",
      );
      Get.dialog(
        SyncProgressDialog(progressModel: progressModel),
        barrierDismissible: false,
      );
      // Both refresh paths must validate before uploading or changing the cache.
      {
        progressModel.updateMessage('Checking your session...');
        if (!await OfflineDbModule.ensureValidSession()) {
          await notice(
            'session',
            'refresh_error',
            'Sign in to refresh offline data',
            'Your session could not be renewed. Sign in again, then try Refresh. Your cached data has been kept.',
          );
          progressModel.increment(isSuccess: false);
          progressModel.isSessionError.value = true;
          progressModel.completeWithError(
            errorMsg:
                'Your session could not be renewed. Please log in again '
                'and retry refreshing ${caption ?? 'offline data'}. '
                'Your cached data has been kept.',
            statuscode: 'SESSION_INVALID',
          );
          return;
        }
      }
      progressModel.updateMessage(
        transId == null
            ? "Uploading pending data..."
            : "Preparing to refresh $caption...",
      );

      final uploadProgress = SyncProgressModel();
      stage = 'uploads';
      final pushResult = transId == null
          ? await OfflineDbModule.processPendingQueue(
              isInternetAvailable: true,
              progress: uploadProgress,
            )
          : 'Not requested';
      LogService.writeLog(message: "$tag[STEP_1] $pushResult");
      // Pending uploads remain one operation, with record counts in details.
      if (transId == null) {
        progressModel.increment(
          isSuccess:
              uploadProgress.failureCount.value == 0 &&
              !uploadProgress.isCompletedWithError.value,
        );
      }
      progressModel.updateMessage(
        transId == null
            ? "Checking for new forms..."
            : "Refreshing $caption...",
      );
      stage = 'forms';
      // Read the existing form names only for a failed-download report. The
      // server's returned list remains authoritative on a successful download.
      try {
        final cachedPages = await OfflineDbModule.getOfflinePages();
        refreshReport = reportForPages(
          cachedPages
              .where((page) => transId == null || page['transid'] == transId)
              .toList(),
          downloaded: false,
        );
      } catch (e) {
        LogService.writeLog(
          message: '$tag Could not collect notification form names: $e',
        );
      }
      if (transId != null && (refreshReport?.forms.isEmpty ?? true)) {
        refreshReport = OfflineRefreshReport([
          OfflineRefreshFormResult(transId: transId, caption: refreshCaption),
        ]);
      }
      final pages = await OfflineDbModule.fetchAndStoreOfflinePages(
        transId: transId,
      );
      if (pages.isEmpty) {
        recordFormDownloadFailure();
        await notice(
          'forms',
          'refresh_error',
          transId == null
              ? 'Offline forms could not be downloaded'
              : '$refreshCaption could not be downloaded',
          'The requested offline forms could not be downloaded. Please try Refresh again.',
        );
        progressModel.increment(isSuccess: false);
        progressModel.completeWithError(
          errorMsg: 'Could not download the requested offline forms.',
          statuscode: 'FORM_REFRESH_FAILED',
        );
        return;
      }
      refreshReport = reportForPages(pages, downloaded: true);
      stage = 'form-list';
      if (transId == null) {
        await getAllPages(); // Preserve existing full-sync loading behavior.
      } else {
        // Update list models without changing the form-loading state.
        allRawPages = await OfflineDbModule.getOfflinePages();
        allPages.value = allRawPages
            .map((page) => OfflineFormPageModel.fromJson(page))
            .where((page) => page.visible)
            .toList();
      }
      LogService.writeLog(
        message: "$tag[STEP_2] Fetched ${pages.length} forms",
      );
      progressModel.increment();
      progressModel.updateMessage("Updating lookup data...");
      final lookupProgress = SyncProgressModel();
      stage = 'lookups';
      await OfflineDbModule.refreshAllDatasourcesFromDownloadedPages(
        isrefetching: true,
        transId: transId,
        progressModel: lookupProgress,
        operationProgress: progressModel,
        onLookupFailure: (formId, datasource, error) async {
          lookupFailures++;
          final matches = pages.where((page) => page['transid'] == formId);
          final form = matches.isEmpty ? <String, dynamic>{} : matches.first;
          final formCaption = form['caption']?.toString() ?? formId;
          final lookupCaption = offlineLookupCaption(form, datasource);
          LogService.writeLog(
            message:
                '$tag Lookup failure form=$formId datasource=$datasource: $error',
          );
          // Keep each exact error in this refresh's report, not in a
          // separate notification. Submission-error notifications are untouched.
          final result = formResult(formId);
          if (result != null &&
              !result.lookupErrors.any(
                (item) => item.datasource == datasource,
              )) {
            result.lookupErrors.add(
              OfflineLookupError(
                datasource: datasource,
                caption: lookupCaption,
                message: friendlyLookupFailure(
                  lookup: lookupCaption,
                  form: formCaption,
                  error: error,
                  preserveOriginal: true,
                ),
              ),
            );
          }
        },
        onFormLookupResult: (formId, updated, failed) async {
          final result = formResult(formId);
          if (result == null) return;
          result.lookupsCompleted = true;
          result.updatedLookups = updated;
          result.failedLookups = max(failed, result.lookupErrors.length);
        },
      );
      LogService.writeLog(
        message:
            "$tag[STEP_3] Lookups: "
            '${lookupProgress.successCount.value} success, '
            '${lookupProgress.failureCount.value} failed',
      );
      refreshPendingCount();
      final summary =
          'Forms updated: ${pages.length}\n'
          'Lookup data: ${lookupProgress.successCount.value} updated, '
          '${lookupProgress.failureCount.value} failed'
          '${transId == null ? '\nUploads: $pushResult' : ''}';
      if (progressModel.failureCount.value > 0) {
        progressModel.completeWithError(
          errorMsg: summary,
          statuscode: 'REFRESH_INCOMPLETE',
        );
        progressModel.title.value = 'Refresh completed with failures';
      } else {
        progressModel.complete();
        progressModel.updateMessage(summary);
      }
      final failedLookups = max(
        lookupFailures,
        lookupProgress.failureCount.value,
      );
      final uploadFailed =
          uploadProgress.failureCount.value > 0 ||
          uploadProgress.isCompletedWithError.value;
      final completeSuccess =
          progressModel.failureCount.value == 0 && failedLookups == 0;
      final updatedFormCount = refreshReport?.updatedForms ?? pages.length;
      await notice(
        'summary',
        completeSuccess ? 'refresh_success' : 'refresh_warning',
        completeSuccess
            ? transId == null
                  ? 'All offline forms refreshed'
                  : '$refreshCaption refreshed'
            : 'Refresh completed with issues',
        '$updatedFormCount ${updatedFormCount == 1 ? 'form' : 'forms'} updated. '
            '${lookupProgress.successCount.value} ${lookupProgress.successCount.value == 1 ? 'lookup' : 'lookups'} updated'
            '${failedLookups == 0 ? '.' : '; $failedLookups failed.'}'
            '${uploadFailed ? ' Some pending records could not be sent. Check submission status before trying again.' : ''}',
        updated: lookupProgress.successCount.value,
        failed: failedLookups,
      );
    } catch (e, st) {
      if (stage == 'forms') recordFormDownloadFailure();
      await notice(
        stage,
        'refresh_error',
        stage == 'forms'
            ? transId == null
                  ? 'Offline forms could not be downloaded'
                  : '$refreshCaption could not be downloaded'
            : 'Refresh could not be completed',
        'We couldn’t finish refreshing offline data. Please try Refresh again.',
      );
      progressModel.increment(isSuccess: false);
      progressModel.completeWithError(
        errorMsg:
            'Could not finish refreshing ${caption ?? 'offline data'}: $e',
        statuscode: 'REFRESH_FAILED',
      );
      LogService.writeLog(message: "$tag[FAILED] $e");
      LogService.writeLog(message: "$tag[STACK] $st");

      Get.snackbar(
        "Sync Failed",
        "Something went wrong. Please check logs.",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        icon: const Icon(Icons.error, color: Colors.white),
      );
    } finally {
      if (lockAcquired) {
        await OfflineDbModule.releaseCachedSaveLock(owner: owner);
      }
      if (transId == null) isLoading.value = false;
    }
  }

  Future<void> actionRefetchDatasources() async {
    if (!await _isInternetAvailable()) {
      _showNeedInternetDialog();
      return;
    }

    final ok = await _confirm(
      title: "Refetch Datasources",
      message:
          "This will re-download lookup data for all downloaded forms. Continue?",
    );
    if (!ok) return;

    try {
      isLoading.value = true;

      SyncProgressModel progressModel = SyncProgressModel(
        initialTitle: "Refetching Datasources",
      );
      // Open the dialog immediately
      Get.dialog(
        SyncProgressDialog(
          progressModel: progressModel,
          reTry: actionRefetchDatasources,
        ),
        barrierDismissible: false,
      );

      await OfflineDbModule.refreshAllDatasourcesFromDownloadedPages(
        progressModel: progressModel,
        isrefetching: true,
      );

      progressModel.complete();
    } catch (e) {
      Get.snackbar("Error", "Failed to update datasources");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> onReportCardClick(String transId) async {
    WebViewController webViewController = Get.find();
    var urlNew =
        "aspx/AxMain.aspx?authKey=AXPERT-${StorageService.sessionId}&pname=$transId";
    webViewController.openWebView(url: await AppConst.getFullWebUrl(urlNew));
  }

  Future<void> saveAudit({
    required String action,
    bool isError = false,
    String? response,
    String? remarks,
  }) async {
    await OfflineDbModule.logAudit(
      action: action,
      isError: isError,
      response: response,
      remarks: remarks,
    );
  }

  Future<void> actionExportDatabaseOld() async {
    try {
      isLoading.value = true;
      final bundle = await OfflineBundleService.createExportBundle();

      if (bundle == null) return;

      Get.dialog(
        AlertDialog(
          title: const Text("Export Database"),
          content: const Text(
            "Choose an action for your secure offline bundle.",
          ),
          actions: [
            TextButton(
              child: const Text("Share"),
              onPressed: () {
                Get.back();
                _handleShare(bundle.path);
              },
            ),
            TextButton(
              child: const Text("Download"),
              onPressed: () {
                Get.back();
                _handleDownload(bundle.path);
              },
            ),
          ],
        ),
      );
    } catch (e) {
      Get.snackbar("Export Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> actionExportDatabase() async {
    final String? choice = await _showExportChoiceDialog();
    if (choice == null) return;
    final notifications = await OfflineNotifications.beginUpdate();

    try {
      isLoading.value = true;

      if (choice == "full") {
        Get.showSnackbar(
          GetSnackBar(
            icon: CupertinoActivityIndicator(color: Colors.white),
            title: "Please Wait",
            message: "Packaging DB and underscore-pathed assets...",
            backgroundColor: AppColors.blue10,
            isDismissible: false,
          ),
        );
        final File? bundle = await OfflineBundleService.createExportBundle();
        Get.back();
        if (bundle == null) {
          await notifications?.exportResult(success: false);
          Get.snackbar("Export Failed", "Could not create export bundle.");
          return;
        }
        Get.dialog(
          AlertDialog(
            title: const Text("Export Database"),
            content: const Text(
              "Choose an action for your secure offline bundle.",
            ),
            actions: [
              TextButton(
                child: const Text("Share"),
                onPressed: () {
                  Get.back();
                  _handleShare(bundle.path, notifications: notifications);
                },
              ),
              TextButton(
                child: const Text("Download"),
                onPressed: () {
                  Get.back();
                  _handleDownload(bundle.path, notifications: notifications);
                },
              ),
            ],
          ),
        );
        await OfflineDbModule.logAudit(
          action: "bundleAction",
          remarks: "User exported full bundle with images.",
        );
      } else if (choice == "db_only") {
        try {
          await OfflineBundleService.uploadDBFile();
          Get.snackbar(
            "Upload Successful",
            "DB file uploaded to server.",
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        } catch (e) {
          await notifications?.exportResult(
            success: false,
            error: e.toString(),
          );
          Get.snackbar(
            "Upload Failed",
            e.toString(),
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }

        // await OfflineDbModule.logAudit(
        //   action: "bundleAction",
        //   remarks: "User exported DB file only.",
        // );
      }
    } catch (e) {
      await notifications?.exportResult(success: false, error: e.toString());
      Get.snackbar("Export Failed", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<String?> _showExportChoiceDialog() async {
    String? result;

    await Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.upload_rounded,
                  size: 30,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                "Export Data",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),

              Text(
                "Choose what to export",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 6),
              _bulletPoint(
                "Full Bundle — includes DB + all attached images (.axbundle).",
              ),
              _bulletPoint(
                "DB Only — exports just the database file (.db). No images included.",
              ),
              const SizedBox(height: 24),

              // Cancel
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    result = null;
                    Get.back();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: Colors.grey[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Text(
                    "CANCEL",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Full bundle
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.folder_zip_rounded),
                  label: Text(
                    "EXPORT FULL BUNDLE",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    result = "full";
                    Get.back();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // DB only
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.storage_rounded),
                  label: Text(
                    "EXPORT DB ONLY",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    result = "db_only";
                    Get.back();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );

    return result;
  }

  Future<void> _handleShare(
    String path, {
    OfflineUpdateNotificationRun? notifications,
  }) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], text: 'Secure Offline Bundle'),
      );
      await _logAudit();
      if (result.status != ShareResultStatus.dismissed) {
        await notifications?.exportResult(
          success: true,
          filePath: path,
          shared: true,
          confirmed: result.status == ShareResultStatus.success,
        );
      }
    } catch (e) {
      await notifications?.exportResult(success: false, error: e.toString());
      if (notifications == null)
        rethrow; // Preserve legacy callers' error behavior.
      Get.snackbar(
        'Export Failed',
        'Could not share your offline backup. Please try again.',
      );
    }
  }

  Future<void> _handleDownload1(String sourcePath) async {
    try {
      File sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw Exception('Bundle file not found at $sourcePath');
      }

      String fileName = sourcePath.split('/').last;
      Uint8List fileBytes = await sourceFile.readAsBytes();

      final String? targetPath = await FilePicker.saveFile(
        dialogTitle: 'Save Bundle to Downloads',
        fileName: fileName,
        bytes: fileBytes,
      );

      if (targetPath != null) {
        Get.snackbar(
          "File Saved",
          "Bundle saved successfully",
          colorText: Colors.white,
          backgroundColor: AppColors.green,
        );
        await _logAudit();
      }
    } catch (e) {
      log(e.toString(), name: "DOWNLOAD BUNDLE");
      Get.snackbar(
        "Download Error",
        e.toString(),
        colorText: Colors.white,
        backgroundColor: AppColors.maroon,
      );
    }
  }

  static const _mediaScanner = MethodChannel(
    'com.agile.ub_bottleapp/media_scanner',
  );

  Future<void> _handleDownload(
    String filePath, {
    OfflineUpdateNotificationRun? notifications,
  }) async {
    try {
      final fileName = basename(filePath);

      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final destPath = join(downloadsDir.path, fileName);
      await File(filePath).copy(destPath);

      await _mediaScanner.invokeMethod('scanFile', {'path': destPath});
      await notifications?.exportResult(success: true, filePath: destPath);

      Get.snackbar(
        "Downloaded",
        "Saved to Downloads/$fileName",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      await notifications?.exportResult(success: false, error: e.toString());
      Get.snackbar("Download Failed", e.toString());
    }
  }

  Future<void> _logAudit() async {
    await OfflineDbModule.logAudit(
      action: "DB_BUNDLE_EXPORT",
      remarks: "Bundled DB and images.",
    );
  }

  // actionImportDatabase1() async {
  //   FilePickerResult? result = await FilePicker.platform.pickFiles(
  //     type: FileType.custom,
  //     allowedExtensions: ['db'],
  //   );
  //   if (result == null || result.files.single.path == null) return;

  //   File dbFile = File(result.files.single.path!);
  //   await DatabaseHelper.instance.replaceDatabase(dbFile);
  // }

  Future<void> actionImportDatabaseOld() async {
    try {
      final bool backupExists = await OfflineBundleService.hasBackup();

      if (backupExists) {
        final meta = await OfflineBundleService.getBackupMeta();
        final String backupInfo = meta != null
            ? "Made on ${meta['displayTime']} by ${meta['user']}"
            : "A previous backup is available.";

        final String? choice = await _showBackupChoiceDialog(backupInfo);

        if (choice == null) return;

        if (choice == "restore") {
          final bool ok = await _confirm(
            title: "Restore Previous Backup",
            subtitle: backupInfo,
            message:
                "**CAUTION:** This will replace your current data with the backup. Proceed?",
            icon: Icons.history_rounded,
            confirmColor: Colors.orange,
            okText: "RESTORE BACKUP",
            cancelText: "CANCEL",
          );
          if (ok == true) {
            await _executeRestore();
          }
          return;
        }
      }

      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['axbundle', 'zip'],
      );
      if (result == null || result.files.single.path == null) return;

      File bundleFile = File(result.files.single.path!);
      String fileName = basename(bundleFile.path);

      final bool ok = await _confirm(
        title: "Import Data Bundle",
        subtitle: "Selected: $fileName",
        message:
            "**CAUTION:** This will permanently **DELETE** your current local data and logs. "
            "Your current data will be auto-backed up first. "
            "You must login with the **SAME credentials** to use this data. Proceed?",
        icon: Icons.settings_backup_restore_rounded,
        confirmColor: Colors.redAccent,
        okText: "IMPORT NOW",
        cancelText: "KEEP CURRENT",
      );

      if (ok == true) {
        await _executeImport(bundleFile);
      }
    } catch (e) {
      Get.snackbar("Error", "Could not process bundle: $e");
    }
  }

  Future<void> actionImportDatabase() async {
    try {
      final bool backupExists = await OfflineBundleService.hasBackup();

      if (backupExists) {
        final meta = await OfflineBundleService.getBackupMeta();
        final String backupInfo = meta != null
            ? "Made on ${meta['displayTime']} by ${meta['user']}"
            : "A previous backup is available.";

        final String? choice = await _showBackupChoiceDialog(backupInfo);

        if (choice == null) return;

        if (choice == "restore") {
          final bool ok = await _confirm(
            title: "Restore Previous Backup",
            subtitle: backupInfo,
            message:
                "**CAUTION:** This will replace your current data with the backup. Proceed?",
            icon: Icons.history_rounded,
            confirmColor: Colors.orange,
            okText: "RESTORE BACKUP",
            cancelText: "CANCEL",
          );
          if (ok == true) {
            await _executeRestore();
          }
          return;
        }
      }

      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['axbundle', 'zip', 'db'], // 👈 added 'db'
      );
      if (result == null || result.files.single.path == null) return;

      File bundleFile = File(result.files.single.path!);
      String fileName = basename(bundleFile.path);
      final bool isDbOnly = fileName.toLowerCase().endsWith(
        '.db',
      ); // 👈 detect .db

      final bool ok = await _confirm(
        title: isDbOnly ? "Import DB File" : "Import Data Bundle",
        subtitle: "Selected: $fileName",
        message: isDbOnly
            ? "**CAUTION:** This will permanently replace your current database. "
                  "Your current data will be auto-backed up first. Proceed?"
            : "**CAUTION:** This will permanently **DELETE** your current local data and logs. "
                  "Your current data will be auto-backed up first. "
                  "You must login with the **SAME credentials** to use this data. Proceed?",
        icon: Icons.settings_backup_restore_rounded,
        confirmColor: Colors.redAccent,
        okText: "IMPORT NOW",
        cancelText: "KEEP CURRENT",
      );
      Get.showSnackbar(
        GetSnackBar(
          icon: CupertinoActivityIndicator(color: Colors.white),
          title: "Please Wait",
          message: "Unpacking DB and other details",
          backgroundColor: AppColors.blue10,
          isDismissible: false,
        ),
      );
      if (ok == true) {
        if (isDbOnly) {
          await _executeDbOnlyImport(bundleFile);
        } else {
          await _executeImport(bundleFile);
        }
      }
      Get.back();
    } catch (e) {
      Get.snackbar("Error", "Could not process file: $e");
    }
  }

  Future<void> _executeDbOnlyImport(File file) async {
    try {
      isLoading.value = true;

      debugPrint("[IMPORT_DB_ONLY] Backing up current DB before import...");
      await OfflineBundleService.backupCurrentDatabase();

      await OfflineBundleService.importDbOnly(file);
      await getAllPages();
      await refreshPendingCount();
      await OfflineDbModule.logAudit(
        action: "DB_IMPORT_DB_ONLY",
        remarks: "User imported a raw .db file directly.",
      );
      _confirm(
        title: "Success",
        message:
            "Database replaced successfully. A backup of your previous data was saved automatically. "
            "Please ensure you are logged in as the correct user.",
        okText: "Done",
      );
    } catch (e) {
      Get.snackbar("Import Failed", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<String?> _showBackupChoiceDialog(String backupInfo) async {
    String? result;

    await Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon Circle ──────────────────────────────────────────────
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 30,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 20),

              // ── Title ────────────────────────────────────────────────────
              Text(
                "Previous Backup Found",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),

              // ── Backup Info Subtitle ─────────────────────────────────────
              Text(
                backupInfo,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.orange[700],
                ),
              ),
              const SizedBox(height: 16),

              // ── Body Message ─────────────────────────────────────────────
              Text(
                "What would you like to do?",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              _bulletPoint(
                "Restore Backup — rolls back to the snapshot taken before your last import.",
              ),
              _bulletPoint(
                "Import New File — pick a new .axbundle (your current data will be backed up first).",
              ),
              const SizedBox(height: 24),

              // ── Cancel ───────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    result = null;
                    Get.back();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: Colors.grey[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Text(
                    "CANCEL",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Restore Backup ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.history_rounded),
                  label: Text(
                    "RESTORE BACKUP",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    result = "restore";
                    Get.back();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Import New ───────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.folder_open_rounded),
                  label: Text(
                    "IMPORT NEW FILE",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    result = "import_new";
                    Get.back();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );

    return result;
  }

  Future<void> _executeRestore() async {
    try {
      isLoading.value = true;
      await OfflineBundleService.restoreBackup();
      await OfflineDbModule.init();
      await getAllPages();
      await refreshPendingCount();
      await OfflineBundleService.deleteBackup();
      await OfflineDbModule.logAudit(
        action: "DB_BACKUP_RESTORE",
        remarks: "User restored the pre-import backup.",
      );
      _confirm(
        title: "Backup Restored",
        message:
            "Your previous data has been restored successfully. Please ensure you are logged in as the correct user.",
        okText: "Done",
      );
    } catch (e) {
      Get.snackbar("Restore Failed", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _executeImport(File file) async {
    try {
      isLoading.value = true;

      debugPrint("[IMPORT] Backing up current DB before import...");
      await OfflineBundleService.backupCurrentDatabase();

      await OfflineBundleService.importBundleNew(file);
      await OfflineDbModule.init();
      await getAllPages();
      await refreshPendingCount();
      await OfflineDbModule.logAudit(
        action: "DB_IMPORT_SUCCESS",
        remarks: "User successfully imported and remapped a bundle.",
      );
      _confirm(
        title: "Success",
        message:
            "Database restored and remapped successfully. A backup of your previous data was saved automatically. "
            "Please ensure you are logged in as the correct user.",
        okText: "Done",
      );
    } catch (e) {
      Get.snackbar("Import Failed", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  ////////////////////////////////////////////////////////
  //////////////CACHED_SAVE//////////////////////
  ////////////////////////////////////////////////////////

  Future<bool> validateSession() async {
    try {
      final Map<String, dynamic> payload = {
        "ARMSessionId": StorageService.sessionId ?? '',
      };
      var url = await AppConst.getFullARMUrl(ApiEndpoints.API_VALIDATE_SESSION);
      log(payload.toString(), name: "validateSession");
      log(url, name: "validateSession");

      final dynamic res = await ApiManager.instance.postDsToServer(
        strictAuth: false,
        url: url,
        body: jsonEncode(payload),
        isBearer: true,
        show_errorSnackbar: false,
      );
      await Future.delayed(Duration(seconds: 2));
      bool isSuccess = false;
      if (res != null && res.isNotEmpty) {
        log(res.toString(), name: "validateSession");
        final decoded = jsonDecode(res);
        if (decoded is Map && decoded['result']['success'] == true) {
          isSuccess = true;
        }
      }
      return isSuccess;
    } catch (e) {
      return false;
    }
  }

  // Previous manual sync implementations: retained for comparison.
  //   Future<void> actionRefreshQueues() async {
  //     const tag = "[OFFLINE_ACTION_REFRESH_PENDING]";
  //     if (!await _isInternetAvailable()) {
  //       _showNeedInternetDialog();
  //       return;
  //     }
  //
  //     var rows = await OfflineDbModule.getPendigQueuesToRefresh();
  //
  //     if (rows.isEmpty) {
  //       await _confirm(
  //         title: "No Pending Queues",
  //         message:
  //             "There is no pending Queues available.\n\nYou can try uploading new Queues to use this feature",
  //         okText: "Okay",
  //         icon: Icons.indeterminate_check_box_outlined,
  //         confirmColor: const Color.fromARGB(255, 235, 103, 37),
  //       );
  //       return;
  //     }
  //     final ok = await _confirm(
  //       title: "Refresh Pending Queues",
  //       message:
  //           "This will refresh ${rows.length} pendind queues from the server.\n\nAre you sure you want to continue?",
  //       okText: "Refresh Now",
  //       icon: Icons.cloud_upload_rounded,
  //       confirmColor: const Color(0xFF2563EB),
  //     );
  //
  //     if (!ok) return;
  //
  //     try {
  //       final sessionResult = await Get.dialog<CachedSessionValidationResult>(
  //         PopScope(canPop: false, child: const CachedSessionValidationDialog()),
  //         barrierDismissible: false,
  //       );
  //
  //       if (sessionResult != CachedSessionValidationResult.valid) {
  //         final login = await _confirm(
  //           title: "Invalid Session",
  //           message:
  //               "Your session has expired. Log back in to sync your pending data and access your forms.",
  //           okText: "Okay",
  //           icon: Icons.indeterminate_check_box_outlined,
  //           confirmColor: const Color.fromARGB(255, 235, 103, 37),
  //         );
  //
  //         cachedSaveUpdateMessage.value = "Invalid Session";
  //
  //         if (login) {
  //           Get.offAllNamed(Routes.LOGIN);
  //         }
  //
  //         return;
  //       }
  //
  //       final refreshResult = await Get.dialog<CachedRefreshResult>(
  //         CachedRefreshDialogWidget(refreshQueueRows: rows),
  //         barrierDismissible: false,
  //       );
  //
  //       if (refreshResult != CachedRefreshResult.refreshed) {
  //         return;
  //       }
  //     } finally {
  //       refreshPendingCount();
  //     }
  //   }
  //
  //   Future<void> actionPushPendingByCachedSave() async {
  //     const tag = "[OFFLINE_ACTION_PUSH_PENDING_BY_CACHED_SAVE]";
  //
  //     if (!await _isInternetAvailable()) {
  //       _showNeedInternetDialog();
  //       return;
  //     }
  //
  //     final pendingCount = await OfflineDbModule.getPendingCount();
  //
  //     if (pendingCount == 0) {
  //       await _confirm(
  //         title: "No Pending Data",
  //         message:
  //             "There is no pending data available.\n\nYou can try saving new forms offline to use this feature",
  //         okText: "Okay",
  //         icon: Icons.indeterminate_check_box_outlined,
  //         confirmColor: const Color.fromARGB(255, 235, 103, 37),
  //       );
  //       return;
  //     }
  //
  //     final ok = await _confirm(
  //       title: "Upload Pending Data",
  //       message:
  //           "This will upload $pendingCount locally saved records to the server.\n\nAre you sure you want to continue?",
  //       okText: "Upload Now",
  //       icon: Icons.cloud_upload_rounded,
  //       confirmColor: const Color(0xFF2563EB),
  //     );
  //
  //     if (!ok) return;
  //
  //     cachedSaveUpdateMessage.value = "Starting Process";
  //     isCachedSaveActive.value = true;
  //
  //     try {
  //       /// ----------------------------------------------------------
  //       /// STEP 1 : Validate Session
  //       /// ----------------------------------------------------------
  //       final sessionResult = await Get.dialog<CachedSessionValidationResult>(
  //         PopScope(canPop: false, child: const CachedSessionValidationDialog()),
  //         barrierDismissible: false,
  //       );
  //
  //       if (sessionResult != CachedSessionValidationResult.valid) {
  //         final login = await _confirm(
  //           title: "Invalid Session",
  //           message:
  //               "Your session has expired. Log back in to sync your pending data and access your forms.",
  //           okText: "Okay",
  //           icon: Icons.indeterminate_check_box_outlined,
  //           confirmColor: const Color.fromARGB(255, 235, 103, 37),
  //         );
  //
  //         cachedSaveUpdateMessage.value = "Invalid Session";
  //
  //         if (login) {
  //           Get.offAllNamed(Routes.LOGIN);
  //         }
  //
  //         return;
  //       }
  //
  //       /// ----------------------------------------------------------
  //       /// STEP 2 : Check Pending Queue Refresh Count
  //       /// ----------------------------------------------------------
  //       final refreshQueueRows = await OfflineDbModule.getPendigQueuesToRefresh();
  //
  //       /// ----------------------------------------------------------
  //       /// STEP 3 : Refresh Queue (only if required)
  //       /// ----------------------------------------------------------
  //       if (refreshQueueRows.isNotEmpty) {
  //         final refreshResult = await Get.dialog<CachedRefreshResult>(
  //           CachedRefreshDialogWidget(refreshQueueRows: refreshQueueRows),
  //           barrierDismissible: false,
  //         );
  //
  //         if (refreshResult != CachedRefreshResult.refreshed) {
  //           return;
  //         }
  //
  //         var newPendingCount = await OfflineDbModule.getPendingCount();
  //         if (newPendingCount == 0) {
  //           await Get.dialog(AllRecordsDoneDialog());
  //           return;
  //         }
  //       }
  //
  //       /// ----------------------------------------------------------
  //       /// STEP 4 : Upload Pending Data
  //       /// ----------------------------------------------------------
  //       cachedSaveUpdateMessage.value = "Uploading Pending Data";
  //
  //       Get.dialog(CachedSaveDialogWidget(), barrierDismissible: false);
  //
  //       await OfflineDbModule.startCachedSave(
  //         controller: Get.find<OfflineFormController>(),
  //       );
  //     } catch (e, st) {
  //       LogService.writeLog(message: "$tag [FAILED]\n$e\n$st");
  //
  //       Get.snackbar(
  //         "Upload Error",
  //         "Failed to process queue. Check logs.",
  //         backgroundColor: Colors.redAccent,
  //         colorText: Colors.white,
  //         icon: const Icon(Icons.warning, color: Colors.white),
  //       );
  //     } finally {
  //       isCachedSaveActive.value = false;
  //       isLoading.value = false;
  //       refreshPendingCount();
  //     }
  //   }

  Future<void> actionRefreshQueues() async {
    const tag = "[OFFLINE_ACTION_REFRESH_PENDING]";

    // 1. Require internet before contacting the server.
    if (!await _isInternetAvailable()) {
      _showNeedInternetDialog();
      return;
    }

    // 2. Check whether there are queues available to refresh.
    // Count/display form submissions only; the refresh button's resolver
    // still processes both form and audit queues using its existing query.
    final rows = formSubmissionQueues(
      await OfflineDbModule.getPendigQueuesToRefresh(),
    );
    if (rows.isEmpty) {
      await _confirm(
        title: "No Pending Queues",
        message: "There are no pending queues to refresh.",
        okText: "Okay",
        icon: Icons.indeterminate_check_box_outlined,
        confirmColor: const Color.fromARGB(255, 235, 103, 37),
      );
      return;
    }

    // 3. Confirm the refresh without holding the sync lock.
    final ok = await _confirm(
      title: "Refresh Pending Queues",
      message:
          "This will refresh ${rows.length} pending queues from the server.\n\n"
          "Are you sure you want to continue?",
      okText: "Refresh Now",
      icon: Icons.cloud_upload_rounded,
      confirmColor: const Color(0xFF2563EB),
    );
    if (!ok) return;

    // 4. Identify this run so it can release only its own lock.
    final owner = 'manual-refresh-${DateTime.now().microsecondsSinceEpoch}';
    bool lockAcquired = false;

    try {
      // 5. Coordinate with background sync using its existing logical lock.
      // No database transaction is held open during network operations.
      // Offline form opening and saving do not acquire this lock.
      lockAcquired = await OfflineDbModule.tryAcquireCachedSaveLock(
        owner: owner,
      );

      // 6. Leave an existing sync running if the lock is unavailable.
      if (!lockAcquired) {
        Get.snackbar(
          "Sync Busy",
          "Another sync is already running. Please try again shortly.",
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // 7. Validate the session before fetching server queue results.
      final sessionResult = await Get.dialog<CachedSessionValidationResult>(
        PopScope(canPop: false, child: const CachedSessionValidationDialog()),
        barrierDismissible: false,
      );

      // 8. Offer login if the session is invalid.
      if (sessionResult != CachedSessionValidationResult.valid) {
        final login = await _confirm(
          title: "Invalid Session",
          message:
              "Your session has expired. Log back in to sync your pending "
              "data and access your forms.",
          okText: "Okay",
          icon: Icons.indeterminate_check_box_outlined,
          confirmColor: const Color.fromARGB(255, 235, 103, 37),
        );
        cachedSaveUpdateMessage.value = "Invalid Session";
        if (login) Get.offAllNamed(Routes.LOGIN);
        return;
      }

      // 9. Reload queues under the lock; background sync may have resolved
      // the original list while the user was confirming this action.
      final currentRows = formSubmissionQueues(
        await OfflineDbModule.getPendigQueuesToRefresh(),
      );
      if (currentRows.isEmpty) {
        await Get.dialog(AllRecordsDoneDialog());
        return;
      }

      // 10. Keep the lock until the existing refresh dialog finishes.
      await Get.dialog<CachedRefreshResult>(
        CachedRefreshDialogWidget(refreshQueueRows: currentRows),
        barrierDismissible: false,
      );
    } catch (e, st) {
      // 11. Record unexpected errors and inform the user.
      LogService.writeLog(message: "$tag [FAILED]\n$e\n$st");
      Get.snackbar(
        "Refresh Error",
        "Failed to refresh queues. Please try again.",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      // 12. Release only this run's acquired lock, including on early exits.
      if (lockAcquired) {
        try {
          await OfflineDbModule.releaseCachedSaveLock(owner: owner);
        } finally {
          // 13. Update dashboard counts after the operation finishes.
          await refreshPendingCount();
        }
      }
    }
  }

  Future<void> actionPushPendingByCachedSave() async {
    // Claim the UI action synchronously, including during confirmations. The
    // existing database lock below remains the authority across isolates.
    if (sendPendingRecordsDisabled) return;
    isSendingPendingRecords.value = true;
    _sendBannerTimer?.cancel();
    sendPendingBanner.value = null;
    _deferredBatchBanner = false;
    try {
      // Establish a scoped notification cursor before this send can produce
      // results. Reading existing notifications never changes sync eligibility.
      await refreshBatchResultBanner();
      await _pushPendingRecordsWithBanner();
    } finally {
      isSendingPendingRecords.value = false;
      // This timer changes presentation only. Queued backend work continues.
      if (_deferredBatchBanner && _batchBannerUpdates.latest != null) {
        showSendPendingBanner(_batchBannerUpdates.latest!);
        _deferredBatchBanner = false;
      } else if (sendPendingBanner.value != null) {
        showSendPendingBanner(sendPendingBanner.value!);
      }
    }
  }

  Future<void> _pushPendingRecordsWithBanner() async {
    const tag = "[OFFLINE_ACTION_PUSH_PENDING_BY_CACHED_SAVE]";

    // 1. Require internet before attempting an upload.
    if (!await _isInternetAvailable()) {
      _showNeedInternetDialog();
      return;
    }

    // 2. Check whether there are records available to upload.
    final pendingRecords = await OfflineDbModule.getPendingCount();
    if (pendingRecords == 0) {
      await _confirm(
        title: "No Pending Data",
        message:
            "There is no pending data available.\n\n"
            "You can try saving new forms offline to use this feature.",
        okText: "Okay",
        icon: Icons.indeterminate_check_box_outlined,
        confirmColor: const Color.fromARGB(255, 235, 103, 37),
      );
      return;
    }

    // 3. Confirm the upload while background sync remains free to run.
    final ok = await _confirm(
      title: "Upload Pending Data",
      message:
          "This will upload $pendingRecords locally saved records "
          "to the server.\n\nAre you sure you want to continue?",
      okText: "Upload Now",
      icon: Icons.cloud_upload_rounded,
      confirmColor: const Color(0xFF2563EB),
    );
    if (!ok) return;

    // 4. Give this upload run its own lock owner identifier.
    final owner = 'manual-upload-${DateTime.now().microsecondsSinceEpoch}';
    bool lockAcquired = false;
    bool previousQueueIssues = false;
    OfflineUpdateNotificationRun? sendNotificationRun;

    try {
      // 5. Acquire the shared sync lock before queue refresh or upload.
      // Form saves remain independent of this logical lock.
      lockAcquired = await OfflineDbModule.tryAcquireCachedSaveLock(
        owner: owner,
      );

      // 6. Avoid overlapping uploads; do not interrupt background sync.
      if (!lockAcquired) {
        Get.snackbar(
          "Sync Busy",
          "Another sync is already running. Please try again shortly.",
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // Capture the existing scope for an unexpected run-level error only.
      // Batch acceptance/failure notifications still use their existing hooks.
      sendNotificationRun = await OfflineNotifications.beginUpdate();

      // 7. Set sync-specific state without changing the form's isLoading.
      cachedSaveUpdateMessage.value = "Starting Process";
      isCachedSaveActive.value = true;
      // The old upload dialog cleared these presentation items in build().
      // Reset once here instead so repeated banner rebuilds never lose batches.
      cachedSaveQueItems.clear();
      resetQueueTracking();
      sendPendingBanner.value = const OfflineSendBannerState(
        phase: OfflineSendBannerPhase.checkingSession,
        title: 'Checking your session',
        description: 'Preparing to send · You can keep working',
      );

      // 8. Validate the session before contacting upload APIs.
      // Previous progress dialog retained for comparison. Reuse its exact
      // validation function directly; the banner now presents this stage.
      // final sessionResult = await Get.dialog<CachedSessionValidationResult>(
      //   PopScope(canPop: false, child: const CachedSessionValidationDialog()),
      //   barrierDismissible: false,
      // );
      final sessionResult = await validateSession()
          ? CachedSessionValidationResult.valid
          : CachedSessionValidationResult.invalid;

      // 9. Offer login if the session is invalid.
      if (sessionResult != CachedSessionValidationResult.valid) {
        sendPendingBanner.value = null;
        final login = await _confirm(
          title: "Invalid Session",
          message:
              "Your session has expired. Log back in to sync your pending "
              "data and access your forms.",
          okText: "Okay",
          icon: Icons.indeterminate_check_box_outlined,
          confirmColor: const Color.fromARGB(255, 235, 103, 37),
        );
        cachedSaveUpdateMessage.value = "Invalid Session";
        if (login) Get.offAllNamed(Routes.LOGIN);
        return;
      }

      // 10. Find previous uploads awaiting server confirmation.
      final refreshQueueRows = await OfflineDbModule.getPendigQueuesToRefresh();

      // 11. Resolve previous queues before selecting new upload batches.
      if (refreshQueueRows.isNotEmpty) {
        // Previous detail dialog retained. Resolve with the same shared
        // function before selecting new batches, without blocking form use.
        // final refreshResult = await Get.dialog<CachedRefreshResult>(
        //   CachedRefreshDialogWidget(refreshQueueRows: refreshQueueRows),
        //   barrierDismissible: false,
        // );
        // if (refreshResult != CachedRefreshResult.refreshed) return;
        sendPendingBanner.value = const OfflineSendBannerState(
          phase: OfflineSendBannerPhase.checkingQueues,
          title: 'Checking earlier submissions',
          description: 'Getting the latest queue results',
        );
        isPendingQuesRefreshing.value = true;
        isPendingQueResolveComplete.value = false;
        pendingQueResolveResults.clear();
        try {
          final results =
              await OfflineDbModule.resolvePendingCachedSaveQueueBatches(
                controller: this,
              );
          pendingQueResolveResults.assignAll(results);
          previousQueueIssues = results.any(
            (result) => result.isError || result.isPartial,
          );
        } finally {
          isPendingQuesRefreshing.value = false;
          isPendingQueResolveComplete.value = true;
        }
      }

      // 12. Recheck pending records under the lock, even without a refresh.
      final currentPendingCount = await OfflineDbModule.getPendingCount();
      if (currentPendingCount == 0) {
        // await Get.dialog(AllRecordsDoneDialog()); // Replaced by the banner.
        sendPendingBanner.value = OfflineSendBannerState(
          phase: previousQueueIssues
              ? OfflineSendBannerPhase.issues
              : OfflineSendBannerPhase.done,
          title: 'No records to send',
          description: 'Check earlier results in notifications',
        );
        return;
      }

      // 13. Keep the previous upload dialog opening code for comparison.
      // Only its presentation is replaced; startCachedSave below is unchanged.
      cachedSaveUpdateMessage.value = "Uploading Pending Data";
      // Get.dialog(CachedSaveDialogWidget(), barrierDismissible: false);
      sendPendingBanner.value = const OfflineSendBannerState(
        phase: OfflineSendBannerPhase.uploading,
        title: 'Sending offline records',
        description: 'Preparing records · You can keep working',
      );

      // 14. Await upload completion so the lock is not released early.
      // Async I/O yields to Flutter's event loop. Do not acquire this lock
      // again inside startCachedSave().
      await OfflineDbModule.startCachedSave(controller: this);
      // Acceptance into a queue is not successful server processing. Preserve
      // actual accepted counts even if FCM has already updated a batch result.
      final items = cachedSaveQueItems.map((item) => item.value).toList();
      final accepted = OfflineSendBannerState.acceptedBatches(items);
      final unsent = max(0, totalExpectedBatches.value - accepted);
      // Group only this send's accepted record queues. Prepared IDs alone do
      // not prove acceptance. Preserve unsent batches in the result summary.
      _batchBannerUpdates.trackSubmission(
        owner,
        items
            .where(
              (item) => OfflineSendBannerState.acceptedBatches([item]) == 1,
            )
            .map((item) => item.qId),
        unsentBatches: unsent,
      );
      final issues =
          previousQueueIssues ||
          unsent > 0 ||
          totalExpectedBatches.value == 0 ||
          items.any(
            (item) =>
                item.submissionStatus == QueueSubmissionStatus.error ||
                item.failedItems > 0,
          );
      sendPendingBanner.value = OfflineSendBannerState(
        phase: issues
            ? OfflineSendBannerPhase.issues
            : OfflineSendBannerPhase.done,
        title: issues
            ? 'Sending completed with issues'
            : 'Records sent for processing',
        description:
            '$accepted batches queued${unsent > 0 ? ' · $unsent not sent' : ''} · View notifications',
      );
    } catch (e, st) {
      // 15. Log upload errors and inform the user.
      LogService.writeLog(message: "$tag [FAILED]\n$e\n$st");
      sendPendingBanner.value = const OfflineSendBannerState(
        phase: OfflineSendBannerPhase.issues,
        title: 'Unable to finish sending',
        description: 'Check submission details in notifications',
      );
      await sendNotificationRun?.notify(
        event: 'send-error',
        type: 'batch_error',
        title: 'Sending offline records was interrupted',
        message:
            'Some records may already be queued. Remaining records are kept offline. Check submission status before trying again.',
      );
      Get.snackbar(
        "Upload Error",
        "Failed to process queue. Check logs.",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        icon: const Icon(Icons.warning, color: Colors.white),
      );
    } finally {
      // 16. A rejected attempt must not reset another upload's UI state.
      if (lockAcquired) {
        isCachedSaveActive.value = false;
        try {
          // 17. Release this run's lock; background sync remains scheduled.
          await OfflineDbModule.releaseCachedSaveLock(owner: owner);
        } finally {
          // 18. Refresh counts without changing the form's loading flag.
          await refreshPendingCount();
        }
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  //////// Cached save progress update items/////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////
  // Manual-send UI state is independent of the form loading state and of the
  // background service. It never controls batching, retries or queue statuses.
  final isSendingPendingRecords = false.obs;
  final sendPendingBanner = Rxn<OfflineSendBannerState>();
  Timer? _sendBannerTimer;
  final _batchBannerUpdates = OfflineBatchBannerUpdates();
  bool _readingBatchBanner = false;
  bool _deferredBatchBanner = false;

  /// Presentation only: new errors reset a two-minute timeout, other results
  /// use five seconds. Polling the same stored event does not call this again.
  void showSendPendingBanner(OfflineSendBannerState state) {
    if (isClosed) return;
    _sendBannerTimer?.cancel();
    sendPendingBanner.value = state;
    _sendBannerTimer = Timer(state.displayDuration, () {
      if (identical(sendPendingBanner.value, state))
        sendPendingBanner.value = null;
    });
  }

  Future<void> refreshBatchResultBanner() async {
    if (_readingBatchBanner || isClosed) return;
    _readingBatchBanner = true;
    try {
      final snapshot = await OfflineNotifications.batchBannerSnapshot(
        previousScope: _batchBannerUpdates.scope,
        afterId: _batchBannerUpdates.lastId,
      );
      if (snapshot == null) return;
      if (snapshot.baseline && _batchBannerUpdates.scope != null) {
        _sendBannerTimer?.cancel();
        sendPendingBanner.value = null;
        _deferredBatchBanner = false;
      }
      final changed = _batchBannerUpdates.consume(snapshot);
      if (!changed) return;
      // Never replace session validation/upload progress or release its lock
      // when a backend result arrives during a manual send.
      if (isSendingPendingRecords.value) {
        _deferredBatchBanner = true;
      } else if (_batchBannerUpdates.latest != null) {
        showSendPendingBanner(_batchBannerUpdates.latest!);
      }
    } catch (e) {
      LogService.writeLog(
        message: '[OFFLINE_BANNER] Result observation failed: $e',
      );
    } finally {
      _readingBatchBanner = false;
    }
  }

  bool get sendPendingRecordsDisabled =>
      isSendingPendingRecords.value ||
      isCachedSaveActive.value ||
      isPendingQuesRefreshing.value ||
      OfflineBackgroundSyncService.instance.isSyncing.value;

  OfflineSendBannerState? get currentSendPendingBanner {
    final state = sendPendingBanner.value;
    if (state?.phase != OfflineSendBannerPhase.uploading) return state;
    // Observe existing progress without adding API calls or a second counter.
    return OfflineSendBannerState.uploading(
      message: cachedSaveUpdateMessage.value,
      totalBatches: totalExpectedBatches.value,
      items: cachedSaveQueItems.map((item) => item.value).toList(),
    );
  }

  var isSessionCheckingForCachedSave = false.obs;
  var isPendingQuesRefreshing = false.obs;
  var pendingQueResolveResults = <QueueResolveResultModel>[].obs;
  var isPendingQueResolveComplete = false.obs;
  var isCachedSaveActive = false.obs;
  final cachedSaveQueItems = <Rx<CachedSaveItemModel>>[].obs;
  var cachedSaveUpdateMessage = ''.obs;
  final RxSet<String> sentQueueIds = <String>{}.obs;
  final RxSet<String> receivedQueueIds = <String>{}.obs;
  var totalExpectedRecords = 0.obs;
  var totalExpectedBatches = 0.obs;
  void registerSentQueueId(String queueId) {
    sentQueueIds.add(queueId);
    // LogService.writeLog(
    //   message:
    //       "[QUEUE_TRACKING] SENT queue_id=$queueId | "
    //       "sent_total=${sentQueueIds.length} received_total=${receivedQueueIds.length}",
    // );
  }

  void registerReceivedQueueId(String queueId) {
    receivedQueueIds.add(queueId);
    LogService.writeLog(
      message:
          "[QUEUE_TRACKING] RECEIVED queue_id=$queueId | "
          "sent_total=${sentQueueIds.length} received_total=${receivedQueueIds.length}",
    );
    _checkIfAllQueuesResolved();
  }

  void _checkIfAllQueuesResolved() {
    if (sentQueueIds.isEmpty) return;

    final bool allResolved = sentQueueIds.every(receivedQueueIds.contains);

    if (allResolved) {
      cachedSaveUpdateMessage.value =
          "Server confirmation received for all ${sentQueueIds.length} batch${sentQueueIds.isEmpty ? '' : "es"}.\nSync is complete.";
    }
  }

  void resetQueueTracking() {
    sentQueueIds.clear();
    receivedQueueIds.clear();
    totalExpectedRecords.value = 0;
    totalExpectedBatches.value = 0;
    LogService.writeLog(message: "[QUEUE_TRACKING] RESET for new run");
  }

  static const Map<QueueSubmissionStatus, int> _statusPriority = {
    QueueSubmissionStatus.refetch: 0,
    QueueSubmissionStatus.error: 1,
    QueueSubmissionStatus.partial: 2,
    QueueSubmissionStatus.success: 3,
    QueueSubmissionStatus.pending: 4,
    QueueSubmissionStatus.sending: 5,
    QueueSubmissionStatus.created: 6,
  };
  void _sortQueueItems() {
    cachedSaveQueItems.sort((a, b) {
      final priorityA = _statusPriority[a.value.submissionStatus]!;
      final priorityB = _statusPriority[b.value.submissionStatus]!;

      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }

      return 0;
    });
  }

  void addQueue(CachedSaveItemModel item) {
    registerSentQueueId(item.qId);
    cachedSaveQueItems.add(item.obs);
  }

  void updateQueueItem(
    String qId,
    CachedSaveItemModel Function(CachedSaveItemModel) updater,
  ) {
    final index = cachedSaveQueItems.indexWhere((e) => e.value.qId == qId);

    if (index == -1) return;

    cachedSaveQueItems[index].value = updater(cachedSaveQueItems[index].value);
    _sortQueueItems();
  }

  // ── Offline settings state ──────────────────────────────────────

  void openOfflinesettings() {
    Get.bottomSheet(
      SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(Get.context!).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: StatefulBuilder(
              builder: (context, refresh) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        height: 4,
                        width: 48,
                        decoration: BoxDecoration(
                          color: AppColors.grey300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.darkBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.settings,
                            color: AppColors.darkBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Offline Settings",
                                style: AppTextStyles.subtitle.copyWith(
                                  color: AppColors.darkBlue,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                "Control how offline data is handled",
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.grey500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Tiles
                    OfflineSettingTile(
                      icon: Icons.sync_rounded,
                      color: AppColors.primaryPurple,
                      title: "Auto sync",
                      subtitle: "Sync saved forms when internet is available",
                      value: OfflineDbModule.autoSync,
                      onChanged: (v) async {
                        await OfflineBackgroundSyncService.instance.setAutoSync(
                          enabled: v,
                        );
                        refresh(() {});
                      },
                    ),

                    OfflineSettingTile(
                      icon: Icons.download_for_offline_rounded,
                      color: AppColors.accentCyan2,
                      title: "Auto sync masters",
                      subtitle: "Sync data sources when internet is available",
                      value: OfflineDbModule.autoSyncMaster,
                      onChanged: (v) async {
                        await OfflineDbModule.toggleAutoSyncMaster();

                        refresh(() {});
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      enterBottomSheetDuration: const Duration(milliseconds: 300),
    );
  }
}

class OfflineSettingTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const OfflineSettingTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 20), // Reduced bottom margin
      decoration: BoxDecoration(
        // Removed the border for a cleaner, flatter look
        color: value ? color.withValues(alpha: 0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(!value),
          child: Padding(
            // Tightened overall padding
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(8), // Smaller icon padding
                  decoration: BoxDecoration(
                    color: value ? color : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 18, // Reduced icon size
                    color: value ? Colors.white : color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.subtitle.copyWith(
                          color: AppColors.grey900,
                          fontWeight: FontWeight.w600,
                          fontSize: 14, // Ensure font is compact
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.grey500,
                          fontSize: 12, // Slightly smaller subtitle
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Scaled down the switch to match the new minimal height
                Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: value,
                    onChanged: onChanged,
                    thumbColor: const WidgetStatePropertyAll(Colors.white),
                    trackColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? color
                          : AppColors.grey300,
                    ),
                    trackOutlineColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
