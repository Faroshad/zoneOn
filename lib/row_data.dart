// ignore_for_file: unused_element, unused_local_variable, avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
// import 'package:flutter_blue/flutter_blue.dart';
import 'package:location/location.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xl;
import 'package:path_provider/path_provider.dart';

import 'dart:async';
import 'dart:io';

class Data {
  List<dynamic> listtimeStamp = [];
  List<double> userLatitude = [];
  List<double> userLongtitude = [];
  double? myLong = 0;
  double? myLat = 0;
  MethodChannel? _methodChannel;
  StreamSubscription? _locationSubscription;
  Location _locationTracker = Location();
  // GoogleMapController? _controller;
  static const maxSeconds = 00;
  int second = maxSeconds;
  Timer? timer;
  // void startBluetooth() async {
  //   try {
  //     BluetoothConnection connection =
  //         await BluetoothConnection.toAddress(address);
  //     print('Connected to the device');

  //     connection.input?.listen((Uint8List data) {
  //       print('Data incoming: ${ascii.decode(data)}');
  //       connection.output.add(data); // Sending data

  //       if (ascii.decode(data).contains('!')) {
  //         connection.finish(); // Closing connection
  //         print('Disconnecting by local host');
  //       }
  //     }).onDone(() {
  //       print('Disconnected by remote request');
  //     });
  //   } catch (exception) {
  //     print('Cannot connect, exception occured');
  //   }
  // }

  void startTimer() {
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      // userLatitude.add(myLatitude);
      // userLongtitude.add(myLongtitude);
      // myTimes.add(second);

      listtimeStamp.add("${DateTime.now()}");
      // _locationSubscription =
      //     _locationTracker.onLocationChanged().listen((newLocalData) {
      //   myLat = newLocalData.latitude;
      //   myLong = newLocalData.longitude;
      // });
      userLatitude.add(myLat!);
      userLongtitude.add(myLong!);
      void getCurrentLocation() async {
        try {
          var location = await _locationTracker.getLocation();
          // Future<bool> changeSettings(
          //         {LocationAccuracy accuracy = LocationAccuracy.HIGH,
          //         int interval = 1000,
          //         double distanceFilter = 0}) =>
          //     _methodChannel!.invokeMethod('changeSettings', {
          //       "accuracy": accuracy.index,
          //       "interval": interval,
          //       "distanceFilter": distanceFilter
          //     }).then((result) => result == 1);

          // if (_locationSubscription != null) {
          //   _locationSubscription!.cancel();
          // }

        } on PlatformException catch (e) {
          if (e.code == 'PERMISSION_DENIED') {
            debugPrint("Permission Denied");
          }
        }
      }

      second++;
    });
  }

  void stopTimer() {
    listtimeStamp.add("${DateTime.now()}");
    userLatitude.add(myLat!);
    userLongtitude.add(myLong!);
    timer!.cancel();
  }
}
