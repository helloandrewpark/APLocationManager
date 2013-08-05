/*
 Wrapper for CLLocationManager so you don't have to import and set delegates for every view controller
 To use:
 
 In header
 #import "APLocationManager.h"
 
 In Implementation
 APLocationManager *locationManager = [[APLocationManager alloc] init];
 [locationManager getCoordinateWithBlock...]
 
 Author: Andrew Park
 */

typedef enum{
    APLMcoordinate,
    APLMcity
} APLMmode;
#import <Foundation/Foundation.h>

#import <CoreLocation/CoreLocation.h>
#import <AddressBook/AddressBook.h>

@interface APLocationManager : NSObject<CLLocationManagerDelegate>

@property (assign) BOOL enableCache;
@property (assign) int geopointLocationCacheTime;//default cache time is 5*60 seconds

+ (APLocationManager *)sharedInstance;
/*
 Gets the users location with latitude and longitude
 @return NSDictionary with keys:
            CLLocation = (CLLocation) the CLLocation object corresponding to their GPS location
            dt = (NSDate) the date that the location was retrieved (when location manager obtained it, not when request was called)
 */
- (void)getCoordinateWithBlock:(void(^)(NSDictionary *response, NSError *error))handler;
/*
 Uses CLGeoCoder to convert a CLLocation to a placemark
 @return NSDictionary with keys:
            CLLocation = (CLLocation) the CLLocation object corresponding to their GPS location
            city = (NSString) city name of location
            state = (NSString) state name of location
            dt = (NSDate) the date that the location was retrieved (when location manager obtained it, not when request was called)
 */
- (void)getCityAndStateOfCoordinate:(CLLocation*)location callback:(void (^)(NSDictionary *response, NSError *error))handler;
/*
Convience method of getting city with just 1 call. otherwise you would have to do
 [manager getCoordinateWithBlock:^(NSDictionary *response, NSError *error) {
    if(error){
        NSLog(@"%@",error.description);
        return;
    }
    CLLocation *location = [response objectForKey:@"CLLocation"];
    [manager getCityAndStateOfCoordinate: location callback:^(NSDictionary *response, NSError *error) {
        if(error){
             NSLog(@"%@",error.description);
             return;
        }
        YAY GOT CITY!
    }];
 }];
 */
- (void)getCityWithBlock:(void(^)(NSDictionary *response, NSError *error))handler;

- (void)clearCache;
//Checks if application has location authorization
- (BOOL)isAuthorized;
/*
 Returns 2 letter representation of a state (i.e. CA, NY)
 */
- (NSString*)get2LetterRepresentationForState:(NSString*)fullStateName;
//calculates distance with haversine formula
- (CGFloat)getMilesBetween:(CLLocation*)point1 and:(CLLocation*)point2;
@end
