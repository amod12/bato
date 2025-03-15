  import 'dart:async';
  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart'; // Import for Clipboard
  import 'package:maplibre_gl/maplibre_gl.dart';
  import 'package:location/location.dart' as loc;
  import 'package:permission_handler/permission_handler.dart' as perm;
  import 'package:http/http.dart' as http; // Import the http package
  import 'dart:convert'; // For JSON decoding


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
    loc.LocationData? _currentLocation;
    final TextEditingController _latController = TextEditingController();
    final TextEditingController _lngController = TextEditingController();

    static const CameraPosition _nullIsland = CameraPosition(
      target: LatLng(0.0, 0.0), // Null Island (0,0 coordinates)
      zoom: 2.0,
    );

    @override
    void initState() {
      super.initState();
      _checkLocationPermission();
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
              zoom: 20.0,
            ),
          ),
        );

        controller.addSymbol(
          SymbolOptions(
            geometry: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
            iconImage: 'marker',
            iconSize: 0.3,
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
        final String latLng = 'Latitude: ${_currentLocation!.latitude}, Longitude: ${_currentLocation!.longitude}';
        await Clipboard.setData(ClipboardData(text: latLng));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location copied to clipboard: $latLng')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No location data available')),
        );
      }
    }

    // Move camera to the specified latitude and longitude
    Future<void> _moveCameraToLocation(double lat, double lng) async {
      if (mapController.isCompleted) {
        final controller = await mapController.future;
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(lat, lng),
              zoom: 20.0, // Adjust zoom level as needed
            ),
          ),
        );

        // Add a marker at the specified location
        controller.addSymbol(
          SymbolOptions(
            geometry: LatLng(lat, lng),
            iconImage: 'marker',
            iconSize: 0.3,
          ),
        );
      }
    }
    
    Future<void> fetchAndAddMarkers(MapLibreMapController mapController) async {
      const String apiUrl =
          "https://api.baato.io/api/v1/search/nearby?type=school&lat=27.71765&lon=85.32691&key=bpk.XsRdlr_BeG-ri__yLIri5h1tJ5tMpSjqIbrzb_Cf99K5&radius=1&limit=10";

      try {
        final response = await http.get(Uri.parse(apiUrl));
          if (response.statusCode == 200) {
          // If the request is successful
          final data = json.decode(response.body); // Decode JSON response

          // Check if the 'data' field exists and is a list
          if (data['data'] != null && data['data'] is List) {
            final List<dynamic> locations = data['data'];

            // Load the custom marker image (pin.png)
            final Uint8List pinImage = await _loadImageFromAssets('images/pin.jpeg');

            // Add the image to the map
            await mapController.addImage('pin', pinImage);

            // Add markers for each location
            for (final location in locations) {
              final double lat = location['centroid']['lat'];
              final double lon = location['centroid']['lon'];

              mapController.addSymbol(
                SymbolOptions(
                  geometry: LatLng(lat, lon),
                  iconImage: 'pin', // Use the custom marker image
                  iconSize: 0.3, // Adjust size as needed
                ),
              );
            }
          } else {
            print("Invalid data format: 'data' field is missing or not a list");
          }
        } else {
          // Handle errors
          print("Failed to load data: ${response.statusCode}");
        }
      } catch (e) {
        // Handle exceptions
        print("Error fetching data: $e");
      }
}

    // Handle search button click
    void _onSearchButtonClicked() {
      try {
        final double lat = double.parse(_latController.text.trim());
        final double lng = double.parse(_lngController.text.trim());

        if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
          _moveCameraToLocation(lat, lng);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid latitude or longitude values')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid latitude and longitude')),
        );
      }
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.miniCenterFloat,
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isLocationEnabled)
              FloatingActionButton(
                onPressed: _moveCameraToUserLocation,
                mini: true,
                child: const Icon(Icons.my_location),
              ),
            const SizedBox(height: 10), // Spacing between buttons
            FloatingActionButton(
              onPressed: _zoomIn,
              mini: true,
              child: const Icon(Icons.add),
            ),
            const SizedBox(height: 10), // Spacing between buttons
            FloatingActionButton(
              onPressed: _zoomOut,
              mini: true,
              child: const Icon(Icons.remove),
            ),
            const SizedBox(height: 10), // Spacing between buttons
            FloatingActionButton(
              onPressed: _copyLocationToClipboard,
              mini: true,
              child: const Icon(Icons.copy),
            ),
          ],
        ),
        body: Column(
          children: [
            // Search Bar and Button
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _lngController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _onSearchButtonClicked,
                    icon: const Icon(Icons.search),
                    tooltip: 'Search Location',
                  ),
                ],
              ),
            ),
            Expanded(
              child: MapLibreMap(
                onMapCreated: (controller) {
                  mapController.complete(controller);
                  fetchAndAddMarkers(controller); // Fetch data and add markers
                  },
                initialCameraPosition: _nullIsland,
                styleString: "$styleUrl?key=$apiKey",
                trackCameraPosition: true,
                onStyleLoadedCallback: () => setState(() => canInteractWithMap = true),
              ),
            ),
          ],
        ),
      );
    }
  }