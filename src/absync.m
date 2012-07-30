#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>
#include <getopt.h>

BOOL absyncAbPersonIsCompany(ABPerson *person)
{
  if ([[person valueForProperty:kABPersonFlags] integerValue] & kABShowAsCompany)
	return YES;
  return NO;
}

BOOL absyncXmlPersonIsCompany(NSXMLElement *xmlPerson)
{
  NSError *err = nil;
  NSArray *nodes = [xmlPerson nodesForXPath:[NSString stringWithFormat:@"./%@", kABPersonFlags]
							  error:&err];
  if (nodes &&
      [nodes count] &&
      ([[[nodes objectAtIndex:[nodes count]-1] stringValue] integerValue] & kABShowAsCompany))
	return YES;
  return NO;
}

NSString* absyncAbPersonFullName(ABPerson *person)
{
  NSString *name = [NSString string];
  if (absyncAbPersonIsCompany(person))
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

NSString* absyncXmlPersonFullName(NSXMLElement *xmlPerson)
{
  NSString *name = [NSString string];
  NSArray *nodes = nil;
  NSError *err = nil;
  if (absyncXmlPersonIsCompany(xmlPerson))
    {
      if ((nodes = [xmlPerson nodesForXPath:[NSString stringWithFormat:@"./%@", kABOrganizationProperty]
                              error:&err]) && [nodes count])
        {
          name = [name stringByAppendingString:[[nodes objectAtIndex:[nodes count]-1] stringValue]];
        }
    }
  else
    {
      if ((nodes = [xmlPerson nodesForXPath:[NSString stringWithFormat:@"./%@", kABLastNameProperty]
                              error:&err]) && [nodes count])
        {
          name = [name stringByAppendingString:[[nodes objectAtIndex:[nodes count]-1] stringValue]];
          name = [name stringByAppendingString:@", "];
        }
      if ((nodes = [xmlPerson nodesForXPath:[NSString stringWithFormat:@"./%@", kABTitleProperty]
                              error:&err]) && [nodes count])
        {
          name = [name stringByAppendingString:[[nodes objectAtIndex:[nodes count]-1] stringValue]];
          name = [name stringByAppendingString:@" "];
        }
      if ((nodes = [xmlPerson nodesForXPath:[NSString stringWithFormat:@"./%@", kABFirstNameProperty]
                              error:&err]) && [nodes count])
        {
          name = [name stringByAppendingString:[[nodes objectAtIndex:[nodes count]-1] stringValue]];
        }
      if ((nodes = [xmlPerson nodesForXPath:[NSString stringWithFormat:@"./%@", kABMiddleNameProperty]
                              error:&err]) && [nodes count])
        {
          name = [name stringByAppendingString:@" "];
          name = [name stringByAppendingString:[[nodes objectAtIndex:[nodes count]-1] stringValue]];
        }
    }
  return name;
}

NSInteger absyncAbPersonSort(ABPerson *person1, ABPerson *person2, void *context)
{
  return [absyncAbPersonFullName(person1) compare:absyncAbPersonFullName(person2)];
}

static NSDateFormatter* CACHE_ABSYNCISODATEFORMATTER = nil;
NSDateFormatter* absyncIsoDateFormatter()
{
  if (!CACHE_ABSYNCISODATEFORMATTER)
    {
      CACHE_ABSYNCISODATEFORMATTER = [[NSDateFormatter alloc]
                                       initWithDateFormat:@"%Y-%m-%d"
                                       allowNaturalLanguage:NO];
    }
  return CACHE_ABSYNCISODATEFORMATTER;
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

static NSArray* CACHE_ABSYNCABPERSONRELEVANTPROPERTIES = nil;
NSArray* absyncAbPersonRelevantProperties()
{
  if (!CACHE_ABSYNCABPERSONRELEVANTPROPERTIES)
    {
      CACHE_ABSYNCABPERSONRELEVANTPROPERTIES = [NSArray arrayWithObjects:
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
      [CACHE_ABSYNCABPERSONRELEVANTPROPERTIES retain];
    }
  return CACHE_ABSYNCABPERSONRELEVANTPROPERTIES;
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
              // NYI: store identifiers (UUIDs), primaryIdentifier?
              NSMutableArray *sortedKeys = [NSMutableArray arrayWithCapacity:0];
              int i = 0;
              for (; i < [value count]; i++)
                {
                  [sortedKeys addObject:[MultiStringItem itemWithKey:[value labelAtIndex:i] index:i]];
                }
              [sortedKeys sortUsingSelector:@selector(compare:)];

              // multistring
              if ([value propertyType] == kABMultiStringProperty)
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
              else if ([value propertyType] == kABMultiDateProperty)
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
              else if ([value propertyType] == kABMultiDictionaryProperty)
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
      printf("%s\n", [output UTF8String]);
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
          printf("%s\n", [[NSString stringWithFormat:@"ERROR: could not write to file \"%@\"", filename] UTF8String]);
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

@interface PersonPropertyMatch : NSObject
{
  // Instance variable declarations
  NSString *property;
  NSString *value;
  NSInteger weighting;
}
// Method and property declarations
- (id)initWithProperty:(NSString*)n value:(NSString*)v weighting:(NSInteger)w;
- (NSInteger)scoreAbPerson:(ABPerson*)abPerson;
- (NSInteger)scoreXmlPerson:(NSXMLElement*)xmlPerson;
@end

@implementation PersonPropertyMatch
- (id)initWithProperty:(NSString*)n
                 value:(NSString*)v
             weighting:(NSInteger)w
{
  self = [super init];
  if (self) {
    property = [n retain];
    value = [v retain];
    weighting = w;
  }
  return self;
}
- (void)dealloc
{
  [property release];
  [value release];
  [super dealloc];
}
- (NSString *)description
{
  return [NSString stringWithFormat:@"<PersonPropertyMatch property=\"%@\" value=\"%@\" weighting=%d>", property, value, weighting];
}
- (NSInteger)scoreAbPerson:(ABPerson*)abPerson
{
  if ([[abPerson valueForProperty:property] isEqualToString:value])
    return weighting;
  else
    return 0;
}
- (NSInteger)scoreXmlPerson:(NSXMLElement*)xmlPerson
{
  NSArray *nodes = nil;
  NSError *err = nil;
  nodes = [xmlPerson nodesForXPath:[NSString stringWithFormat:@"./%@", property]
                     error:&err];
  if (nodes && [nodes count] && [[[nodes objectAtIndex:[nodes count]-1] stringValue] isEqualToString:value])
    return weighting;
  else
    return 0;
}
@end

static NSDictionary *CACHE_ABSYNCPERSONPROPERTYWEIGHTING = nil;
static const NSInteger PERSON_MATCHING_SCORE_THRESHOLD = 3;
NSDictionary *absyncPersonPropertyWeighting()
{
  if (!CACHE_ABSYNCPERSONPROPERTYWEIGHTING)
    {
      CACHE_ABSYNCPERSONPROPERTYWEIGHTING = [NSDictionary dictionaryWithObjectsAndKeys:
                                                            [NSNumber numberWithInteger:2], kABFirstNameProperty,
                                                          [NSNumber numberWithInteger:1], kABMiddleNameProperty,
                                                          [NSNumber numberWithInteger:3], kABLastNameProperty,
                                                          [NSNumber numberWithInteger:4],  kABOrganizationProperty, nil];
      [CACHE_ABSYNCPERSONPROPERTYWEIGHTING retain];
    }
  return CACHE_ABSYNCPERSONPROPERTYWEIGHTING;
}

ABPerson* absyncFindMatchingAbPerson(NSXMLElement *xmlPerson, ABAddressBook *abook)
{
  NSDictionary *propertyWeighting = absyncPersonPropertyWeighting();
  NSMutableDictionary *props = [NSMutableDictionary dictionaryWithCapacity:0];
  for (NSXMLElement *child in [xmlPerson children])
    {
      if ([propertyWeighting objectForKey:[child name]])
        {
		  if ([[child name] isEqualToString:kABOrganizationProperty] && !absyncXmlPersonIsCompany(xmlPerson))
			continue;
          [props setObject:[[PersonPropertyMatch alloc] initWithProperty:[child name]
                                                        value:[child stringValue]
                                                        weighting:[[propertyWeighting objectForKey:[child name]] integerValue]]
                 forKey:[child name]];
        }
    }

  NSInteger bestScore = PERSON_MATCHING_SCORE_THRESHOLD;
  ABPerson *bestCandidate = nil;
  for (ABPerson *abPerson in [abook people])
    {
      NSInteger score = 0;
      for (PersonPropertyMatch *properties in [props allValues])
        {
          score += [properties scoreAbPerson:abPerson];
        }
      if (bestScore < score)
        {
          bestScore = score;
          bestCandidate = abPerson;
        }
    }

  return bestCandidate;
}

NSXMLElement* absyncFindMatchingXmlPerson(ABPerson *abPerson, NSArray *xmlPeople)
{
  NSDictionary *propertyWeighting = absyncPersonPropertyWeighting();
  NSMutableDictionary *props = [NSMutableDictionary dictionaryWithCapacity:0];
  for (NSString *propName in [propertyWeighting allKeys])
    {
      if ([abPerson valueForProperty:propName])
        {
		  if ([propName isEqualToString:kABOrganizationProperty] && !absyncAbPersonIsCompany(abPerson))
			continue;
          [props setObject:[[PersonPropertyMatch alloc] initWithProperty:propName
                                                        value:[abPerson valueForProperty:propName]
                                                        weighting:[[propertyWeighting objectForKey:propName] integerValue]]
                 forKey:propName];
        }
    }

  NSInteger bestScore = PERSON_MATCHING_SCORE_THRESHOLD;
  NSXMLElement *bestCandidate = nil;
  for (NSXMLElement *xmlPerson in xmlPeople)
    {
      NSInteger score = 0;
      for (PersonPropertyMatch *properties in [props allValues])
        {
          score += [properties scoreXmlPerson:xmlPerson];
        }
      if (bestScore < score)
        {
          bestScore = score;
          bestCandidate = xmlPerson;
        }
    }

  return bestCandidate;
}

ABGroup* absyncFindMatchingAbGroup(NSString *groupName, ABAddressBook *abook)
{
  for (ABGroup *group in [abook groups])
    {
      if ([[group valueForProperty:kABGroupNameProperty] isEqualToString:groupName])
        {
          return group;
        }
    }
  return nil;
}

NSXMLDocument* absyncLoadXml(NSString *filename)
{
  NSXMLDocument *xmlDoc = nil;
  NSError *err = nil;
  // NYI: handle "-" for stdin
  NSURL *fileUrl = [NSURL fileURLWithPath:filename];
  if (!fileUrl)
    {
      printf("%s\n", [[NSString stringWithFormat:@"ERROR: Can't create an URL from file %@", filename] UTF8String]);
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

// read all groups out of xml document
NSSet* absyncGetXmlGroupSet(NSXMLDocument *xmldoc)
{
  // returns an arrays of NSXMLElement objects
  NSError *err = nil;
  NSArray *groups = [xmldoc nodesForXPath:@"//Group" error:&err];

  // put groups into a MutableSet object
  NSMutableSet *groupSet = [NSMutableSet setWithCapacity:0];
  for (NSXMLElement *group in groups)
    {
      [groupSet addObject:[group stringValue]];
    }
  return groupSet;
}

// create new group
void absyncCreateNewAbGroup(NSString *groupName, ABAddressBook *abook)
{
  ABGroup *group = [[ABGroup alloc] initWithAddressBook:abook];
  [group setValue:groupName forProperty:kABGroupNameProperty];
  [abook save];
}

// modifies the local address book groups to match the structure given
// in the XML document
void absyncInjectXmlGroups(NSXMLDocument *xmldoc, ABAddressBook *abook,
                           BOOL update_flag, BOOL delete_flag)
{
  NSSet *groupSet = absyncGetXmlGroupSet(xmldoc);
  for (NSString *groupName in groupSet)
    {
      if (!absyncFindMatchingAbGroup(groupName, abook))
        {
          // create new group
          printf("%s\n", [[NSString stringWithFormat:@"Creating group %@", groupName] UTF8String]);
          absyncCreateNewAbGroup(groupName, abook);
        }
    }
  if (delete_flag)
    {
      // find all groups in address book
      for (ABGroup *group in [abook groups])
        {
          // if group is not in xml document
          if (![groupSet member:[group name]])
            {
              // delete it from the address book
              printf("%s\n", [[NSString stringWithFormat:@"Deleting group %@", [group name]] UTF8String]);
              // NOTE: we do not have to remove people from a group
              // before deleting it
              [abook removeRecord:group];
              [abook save];
            }
        }
    }
}

// find all person records in the given XML document
NSArray* absyncGetXmlPeople(NSXMLDocument *xmldoc)
{
  NSError *err = nil;
  return [xmldoc nodesForXPath:@"/AddressBook/Person" error:&err];
}

// test whether there is an entry in multiValue2 which matches the
// entry in multiValue1 at idx.
BOOL absyncMultiValueMatch(ABMultiValue *multiValue1, NSInteger idx, ABMultiValue *multiValue2)
{
  int idx2 = 0;
  for (; idx2 < [multiValue2 count]; idx2++)
    {
      if ([[multiValue1 labelAtIndex:idx] isEqual:[multiValue2 labelAtIndex:idx2]] &&
          [[multiValue1 valueAtIndex:idx] isEqual:[multiValue2 valueAtIndex:idx2]])
        {
          return YES;
        }
    }
  return NO;
}

ABMutableMultiValue* absyncMakeMutableCopyOfMultiValue(ABMultiValue *multivalue)
{
  ABMutableMultiValue *copy = [[ABMutableMultiValue alloc] init];
  if (multivalue)
    {
      int idx = 0;
      for (; idx < [multivalue count]; idx++)
        {
          [copy insertValue:[multivalue valueAtIndex:idx]
                withLabel:[multivalue labelAtIndex:idx]
                atIndex:idx];
        }
    }
  [copy autorelease];
  return copy;
}

NSSet* absyncGetXmlGroups(NSXMLElement *xmlPerson)
{
  NSError *err = nil;
  NSMutableSet *retVal = [NSMutableSet setWithCapacity:0];
  for (NSXMLElement *xmlGroup in [xmlPerson nodesForXPath:@"./Groups/Group/text()" error:&err])
    {
      [retVal addObject:[xmlGroup stringValue]];
    }
  return retVal;
}

void absyncInjectXmlPerson(NSXMLElement *xmlPerson, ABPerson *abPerson, ABAddressBook *abook, BOOL update_flag, BOOL delete_flag)
{
  // inject properties
  NSArray *relevantProperties = absyncAbPersonRelevantProperties();
  NSMutableArray *properties = [NSMutableArray arrayWithCapacity:0];
  for (NSXMLElement *child in [xmlPerson children])
    {
      if ([relevantProperties containsObject:[child name]])
        {
          [properties addObject:child];
        }
    }
  // set relevant properties
  for (NSXMLElement *prop in properties)
    {
      NSString *propName = [prop name];
      NSString *propType = [[prop attributeForName:@"type"] stringValue];
      ABMutableMultiValue *multiValue = nil;
      NSString *multiType = nil;
      if ([propType isEqualToString:@"string"])
        {
          [abPerson setValue:[prop stringValue] forProperty:propName];
        }
      else if ([propType isEqualToString:@"date"])
        {
          [abPerson setValue:[absyncIsoDateFormatter() dateFromString:[prop stringValue]] forProperty:propName];
        }
      else if ([propType isEqualToString:@"number"])
        {
          [abPerson setValue:[NSNumber numberWithInteger:[[prop stringValue] integerValue]] forProperty:propName];
        }
      else if ([propType isEqualToString:@"multistring"] || [propType isEqualToString:@"multidict"] || [propType isEqualToString:@"multidate"])
        {
          multiType = propType;
          multiValue = [[ABMutableMultiValue alloc] init];
          for (NSXMLElement *child in [prop children])
            {
              if (![[child name] isEqualToString:@"item"] ||
                  [[child children] count] != 2 ||
                  ![[[[child children] objectAtIndex:0] name] isEqualToString:@"key"] ||
                  ![[[[child children] objectAtIndex:1] name] isEqualToString:@"value"])
                {
                  continue;
                }
              [multiValue addValue:[[[child children] objectAtIndex:1] XMLString]
                          withLabel:[[[child children] objectAtIndex:0] stringValue]];
            }
        }
      if (!multiValue)
        {
          continue;
        }
      // convert multiValue to have values of the right type
      // NOTE: contrary to the Apple Docs, there does not seem to be a
      // problem with a ABMutableMultiValue having values of different
      // types
      if ([multiType isEqualToString:@"multistring"])
        {
          int idx = 0;
          for (; idx < [multiValue count]; idx++)
            {
              NSError *err = nil;
              NSXMLElement *value = [[NSXMLElement alloc] initWithXMLString:[multiValue valueAtIndex:idx] error:&err];
              [multiValue replaceValueAtIndex:idx withValue:[value stringValue]];
              [value release];
            }
        }
      else if ([multiType isEqualToString:@"multidict"])
        {
          // iterate backwards
          int idx = [multiValue count] - 1;
          for (; 0 <= idx; idx--)
            {
              NSError *err = nil;
              NSXMLElement *value = [[NSXMLElement alloc] initWithXMLString:[multiValue valueAtIndex:idx] error:&err];
              if ([[value children] count] != 1 ||
                  ![[[[value children] objectAtIndex:0] name] isEqualToString:@"Dict"])
                {
                  [multiValue removeValueAndLabelAtIndex:idx];
                  continue;
                }
              NSMutableDictionary *nsdict = [NSMutableDictionary dictionaryWithCapacity:0];
              for (NSXMLElement *dictitem in [[[value children] objectAtIndex:0] children])
                {
                  if (![[dictitem name] isEqualToString:@"DictItem"] ||
                      [[dictitem children] count] != 2 ||
                      ![[[[dictitem children] objectAtIndex:0] name] isEqualToString:@"key"] ||
                      ![[[[dictitem children] objectAtIndex:1] name] isEqualToString:@"value"])
                    {
                      continue;
                    }
                  [nsdict setObject:[[[dictitem children] objectAtIndex:1] stringValue]
                          forKey:[[[dictitem children] objectAtIndex:0] stringValue]];
                }
              [multiValue replaceValueAtIndex:idx withValue:nsdict];
              [value release];
            }
        }
      else if ([multiType isEqualToString:@"multidate"])
        {
          int idx = 0;
          for (; idx < [multiValue count]; idx++)
            {
              NSError *err = nil;
              NSXMLElement *value = [[NSXMLElement alloc] initWithXMLString:[multiValue valueAtIndex:idx] error:&err];
              [multiValue replaceValueAtIndex:idx withValue:[absyncIsoDateFormatter() dateFromString:[value stringValue]]];
              [value release];
            }
        }
      // now do something with the multivalue
      ABMutableMultiValue *abPersonMV = absyncMakeMutableCopyOfMultiValue([abPerson valueForProperty:propName]);
      int idx = 0;
      for (; idx < [multiValue count]; idx++)
        {
          if (!absyncMultiValueMatch(multiValue, idx, abPersonMV))
            {
              // add the multivalue
              [abPersonMV addValue:[multiValue valueAtIndex:idx]
                          withLabel:[multiValue labelAtIndex:idx]];
            }
        }
      // iterate backwards
      for (int idx = [abPersonMV count] - 1; 0 <= idx; idx--)
        {
          if (!absyncMultiValueMatch(abPersonMV, idx, multiValue))
            {
              // remove the multivalue
              [abPersonMV removeValueAndLabelAtIndex:idx];
            }
        }
      // NYI: store identifiers (UUIDs), primaryIdentifier?
    }
  // remove irrelevant properties
  if (delete_flag)
    {
      NSMutableSet *xmlPropertySet = [NSMutableSet setWithCapacity:0];
      for (NSXMLElement *prop in properties)
        {
          [xmlPropertySet addObject:[prop name]];
        }
      for (NSString *propName in relevantProperties)
        {
          if ([abPerson valueForProperty:propName] && ![xmlPropertySet member:propName])
            {
              [abPerson removeValueForProperty:propName];
            }
        }
    }
}

void absyncInjectXmlPersonGroups(NSXMLElement *xmlPerson, ABPerson *abPerson, ABAddressBook *abook, BOOL update_flag, BOOL delete_flag)
{
  // inject groups
  NSSet *xmlGroups = absyncGetXmlGroups(xmlPerson);
  for (NSString *groupName in xmlGroups)
    {
      ABGroup *group = absyncFindMatchingAbGroup(groupName, abook);
      if (group)
        {
          [group addMember:abPerson];
          //[abook save];
        }
    }
  if (delete_flag)
    {
      for (ABGroup *group in [abPerson parentGroups])
        {
          if (![xmlGroups member:[group valueForProperty:kABGroupNameProperty]])
            {
              [group removeMember:abPerson];
              [abook save];
            }
        }
    }
}

void absyncInjectXmlPeople(NSXMLDocument *xmldoc, ABAddressBook *abook, BOOL update_flag, BOOL delete_flag)
{
  NSArray *xmlPeople = absyncGetXmlPeople(xmldoc);
  // for each person in the XML document
  for (NSXMLElement *xmlPerson in xmlPeople)
    {
      ABPerson *abPerson = absyncFindMatchingAbPerson(xmlPerson, abook);
      // if the person is found
      if (abPerson)
        {
          if (update_flag)
            {
              // update the person
              printf("%s\n", [[NSString stringWithFormat:@"Updating person %@ with %@", absyncAbPersonFullName(abPerson),
                                        absyncXmlPersonFullName(xmlPerson)] UTF8String]);
            }
          else
            {
              // don't update the person
              abPerson = nil;
            }
        }
      else
        {
          // create a new person entry
          printf("%s\n", [[NSString stringWithFormat:@"Creating person %@", absyncXmlPersonFullName(xmlPerson)] UTF8String]);
          abPerson = [[ABPerson alloc] initWithAddressBook:abook];
        }
      if (abPerson)
        {
          // inject person properties into the person entry
          absyncInjectXmlPerson(xmlPerson, abPerson, abook, update_flag, delete_flag);
          [abook save];
          // inject person groups into the person entry
          absyncInjectXmlPersonGroups(xmlPerson, abPerson, abook, update_flag, delete_flag);
          [abook save];
        }
    }
  if (delete_flag)
    {
      // for person in address book
      for (ABPerson *abPerson in [abook people])
        {
          // if the person is not found in the XML doc
          if (!absyncFindMatchingXmlPerson(abPerson, xmlPeople))
            {
              // delete the person
              printf("%s\n", [[NSString stringWithFormat:@"Deleting person %@", absyncAbPersonFullName(abPerson)] UTF8String]);
              [abook removeRecord:abPerson];
              [abook save];
            }
        }
    }
}

void absyncReadAddressBook(NSString *filename, BOOL update_flag, BOOL delete_flag)
{
  ABAddressBook *abook = absyncGetAddressBook();
  NSXMLDocument *xmlDoc = absyncLoadXml(filename);
  if (!xmlDoc)
    {
      printf("ERROR: Could not load address book XML data\n");
      [abook release];
      return;
    }
  // synchronize group information
  absyncInjectXmlGroups(xmlDoc, abook, update_flag, delete_flag);
  // synchronize person information
  absyncInjectXmlPeople(xmlDoc, abook, update_flag, delete_flag);

  [xmlDoc release];
  [abook release];
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
      absyncReadAddressBook(filename, update_flag, delete_flag);
      break;
    case RUN_MODE_WRITE:
      absyncWriteAddressBook(filename);
      break;
    case RUN_MODE_REPLACE:
      absyncDeleteAddressBook();
      absyncReadAddressBook(filename, update_flag, delete_flag);
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
