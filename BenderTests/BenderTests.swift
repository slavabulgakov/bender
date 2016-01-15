//
//  BenderTests.swift
//  BenderTests
//
//  Created by Evgenii Kamyshanov on 04.01.16.
//  Copyright © 2016 Evgenii Kamyshanov.
//
//  The MIT License (MIT)
//
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included
//  in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import XCTest
import Quick
import Nimble

@testable import Bender

class Passport {
    var number: Int?
    var issuedBy: String! = nil
    var valid: Bool = true
}

class Person {
    var name: String! = nil
    var age: Float! = nil
    var passport: Passport! = nil
    var oldPass: Passport?
    var nested: [Passport] = []
}

class Passports {
    var items: [Passport] = []
    var numbers: [Int] = []
}

enum IssuedBy {
    case Unknown
    case FMS
    case SMS
    case OPG
}

enum Active {
    case Active
    case Inactive
}

class Pass {
    var issuedBy: IssuedBy = .Unknown
    var active: Active = .Inactive
}

class Folder {
    var name: String = ""
    var size: Int64 = 0
    var folders: [Folder] = []
}

class BenderTests: QuickSpec {
 
    override func spec() {
        
        describe("Basic struct validation") {
            it("should perform nested struct validating and binding") {
                
                let jsonObject = jsonFromFile("basic_test")
                
                let passportRule = StructRule(Passport())
                    .expect("issuedBy", StringRule, { $0.issuedBy = $1 })
                    .optional("number", IntRule, { $0.number = $1 })
                    .expect("valid", BoolRule, { $0.valid = $1 })
                
                let personRule = StructRule(Person())
                    .expect("name", StringRule) { $0.name = $1 }
                    .expect("age", FloatRule) { $0.age = $1 }
                    .expect("passport", passportRule, { $0.passport = $1 })
                    .optional("oldPass", passportRule, { $0.oldPass = $1 })

                do {
                    let person = try personRule.validate(jsonObject)
                    
                    expect(person).toNot(beNil())
                    
                    expect(person.age).to(equal(37.5))
                    
                    expect(person.passport).toNot(beNil())
                    expect(person.passport.number).to(equal(123))
                    expect(person.passport.valid).to(equal(true))
                    
                    expect(person.oldPass).to(beNil())
                    
                } catch let err {
                    expect(false).to(equal(true), description: "\(err)")
                }
            }
            
            it("should handle recurisively nested structs") {
                
                let jsonObject = jsonFromFile("recursive_test")
                
                let folderRule = StructRule(Folder())
                    .expect("name", StringRule) { $0.name = $1 }
                    .expect("size", Int64Rule) { $0.size = $1 }
                
                folderRule
                    .optional("folders", ArrayRule(itemRule: folderRule)) { $0.folders = $1 }
                
                do {
                    let folder = try folderRule.validate(jsonObject)
                    
                    expect(folder).toNot(beNil())
                    expect(folder.folders.count).to(equal(2))
                    expect(folder.folders[1].name).to(equal("nested 2"))
                    expect(folder.folders[1].folders.count).to(equal(1))
                    expect(folder.folders[1].folders[0].name).to(equal("nested 21"))
                    
                } catch let err {
                    expect(false).to(equal(true), description: "\(err)")
                }
                
            }
            
            it("should throw if expected field does not exist") {
                
                let jsonObject = jsonFromFile("basic_test")
                
                let passportRule = StructRule(Passport())
                    .expect("issued", StringRule) { $0.issuedBy = $1 }
                    .optional("number", IntRule) { $0.number = $1 }
                
                let personRule = StructRule(Person())
                    .expect("passport", passportRule) { $0.passport = $1 }

                expect{ try personRule.validate(jsonObject) }.to(throwError(ValidateError.InvalidJSONType("", nil)))
                expect{ try personRule.validate(jsonObject) }.to(throwError { (error: ValidateError) in
                        expect(error.description).to(equal("Error validating mandatory field \"passport\" for Person.\nError validating \"[\"valid\": 1, \"issuedBy\": FMS, \"number\": 123]\" as Passport. Mandatory field \"issued\" not found in struct."))
                    })
            }
            
            it("should throw if expected field is of wrong type") {
                
                let jsonObject = jsonFromFile("basic_test")
                
                let personRule = StructRule(Person())
                    .expect("name", FloatRule) { $0.age = $1 }
                
                expect{ try personRule.validate(jsonObject) }.to(throwError(ValidateError.InvalidJSONType("", nil)))
                expect{ try personRule.validate(jsonObject) }.to(throwError { (error: ValidateError) in
                        expect(error.description).to(equal("Error validating mandatory field \"name\" for Person.\nValue of unexpected type found: \"John\". Expected Float."))
                    })
            }
            
        }
        
        describe("Array validation") {
            it("should perform array validation as field in struct") {
                
                let jsonObject = jsonFromFile("array_test")
                
                let passportRule = StructRule(Passport())
                    .optional("issuedBy", StringRule, { $0.issuedBy = $1 })
                    .expect("number", IntRule, { $0.number = $1 })
                
                let passportArrayRule = ArrayRule(itemRule: passportRule)
                
                let passportsRule = StructRule(Passports())
                    .expect("passports", passportArrayRule, { $0.items = $1 })
                    .expect("numbers", ArrayRule(itemRule: IntRule), { $0.numbers = $1 })
                
                do {
                    let passports = try passportsRule.validate(jsonObject)
                    
                    expect(passports.items.count).to(equal(3))
                    expect(passports.numbers.count).to(equal(7))
                    
                    expect(passports.items[2].number).to(equal(333))
                    expect(passports.numbers[6]).to(equal(27))
                    
                } catch let err {
                    expect(false).to(equal(true), description: "\(err)")
                }
                
            }
            
            it("should perform array validation as root object") {
                
                let jsonObject = jsonFromFile("natural_array_test")
                let arrayRule = ArrayRule(itemRule: IntRule)
                
                do {
                    let numbers = try arrayRule.validate(jsonObject)
                    
                    expect(numbers.count).to(equal(5))
                    expect(numbers[4]).to(equal(199))
                    
                } catch let err {
                    expect(false).to(equal(true), description: "\(err)")
                }
            }
            
            it("should throw if an item struct is of wrong type") {
                
                let jsonObject = jsonFromFile("array_test")
                
                let passportRule = StructRule(Passport())
                    .optional("issuedBy", StringRule) { $0.issuedBy = $1 }
                    .expect("numberX", IntRule) { $0.number = $1 }
                
                let passportArrayRule = ArrayRule(itemRule: passportRule)
                
                let passportsRule = StructRule(Passports())
                    .expect("passports", passportArrayRule, { $0.items = $1 })
                    .expect("numbers", ArrayRule(itemRule: IntRule), { $0.numbers = $1 })
                
                expect{ try passportsRule.validate(jsonObject) }.to(throwError(ValidateError.InvalidJSONType("", nil)))
                expect{ try passportsRule.validate(jsonObject) }.to(throwError { (error: ValidateError) in
                        expect(error.description).to(equal("Error validating mandatory field \"passports\" for Passports.\nError validating array of Passport: item #1 could not be validated.\nError validating \"[\"issuedBy\": FMS1, \"number\": 111]\" as Passport. Mandatory field \"numberX\" not found in struct."))
                    })
            }
            
        }
        
        describe("Enum validtion") {
            it("should performs enum validation of any internal type") {
                
                let jsonObject = jsonFromFile("enum_test")
                
                let enumRule = EnumRule<IssuedBy>()
                    .option("FMS", .FMS)
                    .option("SMS", .SMS)
                    .option("OPG", .OPG)
                    .option(0, .Unknown)                
                
                let intEnumRule = EnumRule<Active>()
                    .option(0, .Inactive)
                    .option(1, .Active)
                
                let testRule = StructRule(Pass())
                    .expect("issuedBy", enumRule) { $0.issuedBy = $1 }
                    .expect("active", intEnumRule) { $0.active = $1 }
                
                let testRules = ArrayRule(itemRule: testRule)
                
                do {
                    let tests = try testRules.validate(jsonObject)
                    
                    expect(tests.count).to(equal(4))
                    
                    expect(tests[1].active).to(equal(Active.Inactive))
                    expect(tests[1].issuedBy).to(equal(IssuedBy.SMS))
                    
                } catch let err {
                    expect(false).to(equal(true), description: "\(err)")
                }
                
            }
            
            it("should throw if enum is not in set of values provided") {
                let jsonObject = jsonFromFile("enum_test")
                
                let enumRule = EnumRule<IssuedBy>()
                    .option("XMS", .FMS)
                    .option("XMS", .SMS)
                    .option("XPG", .OPG)
                    .option(0, .Unknown)
                
                let testRule = StructRule(Pass())
                    .expect("issuedBy", enumRule) { $0.issuedBy = $1 }
                
                let testRules = ArrayRule(itemRule: testRule)
                
                expect{ try testRules.validate(jsonObject) }.to(throwError(ValidateError.InvalidJSONType("", nil)))
                expect{ try testRules.validate(jsonObject) }.to(throwError { (error: ValidateError) in
                    expect(error.description).to(equal("Error validating array of Pass: item #1 could not be validated.\nError validating mandatory field \"issuedBy\" for Pass.\nError validating enum IssuedBy. Invalid enum case found: \"FMS\"."))
                    })

            }
        }
        
        describe("Stringified JSON validation") {
            it("should perform validation in accordance with the nested rule") {
                
                let jsonObject = jsonFromFile("stringified_test")
                
                let passportRule = StructRule(Passport())
                    .expect("issuedBy", StringRule, { $0.issuedBy = $1 })
                    .optional("number", IntRule, { $0.number = $1 })
                    .expect("valid", BoolRule, { $0.valid = $1 })
                
                let personRule = StructRule(Person())
                    .expect("passport", StringifiedJSONRule(nestedRule: passportRule), { $0.passport = $1 })
                    .optional("passports", StringifiedJSONRule(nestedRule: ArrayRule(itemRule: passportRule))) { $0.nested = $1 }
                
                do {
                    let person = try personRule.validate(jsonObject)
                    
                    expect(person).toNot(beNil())
                    
                    expect(person.passport).toNot(beNil())
                    expect(person.passport.number).to(equal(123))
                    expect(person.passport.valid).to(equal(true))
                    
                    expect(person.nested.count).to(equal(2))
                    
                } catch let err {
                    expect(false).to(equal(true), description: "\(err)")
                }
            }
            
            it("should throw on parse error: comma absent after the 'number' field definition") {
                
                let jsonObject = jsonFromFile("stringified_negative_test")
                
                let passportRule = StructRule(Passport())
                    .expect("issuedBy", StringRule, { $0.issuedBy = $1 })
                
                let personRule = StructRule(Person())
                    .expect("passport", StringifiedJSONRule(nestedRule: passportRule), { $0.passport = $1 })
                
                expect{ try personRule.validate(jsonObject) }.to(throwError(ValidateError.InvalidJSONType("", nil)))
                expect{ try personRule.validate(jsonObject) }.to(throwError { (error: ValidateError) in
                    expect(error.description).to(equal("Error validating mandatory field \"passport\" for Person.\nUnable to parse stringified JSON: {\"number\": 123 \"issuedBy\": \"FMS\", \"valid\": true}.\nBadly formed object around character 15."))
                    })

            }
        }
    }
}

func jsonFromFile(name: String) -> AnyObject {
    let data = NSData(contentsOfFile: NSBundle(forClass: BenderTests.self).pathForResource(name, ofType: "json")!)!
    return try! NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
}
