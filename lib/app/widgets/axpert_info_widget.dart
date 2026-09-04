import 'package:axpert/app/widgets/axi_logo.dart';

import '../core/common.dart';

class AxpertInfoWidget extends StatelessWidget {
  const AxpertInfoWidget({
    super.key,
    this.padding = EdgeInsetsGeometry.zero,
    this.expand = false,
  });
  final EdgeInsetsGeometry padding;
  final bool expand;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              Text(
                "Powered by",
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.colors.primaryText,
                  fontWeight: FontWeight.w500,
                  fontSize: expand ? null : 12.sp,
                ),
              ),
              AxpertLogo(width: 20.w),
              // Text(
              //   "AXPERT",
              //   style: AppTextStyles.bodyMedium.copyWith(
              //     color: context.colors.primaryText,
              //     fontWeight: FontWeight.w500,
              //   ),
              // ),
            ],
          ),
          5.verticalSpace,
          Text(
            "${DateTime.now().year} AXPERT. All rights reserved",
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.colors.primaryText.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
              fontSize: expand ? null : 12.sp,
            ),
          ),
        ],
      ),
    );
  }
}
