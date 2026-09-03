// ignore_for_file: non_constant_identifier_names

import '../core/common.dart';

class GlobalVariableController extends GetxController {
  static GlobalVariableController get to => Get.find();

  var isDataSourcefetchingOnStart = false.obs;
  var totalDsCountOnStart = 0.obs;
  var completedDsCountOnStart = 0.obs;

  var OFFLINE_FORMS_COUNT = 0.obs;
  var USER_ROLE = ''.obs;
}
