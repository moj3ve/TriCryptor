#import "Tweak.h"

BOOL encryptionMode;
NSString *encryptionKey;
NSString *prefixSymbol;
NSString *prefixString;

%hook DCDChatInput 

- (instancetype)init {
    if ((self = %orig)) {
        // Add a observer for the encryption notification
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(encryptText:) name:@"TriCryptNeedsEncryption" object:nil];

        // Add a tap gesture recognizer to the textbox that requires 2 taps
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(setEncryptionState:)];
        tapGesture.delegate = (id<UIGestureRecognizerDelegate>)self;
        tapGesture.numberOfTapsRequired = 2;
        [self addGestureRecognizer:tapGesture];
    }
    return self;
}

%new
- (void)setEncryptionState:(UITapGestureRecognizer *)tapGesture {
   UIAlertController *encryptController = [UIAlertController alertControllerWithTitle:@"Encryption/Decryption" message:@"Please provide the encryption/decryption key you wish to use" preferredStyle:UIAlertControllerStyleAlert];
   
    [encryptController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
       textField.placeholder = @"Prefix Symbol";
       textField.textAlignment = NSTextAlignmentCenter;
    }];

    [encryptController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
       textField.placeholder = @"Prefix Message";
       textField.textAlignment = NSTextAlignmentCenter;
    }];

   [encryptController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
       textField.placeholder = @"Encryption/Decryption Key";
       textField.secureTextEntry = YES;
       textField.textAlignment = NSTextAlignmentCenter;
    }];

   [encryptController addAction:[UIAlertAction actionWithTitle:@"Submit" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *textFieldPrefixSymbolText = [[[encryptController textFields][0] text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *textFieldPrefixText = [[[encryptController textFields][1] text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *textFieldKeyText = [[[encryptController textFields][2] text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        // Check if the text fields are empty, except for the Prefix textfield that one is optional
        if ([textFieldKeyText isEqualToString:@""] || [textFieldPrefixSymbolText isEqualToString:@""]) {
           encryptionMode = NO;
           encryptionKey = nil;
           prefixSymbol = nil;
           prefixString = nil;

           NSLog(@"[Crypt]: No key/prefix provided, encryption/decryption disabled");
        }
        else {
            // Set the values for our globals
            prefixSymbol = textFieldPrefixSymbolText;
            prefixString = textFieldPrefixText;
            encryptionKey = textFieldKeyText;
            encryptionMode = YES;
        }
       
   }]];
   [self.window.rootViewController presentViewController:encryptController animated:YES completion:nil];
    
}

%new
- (void)encryptText:(NSNotification *)notification {
    // Check if the notification matches and check for text + encryption + prefix stuff
    if ([notification.name isEqualToString:@"TriCryptNeedsEncryption"] && [self hasText] && encryptionMode && encryptionKey && prefixSymbol) {
        NSString *textViewText = self.text;
        if (![textViewText containsString:[NSString stringWithFormat:@"%@%@", prefixSymbol, prefixString]]) return;

        // We get the message without "prefix symbol + prefix + space", example: Before: "-encrypt hello" After: "hello"
        NSString *messageStringWithoutPrefix = [textViewText substringFromIndex:prefixSymbol.length + prefixString.length + 1]; // "+ 1" is usually the space
        NSData *data = [messageStringWithoutPrefix dataUsingEncoding:NSUTF8StringEncoding];
        
        // Here we encrypt the string with the key
        NSError *error = nil;
        NSData *encryptedData = [RNEncryptor encryptData:data withSettings:kRNCryptorAES256Settings password:encryptionKey error:&error];
        // Check if the encryption failed 
        if (error || !encryptedData) {
            [self setText:@"Error, couldn't encrypt :/"];
        }
        else {
            // Change the encrypted data to a base64 string and add the prefix to it
            NSString *base64EncryptedString = [encryptedData base64EncodedStringWithOptions:0];

            // Check if a prefix string is being used, if not use "GEN-" and add the base64 string to a newline
            NSString *base64EncryptedStringWithPrefix = [[NSString stringWithFormat:@"--%@-CRYPT--\n", ![prefixString isEqualToString:@""] ? prefixString : @"GEN-"] stringByAppendingString:base64EncryptedString];
            // Set the text to the prefix + encrypted base64 string
            [self setText:base64EncryptedStringWithPrefix];
        }
    }
}

%end


%hook RCTImageView

- (void)setImageSources:(NSArray *)imageSources {
    %orig;
    
    // Get the image url for the done button
    NSURL *imgUrl = ((RCTImageSource *)imageSources.firstObject).request.URL;
    NSString *absoluteImgUrlString = imgUrl.absoluteString;

    if ([absoluteImgUrlString containsString:@"ios/icons/ic_send"]) {
        // Add a tap gesture to the send button
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(sendNotificationToEncryptText:)];
        tapGesture.delegate = (id<UIGestureRecognizerDelegate>)self;
        [self addGestureRecognizer:tapGesture];
    }
}

%new 
-(void)sendNotificationToEncryptText:(UITapGestureRecognizer *)tapGesture {
    // Send a notification to the DCDChatInput class to encrypt the text
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TriCryptNeedsEncryption" object:nil];
}

%end


%hook DCDMessageTableViewCell

- (id)processContent:(NSMutableAttributedString *)content message:(NSDictionary *)message {
    // Get the contents of the message
    NSString *messageContent = [content string];
    // Get the prefix message string, and check again if prefix string is being used, if not use "GEN-"
    NSString *prefixMessageString = [NSString stringWithFormat:@"--%@-CRYPT--\n", ![prefixString isEqualToString:@""] ? prefixString : @"GEN-"];

    // Check if the message contains our prefix and check if encryption/decryption is enabled
    if ([messageContent hasPrefix:prefixMessageString] && encryptionMode) {

        // Get the encrypted base64 string without the "--%@-CRYPT--\n" prefix and get it as NSData
        NSString *base64MessageContentWithoutPrefix = [messageContent substringFromIndex:prefixMessageString.length];
        NSData *encryptedMessageData = [[NSData alloc] initWithBase64EncodedString:base64MessageContentWithoutPrefix options:0];
        NSError *error = nil;
        
        // Decrypt the NSData which contains the encrypted text
        NSData *decryptedData = [RNDecryptor decryptData:encryptedMessageData withPassword:encryptionKey error:&error];
        if (!error) {
            // Get the decrypted string from the decrypted data
            NSString *decryptedString = [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];

            // Get the original Attributed String and add an attribute to it that changes the color for decrypted messages to red,
            // so you can see which messages are encrypted and which are not.
            NSMutableAttributedString *selectedString = [[NSMutableAttributedString alloc] initWithAttributedString:content];
            [content addAttribute:NSForegroundColorAttributeName value:UIColor.redColor range:NSMakeRange(0, selectedString.length)];
            [content.mutableString setString:decryptedString];

            return %orig(content, message);
        }
    }

    return %orig(content, message);
}
%end


%ctor {
    NSLog(@"[Crypt]: Tweak started!");   
}