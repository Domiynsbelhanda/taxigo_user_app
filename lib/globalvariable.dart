
import 'package:taxigo_user_app/datamodels/user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';


String serverKey = 'key=AAAA36PfQio:APA91bHwaOhOMCmCcA9J-YSI0MoOHpd4CQqaY2abbYjbr-s8V02XnVzSzhRUjHHufnZeF9Vk3IagdK0FfhmuZSEvsgTXD_L04d4pqAfdZgz76JnDumrQ46hu7He2L4o8bqH0z8vGTn20';

String mapKey = 'AIzaSyDMU4bZSvasDrSFyf5WNrLsxU1vqJ5pMsI';

final CameraPosition googlePlex = CameraPosition(
  target: LatLng(37.42796133580664, -122.085749655962),
  zoom: 14.4746,
);

User currentFirebaseUser;

Users currentUserInfo;

String langue;
