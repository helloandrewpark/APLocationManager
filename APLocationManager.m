//
//  APLocationManager
//
//  Created by Andrew Park on 7/17/12.
//  Copyright (c) 2012 . All rights reserved.
//
#define APLM_DEBUG 0

#import "APLocationManager.h"

@interface APLocationManager (){
    NSUserDefaults *def;
    CLLocationManager *locationManager;
    CLGeocoder *geoCoder;
    APLMmode mode;
    NSMutableArray *coordinateBlockStack;
    NSMutableArray *cityBlockStack;
}
- (BOOL)cachedLocationIsValid;
- (void)privateGetCityAndStateOfCoordinate:(CLLocation*)location callback:(void (^)(NSDictionary *response, NSError *error))handler;
- (void)coordinateQueryCompleted:(NSDictionary*)dictionary withError:(NSError*)error;
- (void)cityQueryCompleted:(NSDictionary*)dictionary withError:(NSError*)error;
@end

@implementation APLocationManager
@synthesize geopointLocationCacheTime;
@synthesize enableCache;

+ (APLocationManager *)sharedInstance
{
    static APLocationManager *sharedInstance = nil;
    static dispatch_once_t pred;
    
    dispatch_once(&pred, ^{
        sharedInstance = [APLocationManager alloc];
        sharedInstance = [sharedInstance init];
    });
    
    return sharedInstance;
}

- (id)init
{
    if (self = [super init]) {
        mode = APLMcoordinate;//default mode is to retrieve coordinates only
        self.geopointLocationCacheTime = 60*5;
        self.enableCache = YES;
        
        def = [NSUserDefaults standardUserDefaults];
        coordinateBlockStack = [NSMutableArray array];
        cityBlockStack = [NSMutableArray array];
        
        locationManager = [[CLLocationManager alloc] init];
        locationManager.delegate = self;
        locationManager.distanceFilter = 100;
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
        
        geoCoder = [[CLGeocoder alloc] init];
    }
    return self;
}

- (BOOL)isAuthorized
{
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    switch (status) {
        case kCLAuthorizationStatusAuthorized:
            return YES;
            break;
        default:
            return NO;
            break;
    }
}

- (void)getCoordinateWithBlock:(void (^)(NSDictionary *, NSError *))handler
{
    if(APLM_DEBUG)NSLog(@"Coordinate requested");
    mode = APLMcoordinate;
    if (handler) {
        void (^handlerCopy)(NSDictionary *, NSError *) = [handler copy];
        [coordinateBlockStack addObject:handlerCopy];
    }
    if ([self cachedLocationIsValid]) {
        if(APLM_DEBUG)NSLog(@"Coordinate cache valid. returning cache");
        NSDictionary *dict = [def objectForKey:@"APLMCachedLocation"];
        double latitude = [[dict objectForKey:@"lat"] doubleValue];
        double longitude = [[dict objectForKey:@"lng"] doubleValue];
        CLLocation *location = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
        NSDictionary *response = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSDate date],@"dt",
                                  location, @"CLLocation",
                                  nil];
        [self coordinateQueryCompleted:response withError:nil];
        return;
    }
    if(APLM_DEBUG)NSLog(@"Querying for coordinate");
    [locationManager startUpdatingLocation];
}

- (void)getCityWithBlock:(void (^)(NSDictionary *, NSError *))handler
{
    if(APLM_DEBUG)NSLog(@"City requested");
    mode = APLMcity;
    if (handler) {
        void (^handlerCopy)(NSDictionary *,NSError *) = [handler copy];
        [cityBlockStack addObject:handlerCopy];
    }
    if ([self cachedLocationIsValid]) {
        NSDictionary *cachedLocation = [def objectForKey:@"APLMCachedLocation"];
        CLLocation *location = [[CLLocation alloc] initWithLatitude:[[cachedLocation objectForKey:@"lat"] doubleValue] longitude:[[cachedLocation objectForKey:@"lng"] doubleValue]];
        if([cachedLocation objectForKey:@"city"]){
            if(APLM_DEBUG)NSLog(@"City cache valid, returning city");
            NSDictionary *response = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [cachedLocation objectForKey:@"dt"],@"dt",
                                      location, @"CLLocation",
                                      [cachedLocation objectForKey:@"city"],@"city",
                                      [cachedLocation objectForKey:@"state"],@"state",
                                      nil];
            [self cityQueryCompleted:response withError:nil];
            return;
        }else{
            if(APLM_DEBUG)NSLog(@"Coordinate cache valid but no city, querying reverse geocoder");
            //previously, only coordinate was saved, but since cache is still valid, use reverse geocoder to get location of cached coordinate
            [self privateGetCityAndStateOfCoordinate:location callback:^(NSDictionary *response, NSError *error) {
                [self cityQueryCompleted:response withError:error];
            }];
        }
    }
    [self getCoordinateWithBlock:^(NSDictionary *response, NSError *error) {
        if(error){
            [self cityQueryCompleted:nil withError:error];
            return;
        }
        CLLocation *location = [response objectForKey:@"CLLocation"];
        [self privateGetCityAndStateOfCoordinate:location callback:^(NSDictionary *response, NSError *error) {
            [self cityQueryCompleted:response withError:error];
        }];
    }];
}

- (void)getCityAndStateOfCoordinate:(CLLocation*)location callback:(void (^)(NSDictionary *, NSError *))handler
{
    if(APLM_DEBUG)NSLog(@"Convert to city requested");
    mode = APLMcity;
    if (handler) {
        void (^handlerCopy)(NSDictionary *,NSError *) = [handler copy];
        [cityBlockStack addObject:handlerCopy];
    }
    [self privateGetCityAndStateOfCoordinate:location callback:^(NSDictionary *response, NSError *error) {
        [self cityQueryCompleted:response withError:error];
    }];
}

- (void)privateGetCityAndStateOfCoordinate:(CLLocation*)location callback:(void (^)(NSDictionary *, NSError *))handler
{
    if(APLM_DEBUG)NSLog(@"Querying reverse geocoder");
    [geoCoder reverseGeocodeLocation:location completionHandler:^(NSArray *placemarks, NSError *error) {
        if (error) {
            if(APLM_DEBUG)NSLog(@"Reverse geocoder query complete, has error %@",error.description);
            handler(nil, error);
        }else{
            if(APLM_DEBUG)NSLog(@"Reverse geocoder query complete with no errors");
            CLPlacemark *placemark = [placemarks objectAtIndex:0];
            
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                         [NSDate date],@"dt",
                                         [NSNumber numberWithDouble:placemark.location.coordinate.latitude],@"lat",
                                         [NSNumber numberWithDouble:placemark.location.coordinate.longitude],@"lng",
                                         placemark.locality,@"city",
                                         placemark.administrativeArea,@"state",
                                         nil];
            [def setObject:dict forKey:@"APLMCachedLocation"];
            //now get rid of lat,lng and put in CLLocation key (nsuserdefault cannot store CLLocation object)
            [dict removeObjectForKey:@"lat"];
            [dict removeObjectForKey:@"lng"];
            [dict setObject:placemark.location forKey:@"CLLocation"];
            handler(dict, nil);
        }
    }];
}

- (void)clearCache{
    if(APLM_DEBUG)NSLog(@"Cleared cache");
    [def removeObjectForKey:@"APLMCachedLocation"];
}

- (BOOL)cachedLocationIsValid
{
    if(!enableCache){
        return NO;
    }
    if ([def objectForKey:@"APLMCachedLocation"]) {
        NSDictionary *dict = [def objectForKey:@"APLMCachedLocation"];
        if ([dict objectForKey:@"dt"]) {
            NSDate *date = [dict objectForKey:@"dt"];
            float timeSinceLastCheck = [[NSDate date] timeIntervalSinceDate:date];
            if (timeSinceLastCheck < geopointLocationCacheTime) {
                return YES;
            }
        }
    }
    return NO;
}

-(void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    if(APLM_DEBUG)NSLog(@"Completed location manager query with lat: %lf and lng: %lf",newLocation.coordinate.latitude, newLocation.coordinate.longitude);
    [manager stopUpdatingLocation];
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                          [NSDate date],@"dt",
                          [NSNumber numberWithDouble:newLocation.coordinate.latitude],@"lat",
                          [NSNumber numberWithDouble:newLocation.coordinate.longitude],@"lng",nil];
    [def setObject:dict forKey:@"APLMCachedLocation"];
    [def synchronize];
    [dict removeObjectForKey:@"lat"];
    [dict removeObjectForKey:@"lng"];
    [dict setObject:newLocation forKey:@"CLLocation"];
    [self coordinateQueryCompleted:dict withError:nil];
    
    if (mode == APLMcoordinate) {
        return;
    }
    return;
    [self privateGetCityAndStateOfCoordinate:newLocation callback:^(NSDictionary *response, NSError *error) {
        [self cityQueryCompleted:response withError:error];
    }];
}

-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    if(APLM_DEBUG)NSLog(@"Location manager query failed with error %@",error.description);
    [self coordinateQueryCompleted:nil withError:error];
    [self cityQueryCompleted:nil withError:error];
}

- (void)coordinateQueryCompleted:(NSDictionary *)dictionary withError:(NSError *)error{
    for (int i=0; i<coordinateBlockStack.count; i++) {
        void (^handlerCopy)(NSDictionary *, NSError *) = [coordinateBlockStack objectAtIndex:i];
        handlerCopy(dictionary,error);
    }
    [coordinateBlockStack removeAllObjects];
}

- (void)cityQueryCompleted:(NSDictionary *)dictionary withError:(NSError *)error{
    for (int i=0; i<cityBlockStack.count; i++) {
        void (^handlerCopy)(NSDictionary *, NSError *) = [cityBlockStack objectAtIndex:i];
        handlerCopy(dictionary,error);
    }
    [cityBlockStack removeAllObjects];
}

#pragma mark - Convenient Location methods

- (CGFloat)getMilesBetween:(CLLocation*)location1 and:(CLLocation*)location2
{
    double lat1 = location1.coordinate.latitude;
    double lng1 = location1.coordinate.longitude;
    double lat2 = location2.coordinate.latitude;
    double lng2 = location2.coordinate.longitude;
    int earthRadius = 6371;//unit is km
    // Get the difference between our two points
    // then convert the difference into radians
    double latDiff = (lat2 - lat1) * (M_PI/180);
    double lngDiff = (lng2 - lng1) * (M_PI/180);
    double a = pow ( sin(latDiff/2), 2 ) + cos(lat1) * cos(lat2) * pow ( sin(lngDiff/2), 2 );
    
    double b = 2 * atan2( sqrt(a), sqrt( 1 - a ));
    double kmDistance = earthRadius * b;
    return kmDistance/1.60934;
}

- (NSString*)get2LetterRepresentationForState:(NSString*)fullStateName
{
    NSDictionary *map = [NSDictionary dictionaryWithObjectsAndKeys:
                         @"AL",@"alabama",
                         @"AK",@"alaska",
                         @"AZ",@"arizona",
                         @"AR",@"arkansas",
                         @"CA",@"california",
                         @"CO",@"colorado",
                         @"CT",@"connecticut",
                         @"DE",@"delaware",
                         @"FL",@"florida",
                         @"GA",@"georgia",
                         @"HI",@"hawaii",
                         @"ID",@"idaho",
                         @"IL",@"illinois",
                         @"IN",@"indiana",
                         @"IA",@"iowa",
                         @"KS",@"kansas",
                         @"KY",@"kentucky",
                         @"LA",@"louisiana",
                         @"ME",@"maine",
                         @"MD",@"maryland",
                         @"MA",@"massachusetts",
                         @"MI",@"michigan",
                         @"MN",@"minnesota",
                         @"MS",@"mississippi",
                         @"MO",@"missouri",
                         @"MT",@"montana",
                         @"NE",@"nebraska",
                         @"NV",@"nevada",
                         @"NH",@"new hampshire",
                         @"NJ",@"new jersey",
                         @"NM",@"new mexico",
                         @"NY",@"new york",
                         @"NC",@"north carolina",
                         @"ND",@"north dakota",
                         @"OH",@"ohio",
                         @"OK",@"oklahoma",
                         @"OR",@"oregon",
                         @"PA",@"pennsylvania",
                         @"RI",@"rhode island",
                         @"SC",@"south carolina",
                         @"SD",@"south dakota",
                         @"TN",@"tennessee",
                         @"TX",@"texas",
                         @"UT",@"utah",
                         @"VT",@"vermont",
                         @"VA",@"virginia",
                         @"WA",@"washington",
                         @"WV",@"west virginia",
                         @"WI",@"wisconsin",
                         @"WY",@"wyoming",
                         nil];
    NSString *name = [fullStateName lowercaseString];
    if ([map objectForKey:name]) {
        return [map objectForKey:name];
    }
    return nil;
}

@end
