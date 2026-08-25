import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AxpertLogo extends StatelessWidget {
  const AxpertLogo({super.key, this.width, this.isFull = false});
  final double? width;
  final bool isFull;
  @override
  Widget build(BuildContext context) {
    var imageName = isFull ? "axpert_logo_new" : "axpert_logo_new";
    return Image.asset("assets/images/$imageName.png", width: width ?? 50.w);
  }
}
