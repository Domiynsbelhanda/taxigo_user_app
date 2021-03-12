import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_select/smart_select.dart';
import 'package:taxigo_user_app/brand_colors.dart';
import 'package:taxigo_user_app/datamodels/directiondetails.dart';
import 'package:taxigo_user_app/datamodels/nearbydriver.dart';
import 'package:taxigo_user_app/dataprovider/appdata.dart';
import 'package:taxigo_user_app/globalvariable.dart';
import 'package:taxigo_user_app/helpers/firehelper.dart';
import 'package:taxigo_user_app/helpers/helpermethods.dart';
import 'package:taxigo_user_app/helpers/mapkithelper.dart';
import 'package:taxigo_user_app/rideVaribles.dart';
import 'package:taxigo_user_app/screens/searchpage.dart';
import 'package:taxigo_user_app/styles/styles.dart';
import 'package:taxigo_user_app/translations.dart';
import 'package:taxigo_user_app/widgets/BrandDivier.dart';
import 'package:taxigo_user_app/widgets/CollectPaymentDialog.dart';
import 'package:taxigo_user_app/widgets/NoDriverDialog.dart';
import 'package:taxigo_user_app/widgets/ProgressDialog.dart';
import 'package:taxigo_user_app/widgets/TaxiButton.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:outline_material_icons/outline_material_icons.dart';
import 'dart:io';
import 'package:animated_text_kit/animated_text_kit.dart';

import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application.dart';
import 'loginpage.dart';


class MainPage extends StatefulWidget {

  static const String id = 'mainpage';

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with TickerProviderStateMixin {

  GlobalKey<ScaffoldState> scaffoldKey = new GlobalKey<ScaffoldState>();
  double searchSheetHeight = (Platform.isIOS) ? 150 : 135;
  double rideDetailsSheetHeight = 0; // (Platform.isAndroid) ? 235 : 260
  double requestingSheetHeight = 0; // (Platform.isAndroid) ? 195 : 220
  double tripSheetHeight = 0; // (Platform.isAndroid) ? 275 : 300

  Completer<GoogleMapController> _controller = Completer();
  GoogleMapController mapController;
  double mapBottomPadding = 0;

  List<LatLng> polylineCoordinates = [];
  Set<Polyline> _polylines = {};
  Set<Marker> _Markers = {};
  Set<Circle> _Circles = {};

  BitmapDescriptor nearbyIcon;

  var geoLocator = Geolocator();
  Position currentPosition;
  DirectionDetails tripDirectionDetails;

  String appState = 'NORMAL';

  bool drawerCanOpen = true;

  DatabaseReference rideRef;

  StreamSubscription<Event> rideSubscription;

  List<NearbyDriver> availableDrivers;

  bool nearbyDriversKeysLoaded = false;

  bool isRequestingLocationDetails = false;

  void setupPositionLocator() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    currentPosition = position;

    LatLng pos = LatLng(currentPosition.latitude, currentPosition.longitude);
    CameraPosition cp = new CameraPosition(target: pos, zoom: 14);
    mapController.animateCamera(CameraUpdate.newCameraPosition(cp));

    // confirm location
    await HelperMethods.findCordinateAddress(currentPosition, context);

    startGeofireListener();

  }

  void showDetailSheet () async {
    await getDirection();

    setState(() {
      searchSheetHeight = 0;
      mapBottomPadding = (Platform.isAndroid) ? 240 : 230;
      rideDetailsSheetHeight = (Platform.isAndroid) ? 235 : 260;
      drawerCanOpen = false;
    });
  }

  void showRequestingSheet(){
    setState(() {

      rideDetailsSheetHeight = 0;
      requestingSheetHeight = (Platform.isAndroid) ? 195 : 220;
      mapBottomPadding = (Platform.isAndroid) ? 200 : 190;
      drawerCanOpen = true;

    });

    createRideRequest();
  }

  showTripSheet(){

    setState(() {
      requestingSheetHeight = 0;
      tripSheetHeight = (Platform.isAndroid) ? 275 : 300;
      mapBottomPadding = (Platform.isAndroid) ? 280 : 270;
    });
  }

  void createMarker(){
    if(nearbyIcon == null){

      ImageConfiguration imageConfiguration = createLocalImageConfiguration(context, size: Size(2,2));
      BitmapDescriptor.fromAssetImage(
          imageConfiguration, (Platform.isIOS)
          ? 'images/car_ios.png'
          : 'images/car_android.png'
      ).then((icon){
        nearbyIcon = icon;
      });
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    HelperMethods.getCurrentUserInfo();
  }

    String value = langue;
    List<S2Choice<String>> options = [
      S2Choice<String>(value: 'en', title: 'Anglais'),
      S2Choice<String>(value: 'fr', title: 'Français'),
      S2Choice<String>(value: 'ar', title: 'Arabe'),
    ];

  @override
  Widget build(BuildContext context) {

    createMarker();

    return Scaffold(
      key: scaffoldKey,
      drawer: Container(
        width: 250,
        color: Colors.white,
        child: Drawer(

          child: ListView(
            padding: EdgeInsets.all(0),
            children: <Widget>[

              UserAccountsDrawerHeader(
                accountName: Text(currentUserInfo.fullName),
                accountEmail: Text('${currentUserInfo.email} \n ${currentUserInfo.phone}'),
                currentAccountPicture: CircleAvatar(
                    backgroundImage: NetworkImage(
                        currentUserInfo.image
                      ),
                  ),
                

                //onDetailsPressed: (){},


                decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage("https://firebasestorage.googleapis.com/v0/b/car-rental-rdc.appspot.com/o/fundo.jpg?alt=media&token=537b483c-2065-43a7-9048-77345870d437"),
                     fit: BoxFit.cover)
              ),),

              SmartSelect<String>.single(
                title: Translations.of(context).text('langue'),
                value: value,
                choiceItems: options,
                onChange: (state) async{
                  value = state.value;
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  prefs.setString('langue', value);
                  applic.onLocaleChanged(new Locale(value,''));
                  (context as Element).markNeedsBuild();
                }
              ),

              ListTile(
                leading: Icon(OMIcons.info),
                title: Text(Translations.of(context).text('about'), style: kDrawerItemStyle,),
              ),

              GestureDetector(
                child: ListTile(
                  leading: Icon(OMIcons.info),
                  title: Text(Translations.of(context).text('log_out'), style: kDrawerItemStyle,),
                ),
                onTap: (){
                  FirebaseAuth.instance.signOut();
                  Navigator.pushNamedAndRemoveUntil(context, LoginPage.id, (route) => false);
                }
              )

            ],
          ),
        ),
      ),
      body: Stack(
        children: <Widget>[
          GoogleMap(
            padding: EdgeInsets.only(bottom: mapBottomPadding),
            mapType: MapType.terrain,
            myLocationButtonEnabled: true,
            initialCameraPosition: googlePlex,
            myLocationEnabled: true,
            zoomGesturesEnabled: true,
            zoomControlsEnabled: true,
            polylines: _polylines,
            markers: _Markers,
            circles: _Circles,
            onMapCreated: (GoogleMapController controller){
              _controller.complete(controller);
              mapController = controller;

              setState(() {
                mapBottomPadding = (Platform.isAndroid) ? 280 : 270;
              });

              setupPositionLocator();
            },
          ),

          Positioned(
            bottom: 20,
            right: 20,
            child: GestureDetector(
                        onTap: () async {

                         var response = await  Navigator.push(context, MaterialPageRoute(
                            builder: (context)=> SearchPage()
                          ));

                         if(response == 'getDirection'){
                           showDetailSheet();
                         }

                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 5.0,
                                spreadRadius: 0.5,
                                offset: Offset(
                                  0.7,
                                  0.7,
                                )
                              )
                            ]
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Row(
                              children: <Widget>[
                                Icon(Icons.search, color: Colors.blueAccent,),
                                SizedBox(width: 10,),
                                Text(Translations.of(context).text('search_destination')),
                              ],
                            ),
                          ),
                        ),
                      ),
          ),

          ///MenuButton
          Positioned(
            top: 44,
            left: 20,
            child: GestureDetector(
              onTap: (){
                if(drawerCanOpen){
                  scaffoldKey.currentState.openDrawer();
                }
                else{
                  resetApp();
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 5.0,
                      spreadRadius: 0.5,
                      offset: Offset(
                        0.7,
                        0.7,
                      )
                    )
                  ]
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 20,
                  child: Icon((drawerCanOpen) ? Icons.menu : Icons.arrow_back, color: Colors.black87,),
                ),
              ),
            ),
          ),


          /// RideDetails Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSize(
              vsync: this,
              duration: new Duration(milliseconds: 150),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 15.0, // soften the shadow
                      spreadRadius: 0.5, //extend the shadow
                      offset: Offset(
                        0.7, // Move to right 10  horizontally
                        0.7, // Move to bottom 10 Vertically
                      ),
                    )
                  ],

                ),
                height: rideDetailsSheetHeight,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Column(
                    children: <Widget>[

                      Container(
                        width: double.infinity,
                        color: BrandColors.colorAccent1,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: <Widget>[
                              Image.asset('images/taxi.png', height: 70, width: 70,),
                              SizedBox(width: 16,),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(Translations.of(context).text('taxi'), style: TextStyle(fontSize: 18, fontFamily: 'Brand-Bold'),),
                                  Text((tripDirectionDetails != null) ? tripDirectionDetails.distanceText : '', style: TextStyle(fontSize: 16, color: BrandColors.colorTextLight),)

                                ],
                              ),
                              Expanded(child: Container()),
                              Text((tripDirectionDetails != null) ? '\$${HelperMethods.estimateFares(tripDirectionDetails)}' : '', style: TextStyle(fontSize: 18, fontFamily: 'Brand-Bold'),),

                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 22,),

                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: <Widget>[

                            Icon(FontAwesomeIcons.moneyBillAlt, size: 18, color: BrandColors.colorTextLight,),
                            SizedBox(width: 16,),
                            Text(Translations.of(context).text('cash')),
                            SizedBox(width: 5,),
                            Icon(Icons.keyboard_arrow_down, color: BrandColors.colorTextLight, size: 16,),
                          ],
                        ),
                      ),

                      SizedBox(height: 22,),

                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: TaxiButton(
                          title: Translations.of(context).text('request'),
                          color: BrandColors.colorGreen,
                          onPressed: (){

                            setState(() {
                              appState = 'REQUESTING';
                            });
                            showRequestingSheet();

                            availableDrivers = FireHelper.nearbyDriverList;

                            findDriver();

                          },
                        ),
                      )

                    ],
                  ),
                ),
              ),
            ),
          ),

          /// Request Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSize(
              vsync: this,
              duration: new Duration(milliseconds: 150),
              curve: Curves.easeIn,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 15.0, // soften the shadow
                      spreadRadius: 0.5, //extend the shadow
                      offset: Offset(
                        0.7, // Move to right 10  horizontally
                        0.7, // Move to bottom 10 Vertically
                      ),
                    )
                  ],
                ),
                height: requestingSheetHeight,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[

                      SizedBox(height: 10,),

                      SizedBox(
                        width: double.infinity,
                        child: TextLiquidFill(
                        text: Translations.of(context).text('requesting'),
                        waveColor: BrandColors.colorTextSemiLight,
                        boxBackgroundColor: Colors.white,
                        textStyle: TextStyle(
                          color: BrandColors.colorText,
                          fontSize: 22.0,
                          fontFamily: 'Brand-Bold'
                        ),
                        boxHeight: 40.0,
                      ),
                      ),

                      SizedBox(height: 20,),

                      GestureDetector(
                        onTap: (){
                          cancelRequest();
                          resetApp();
                        },
                        child: Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(width: 1.0, color: BrandColors.colorLightGrayFair),

                          ),
                          child: Icon(Icons.close, size: 25,),
                        ),
                      ),

                      SizedBox(height: 10,),

                      Container(
                        width: double.infinity,
                        child: Text(
                          Translations.of(context).text('cancel_ride'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),


                    ],
                  ),
                ),
              ),
            ),
          ),


          /// Trip Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSize(
              vsync: this,
              duration: new Duration(milliseconds: 150),
              curve: Curves.easeIn,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 15.0, // soften the shadow
                      spreadRadius: 0.5, //extend the shadow
                      offset: Offset(
                        0.7, // Move to right 10  horizontally
                        0.7, // Move to bottom 10 Vertically
                      ),
                    )
                  ],
                ),
                height: tripSheetHeight,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[

                      SizedBox(height: 5,),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(tripStatusDisplay,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, fontFamily: 'Brand-Bold'),
                          ),
                        ],
                      ),

                      SizedBox(height: 20,),

                      BrandDivider(),

                      SizedBox(height: 20,),

                      Text(driverCarDetails, style: TextStyle(color: BrandColors.colorTextLight),),

                      Text(driverFullName, style: TextStyle(fontSize: 20),),

                      SizedBox(height: 20,),

                      BrandDivider(),

                      SizedBox(height: 20,),


                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [

                          GestureDetector(
                            onTap: () async {
                              await launch('tel:$driverPhoneNumber');
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [

                                Container(
                                  height: 50,
                                  width: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.all(Radius.circular((25))),
                                    border: Border.all(width: 1.0, color: BrandColors.colorTextLight),
                                  ),
                                  child: Icon(Icons.call),
                                ),

                                SizedBox(height: 10,),

                                Text(Translations.of(context).text('call')),
                              ],
                            ),
                          ),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [

                              Container(
                                height: 50,
                                width: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.all(Radius.circular((25))),
                                  border: Border.all(width: 1.0, color: BrandColors.colorTextLight),
                                ),
                                child: SizedBox(),
                              ),

                              SizedBox(height: 10,),

                              Text(''),
                            ],
                          ),

                          GestureDetector(
                            onTap: (){
                              cancelRequest();
                              resetApp();
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [

                                Container(
                                  height: 50,
                                  width: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.all(Radius.circular((25))),
                                    border: Border.all(width: 1.0, color: BrandColors.colorTextLight),
                                  ),
                                  child: Icon(OMIcons.clear),
                                ),

                                SizedBox(height: 10,),

                                Text(Translations.of(context).text('cancel_rides')),
                              ],
                            ),
                          ),

                        ],
                      )

                    ],
                  ),
                ),
              ),
            ),
          )

        ],
      )
    );
  }

  Future<void> getDirection() async {

    var pickup = Provider.of<AppData>(context, listen: false).pickupAddress;
    var destination =  Provider.of<AppData>(context, listen: false).destinationAddress;

    var pickLatLng = LatLng(pickup.latitude, pickup.longitude);
    var destinationLatLng = LatLng(destination.latitude, destination.longitude);

    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) => ProgressDialog(status: 'Please wait...',)
    );

    var thisDetails = await HelperMethods.getDirectionDetails(pickLatLng, destinationLatLng);

    setState(() {
      tripDirectionDetails = thisDetails;
    });

    Navigator.pop(context);

   PolylinePoints polylinePoints = PolylinePoints();
   List<PointLatLng> results = polylinePoints.decodePolyline(thisDetails.encodedPoints);

    polylineCoordinates.clear();
   if(results.isNotEmpty){
     // loop through all PointLatLng points and convert them
     // to a list of LatLng, required by the Polyline
     results.forEach((PointLatLng point) {
       polylineCoordinates.add(LatLng(point.latitude, point.longitude));
     });
   }

   _polylines.clear();

   setState(() {

     Polyline polyline = Polyline(
       polylineId: PolylineId('polyid'),
       color: Color.fromARGB(255, 95, 109, 237),
       points: polylineCoordinates,
       jointType: JointType.round,
       width: 4,
       startCap: Cap.roundCap,
       endCap: Cap.roundCap,
       geodesic: true,
     );

     _polylines.add(polyline);

   });

   // make polyline to fit into the map

    LatLngBounds bounds;

    if(pickLatLng.latitude > destinationLatLng.latitude && pickLatLng.longitude > destinationLatLng.longitude){
      bounds = LatLngBounds(southwest: destinationLatLng, northeast: pickLatLng);
    }
    else if(pickLatLng.longitude > destinationLatLng.longitude){
      bounds = LatLngBounds(
        southwest: LatLng(pickLatLng.latitude, destinationLatLng.longitude),
        northeast: LatLng(destinationLatLng.latitude, pickLatLng.longitude)
      );
    }
    else if(pickLatLng.latitude > destinationLatLng.latitude){
      bounds = LatLngBounds(
        southwest: LatLng(destinationLatLng.latitude, pickLatLng.longitude),
        northeast: LatLng(pickLatLng.latitude, destinationLatLng.longitude),
      );
    }
    else{
      bounds = LatLngBounds(southwest: pickLatLng, northeast: destinationLatLng);
    }

    mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));

    Marker pickupMarker = Marker(
      markerId: MarkerId('pickup'),
      position: pickLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(title: pickup.placeName, snippet: 'My Location'),
    );

    Marker destinationMarker = Marker(
      markerId: MarkerId('destination'),
      position: destinationLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(title: destination.placeName, snippet: 'Destination'),
    );

    setState(() {
      _Markers.add(pickupMarker);
      _Markers.add(destinationMarker);
    });

    Circle pickupCircle = Circle(
      circleId: CircleId('pickup'),
      strokeColor: Colors.green,
      strokeWidth: 3,
      radius: 12,
      center: pickLatLng,
      fillColor: BrandColors.colorGreen,
    );

    Circle destinationCircle = Circle(
      circleId: CircleId('destination'),
      strokeColor: BrandColors.colorAccentPurple,
      strokeWidth: 3,
      radius: 12,
      center: destinationLatLng,
      fillColor: BrandColors.colorAccentPurple,
    );



    setState(() {
      _Circles.add(pickupCircle);
      _Circles.add(destinationCircle);
    });

  }

  void startGeofireListener() {
    
    Geofire.initialize('driversAvailable');
    Geofire.queryAtLocation(currentPosition.latitude, currentPosition.longitude, 20).listen((map) {

      if (map != null) {
        var callBack = map['callBack'];

        switch (callBack) {
          case Geofire.onKeyEntered:

            NearbyDriver nearbyDriver = NearbyDriver();
            nearbyDriver.key = map['key'];
            nearbyDriver.latitude = map['latitude'];
            nearbyDriver.longitude = map['longitude'];
            FireHelper.nearbyDriverList.add(nearbyDriver);

            if(nearbyDriversKeysLoaded){
              updateDriversOnMap();
            }
            break;

          case Geofire.onKeyExited:
            FireHelper.removeFromList(map['key']);
            updateDriversOnMap();
            break;

          case Geofire.onKeyMoved:
          // Update your key's location

            NearbyDriver nearbyDriver = NearbyDriver();
            nearbyDriver.key = map['key'];
            nearbyDriver.latitude = map['latitude'];
            nearbyDriver.longitude = map['longitude'];

            FireHelper.updateNearbyLocation(nearbyDriver);
            updateDriversOnMap();
            break;

          case Geofire.onGeoQueryReady:

            nearbyDriversKeysLoaded = true;
            updateDriversOnMap();
            break;
        }
      }
    });
  }

  void updateDriversOnMap(){
    setState(() {
      _Markers.clear();
    });

    Set<Marker> tempMarkers = Set<Marker>();

    for (NearbyDriver driver in FireHelper.nearbyDriverList){

      LatLng driverPosition = LatLng(driver.latitude, driver.longitude);
      Marker thisMarker = Marker(
        markerId: MarkerId('driver${driver.key}'),
        position: driverPosition,
        icon: nearbyIcon,
        rotation: HelperMethods.generateRandomNumber(360),
      );

      tempMarkers.add(thisMarker);
    }

    setState(() {
      _Markers = tempMarkers;
    });

  }

  void createRideRequest(){

    rideRef = FirebaseDatabase.instance.reference().child('rideRequest').push();

    var pickup = Provider.of<AppData>(context, listen: false).pickupAddress;
    var destination = Provider.of<AppData>(context, listen: false).destinationAddress;

    Map pickupMap = {
      'latitude': pickup.latitude.toString(),
      'longitude': pickup.longitude.toString(),
    };

    Map destinationMap = {
      'latitude': destination.latitude.toString(),
      'longitude': destination.longitude.toString(),
    };

    Map rideMap = {
      'created_at': DateTime.now().toString(),
      'rider_name': currentUserInfo.fullName,
      'rider_phone': currentUserInfo.phone,
      'pickup_address' : pickup.placeName,
      'destination_address': destination.placeName,
      'location': pickupMap,
      'destination': destinationMap,
      'payment_method': 'card',
      'driver_id': 'waiting',
    };

    rideRef.set(rideMap);

    rideSubscription = rideRef.onValue.listen((event) async {

      //check for null snapshot
      if(event.snapshot.value == null){
        return;
      }

      //get car details
      if(event.snapshot.value['car_details'] != null){
        setState(() {
          driverCarDetails = event.snapshot.value['car_details'].toString();
        });
      }

      // get driver name
      if(event.snapshot.value['driver_name'] != null){
        setState(() {
          driverFullName = event.snapshot.value['driver_name'].toString();
        });
      }

      // get driver phone number
      if(event.snapshot.value['driver_phone'] != null){
        setState(() {
          driverPhoneNumber = event.snapshot.value['driver_phone'].toString();
        });
      }


      //get and use driver location updates
      if(event.snapshot.value['driver_location'] != null){

        double driverLat = double.parse(event.snapshot.value['driver_location']['latitude'].toString());
        double driverLng = double.parse(event.snapshot.value['driver_location']['longitude'].toString());
        LatLng driverLocation = LatLng(driverLat, driverLng);

        if(status == 'accepted'){
          updateToPickup(driverLocation);
        }
        else if(status == 'ontrip'){
          updateToDestination(driverLocation);
        }
        else if(status == 'arrived'){
          setState(() {
            tripStatusDisplay = 'Driver has arrived';
          });
        }

      }


      if(event.snapshot.value['status'] != null){
        status = event.snapshot.value['status'].toString();
      }

      if(status == 'accepted'){
        showTripSheet();
        Geofire.stopListener();
        removeGeofireMarkers();
      }

      if(status == 'ended'){

        if(event.snapshot.value['fares'] != null) {

          int fares = int.parse(event.snapshot.value['fares'].toString());

          var response = await showDialog(
              context: context,
            barrierDismissible: false,
            builder: (BuildContext context) => CollectPayment(paymentMethod: 'cash', fares: fares,),
          );

          if(response == 'close'){
            rideRef.onDisconnect();
            rideRef = null;
            rideSubscription.cancel();
            rideSubscription = null;
            resetApp();
          }

        }
      }

    });

  }

  void removeGeofireMarkers(){
    setState(() {
      _Markers.removeWhere((m) => m.markerId.value.contains('driver'));
    });
  }

  void updateToPickup(LatLng driverLocation) async {

    LatLng oldPosition = LatLng(0,0);

    if(!isRequestingLocationDetails){

      isRequestingLocationDetails = true;

      var positionLatLng = LatLng(currentPosition.latitude, currentPosition.longitude);

      var thisDetails = await HelperMethods.getDirectionDetails(driverLocation, positionLatLng);

      if(thisDetails == null){
        return;
      }

      var rotation = MapKitHelper.getMarkerRotation(oldPosition.latitude, oldPosition.longitude, driverLocation.latitude, driverLocation.longitude);



      Marker drivers = Marker(
        markerId: MarkerId('drivers'),
        position: driverLocation,
        icon: nearbyIcon,
        rotation: rotation,
        infoWindow: InfoWindow(title: 'Driver Location')
      );

      setState(() {
        tripStatusDisplay = 'Driver is Arriving - ${thisDetails.durationText}';
        _Markers.add(drivers);
      });

      isRequestingLocationDetails = false;

    }


  }

  void updateToDestination(LatLng driverLocation) async {

    LatLng oldPosition = LatLng(0,0);

    if(!isRequestingLocationDetails){

      isRequestingLocationDetails = true;

      var destination = Provider.of<AppData>(context, listen: false).destinationAddress;

      var destinationLatLng = LatLng(destination.latitude, destination.longitude);

      var thisDetails = await HelperMethods.getDirectionDetails(driverLocation, destinationLatLng);

      if(thisDetails == null){
        return;
      }

      var rotation = MapKitHelper.getMarkerRotation(oldPosition.latitude, oldPosition.longitude, driverLocation.latitude, driverLocation.longitude);



      Marker drivers = Marker(
        markerId: MarkerId('drivers'),
        position: driverLocation,
        icon: nearbyIcon,
        rotation: rotation,
        infoWindow: InfoWindow(title: 'Driver Location')
      );

      setState(() {
        tripStatusDisplay = 'Driving to Destination - ${thisDetails.durationText}';
        _Markers.add(drivers);
      });

      isRequestingLocationDetails = false;

    }


  }

  void cancelRequest(){
    rideRef.remove();

    setState(() {
      appState = 'NORMAL';
    });
  }

  resetApp(){

    setState(() {

      polylineCoordinates.clear();
      _polylines.clear();
      _Markers.clear();
      _Circles.clear();
      rideDetailsSheetHeight = 0;
      requestingSheetHeight = 0;
      tripSheetHeight = 0;
      searchSheetHeight = (Platform.isAndroid) ? 135 : 150;
      mapBottomPadding = (Platform.isAndroid) ? 130 : 140;
      drawerCanOpen = true;

      status = '';
      driverFullName = '';
      driverPhoneNumber = '';
      driverCarDetails = '';
      tripStatusDisplay = 'Driver is Arriving';

    });

   setupPositionLocator();

  }

  void noDriverFound(){
    showDialog(
        context: context,
      barrierDismissible: false,
        builder: (BuildContext context) => NoDriverDialog()
    );
  }

  void findDriver (){

    if(availableDrivers.length == 0){
      cancelRequest();
      resetApp();
      noDriverFound();
      return;
    }

    var driver = availableDrivers[0];

    notifyDriver(driver);

    availableDrivers.removeAt(0);

    print(driver.key);

  }

  void notifyDriver(NearbyDriver driver){

    DatabaseReference driverTripRef = FirebaseDatabase.instance.reference().child('drivers/${driver.key}/newtrip');
    driverTripRef.set(rideRef.key);

    // Get and notify driver using token
    DatabaseReference tokenRef = FirebaseDatabase.instance.reference().child('drivers/${driver.key}/token');

    tokenRef.once().then((DataSnapshot snapshot){

      if(snapshot.value != null){

        String token = snapshot.value.toString();

        // send notification to selected driver
        HelperMethods.sendNotification(token, context, rideRef.key);
      }
      else{

        return;
      }

      const oneSecTick = Duration(seconds: 1);

      var timer = Timer.periodic(oneSecTick, (timer) {

        // stop timer when ride request is cancelled;
        if(appState != 'REQUESTING'){
          driverTripRef.set('cancelled');
          driverTripRef.onDisconnect();
          timer.cancel();
          driverRequestTimeout = 30;
        }


        driverRequestTimeout --;

        // a value event listener for driver accepting trip request
        driverTripRef.onValue.listen((event) {

          // confirms that driver has clicked accepted for the new trip request
          if(event.snapshot.value.toString() == 'accepted'){
            driverTripRef.onDisconnect();
            timer.cancel();
            driverRequestTimeout = 30;
          }
        });


        if(driverRequestTimeout == 0){

          //informs driver that ride has timed out
          driverTripRef.set('timeout');
          driverTripRef.onDisconnect();
          driverRequestTimeout = 30;
          timer.cancel();

          //select the next closest driver
          findDriver();
        }


      });


    });

  }

}
