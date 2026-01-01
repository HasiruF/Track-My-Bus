import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'seatbooking_screen.dart';
import 'home_screen.dart';
import 'drive_route_screen.dart';
import 'seatviewing_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'halt_details_screen.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart'; 
import 'UserProfileScreen.dart';


class DriverHomePage extends StatefulWidget {
  final String userId;

  DriverHomePage({required this.userId});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  String userName = '';
  String userEmail = '';
  String userType = 'Driver'; // Hardcoded for Driver

  //current  tab
  int _currentIndex = 0;

  //BottomNavigationBar items
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails(); // Fetch driver's details
    _pages = [
      DriverTripsPage(userId: widget.userId), // iewing/managing trips
      DriverMapPage(userId: widget.userId), // New tab for Google Maps
      DriverClientsPage(driverId: widget.userId),
      DriverProfilePage(), // Driver's profile page
      
      
    ];
  }

  Future<void> _fetchUserDetails() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          userName = userDoc['username'];
          userEmail = userDoc['email'];
        });
      }
    } catch (e) {
      print('Error fetching driver details: $e');
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text(
          'Driver Dashboard, $userName',
        ),
        actions: [
          // Sign out button in the AppBar
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () async {
              // Sign out the user
              await FirebaseAuth.instance.signOut();

              //avigate back to the login page
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            },
          ),
        ],
      ),
      body: _pages[_currentIndex], // Show the selected page
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex, // Current selected index
        onTap: _onTabTapped, // Update selected tab
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey, 
        backgroundColor: Colors.white, 
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus),
            label: 'Trips',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),  // Google Maps icon
            label: 'Map',           
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Client',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class DriverTripsPage extends StatefulWidget {
  final String userId;

  DriverTripsPage({required this.userId});

  @override
  _DriverTripsPageState createState() => _DriverTripsPageState();
}

class _DriverTripsPageState extends State<DriverTripsPage> {
  Future<List<Map<String, dynamic>>> _fetchDriverTrips() async {
    List<Map<String, dynamic>> trips = [];

    try {
      // Fetch all buses assigned to this driver
      QuerySnapshot busSnapshot = await FirebaseFirestore.instance
          .collection('buses')
          .where('driver_id', isEqualTo: widget.userId)
          .get();

      for (var busDoc in busSnapshot.docs) {
        String busId = busDoc.id;
        String routeName = busDoc['route_name'] ?? 'Unknown Route';
        String busNumber = busDoc['bus_number'] ?? 'Unknown Number';

        // Fetch bookings for this bus from the seats collection
        QuerySnapshot seatSnapshot = await FirebaseFirestore.instance
            .collection('seats')
            .where('busId', isEqualTo: busId)
            .get();

        Map<String, Map<String, int>> bookingsByDateAndTime = {};

        for (var seatDoc in seatSnapshot.docs) {
          String date = seatDoc['date'] ?? 'Unknown Date';
          String timeSlot = seatDoc['timeSlot'] ?? 'Unknown Time Slot';
          Map<String, dynamic> bookedSeats = seatDoc['bookedSeats'] ?? {};

          if (bookedSeats.isNotEmpty) {
            // Ensure the map for this date exists
            if (bookingsByDateAndTime[date] == null) {
              bookingsByDateAndTime[date] = {};
            }

            // Ensure the time slot exists and initialize it to 0 if it's null
            if (bookingsByDateAndTime[date]![timeSlot] == null) {
              bookingsByDateAndTime[date]![timeSlot] = 0;
            }

            // Increment the booking count
            bookingsByDateAndTime[date]![timeSlot] =
                bookingsByDateAndTime[date]![timeSlot]! + bookedSeats.length;
          }
        }

        if (bookingsByDateAndTime.isNotEmpty) {
          trips.add({
            'routeName': routeName,
            'busNumber': busNumber,
            'busId': busId,
            'dayTimeBookings': bookingsByDateAndTime,
          });
        }
      }
    } catch (e) {
      print('Error fetching driver trips: $e');
    }

    return trips;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Trips'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>( 
        future: _fetchDriverTrips(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading trips'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No trips found'));
          } else {
            List<Map<String, dynamic>> trips = snapshot.data!;

            return Column(
              children: [
                // List of trips
                Expanded(
                  child: ListView.builder(
                    itemCount: trips.length,
                    itemBuilder: (context, index) {
                      var trip = trips[index];
                      String routeName = trip['routeName'] ?? 'Unknown Route';
                      String busNumber = trip['busNumber'] ?? 'Unknown Bus';
                      String busId = trip['busId'] ?? 'Unknown Bus ID';

                      return Column(
                        children: [
                          // Bus Route and Number
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              '$routeName - $busNumber',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          // Loop through the bookings
                          ...trip['dayTimeBookings']?.entries.map((entry) {
                            String date = entry.key;
                            Map<String, int> timeSlots = entry.value;

                            return GestureDetector(
                              onTap: () {
                                // Navigate to SeatViewerPage on tap
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SeatViewerPage(
                                      busId: busId,
                                      date: date,
                                      timeSlot: timeSlots.keys.first,
                                    ),
                                  ),
                                );
                              },
                              child: Card(
                                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                child: ListTile(
                                  title: Text('$date, ${timeSlots.keys.first}'), // date and time slot
                                  subtitle: Text('Bookings: ${timeSlots.values.first}'), // booking count
                                ),
                              ),
                            );
                          }).toList() ?? [],
                        ],
                      );
                    },
                  ),
                ),
                // Manage Route Button outside FutureBuilder
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate to the DriverRouteScreen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DriverRouteScreen(
                            busId: trips[0]['busId'], // Pass busId to the DriverRouteScreen
                          ),
                        ),
                      );
                    },
                    child: Text('Manage Route'),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}

class DriverProfilePage extends StatefulWidget {
  const DriverProfilePage({super.key});

  @override
  _DriverProfilePageState createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String username = "";
  String email = "";
  String emergencyContact = "";
  String profileImageUrl = "";

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        username = userDoc["username"] ?? "";
        email = userDoc["email"] ?? "";
        emergencyContact = userDoc["emergency_contact"] ?? "";
        profileImageUrl = userDoc["profile_image"] ?? "";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: profileImageUrl.isNotEmpty
                    ? NetworkImage(profileImageUrl)
                    : null,
                child: profileImageUrl.isEmpty
                    ? Icon(Icons.person, size: 50)
                    : null,
              ),
            ),
            SizedBox(height: 10),
            Text("Username: $username", style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text("Email: $email", style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text("Emergency Contact: $emergencyContact",
                style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserProfileScreen()),
                ).then((_) => _loadUserProfile());
              },
              child: Text("Edit Profile"),
            ),
          ],
        ),
      ),
    );
  }
}

class DriverMapPage extends StatefulWidget {
  final String userId;

  DriverMapPage({required this.userId});

  @override
  _DriverMapPageState createState() => _DriverMapPageState();
}

class _DriverMapPageState extends State<DriverMapPage> with WidgetsBindingObserver {
  late GoogleMapController _mapController;
  late LatLng _userLocation;
  bool _isLoading = true;
  late Set<Marker> _markers;
  late Set<Polyline> _polylines;
  List<LatLng> _haltLocations = [];

  BitmapDescriptor? _busIcon;
  BitmapDescriptor? _haltIcon;

  @override
  void initState() {
    super.initState();
    _markers = Set();
    _polylines = Set();
    _loadCustomIcons();
    _fetchUserLocation();
    _fetchHaltLocations();
    WidgetsBinding.instance.addObserver(this); 
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App resumed, update user location
      _fetchUserLocation();
    }
  }

  Future<void> _loadCustomIcons() async {
    _busIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(5, 5)),
      'assets/bus_icon.png',
    );
    _haltIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(5, 5)),
      'assets/halt_icon.png',
    );
  }

  Future<void> _fetchUserLocation() async {
    try {
      // Get current location using Geolocator plugin
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _markers.add(Marker(
          markerId: MarkerId('user_location'),
          position: _userLocation,
          icon: _busIcon ?? BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(title: 'Your Location'),
        ));
        _isLoading = false;
      });

      
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'location': GeoPoint(position.latitude, position.longitude),
      });

    } catch (e) {
      print('Error fetching location: $e');
    }
  }


  Future<void> _fetchHaltLocations() async {
    try {
      QuerySnapshot busSnapshot = await FirebaseFirestore.instance
          .collection('buses')
          .where('driver_id', isEqualTo: widget.userId)
          .get();

      for (var busDoc in busSnapshot.docs) {
        List<dynamic> haltLocations = busDoc['haltLocations'] ?? [];

        setState(() {
          _haltLocations = haltLocations
              .map((location) => LatLng(location.latitude, location.longitude))
              .toList();

          // Add markers for each halt
          for (int i = 0; i < _haltLocations.length; i++) {
            _markers.add(Marker(
              markerId: MarkerId('halt_$i'),
              position: _haltLocations[i],
              icon: _haltIcon ?? BitmapDescriptor.defaultMarker,
              infoWindow: InfoWindow(title: 'Halt $i'),
              onTap: () async {
                // Fetch current halt index from seats collection
                String timeSlot = DateTime.now().hour < 12 ? 'morning' : 'evening';
                String selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

                QuerySnapshot seatSnapshot = await FirebaseFirestore.instance
                    .collection('seats')
                    .where('busId', isEqualTo: busDoc.id)
                    .where('date', isEqualTo: selectedDate)
                    .where('timeSlot', isEqualTo: timeSlot)
                    .get();

                int currentHalt = -2; // Default if bus hasn't started
                if (seatSnapshot.docs.isNotEmpty) {
                  Map<String, dynamic> seatData =
                      seatSnapshot.docs.first.data() as Map<String, dynamic>;
                  currentHalt = seatData['current'] ?? -2;
                }

                bool isFirstHalt = i == 0 && currentHalt == -2; // First halt, bus not started
                bool isNextHalt = i == currentHalt + 1; // Next halt after current

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HaltDetailsPage(
                      haltIndex: i,
                      busId: busDoc.id,
                      haltCoordinates: _haltLocations[i],
                      isFirstHalt: isFirstHalt,
                      isNextHalt: isNextHalt,
                    ),
                  ),
                );
              }
            ));

            if (i < _haltLocations.length - 1) {
              _polylines.add(Polyline(
                polylineId: PolylineId("halt_to_halt_$i"),
                points: [_haltLocations[i], _haltLocations[i + 1]],
                color: Colors.blue,
                width: 5,
              ));
            }
          }
        });
      }
    } catch (e) {
      print('Error fetching halt locations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Location'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: _userLocation,
                zoom: 17.0,
              ),
              markers: _markers,
              polylines: _polylines,
            ),
    );
  }
}


class DriverClientsPage extends StatefulWidget {
  final String driverId;

  DriverClientsPage({required this.driverId});

  @override
  _DriverClientsPageState createState() => _DriverClientsPageState();
}

class _DriverClientsPageState extends State<DriverClientsPage> {
  List<Map<String, String>> clientsList = [];
  List<Map<String, String>> searchResults = [];
  String? busId;
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDriverBus();
  }

  Future<void> _fetchDriverBus() async {
    try {
      QuerySnapshot busSnapshot = await FirebaseFirestore.instance
          .collection('buses')
          .where('driver_id', isEqualTo: widget.driverId)
          .get();

      if (busSnapshot.docs.isNotEmpty) {
        DocumentSnapshot busDoc = busSnapshot.docs.first;
        busId = busDoc.id;
        List<dynamic> clientIds = busDoc['clients'] ?? [];
        await _fetchClientDetails(clientIds);
      }
    } catch (e) {
      print('Error fetching driver bus: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchClientDetails(List<dynamic> clientIds) async {
    List<Map<String, String>> clients = [];

    for (String clientId in clientIds) {
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance.collection('users').doc(clientId).get();
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        clients.add({
          'id': clientId,
          'name': (userData['username'] ?? 'Unknown').toString(),
          'email': (userData['email'] ?? 'No Email').toString(),
        });
      }
    }

    setState(() {
      clientsList = clients;
    });
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
      });
      return;
    }

    QuerySnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: query + '\uf8ff')
        .limit(5)
        .get();

    List<Map<String, String>> results = userSnapshot.docs.map((doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'name': (data['username'] ?? 'Unknown').toString(),
        'email': (data['email'] ?? 'No Email').toString(),
      };
    }).toList();

    setState(() {
      searchResults = results;
    });
  }

  Future<void> _addClient(String clientId) async {
    if (busId == null) return;

    try {
      await FirebaseFirestore.instance.collection('buses').doc(busId).update({
        'clients': FieldValue.arrayUnion([clientId])
      });
      searchController.clear();
      setState(() {
        searchResults = [];
      });
      _fetchDriverBus();
    } catch (e) {
      print('Error adding client: $e');
    }
  }

  Future<void> _removeClient(String clientId) async {
    if (busId == null) return;

    try {
      await FirebaseFirestore.instance.collection('buses').doc(busId).update({
        'clients': FieldValue.arrayRemove([clientId])
      });
      _fetchDriverBus();
    } catch (e) {
      print('Error removing client: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Manage Clients')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: 'Search Client by Name',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.search),
                    ),
                    onChanged: _searchUsers,
                  ),
                  SizedBox(height: 10),

                  // Search Results
                  if (searchResults.isNotEmpty)
                    Container(
                      height: 150,
                      child: ListView.builder(
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(searchResults[index]['name']!),
                            subtitle: Text(searchResults[index]['email']!),
                            trailing: IconButton(
                              icon: Icon(Icons.add, color: Colors.green),
                              onPressed: () => _addClient(searchResults[index]['id']!),
                            ),
                          );
                        },
                      ),
                    ),

                  SizedBox(height: 20),

                  // Client List
                  Expanded(
                    child: ListView.builder(
                      itemCount: clientsList.length,
                      itemBuilder: (context, index) {
                        return Card(
                          child: ListTile(
                            title: Text(clientsList[index]['name']!),
                            subtitle: Text(clientsList[index]['email']!),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _removeClient(clientsList[index]['id']!),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}