import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/form_page_model.dart';

class RefreshSelectionDialog extends StatelessWidget {
  const RefreshSelectionDialog({super.key, required this.forms});

  final List<OfflineFormPageModel> forms;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF262733) : Colors.white;
    final ink = dark ? const Color(0xFFF2F1F8) : AppColors.AXMDark;
    final muted = dark ? const Color(0xFFB9BED0) : AppColors.AXMGray;
    final accent = dark ? const Color(0xFFB7AFFF) : AppColors.darkBlue;
    final tint = dark ? const Color(0xFF353148) : const Color(0xFFF0EFFB);
    final border = dark ? const Color(0xFF474856) : const Color(0xFFE6E7EF);

    Widget option({
      required String title,
      required String description,
      required String id,
      required IconData icon,
      bool featured = false,
    }) {
      return Material(
        color: featured ? tint : surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: featured ? tint : border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: accent, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        description,
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: muted, size: 20),
              ],
            ),
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: DefaultTextStyle(
            style: TextStyle(fontFamily: 'Poppins', color: ink),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: tint,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(Icons.sync_rounded, color: accent, size: 27),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Refresh offline data',
                  style: TextStyle(
                    color: ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose everything or just one form.',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
                const SizedBox(height: 22),
                option(
                  title: 'Refresh All',
                  description:
                      'Send pending records and update all forms and lookup data.',
                  id: '',
                  icon: Icons.sync_rounded,
                  featured: true,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'OR CHOOSE A FORM',
                        style: TextStyle(
                          color: muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Text(
                      '${forms.length} ${forms.length == 1 ? 'form' : 'forms'}',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (forms.isEmpty)
                  Text(
                    'No offline forms are available yet.',
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                ...forms.map(
                  (page) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: option(
                      title: page.caption,
                      description: 'Update this form and its lookup data.',
                      id: page.transId,
                      icon: Icons.description_outlined,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_rounded, color: muted, size: 15),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        'Internet connection required',
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
