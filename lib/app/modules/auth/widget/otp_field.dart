import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import '../../../widgets/connection_style.dart';

class WidgetOtpTextField extends StatelessWidget {
  const WidgetOtpTextField({
    super.key,
    required this.label,
    this.isLoading = false,
    this.width = 10,
    this.otpLength = 4,
    this.controller,
    this.errorText = '',
    this.onCompleted,
  });
  final String label;
  final bool isLoading;
  final double width;
  final int otpLength;
  final TextEditingController? controller;
  final String errorText;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          if (isLoading) ...[
            const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ConnectionStyle.navy,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Text(
            label,
            style: ConnectionStyle.text(
              context,
              12,
              weight: FontWeight.w600,
              color: ConnectionStyle.muted(context),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, constraints) {
          const gap = 5.0;
          final fieldWidth =
              ((constraints.maxWidth - gap * (otpLength - 1)) / otpLength)
                  .clamp(1.0, 56.0);
          final danger = ConnectionStyle.dark(context)
              ? const Color(0xffFF7A8C)
              : const Color(0xffC7364B);
          PinTheme pinTheme(
            Color border, {
            Color? fill,
            double borderWidth = 1.5,
          }) => PinTheme(
            width: fieldWidth,
            height: 52,
            textStyle: ConnectionStyle.text(
              context,
              19,
              weight: FontWeight.w700,
            ),
            decoration: BoxDecoration(
              color: fill ?? ConnectionStyle.field(context),
              border: Border.all(color: border, width: borderWidth),
              borderRadius: BorderRadius.circular(12),
            ),
          );
          return Center(
            child: Pinput(
              length: otpLength,
              controller: controller,
              separatorBuilder: (_) => const SizedBox(width: gap),
              defaultPinTheme: pinTheme(
                errorText.isNotEmpty ? danger : ConnectionStyle.line(context),
              ),
              focusedPinTheme: pinTheme(
                errorText.isNotEmpty ? danger : ConnectionStyle.navy,
                fill: ConnectionStyle.card(context),
                borderWidth: 2,
              ),
              submittedPinTheme: pinTheme(
                errorText.isNotEmpty ? danger : ConnectionStyle.navy,
              ),
              onCompleted: (_) => onCompleted?.call(),
            ),
          );
        },
      ),
      Padding(
        padding: const EdgeInsets.only(left: 4, top: 6),
        child: Semantics(
          liveRegion: true,
          child: Text(
            errorText,
            style: ConnectionStyle.text(
              context,
              12,
              weight: FontWeight.w600,
              color: ConnectionStyle.dark(context)
                  ? const Color(0xffFF7A8C)
                  : const Color(0xffC7364B),
            ),
          ),
        ),
      ),
    ],
  );
}
