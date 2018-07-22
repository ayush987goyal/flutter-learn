import 'package:scoped_model/scoped_model.dart';

import '../models/product.dart';

class ProductsModel extends Model {
  List<Product> _products = [];
  int _selectedProuctIndex;

  List<Product> get products {
    return List.from(_products);
  }

  int get selectedProductIndex {
    return _selectedProuctIndex;
  }

  Product get selectedProduct {
    return _selectedProuctIndex == null
        ? null
        : _products[_selectedProuctIndex];
  }

  void addProduct(Product product) {
    _products.add(product);
    _selectedProuctIndex = null;
  }

  void updateProduct(Product product) {
    _products[_selectedProuctIndex] = product;
    _selectedProuctIndex = null;
  }

  void deleteProduct(int index) {
    _products.removeAt(index);
    _selectedProuctIndex = null;
  }

  void selectProduct(int index) {
    _selectedProuctIndex = index;
  }
}
