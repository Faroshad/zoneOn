// ignore_for_file: sized_box_for_whitespace

import 'package:flutter/material.dart';
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
import 'package:zone_on/main.dart';
import 'package:zone_on/row_data.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:zone_on/start_page.dart';

import 'BackgroundCollectingTask.dart';
import 'DiscoveryPage.dart';

class StartPage extends StatefulWidget {
  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;

  String _address = "...";
  String _name = "...";

  Timer? _discoverableTimeoutTimer;
  int _discoverableTimeoutSecondsLeft = 0;

  BackgroundCollectingTask? _collectingTask;

  bool _autoAcceptPairingRequests = false;

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
        _discoverableTimeoutTimer = null;
        _discoverableTimeoutSecondsLeft = 0;
      });
    });
  }

  void _startTracking(BuildContext context, BluetoothDevice server) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return MyHomePage(server: server);
        },
      ),
    );
  }

  @override
  void dispose() {
    FlutterBluetoothSerial.instance.setPairingRequestHandler(null);
    _collectingTask?.dispose();
    _discoverableTimeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 0, 201, 167),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: height / 1.5),
            child: Center(
              child: Container(
                width: 300,
                child: Image.asset(
                  'assets/zon.png',
                  color: Color.fromARGB(255, 48, 48, 48),
                ),
              ),
            ),
          ),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: SwitchListTile(
                          // contentPadding: EdgeInsets.symmetric(horizontal: 30),
                          activeColor: Color.fromARGB(255, 0, 201, 167),
                          selectedTileColor: Color.fromARGB(255, 255, 255, 255),
                          tileColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(45), // <-- Radius
                          ),
                          // title: const Text('Enable Bluetooth'),
                          value: _bluetoothState.isEnabled,
                          onChanged: (bool value) {
                            // Do the request and update with the true value then
                            future() async {
                              // async lambda seems to not working
                              if (value)
                                await FlutterBluetoothSerial.instance
                                    .requestEnable();
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
                        height: 10,
                      ),
                      Text(
                        "1",
                        style: GoogleFonts.openSans(
                            textStyle:
                                Theme.of(context).textTheme.displayMedium,
                            color: Color.fromARGB(255, 255, 255, 255),
                            fontWeight: FontWeight.w700,
                            fontSize: 18),
                      )
                    ],
                  ),
                ),
                SizedBox(
                  width: 10,
                ),
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: FloatingActionButton(
                          heroTag: 's',
                          backgroundColor: Color.fromARGB(255, 255, 255, 255),
                          child: Icon(
                            Icons.search_rounded,
                            color: Color.fromARGB(255, 0, 201, 167),
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
                              print('Discovery -> selected ' +
                                  selectedDevice.address);
                            } else {
                              print('Discovery -> no device selected');
                            }
                          },
                        ),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Text(
                        "2",
                        style: GoogleFonts.openSans(
                            textStyle:
                                Theme.of(context).textTheme.displayMedium,
                            color: Color.fromARGB(255, 255, 255, 255),
                            fontWeight: FontWeight.w700,
                            fontSize: 18),
                      )
                    ],
                  ),
                ),
                SizedBox(
                  width: 15,
                ),
                Flexible(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: FloatingActionButton(
                            heroTag: 's2',
                            backgroundColor: Color.fromARGB(255, 255, 255, 255),
                            child: Icon(
                              Icons.bluetooth_connected_outlined,
                              color: Color.fromARGB(255, 0, 201, 167),
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
                                print('Connect -> selected ' +
                                    selectedDevice.address);
                                _startTracking(context, selectedDevice);
                              } else {
                                print('Connect -> no device selected');
                              }
                            },
                          ),
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        Text(
                          "3",
                          style: GoogleFonts.openSans(
                              textStyle:
                                  Theme.of(context).textTheme.displayMedium,
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontWeight: FontWeight.w700,
                              fontSize: 18),
                        ),
                      ]),
                ),
                SizedBox(
                  width: 15,
                ),
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: FloatingActionButton(
                            heroTag: 's3',
                            backgroundColor: Color.fromARGB(255, 48, 48, 48),
                            child: Icon(
                              Icons.track_changes_outlined,
                              color: Color.fromARGB(255, 255, 255, 255),
                              size: 30,
                            ),
                            onPressed: () async {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) {
                                    return MyHomePage();
                                  },
                                ),
                              );
                              ;
                            }),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Text(
                        "GPS",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.openSans(
                            textStyle:
                                Theme.of(context).textTheme.displayMedium,
                            color: Color.fromARGB(255, 48, 48, 48),
                            fontWeight: FontWeight.w800,
                            fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
