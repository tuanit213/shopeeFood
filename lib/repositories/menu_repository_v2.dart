import '../domain/menu/menu_models_v2.dart';

abstract interface class MenuRepositoryV2 {
  Stream<List<MenuSectionV2>> watchSections(String branchId);
  Stream<List<MenuItemV2>> watchItems(String branchId);
  Stream<List<OptionGroupV2>> watchOptionGroups(String branchId);
}
