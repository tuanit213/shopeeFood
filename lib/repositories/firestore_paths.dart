abstract final class FirestorePaths {
  static String user(String uid) => 'users/$uid';
  static String address(String uid, String addressId) =>
      'users/$uid/addresses/$addressId';
  static String restaurant(String id) => 'restaurants/$id';
  static String branch(String id) => 'restaurantBranches/$id';
  static String menuSection(String branchId, String sectionId) =>
      'restaurantBranches/$branchId/menuSections/$sectionId';
  static String menuItem(String branchId, String itemId) =>
      'restaurantBranches/$branchId/menuItems/$itemId';
  static String optionGroup(String branchId, String groupId) =>
      'restaurantBranches/$branchId/optionGroups/$groupId';
  static String order(String id) => 'orders/$id';
  static String orderEvent(String orderId, String eventId) =>
      'orders/$orderId/events/$eventId';
  static String rating(String id) => 'ratings/$id';
}
