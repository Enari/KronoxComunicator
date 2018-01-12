# KronoxComunicator
A library for communicating with the website for booking group rooms at Mälardalen University (MDH).


## Introduction
Mälardalen University provides limited places to studdy. The School has bookable group rooms that has to be booked in advance. For students the rooms can be booked one week in advance, and generally you have to. This library provides an easy way to comunicate with the booking service.


## Example usage
Logging in and getting bookings.
```swift
let kronoxComm = KronoxComunicator();
kronoxComm.login(username: "username", password: "password")
kronoxComm.getMyBookings()
```

Starting a session from cookie (JSESSIONID) and making a booking.
```swift
let kronoxComm = KronoxComunicator("wshQC7-qgzzGH-tt0y8x+8dL");
kronoxComm.makeBooking(date: "2018-01-01", room: "U2-271", interval: 1, comment: "Example Booking")
```
