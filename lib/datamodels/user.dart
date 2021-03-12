

import 'package:firebase_database/firebase_database.dart';

class Users{
  String fullName;
  String email;
  String phone;
  String id;
  String image;

  Users({
    this.email,
    this.fullName,
    this.phone,
    this.id,
    this.image
  });

  Users.fromSnapshot(DataSnapshot snapshot){
    id = snapshot.key;
    phone = snapshot.value['phone'];
    email = snapshot.value['email'];
    fullName = snapshot.value['fullname'];
    image = snapshot.value["image"];
  }

}