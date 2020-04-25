#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Classes/RNCryptor/RNEncryptor.h"
#import "Classes/RNCryptor/RNDecryptor.h"

@interface DCDChatInput : UITextView
@end

@interface RCTView : UIView
-(id)accessibilityLabel;
@end

@interface RCTImageView : RCTView
@property (nonatomic, retain) NSArray *imageSources;
@end


@interface RCTImageSource : NSObject
@property (nonatomic, retain) NSURLRequest *request;
@end

@interface DCDMessageTableViewCell : UITableViewCell
@end

@interface DCDChat : UIView
@end