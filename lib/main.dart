// ignore_for_file: prefer_const_constructors, unused_label, unused_local_variable, unnecessary_this, unnecessary_new, sort_child_properties_last, unused_element, unused_field, prefer_final_fields, avoid_unnecessary_containers, use_build_context_synchronously, no_leading_underscores_for_local_identifiers

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
import 'package:zone_on/start_page.dart';

import 'BackgroundCollectingTask.dart';
import 'DiscoveryPage.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Maps',
      home: StartPage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final BluetoothDevice? server;
  const MyHomePage({this.server});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _Message {
  int whom;
  String text;

  _Message(this.whom, this.text);
}

class _MyHomePageState extends State<MyHomePage> {
  static final clientID = 0;
  BluetoothConnection? connection;

  List<_Message> messages = List<_Message>.empty(growable: true);
  String _messageBuffer = '';

  final TextEditingController textEditingController =
      new TextEditingController();
  final ScrollController listScrollController = new ScrollController();
  bool isConnecting = true;
  bool get isConnected => (connection?.isConnected ?? false);
  bool isDisconnecting = false;
  MethodChannel? _methodChannel;
  List<String> firstRow = ['Time Stamp', 'User Latitude', 'User Longtitude'];
  bool _isElevated = false;
  bool _isElevated2 = false;
  Data data = Data();
  StreamSubscription? _locationSubscription;
  Location _locationTracker = Location();
  bool inProgress = false;
  BackgroundCollectingTask? _collectingTask;
  // Marker? marker;
  // Circle? circle;
  static const maxSeconds = 00;

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

    if (widget.server != null) {
      BluetoothConnection.toAddress(widget.server?.address).then((_connection) {
        print('Connected to the device');
        connection = _connection;
        setState(() {
          isConnecting = false;
          isDisconnecting = false;
        });

        connection!.input!.listen(_onDataReceived).onDone(() {
          // Example: Detect which side closed the connection
          // There should be `isDisconnecting` flag to show are we are (locally)
          // in middle of disconnecting process, should be set before calling
          // `dispose`, `finish` or `close`, which all causes to disconnect.
          // If we except the disconnection, `onDone` should be fired as result.
          // If we didn't except this (no flag set), it means closing by remote.
          if (isDisconnecting) {
            print('Disconnecting locally!');
          } else {
            print('Disconnected remotely!');
          }
          if (this.mounted) {
            setState(() {});
          }
        });
      }).catchError((error) {
        print('Cannot connect, exception occured');
        print(error);
      });
    }
  }

  Future<void> reasume() async {
    inProgress = true;
    connection?.output.add(ascii.encode('S'));
    await connection?.output.allSent;
  }

  void _sendMessage(String text) async {
    text = text.trim();

    if (text.length > 0) {
      try {
        connection?.output.add(Uint8List.fromList(ascii.encode(text + "\r\n")));
        await connection?.output.allSent;
        print("data Recieved");

        setState(() {
          messages.add(_Message(clientID, text));
        });
      } catch (e) {
        // Ignore error, but notify state
        setState(() {
          print("data failed");
        });
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

    // Create message if there is new line character
    String dataString = String.fromCharCodes(buffer);
    int index = buffer.indexOf(13);
    if (~index != 0) {
      setState(() {
        messages.add(
          _Message(
            1,
            backspacesCounter > 0
                ? _messageBuffer.substring(
                    0, _messageBuffer.length - backspacesCounter)
                : _messageBuffer + dataString.substring(0, index),
          ),
        );
        _messageBuffer = dataString.substring(index);
      });
    } else {
      _messageBuffer = (backspacesCounter > 0
          ? _messageBuffer.substring(
              0, _messageBuffer.length - backspacesCounter)
          : _messageBuffer + dataString);
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
    if (isConnected) {
      isDisconnecting = true;
      connection?.dispose();
      connection = null;
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) {
                  return StartPage();
                },
              ),
            );
          },
          color: Color.fromARGB(255, 48, 48, 48),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(12),
          ),
        ),
        shadowColor: Colors.transparent,
        backgroundColor: Color.fromARGB(0, 255, 255, 255).withOpacity(0),
        title: Container(
          width: 120,
          child: Image.asset(
            'assets/zon.png',
            color: Color.fromARGB(255, 48, 48, 48),
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
                  color: Color.fromARGB(255, 0, 201, 167),
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
              roadColor: Color.fromARGB(255, 0, 201, 167),
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
            padding: EdgeInsets.only(bottom: height / 1.35, left: width / 1.8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    widget.server == null
                        ? Container(
                            width: 110,
                            height: 35,
                            decoration: BoxDecoration(
                                border: Border.all(
                                  color: Color.fromARGB(255, 0, 201, 167),
                                ),
                                borderRadius: BorderRadius.circular(
                                    20) // use instead of BorderRadius.all(Radius.circular(20))
                                ),
                            child: Center(
                              child: Text(
                                "just for tracking",
                                style: GoogleFonts.openSans(
                                    textStyle: Theme.of(context)
                                        .textTheme
                                        .displayMedium,
                                    color: Color.fromARGB(255, 68, 68, 68),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 10),
                              ),
                            ),
                          )
                        : Container(
                            width: 110,
                            height: 35,
                            decoration: BoxDecoration(
                                border: Border.all(
                                  color: Color.fromARGB(255, 0, 201, 167),
                                ),
                                borderRadius: BorderRadius.circular(
                                    20) // use instead of BorderRadius.all(Radius.circular(20))
                                ),
                            child: Center(
                              child: Text(
                                "${widget.server?.address}",
                                style: GoogleFonts.openSans(
                                    textStyle: Theme.of(context)
                                        .textTheme
                                        .displayMedium,
                                    color: Color.fromARGB(255, 68, 68, 68),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 10),
                              ),
                            ),
                          ),
                    SizedBox(
                      width: 12,
                    ),
                    SizedBox(
                      width: 40,
                      child: FloatingActionButton(
                          heroTag: '123',
                          backgroundColor: Color.fromARGB(255, 0, 201, 167),
                          child: Icon(
                            Icons.mode_comment_outlined,
                            color: Color.fromARGB(255, 255, 255, 255),
                            size: 22,
                          ),
                          onPressed: () {
                            // Start scanning
                          }),
                    ),
                  ],
                ),
                SizedBox(
                  height: 2,
                ),
                widget.server != null
                    ? Row(
                        children: [
                          Container(
                            width: 110,
                            height: 35,
                            decoration: BoxDecoration(
                                border: Border.all(
                                  color: Color.fromARGB(255, 0, 201, 167),
                                ),
                                borderRadius: BorderRadius.circular(
                                    20) // use instead of BorderRadius.all(Radius.circular(20))
                                ),
                            child: Center(
                              child: Text(
                                "${widget.server?.name}",
                                style: GoogleFonts.openSans(
                                    textStyle: Theme.of(context)
                                        .textTheme
                                        .displayMedium,
                                    color: Color.fromARGB(255, 68, 68, 68),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 12,
                          ),
                          SizedBox(
                            width: 40,
                            child: FloatingActionButton(
                                heroTag: '435',
                                backgroundColor:
                                    Color.fromARGB(255, 0, 201, 167),
                                child: Icon(
                                  Icons.sensors,
                                  color: Color.fromARGB(255, 255, 255, 255),
                                  size: 22,
                                ),
                                onPressed: () {
                                  // Start scanning
                                }),
                          ),
                        ],
                      )
                    : Text("")
              ],
            ),
          ),
          Row(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                    width / 25, height - height / 9.6, 0, 0),
                child: FloatingActionButton(
                    backgroundColor: Color.fromARGB(255, 48, 48, 48),
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
