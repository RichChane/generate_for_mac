//
//  SchemaGenerator.m
//  generate
//
//  Created by guang on 15/4/20.
//  Copyright (c) 2015年 ifangchou. All rights reserved.
//

#import "SchemaGenerator.h"
#import "SchemaProduceProtocal.h"
#import "SchemaProperties_M.h"

#pragma mark -

@implementation SchemaObject

@synthesize order = _order;
@synthesize protocol = _protocol;

- (id)init
{
    self = [super init];
    if ( self )
    {
        static NSInteger __orderSeed = 0;
        
        self.order = __orderSeed++;
        self.protocol = nil;
    }
    return self;
}

+ (id)parseKey:(NSString *)key value:(id)value protocol:(SchemaProtocol *)protocol
{
    return nil;
}

- (NSString *)JSON
{
    return @"";
}

- (NSString *)h
{
    return nil;
}

- (NSString *)mm
{
    return nil;
}

- (NSString *)randColor
{
    return @"grey25";
    
    //	switch ( rand() % 5 )
    //	{
    //	case 0:	return @"black";
    //	case 1:	return @"orange";
    //	case 2:	return @"red";
    //	case 3:	return @"purple";
    //	case 4:	return @"blue";
    //	default: return @"black";
    //	}
}

@end

#pragma mark -

@implementation SchemaProperty

DEF_INT( TYPE_UNKNOWN,		0 )
DEF_INT( TYPE_ENUM,			1 )
DEF_INT( TYPE_NUMBER,		2 )
DEF_INT( TYPE_STRING,		3 )
DEF_INT( TYPE_ARRAY,		4 )
DEF_INT( TYPE_DICTIONARY,	5 )
DEF_INT( TYPE_OBJECT,		6 )

@synthesize required = _required;
@synthesize type = _type;
@synthesize name = _name;
@synthesize value = _value;

@synthesize elemType = _elemType;
@synthesize elemClass = _elemClass;
@synthesize elemCount = _elemCount;
@synthesize elemProperty = _elemProperty;

@synthesize subProperties = _subProperties;


+ (id)parseKey:(NSString *)key value:(id)value protocol:(SchemaProtocol *)protocol
{
    //	INFO( @"property >>> '%@'", key );
    
    //-----------------SchemaProperty 制造工厂
    SchemaProperty * property = nil;
    
    if ( nil == value || [value isKindOfClass:[NSNull class]] )
    {
        property = [SchemaPropertyUnknown parseKey:key value:value protocol:protocol];
    }
    else
    {
        if ( [value isKindOfClass:[NSNumber class]] )
        {
            property = [SchemaPropertyNumber parseKey:key value:value protocol:protocol];
        }
        else if ( [value isKindOfClass:[NSString class]] )
        {
            property = [SchemaPropertyString parseKey:key value:value protocol:protocol];
        }
        else if ( [value isKindOfClass:[NSArray class]] )
        {
            property = [SchemaPropertyArray parseKey:key value:value protocol:protocol];
        }
        else if ( [value isKindOfClass:[NSDictionary class]] )
        {
            NSDictionary * dict = (NSDictionary *)value;
            if ( dict.count )
            {
                property = [SchemaPropertyEmbedObject parseKey:key value:value protocol:protocol];
            }
            else
            {
                property = [SchemaPropertyDictionary parseKey:key value:value protocol:protocol];
            }
        }
        else
        {
            property = [SchemaPropertyUnknown parseKey:key value:value protocol:protocol];
        }
    }
    
    if ( [key hasPrefix:@"!"] )
    {
        property.required = YES;
        property.name = [key substringFromIndex:1].trim;
    }
    else
    {
        property.required = NO;
        property.name = key.trim;
    }
    
    property.protocol = protocol;
    return property;
}

@end

#pragma mark -

@implementation SchemaPropertyNumber

+ (id)parseKey:(NSString *)key value:(id)value protocol:(SchemaProtocol *)protocol
{
    SchemaPropertyNumber * property = [[[self alloc] init] autorelease];
    property.type = SchemaProperty.TYPE_NUMBER;
    property.value = value;
    property.protocol = protocol;
    return property;
}

- (NSString *)JSON
{
    return [NSString stringWithFormat:@"%@", self.value];
}

@end

#pragma mark -

@implementation SchemaPropertyString

+ (id)parseKey:(NSString *)key value:(id)value protocol:(SchemaProtocol *)protocol
{
    NSString *			text = ((NSString *)value).trim;
    NSCharacterSet *	charset = [NSCharacterSet whitespaceCharacterSet];
    
    if ( NSNotFound == [text rangeOfCharacterFromSet:charset].location )
    {
        if ( [text hasPrefix:@"{"] && [text hasSuffix:@"}"] )
        {
            return [SchemaPropertyObject parseKey:key value:text protocol:protocol];
        }
        else if ( [text hasPrefix:@"<"] && [text hasSuffix:@">"] )
        {
            return [SchemaPropertyEnum parseKey:key value:text protocol:protocol];
        }
    }
    
    SchemaPropertyString * property = [[[self alloc] init] autorelease];
    property.type = SchemaProperty.TYPE_STRING;
    property.value = value;
    property.protocol = protocol;
    return property;
}

- (NSString *)JSON
{
    return [NSString stringWithFormat:@"\"%@\"", [self.value stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]];
}

@end

#pragma mark -

@implementation SchemaPropertyArray

+ (id)parseKey:(NSString *)key value:(id)value protocol:(SchemaProtocol *)protocol
{
    if ( NO == [value isKindOfClass:[NSArray class]] )
        return nil;
    
    SchemaPropertyArray * property = [[[self alloc] init] autorelease];
    property.type = SchemaProperty.TYPE_ARRAY;
    property.value = value;
    property.subProperties = [[[NSMutableArray alloc] init] autorelease];
    
    NSArray * array = (NSArray *)value;
    if ( 0 == array.count )
    {
        property.elemType = SchemaProperty.TYPE_UNKNOWN;
        property.elemClass = nil;
        property.elemCount = 0;
        property.elemProperty = [SchemaPropertyUnknown parseKey:key value:nil protocol:protocol];
    }
    else
    {
        property.elemCount = array.count;
        
        NSObject * firstObj = [array objectAtIndex:0];
        if ( [firstObj isKindOfClass:[NSNumber class]] )
        {
            property.elemType = SchemaProperty.TYPE_NUMBER;
            property.elemClass = nil;
            property.elemProperty = [SchemaPropertyNumber parseKey:key value:firstObj protocol:protocol];
        }
        else if ( [firstObj isKindOfClass:[NSString class]] )
        {
            NSString *			text = ((NSString *)firstObj).trim;
            NSCharacterSet *	charset = [NSCharacterSet whitespaceCharacterSet];
            
            if ( NSNotFound == [text rangeOfCharacterFromSet:charset].location )
            {
                if ( [text hasPrefix:@"<"] && [text hasSuffix:@">"] )
                {
                    property.elemType = SchemaProperty.TYPE_ENUM;
                    property.elemClass = [text substringWithRange:NSMakeRange(1, text.length - 2)].trim;
                    property.elemProperty = [SchemaPropertyEnum parseKey:key value:firstObj protocol:protocol];
                }
                else if ( [text hasPrefix:@"{"] && [text hasSuffix:@"}"] )
                {
                    property.elemType = SchemaProperty.TYPE_OBJECT;
                    property.elemClass = [text substringWithRange:NSMakeRange(1, text.length - 2)].trim;
                    property.elemProperty = [SchemaPropertyObject parseKey:key value:firstObj protocol:protocol];
                }
                else
                {
                    property.elemType = SchemaProperty.TYPE_STRING;
                    property.elemClass = nil;
                    property.elemProperty = [SchemaPropertyString parseKey:key value:firstObj protocol:protocol];
                }
            }
            else
            {
                property.elemType = SchemaProperty.TYPE_STRING;
                property.elemClass = nil;
                property.elemProperty = [SchemaPropertyString parseKey:key value:firstObj protocol:protocol];
            }
        }
        else if ( [firstObj isKindOfClass:[NSArray class]] )
        {
            SchemaProperty * subProperty = [SchemaPropertyArray parseKey:key value:firstObj protocol:protocol];
            if ( subProperty )
            {
                property.elemType = SchemaProperty.TYPE_ARRAY;
                property.elemClass = subProperty.elemClass;
                property.elemProperty = subProperty;
            }
            else
            {
                WARN( @"non-support element, %@ : %@", key, value );
                return nil;
            }
        }
        else if ( [firstObj isKindOfClass:[NSDictionary class]] )
        {
            SchemaPropertyEmbedObject * subProperty = [SchemaPropertyEmbedObject parseKey:key value:firstObj protocol:protocol];
            if ( subProperty )
            {
                property.elemType = subProperty.type;
                property.elemClass = subProperty.elemClass;
                property.elemProperty = subProperty;
            }
            else
            {
                WARN( @"non-support element, %@ : %@", key, value );
                return nil;
            }
        }
        else
        {
            WARN( @"non-support element, %@ : %@", key, value );
            return nil;
        }
    }
    
    property.protocol = protocol;
    return property;
}

- (NSString *)JSON
{
    NSMutableString * code = [NSMutableString string];
    
    if ( self.elemProperty )
    {
        [code appendString:@"[ "];
        
        for ( NSUInteger i = 0; i < self.elemCount; ++i )
        {
            [code appendString:[self.elemProperty JSON]];
            
            if ( (i + 1) < self.elemCount )
            {
                [code appendString:@", "];
            }
        }
        
        [code appendString:@" ]"];
    }
    else
    {
        [code appendString:@"[]"];
    }
    
    return code;
}

@end

#pragma mark -

@implementation SchemaPropertyDictionary

+ (id)parseKey:(NSString *)key value:(id)value protocol:(SchemaProtocol *)protocol
{
    if ( nil == value || NO == [value isKindOfClass:[NSDictionary class]] )
        return nil;
    
    SchemaPropertyDictionary * property = [[[self alloc] init] autorelease];
    property.type = SchemaProperty.TYPE_DICTIONARY;
    property.value = value;
    property.subProperties = [[[NSMutableArray alloc] init] autorelease];
    
    NSDictionary * dict = (NSDictionary *)value;
    if ( dict.count )
    {
        NSMutableArray * sortedKeys = [NSMutableArray arrayWithArray:dict.allKeys];
        [sortedKeys sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            return [obj1 compare:obj2];
        }];
        
        for ( NSString * key in sortedKeys )
        {
            NSObject * value = [dict objectForKey:key];
            
            SchemaProperty * subProperty = [SchemaProperty parseKey:key value:value protocol:protocol];
            if ( subProperty )
            {
                [property.subProperties addObject:subProperty];
            }
        }
    }
    
    property.protocol = protocol;
    return property;
}

- (NSString *)JSON
{
    NSMutableString * code = [NSMutableString string];
    
    if ( self.subProperties.count )
    {
        [code appendString:@"{ "];
        
        for ( SchemaProperty * property in self.subProperties )
        {
            [code appendString:[property JSON]];
        }
        
        [code appendString:@" }"];
    }
    else
    {
        [code appendString:@"{}"];
    }
    
    return code;
}

@end

#pragma mark -

@implementation SchemaPropertyUnknown

+ (id)parseKey:(NSString *)key value:(id)value protocol:(SchemaProtocol *)protocol
{
    SchemaPropertyUnknown * property = [[[self alloc] init] autorelease];
    property.type = SchemaProperty.TYPE_UNKNOWN;
    property.value = value;
    property.protocol = protocol;
    return property;
}

- (NSString *)JSON
{
    return @"null";
}

@end

#pragma mark -

@implementation SchemaPropertyEnum

+ (id)parseKey:(NSString *)key value:(id)value protocol:(SchemaProtocol *)protocol
{
    if ( NO == [value isKindOfClass:[NSString class]] )
        return nil;
    
    NSString * text = ((NSString *)value).trim;
    
    if ( [text hasPrefix:@"<"] && [text hasSuffix:@">"] )
    {
        SchemaPropertyEnum * property = [[[self alloc] init] autorelease];
        property.type = SchemaProperty.TYPE_ENUM;
        property.value = value;
        property.elemClass = [text substringWithRange:NSMakeRange(1, text.length - 2)].trim;
        
        SchemaEnum * enums = [protocol enumByName:property.elemClass];
        if ( enums )
        {
            if ( enums.isString )
            {
                NSString * string = [enums.values objectForKey:[enums.values.allKeys objectAtIndex:0]];
                
                property.elemType = SchemaProperty.TYPE_STRING;
                property.elemProperty = [SchemaPropertyString parseKey:enums.name value:string protocol:protocol];
            }
            else
            {
                NSNumber * number = [enums.values objectForKey:[enums.values.allKeys objectAtIndex:0]];
                
                property.elemType = SchemaProperty.TYPE_NUMBER;
                property.elemProperty = [SchemaPropertyNumber parseKey:enums.name value:number protocol:protocol];
            }
        }
        
        property.protocol = protocol;
        return property;
    }
    
    return nil;
}

- (NSString *)JSON
{
    if ( self.elemProperty )
    {
        return [self.elemProperty JSON];
    }
    else
    {
        return @"0";
    }
}

@end

#pragma mark -

@implementation SchemaPropertyObject

+ (id)parseKey:(NSString *)key value:(id)value protocol:(SchemaProtocol *)protocol
{
    if ( NO == [value isKindOfClass:[NSString class]] )
        return nil;
    
    NSString * text = ((NSString *)value).trim;
    
    SchemaPropertyObject * property = [[[self alloc] init] autorelease];
    property.type = SchemaProperty.TYPE_OBJECT;
    property.value = value;
    property.elemClass = [text substringWithRange:NSMakeRange(1, text.length - 2)].trim;
    property.protocol = protocol;
    return property;
}

- (NSString *)JSON
{
    NSMutableString * code = [NSMutableString string];
    
    SchemaModel * model = [self.protocol modelByName:self.elemClass];
    if ( model )
    {
        [code appendString:[model JSON]];
    }
    else
    {
        [code appendString:@"{}"];
    }
    
    return code;
}

@end

#pragma mark -

@implementation SchemaPropertyEmbedObject

+ (id)parseKey:(NSString *)key value:(id)value protocol:(SchemaProtocol *)protocol
{
    if ( nil == value || NO == [value isKindOfClass:[NSDictionary class]] )
        return nil;
    
    
    if ( nil == key || 0 == key.length )
    {
        key = @"ANONYMOUS_OBJECT";
    }
    
    NSString *		modelClass = key;
    SchemaModel *	model = nil;
    
    if ( [modelClass hasPrefix:@"!"] )
    {
        modelClass = [modelClass substringFromIndex:1].trim;
    }
    
    model = [protocol modelByName:modelClass];
    if ( nil != model )
    {
        WARN( @"conflict name '%@' will merge", modelClass );
        
        [model appendKeyValues:value];
    }
    else
    {
        model = [SchemaModel parseKey:key value:value protocol:protocol];
        if ( model )
        {
            [protocol.models addObject:model];
        }
    }
    
    SchemaPropertyObject * property = [[[self alloc] init] autorelease];
    if ( property )
    {
        property.type = SchemaProperty.TYPE_OBJECT;
        property.value = value;
        property.elemClass = modelClass;
    }
    
    property.protocol = protocol;
    return property;
}

- (NSString *)JSON
{
    NSMutableString * code = [NSMutableString string];
    
    SchemaModel * model = [self.protocol modelByName:self.elemClass];
    if ( model )
    {
        [code appendString:[model JSON]];
    }
    else
    {
        [code appendString:@"{}"];
    }
    
    return code;
}

@end

#pragma mark - /*  ----- 解析key-->model------ */

@implementation SchemaModel

@synthesize superClassName = _superClassName;
@synthesize className = _className;
@synthesize properties = _properties;
@synthesize isActiveRecord = _isActiveRecord;
@synthesize isArray = _isArray;
@synthesize isDictionary = _isDictionary;
@synthesize isContainer = _isContainer;

//----------------SchemaModel制造工厂（一个model的最终产品，包括类名，类属性，类属性类型）
+ (id)parseKey:(NSString *)key value:(NSDictionary *)value protocol:(SchemaProtocol *)protocol
{

    //	INFO( @"model >>> '%@'", key );
    
    NSString * thisClass = nil;
    NSString * superClass = nil;
    
    if ( NSNotFound != [key rangeOfString:@"<"].location )
    {
        NSArray * array = [key componentsSeparatedByString:@"<"];
        if ( array.count >= 2 )
        {
            thisClass = ((NSString *)[array objectAtIndex:0]).trim;
            superClass = ((NSString *)[array objectAtIndex:1]).trim;
        }
        else
        {
            thisClass = key.trim;
        }
    }
    else
    {
        thisClass = key.trim;
    }
    
    if ( thisClass && thisClass.length )
    {
        SchemaModel * model = [[[self alloc] init] autorelease];
        model.superClassName = superClass;
        
        if ( [thisClass hasPrefix:@"!"] )
        {
            model.isActiveRecord = YES;
            model.className = [thisClass substringFromIndex:1].trim;
        }
        else
        {
            model.isActiveRecord = NO;
            model.className = thisClass;
        }
        
        model.properties = [[[NSMutableArray alloc] init] autorelease];
        
        if ( [value isKindOfClass:[NSDictionary class]] )
        {
            NSMutableArray * sortedKeys = [NSMutableArray arrayWithArray:value.allKeys];
            [sortedKeys sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                return [obj1 compare:obj2];
            }];
            
            for ( NSString * sortedKey in sortedKeys )
            {
                SchemaProperty * property = [SchemaProperty parseKey:sortedKey value:[value objectForKey:sortedKey] protocol:protocol];
                if ( property )
                {
                    [model.properties addObject:property];//类属性集合
                }
            }
            
            model.isDictionary = YES;
            model.isContainer = YES;
        }
        else if ( [value isKindOfClass:[NSArray class]] )
        {
            SchemaProperty * property = [SchemaProperty parseKey:key value:value protocol:protocol];
            if ( property )
            {
                [model.properties addObject:property];
            }
            
            model.isArray = YES;
            model.isContainer = NO;
        }
        else
        {
            SchemaProperty * property = [SchemaProperty parseKey:key value:value protocol:protocol];
            if ( property )
            {
                [model.properties addObject:property];
            }
            
            model.isContainer = NO;
        }
        
        [model.properties sortUsingComparator:^NSComparisonResult(id obj1, id obj2)
         {//排序
             NSInteger result = NSOrderedSame;
             
             if ( ((SchemaProperty *)obj1).required )
             {
                 result = 1;
             }
             else if ( ((SchemaProperty *)obj2).required )
             {
                 result = -1;
             }
             else
             {
                 result = ((SchemaProperty *)obj1).order - ((SchemaProperty *)obj2).order;
             }
             
             return (result > 0 ? NSOrderedDescending : (result < 0 ? NSOrderedAscending : NSOrderedSame));
         }];
        
        model.properties = [[[NSMutableArray alloc] init] autorelease];
        
        if ( [value isKindOfClass:[NSDictionary class]] )
        {
            NSMutableArray * sortedKeys = [NSMutableArray arrayWithArray:value.allKeys];
            [sortedKeys sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                return [obj1 compare:obj2];
            }];
            
            for ( NSString * sortedKey in sortedKeys )
            {
                SchemaProperty * property = [SchemaProperty parseKey:sortedKey value:[value objectForKey:sortedKey] protocol:protocol];
                if ( property )
                {
                    [model.properties addObject:property];//类属性集合
                }
            }
            
            model.isDictionary = YES;
            model.isContainer = YES;
        }
        else if ( [value isKindOfClass:[NSArray class]] )
        {
            SchemaProperty * property = [SchemaProperty parseKey:key value:value protocol:protocol];
            if ( property )
            {
                [model.properties addObject:property];
            }
            
            model.isArray = YES;
            model.isContainer = NO;
        }
        else
        {
            SchemaProperty * property = [SchemaProperty parseKey:key value:value protocol:protocol];
            if ( property )
            {
                [model.properties addObject:property];
            }
            
            model.isContainer = NO;
        }
        
        [model.properties sortUsingComparator:^NSComparisonResult(id obj1, id obj2)
         {//排序
             NSInteger result = NSOrderedSame;
             
             if ( ((SchemaProperty *)obj1).required )
             {
                 result = 1;
             }
             else if ( ((SchemaProperty *)obj2).required )
             {
                 result = -1;
             }
             else
             {
                 result = ((SchemaProperty *)obj1).order - ((SchemaProperty *)obj2).order;
             }
             
             return (result > 0 ? NSOrderedDescending : (result < 0 ? NSOrderedAscending : NSOrderedSame));
         }];
        
        //		[model.properties sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        //			NSInteger result = ((SchemaProperty *)obj1).order - ((SchemaProperty *)obj2).order;
        //			return (result > 0 ? NSOrderedDescending : (result < 0 ? NSOrderedAscending : NSOrderedSame));
        //		}];
        
        model.protocol = protocol;
        return model;
    }
    
    return nil;
}

- (BOOL)appendKeyValues:(NSDictionary *)keyValues
{
    if ( nil == keyValues || NO == [keyValues isKindOfClass:[NSDictionary class]] )
        return NO;
    
    for ( NSString * key in keyValues )
    {
        BOOL found = NO;
        
        for ( SchemaProperty * property in self.properties )
        {
            if ( [property.name isEqualToString:key] )
            {
                found = YES;
                break;
            }
        }
        
        if ( NO == found )
        {
            SchemaProperty * newProperty = [SchemaProperty parseKey:key value:[keyValues objectForKey:key] protocol:self.protocol];
            if ( newProperty )
            {
                [self.properties addObject:newProperty];
            }
        }
    }
    
    return YES;
}

- (NSString *)JSON
{
    NSMutableString * code = [NSMutableString string];
    
    if ( self.properties.count )
    {
        [code appendString:@"{ "];
        
        for ( SchemaProperty * property in self.properties )
        {
            [code appendFormat:@"\"%@\":%@", property.name, [property JSON]];
            
            if ( property != [self.properties lastObject] )
            {
                [code appendString:@", "];
            }
        }
        
        [code appendString:@" }"];
    }
    else
    {
        [code appendString:@"{}"];
    }
    
    return code;
}


- (NSString *)h//生成.h中部内容
{
    if ( NO == self.isContainer )
        return nil;
    
    NSString *			prefix = self.protocol.prefix;
    NSMutableString *	code = [NSMutableString string];
    
    //	code.LINE( @"#pragma mark - %@%@", prefix, self.className );
    //	code.LINE( nil );
    
    if ( self.superClassName )
//@interface SHOT : BeeActiveObject
    {
        code.LINE( @"@interface %@%@ : %@%@", prefix, self.className, prefix, self.superClassName );
    }
    else
    {
        if ( self.isActiveRecord )
        {
            code.LINE( @"@interface %@%@ : %@", prefix, self.className, @"BeeActiveRecord" );
        }
        else
        {
            code.LINE( @"@interface %@%@ : %@", prefix, self.className, @"BeeActiveObject" );
        }
    }
    
    for ( SchemaProperty * property in self.properties )
//设置生成的属性及类型
//    @interface SHOT : BeeActiveObject
//    @property (nonatomic, retain) NSNumber *			comments_count;
//    @property (nonatomic, retain) NSString *			created_at;
//    @property (nonatomic, retain) NSNumber *			height;
//    @property (nonatomic, retain) NSNumber *			likes_count;
//    @property (nonatomic, retain) PLAYER *			player;
//    @property (nonatomic, retain) NSNumber *			rebound_source_id;
//    @property (nonatomic, retain) NSNumber *			rebounds_count;
//    @property (nonatomic, retain) NSString *			title;
//    @property (nonatomic, retain) NSNumber *			views_count;
//    @property (nonatomic, retain) NSNumber *			width;
//    @property (nonatomic, retain) NSNumber *			id;
//    @end
    {
        if ( property.type == SchemaProperty.TYPE_ENUM )
        {
            SchemaEnum * enums = [self.protocol enumByName:property.elemClass];
            if ( enums && enums.isString )
            {
                code.LINE( @"@property (nonatomic, retain) NSString *\t\t\t%@;", property.name );
            }
            else
            {
                code.LINE( @"@property (nonatomic, retain) NSNumber *\t\t\t%@;", property.name );
            }
        }
        else if ( property.type == SchemaProperty.TYPE_NUMBER )
        {
            code.LINE( @"@property (nonatomic, retain) NSNumber *\t\t\t%@;", property.name );
        }
        else if ( property.type == SchemaProperty.TYPE_STRING )
        {
            code.LINE( @"@property (nonatomic, retain) NSString *\t\t\t%@;", property.name );
        }
        else if ( property.type == SchemaProperty.TYPE_ARRAY )
        {
            code.LINE( @"@property (nonatomic, retain) NSArray *\t\t\t\t%@;", property.name );
        }
        else if ( property.type == SchemaProperty.TYPE_DICTIONARY )
        {
            code.LINE( @"@property (nonatomic, retain) NSDictionary *\t\t\t%@;", property.name );
        }
        else if ( property.type == SchemaProperty.TYPE_OBJECT )
        {
            code.LINE( @"@property (nonatomic, retain) %@%@ *\t\t\t%@;", prefix, property.elemClass, property.name );
        }
        else
        {
            code.LINE( @"@property (nonatomic, retain) NSObject *\t\t\t%@;", property.name );
        }
    }
    
    //	code.LINE( @"- (BOOL)validate;" );
    code.LINE( @"@end" );
    return code;
}

- (NSString *)mm
{
    if ( NO == self.isContainer )
        return nil;
    
    NSString *			prefix = self.protocol.prefix;
    NSMutableString *	code = [NSMutableString string];
    
    code.LINE( @"#pragma mark - %@%@", prefix, self.className );
    code.LINE( nil );
    

    code.LINE( @"@interface %@%@ ()", prefix, self.className );
    code.LINE( nil );
    if ( self.properties && self.properties.count )
    {
        for ( SchemaProperty * property in self.properties )
        {
            if ( property.type == SchemaProperty.TYPE_ENUM )
            {
                SchemaEnum * enums = [self.protocol enumByName:property.elemClass];
                if ( enums && enums.isString )
                {
                    code.LINE( @"@property (nonatomic, retain) NSString *\t\t\t%@;", property.name );
                }
                else
                {
                    code.LINE( @"@property (nonatomic, retain) NSNumber *\t\t\t%@;", property.name );
                }
            }
            else if ( property.type == SchemaProperty.TYPE_NUMBER )
            {
                code.LINE( @"@property (nonatomic, retain) NSNumber *\t\t\t%@;", property.name );
            }
            else if ( property.type == SchemaProperty.TYPE_STRING )
            {
                code.LINE( @"@property (nonatomic, retain) NSString *\t\t\t%@;", property.name );
            }
            else if ( property.type == SchemaProperty.TYPE_ARRAY )
            {
                code.LINE( @"@property (nonatomic, retain) NSArray *\t\t\t\t%@;", property.name );
            }
            else if ( property.type == SchemaProperty.TYPE_DICTIONARY )
            {
                code.LINE( @"@property (nonatomic, retain) NSDictionary *\t\t\t%@;", property.name );
            }
            else if ( property.type == SchemaProperty.TYPE_OBJECT )
            {
                code.LINE( @"@property (nonatomic, retain) %@%@ *\t\t\t%@;", prefix, property.elemClass, property.name );
            }
            else
            {
                code.LINE( @"@property (nonatomic, retain) NSObject *\t\t\t%@;", property.name );
            }
        }
    }
    code.LINE( @"@end" );
    code.LINE( nil );
    
    code.LINE( @"@implementation %@%@", prefix, self.className );
    code.LINE( nil );
    
    if ( self.properties && self.properties.count )
    {
        for ( SchemaProperty * property in self.properties )
        {
            //做属性与实例变量
            code.LINE( @"@synthesize %@ = _%@;", property.name, property.name );
        }
        
        code.LINE( nil );
        
        BOOL found = NO;
        
        for ( SchemaProperty * property in self.properties )
        {
            if ( property.type == SchemaProperty.TYPE_ARRAY )
            {
                if ( property.elemType == SchemaProperty.TYPE_OBJECT )
                {
                    code.LINE( @"CONVERT_PROPERTY_CLASS( %@, %@%@ );", property.name, prefix, property.elemClass );
                    found = YES;
                }
            }
        }
        
        if ( found )
        {
            code.LINE( nil );
        }
        
        if ( self.isActiveRecord )
        {
            code.LINE( @"+ (void)mapRelation" );
            code.LINE( @"{" );
            code.LINE( @"	[super mapRelation];" );
            
            for ( SchemaProperty * property in self.properties )
            {
                if ( property.type == SchemaProperty.TYPE_NUMBER )
                {
                    if ( property.required )
                    {
                        code.LINE( @"	[super mapPropertyAsKey:@\"%@\"];", property.name );
                    }
                }
                else if ( property.type == SchemaProperty.TYPE_ARRAY )
                {
                    if ( property.elemType == SchemaProperty.TYPE_ENUM )
                    {
                        code.LINE( @"	[super mapPropertyAsArray:@\"%@\"];", property.name );
                    }
                    else if ( property.elemType == SchemaProperty.TYPE_NUMBER )
                    {
                        code.LINE( @"	[super mapPropertyAsArray:@\"%@\"];", property.name );
                    }
                    else if ( property.elemType == SchemaProperty.TYPE_STRING )
                    {
                        code.LINE( @"	[super mapPropertyAsArray:@\"%@\"];", property.name );
                    }
                    else if ( property.elemType == SchemaProperty.TYPE_OBJECT )
                    {
                        code.LINE( @"	[super mapPropertyAsArray:@\"%@\" forClass:@\"%@%@\"];", property.name, prefix, property.elemClass );
                    }
                    else
                    {
                        WARN( @"non support element type, '%@'", property.name );
                        break;
                    }
                }
            }
            
            code.LINE( @"}" );
            code.LINE( nil );
        }
    }
    
    

    code.LINE( nil );
    
    code.LINE( @"@end" );
    return code;
}

- (NSString *)publicSetGetMethod
{
    NSString *			prefix = self.protocol.prefix;
    NSMutableString *	code = [NSMutableString string];
    
    
    if ( self.properties.count )
    {
        for ( SchemaProperty * property in self.properties )
        {
            NSString* capitalName = [property.name stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[property.name substringToIndex:1] uppercaseString]];
            
            if ( property.type == SchemaProperty.TYPE_ENUM )
            {
                SchemaEnum * enums = [self.protocol enumByName:property.elemClass];
                if ( enums && enums.isString )
                {
                    //set
                    code.LINE( @"- (void)set%@:(NSString*)%@", capitalName,property.name );
                    code.LINE( @"{" );
                    code.LINE( @"   _%@ = %@;" , property.name,property.name);//self.改成_
                    code.LINE( @"}" );
                    code.LINE( nil );
                    //get
                    code.LINE( @"- (NSString*)get%@", capitalName );
                    code.LINE( @"{" );
                    code.LINE( @"   return _%@" , property.name);
                    code.LINE( @"}" );
                    
                }
                else
                {
                    code.LINE( @"- (void)set%@:(NSNumber*)%@", capitalName,property.name );
                    code.LINE( @"{" );
                    code.LINE( @"   _%@ = %@;" , property.name,property.name);
                    code.LINE( @"}" );
                    code.LINE( nil );
                    //get
                    code.LINE( @"- (NSNumber*)get%@", capitalName );
                    code.LINE( @"{" );
                    code.LINE( @"   return _%@" , property.name);
                    code.LINE( @"}" );
                }
            }
            else if ( property.type == SchemaProperty.TYPE_NUMBER )
            {
                code.LINE( @"- (void)set%@:(NSArray*)%@", capitalName,property.name );
                code.LINE( @"{" );
                code.LINE( @"   _%@ = %@;" , property.name,property.name);
                code.LINE( @"}" );
                code.LINE( nil );
                //get
                code.LINE( @"- (NSArray*)get%@", capitalName );
                code.LINE( @"{" );
                code.LINE( @"   return _%@" , property.name);
                code.LINE( @"}" );
                
            }
            else if ( property.type == SchemaProperty.TYPE_STRING )
            {
                code.LINE( @"- (void)set%@:(NSString*)%@", capitalName,property.name );
                code.LINE( @"{" );
                code.LINE( @"   _%@ = %@;" , property.name,property.name);
                code.LINE( @"}" );
                code.LINE( nil );
                //get
                code.LINE( @"- (NSString*)get%@", capitalName );
                code.LINE( @"{" );
                code.LINE( @"   return _%@" , property.name);
                code.LINE( @"}" );
                
            }
            else if ( property.type == SchemaProperty.TYPE_ARRAY )
            {
                code.LINE( @"- (void)set%@:(NSArray*)%@", capitalName,property.name );
                code.LINE( @"{" );
                code.LINE( @"   _%@ = %@;" , property.name,property.name);
                code.LINE( @"}" );
                code.LINE( nil );
                //get
                code.LINE( @"- (NSArray*)get%@", capitalName );
                code.LINE( @"{" );
                code.LINE( @"   return _%@" , property.name);
                code.LINE( @"}" );
                
            }
            else if ( property.type == SchemaProperty.TYPE_DICTIONARY )
            {
                code.LINE( @"- (void)set%@:(NSDictionary*)%@", capitalName,property.name );
                code.LINE( @"{" );
                code.LINE( @"   _%@ = %@;" , property.name,property.name);
                code.LINE( @"}" );
                code.LINE( nil );
                //get
                code.LINE( @"- (NSDictionary*)get%@", capitalName );
                code.LINE( @"{" );
                code.LINE( @"   return _%@" , property.name);
                code.LINE( @"}" );
                
            }
            else if ( property.type == SchemaProperty.TYPE_OBJECT )
            {
                code.LINE( @"- (void)set%@:(%@%@*)%@", prefix, capitalName,property.name,property.name );
                code.LINE( @"{" );
                code.LINE( @"   _%@ = %@;" , property.name,property.name);
                code.LINE( @"}" );
                code.LINE( nil );
                //get
                code.LINE( @"- (%@%@*)get%@", prefix, capitalName,property.name );
                code.LINE( @"{" );
                code.LINE( @"   return _%@" , property.name);
                code.LINE( @"}" );
                
            }
            else
            {
                code.LINE( @"- (void)set%@:(NSObject*)%@", capitalName,property.name );
                code.LINE( @"{" );
                code.LINE( @"   _%@ = %@;" , property.name,property.name);
                code.LINE( @"}" );
                code.LINE( nil );
                //get
                code.LINE( @"- (NSObject*)get%@", capitalName );
                code.LINE( @"{" );
                code.LINE( @"   return _%@" , property.name);
                code.LINE( @"}" );
            }
        }
    }
    
    return code;
}

@end

#pragma mark -

@implementation SchemaRequest


@end

#pragma mark -

@implementation SchemaResponse

@end

#pragma mark -  /*  ----- 解析key-->controller------ */

@implementation SchemaController

@synthesize method = _method;
@synthesize url = _url;
@dynamic relativeUrl;
@synthesize request = _request;
@synthesize response = _response;

- (NSString *)methodName
{
    NSString * methodName = self.url;
    
    if ( [methodName hasPrefix:@"http://"] )
    {
        methodName = [methodName stringByReplacingOccurrencesOfString:@"http://" withString:@""];
    }
    else if ( [methodName hasPrefix:@"https://"] )
    {
        methodName = [methodName stringByReplacingOccurrencesOfString:@"https://" withString:@""];
    }
    else
    {
        methodName = [methodName hasPrefix:@"/"] ? [methodName substringFromIndex:1] : methodName;
    }
    
    if ( [self.protocol.shortName boolValue] )
    {
        methodName = [[methodName lastPathComponent] stringByDeletingPathExtension];
    }
    
    methodName = [methodName stringByReplacingOccurrencesOfString:@"/:" withString:@"_"];
    methodName = [methodName stringByReplacingOccurrencesOfString:@"/." withString:@"_"];
    methodName = [methodName stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    methodName = [methodName stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    
    return methodName.uppercaseString;
}

- (NSArray *)methodParams
{
    NSMutableArray * params = [NSMutableArray array];
    
    NSArray * segments = [self.url componentsSeparatedByString:@"/"];
    for ( NSString * segment in segments )
    {
        if ( [segment hasPrefix:@":"] )
        {
            [params addObject:segment];
        }
    }
    
    return params;
}

//----------------SchemaController制造工厂（一个controller的最终产品，包括类名，类属性，类属性类型）

+ (id)parseKey:(NSString *)key value:(NSDictionary *)value protocol:(SchemaProtocol *)protocol
{
    //	INFO( @"controller >>> '%@'", key );
    
    NSArray *		array = [key componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *		method = (array.count > 0) ? [array objectAtIndex:0] : nil;
    NSString *		url = (array.count > 1) ? [array objectAtIndex:1] : nil;
    
    if ( [key hasPrefix:@"-"] )
    {
        INFO( @"'%@' skipped", key );
        return nil;
    }
    
    NSDictionary *	request = [value objectForKey:@"request"];
    NSDictionary *	response = [value objectForKey:@"response"];
    
    if ( nil == method )
    {
        WARN( @"method not found" );
        return nil;
    }
    
    if ( nil == url )
    {
        WARN( @"url not found" );
        return nil;
    }
    
    SchemaController * controller = [[[self alloc] init] autorelease];
    if ( controller )
    {
        controller.method = method;
        controller.url = url;
        
        NSString * key = [controller methodName];
        NSString * reqKey = [[NSString stringWithFormat:@"REQ_%@", key] uppercaseString];
        NSString * rspKey = [[NSString stringWithFormat:@"RESP_%@", key] uppercaseString];
        
        if ( nil == request && nil == response )
        {
            controller.request = nil;
            controller.response = [SchemaResponse parseKey:rspKey value:value protocol:protocol];
        }
        else
        {
            if ( request )
            {
                controller.request = [SchemaRequest parseKey:reqKey value:request protocol:protocol];
            }
            
            if ( response )
            {
                controller.response = [SchemaResponse parseKey:rspKey value:response protocol:protocol];
            }
        }
    }
    
    controller.desc = [value objectForKey:@"__desc__"];
    controller.protocol = protocol;
    return controller;
}

- (NSString *)relativeUrl
{
    if ( nil == self.url )
        return nil;
    
    if ( [self.url hasPrefix:@"http://"] || [self.url hasPrefix:@"https://"] )
    {
        NSURL * url = [NSURL URLWithString:self.url];
        if ( nil == url )
            return nil;
        
        return url.path;
    }
    else
    {
        return self.url;
    }
}


- (NSString *)h
{
    NSMutableString *	code = [NSMutableString string];
    NSString *			prefix = self.protocol.prefix;
    
    code.LINE( @"#pragma mark - %@ %@", self.method, self.url );
    code.LINE( nil );
    
    if ( self.request && self.request.properties.count )
    {
        code.LINE( [self.request h] );
    }
    
    if ( self.response && self.response.properties.count )
    {
        code.LINE( [self.response h] );
    }
    
    NSString * key = [self methodName];
    NSString * msgKey = [[NSString stringWithFormat:@"API_%@", key] uppercaseString];
    NSString * reqKey = nil;
    NSString * rspKey = nil;
    
    if ( self.request )
    {
        if ( self.request.isContainer )
        {
            reqKey = [[NSString stringWithFormat:@"REQ_%@", key] uppercaseString];
        }
        else
        {
            SchemaProperty * property = [self.request.properties safeObjectAtIndex:0];
            reqKey = property.elemClass;
        }
    }
    
    if ( self.response )
    {
        if ( self.response.isContainer )
        {
            rspKey = [[NSString stringWithFormat:@"RESP_%@", key] uppercaseString];
        }
        else
        {
            SchemaProperty * property = [self.response.properties safeObjectAtIndex:0];
            rspKey = property.elemClass;
        }
    }
    
    code.LINE( @"@interface %@%@ : BeeAPI", prefix, msgKey );
    
    NSArray * params = [self methodParams];
    for ( NSString * param in params )
    {
        NSString * name = [param.trim substringFromIndex:1];
        code.LINE( @"@property (nonatomic, retain) NSString *	%@;", name );
    }
    
    if ( self.request && self.request.properties.count )
    {
        if ( self.request.isContainer )
        {
            code.LINE( @"@property (nonatomic, retain) %@%@ *	req;", prefix, reqKey );
        }
        else
        {
            if ( self.request.isArray )
            {
                code.LINE( @"@property (nonatomic, retain) NSArray *	req;" );
            }
            else
            {
                code.LINE( @"@property (nonatomic, retain) %@%@ *	req;", prefix, reqKey );
            }
        }
    }
    
    if ( self.response && self.response.properties.count )
    {
        if ( self.response.isContainer )
        {
            code.LINE( @"@property (nonatomic, retain) %@%@ *	resp;", prefix, rspKey );
        }
        else
        {
            if ( self.response.isArray )
            {
                code.LINE( @"@property (nonatomic, retain) NSArray *	resp;" );
            }
            else
            {
                code.LINE( @"@property (nonatomic, retain) %@%@ *	resp;", prefix, rspKey );
            }
        }
    }
    
    code.LINE( @"@end" );
    
    return code;
}

- (NSString *)mm
{
    NSMutableString *	code = [NSMutableString string];
    NSString *			prefix = self.protocol.prefix;
    
    code.LINE( @"#pragma mark - %@ %@", self.method, self.url );
    code.LINE( nil );
    
    if ( self.request && self.request.properties.count )
    {
        code.LINE( [self.request mm] );
    }
    
    if ( self.response && self.response.properties.count )
    {
        code.LINE( [self.response mm] );
    }
    
    NSString * key = [self methodName];
    NSString * msgKey = [[NSString stringWithFormat:@"API_%@", key] uppercaseString];
    NSString * reqKey = nil;
    NSString * rspKey = nil;
    
    if ( self.request && self.request.properties.count )
    {
        if ( self.request.isContainer )
        {
            reqKey = [[NSString stringWithFormat:@"REQ_%@", key] uppercaseString];
        }
        else
        {
            SchemaProperty * property = [self.request.properties safeObjectAtIndex:0];
            reqKey = property.elemClass;
        }
    }
    
    if ( self.response && self.response.properties.count )
    {
        if ( self.response.isContainer )
        {
            rspKey = [[NSString stringWithFormat:@"RESP_%@", key] uppercaseString];
        }
        else
        {
            SchemaProperty * property = [self.response.properties safeObjectAtIndex:0];
            rspKey = property.elemClass;
        }
    }
    
    code.LINE( @"@implementation %@%@", prefix, msgKey );
    code.LINE( nil );
    
    NSArray * params = [self methodParams];
    for ( NSString * param in params )
    {
        NSString * name = [param.trim substringFromIndex:1];
        code.LINE( @"@synthesize %@ = _%@;", name, name );
    }
    
    if ( self.request && self.request.properties.count )
    {
        code.LINE( @"@synthesize req = _req;" );
    }
    
    if ( self.response && self.response.properties.count )
    {
        code.LINE( @"@synthesize resp = _resp;" );
    }
    
    code.LINE( nil );
    
    code.LINE( @"- (id)init" );
    code.LINE( @"{" );
    code.LINE( @"	self = [super init];" );
    code.LINE( @"	if ( self )" );
    code.LINE( @"	{" );
    
    if ( self.request && self.request.properties.count )
    {
        code.LINE( @"		self.req = [[[%@%@ alloc] init] autorelease];", prefix, reqKey );
    }
    
    if ( self.response && self.response.properties.count )
    {
        //		code.LINE( @"		self.resp = [[[%@ alloc] init] autorelease];", rspKey );
        code.LINE( @"		self.resp = nil;" );
    }
    
    code.LINE( @"	}" );
    code.LINE( @"	return self;" );
    code.LINE( @"}" );
    code.LINE( nil );
    
    code.LINE( @"- (void)dealloc" );
    code.LINE( @"{" );
    
    if ( self.request && self.request.properties.count )
    {
        code.LINE( @"	self.req = nil;" );
    }
    
    if ( self.response && self.response.properties.count )
    {
        code.LINE( @"	self.resp = nil;" );
    }
    
    code.LINE( @"	[super dealloc];" );
    code.LINE( @"}" );
    code.LINE( nil );
    
    code.LINE( @"- (void)routine" );
    code.LINE( @"{" );
    code.LINE( @"	if ( self.sending )" );
    code.LINE( @"	{" );
    
    if ( self.request && self.request.properties.count )
    {
        if ( self.request.isContainer )
        {
            code.LINE( @"		if ( nil == self.req || NO == [self.req validate] )" );
            code.LINE( @"		{" );
            code.LINE( @"			self.failed = YES;" );
            code.LINE( @"			return;" );
            code.LINE( @"		}" );
            code.LINE( nil );
        }
        else
        {
            code.LINE( @"		if ( nil == self.req )" );
            code.LINE( @"		{" );
            code.LINE( @"			self.failed = YES;" );
            code.LINE( @"			return;" );
            code.LINE( @"		}" );
            code.LINE( nil );
        }
    }
    
    if ( params && params.count )
    {
        for ( NSString * param in params )
        {
            NSString * name = [param.trim substringFromIndex:1];
            
            code.LINE( @"		if ( NULL == self.%@ )", name );
            code.LINE( @"		{" );
            code.LINE( @"			self.failed = YES;" );
            code.LINE( @"			return;" );
            code.LINE( @"		}" );
            code.LINE( nil );
        }
    }
    
    if ( [self.url hasPrefix:@"http://"] || [self.url hasPrefix:@"https://"] )
    {
        code.LINE( @"		NSString * requestURI = @\"%@\";", self.url );
    }
    else
    {
        code.LINE( @"		NSString * requestURI = [[%@ServerConfig sharedInstance].url stringByAppendingString:@\"%@\"];", prefix, self.url );
    }
    
    if ( params && params.count )
    {
        for ( NSString * param in params )
        {
            NSString * name = [param.trim substringFromIndex:1];
            code.LINE( @"		requestURI = [requestURI stringByReplacingOccurrencesOfString:@\"%@\" withString:self.%@];", param, name );
        }
        
        code.LINE( nil );
    }
    
    if ( self.request && self.request.properties.count )
    {
        if ( NSOrderedSame == [self.method compare:@"GET" options:NSCaseInsensitiveSearch] )
        {
            code.LINE( @"		self.HTTP_%@( requestURI ).PARAM( [self.req objectToDictionary] );", [self.method uppercaseString] );
        }
        else
        {
            code.LINE( @"		NSString * requestBody = [self.req objectToString];" );
            code.LINE( @"		self.HTTP_%@( requestURI ).PARAM( @\"json\", requestBody );", [self.method uppercaseString] );
        }
    }
    else
    {
        code.LINE( @"		self.HTTP_%@( requestURI );", [self.method uppercaseString] );
    }
    
    code.LINE( @"	}" );
    code.LINE( @"	else if ( self.succeed )" );
    code.LINE( @"	{" );
    
    if ( self.response && self.response.properties.count )
    {
        code.LINE( @"		NSObject * result = self.responseJSON;" );
        code.LINE( nil );
        
        if ( self.response.isContainer )
        {
            code.LINE( @"		if ( result && [result isKindOfClass:[NSDictionary class]] )" );
            code.LINE( @"		{" );
            code.LINE( @"			self.resp = [%@%@ objectFromDictionary:(NSDictionary *)result];", prefix, rspKey );
            code.LINE( @"		}" );
            code.LINE( nil );
            
            code.LINE( @"		if ( nil == self.resp || NO == [self.resp validate] )" );
            code.LINE( @"		{" );
            code.LINE( @"			self.failed = YES;" );
            code.LINE( @"			return;" );
            code.LINE( @"		}" );
        }
        else
        {
            if ( self.response.isArray )
            {
                code.LINE( @"		if ( result && [result isKindOfClass:[NSArray class]] )" );
                code.LINE( @"		{" );
                code.LINE( @"			self.resp = [%@%@ objectsFromArray:(NSArray *)result];", prefix, rspKey );
                code.LINE( @"		}" );
                code.LINE( nil );
            }
            else
            {
                code.LINE( @"		if ( result && [result isKindOfClass:[%@%@ class]] )", prefix, rspKey );
                code.LINE( @"		{" );
                code.LINE( @"			self.resp = (%@%@ *)result;", prefix, rspKey );
                code.LINE( @"		}" );
                code.LINE( @"		else if ( result && [result isKindOfClass:[NSDictionary class]] )" );
                code.LINE( @"		{" );
                code.LINE( @"			self.resp = [%@%@ objectFromDictionary:(NSDictionary *)result];", prefix, rspKey );
                code.LINE( @"		}" );
                code.LINE( nil );
            }
            
            code.LINE( @"		if ( nil == self.resp )" );
            code.LINE( @"		{" );
            code.LINE( @"			self.failed = YES;" );
            code.LINE( @"			return;" );
            code.LINE( @"		}" );
        }
    }
    else
    {
        code.LINE( @"		// TODO:" );
    }
    
    code.LINE( @"	}" );
    code.LINE( @"	else if ( self.failed )" );
    code.LINE( @"	{" );
    code.LINE( @"		// TODO:" );
    code.LINE( @"	}" );
    code.LINE( @"	else if ( self.cancelled )" );
    code.LINE( @"	{" );
    code.LINE( @"		// TODO:" );
    code.LINE( @"	}" );
    code.LINE( @"}" );
    
    code.LINE( @"@end" );
    
    return code;
}

@end

#pragma mark -

@implementation SchemaEnum

@synthesize isString = _isString;
@synthesize name = _name;
@synthesize values = _values;

+ (id)parseKey:(NSString *)key value:(id)value protocol:(SchemaProtocol *)protocol
{
    //	INFO( @"enum >>> '%@'", key );
    
    if ( nil == value || NO == [value isKindOfClass:[NSDictionary class]] )
        return nil;
    
    SchemaEnum * enums = [[[self alloc] init] autorelease];
    enums.name = key;
    enums.values = value;
    
    NSDictionary * dict = (NSDictionary *)value;
    if ( dict.count )
    {
        NSString * key = [dict.allKeys objectAtIndex:0];
        NSObject * val = [dict objectForKey:key];
        
        if ( [val isKindOfClass:[NSString class]] )
        {
            enums.isString = YES;
        }
    }
    
    enums.protocol = protocol;
    return enums;
}


- (NSString *)h
{
    NSMutableString *	code = [NSMutableString string];
    NSString *			prefix = self.protocol.prefix;
    
    NSString * firstKey = [self.values.allKeys objectAtIndex:0];
    NSObject * firstVal = [self.values objectForKey:firstKey];
    
    if ( [firstVal isKindOfClass:[NSNumber class]] )
    {
        code.LINE( @"enum %@%@", prefix, self.name );
        code.LINE( @"{" );
        
        NSMutableArray * sortedKeys = [NSMutableArray arrayWithArray:self.values.allKeys];
        [sortedKeys sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            NSNumber * number1 = [self.values objectForKey:obj1];
            NSNumber * number2 = [self.values objectForKey:obj2];
            return [number1 compare:number2];
        }];
        
        for ( NSString * key in sortedKeys )
        {
            NSNumber * val = [self.values objectForKey:key];
            if ( val )
            {
                code.LINE( @"	%@%@_%@ = %@,", prefix, self.name, key, val );
            }
        }
        
        code.LINE( @"};" );
    }
    else if ( [firstVal isKindOfClass:[NSString class]] )
    {
        for ( NSString * key in self.values.allKeys )
        {
            NSString * val = [self.values objectForKey:key];
            if ( val )
            {
                code.LINE( @"#define %@%@_%@	@\"%@\"", prefix, self.name, key, val );
            }
        }
    }
    
    return code;
}

- (NSString *)mm
{
    return nil;
}

@end

#pragma mark -

@implementation SchemaProtocol

@synthesize author = _author;
@synthesize title = _title;
@synthesize source = _source;
@synthesize prefix = _prefix;
@synthesize shortName = _shortName;

@synthesize server = _server;

@synthesize enums = _enums;
@synthesize models = _models;
@synthesize controllers = _controllers;

@synthesize fileName = _fileName;

- (BOOL)parseString:(NSString *)str error:(NSError **)perror
{
    NSError * error = NULL;
    //数据源
    NSObject * obj = [str objectFromJSONStringWithParseOptions:JKParseOptionValidFlags error:&error];
    if ( nil == obj || NO == [obj isKindOfClass:[NSDictionary class]] )
    {
        if ( perror )
        {
            *perror = error;
        }
        return NO;
    }
    
    NSMutableDictionary * dict = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)obj];
    
    // read configuration
    
    self.author = [dict stringAtPath:@"author"];
    self.title = [dict stringAtPath:@"title"];
    self.source = [dict stringAtPath:@"source"];
    self.prefix = [dict stringAtPath:@"prefix"];
    self.shortName = [dict numberAtPath:@"shortname"];
    self.server = [dict dictAtPath:@"server"];
    
    if ( nil == self.prefix || 0 == self.prefix.length )
    {
        self.prefix = @"";
    }
    
    [dict removeObjectForKey:@"author"];
    [dict removeObjectForKey:@"title"];
    [dict removeObjectForKey:@"source"];
    [dict removeObjectForKey:@"prefix"];
    [dict removeObjectForKey:@"shortname"];
    [dict removeObjectForKey:@"server"];
    
    // start to parse
    
    self.enums = [[[NSMutableArray alloc] init] autorelease];
    self.models = [[[NSMutableArray alloc] init] autorelease];
    self.controllers = [[[NSMutableArray alloc] init] autorelease];
    self.propertyModels_M = [[[NSMutableArray alloc] init] autorelease];
    
    /*  ----- 解析key-->enum------ */
    NSDictionary * enums = [dict dictAtPath:@"enum"];
    if ( enums && enums.count )
    {
        NSMutableArray * sortedKeys = [NSMutableArray arrayWithArray:enums.allKeys];
        [sortedKeys sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            return [obj1 compare:obj2];
        }];
        
        for ( NSString * key in sortedKeys )
        {
            SchemaEnum * object = [SchemaEnum parseKey:key value:[enums objectForKey:key] protocol:self];
            if ( object )
            {
                [self.enums addObject:object];
            }
        }
    }
    
    /*  ----- 解析key-->model------ */
    NSDictionary * model = [dict dictAtPath:@"model"];
    if ( model && model.count )
    {
        for ( NSString * key in model.allKeys )
        {
            SchemaModel * object = [SchemaModel parseKey:key value:[model objectForKey:key] protocol:self];
            if ( object )
            {
                [self.models addObject:object];
            }
        }
    }
    else
    {
        for ( NSString * key in [NSArray arrayWithArray:dict.allKeys] )
        {
            if ( [key hasPrefix:@"GET "] || [key hasPrefix:@"POST "] || [key hasPrefix:@"PUT "] || [key hasPrefix:@"HEAD "] || [key hasPrefix:@"DELETE "] )
            {
                continue;
            }
            
            SchemaModel * object = [SchemaModel parseKey:key value:[dict objectForKey:key] protocol:self];
            if ( object )
            {
                [self.models addObject:object];
                
                [dict removeObjectForKey:key];
            }
        }
    }
    
    /*  ----- 解析key-->protocal------ */
    NSDictionary * protocal = [dict dictAtPath:@"protocal"];
    if ( protocal && protocal.count )
    {
        for ( NSString * key in protocal.allKeys )
        {
            SchemaProduceProtocal * object = [SchemaProduceProtocal parseKey:key value:[protocal objectForKey:key] protocol:self];
            if ( object )
            {
                [self.models addObject:object];
//                [self.protocals addObject:object];
            }
        }
    }
    else
    {
        for ( NSString * key in [NSArray arrayWithArray:dict.allKeys] )
        {
            if ( [key hasPrefix:@"GET "] || [key hasPrefix:@"POST "] || [key hasPrefix:@"PUT "] || [key hasPrefix:@"HEAD "] || [key hasPrefix:@"DELETE "] )
            {
                continue;
            }
            
            SchemaModel * object = [SchemaModel parseKey:key value:[dict objectForKey:key] protocol:self];
            if ( object )
            {
                [self.models addObject:object];
//                [self.protocals addObject:object];
                [dict removeObjectForKey:key];
            }
        }
    }
    
    /*  ----- 解析key-->SchemaProperties_M------ */
    NSDictionary* properties_M = [dict dictAtPath:@"properties_M"];
    if (properties_M && properties_M.count) {
        for (NSString* key in properties_M.allKeys) {
            SchemaProperties_M* obj = [SchemaProperties_M parseKey:key value:[properties_M objectForKey:key] protocol:self];
            if (obj) {
                [self.propertyModels_M addObject:obj];
                
            }
            
        }
    }
    else
    {
        for ( NSString * key in [NSArray arrayWithArray:dict.allKeys] )
        {
            if ( [key hasPrefix:@"GET "] || [key hasPrefix:@"POST "] || [key hasPrefix:@"PUT "] || [key hasPrefix:@"HEAD "] || [key hasPrefix:@"DELETE "] )
            {
                continue;
            }
            
            SchemaModel * object = [SchemaModel parseKey:key value:[dict objectForKey:key] protocol:self];
            if ( object )
            {
                [self.models addObject:object];
                
                [dict removeObjectForKey:key];
            }
        }
    }
    
    
    /*  ----- 解析key-->controller------ */
    NSDictionary * controller = [dict dictAtPath:@"controller"];
    if ( controller && controller.count )
    {
        for ( NSString * key in controller.allKeys )
        {
            SchemaController * object = [SchemaController parseKey:key value:[controller objectForKey:key] protocol:self];
            if ( object )
            {
                [self.controllers addObject:object];
            }
        }
    }
    else
    {
        for ( NSString * key in [NSArray arrayWithArray:dict.allKeys] )
        {
            SchemaController * object = [SchemaController parseKey:key value:[dict objectForKey:key] protocol:self];
            if ( object )
            {
                [self.controllers addObject:object];
                
                [dict removeObjectForKey:key];
                
                //				VAR_DUMP( [object.response JSON] );
            }
        }
    }
    
    // TODO: model merge
    
    [self.models sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        SchemaModel * model1 = (SchemaModel *)obj1;
        SchemaModel * model2 = (SchemaModel *)obj2;
        
        if ( nil == model1.superClassName && nil == model2.superClassName )
        {
            return [model1.className compare:model2.className];
        }
        else
        {
            if ( model1.superClassName )
            {
                return NSOrderedDescending;
            }
            
            if ( model2.superClassName )
            {
                return NSOrderedAscending;
            }
            
            return NSOrderedSame;
        }
    }];
    
    [self.controllers sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        SchemaController * controller1 = obj1;
        SchemaController * controller2 = obj2;
        return [controller1.url compare:controller2.url];
    }];
    
    [dict removeObjectForKey:@"enum"];
    [dict removeObjectForKey:@"model"];
    [dict removeObjectForKey:@"controller"];
    [dict removeObjectForKey:@"protocal"];//额外加的
    
    if ( dict.count )
    {
        WARN( @"unknown structure: \n%@", dict );
    }
    
    INFO( @"total: %d enum(s), %d model(s), %d controller(s)", self.enums.count, self.models.count, self.controllers.count );
    
    return YES;
}

- (SchemaEnum *)enumByName:(NSString *)name
{
    for ( SchemaEnum * enums in self.enums )
    {
        if ( [enums.name isEqualToString:name] )
            return enums;
    }
    
    return nil;
}

- (SchemaModel *)modelByName:(NSString *)name
{
    if ( [name hasPrefix:@"!"] )
    {
        name = [name substringFromIndex:1].trim;
    }
    
    for ( SchemaModel * model in self.models )
    {
        if ( [model.className isEqualToString:name] )
            return model;
    }
    
    return nil;
}

- (void)outputHeader:(NSMutableString *)code//头部 title author date
{
    code.LINE( @"// title:  %@", self.title ? self.title : @"" );
    code.LINE( @"// author: %@", self.author ? self.author : @"unknown" );
    code.LINE( @"// date:   %@", NSDate.now );
    code.LINE( @"//" );
    code.LINE( nil );
}

- (NSString *)h//生成.h
{
    NSMutableString *	code = [NSMutableString string];
    NSString *			prefix = self.prefix;
    
    [self outputHeader:code];
    
    code.LINE( @"#import \"Lion.h\"" );
    code.LINE( nil );
    
    if ( self.enums && self.enums.count )
    {
        code.LINE( @"#pragma mark - enums" );
        code.LINE( nil );
        
        for ( SchemaEnum * e in self.enums )
        {
            code.LINE( [e h] );
        }
    }
    
    //model
    if ( self.models && self.models.count )
    {
        code.LINE( @"#pragma mark - models" );
        code.LINE( nil );
        
        for ( SchemaModel * model in self.models )
        {
            code.LINE( @"@class %@%@;", prefix, model.className );
        }
        
        code.LINE( nil );
        
        for ( SchemaModel * model in self.models )
        {
            //		code.LINE( @"// %@", model.className );
            code.LINE( [model h] );
        }
    }
    
    
    //protocal
    if ( self.protocals && self.protocals.count )
    {
        code.LINE( @"#pragma mark - protocal" );
        code.LINE( nil );
        
        for ( SchemaProduceProtocal * protocal in self.protocals )
        {
            code.LINE( @"@class %@%@;", prefix, protocal.className );
        }
        
        code.LINE( nil );
        
        for ( SchemaProduceProtocal * protocal in self.protocals )
        {
            //		code.LINE( @"// %@", model.className );
            code.LINE( [protocal h] );
        }
    }
    
    //controller
//    if ( self.controllers && self.controllers.count )
    if ( !self.controllers && self.controllers.count )//不要controllers
    {
        code.LINE( @"#pragma mark - controllers" );
        code.LINE( nil );
        
        for ( SchemaController * controller in self.controllers )
        {
            code.LINE( [controller h] );
        }
        
        code.LINE( @"#pragma mark - config" );
        code.LINE( nil );
        
        code.LINE( [NSString stringWithFormat:@"@interface %@ServerConfig : NSObject", prefix] );
        code.LINE( nil );
        
        code.LINE( [NSString stringWithFormat:@"AS_SINGLETON( %@ServerConfig )", prefix] );
        code.LINE( nil );
        
        code.LINE( @"AS_INT( CONFIG_DEVELOPMENT )" );
        code.LINE( @"AS_INT( CONFIG_TEST )" );
        code.LINE( @"AS_INT( CONFIG_PRODUCTION )" );
        code.LINE( nil );
        
        code.LINE( @"@property (nonatomic, assign) NSUInteger			config;" );
        code.LINE( nil );
        
        code.LINE( @"@property (nonatomic, readonly) NSString *			url;" );
        code.LINE( @"@property (nonatomic, readonly) NSString *			testUrl;" );
        code.LINE( @"@property (nonatomic, readonly) NSString *			productionUrl;" );
        code.LINE( @"@property (nonatomic, readonly) NSString *			developmentUrl;" );
        code.LINE( nil );
        
        code.LINE( @"@end" );
        code.LINE( nil );
    }
    
    return code;//最终的.h
}

- (NSString *)mm
{
    NSMutableString *	code = [NSMutableString string];
    NSString *			prefix = self.prefix;
    
    [self outputHeader:code];
    
    code.LINE( @"#import \"%@.h\"", self.fileName );
    code.LINE( nil );
    
    /*  .m中的属性集 */
    if ( self.propertyModels_M && self.propertyModels_M.count )
    {
        for ( SchemaProperties_M * model in self.propertyModels_M )
        {
            code.LINE( [model mm] );
        }
    }
    
    code.LINE( @"#pragma mark set get" );
    /*  .h中的属性集 */ //生成get set方法
    if ( self.models && self.models.count )
    {
        for ( SchemaModel * model in self.models )
        {
            code.LINE( [model publicSetGetMethod] );
        }
    }
    
    code.LINE( @"@end" );
    //----------------------------------------------------------@end
    
//    if ( self.controllers && self.controllers.count )//去除controller
    if ( !self.controllers && self.controllers.count )
    {
        for ( SchemaController * controller in self.controllers )
        {
            code.LINE( [controller mm] );
        }
        
        NSString * dev = [self.server objectForKey:@"development"];
        NSString * tst = [self.server objectForKey:@"test"];
        NSString * pro = [self.server objectForKey:@"production"];
        
        code.LINE( @"#pragma mark - config" );
        code.LINE( nil );
        
        code.LINE( [NSString stringWithFormat:@"@implementation %@ServerConfig", prefix] );
        code.LINE( nil );
        
        code.LINE( [NSString stringWithFormat:@"DEF_SINGLETON( %@ServerConfig )", prefix] );
        code.LINE( nil );
        
        code.LINE( @"DEF_INT( CONFIG_DEVELOPMENT,	0 )" );
        code.LINE( @"DEF_INT( CONFIG_TEST,			1 )" );
        code.LINE( @"DEF_INT( CONFIG_PRODUCTION,	2 )" );
        code.LINE( nil );
        
        code.LINE( @"@synthesize config = _config;" );
        code.LINE( @"@dynamic url;" );
        code.LINE( @"@dynamic testUrl;" );
        code.LINE( @"@dynamic productionUrl;" );
        code.LINE( @"@dynamic developmentUrl;" );
        code.LINE( nil );
        
        code.LINE( @"- (NSString *)url" );
        code.LINE( @"{" );
        code.LINE( @"	NSString * host = nil;" );
        code.LINE( nil );
        code.LINE( @"	if ( self.CONFIG_DEVELOPMENT == self.config )" );
        code.LINE( @"	{" );
        code.LINE( @"		host = self.developmentUrl;" );
        code.LINE( @"	}" );
        code.LINE( @"	else if ( self.CONFIG_TEST == self.config )" );
        code.LINE( @"	{" );
        code.LINE( @"		host = self.testUrl;" );
        code.LINE( @"	}" );
        code.LINE( @"	else" );
        code.LINE( @"	{" );
        code.LINE( @"		host = self.productionUrl;" );
        code.LINE( @"	}" );
        code.LINE( nil );
        code.LINE( @"	if ( NO == [host hasPrefix:@\"http://\"] && NO == [host hasPrefix:@\"https://\"] )" );
        code.LINE( @"	{" );
        code.LINE( @"		host = [@\"http://\" stringByAppendingString:host];" );
        code.LINE( @"	}" );
        code.LINE( nil );
        code.LINE( @"	return host;" );
        code.LINE( @"}" );
        code.LINE( nil );
        
        code.LINE( @"- (NSString *)developmentUrl" );
        code.LINE( @"{" );
        code.LINE( [NSString stringWithFormat:@"	return @\"%@\";", dev ? dev : @""] );
        code.LINE( @"}" );
        code.LINE( nil );
        
        code.LINE( @"- (NSString *)testUrl" );
        code.LINE( @"{" );
        code.LINE( [NSString stringWithFormat:@"	return @\"%@\";", tst ? tst : @""] );
        code.LINE( @"}" );
        code.LINE( nil );
        
        code.LINE( @"- (NSString *)productionUrl" );
        code.LINE( @"{" );
        code.LINE( [NSString stringWithFormat:@"	return @\"%@\";", pro ? pro : @""] );
        code.LINE( @"}" );
        code.LINE( nil );
        
        code.LINE( @"@end" );
        code.LINE( nil );
    }
    
    return code;
}

@end

#pragma mark -

@implementation SchemaGenerator

@synthesize inputPath = _inputPath;
@synthesize inputFile = _inputFile;
@synthesize outputPath = _outputPath;

@synthesize errorLine = _errorLine;
@synthesize errorDesc = _errorDesc;

@synthesize results = _results;

- (BOOL)generate//组织数据
{
    NSString *	inputFullPath = nil;
    NSString *	inputExtension = nil;
    
    NSString *	outputPath = nil;
    NSString *	outputFullPath = nil;
    NSString *	outputFileH = nil;
    NSString *	outputFileM = nil;
    
    NSString *	date = [[NSDate now] stringWithDateFormat:@"yyyyMMdd_hhmmss"];
    
    inputFullPath = [NSString stringWithFormat:@"%@/%@", self.inputPath, self.inputFile];
    inputFullPath = [inputFullPath stringByReplacingOccurrencesOfString:@"//" withString:@"/"];
    inputExtension = [NSString stringWithFormat:@".%@", [inputFullPath pathExtension]];
    
    outputPath = [NSString stringWithFormat:@"%@/%@", self.outputPath ? self.outputPath : self.inputPath, date];
    [LionSandbox touch:[NSString stringWithFormat:@"%@", outputPath]];
    
    outputFullPath = [NSString stringWithFormat:@"%@/%@", outputPath, self.inputFile];
    outputFullPath = [outputFullPath stringByReplacingOccurrencesOfString:@"//" withString:@"/"];
    
    outputFileH = [outputFullPath stringByReplacingOccurrencesOfString:inputExtension withString:@".h"];
    outputFileM = [outputFullPath stringByReplacingOccurrencesOfString:inputExtension withString:@".mm"];
    
    NSString * content = [NSString stringWithContentsOfFile:inputFullPath encoding:NSUTF8StringEncoding error:NULL];
    if ( nil == content || 0 == content.length )
    {
        self.errorLine = 0;
        self.errorDesc = [NSString stringWithFormat:@"Failed to open '%@'", inputFullPath];
        return NO;
    }
    
    SchemaProtocol * protocol = [[[SchemaProtocol alloc] init] autorelease];
    if ( nil == protocol )
    {
        self.errorLine = 0;
        self.errorDesc = @"Out of memory";
        return NO;
    }
    
    protocol.fileName = [[outputFullPath lastPathComponent] stringByDeletingPathExtension];
    if ( nil == protocol.fileName || 0 == protocol.fileName.length )
    {
        self.errorLine = 0;
        self.errorDesc = @"Invalid file name";
        return NO;
    }
    
    NSError * error = nil;
    BOOL succeed = [protocol parseString:content error:&error];
    if ( NO == succeed )
    {
        NSDictionary * params = error.userInfo;
        NSString * desc = [params stringAtPath:@"NSLocalizedDescription"];
        NSString * line = [params stringAtPath:@"JKLineNumberKey"];
        
        self.errorLine = line.integerValue;
        self.errorDesc = desc;
        return NO;
    }
    
    NSString * hh = [protocol h];
    NSString * mm = [protocol mm];

    [hh writeToFile:outputFileH atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [mm writeToFile:outputFileM atomically:YES encoding:NSUTF8StringEncoding error:NULL];

    self.results = [NSMutableArray array];
    [self.results addObject:outputFileH];
    [self.results addObject:outputFileM];

    
    return YES;
}

@end

