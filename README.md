APLocationManager
=================

Convenience class to handle location authentication, obtain CLLocation, and placemark strings

APLocationManager provides a simple interface to obtain location data without having to deal with instantiating multiple variables.

Setup:

You can import APLocationManager into PROJECT_NAME-Prefix.pch for global access or individually into each header file like so
#import "APLocationManager.h"

APLocationManager uses a singleton instance so it's best to setup the cache settings in your AppDelegate.h

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    APLocationManager *manager = [APLocationManager sharedInstance];
    manager.enableCache = YES;
    manager.cacheInterval = 60;//60 seconds, 5 minutes is default
    return YES;
}


To get the latitude and longitude of the current location, do...
- (void)someMethod{
	//....
	APLocationManager *manager = [APLocationManager sharedInstance];
	[manager getCoordinateWithBlock:^(NSDictionary *response, NSError *error) {
        if(error){
            NSLog(@"%@",error.description);
            return;
        }
        CLLocation *location = [response objectForKey:@"CLLocation"];
        double latitude = location.coordinate.latitude;
        double longitude = location.coordinate.longitude;
        //do something with latitude,longitude
    }];
    //....
}

To get the city and state the user is in, do...

- (void)someMethod{
	//....
	APLocationManager *manager = [APLocationManager sharedInstance];
    [manager getCityWithBlock:^(NSDictionary *response, NSError *error) {
        if(error){
            NSLog(@"%@",error.description);
            return;
        }
        CLLocation *location = [response objectForKey:@"CLLocation"];
        double latitude = location.coordinate.latitude;
        double longitude = location.coordinate.longitude;
        NSString *city = [response objectForKey:@"city"];
        NSString *state = [response objectForKey:@"state"];
    }];
	//....
}