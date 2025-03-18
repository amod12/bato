import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for Clipboard
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:http/http.dart' as http; // Import the http package
import 'dart:convert'; // For JSON decoding
import 'package:app_links/app_links.dart';


const apiKey = "vtXVqLdP6bQI5NGQ8Jk6";
const styleUrl = "https://api.maptiler.com/maps/streets-v2/style.json";

class MapParentWidget extends StatefulWidget {
  @override
  State<MapParentWidget> createState() => MapParentWidgetState();
}

class MapParentWidgetState extends State<MapParentWidget> {
  final Completer<MapLibreMapController> mapController = Completer();
  bool canInteractWithMap = false;
  bool isLocationEnabled = false;
  bool _showPoiList = false; // Add this variable to your state class
  String selectedType = 'school'; // Default selected type


  loc.LocationData? _currentLocation;
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();

  final AppLinks _appLinks = AppLinks();


  List<Map<String, dynamic>> poiList = []; // List to store POIs

  static const CameraPosition _nullIsland = CameraPosition(
    target: LatLng(0.0, 0.0), // Null Island (0,0 coordinates)
    zoom: 2.0,
  );

  @override
  void initState() {
    super.initState();
        _checkLocationPermission();
        _handleIncomingLinks();
  }

   void _handleIncomingLinks() {
     print("@@11"); // Debugging
     AppLinks().uriLinkStream.listen((Uri? uri) {
       print("@@21"); // Debugging

       print("Incoming URI: $uri"); // Debugging
    if (uri != null && uri.host == "map") {
      final double? lat = double.tryParse(uri.queryParameters["lat"] ?? "");
      final double? lng = double.tryParse(uri.queryParameters["lng"] ?? "");

      if (lat != null && lng != null) {
        _moveCameraToLocation(lat, lng);
      }
    }
  });
  }

  Future<void> _checkLocationPermission() async {
    var status = await perm.Permission.location.request();
    if (status.isGranted) {
      _getLocation();
      print('Location permission granted');
    } else {
      print('Location permission denied');
    }
  }

  Future<void> _getLocation() async {
    loc.Location location = loc.Location();
    try {
      bool _serviceEnabled = await location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await location.requestService();
        if (!_serviceEnabled) {
          print('Location service not enabled');
          return;
        }
      }
      loc.PermissionStatus _permissionGranted = await location.hasPermission();
      if (_permissionGranted == loc.PermissionStatus.denied) {
        _permissionGranted = await location.requestPermission();
        if (_permissionGranted != loc.PermissionStatus.granted) {
          print('Location permission denied');
          return;
        }
      }
      // _currentLocation = await location.getLocation();
      _currentLocation = loc.LocationData.fromMap({
        "latitude": 27.6856,  // Pepsicola, Kathmandu
        "longitude": 85.3702,
      });
      print('@@');
      print(_currentLocation);
      if (_currentLocation != null) {
        setState(() {
          isLocationEnabled = true;
        });
        _moveCameraToUserLocation();
      }
    } catch (e) {
      print('Error fetching location: $e');
    }
  }

  Future<void> _moveCamera(double lat, double lng) async {
    if (mapController.isCompleted) {
      final controller = await mapController.future;

      // Remove all existing symbols with the 'marker' image
      final symbols = await controller.symbols;
      for (var symbol in symbols) {
        if (symbol.options.iconImage == 'marker') {
          await controller.removeSymbol(symbol);
        }
      }

      // Load new marker image
      await controller.addImage(
        'marker',
        await _loadImageFromAssets('images/marker.jpg'),
      );

      // Move camera to new position
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(lat, lng),
            zoom: 15.0,
          ),
        ),
      );
      controller.addSymbol(
        SymbolOptions(
          geometry: LatLng(lat, lng),
          iconImage: 'marker',
          iconSize: 0.4,
        ),
      );
    }
  }


  Future<void> _moveCameraToUserLocation() async {
    if (_currentLocation != null && mapController.isCompleted) {
      final controller = await mapController.future;

      await controller.addImage(
        'marker',
        await _loadImageFromAssets('images/marker.jpg'),
      );

      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
            zoom: 15.0,
          ),
        ),
      );

      controller.addSymbol(
        SymbolOptions(
          geometry: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
          iconImage: 'marker',
          iconSize: 0.4,
        ),
      );
    }
  }
 
 Future<void> _moveCameraToLocation(double lat, double lng) async {
    if (mapController.isCompleted) {
      print('@@2');

      final controller = await mapController.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(lat, lng),
            zoom: 15.0, // Adjust zoom level as needed
          ),
        ),
      );

      // Add a marker at the specified location
      controller.addSymbol(
        SymbolOptions(
          geometry: LatLng(lat, lng),
          iconImage: 'marker',
          iconSize: 0.4,
        ),
      );
    }
  }

  
  Future<Uint8List> _loadImageFromAssets(String path) async {
    final ByteData bytes = await rootBundle.load(path);
    return bytes.buffer.asUint8List();
  }

  // Zoom in function
  Future<void> _zoomIn() async {
    if (mapController.isCompleted) {
      final controller = await mapController.future;
      controller.animateCamera(CameraUpdate.zoomIn());
    }
  }

  // Zoom out function
  Future<void> _zoomOut() async {
    if (mapController.isCompleted) {
      final controller = await mapController.future;
      controller.animateCamera(CameraUpdate.zoomOut());
    }
  }

  // Copy latitude and longitude to clipboard
  Future<void> _copyLocationToClipboard() async {
    if (_currentLocation != null) {
      final String deepLink =
          'bato://map?lat=${_currentLocation!.latitude}&lng=${_currentLocation!.longitude}';

      await Clipboard.setData(ClipboardData(text: deepLink));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location link copied to clipboard')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No location data available')),
      );
    }
  }
  
 Future<void> fetchAndAddMarkers1(MapLibreMapController mapController, {String type = 'school'}) async {
    final String apiUrl =
        "https://api.baato.io/api/v1/search/nearby?type=$type&lat=27.71765&lon=85.32691&key=bpk.XsRdlr_BeG-ri__yLIri5h1tJ5tMpSjqIbrzb_Cf99K5&radius=1&limit=10";
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      // If the request is successful
      final data = json.decode(response.body); // Decode JSON response

      // Check if the 'data' field exists and is a list
      if (data['data'] != null && data['data'] is List) {
        setState(() {
          poiList = List<Map<String, dynamic>>.from(data['data']);
        });
      }
    }
  }

  Future<void> fetchAndAddMarkers(MapLibreMapController mapController) async {
  const String schoolApiUrl =
      "https://api.baato.io/api/v1/search/nearby?type=school&lat=27.71765&lon=85.32691&key=bpk.XsRdlr_BeG-ri__yLIri5h1tJ5tMpSjqIbrzb_Cf99K5&radius=1&limit=10";
  const String eatApiUrl =
      "https://api.baato.io/api/v1/search/nearby?type=eat&lat=27.71765&lon=85.32691&key=bpk.XsRdlr_BeG-ri__yLIri5h1tJ5tMpSjqIbrzb_Cf99K5&radius=1&limit=10";
  print('@@in');
  try {
    // Fetch school data
    final schoolResponse = await http.get(Uri.parse(schoolApiUrl));
    final eatResponse = await http.get(Uri.parse(eatApiUrl));

    if (schoolResponse.statusCode == 200 && eatResponse.statusCode == 200) {
      // Decode JSON responses
      final schoolData = json.decode(schoolResponse.body);
      final eatData = json.decode(eatResponse.body);

      // Load custom marker images
      final Uint8List pinImage = await _loadImageFromAssets('images/pin1.png');
      final Uint8List eatImage = await _loadImageFromAssets('images/eat.jpg');

      // Add images to the map
      await mapController.addImage('pin', pinImage);
      await mapController.addImage('eat', eatImage);

      // Add school markers
      if (schoolData['data'] != null && schoolData['data'] is List) {
        final schoolList = List<Map<String, dynamic>>.from(schoolData['data']);
        await _addMarkers(mapController, schoolList, 'pin');
      }

      // Add eat markers
      if (eatData['data'] != null && eatData['data'] is List) {
        final eatList = List<Map<String, dynamic>>.from(eatData['data']);
        await _addMarkers(mapController, eatList, 'eat');
      }
    } else {
      print("Failed to load data: School - ${schoolResponse.statusCode}, Eat - ${eatResponse.statusCode}");
    }
  } catch (e) {
    print("Error fetching data: $e");
  }
}

  Future<void> _addMarkers(MapLibreMapController mapController, List<Map<String, dynamic>> locations, String iconImage) async {
  for (final location in locations) {
    final double lat = location['centroid']['lat'];
    final double lon = location['centroid']['lon'];

    // Add the symbol to the map with location data
    final symbol = await mapController.addSymbol(
      SymbolOptions(
        geometry: LatLng(lat, lon), // Coordinates of the symbol
        iconImage: iconImage, // Custom marker image
        iconSize: 0.4, // Size of the icon
      ),
    );

    // Set up the onFeatureTapped callback
    mapController.onFeatureTapped.add((id, point, coordinates, layerId) {
      // Check if the tapped feature is the symbol we added
      if (id == symbol.id) {
        // Extract the name, address, and type from the location data
        final name = location['name'];
        final address = location['address'];
        final type = location['type'];

        // Perform your custom action here
        print('Symbol tapped: $name, $address, $type');

        // Show a dialog with the name, address, and type
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Location Info'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Name: $name'),
                Text('Address: $address'),
                Text('Type: $type'),
              ],
            ),
          ),
        );
      }
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.miniCenterFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(left: 16.0), // Add left padding
        child: Align(
          alignment: Alignment.centerLeft, // Align to the left side
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isLocationEnabled)
                FloatingActionButton(
                  onPressed: () {
                    _moveCameraToUserLocation();
                    setState(() {
                      _showPoiList = false; // Toggle the visibility of the POI list
                    });
                  },
                  mini: true,
                  child: const Icon(Icons.my_location),
                ),
              const SizedBox(height: 10),
              FloatingActionButton(
                onPressed: () {
                  _zoomIn();
                  setState(() {
                    _showPoiList = false; // Toggle the visibility of the POI list
                  });
                },
                mini: true,
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 10),
              FloatingActionButton(
                onPressed: () {
                  _zoomOut();
                  setState(() {
                    _showPoiList = false; // Toggle the visibility of the POI list
                  });
                },
                mini: true,
                child: const Icon(Icons.remove),
              ),
              const SizedBox(height: 10),
              FloatingActionButton(
                onPressed: () {
                  _copyLocationToClipboard();
                  setState(() {
                    _showPoiList = false; // Toggle the visibility of the POI list
                  });
                },
                mini: true,
                child: const Icon(Icons.copy),
              ),
              const SizedBox(height: 10),
              FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _showPoiList = !_showPoiList; // Toggle the visibility of the POI list
                  });
                },
                mini: true,
                child: const Icon(Icons.list),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // Map
          MapLibreMap(
            onMapCreated: (controller) {
              mapController.complete(controller);
              fetchAndAddMarkers1(controller);
              fetchAndAddMarkers(controller); // Fetch data and add markers
            },
            initialCameraPosition: _nullIsland,
            styleString: "$styleUrl?key=$apiKey",
            trackCameraPosition: true,
            onStyleLoadedCallback: () => setState(() => canInteractWithMap = true),
            onMapClick: (point, coordinates) {
              setState(() {
                _showPoiList = false; // Hide the POI list when the map is clicked
              });
            },
          ),

          // POI List (overlayed on top of the map)
          if (_showPoiList)
            Positioned(
            top: 100, // Adjust the position as needed
            left: 20,
            right: 20,
            child: Container(
              height: 400, // Adjust the height as needed
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9), // Semi-transparent background
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Text(
                          'Points of Interest',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 10), // Add some spacing
                        DropdownButton<String>(
                          value: selectedType,
                          onChanged: (String? newValue) async {
                            setState(() {
                              selectedType = newValue!;
                            });
                            // Fetch new markers based on the selected type
                             final controller = await mapController.future;
                            fetchAndAddMarkers1(controller, type: selectedType);
                          },
                          items: <String>['school', 'eat']
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: poiList.length,
                      itemBuilder: (context, index) {
                        final poi = poiList[index];
                        return ListTile(
                          title: Text(poi['name']),
                          subtitle: Text(poi['address']),
                          onTap: () {
                            setState(() {
                              _showPoiList = false; // Toggle the visibility of the POI list
                            });
                            // Move camera to the selected POI
                            _moveCamera(poi['centroid']['lat'], poi['centroid']['lon']);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}