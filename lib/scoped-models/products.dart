import 'package:scoped_model/scoped_model.dart';

import '../models/product.dart';

class ProductsModel extends Model {
  List<Product> _products = [];
  int _selectedProuctIndex;
  bool _showFavorites = false;

  List<Product> get products {
    return List.from(_products);
  }

  List<Product> get displayedProducts {
    if (_showFavorites) {
      return _products.where((Product product) => product.isFavorite).toList();
    }
    return List.from(_products);
  }

  int get selectedProductIndex {
    return _selectedProuctIndex;
  }

  bool get displayFavoritesOnly {
    return _showFavorites;
  }

  Product get selectedProduct {
    return _selectedProuctIndex == null
        ? null
        : _products[_selectedProuctIndex];
  }

  void addProduct(Product product) {
    _products.add(product);
    _selectedProuctIndex = null;
    notifyListeners();
  }

  void updateProduct(Product product) {
    _products[_selectedProuctIndex] = product;
    _selectedProuctIndex = null;
    notifyListeners();
  }

  void deleteProduct() {
    _products.removeAt(_selectedProuctIndex);
    _selectedProuctIndex = null;
    notifyListeners();
  }

  void toggleProductFavoriteStatus() {
    final bool isCurrentlyFavorite = selectedProduct.isFavorite;
    final bool newFavoriteStatus = !isCurrentlyFavorite;
    final Product updatedProduct = Product(
        title: selectedProduct.title,
        description: selectedProduct.description,
        price: selectedProduct.price,
        image: selectedProduct.image,
        isFavorite: newFavoriteStatus);
    _products[_selectedProuctIndex] = updatedProduct;
    _selectedProuctIndex = null;
    notifyListeners();
  }

  void selectProduct(int index) {
    _selectedProuctIndex = index;
    notifyListeners();
  }

  void toggleDisplayMode() {
    _showFavorites = !_showFavorites;
    notifyListeners();
  }
}
