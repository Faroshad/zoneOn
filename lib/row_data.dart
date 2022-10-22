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

class MyData {
  dynamic listtimeStamp;
  double? userLatitude;
  double? userLongtitude;
  double? temperature;
  double? heatIndex;
  double? humidity;
  double? ppm;
  double? rZero;
  double? light;
  double? sound;

  MyData(
      {this.listtimeStamp,
      this.userLatitude,
      this.userLongtitude,
      this.temperature,
      this.heatIndex,
      this.humidity,
      this.ppm,
      this.rZero,
      this.light,
      this.sound});
  // GoogleMapController? _controller;
  List<MyData> rowData = [];
}
