import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../widgets/connection_style.dart';
import '../../../data/enums/project_enums.dart';
import '../controller/project_controller.dart';

class ConnectionEditor extends StatefulWidget {
  const ConnectionEditor({super.key});
  @override
  State<ConnectionEditor> createState() => _ConnectionEditorState();
}

class _ConnectionEditorState extends State<ConnectionEditor>
    with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  final ProjectController c = Get.find();
  late final Map<FocusNode, GlobalKey> _fieldKeys;

  @override
  void initState() {
    super.initState();
    _fieldKeys = {
      c.webUrlFocusNode: GlobalKey(),
      c.armUrlFocusNode: GlobalKey(),
      c.connectionNameFocusNode: GlobalKey(),
      c.connectionCaptionFocusNode: GlobalKey(),
      c.accessCodeFocusNode: GlobalKey(),
    };
    WidgetsBinding.instance.addObserver(this);
    for (final node in _fieldKeys.keys) {
      node.addListener(_revealFocusedField);
    }
    _revealFocusedField();
  }

  @override
  void didChangeMetrics() => _revealFocusedField();

  void _revealFocusedField() {
    // Wait for the keyboard/layout change before calculating the visible area.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final entry in _fieldKeys.entries) {
        final fieldContext = entry.value.currentContext;
        if (entry.key.hasFocus && fieldContext != null) {
          Scrollable.ensureVisible(
            fieldContext,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          );
          break;
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final node in _fieldKeys.keys) {
      node.removeListener(_revealFocusedField);
    }
    // Focus nodes belong to ProjectController and are disposed there.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final busy = c.isProjectSaving.value || c.isAccessCodeLoading.value;
    final edit = c.currentTileState.value == ProjectAddingState.urlEdit;
    final access = c.manualTabIndex.value == 1 && !edit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter the connection details supplied by your administrator.',
          style: ConnectionStyle.text(
            context,
            12,
            color: ConnectionStyle.muted(context),
          ),
        ),
        const SizedBox(height: 16),
        if (!edit) ...[
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('URL details')),
              ButtonSegment(value: 1, label: Text('Access code')),
            ],
            selected: {c.manualTabIndex.value},
            onSelectionChanged: busy
                ? null
                : (v) {
                    c.manualTabIndex.value = v.first;
                    c.manualTabCtrl.animateTo(v.first);
                  },
          ),
          const SizedBox(height: 16),
        ],
        Form(
          key: _form,
          child: Column(
            children: access
                ? [
                    _field(
                      'Access code',
                      c.accessCodeCtrl,
                      Icons.key,
                      focus: c.accessCodeFocusNode,
                      enabled: !busy,
                    ),
                  ]
                : [
                    _field(
                      'Project URL',
                      c.webUrlCtrl,
                      Icons.link,
                      validator: c.validateUrl,
                      focus: c.webUrlFocusNode,
                      nextFocus: c.armUrlFocusNode,
                      url: true,
                      enabled: !busy,
                    ),
                    _field(
                      'ARM URL',
                      c.armUrlCtrl,
                      Icons.dns_outlined,
                      validator: c.validateUrl,
                      focus: c.armUrlFocusNode,
                      nextFocus: c.connectionNameFocusNode,
                      url: true,
                      enabled: !busy,
                    ),
                    _field(
                      'Connection name',
                      c.connectionNameCtrl,
                      Icons.storage_outlined,
                      validator: (v) => c.validateNormalField(v, false),
                      focus: c.connectionNameFocusNode,
                      nextFocus: c.connectionCaptionFocusNode,
                      enabled: !busy,
                    ),
                    _field(
                      'Caption',
                      c.connectionCaptionCtrl,
                      Icons.label_outline,
                      validator: (v) => c.validateNormalField(v, true),
                      focus: c.connectionCaptionFocusNode,
                      enabled: !busy,
                    ),
                  ],
          ),
        ),
        ConnectionButton(
          label: busy
              ? c.projectSavingInfoText.value.isEmpty
                    ? 'Connecting...'
                    : c.projectSavingInfoText.value
              : edit
              ? 'Save changes'
              : 'Connect',
          loading: busy,
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            if (access) {
              c.onSaveAccessCode();
            } else {
              c.onSaveUrlDetails(_form);
            }
          },
        ),
      ],
    );
  });
  Widget _field(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    String? Function(String?)? validator,
    required FocusNode focus,
    FocusNode? nextFocus,
    bool url = false,
    bool enabled = true,
  }) => Padding(
    key: _fieldKeys[focus],
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ConnectionStyle.text(
            context,
            12,
            weight: FontWeight.w600,
            color: ConnectionStyle.muted(context),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          focusNode: focus,
          scrollPadding: const EdgeInsets.all(24),
          textInputAction: nextFocus == null
              ? TextInputAction.done
              : TextInputAction.next,
          onFieldSubmitted: (_) {
            if (nextFocus != null) {
              nextFocus.requestFocus();
            } else {
              focus.unfocus();
            }
          },
          enabled: enabled,
          validator: validator,
          keyboardType: url ? TextInputType.url : TextInputType.text,
          autocorrect: false,
          style: ConnectionStyle.text(context, 14),
          decoration: ConnectionStyle.input(
            context,
            url ? 'https://yourcompany.com/axpert' : label,
            icon,
          ),
        ),
      ],
    ),
  );
}
