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

class _ConnectionEditorState extends State<ConnectionEditor> {
  final _form = GlobalKey<FormState>();
  final ProjectController c = Get.find();
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
                      url: true,
                      enabled: !busy,
                    ),
                    _field(
                      'ARM URL',
                      c.armUrlCtrl,
                      Icons.dns_outlined,
                      validator: c.validateUrl,
                      url: true,
                      enabled: !busy,
                    ),
                    _field(
                      'Connection name',
                      c.connectionNameCtrl,
                      Icons.storage_outlined,
                      validator: (v) => c.validateNormalField(v, false),
                      enabled: !busy,
                    ),
                    _field(
                      'Caption',
                      c.connectionCaptionCtrl,
                      Icons.label_outline,
                      validator: (v) => c.validateNormalField(v, true),
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
    FocusNode? focus,
    bool url = false,
    bool enabled = true,
  }) => Padding(
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
