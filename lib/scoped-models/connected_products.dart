import 'dart:async';
import 'dart:convert';

import 'package:scoped_model/scoped_model.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rxdart/subjects.dart';

import '../app_config.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../models/auth.dart';
import '../models/location_data.dart';

class ConnectedProductsModel extends Model {
  List<Product> _products = [];
  String _selProductId;
  User _authenticatedUser;
  bool _isLoading = false;
}

class ProductsModel extends ConnectedProductsModel {
  bool _showFavorites = false;

  List<Product> get allProducts {
    return List.from(_products);
  }

  List<Product> get displayedProducts {
    if (_showFavorites) {
      return _products.where((Product product) => product.isFavorite).toList();
    }
    return List.from(_products);
  }

  int get selectedProductIndex {
    return _products.indexWhere((Product product) {
      return product.id == _selProductId;
    });
  }

  String get selectedProductId {
    return _selProductId;
  }

  bool get displayFavoritesOnly {
    return _showFavorites;
  }

  Product get selectedProduct {
    return _selProductId == null
        ? null
        : _products.firstWhere((Product product) {
            return product.id == _selProductId;
          });
  }

  Future<bool> addProduct(String title, String description, double price,
      String image, LocationData locData) async {
    final Map<String, dynamic> productData = {
      'title': title,
      'description': description,
      'price': price,
      'image':
          'https://cms.qz.com/wp-content/uploads/2017/04/india-chocolate-market.jpg?quality=80&strip=all&w=1600',
      'userEmail': _authenticatedUser.email,
      'userId': _authenticatedUser.id,
      'loc_lat': locData.latitude,
      'loc_lng': locData.longitude,
      'loc_address': locData.address
    };

    _isLoading = true;
    notifyListeners();
    try {
      final http.Response response = await http.post(
          'https://flutter-products-6fdce.firebaseio.com/products.json?auth=${_authenticatedUser.token}',
          body: json.encode(productData));

      if (response.statusCode != 200 && response.statusCode != 201) {
        _isLoading = false;
        notifyListeners();
        return false;
      }
      final Map<String, dynamic> responseData = json.decode(response.body);
      final Product newProduct = Product(
          id: responseData['name'],
          title: title,
          description: description,
          price: price,
          image: image,
          userEmail: _authenticatedUser.email,
          userId: _authenticatedUser.id);
      _products.add(newProduct);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct(
      String title, String description, double price, String image) {
    final Map<String, dynamic> updateData = {
      'title': title,
      'description': description,
      'price': price,
      'image':
          'https://cms.qz.com/wp-content/uploads/2017/04/india-chocolate-market.jpg?quality=80&strip=all&w=1600',
      'userEmail': selectedProduct.userEmail,
      'userId': selectedProduct.userId
    };

    _isLoading = true;
    notifyListeners();
    return http
        .put(
            'https://flutter-products-6fdce.firebaseio.com/products/${selectedProduct.id}.json?auth=${_authenticatedUser.token}',
            body: jsonEncode(updateData))
        .then((http.Response response) {
      final Product updatedProduct = Product(
          id: selectedProduct.id,
          title: title,
          description: description,
          price: price,
          image:
              'https://cms.qz.com/wp-content/uploads/2017/04/india-chocolate-market.jpg?quality=80&strip=all&w=1600',
          userEmail: selectedProduct.userEmail,
          userId: selectedProduct.userId);

      _products[selectedProductIndex] = updatedProduct;
      _isLoading = false;
      notifyListeners();
      return true;
    }).catchError((error) {
      _isLoading = false;
      notifyListeners();
      return false;
    });
  }

  Future<bool> deleteProduct() {
    _isLoading = true;
    final deletedProductId = selectedProduct.id;
    _products.removeAt(selectedProductIndex);
    _selProductId = null;
    notifyListeners();
    return http
        .delete(
            'https://flutter-products-6fdce.firebaseio.com/products/${deletedProductId}.json?auth=${_authenticatedUser.token}')
        .then((http.Response response) {
      _isLoading = false;
      notifyListeners();
      return true;
    }).catchError((error) {
      _isLoading = false;
      notifyListeners();
      return false;
    });
  }

  Future<Null> fetchProducts({onlyForUser = false}) {
    _isLoading = true;
    notifyListeners();
    return http
        .get(
            'https://flutter-products-6fdce.firebaseio.com/products.json?auth=${_authenticatedUser.token}')
        .then<Null>((http.Response response) {
      final List<Product> fetchedProductList = [];
      final Map<String, dynamic> productListData = jsonDecode(response.body);
      if (productListData == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      productListData.forEach((String productId, dynamic productData) {
        final Product newProduct = Product(
          id: productId,
          title: productData['title'],
          description: productData['description'],
          price: productData['price'],
          image: productData['image'],
          userEmail: productData['userEmail'],
          userId: productData['userId'],
          isFavorite: productData['wishlistUsers'] == null
              ? false
              : (productData['wishlistUsers'] as Map<dynamic, dynamic>)
                  .containsKey(_authenticatedUser.id),
        );
        fetchedProductList.add(newProduct);
      });

      _products = onlyForUser
          ? fetchedProductList.where((Product product) {
              return product.userId == _authenticatedUser.id;
            }).toList()
          : fetchedProductList;
      _isLoading = false;
      notifyListeners();
      _selProductId = null;
    }).catchError((error) {
      _isLoading = false;
      notifyListeners();
      return false;
    });
  }

  void toggleProductFavoriteStatus() async {
    final bool isCurrentlyFavorite = selectedProduct.isFavorite;
    final bool newFavoriteStatus = !isCurrentlyFavorite;

    final Product updatedProduct = Product(
      id: selectedProduct.id,
      title: selectedProduct.title,
      description: selectedProduct.description,
      price: selectedProduct.price,
      image: selectedProduct.image,
      userEmail: selectedProduct.userEmail,
      userId: selectedProduct.userId,
      isFavorite: newFavoriteStatus,
    );
    _products[selectedProductIndex] = updatedProduct;
    notifyListeners();

    http.Response response;

    if (newFavoriteStatus) {
      response = await http.put(
          'https://flutter-products-6fdce.firebaseio.com/products/${selectedProduct.id}/wishlistUsers/${_authenticatedUser.id}.json?auth=${_authenticatedUser.token}',
          body: jsonEncode(true));
    } else {
      response = await http.delete(
          'https://flutter-products-6fdce.firebaseio.com/products/${selectedProduct.id}/wishlistUsers/${_authenticatedUser.id}.json?auth=${_authenticatedUser.token}');
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      final Product updatedProduct = Product(
        id: selectedProduct.id,
        title: selectedProduct.title,
        description: selectedProduct.description,
        price: selectedProduct.price,
        image: selectedProduct.image,
        userEmail: selectedProduct.userEmail,
        userId: selectedProduct.userId,
        isFavorite: !newFavoriteStatus,
      );
      _products[selectedProductIndex] = updatedProduct;
      notifyListeners();
    }

    _selProductId = null;
  }

  void selectProduct(String prouctId) {
    _selProductId = prouctId;
    if (prouctId != null) {
      notifyListeners();
    }
  }

  void toggleDisplayMode() {
    _showFavorites = !_showFavorites;
    notifyListeners();
  }
}

class UserModel extends ConnectedProductsModel {
  Timer _authTimer;
  PublishSubject<bool> _userSubject = PublishSubject();

  User get user {
    return _authenticatedUser;
  }

  PublishSubject<bool> get userSubject {
    return _userSubject;
  }

  Future<Map<String, dynamic>> authenticate(String email, String password,
      [AuthMode mode = AuthMode.Login]) async {
    _isLoading = true;
    notifyListeners();

    final Map<String, dynamic> authData = {
      'email': email,
      'password': password,
      'returnSecureToken': true
    };
    String endpoint = mode == AuthMode.Login
        ? 'https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyPassword?key=${AppConfig.authAPI}'
        : 'https://www.googleapis.com/identitytoolkit/v3/relyingparty/signupNewUser?key=${AppConfig.authAPI}';

    final http.Response response =
        await http.post(endpoint, body: jsonEncode(authData));
    final Map<String, dynamic> responseData = jsonDecode(response.body);
    bool hasError = true;
    String message = 'Something went wrong.';

    if (responseData.containsKey('idToken')) {
      hasError = false;
      message = 'Authentication succeeded!';
      _authenticatedUser = new User(
        id: responseData['localId'],
        email: email,
        token: responseData['idToken'],
      );

      setAuthTimeout(int.parse(responseData['expiresIn']));
      _userSubject.add(true);
      final DateTime now = DateTime.now();
      final DateTime expiryTime =
          now.add(Duration(seconds: int.parse(responseData['expiresIn'])));

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString('userId', responseData['localId']);
      prefs.setString('userEmail', email);
      prefs.setString('token', responseData['idToken']);
      prefs.setString('expiryTime', expiryTime.toIso8601String());
    } else if (responseData['error']['message'] == 'EMAIL_NOT_FOUND') {
      message = 'This email was not found.';
    } else if (responseData['error']['message'] == 'INVALID_PASSWORD') {
      message = 'The password is invalid';
    } else if (responseData['error']['message'] == 'EMAIL_EXISTS') {
      message = 'This email already exists.';
    }

    _isLoading = false;
    notifyListeners();
    return {'success': !hasError, 'message': message};
  }

  void autoAuthenticate() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String token = prefs.getString('token');
    final String expiryTimeString = prefs.getString('expiryTime');
    if (token != null) {
      final DateTime now = DateTime.now();
      final parsedExpiryTime = DateTime.parse(expiryTimeString);
      if (parsedExpiryTime.isBefore(now)) {
        _authenticatedUser = null;
        notifyListeners();
        return;
      }

      final String userId = prefs.getString('userId');
      final String userEmail = prefs.getString('userEmail');
      final int tokenLifespan = parsedExpiryTime.difference(now).inSeconds;
      _authenticatedUser = new User(
        id: userId,
        email: userEmail,
        token: token,
      );
      _userSubject.add(true);
      setAuthTimeout(tokenLifespan);
      notifyListeners();
    }
  }

  void logout() async {
    _authenticatedUser = null;
    _authTimer.cancel();
    _userSubject.add(false);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('token');
    prefs.remove('userId');
    prefs.remove('userEmail');
  }

  void setAuthTimeout(int time) {
    _authTimer = Timer(Duration(seconds: time), logout);
  }
}

class UtilityModel extends ConnectedProductsModel {
  bool get isLoading {
    return _isLoading;
  }
}
