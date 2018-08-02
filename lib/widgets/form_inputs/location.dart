import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:map_view/map_view.dart';
import 'package:http/http.dart' as http;

import '../../app_config.dart';
import '../../models/location_data.dart';

class LocationInput extends StatefulWidget {
  final Function setLocation;

  LocationInput(this.setLocation);

  @override
  State<StatefulWidget> createState() {
    return _LocationInputState();
  }
}

class _LocationInputState extends State<LocationInput> {
  Uri _staticMapUri;
  LocationData _locationData;
  final FocusNode _addressInputFocusNode = FocusNode();
  final TextEditingController _addressInputController = TextEditingController();

  @override
  void initState() {
    _addressInputFocusNode.addListener(_updateLocation);
    super.initState();
  }

  @override
  void dispose() {
    _addressInputFocusNode.removeListener(_updateLocation);
    super.dispose();
  }

  void getStaticMap(String address) async {
    if (address.isEmpty) {
      setState(() {
        _staticMapUri = null;
      });
      widget.setLocation(null);
      return;
    }
    final Uri uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {'address': address, 'key': AppConfig.mapsAPI},
    );
    final http.Response response = await http.get(uri);
    final decodedResponse = jsonDecode(response.body);
    final formattedAddress = decodedResponse['results'][0]['formatted_address'];
    final coords = decodedResponse['results'][0]['geometry']['location'];
    _locationData = LocationData(
      address: formattedAddress,
      latitude: coords['lat'],
      longitude: coords['lng'],
    );

    final StaticMapProvider staticMapProvider =
        StaticMapProvider(AppConfig.mapsAPI);
    final Uri staticMapUri = staticMapProvider.getStaticUriWithMarkers(
      [
        Marker('postion', 'Postion', _locationData.latitude,
            _locationData.longitude)
      ],
      center: Location(_locationData.latitude, _locationData.longitude),
      width: 500,
      height: 300,
      maptype: StaticMapViewType.roadmap,
    );

    widget.setLocation(_locationData);
    setState(() {
      _addressInputController.text = _locationData.address;
      _staticMapUri = staticMapUri;
    });
  }

  void _updateLocation() {
    if (!_addressInputFocusNode.hasFocus) {
      getStaticMap(_addressInputController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TextFormField(
          focusNode: _addressInputFocusNode,
          controller: _addressInputController,
          validator: (String value) {
            if (_locationData == null || value.isEmpty) {
              return 'No valid location found';
            }
          },
          decoration: InputDecoration(labelText: 'Address'),
        ),
        SizedBox(
          height: 10.0,
        ),
        _staticMapUri != null
            ? Image.network(_staticMapUri.toString())
            : Container(),
      ],
    );
  }
}
