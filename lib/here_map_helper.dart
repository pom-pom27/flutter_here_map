import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/gestures.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/core.dart';
import 'dart:typed_data';
import 'package:here_sdk/routing.dart' as here;

import 'package:here_sdk/routing.dart';

class HereMapHelper {
  MapPolyline _mapPolyline;
  MapPolygon _mapPolygon;
  MapPolygon _mapCircle;
  HereMapController _hereMapController;

  List<MapMarker> _mapMarkerList = [];
  List<GeoCoordinates> coordinates = [];

  RoutingEngine _routingEngine;

  MapImage _poiMapImage;

  HereMapHelper(HereMapController hereMapController) {
    _hereMapController = hereMapController;

    double distanceToEarthInMeters = 5000;
    hereMapController.camera.lookAtPointWithDistance(
        GeoCoordinates(52.530932, 13.384915), distanceToEarthInMeters);

    _setLongPressGestureHandler();

    _setTapGestureHandler();

    try {
      _routingEngine = RoutingEngine();
    } on InstantiationException {
      throw ("Initialization of RoutingEngine failed.");
    }
  }

  void dispose() {
    _hereMapController.finalize();
  }

  Future<Uint8List> _loadFileAsUint8List(String assetPathToFile) async {
    // The path refers to the assets directory as specified in pubspec.yaml.
    ByteData fileData = await rootBundle.load(assetPathToFile);
    return Uint8List.view(fileData.buffer);
  }

  void _setTapGestureHandler() {
    _hereMapController.gestures.tapListener =
        TapListener.fromLambdas(lambda_onTap: (Point2D touchPoint) {
      final geo = _hereMapController.viewToGeoCoordinates(touchPoint);

      if (coordinates.length > 3) {
        coordinates.clear();
        _hereMapController.mapScene.removeMapPolygon(_mapPolygon);
        _mapPolygon.release();
        return;
      }

      coordinates.add(geo);
      if (coordinates.length == 4) {
        print('object');
        _mapPolygon = _createPolygon();
        _hereMapController.mapScene.addMapPolygon(_mapPolygon);
      }
      print(coordinates.length.toString());

      // _createPolygon();
    });
  }

  void _setLongPressGestureHandler() {
    _hereMapController.gestures.longPressListener =
        LongPressListener.fromLambdas(lambda_onLongPress:
            (GestureState gestureState, Point2D touchPoint) {
      final geo = _hereMapController.viewToGeoCoordinates(touchPoint);

      if (gestureState == GestureState.begin) {
        _addPOIMapMarker(geo);
      }
    });
  }

  void clearMarkers() {
    if (_mapMarkerList.isNotEmpty) {
      for (var item in _mapMarkerList) {
        _hereMapController.mapScene.removeMapMarker(item);
      }
      _mapMarkerList.clear();
      _hereMapController.mapScene.removeMapPolyline(_mapPolyline);
    }

    if (_mapPolygon != null) {
      coordinates.clear();
      _hereMapController.mapScene.removeMapPolygon(_mapPolygon);
    }
    _hereMapController.mapScene.release();
  }

  Future<void> _addPOIMapMarker(GeoCoordinates geoCoordinates) async {
    // Reuse existing MapImage for new map markers.
    if (_poiMapImage == null) {
      Uint8List imagePixelData = await _loadFileAsUint8List('assets/poi.png');
      _poiMapImage =
          MapImage.withPixelDataAndImageFormat(imagePixelData, ImageFormat.png);
    }

    // By default, the anchor point is set to 0.5, 0.5 (= centered).
    // Here the bottom, middle position should point to the location.
    Anchor2D anchor2D = Anchor2D.withHorizontalAndVertical(0.5, 1);

    print(_mapMarkerList.length.toString());

    if (_mapMarkerList.length > 1) {
      clearMarkers();

      final marker =
          MapMarker.withAnchor(geoCoordinates, _poiMapImage, anchor2D);
      marker.drawOrder = 0;
      _mapMarkerList.add(marker);
      _hereMapController.mapScene.addMapMarker(marker);
    } else {
      final marker =
          MapMarker.withAnchor(geoCoordinates, _poiMapImage, anchor2D);
      marker.drawOrder = 1;
      _mapMarkerList.add(marker);

      _hereMapController.mapScene.addMapMarker(marker);
    }

    await addRoute();
  }

  Future<void> addRoute() async {
    if (_mapMarkerList.length > 1) {
      var startGeoCoordinates = _mapMarkerList[0].coordinates;
      var destinationGeoCoordinates = _mapMarkerList[1].coordinates;
      var startWaypoint = Waypoint.withDefaults(startGeoCoordinates);
      var destinationWaypoint =
          Waypoint.withDefaults(destinationGeoCoordinates);

      List<Waypoint> waypoints = [startWaypoint, destinationWaypoint];

      await _routingEngine
          .calculateCarRoute(waypoints, CarOptions.withDefaults(),
              (RoutingError routingError, List<here.Route> routeList) async {
        if (routingError == null) {
          here.Route route = routeList.first;
          _showRouteOnMap(route);
        } else {
          var error = routingError.toString();
          print(error);
        }
      });
    }
  }

  _showRouteOnMap(here.Route route) {
    // Show route as polyline.
    GeoPolyline routeGeoPolyline = GeoPolyline(route.polyline);

    double widthInPixels = 20;
    MapPolyline routeMapPolyline = MapPolyline(
        routeGeoPolyline, widthInPixels, Color.fromARGB(160, 0, 144, 138));

    _hereMapController.mapScene.addMapPolyline(routeMapPolyline);
    _mapPolyline = routeMapPolyline;
  }

  MapPolygon _createPolygon() {
    GeoPolygon geoPolygon;
    try {
      geoPolygon = GeoPolygon(coordinates);
    } on InstantiationException {
      // Less than three vertices.
      return null;
    }

    Color fillColor = Color.fromARGB(160, 0, 144, 138);
    MapPolygon mapPolygon = MapPolygon(geoPolygon, fillColor);

    return mapPolygon;
  }
}
