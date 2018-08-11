import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:scoped_model/scoped_model.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rxdart/subjects.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

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

  Future<Map<String, dynamic>> uploadImage(File image,
      {String imagePath}) async {
    final mimeTypeData = lookupMimeType(image.path).split('/');
    final imageUploadRequest = http.MultipartRequest(
      'POST',
      Uri.parse(
          'https://us-central1-flutter-products-6fdce.cloudfunctions.net/storeImage'),
    );
    final file = await http.MultipartFile.fromPath(
      'image',
      image.path,
      contentType: MediaType(mimeTypeData[0], mimeTypeData[1]),
    );
    imageUploadRequest.files.add(file);
    if (imagePath != null) {
      imageUploadRequest.fields['imagePath'] = Uri.encodeComponent(imagePath);
    }
    imageUploadRequest.headers['Authorization'] =
        'Bearer ${_authenticatedUser.token}';

    try {
      final streamedResponse = await imageUploadRequest.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode != 200 && response.statusCode != 201) {
        print('Something went wrong');
        print(jsonDecode(response.body));
        return null;
      }
      final responseData = jsonDecode(response.body);
      return responseData;
    } catch (error) {
      print(error);
      return null;
    }
  }

  Future<bool> addProduct(String title, String description, double price,
      File image, LocationData locData) async {
    _isLoading = true;
    notifyListeners();

    final uploadData = await uploadImage(image);

    if (uploadData == null) {
      print('Upload failed!');
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final Map<String, dynamic> productData = {
      'title': title,
      'description': description,
      'price': price,
      'userEmail': _authenticatedUser.email,
      'userId': _authenticatedUser.id,
      'imagePath': uploadData['imagePath'],
      'imageUrl': uploadData['imageUrl'],
      'loc_lat': locData.latitude,
      'loc_lng': locData.longitude,
      'loc_address': locData.address
    };

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
          image: uploadData['imageUrl'],
          imagePath: uploadData['imagePath'],
          location: locData,
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

  Future<bool> updateProduct(String title, String description, double price,
      File image, LocationData locData) async {
    _isLoading = true;
    notifyListeners();

    String imageUrl = selectedProduct.image;
    String imagePath = selectedProduct.imagePath;
    if (image != null) {
      final uploadData = await uploadImage(image);
      if (uploadData == null) {
        print('Upload failed!');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      imageUrl = uploadData['imageUrl'];
      imagePath = uploadData['imagePath'];
    }

    final Map<String, dynamic> updateData = {
      'title': title,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      'userEmail': selectedProduct.userEmail,
      'userId': selectedProduct.userId,
      'loc_lat': locData.latitude,
      'loc_lng': locData.longitude,
      'loc_address': locData.address
    };

    try {
      final http.Response response = await http.put(
          'https://flutter-products-6fdce.firebaseio.com/products/${selectedProduct.id}.json?auth=${_authenticatedUser.token}',
          body: jsonEncode(updateData));
      final Product updatedProduct = Product(
        id: selectedProduct.id,
        title: title,
        description: description,
        price: price,
        location: locData,
        image: imageUrl,
        imagePath: imagePath,
        userEmail: selectedProduct.userEmail,
        userId: selectedProduct.userId,
      );

      _products[selectedProductIndex] = updatedProduct;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
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
          image: productData['imageUrl'],
          imagePath: productData['imagePath'],
          location: LocationData(
            address: productData['loc_address'],
            latitude: productData['loc_lat'],
            longitude: productData['loc_lng'],
          ),
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

  void toggleProductFavoriteStatus(Product toggledProduct) async {
    final bool isCurrentlyFavorite = selectedProduct.isFavorite;
    final bool newFavoriteStatus = !isCurrentlyFavorite;

    final int toggledProductIndex = _products.indexWhere((Product product) {
      return product.id == toggledProduct.id;
    });

    final Product updatedProduct = Product(
      id: toggledProduct.id,
      title: toggledProduct.title,
      description: toggledProduct.description,
      price: toggledProduct.price,
      image: toggledProduct.image,
      imagePath: toggledProduct.imagePath,
      location: toggledProduct.location,
      userEmail: toggledProduct.userEmail,
      userId: toggledProduct.userId,
      isFavorite: newFavoriteStatus,
    );
    _products[toggledProductIndex] = updatedProduct;
    notifyListeners();

    http.Response response;

    if (newFavoriteStatus) {
      response = await http.put(
          'https://flutter-products-6fdce.firebaseio.com/products/${toggledProduct.id}/wishlistUsers/${_authenticatedUser.id}.json?auth=${_authenticatedUser.token}',
          body: jsonEncode(true));
    } else {
      response = await http.delete(
          'https://flutter-products-6fdce.firebaseio.com/products/${toggledProduct.id}/wishlistUsers/${_authenticatedUser.id}.json?auth=${_authenticatedUser.token}');
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      final Product updatedProduct = Product(
        id: toggledProduct.id,
        title: toggledProduct.title,
        description: toggledProduct.description,
        price: toggledProduct.price,
        image: toggledProduct.image,
        imagePath: toggledProduct.imagePath,
        location: toggledProduct.location,
        userEmail: toggledProduct.userEmail,
        userId: toggledProduct.userId,
        isFavorite: !newFavoriteStatus,
      );
      _products[toggledProductIndex] = updatedProduct;
      notifyListeners();
    }
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
    _selProductId = null;
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
