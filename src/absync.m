#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>
#include <getopt.h>

NSString* absyncAbPersonFullName(ABPerson *person)
{
  NSString *name = [NSString string];
  if ([[person valueForProperty:kABPersonFlags] intValue] & kABShowAsCompany)
    {
      name = [name stringByAppendingString:[person valueForProperty:kABOrganizationProperty]];
    }
  else
    {
      if ([person valueForProperty:kABLastNameProperty])
        {
          name = [name stringByAppendingString:[person valueForProperty:kABLastNameProperty]];
          name = [name stringByAppendingString:@", "];
        }
      if ([person valueForProperty:kABTitleProperty])
        {
          name = [name stringByAppendingString:[person valueForProperty:kABTitleProperty]];
          name = [name stringByAppendingString:@" "];
        }
      if ([person valueForProperty:kABFirstNameProperty])
        {
          name = [name stringByAppendingString:[person valueForProperty:kABFirstNameProperty]];
        }
      if ([person valueForProperty:kABMiddleNameProperty])
        {
          name = [name stringByAppendingString:@" "];
          name = [name stringByAppendingString:[person valueForProperty:kABMiddleNameProperty]];
        }
    }
  return name;
}

NSInteger absyncPersonSort(ABPerson *person1, ABPerson *person2, void *context)
{
  return [absyncPersonFullName(person1) compare:absyncPersonFullName(person2)];
}

NSDateFormatter* absyncIsoDateFormatter()
{
  NSDateFormatter *dateFormat = [[NSDateFormatter alloc]
                                  initWithDateFormat:@"%Y-%m-%d"
                                  allowNaturalLanguage:NO];
  [dateFormat autorelease];
  return dateFormat;
}

@interface MultiStringItem : NSObject
{
  NSString *key;
  int       index;
}
- (id)initWithKey:(NSString*)k index:(int)i;
+ (MultiStringItem*)itemWithKey:(NSString*)k index:(int)i;
@property (retain) NSString* key;
@property          int       index;
@end

@implementation MultiStringItem
@synthesize key;
@synthesize index;
- (id)initWithKey:(NSString*)k index:(int)i
{
  self = [super init];
  if (self) {
    key   = [k retain];
    index = i;
  }
  return self;
}
- (void)dealloc
{
  [key release];
  [super dealloc];
}
+ (MultiStringItem*)itemWithKey:(NSString*)k index:(int)i
{
  MultiStringItem *item = [[MultiStringItem alloc] initWithKey:k index:i];
  return [item autorelease];
}
- (NSComparisonResult)compare:(MultiStringItem*)otherObject
{
  NSComparisonResult r = [[self key] compare:[otherObject key]];
  if (r == NSOrderedSame)
    {
      if ([self index] < [otherObject index])
        return -1;
      else if ([otherObject index] < [self index])
        return 1;
      else
        return 0;
    }
  else
    return r;
}
@end

NSArray* absyncAbPersonRelevantProperties()
{
  return [NSArray arrayWithObjects:
                    kABTitleProperty,
                  kABFirstNameProperty,
                  kABFirstNamePhoneticProperty,
                  kABMiddleNameProperty,
                  kABMiddleNamePhoneticProperty,
                  kABLastNameProperty,
                  kABLastNamePhoneticProperty,
                  kABSuffixProperty,
                  kABNicknameProperty,
                  kABMaidenNameProperty,
                  kABJobTitleProperty,
                  kABBirthdayProperty,
                  //kABBirthdayComponentsProperty, //OS X 10.7+ only
                  kABOrganizationProperty,
                  //kABHomePageProperty, // deprecated OS X 10.4+
                  kABURLsProperty,
                  kABCalendarURIsProperty,
                  kABEmailProperty,
                  kABAddressProperty,
                  kABOtherDatesProperty,
                  //kABOtherDateComponentsProperty, //OS X 10.7+ only
                  kABRelatedNamesProperty,
                  kABDepartmentProperty,
                  kABPersonFlags,
                  kABPhoneProperty,
                  //kABInstantMessageProperty, //OS X 10.7+ only
                  kABAIMInstantProperty,
                  kABJabberInstantProperty,
                  kABMSNInstantProperty,
                  kABYahooInstantProperty,
                  kABICQInstantProperty,
                  kABNoteProperty,
                  //kABSocialProfileProperty, //OS X 10.7+ only
                  nil];
}

NSXMLElement* absyncAbPersonBuildXml(ABPerson *person, BOOL isMe)
{
  NSArray *personProperties = absyncAbPersonRelevantProperties();

  NSXMLElement *xmlPerson = (NSXMLElement*)[NSXMLNode elementWithName:@"Person"];
  // is me?
  if (isMe)
    {
      [xmlPerson addChild:[NSXMLNode elementWithName:@"IsMe" stringValue:@"1"]];
    }
  // person groups
  NSMutableArray *sortedGroups = [NSMutableArray arrayWithCapacity:0];
  for (ABGroup *group in [person parentGroups])
    {
      [sortedGroups addObject:[group valueForProperty:kABGroupNameProperty]];
    }
  [sortedGroups sortUsingSelector:@selector(compare:)];
  NSXMLElement *xmlGroups = (NSXMLElement*)[NSXMLNode elementWithName:@"Groups"];
  for (NSString *groupName in sortedGroups)
    {
      [xmlGroups addChild:[NSXMLNode elementWithName:@"Group" stringValue:groupName]];
    }
  [xmlPerson addChild:xmlGroups];
  // person properties
  for (NSString* property in personProperties)
    {
      if ([property isEqualToString:kABPersonFlags] || [person valueForProperty:property])
        {
          id value = [person valueForProperty:property];
          // string
          if ([value isKindOfClass:[NSString class]])
            {
              [xmlPerson addChild:[NSXMLNode elementWithName:property
                                             children:[NSArray arrayWithObjects: [NSXMLNode textWithStringValue:value], nil]
                                             attributes:[NSArray arrayWithObjects: [NSXMLNode attributeWithName:@"type"
                                                                                              stringValue:@"string"], nil]]];
            }
          // date
          else if ([value isKindOfClass:[NSDate class]])
            {
              [xmlPerson addChild:[NSXMLNode elementWithName:property
                                             children:[NSArray arrayWithObjects:
                                                                 [NSXMLNode textWithStringValue:[absyncIsoDateFormatter() stringFromDate:value]], nil]
                                             attributes:[NSArray arrayWithObjects:
                                                                   [NSXMLNode attributeWithName:@"type" stringValue:@"date"], nil]]];
            }
          else if ([value isKindOfClass:[ABMultiValue class]])
            {
              // sort keys of the multivalue
              // NYI: store primaryIdentifier
              NSMutableArray *sortedKeys = [NSMutableArray arrayWithCapacity:0];
              int i = 0;
              for (; i < [value count]; i++)
                {
                  [sortedKeys addObject:[MultiStringItem itemWithKey:[value labelAtIndex:i] index:i]];
                }
              [sortedKeys sortUsingSelector:@selector(compare:)];

              // multistring
              if ([value propertyType] == kABMultiStringProperty /*kABStringProperty*/)
                {
                  NSXMLElement *xmlValue = (NSXMLElement*)[NSXMLNode elementWithName:property
                                                                     children:nil
                                                                     attributes:[NSArray arrayWithObjects: [NSXMLNode attributeWithName:@"type"
                                                                                                                      stringValue:@"multistring"], nil]];
                  [xmlPerson addChild:xmlValue];
                  for (MultiStringItem *item in sortedKeys)
                    {
                      NSXMLElement *xmlItem =
                        (NSXMLElement*)[NSXMLNode elementWithName:@"item"
                                                  children:[NSArray arrayWithObjects:
                                                                      [NSXMLNode elementWithName:@"key" stringValue:[item key]],
                                                                    [NSXMLNode elementWithName:@"value" stringValue:[value valueAtIndex:[item index]]],
                                                                    nil]
                                                  attributes:nil];
                      [xmlValue addChild:xmlItem];
                    }
                }
              // multidate
              else if ([value propertyType] == kABMultiDateProperty /*kABDateProperty*/)
                {
                  NSXMLElement *xmlValue = (NSXMLElement*)[NSXMLNode elementWithName:property
                                                                     children:nil
                                                                     attributes:[NSArray arrayWithObjects: [NSXMLNode attributeWithName:@"type"
                                                                                                                      stringValue:@"multidate"], nil]];
                  [xmlPerson addChild:xmlValue];
                  for (MultiStringItem *item in sortedKeys)
                    {
                      NSXMLElement *xmlItem =
                        (NSXMLElement*)[NSXMLNode elementWithName:@"item"
                                                  children:[NSArray arrayWithObjects:
                                                                      [NSXMLNode elementWithName:@"key" stringValue:[item key]],
                                                                    [NSXMLNode elementWithName:@"value" stringValue:
                                                                                 [absyncIsoDateFormatter() stringFromDate:[value valueAtIndex:[item index]]]],
                                                                    nil]
                                                  attributes:nil];
                      [xmlValue addChild:xmlItem];
                    }
                }
              // multidictionary
              else if ([value propertyType] == kABMultiDictionaryProperty /*kABDictionaryProperty*/)
                {
                  NSXMLElement *xmlValue = (NSXMLElement*)[NSXMLNode elementWithName:property
                                                                     children:nil
                                                                     attributes:[NSArray arrayWithObjects: [NSXMLNode attributeWithName:@"type"
                                                                                                                      stringValue:@"multidict"], nil]];
                  [xmlPerson addChild:xmlValue];
                  for (MultiStringItem *item in sortedKeys)
                    {
                      NSXMLElement *xmlItem = (NSXMLElement*)[NSXMLNode elementWithName:@"item"];
                      [xmlItem addChild:[NSXMLNode elementWithName:@"key" stringValue:[item key]]];
                      NSDictionary *dict = [value valueAtIndex:[item index]];
                      NSArray *sortedDictKeys = [[dict allKeys] sortedArrayUsingSelector:@selector(compare:)];
                      NSXMLElement *xmlDict = (NSXMLElement*)[NSXMLNode elementWithName:@"Dict"];
                      for (NSString *dictKey in sortedDictKeys)
                        {
                          id dictValue = [dict objectForKey:dictKey];
                          assert([dictValue isKindOfClass:[NSString class]]);
                          NSXMLElement *xmlDictItem = (NSXMLElement*)[NSXMLNode elementWithName:@"DictItem"];
                          [xmlDictItem addChild:[NSXMLNode elementWithName:@"key" stringValue:dictKey]];
                          [xmlDictItem addChild:[NSXMLNode elementWithName:@"value" stringValue:dictValue]];
                          [xmlDict addChild:xmlDictItem];
                        }
                      [xmlItem addChild:[NSXMLNode elementWithName:@"value"
                                                   children:[NSArray arrayWithObjects:xmlDict, nil]
                                                   attributes:nil]];
                      [xmlValue addChild:xmlItem];
                    }
                }
              // multi date components // OS X 10.7+ only
            }
          // person flags
          else if ([value isKindOfClass:[NSNumber class]])
            {
              [xmlPerson addChild:[NSXMLNode elementWithName:property
                                             children:[NSArray arrayWithObjects: [NSXMLNode textWithStringValue:[value stringValue]], nil]
                                             attributes:[NSArray arrayWithObjects: [NSXMLNode attributeWithName:@"type"
                                                                                              stringValue:@"number"], nil]]];
            }
          // date components // OS X 10.7+ only
          //else if ([value isKindOfClass:[NSDateComponents class]])
          //  {
          //  }
        }
    }
  return xmlPerson;
}

NSXMLDocument* absyncAddressBookBuildXml(ABAddressBook *abook)
{
  // sort the address book entries
  NSArray *people = [[abook people] sortedArrayUsingFunction:absyncAbPersonSort context:NULL];
  NSXMLElement *root = (NSXMLElement*)[NSXMLNode elementWithName:@"AddressBook"];
  for (ABPerson* person in people)
    {
      [root addChild:absyncAbPersonBuildXml(person, [abook me] == person)];
    }
  NSXMLDocument *xmlDoc = [[NSXMLDocument alloc] initWithRootElement:root];
  [xmlDoc setVersion:@"1.0"];
  [xmlDoc setCharacterEncoding:@"UTF-8"];
  return [xmlDoc autorelease];
}

void printHelp()
{
  printf("absync - Mac OS X Adddress Book Synchronization\n");
  printf("(c) 2012 Will Roberts\n");
  printf("\n");
  printf("This is a utility to export the Mac OS X Adddress Book as an XML file,\n");
  printf("or to read an XML file in, modifying the Address Book.\n");
  printf("\n");
  printf("Syntax:\n");
  printf("\n");
  printf("   absync -w OUTFILE.XML\n");
  printf("   absync [--no-update] [--no-delete] -r INFILE.XML\n");
  printf("   absync --replace INFILE.XML\n");
  printf("   absync --delete\n");
  printf("\n");
  printf("absync -w dumps the Address Book to the named file (or standard output\n");
  printf("if filename is \"-\").\n");
  printf("\n");
  printf("absync -r reads an XML file (or standard input if filename is \"-\"),\n");
  printf("creating, modifying, and deleting entries in the Address Book to\n");
  printf("mirror the data read.  If --no-update is specified, the tool will not\n");
  printf("modify any entries.  If --no-delete is specified, the tool will not\n");
  printf("delete any entries.\n");
  printf("\n");
  printf("absync --replace deletes the local address book and replaces its\n");
  printf("contents with the entries loaded from the given XML file.  USE WITH\n");
  printf("CAUTION.\n");
  printf("\n");
  printf("absync --delete deletes the local address book.  USE WITH CAUTION.\n");
  printf("\n");
}

ABAddressBook* absyncGetAddressBook()
{
  ABAddressBook *abook = [ABAddressBook addressBook];
  [abook retain];
  return abook;
}

void absyncWriteAddressBook(NSString *filename)
{
  ABAddressBook *abook = absyncGetAddressBook();
  NSXMLDocument *xmlDoc = absyncAddressBookBuildXml(abook);
  NSData *data = [xmlDoc XMLDataWithOptions:NSXMLNodePrettyPrint];
  if ([filename isEqualToString:@"-"])
    {
      // print to standard output
      NSString *output = [[NSString alloc] initWithBytes:[data bytes]
                                           length:[data length]
                                           encoding:NSUTF8StringEncoding];
      printf("%s", [output UTF8String]);
      printf("\n");
    }
  else
    {
      // write to file
      BOOL success = YES;
      NSError *errorPtr = nil;
      success = [data writeToFile:filename
                      options:0
                      error:&errorPtr];
      if (!success)
        {
          printf("%s", [[NSString stringWithFormat:@"ERROR: could not write to file \"%@\"\n", filename] UTF8String]);
        }
    }
  [abook release];
}

void absyncDeleteAddressBook()
{
  ABAddressBook *abook = absyncGetAddressBook();

  // delete all groups
  for (ABGroup *group in [abook groups])
    {
      [abook removeRecord:group];
    }

  // delete all persons
  for (ABPerson *person in [abook people])
    {
      [abook removeRecord:person];
    }

  [abook save];

  [abook release];
}

NSXMLDocument* absyncLoadXml(NSString *filename)
{
  NSXMLDocument *xmlDoc = nil;
  NSError *err = nil;
  NSURL *fileUrl = [NSURL fileURLWithPath:filename];
  if (!fileUrl)
    {
      printf("%s", [[NSString stringWithFormat:@"ERROR: Can't create an URL from file %@", filename] UTF8String]);
      return nil;
    }
  xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:fileUrl
                                  options:0
                                  error:&err];
  if (xmlDoc == nil)
    {
      xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:fileUrl
                                      options:NSXMLDocumentTidyXML
                                      error:&err];
    }
  if (xmlDoc == nil)
    {
      if (err) {
        /*handle error*/
      }
      return nil;
    }

  if (err)
    {
      /*handle error*/
      return nil;
    }
  return xmlDoc;
}

enum {
  RUN_MODE_INVALID = 0,

  RUN_MODE_READ = 1,
  RUN_MODE_WRITE,

  RUN_MODE_REPLACE = 254,
  RUN_MODE_DELETE
};

int main (int argc, const char * argv[])
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  int c;
  int mode = RUN_MODE_INVALID;
  // flags for the read-function
  int update_flag = 1;
  int delete_flag = 1;

  while (1)
    {
      const struct option long_options[] =
        {
          /* These options set a flag. */
          {"no-update", no_argument, &update_flag, 0},
          {"no-delete", no_argument, &delete_flag, 0},
          /* These options don't set a flag.
             We distinguish them by their indices. */
          {"write" ,    no_argument, 0, 'w'},
          {"read",      no_argument, 0, 'r'},
          {"replace",   no_argument, 0, RUN_MODE_REPLACE},
          {"delete",    no_argument, 0, RUN_MODE_DELETE},
          {"help",      no_argument, 0, 'h'},
          {0, 0, 0, 0}
        };
      /* getopt_long stores the option index here. */
      int option_index = 0;

      c = getopt_long (argc, (char * const *)argv,
					   "rwh", long_options, &option_index);

      /* Detect the end of the options. */
      if (c == -1)
        break;

      switch (c)
        {
        case 0:
          /* If this option set a flag, do nothing else now. */
          break;
        case 'r':
          if (mode != RUN_MODE_INVALID)
            {
              printf("ERROR: Cannot specify both -r and -w\n");
              printHelp();
              [pool release];
              exit(1);
            }
          mode = RUN_MODE_READ;
          break;
        case 'w':
          if (mode != RUN_MODE_INVALID)
            {
              printf("ERROR: Cannot specify both -r and -w\n");
              printHelp();
              [pool release];
              exit(1);
            }
          mode = RUN_MODE_WRITE;
          break;
        case RUN_MODE_REPLACE:
        case RUN_MODE_DELETE:
          if (mode != RUN_MODE_INVALID)
            {
              printf("ERROR: Cannot specify multiple run modes\n");
              printHelp();
              [pool release];
              exit(1);
            }
          mode = c;
          break;
        case 'h':
        case '?':
        default:
          printHelp();
          [pool release];
          exit(0);
        }
    } // end while(1)

  if (mode == RUN_MODE_INVALID)
    {
      printf("ERROR: Must specify either read or write mode\n");
      printHelp();
      [pool release];
      exit(1);
    }

  NSString *filename = [NSString string];
  if (mode != RUN_MODE_DELETE)
    {
      if (argc <= optind)
        {
          printf("ERROR: Must specify an xml filename\n");
          printHelp();
          [pool release];
          exit(1);
        }
      else
        {
          filename = [NSString stringWithUTF8String:argv[optind]];
        }
    }

  switch (mode)
    {
    case RUN_MODE_READ:
      printf("ERROR: Function read not yet implemented\n");
      [pool release];
      exit(1);
      break;
    case RUN_MODE_WRITE:
      absyncWriteAddressBook(filename);
      break;
    case RUN_MODE_REPLACE:
      printf("ERROR: Function replace not yet implemented\n");
      [pool release];
      exit(1);
      break;
    case RUN_MODE_DELETE:
      absyncDeleteAddressBook();
      break;
    default:
      printf("ERROR: Invalid run mode\n");
      [pool release];
      exit(1);
    }

  [pool release];

  return 0;
}
