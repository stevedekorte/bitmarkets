//
//  MKMarketChannel.h
//  Bitmessage
//
//  Created by Steve Dekorte on 3/13/14.
//  Copyright (c) 2014 Bitmarkets.org. All rights reserved.
//
// This object reads messages from the bitmarkets channel,
// creates objects for each as a child to the appropriate
// MKCategory
//

#import <BitMessageKit/BitMessageKit.h>
#import <NavKit/NavKit.h>

@interface MKMarketChannel : BMNode

@property (strong, nonatomic) NSString *passphrase;
@property (strong, nonatomic) BMChannel *channel;

//@property (strong, nonatomic) NSMutableSet *allAsks;

@property (strong, nonatomic) NavInfoNode *validMessages;
@property (strong, nonatomic) NavInfoNode *allAsks;

- (void)fetch;

@end
