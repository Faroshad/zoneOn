// ignore_for_file: prefer_const_constructors, unused_label, unused_local_variable, unnecessary_this, unnecessary_new, sort_child_properties_last, unused_element, unused_field, prefer_final_fields, avoid_unnecessary_containers, use_build_context_synchronously, no_leading_underscores_for_local_identifiers

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:location/location.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xl;
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_streamer/audio_streamer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zone_on/SelectBondedDevicePage.dart';
import 'package:zone_on/row_data.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:zone_on/start_page.dart';
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
  bool _isRecording = false;

  StreamSubscription<NoiseReading>? _noiseSubscription;

  NoiseMeter? _noiseMeter;
  BluetoothConnection? connection;
  List<dynamic> listTimeStamp = [];
  List<double> listLong = [];
  List<double> listLat = [];
  List<String> listTemp = [];
  List<String> listHitindex = [];
  List<String> listHumidity = [];
  List<String> listSound = [];
  List<String> listPpm = [];
  List<String> listRzero = [];
  List<String> listLight = [];
  List<double> listSoundNew = [];
  List<double> listPitch = [];
  List<double> listRoll = [];
  List<double> listYaw = [];
  double? result;
  Color yellow = Color.fromARGB(255, 255, 230, 0);
  Color pink = Color.fromARGB(255, 255, 0, 98);
  Color greenBlue = Color.fromARGB(255, 0, 201, 167);
  Color darkGray = Color.fromARGB(255, 46, 46, 46);

  double? batteryLife = 5;
  double? oldBatteryLife = 3;

  List<_Message> messages = List<_Message>.empty(growable: true);
  String _messageBuffer = '';

  MethodChannel? _methodChannel;
  StreamSubscription? _locationSubscription;
  Location _locationTracker = Location();
  final TextEditingController textEditingController =
      new TextEditingController();
  final ScrollController listScrollController = new ScrollController();
  bool isConnecting = true;
  bool get isConnected => (connection?.isConnected ?? false);
  bool isDisconnecting = false;

  List<String> firstRow = [
    'Time Stamp',
    'User Latitude',
    'User Longtitude',
    "Temperature",
    "Heat index",
    "Humidity",
    "Sound",
    "ppm",
    "rZero",
    "Light",
    "pitch",
    "roll",
    "yaw"
  ];
  bool _isElevated = false;
  bool _isElevated2 = false;
  double myLat = 0;
  double myLong = 0;

  List sample = [];
  bool inProgress = false;
  String situation = '';

  MyData myData = MyData();
  int seconds = 0, minutes = 0;
  String digitSeconds = "00", digitMinutes = "00";
  Timer? _timer;
  bool started = false;

  void stoplaps() {
    _timer!.cancel();
    setState(() {
      started = false;
    });
  }

  void startlaps() {
    started = true;
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      int localSeconds = seconds;
      int localMinutes = minutes;
      if (localSeconds > 58) {
        localMinutes++;
        localSeconds = 0;
      } else {
        localSeconds++;
      }
      setState(() {
        seconds = localSeconds;
        minutes = localMinutes;
        digitSeconds = (seconds >= 10) ? "$seconds" : "0$seconds";
        digitMinutes = (minutes >= 10) ? "$minutes" : "0$minutes";
      });
    });
  }

  static const maxSeconds = 00;
  int second = maxSeconds;
  Timer? timer;
  Timer? timer2;

  MapController controller = MapController();
  // GoogleMapController? _controller;
  final xl.Workbook workbook = xl.Workbook();
  Future<void> createExcel() async {
    final xl.Worksheet sheet = workbook.worksheets[0];
    sheet.importList(firstRow, 1, 1, false);

    sheet.importList(listTimeStamp, 2, 1, true);
    sheet.importList(listLat, 2, 2, true);
    sheet.importList(listLong, 2, 3, true);
    sheet.importList(listTemp, 2, 4, true);
    sheet.importList(listHitindex, 2, 5, true);
    sheet.importList(listHumidity, 2, 6, true);
    sheet.importList(listSound, 2, 7, true);
    sheet.importList(listPpm, 2, 8, true);
    sheet.importList(listRzero, 2, 9, true);
    sheet.importList(listLight, 2, 10, true);
    sheet.importList(listPitch, 2, 11, true);
    sheet.importList(listRoll, 2, 12, true);
    sheet.importList(listYaw, 2, 13, true);

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
    _noiseMeter = new NoiseMeter(onError);

    if (widget.server != null) {
      BluetoothConnection.toAddress(widget.server?.address).then((_connection) {
        print('Connected to the device');
        connection?.input?.listen((Uint8List data) {
          print('Data incoming: ${ascii.decode(data)}');
          connection?.output.add(data);
          // samples.add(data);
          // print(" the number ${samples.length}");
          // Sending data

          if (ascii.decode(data).contains('!')) {
            connection?.finish(); // Closing connection
            print('Disconnecting by local host');
          }
        }).onDone(() {
          print('Disconnected by remote request');
        });

        connection = _connection;
        setState(() {
          isConnecting = false;
          isDisconnecting = false;
        });

        connection!.input!.listen(_onDataReceived).onDone(() {
          print("on Done!");
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

  String? title() {
    if (isConnected) {
      return "connected";
    } else {
      return "disconnected";
    }
  }

  void _sendMessage(String text) async {
    text = text.trim();

    if (text.length > 0) {
      try {
        connection?.output.add(Uint8List.fromList(ascii.encode(text)));
        await connection?.output.allSent;
        print("data sent");
        print(text);

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

  Widget batteries() {
    if (batteryLife! >= 84) {
      return Icon(
        Icons.battery_6_bar_sharp,
        color: Colors.black,
      );
    }
    if (batteryLife! <= 84 && batteryLife! >= 68) {
      return Icon(
        Icons.battery_5_bar_sharp,
        color: Colors.black,
      );
    }
    if (batteryLife! <= 68 && batteryLife! >= 52) {
      return Icon(
        Icons.battery_4_bar_sharp,
        color: Colors.black,
      );
    }
    if (batteryLife! <= 52 && batteryLife! >= 36) {
      return Icon(
        Icons.battery_3_bar_sharp,
        color: Colors.black,
      );
    }
    if (batteryLife! <= 36 && batteryLife! >= 20) {
      return Icon(
        Icons.battery_2_bar_sharp,
        color: Colors.black,
      );
    }
    if (batteryLife! <= 20 && batteryLife! >= 4) {
      return Icon(
        Icons.battery_1_bar_sharp,
        color: Colors.black,
      );
    } else {
      return Icon(
        Icons.battery_0_bar_sharp,
        color: Color.fromARGB(255, 255, 0, 0),
      );
    }
  }

  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data
    // print("data received");
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

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
    print(dataString);

    const temp = "TEMP:";
    const heatindex = ",HI:";

    final startIndex = dataString.indexOf(temp);
    final endIndex = dataString.indexOf(heatindex, startIndex + temp.length);
    listTemp.add(
        double.parse(dataString.substring(startIndex + temp.length, endIndex))
            .toStringAsFixed(2));
    //
    const humidity = ",RH:";

    final startIndex1 = dataString.indexOf(heatindex);
    final endIndex1 =
        dataString.indexOf(humidity, startIndex1 + humidity.length);
    listHitindex.add(double.parse(
            dataString.substring(startIndex1 + heatindex.length, endIndex1))
        .toStringAsFixed(2));

    const ppm = ",CPPM:";

    final startIndex2 = dataString.indexOf(humidity);
    final endIndex2 = dataString.indexOf(ppm, startIndex2 + ppm.length);
    listHumidity.add(double.parse(
            dataString.substring(startIndex2 + humidity.length, endIndex2))
        .toStringAsFixed(2));

    const rZero = ",CRZ:";

    final startIndex3 = dataString.indexOf(ppm);
    final endIndex3 = dataString.indexOf(rZero, startIndex3 + rZero.length);
    listPpm.add(
        double.parse(dataString.substring(startIndex3 + ppm.length, endIndex3))
            .toStringAsFixed(2));

    const light = ",LIGHT:";

    final startIndex4 = dataString.indexOf(rZero);
    final endIndex4 = dataString.indexOf(light, startIndex4 + light.length);
    listRzero.add(double.parse(
            dataString.substring(startIndex4 + rZero.length, endIndex4))
        .toStringAsFixed(2));

    const mic = ",MIC:";

    final startIndex5 = dataString.indexOf(light);
    final endIndex5 = dataString.indexOf(mic, startIndex5 + mic.length);
    listLight.add(double.parse(
            dataString.substring(startIndex5 + light.length, endIndex5))
        .toStringAsFixed(2));

    const battery = ",BATT:";

    // final startIndex6 = dataString.indexOf(mic);
    // final endIndex6 = dataString.indexOf(battery, startIndex6 + battery.length);
    // listSound.add(dataString.substring(startIndex6 + mic.length, endIndex6));

    const pitch = ",PITCH:";

    final startIndex7 = dataString.indexOf(battery);
    final endIndex7 = dataString.indexOf(pitch, startIndex7 + pitch.length);
    oldBatteryLife = double.parse(
        dataString.substring(startIndex7 + battery.length, endIndex7));

    batteryLife = (((oldBatteryLife! - 2.6) * (100 - 0)) / (3.7 - 2.6)) + 0;

    const roll = ",ROLL:";

    final startIndex8 = dataString.indexOf(pitch);
    final endIndex8 = dataString.indexOf(roll, startIndex8 + roll.length);
    listPitch.add(double.parse(
        dataString.substring(startIndex8 + pitch.length, endIndex8)));

    const yaw = ",YAW:";

    final startIndex9 = dataString.indexOf(roll);
    final endIndex9 = dataString.indexOf(yaw, startIndex9 + yaw.length);
    listRoll.add(double.parse(
        dataString.substring(startIndex9 + roll.length, endIndex9)));

    const last = ",";

    final startIndex10 = dataString.indexOf(yaw);
    final endIndex10 = dataString.indexOf(last, startIndex10 + last.length);
    listYaw.add(double.parse(
        dataString.substring(startIndex10 + yaw.length, endIndex10)));

    // RegExp exp = RegExp('(?<="temperature")(.*?)(?=,"heatIndex")');
    // String str = dataString;
    // RegExpMatch? match = exp.firstMatch(str);
    // print("the match is : ${match.toString()}");

    // RegExp exp2 = RegExp(r'\d+');
    // String str2 = dataString;
    // Iterable<RegExpMatch> matches = exp2.allMatches(str2);
    // for (final m in matches) {
    //   // print(m[0].toString());
    // }
  }

  void timerBanner() {
    timer2 = Timer.periodic(Duration(milliseconds: 500), (timer2) {
      second++;
      result = listSoundNew.reduce((a, b) => a + b) / listSoundNew.length;
      print(result);
      listSound.add(result!.toStringAsFixed(2));
      listSoundNew = [];
    });
  }

  void startTimer() {
    timer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      print("Location work perfect");
      _locationSubscription =
          _locationTracker.onLocationChanged.listen((newLocalData) {
        myLat = newLocalData.latitude!;
        myLong = newLocalData.longitude!;
      });

      _sendMessage("s");
      listTimeStamp.add("${DateTime.now()}");

      listLat.add(myLat);
      listLong.add(myLong);
      // listTimeStamp.add("");
      // listLat.add(myLat);
      // listLong.add(myLong);
      // listTimeStamp.add("");
      // listLat.add(myLat);
      // listLong.add(myLong);
      // listTimeStamp.add("");
      // listLat.add(myLat);
      // listLong.add(myLong);

      // myData.rowData.add(MyData(
      //   listtimeStamp: "${DateTime.now()}",
      //   userLatitude: myLat,
      //   userLongtitude: myLong,
      //   // temperature: ,
      //   // heatIndex: ,
      //   // humidity: ,
      //   // sound: ,
      //   // ppm: ,
      //   // rZero: ,
      //   // light: ,
      // ));

      // userLatitude.add(myLat!);
      // userLongtitude.add(myLong!);
    });
  }

  void getCurrentLocation() async {
    try {
      var location = await _locationTracker.getLocation();
      await controller.currentLocation();

      if (_locationSubscription != null) {
        _locationSubscription!.cancel();
      }
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        debugPrint("Permission Denied");
      }
    }
  }

  void stopBanner() {
    timer2!.cancel();
  }

  void stopTimer() {
    timer!.cancel();
    stop2();
  }

  void onData(NoiseReading noiseReading) {
    this.setState(() {
      if (!this._isRecording) {
        this._isRecording = true;
      }
    });

    listSoundNew.add(noiseReading.meanDecibel);
    // if (listSoundNew.length == 250) {
    //   result = listSoundNew.reduce((a, b) => a + b) / listSoundNew.length;
    //   print(result);
    //   listSound.add(result!);
    //   listSoundNew = [];
    // }
  }

  void onError(Object error) {
    print(error.toString());
    _isRecording = false;
  }

  // Stream<double> getRandomValues() async* {
  //   while (true) {
  //     await Future.delayed(Duration(seconds: 1));
  //   }
  // }

  void start() async {
    try {
      _noiseSubscription = _noiseMeter?.noiseStream.listen(onData);
    } catch (err) {
      print(err);
    }
  }

  void stop2() async {
    try {
      if (_noiseSubscription != null) {
        _noiseSubscription!.cancel();
        _noiseSubscription = null;
        print("Streaming data Stopeed now!!!!");
      }
      this.setState(() {
        this._isRecording = false;
      });
    } catch (err) {
      print('stopRecorder error: $err');
    }
  }

  @override
  void dispose() {
    _noiseSubscription?.cancel();
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
        actions: [
          IconButton(
              iconSize: 30,
              onPressed: () {
                _sendMessage("s");

                // Navigator.of(context).push(
                //   MaterialPageRoute(
                //     builder: (context) {
                //       return BackgroundCollectedPage();
                //     },
                //   ),
                // );
              },
              icon: batteries())
        ],
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
            'assets/First.png',
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
                  color: yellow,
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
              roadColor: yellow,
            ),
            markerOption: MarkerOption(
                defaultMarker: MarkerIcon(
              icon: Icon(
                Icons.circle_outlined,
                color: yellow,
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
                                  color: yellow,
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
                                  color: yellow,
                                ),
                                borderRadius: BorderRadius.circular(
                                    20) // use instead of BorderRadius.all(Radius.circular(20))
                                ),
                            child: Center(
                              child: Text(
                                title()!,
                                style: GoogleFonts.openSans(
                                    textStyle: Theme.of(context)
                                        .textTheme
                                        .displayMedium,
                                    color: Color.fromARGB(255, 68, 68, 68),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12),
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
                          backgroundColor: yellow,
                          child: Icon(
                            Icons.mode_comment_outlined,
                            color: darkGray,
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
                                  color: yellow,
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
                                    color: Colors.black,
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
                                backgroundColor: yellow,
                                child: Icon(
                                  Icons.sensors,
                                  color: darkGray,
                                  size: 22,
                                ),
                                onPressed: () {
                                  // Start scanning
                                }),
                          ),
                        ],
                      )
                    : Text(""),
                Text(
                  "",
                  style: GoogleFonts.openSans(
                      textStyle: Theme.of(context).textTheme.displayMedium,
                      color: Color.fromARGB(255, 68, 68, 68),
                      fontWeight: FontWeight.w500,
                      fontSize: 11),
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
                        startTimer();
                        timerBanner();
                        start();
                        startlaps();
                      } else {
                        stopTimer();
                        stopBanner();
                        stop2();
                        stoplaps();

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
                                padding: EdgeInsets.only(left: 10),
                                child: Text(
                                  "$digitMinutes:$digitSeconds",
                                  style: GoogleFonts.openSans(
                                      textStyle: Theme.of(context)
                                          .textTheme
                                          .displayMedium,
                                      color: darkGray,
                                      fontWeight: FontWeight.w600,
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
