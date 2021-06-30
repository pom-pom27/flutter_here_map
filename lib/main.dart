import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';

import 'here_map_helper.dart';

void main() {
  SdkContext.init(IsolateOrigin.main);
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  HereMapHelper _hereMapHelper;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HERE SDK for Flutter - Hello Map!',
      home: Scaffold(
        body: SafeArea(
          child: HereMap(
            onMapCreated: _onMapCreated,
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _hereMapHelper.clearMarkers();
          },
          child: Icon(Icons.delete),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _hereMapHelper.dispose();
  }

  void _onMapCreated(HereMapController hereMapController) {
    hereMapController.mapScene.loadSceneForMapScheme(MapScheme.normalDay,
        (MapError error) {
      if (error == null) {
        _hereMapHelper = HereMapHelper(hereMapController);
      } else {
        print("Map scene not loaded. MapError: " + error.toString());
      }
    });
  }
}
