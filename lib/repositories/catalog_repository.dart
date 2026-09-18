import '../domain/catalog/restaurant_v2.dart';

abstract interface class CatalogRepository {
  Stream<List<RestaurantV2>> watchRestaurants();
  Future<RestaurantV2?> getRestaurant(String id);
  Future<RestaurantBranch?> getBranch(String id);
}
