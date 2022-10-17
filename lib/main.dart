// ignore_for_file: prefer_const_constructors, unused_label, unused_local_variable, unnecessary_this, unnecessary_new, sort_child_properties_last, unused_element, unused_field, prefer_final_fields, avoid_unnecessary_containers, use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:location/location.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xl;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zone_on/SelectBondedDevicePage.dart';
import 'package:zone_on/row_data.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:scoped_model/scoped_model.dart';

import 'BackgroundCollectingTask.dart';
import 'DiscoveryPage.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Maps',
      home: MyHomePage(),
    );
  }
}

class _Message {
  int whom;
  String text;

  _Message(this.whom, this.text);
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  MethodChannel? _methodChannel;
  List<String> firstRow = ['Time Stamp', 'User Latitude', 'User Longtitude'];
  bool _isElevated = false;
  bool _isElevated2 = false;
  Data data = Data();
  StreamSubscription? _locationSubscription;
  Location _locationTracker = Location();
  String _address = "...";
  String _name = "...";
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  // BluetoothDevice? device;

  bool _autoAcceptPairingRequests = false;
  BackgroundCollectingTask? _collectingTask;
  // Marker? marker;
  // Circle? circle;
  static const maxSeconds = 00;
  BluetoothConnection? connection;

  int second = maxSeconds;
  Timer? timer;

  MapController controller = MapController();
  // GoogleMapController? _controller;
  final xl.Workbook workbook = xl.Workbook();
  Future<void> createExcel() async {
    final xl.Worksheet sheet = workbook.worksheets[0];
    sheet.importList(firstRow, 1, 1, false);

    sheet.importList(data.userLatitude, 2, 2, true);
    sheet.importList(data.userLongtitude, 2, 3, true);
    sheet.importList(data.listtimeStamp, 2, 1, true);

    //Save and launch the excel.
    final List<int> bytes = workbook
        .saveAsStream(); //Get the storage folder location using path_provider package.

    final Directory? directory = await getExternalStorageDirectory();
    final String path = directory!.path;
    final File file = File('$path/ImportData.xlsx');
    await file.writeAsBytes(bytes, flush: true);

    //Launch the file (used open_file package)
    await OpenFile.open('$path/ImportData.xlsx');

    //Dispose the document.
    workbook.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Get current state
    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });

    Future.doWhile(() async {
      // Wait if adapter not enabled
      if ((await FlutterBluetoothSerial.instance.isEnabled) ?? false) {
        return false;
      }
      await Future.delayed(Duration(milliseconds: 0xDD));
      return true;
    }).then((_) {
      // Update the address field
      FlutterBluetoothSerial.instance.address.then((address) {
        setState(() {
          _address = address!;
        });
      });
    });

    FlutterBluetoothSerial.instance.name.then((name) {
      setState(() {
        _name = name!;
      });
    });

    // Listen for futher state changes
    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;

        // Discoverable mode is disabled when Bluetooth gets disabled
      });
    });
  }

  void _sendMessage(String text) async {
    text = "S";
    if (text.length > 0) {
      try {
        connection!.output.add(Uint8List.fromList(utf8.encode(text + "\r\n")));
        await connection!.output.allSent;
      } catch (e) {
        // Ignore error, but notify state
        setState(() {});
      }
    }
  }

  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    // Apply backspace control character
    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      } else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        } else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }
  }

  // void startTimer() {
  //   timer = Timer.periodic(Duration(seconds: 1), (timer) {
  //     setState(() {
  //       // userLatitude.add(myLatitude);
  //       // userLongtitude.add(myLongtitude);
  //       // myTimes.add(second);

  //       listtimeStamp.add('${DateTime.now()}');

  //       second++;
  //     });
  //   });
  // }

  // void stopTimer() {
  //   listtimeStamp.add('${DateTime.now()}');
  //   timer!.cancel();
  // }

  // static final CameraPosition initialLocation = CameraPosition(
  //   target: LatLng(29.591768, 52.583698),
  //   zoom: 14.4746,
  // );

  // Future<Uint8List> getMarker() async {
  //   ByteData byteData =
  //       await DefaultAssetBundle.of(context).load("assets/dot2.png");
  //   return byteData.buffer.asUint8List();
  // }

  // void updateMarkerAndCircle(LocationData newLocalData, Uint8List imageData) {
  //   LatLng latlng = LatLng(newLocalData.latitude, newLocalData.longitude);
  //   this.setState(() {
  //     marker = Marker(
  //         markerId: MarkerId("home"),
  //         position: latlng,
  //         rotation: newLocalData.heading,
  //         draggable: false,
  //         zIndex: 2,
  //         flat: true,
  //         anchor: Offset(0.5, 0.5),
  //         icon: BitmapDescriptor.fromBytes(imageData));
  //     circle = Circle(
  //         circleId: CircleId("car"),
  //         radius: newLocalData.accuracy,
  //         strokeWidth: 2,
  //         zIndex: 1,
  //         strokeColor: Color.fromARGB(255, 255, 255, 255),
  //         center: latlng,
  //         fillColor: Color.fromARGB(123, 241, 0, 68).withAlpha(60));
  //   });
  // }

  void startScan() async {
    var status = await Permission.bluetoothConnect.status;

    if (status.isDenied) {
      // We didn't ask for permission yet or the permission has been denied before but not permanently.
    }

// You can can also directly ask the permission about its status.
    if (await Permission.bluetoothConnect.isRestricted) {
      // The OS restricts access, for example because of parental controls.
    }

    if (await Permission.bluetoothConnect.request().isGranted) {
      // Navigator.push(
      //   context,
      //   MaterialPageRoute(
      //     builder: (context) => FlutterBlueApp(),
      //   ),
      // );
      // Either the permission was already granted before or the user just granted it.
    }
  }

  void getCurrentLocation() async {
    try {
      // Uint8List imageData = await getMarker();
      var location = await _locationTracker.getLocation();
      await controller.currentLocation();
      // MapController controller = MapController(
      //   initMapWithUserPosition: false,
      //   initPosition: GeoPoint(
      //     latitude: 29.591768,
      //     longitude: 52.583698,
      //   ),
      // );
      // Future<bool> changeSettings(
      //         {LocationAccuracy accuracy = LocationAccuracy.HIGH,
      //         int interval = 1000,
      //         double distanceFilter = 0}) =>
      //     _methodChannel!.invokeMethod('changeSettings', {
      //       "accuracy": accuracy.index,
      //       "interval": interval,
      //       "distanceFilter": distanceFilter
      //     }).then((result) => result == 1);

      // updateMarkerAndCircle(location, imageData);

      if (_locationSubscription != null) {
        _locationSubscription!.cancel();
      }

      // _locationSubscription =
      //     _locationTracker.onLocationChanged().listen((newLocalData) {
      //   // setState(() {
      //   //   myLat = "${newLocalData.latitude}";
      //   //   myLong = "${newLocalData.longitude}";
      //   //   userLatitude.add("$myLat");
      //   //   userLongtitude.add("$myLong");
      //   // });

      //   // if (_controller != null) {
      //   //   _controller!.animateCamera(CameraUpdate.newCameraPosition(
      //   //       new CameraPosition(
      //   //           bearing: 180,
      //   //           target: LatLng(newLocalData.latitude, newLocalData.longitude),
      //   //           tilt: 0,
      //   //           zoom: 18.00)));
      //   //   // updateMarkerAndCircle(newLocalData, imageData);
      //   //   setState(() {});
      //   // }
      // });
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        debugPrint("Permission Denied");
      }
    }
  }

  @override
  void dispose() {
    FlutterBluetoothSerial.instance.setPairingRequestHandler(null);
    _collectingTask?.dispose();
    timer?.cancel();
    super.dispose();
    if (_locationSubscription != null) {
      _locationSubscription!.cancel();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Color.fromARGB(0, 255, 255, 255),
      appBar: AppBar(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(12),
          ),
        ),
        shadowColor: Colors.transparent,
        backgroundColor: Color.fromARGB(255, 255, 255, 255).withOpacity(1),
        title: Padding(
          padding: EdgeInsets.symmetric(horizontal: width / 20),
          child: Row(
            children: [
              Icon(
                Icons.crop_free_sharp,
                color: Colors.black,
              ),
              SizedBox(
                width: 10,
              ),
              Text(
                "ZoneOn",
                style: GoogleFonts.openSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: Color.fromARGB(255, 39, 39, 39)),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          OSMFlutter(
            controller: controller,
            trackMyPosition: true,
            initZoom: 12,
            minZoomLevel: 10,
            maxZoomLevel: 19,
            stepZoom: 2.0,
            userLocationMarker: UserLocationMaker(
              personMarker: MarkerIcon(
                icon: Icon(
                  Icons.circle,
                  color: Color.fromARGB(255, 0, 137, 201),
                  size: 52,
                ),
              ),
              directionArrowMarker: MarkerIcon(
                icon: Icon(
                  Icons.circle_outlined,
                  size: 48,
                ),
              ),
            ),
            roadConfiguration: RoadConfiguration(
              startIcon: MarkerIcon(
                icon: Icon(
                  Icons.circle_outlined,
                  size: 64,
                  color: Colors.brown,
                ),
              ),
              roadColor: Colors.yellowAccent,
            ),
            markerOption: MarkerOption(
                defaultMarker: MarkerIcon(
              icon: Icon(
                Icons.circle_outlined,
                color: Colors.blue,
                size: 56,
              ),
            )),
          ),
          Container(
            padding: EdgeInsets.only(bottom: height / 1.5, right: 23),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Transform.scale(
                  scale: 1.2,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.only(right: 28),
                    selectedTileColor: Color.fromARGB(255, 0, 137, 201),
                    // title: const Text('Enable Bluetooth'),
                    value: _bluetoothState.isEnabled,
                    onChanged: (bool value) {
                      // Do the request and update with the true value then
                      future() async {
                        // async lambda seems to not working
                        if (value)
                          await FlutterBluetoothSerial.instance.requestEnable();
                        else
                          await FlutterBluetoothSerial.instance
                              .requestDisable();
                      }

                      future().then((_) {
                        setState(() {});
                      });
                    },
                  ),
                ),
                SizedBox(
                  height: 5,
                ),
                // FloatingActionButton(
                //     heroTag: 'deboug',
                //     backgroundColor: Color.fromARGB(255, 0, 137, 201),
                //     child: Icon(
                //       Icons.bluetooth,
                //       color: Color.fromARGB(255, 255, 255, 255),
                //       size: 30,
                //     ),
                //     onPressed: () {
                //       // Start scanning
                //       startScan();
                //     }),
                // SizedBox(
                //   height: 15,
                // ),
                FloatingActionButton(
                  heroTag: 's',
                  backgroundColor: Color.fromARGB(255, 0, 137, 201),
                  child: Icon(
                    Icons.search_rounded,
                    color: Color.fromARGB(255, 255, 255, 255),
                    size: 30,
                  ),
                  onPressed: () async {
                    final BluetoothDevice? selectedDevice =
                        await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) {
                          return DiscoveryPage();
                        },
                      ),
                    );

                    if (selectedDevice != null) {
                      print('Discovery -> selected ' + selectedDevice.address);
                    } else {
                      print('Discovery -> no device selected');
                    }
                  },
                ),
                SizedBox(
                  height: 15,
                ),
                FloatingActionButton(
                  heroTag: 's1',
                  backgroundColor: Color.fromARGB(255, 0, 137, 201),
                  child: Icon(
                    Icons.bluetooth_connected,
                    color: Color.fromARGB(255, 255, 255, 255),
                    size: 30,
                  ),
                  onPressed: () async {
                    final BluetoothDevice? selectedDevice =
                        await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) {
                          return SelectBondedDevicePage(
                              checkAvailability: false);
                        },
                      ),
                    );

                    if (selectedDevice != null) {
                      print('Connect -> selected ' + selectedDevice.address);
                    } else {
                      print('Connect -> no device selected');
                    }
                  },
                ),
              ],
            ),
          ),
          Row(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                    width / 25, height - height / 9.6, 0, 0),
                child: FloatingActionButton(
                    backgroundColor: Color.fromARGB(255, 0, 0, 0),
                    child: Icon(Icons.location_searching,
                        color: Color.fromARGB(255, 255, 255, 255)),
                    onPressed: () {
                      getCurrentLocation();
                    }),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    width / 50, height - height / 9.6, 0, 0),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isElevated = !_isElevated;
                      if (_isElevated) {
                        data.startTimer();
                      } else {
                        data.stopTimer();

                        second = maxSeconds;
                      }
                    });
                  },
                  child: AnimatedContainer(
                    child: Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(
                            _isElevated
                                ? Icons.radio_button_checked
                                : Icons.stop,
                          ),
                        ),
                        Text(
                          _isElevated ? 'Stop' : 'Start',
                          style: GoogleFonts.openSans(
                              textStyle:
                                  Theme.of(context).textTheme.displayMedium,
                              color: Color.fromARGB(255, 48, 48, 48),
                              fontWeight: FontWeight.w700,
                              fontSize: 18),
                        ),
                        _isElevated
                            ? Padding(
                                padding: const EdgeInsets.only(left: 20),
                                child: Text(
                                  '${data.second}',
                                  style: GoogleFonts.openSans(
                                      textStyle: Theme.of(context)
                                          .textTheme
                                          .displayMedium,
                                      color: Color.fromARGB(255, 0, 0, 0),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16),
                                ),
                              )
                            : Text("")
                      ],
                    ),
                    // Providing duration parameter
                    // to create animation
                    duration: const Duration(
                      milliseconds: 100,
                    ),
                    height: 50,
                    width: _isElevated ? width / 2.5 : width / 3.2,
                    decoration: BoxDecoration(
                      color: Color.fromARGB(255, 255, 255, 255),
                      borderRadius: BorderRadius.circular(22),

                      // If widget is not elevated, elevate it.
                      boxShadow: _isElevated
                          ?
                          // Elevation Effect
                          [
                              BoxShadow(
                                color: Color.fromARGB(61, 0, 0, 0)
                                    .withOpacity(0.2),
                                // Shadow for bottom right corner
                                offset: Offset(3, 3),
                                blurRadius: 3,
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: Color.fromARGB(69, 36, 36, 36)
                                    .withOpacity(0.1),
                                // Shadow for top left corner
                                offset: Offset(3, 3),
                                blurRadius: 3,
                                spreadRadius: 1,
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Color.fromARGB(61, 133, 133, 133)
                                    .withOpacity(0.2),
                                // Shadow for bottom right corner
                                offset: Offset(3, 3),
                                blurRadius: 3,
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: Color.fromARGB(61, 133, 133, 133)
                                    .withOpacity(0.1),
                                // Shadow for top left corner
                                offset: Offset(3, 3),
                                blurRadius: 3,
                                spreadRadius: 1,
                              ),
                            ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    width / 50, height - height / 9.6, 0, 0),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isElevated2 = !_isElevated2;
                      createExcel();
                    });
                  },
                  child: AnimatedContainer(
                    child: Center(
                      child: Text(
                        "Save",
                        style: GoogleFonts.openSans(
                            textStyle:
                                Theme.of(context).textTheme.displayMedium,
                            color: Color.fromARGB(255, 97, 97, 97),
                            fontWeight: FontWeight.w700,
                            fontSize: 18),
                      ),
                    ),

                    // Providing duration parameter
                    // to create animation
                    duration: const Duration(
                      milliseconds: 100,
                    ),
                    height: 50,
                    width: width / 4.2,
                    decoration: BoxDecoration(
                      color: Color.fromARGB(255, 255, 255, 255).withOpacity(1),
                      borderRadius: BorderRadius.circular(22),

                      // If widget is not elevated, elevate it.
                      boxShadow: _isElevated2
                          ?
                          // Elevation Effect
                          [
                              BoxShadow(
                                color: Color.fromARGB(61, 133, 133, 133)
                                    .withOpacity(0.4),
                                // Shadow for bottom right corner
                                offset: Offset(2, 2),
                                blurRadius: 5,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: Color.fromARGB(61, 133, 133, 133)
                                    .withOpacity(0.3),
                                // Shadow for top left corner
                                offset: Offset(-2, -2),
                                blurRadius: 5,
                                spreadRadius: 2,
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Color.fromARGB(61, 133, 133, 133)
                                    .withOpacity(0.4),
                                // Shadow for bottom right corner
                                offset: Offset(2, 2),
                                blurRadius: 3,
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: Color.fromARGB(61, 133, 133, 133)
                                    .withOpacity(0.3),
                                // Shadow for top left corner
                                offset: Offset(-2, -2),
                                blurRadius: 3,
                                spreadRadius: 1,
                              ),
                            ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
