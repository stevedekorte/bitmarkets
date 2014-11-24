//
//  MKMarketChannel.m
//  Bitmessage
//
//  Created by Steve Dekorte on 3/13/14.
//  Copyright (c) 2014 voluntary.net. All rights reserved.
//

#import "MKMarketChannel.h"
#import <BitMessageKit/BitMessageKit.h>
#import "MKMsg.h"
#import "MKSell.h"
#import "MKMarkets.h"
#import "MKRootNode.h"
#import "MKClosePostMsg.h"

@implementation MKMarketChannel

- (NSString *)nodeTitle
{
    return @"Channel";
}

- (id)init
{
    self = [super init];

    if (MKRootNode.sharedMKRootNode.wallet.usesTestNet)
    {
        self.passphrase = @"Bitmarkets beta 0.8";
    }
    else
    {
        self.passphrase = @"Bitmarkets beta 0.8";
    }

    [NSNotificationCenter.defaultCenter addObserver:self
                                             selector:@selector(channelChanged:)
                                                 name:nil
                                                 //name:NavNodeAddedChildNotification
                                               object:self.channel];

    [NSNotificationCenter.defaultCenter addObserver:self
                                             selector:@selector(receivedMessagesChanged:)
                                                 //name:NavNodeAddedChildNotification
                                                 name:nil
                                               object:BMClient.sharedBMClient.messages.received];

    self.needsToFetchChannelMessages = YES;
    self.needsToFetchDirectMessages  = YES;
    return self;
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)channelChanged:(NSNotification *)note
{
    //[self fetchChannelMessages];
    if (!self.needsToFetchChannelMessages)
    {
        self.needsToFetchChannelMessages = YES;
        [self performSelector:@selector(fetchChannelMessages) withObject:self afterDelay:0.0];
    }
}

- (void)receivedMessagesChanged:(NSNotification *)note
{
    if (!self.needsToFetchDirectMessages)
    {
        self.needsToFetchDirectMessages = YES;
        [self performSelector:@selector(fetchDirectMessages) withObject:self afterDelay:0.0];
    }
}


- (CGFloat)nodeSuggestedWidth
{
    return 250;
}

/*
- (void)setPassphrase:(NSString *)passphrase
{
    if (_channel)
    {
        _channel = nil;
    }
    
    _passphrase = passphrase;
    
    //[self channel];
}
*/

- (BMChannel *)channel
{
    if (!_channel)
    {
        BMChannels *channels = BMClient.sharedBMClient.channels;

        if (![channels channelWithPassphrase:self.passphrase])
        {
            [channels leaveAllChannels];
        }
        
        _channel = [channels channelWithPassphraseJoinIfNeeded:self.passphrase];
    }
    
    return _channel;
}

- (void)fetch
{
    // just make sure this is in the fetch chain from BMClient?
    //[[[BMClient sharedBMClient] channels] fetch];
    //[BMClient.sharedBMClient refresh];
    
    [self fetchChannelMessages];
    [self expireOldChannelMessages]; // really only need to do this once daily

    [self fetchDirectMessages];
    [self expireDirectMessages]; // really only need to do this once daily
}

- (void)fetchChannelMessages
{
    self.needsToFetchChannelMessages = NO;
    
    NSArray *messages = self.channel.children.copy;
    
    NSMutableArray *closeMsgs = [NSMutableArray array];
    
    int newPostCount = 0;
    
    for (BMReceivedMessage *bmMsg in messages)
    {
        //if (!bmMsg.isRead)
        {
            MKMsg *msg = [MKMsg withBMMessage:bmMsg];
            
            if (msg)
            {
                if ([msg isKindOfClass:MKPostMsg.class])
                {
                    MKPostMsg *postMsg = (MKPostMsg *)msg;
                    MKPost *mkPost = [postMsg mkPost];
                    
                    [mkPost addChild:postMsg];

                    if (mkPost.hasPriceWithinMinMaxRange) // generalize this later
                    {
                        if (!mkPost.isAlreadyInMarketsPath)
                        {
                            newPostCount ++;
                            _totalPostCount ++;
                        }
                        
                        BOOL couldPlace = [mkPost placeInMarketsPath]; // deals with merging
                        
                        if (!couldPlace)
                        {
                            // can't place this message
                            [bmMsg delete];
                        }
                    }
                    else
                    {
                        //[bmMsg delete];
                        NSLog(@"price too small");
                    }
                }
                else if ([msg isKindOfClass:MKClosePostMsg.class])
                {
                    [closeMsgs addObject:msg];
                }
                else // don't know how to handle this Msg class, so delete it
                {
                    [bmMsg delete];
                }
            }
            else
            {
                // it wasn't a valid bitmarkets message, so delete it
                [bmMsg delete];
            }
        
            //[bmMsg markAsRead];
        }
    }
  
    NSWindow *window = NSApplication.sharedApplication.mainWindow;
    
    if (newPostCount > 0)
    {
        NSString *title = [NSString stringWithFormat:@"received new %i posts", newPostCount];
        if (newPostCount == 1)
        {
            title = @"received 1 new post";
        }
        
        [window setTitle:title];
        [window performSelector:@selector(setTitle:) withObject:@"" afterDelay:3.0];
    }
    else if (_totalPostCount == 0)
    {
        [window setTitle:@"syncing with bitmarkets channel..."];
    }
    
    // process this after others in case it's before the message it's closing
    
    for (MKClosePostMsg *closeMsg in closeMsgs)
    {
        MKRegion *rootRegion = MKRootNode.sharedMKRootNode.markets.rootRegion;
        
        if ([rootRegion handleMsg:closeMsg])
        {
            [closeMsg.bmMessage delete];
        }
        
        /*
        NSLog(@"closeMsg.postUuid %@", closeMsg.postUuid);
        
        // wait to delete it since the msg might arrive after the close msgS
        NSTimeInterval ttlSeconds = 60*60*24*2.5; // 2.5 days
        if (closeMsg.bmMessage.ageInSeconds > ttlSeconds)
        {
            [closeMsg.bmMessage delete];
        }
        */
    }
}

- (void)expireOldChannelMessages
{
    NSUInteger daysTillExpire = 30;
    NSArray *messages = self.channel.children.copy;

    for (BMReceivedMessage *bmMsg in messages)
    {
        NSTimeInterval ttlSeconds = 60*60*24*daysTillExpire;
        
        if (bmMsg.ageInSeconds > ttlSeconds)
        {
            [bmMsg delete];
        }
    }
}

- (void)fetchDirectMessages
{
    self.needsToFetchDirectMessages = NO;

    NSArray *inboxMessages = BMClient.sharedBMClient.messages.received.children.copy;
    [self handleBMMessages:inboxMessages];
}

- (void)expireDirectMessages
{
    NSUInteger daysTillExpire = 30;
    NSArray *messages = BMClient.sharedBMClient.messages.received.children.copy;
   
    for (BMReceivedMessage *bmMsg in messages)
    {
        NSTimeInterval ttlSeconds = 60*60*24*daysTillExpire;
        
        if (bmMsg.ageInSeconds > ttlSeconds)
        {
            [bmMsg delete];
        }
    }
}

- (void)handleBMMessages:(NSArray *)bmMessages
{
    NSArray *inboxMessages = BMClient.sharedBMClient.messages.received.children.copy;
    MKMarkets *markets = MKRootNode.sharedMKRootNode.markets;
    
    for (BMMessage *bmMessage in inboxMessages)
    {
        if (!bmMessage.isRead) // keep around read messages for debugging
        {
            MKMsg *msg = [MKMsg withBMMessage:bmMessage];
            
            if (!msg)
            {
                NSLog(@"invalid message");
                continue;
            }

            BOOL didHandle = [markets handleMsg:msg];
           
            if (!didHandle)
            {
                NSLog(@"unable to handle direct message");
            }
            
            [bmMessage markAsRead];
        }
    }
}

@end
