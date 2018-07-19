import 'package:flutter/material.dart';
import 'dart:async';

class ProductPage extends StatelessWidget {
  final String title;
  final String imageUrl;
  final String description;
  final double price;

  ProductPage(this.title, this.imageUrl, this.description, this.price);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        Navigator.pop(context, false);
        return Future.value(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Image.asset(imageUrl),
            Container(
              margin: EdgeInsets.all(10.0),
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Oswald',
                  fontSize: 26.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Union Sqaure, San Francisco',
                  style: TextStyle(
                    fontFamily: 'Oswald',
                    color: Colors.grey,
                  ),
                ),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 5.0),
                  child: Text(
                    '|',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                Text(
                  '\$' + price.toString(),
                  style: TextStyle(
                    fontFamily: 'Oswald',
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            Container(
              padding: EdgeInsets.all(10.0),
              child: Text(
                description,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
