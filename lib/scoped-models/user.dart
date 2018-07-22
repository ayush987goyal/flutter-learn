import '../models/user.dart';
import './connected_products.dart';

class UserModel extends ConnectedProducts {
  void login(String email, String password) {
    authenticatedUser = User(id: 'dsfwfdv', email: email, password: password);
  }
}
