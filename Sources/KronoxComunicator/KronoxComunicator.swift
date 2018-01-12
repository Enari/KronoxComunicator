//
//  KronoxComunicator.swift
//  Glassmaskin
//
//  Created by Anton Roslund on 2017-10-24.
//  Copyright © 2017 Anton Roslund. All rights reserved.
//

import Foundation
import SwiftSoup
import Just

struct Booking {
    let bokningsId : String
    let date : String
    let time : String
    let room : String
    let booker : String
}

class KronoxComunicator {
    public var sessionCookie : HTTPCookie?
    var timer = Timer()
    
    init() {
        // Starts the session
        startSession()
        
        // Schedulle the keep alive function to run every 20 minutes.
        timer = Timer.scheduledTimer(timeInterval: 1200, target: self, selector: #selector(self.sessionKeepAlive), userInfo: nil, repeats: true)
    }
    
    func startSession(){
        sessionCookie = Just.post("https://webbschema.mdh.se/login_do.jsp").cookies["JSESSIONID"]!
    }
    
    @discardableResult
    func login(username : String, password : String) -> (status: Bool, message: String) {
        let parameters = ["username": username , "password": password]
        let request = Just.get("http://webbschema.mdh.se/ajax/ajax_login.jsp", params : parameters, cookies: ["JSESSIONID": sessionCookie!.value])
        
        if request.text != "OK" {
            return (false, request.text!)
        }
        return (true, request.text!)
    }
    
    @discardableResult
    func makeBooking(date : Date, room : String, interval : String, comment : String = "") -> (status: Bool, message: String) {
        
        let dateStringFormatter = DateFormatter()
        dateStringFormatter.dateFormat = "yy-MM-dd"
        
        let parameters = ["op": "boka", "datum": dateStringFormatter.string(from: date), "id": room, "typ": "RESURSER_LOKALER", "intervall" : interval, "moment" : comment, "flik" : "FLIK_0001"]
        let request = Just.get("http://webbschema.mdh.se/ajax/ajax_resursbokning.jsp", params : parameters, cookies: ["JSESSIONID": sessionCookie!.value])
        
        if(request.text! != "OK") {
            return (false, request.text!)
        }
        return (true, request.text!)
    }
    
    func unBook(bokningsID : String) -> (status: Bool, message: String) {
        let parameters = ["op": "avboka", "bokningsId": bokningsID]
        let request = Just.get("http://webbschema.mdh.se/ajax/ajax_resursbokning.jsp", params : parameters, cookies: ["JSESSIONID": sessionCookie!.value])
        
        if(request.text! != "OK") {
            return (false, request.text!)
        }
        return (true, request.text!)
    }
    
    func getMyBookings() -> [Booking] {
        var bookings : [Booking] = []
        
        
        // Make request and get HTML
        let parameters = ["flik": "FLIK_0001", "datum": "00-00-00"]
        let request = Just.get("http://webbschema.mdh.se/minaresursbokningar.jsp", params : parameters, cookies: ["JSESSIONID": sessionCookie!.value])
        let html : String = request.text!
        
        
        do{
            let doc: Document = try! SwiftSoup.parseBodyFragment(html)
            let body: Element = doc.body()!
            
            let bookingsDivs = try body.getElementsByAttributeValue("style", "padding:5px;margin-bottom:10px;margin-top:10px;border:1px solid #E6E7E6;background:#FFF;")
            
            
            for booking in bookingsDivs {
                let bokningsId = try booking.attr("id").suffix(5)
                let date = try "20" + booking.select("a").first()!.html()
                let time = booking.getChildNodes().first!.getChildNodes()[1].description.suffix(1)
                let room = try booking.select("b").html().suffix(16)
                let booker = try booking.select("b").html().suffix(8).prefix(3)
                
                bookings.append(Booking(bokningsId: String(bokningsId), date: date, time: String(time), room: String(room), booker : String(booker)))
            }
        }
        catch Exception.Error(_, let message) {
            print(message)
        }
        catch{
            print("error")
        }
        
        return bookings
    }
    
    func getBookings(_ date : Date = Date()) -> [[String]] {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yy-MM-dd"
        
        let parameters = ["op" : "hamtaBokningar", "datum": dateFormatter.string(from: date), "flik": "FLIK_0001"]
        let request = Just.get("http://webbschema.mdh.se/ajax/ajax_resursbokning.jsp", params : parameters, cookies: ["JSESSIONID": sessionCookie!.value])
        
        let html : String = request.text!
        
        var rows : [[String]] = []
        
        do{
            
            let doc: Document = try! SwiftSoup.parseBodyFragment(html)
            let body: Element = doc.body()!
            
            var tableRows = try body.select("table").select("tbody").first()!.select("tr").array()
            
            //Remove the first row, since it only contains the times.
            tableRows.removeFirst()
            
            for tableRow in tableRows {
                var row : [String] = []
                let cells = try tableRow.getElementsByTag("td")
                
                //Loop throught all the cells
                for cell in cells {
                    if try cell.className() == "grupprum-kolumn" {
                        row.append(try cell.getElementsByTag("b").html())
                    }
                    else if try cell.classNames().contains("grupprum-upptagen")   {
                        //row.append(try cell.getElementsByTag("center").html().substring(0, 8))
                        row.append(try cell.getElementsByTag("center").html().components(separatedBy: " ")[0])
                    }
                    else if try cell.className() == "grupprum-ledig grupprum-kolumn" {
                        row.append("Ledig")
                    }
                    else if try cell.className() == "grupprum-passerad grupprum-kolumn" {
                        row.append("Passerad")
                    }
                    else {
                        let classname = try cell.className()
                        print("Error, unkknow class: " + classname)
                    }
                    
                }
                rows.append(row)
            }
            
        }
        catch Exception.Error(_, let message) {
            print(message)
        }
        catch{
            print("error")
        }
        
        return(rows)
    }
    
    // Keeps the "Session" on the server active.
    @objc public func sessionKeepAlive() {
        let parameters = ["op": "poll"]
        let request = Just.get("http://webbschema.mdh.se/ajax/ajax_session.jsp", params : parameters, cookies: ["JSESSIONID": sessionCookie!.value])
        
        if request.text! != "OK" {
            print("Session Timed Out")
        }
    }
    
    func getUserId() -> String {
        let parameters = ["op": "anvandarId"]
        let request = Just.get("http://webbschema.mdh.se/ajax/ajax_session.jsp", params : parameters, cookies: ["JSESSIONID": sessionCookie!.value])
        
        if(request.text! == "INLOGGNING KRÄVS") {
            return ""
        }
        
        return(request.text!)
    }
    
    func isLoggedIn() -> Bool {
        let parameters = ["op": "anvandarId"]
        let request = Just.get("http://webbschema.mdh.se/ajax/ajax_session.jsp", params : parameters, cookies: ["JSESSIONID": sessionCookie!.value])
        
        if(request.text! == "INLOGGNING KRÄVS") {
            return false
        }
        return true
    }
    
}

extension KronoxComunicator {
    convenience init(JSESSIONID: String) {
        let cookieProps: [HTTPCookiePropertyKey : Any] = [
            HTTPCookiePropertyKey.domain: "webbschema.mdh.se",
            HTTPCookiePropertyKey.path: "/",
            HTTPCookiePropertyKey.name: "JSESSIONID",
            HTTPCookiePropertyKey.value: JSESSIONID,
            HTTPCookiePropertyKey.secure: "TRUE"
        ]
        
        self.init()
        self.sessionCookie = HTTPCookie(properties: cookieProps)!
    }
}

