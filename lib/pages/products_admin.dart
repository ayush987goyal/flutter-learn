import 'package:flutter/material.dart';

import './product_edit.dart';
import './product_list.dart';
import '../widgets/ui_elements/logout_list_tile.dart';
import '../scoped-models/main.dart';

class ProductsAdminPage extends StatefulWidget {
  final MainModel model;

  ProductsAdminPage(this.model);

  @override
  State<StatefulWidget> createState() {
    return _ProductsAdminPageState();
  }
}

class _ProductsAdminPageState extends State<ProductsAdminPage> {
  Widget _buildSideDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: <Widget>[
          AppBar(
            title: Text('Choose'),
          ),
          ListTile(
            leading: Icon(Icons.shop),
            title: Text('All Products'),
            onTap: () => Navigator.pushReplacementNamed(context, '/'),
          ),
          Divider(),
          LogoutTileList()
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        drawer: _buildSideDrawer(context),
        appBar: AppBar(
          title: Text('Manage Products'),
          bottom: TabBar(
            tabs: <Widget>[
              Tab(
                icon: Icon(Icons.create),
                text: 'Create Product',
              ),
              Tab(
                icon: Icon(Icons.list),
                text: 'My Products',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[ProductEditPage(), ProductListPage(widget.model)],
        ),
      ),
    );
  }
}
