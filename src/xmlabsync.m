/**
 * xmlabsync
 * Mac OS X Address Book Synchronization
 *
 * Copyright (C) 2012 Will Roberts <wildwilhelm@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>
#include <getopt.h>
#include "xmlabsyncconfig.h"
#include "google/GTMStringEncoding.h"


// ======================================================================
//  STATIC FACTORY METHODS
// ======================================================================

static NSDateFormatter* CACHE_XMLABSYNCISODATEFORMATTER = nil;

/**
 * Returns a standard NSDateFormatter object that formats dates into
 * ISO format (YYYY-MM-DD).
 *
 * \return A NSDateFormatter object for reading and writing the ISO
 * date format.
 */
NSDateFormatter*
xmlabsyncIsoDateFormatter()
{
  if (!CACHE_XMLABSYNCISODATEFORMATTER)
    {
      CACHE_XMLABSYNCISODATEFORMATTER = [[NSDateFormatter alloc]
                                          initWithDateFormat:@"%Y-%m-%d"
                                          allowNaturalLanguage:NO];
    }
  return CACHE_XMLABSYNCISODATEFORMATTER;
}

static NSArray* CACHE_XMLABSYNCABPERSONRELEVANTPROPERTIES = nil;

/**
 * Returns an array with a list of person record properties which are
 * relevant for reading and writing to XML file.
 *
 * \return A NSArray* of relevant property names.
 */
NSArray*
xmlabsyncAbPersonRelevantProperties()
{
  if (!CACHE_XMLABSYNCABPERSONRELEVANTPROPERTIES)
    {
      CACHE_XMLABSYNCABPERSONRELEVANTPROPERTIES = [NSArray arrayWithObjects:
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
      [CACHE_XMLABSYNCABPERSONRELEVANTPROPERTIES retain];
    }
  return CACHE_XMLABSYNCABPERSONRELEVANTPROPERTIES;
}

static NSDictionary *CACHE_XMLABSYNCPERSONPROPERTYWEIGHTING = nil;
static const NSInteger PERSON_MATCHING_SCORE_THRESHOLD = 4;

/**
 * Returns a dictionary which maps person properties to their
 * corresponding person matching scores.
 *
 * \return An NSDictionary object with property names mapping to
 * scores.
 */
NSDictionary*
xmlabsyncPersonPropertyWeighting()
{
  if (!CACHE_XMLABSYNCPERSONPROPERTYWEIGHTING)
    {
      CACHE_XMLABSYNCPERSONPROPERTYWEIGHTING = [NSDictionary dictionaryWithObjectsAndKeys:
                                                               [NSNumber numberWithInteger:2], kABFirstNameProperty,
                                                             [NSNumber numberWithInteger:1], kABMiddleNameProperty,
                                                             [NSNumber numberWithInteger:3], kABLastNameProperty,
                                                             [NSNumber numberWithInteger:5],  kABOrganizationProperty, nil];
      [CACHE_XMLABSYNCPERSONPROPERTYWEIGHTING retain];
    }
  return CACHE_XMLABSYNCPERSONPROPERTYWEIGHTING;
}


// ======================================================================
//  MULTIVALUE STRUCTURE ENTRIES
// ======================================================================

/**
 * An Objective-C object representing an entry in an Address Book
 * MultiValue structure.
 *
 * These entries have both a NSString label and an index (since there
 * may be multiple entries with the same label).
 */
@interface MultiValueEntry : NSObject
{
  NSString *label;
  int       index;
}
- (id)initWithLabel:(NSString*)l index:(int)i;
+ (MultiValueEntry*)entryWithLabel:(NSString*)l index:(int)i;
@property (retain) NSString* label;
@property          int       index;
@end

@implementation MultiValueEntry
@synthesize label;
@synthesize index;

/**
 * Initializer.
 *
 * \param l the label to store
 * \param i the index to store
 * \return Self.
 */
- (id)initWithLabel:(NSString*)l
              index:(int)i
{
  self = [super init];
  if (self) {
    label   = [l retain];
    index = i;
  }
  return self;
}

/**
 * Deconstructor.
 */
- (void)dealloc
{
  [label release];
  [super dealloc];
}

/**
 * Returns a new MultiValueEntry with the given label and index values.
 *
 * \param l the label to store
 * \param i the index to store
 * \return Self.
 */
+ (MultiValueEntry*)entryWithLabel:(NSString*)l
                             index:(int)i
{
  MultiValueEntry *entry = [[MultiValueEntry alloc] initWithLabel:l index:i];
  return [entry autorelease];
}

/**
 * A comparator function to sort MultiValueEntry objects
 * alphabetically by label, followed by numerically by index.
 *
 * \param otherObject the other object to compare to this one
 * \return -1 if this object is less than otherObject; +1 if this
 * object is greater; 0 if they are equal.
 */
- (NSComparisonResult)compare:(MultiValueEntry*)otherObject
{
  NSComparisonResult r = [[self label] compare:[otherObject label]];
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


// ======================================================================
//  ADDRESS BOOK PERSON RECORDS
// ======================================================================

/**
 * A category on the ABPerson class to enable some xmlabsync-specific
 * functionality to be associated directly with the class.
 */
@interface ABPerson (xmlabsync)
- (BOOL)isCompany;
- (NSString*)fullName;
- (NSComparisonResult)compare:(ABPerson*)otherPerson;
- (NSXMLElement*)buildXmlIsMe:(BOOL)isMe;
@end

@implementation ABPerson (xmlabsync)
/**
 * Tests whether this address book record represents a company.
 *
 * \return YES if the record is a company; NO otherwise.
 */
- (BOOL)isCompany
{
  if ([[self valueForProperty:kABPersonFlags] integerValue] & kABShowAsCompany)
    return YES;
  return NO;
}

/**
 * Returns the full name of this person record.
 *
 * The format used is "LastName, FirstName MiddleName".
 *
 * \return A NSString* containing the generated full name.
 */
- (NSString*)fullName
{
  NSString *name = [NSString string];
  if ([self isCompany])
    {
      name = [name stringByAppendingString:[self valueForProperty:kABOrganizationProperty]];
    }
  else
    {
      if ([self valueForProperty:kABLastNameProperty])
        {
          name = [name stringByAppendingString:[self valueForProperty:kABLastNameProperty]];
          name = [name stringByAppendingString:@", "];
        }
      if ([self valueForProperty:kABTitleProperty])
        {
          name = [name stringByAppendingString:[self valueForProperty:kABTitleProperty]];
          name = [name stringByAppendingString:@" "];
        }
      if ([self valueForProperty:kABFirstNameProperty])
        {
          name = [name stringByAppendingString:[self valueForProperty:kABFirstNameProperty]];
        }
      if ([self valueForProperty:kABMiddleNameProperty])
        {
          name = [name stringByAppendingString:@" "];
          name = [name stringByAppendingString:[self valueForProperty:kABMiddleNameProperty]];
        }
    }
  return name;
}

/**
 * A comparator function for sorting ABPerson records by name.
 *
 * \param otherPerson the other person record to compare to this one
 * \return -1 if this person is less than the second; +1 if this
 * person is greater than the second, 0 if they are equal.
 */
- (NSComparisonResult)compare:(ABPerson*)otherPerson
{
  return [[self fullName] compare:[otherPerson fullName]];
}

/**
 * Builds an XML element representing this Address Book person record.
 *
 * \param isMe a flag indicating if this person is "Me" in the address book
 * \return An NSXMLElement object representing this person record.
 */
- (NSXMLElement*)buildXmlIsMe:(BOOL)isMe
{
  NSArray      *personProperties  = xmlabsyncAbPersonRelevantProperties();
  NSXMLElement *xmlPerson         = (NSXMLElement*)[NSXMLNode elementWithName:@"Person"];
  // is me?
  if (isMe)
    {
      [xmlPerson addChild:[NSXMLNode elementWithName:@"IsMe" stringValue:@"1"]];
    }
  // image data
  if ([self imageData])
    {
      NSString *base64ImageData = [[GTMStringEncoding rfc4648Base64StringEncoding] encode:[self imageData]];
      [xmlPerson addChild:[NSXMLNode elementWithName:@"ImageData"
                                     children:[NSArray arrayWithObjects: [NSXMLNode textWithStringValue:base64ImageData], nil]
                                     attributes:[NSArray arrayWithObjects: [NSXMLNode attributeWithName:@"type"
                                                                                      stringValue:@"base64"], nil]]];
    }
  // person groups
  NSMutableArray *sortedGroups = [NSMutableArray arrayWithCapacity:0];
  for (ABGroup *group in [self parentGroups])
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
      if ([property isEqualToString:kABPersonFlags] || [self valueForProperty:property])
        {
          id value = [self valueForProperty:property];
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
                                                                 [NSXMLNode textWithStringValue:[xmlabsyncIsoDateFormatter() stringFromDate:value]], nil]
                                             attributes:[NSArray arrayWithObjects:
                                                                   [NSXMLNode attributeWithName:@"type" stringValue:@"date"], nil]]];
            }
          else if ([value isKindOfClass:[ABMultiValue class]])
            {
              // sort entries of the multivalue
              // NYI: store identifiers (UUIDs), primaryIdentifier?
              NSMutableArray *sortedEntries = [NSMutableArray arrayWithCapacity:0];
              int i = 0;
              for (; i < [value count]; i++)
                {
                  [sortedEntries addObject:[MultiValueEntry entryWithLabel:[value labelAtIndex:i] index:i]];
                }
              [sortedEntries sortUsingSelector:@selector(compare:)];

              // multistring
              if ([value propertyType] == kABMultiStringProperty)
                {
                  NSXMLElement *xmlValue = (NSXMLElement*)[NSXMLNode elementWithName:property
                                                                     children:nil
                                                                     attributes:[NSArray arrayWithObjects: [NSXMLNode attributeWithName:@"type"
                                                                                                                      stringValue:@"multistring"], nil]];
                  [xmlPerson addChild:xmlValue];
                  for (MultiValueEntry *entry in sortedEntries)
                    {
                      NSXMLElement *xmlItem =
                        (NSXMLElement*)[NSXMLNode elementWithName:@"item"
                                                  children:[NSArray arrayWithObjects:
                                                                      [NSXMLNode elementWithName:@"key" stringValue:[entry label]],
                                                                    [NSXMLNode elementWithName:@"value" stringValue:[value valueAtIndex:[entry index]]],
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
                  for (MultiValueEntry *entry in sortedEntries)
                    {
                      NSXMLElement *xmlItem =
                        (NSXMLElement*)[NSXMLNode elementWithName:@"item"
                                                  children:[NSArray arrayWithObjects:
                                                                      [NSXMLNode elementWithName:@"key" stringValue:[entry label]],
                                                                    [NSXMLNode elementWithName:@"value" stringValue:
                                                                                 [xmlabsyncIsoDateFormatter() stringFromDate:[value valueAtIndex:[entry index]]]],
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
                  for (MultiValueEntry *entry in sortedEntries)
                    {
                      NSXMLElement *xmlItem = (NSXMLElement*)[NSXMLNode elementWithName:@"item"];
                      [xmlItem addChild:[NSXMLNode elementWithName:@"key" stringValue:[entry label]]];
                      NSDictionary *dict            = [value valueAtIndex:[entry index]];
                      NSArray      *sortedDictKeys  = [[dict allKeys] sortedArrayUsingSelector:@selector(compare:)];
                      NSXMLElement *xmlDict         = (NSXMLElement*)[NSXMLNode elementWithName:@"Dict"];
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
@end

// ======================================================================
//  XML PERSON RECORDS
// ======================================================================

/**
 * An Objective-C object which represents a person record loaded from
 * an XML file.
 *
 * This object exists to cache the XML data so that it does not have
 * to be looked up again every time it is needed.
 */
@interface XmlPersonRecord : NSObject
{
  NSXMLElement        *xmlElement;
  NSMutableDictionary *cachedProperties;
  NSMutableSet        *groups;
  NSMutableArray      *relevantProperties;
}
- (id)initWithXMLElement:(NSXMLElement*)element;
- (NSSet*)getGroups;
- (NSArray*) getProperties:(NSArray*)properties;
- (BOOL)isCompany;
- (NSString*)fullName;
- (NSArray*)getResultsForProperty:(NSString*)propertyName;
- (id)getLastResultForProperty:(NSString*)propertyName;
- (NSString*)getLastStringValueForProperty:(NSString*)propertyName;
@end

@implementation XmlPersonRecord
/**
 * Constructor.
 *
 * \param element the XML element representing a person record
 * \return Self.
 */
- (id)initWithXMLElement:(NSXMLElement*)element
{
  self = [super init];
  if (self)
    {
      xmlElement         = [element retain];
      cachedProperties   = [[NSMutableDictionary alloc] initWithCapacity:0];
      groups             = nil;
      relevantProperties = nil;
    }
  return self;
}

/**
 * Destructor.
 */
- (void)dealloc
{
  [xmlElement release];
  [cachedProperties release];
  [groups release];
  [relevantProperties release];
  [super dealloc];
}

/**
 * Gets all the groups that the given XML file person record belongs
 * to.
 *
 * \return An NSSet object containing the names of all the groups the
 * given person belongs to.
 */
- (NSSet*)getGroups
{
  if (!groups)
    {
      NSError *err = nil;
      groups = [[NSMutableSet alloc] initWithCapacity:0];
      for (NSXMLElement *xmlGroup in [xmlElement nodesForXPath:@"./Groups/Group/text()" error:&err])
        {
          [groups addObject:[xmlGroup stringValue]];
        }
      return groups;
    }
  else
    return groups;
}

/**
 * Gets a list of children of this XmlPersonRecord's XML tag which are
 * named in the passed array object.
 *
 * \param properties an NSArray object containing the names of
 * properties which are of interest
 * \return An NSArray containing NSXMLElement objects found which
 * match the names listed in the passed properties array.
 */
- (NSArray*)getProperties:(NSArray*)properties
{
  if (!relevantProperties)
    {
      relevantProperties = [[NSMutableArray alloc] initWithCapacity:0];
      for (NSXMLElement *child in [xmlElement children])
        {
          if ([properties containsObject:[child name]])
            {
              [relevantProperties addObject:child];
            }
        }
    }
  return relevantProperties;
}

/**
 * Tests whether this XML file person record represents a company.
 *
 * \return YES if this person record is a company; NO otherwise.
 */
- (BOOL)isCompany
{
  if ([self getLastStringValueForProperty:kABPersonFlags] &&
      [[self getLastStringValueForProperty:kABPersonFlags] integerValue] & kABShowAsCompany)
    return YES;
  return NO;
}

/**
 * Returns the full name of this person record.
 *
 * The format used is "LastName, FirstName MiddleName".
 *
 * \return A NSString* containing the generated full name.
 */
- (NSString*)fullName
{
  NSString *name   = [NSString string];
  if ([self isCompany])
    {
      if ([self getLastStringValueForProperty:kABOrganizationProperty])
        {
          name = [name stringByAppendingString:[self getLastStringValueForProperty:kABOrganizationProperty]];
        }
    }
  else
    {
      if ([self getLastStringValueForProperty:kABLastNameProperty])
        {
          name = [name stringByAppendingString:[self getLastStringValueForProperty:kABLastNameProperty]];
          name = [name stringByAppendingString:@", "];
        }
      if ([self getLastStringValueForProperty:kABTitleProperty])
        {
          name = [name stringByAppendingString:[self getLastStringValueForProperty:kABTitleProperty]];
          name = [name stringByAppendingString:@" "];
        }
      if ([self getLastStringValueForProperty:kABFirstNameProperty])
        {
          name = [name stringByAppendingString:[self getLastStringValueForProperty:kABFirstNameProperty]];
        }
      if ([self getLastStringValueForProperty:kABMiddleNameProperty])
        {
          name = [name stringByAppendingString:@" "];
          name = [name stringByAppendingString:[self getLastStringValueForProperty:kABMiddleNameProperty]];
        }
    }
  return name;
}

/**
 * Value accessor.  Caches the result of XML lookups to speed up
 * xmlabsync.
 *
 * \param propertyName the name of the property to access
 * \return An NSArray object containing the result of looking up the
 * property.
 */
- (NSArray*)getResultsForProperty:(NSString*)propertyName
{
  if ([cachedProperties objectForKey:propertyName])
    {
      return [cachedProperties objectForKey:propertyName];
    }
  else
    {
      // NYI PERFORMANCE: xpath queries are awfully expensive, and
      // we're just pulling out lists of child nodes here; this could
      // easily be made faster by iterating through the children of
      // xmlElement.  Profiling says this won't make things much
      // faster tho.
      NSError *err   = nil;
      NSArray *nodes = [xmlElement nodesForXPath:[NSString stringWithFormat:@"./%@", propertyName]
                                   error:&err];
      if (nodes)
        {
          [cachedProperties setObject:nodes forKey:propertyName];
          return nodes;
        }
      else
        {
          return nil;
        }
    }
}

/**
 * Value accessor.  Caches the result of XML lookups to speed up
 * xmlabsync.
 *
 * \param propertyName the name of the property to access
 * \return Returns the last element in the NSArray object containing
 * the result of looking up the property.
 */
- (id)getLastResultForProperty:(NSString*)propertyName
{
  NSArray *nodes = [self getResultsForProperty:propertyName];
  if (nodes && [nodes count])
    {
      return [nodes objectAtIndex:[nodes count]-1];
    }
  return nil;
}

/**
 * Value accessor.  Caches the result of XML lookups to speed up
 * xmlabsync.
 *
 * \param propertyName the name of the property to access
 * \return Returns the string value of the last element in the NSArray
 * object containing the result of looking up the property.
 */
- (NSString*)getLastStringValueForProperty:(NSString*)propertyName
{
  id value = [self getLastResultForProperty:propertyName];
  if (value)
    {
      return [value stringValue];
    }
  return nil;
}
@end


// ======================================================================
//  PERSON MATCHING
// ======================================================================

/**
 * An Objective-C object representing a match on a property of a
 * person record in the Address Book.
 *
 * Some properties are useful for matching up person records (e.g.,
 * first name, last name).  These are stored in this object as
 * property (the name of the property) and value (the value of the
 * property).  Further, this object stores a weighting parameter,
 * indicating how useful a match on the given property is.
 */
@interface PersonPropertyMatch : NSObject
{
  NSString *property;
  NSString *value;
  NSInteger weighting;
}
- (id)initWithProperty:(NSString*)n value:(NSString*)v weighting:(NSInteger)w;
+ (PersonPropertyMatch*)propertyMatchWithProperty:(NSString*)n value:(NSString*)v weighting:(NSInteger)w;
- (NSInteger)scoreAbPerson:(ABPerson*)abPerson;
- (NSInteger)scoreXmlPerson:(XmlPersonRecord*)xmlPerson;
@end

@implementation PersonPropertyMatch
/**
 * Initializer.
 *
 * \param n the name of the property to match
 * \param v the value of the property to match
 * \param w the score for a match on this property
 * \return Self.
 */
- (id)initWithProperty:(NSString*)n
                 value:(NSString*)v
             weighting:(NSInteger)w
{
  self = [super init];
  if (self) {
    property  = [n retain];
    value     = [v retain];
    weighting = w;
  }
  return self;
}

/**
 * Creates a new autoreleased PersonPropertyMatch object with the
 * given parameters.
 *
 * \param n the name of the property to match
 * \param v the value of the property to match
 * \param w the score for a match on this property
 * \return Self.
 */
+ (PersonPropertyMatch*)propertyMatchWithProperty:(NSString*)n
                                            value:(NSString*)v
                                        weighting:(NSInteger)w
{
  PersonPropertyMatch *val = [[PersonPropertyMatch alloc] initWithProperty:n value:v weighting:w];
  [val autorelease];
  return val;
}

/**
 * Deconstructor.
 */
- (void)dealloc
{
  [property release];
  [value release];
  [super dealloc];
}

/**
 * Returns a string description of this object for debugging.
 *
 * \return An NSString object representing this object.
 */
- (NSString *)description
{
  return [NSString stringWithFormat:@"<PersonPropertyMatch property=\"%@\" value=\"%@\" weighting=%d>",
                   property, value, weighting];
}

/**
 * Scores the given Address Book person record for goodness of fit
 * against this property.
 *
 * \param abPerson the person record to score
 * \return An integer representing the given person's score on this
 * property (bigger scores are better).
 */
- (NSInteger)scoreAbPerson:(ABPerson*)abPerson
{
  NSString *abPersonValue = [NSString string];
  if ([abPerson valueForProperty:property])
    {
      abPersonValue = [abPerson valueForProperty:property];
    }
  if ([abPersonValue isEqualToString:value])
    return weighting;
  else
    return 0;
}

/**
 * Scores the given XML file person record for goodness of fit against
 * this property.
 *
 * \param xmlPerson the person record to score
 * \return An integer representing the given person's score on this
 * property (bigger scores are better).
 */
- (NSInteger)scoreXmlPerson:(XmlPersonRecord*)xmlPerson
{
  NSString *xmlPersonValue  = [NSString string];
  if ([xmlPerson getLastStringValueForProperty:property])
    {
      xmlPersonValue = [xmlPerson getLastStringValueForProperty:property];
    }
  if ([xmlPersonValue isEqualToString:value])
    return weighting;
  else
    return 0;
}
@end


// ======================================================================
//  PROGRAM FUNCTIONS
// ======================================================================

/**
 * Builds a complete XML document representing the Address Book.
 *
 * \param abook the Address Book to create the XML for
 * \return An NSXMLDocument representing the passed Address Book object.
 */
NSXMLDocument*
xmlabsyncAddressBookBuildXml ( ABAddressBook *abook )
{
  // sort the address book entries
  NSArray      *people  = [[abook people] sortedArrayUsingSelector:@selector(compare:)];
  NSXMLElement *root    = (NSXMLElement*)[NSXMLNode elementWithName:@"AddressBook"];
  for (ABPerson* person in people)
    {
      [root addChild:[person buildXmlIsMe:[abook me] == person]];
    }
  NSXMLDocument *xmlDoc = [[NSXMLDocument alloc] initWithRootElement:root];
  [xmlDoc setVersion:@"1.0"];
  [xmlDoc setCharacterEncoding:@"UTF-8"];
  return [xmlDoc autorelease];
}

/**
 * Prints the version number for this program to standard output.
 */
void
printVersion()
{
  printf("xmlabsync Version %d.%d\n", xmlabsync_VERSION_MAJOR, xmlabsync_VERSION_MINOR);
}

/**
 * Prints help for this program to standard output.
 */
void
printHelp()
{
  printVersion();
  printf("Mac OS X Address Book Synchronization\n");
  printf("Copyright (c) 2012 Will Roberts\n");
  printf("\n");
  printf("This is a utility to export the Mac OS X Address Book as an XML file,\n");
  printf("or to read an XML file in, modifying the Address Book.\n");
  printf("\n");
  printf("Syntax:\n");
  printf("\n");
  printf("   xmlabsync -w OUTFILE.XML\n");
  printf("   xmlabsync [--no-update] [--no-delete] -r INFILE.XML\n");
  printf("   xmlabsync --replace INFILE.XML\n");
  printf("   xmlabsync --delete\n");
  printf("\n");
  printf("xmlabsync -w dumps the Address Book to the named file (or standard output\n");
  printf("if filename is \"-\").\n");
  printf("\n");
  printf("xmlabsync -r reads an XML file (or standard input if filename is \"-\"),\n");
  printf("creating, modifying, and deleting entries in the Address Book to\n");
  printf("mirror the data read.  If --no-update is specified, the tool will not\n");
  printf("modify any existing entries.  If --no-delete is specified, the tool\n");
  printf("will not delete any existing entries.\n");
  printf("\n");
  printf("xmlabsync --replace deletes the local address book and replaces its\n");
  printf("contents with the entries loaded from the given XML file.  USE WITH\n");
  printf("CAUTION.\n");
  printf("\n");
  printf("xmlabsync --delete deletes the local address book.  USE WITH CAUTION.\n");
  printf("\n");
}

/**
 * Gets the logged in user's Address Book.
 *
 * \return An ABAddressBook object.  Remember to release this when you
 * are done with it.
 */
ABAddressBook*
xmlabsyncGetAddressBook()
{
  ABAddressBook *abook = [ABAddressBook addressBook];
  [abook retain];
  return abook;
}

/**
 * Writes the Address Book in XML format to the given file.
 *
 * \param filename the name of the XML file to write, or "-" to write
 * to standard output.
 */
void
xmlabsyncWriteAddressBook ( NSString *filename )
{
  ABAddressBook *abook   = xmlabsyncGetAddressBook();
  NSXMLDocument *xmlDoc  = xmlabsyncAddressBookBuildXml(abook);
  NSData        *data    = [xmlDoc XMLDataWithOptions:NSXMLNodePrettyPrint];
  if ([filename isEqualToString:@"-"])
    {
      // print to standard output
      NSString *output = [[NSString alloc] initWithBytes:[data bytes]
                                           length:[data length]
                                           encoding:NSUTF8StringEncoding];
      printf("%s\n", [output UTF8String]);
      [output release];
    }
  else
    {
      // write to file
      BOOL     success   = YES;
      NSError *errorPtr  = nil;
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

/**
 * Deletes the contents of the logged in user's Address Book.
 */
void
xmlabsyncDeleteAddressBook()
{
  ABAddressBook *abook = xmlabsyncGetAddressBook();

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

/**
 * Finds the Address Book person record which best matches the given
 * XML file person record.
 *
 * \param xmlPerson the person record to match
 * \param abook the user's address book
 * \return A matching ABPerson object, or nil if no matching record is
 * found.
 */
ABPerson*
xmlabsyncFindMatchingAbPerson ( XmlPersonRecord *xmlPerson,
                                ABAddressBook   *abook )
{
  NSDictionary        *propertyWeighting  = xmlabsyncPersonPropertyWeighting();
  NSMutableDictionary *props              = [NSMutableDictionary dictionaryWithCapacity:0];
  BOOL                 xmlPersonIsCompany = [xmlPerson isCompany];
  for (NSString *propName in [propertyWeighting allKeys])
    {
      if ([propName isEqualToString:kABOrganizationProperty] != xmlPersonIsCompany)
        continue;
      NSString *propValue  = [NSString string];
      if ([xmlPerson getLastStringValueForProperty:propName])
        {
          propValue = [xmlPerson getLastStringValueForProperty:propName];
        }
      [props setObject:[PersonPropertyMatch propertyMatchWithProperty:propName
                                            value:propValue
                                            weighting:[[propertyWeighting objectForKey:propName] integerValue]]
             forKey:propName];
    }

  NSInteger bestScore      = PERSON_MATCHING_SCORE_THRESHOLD;
  ABPerson *bestCandidate  = nil;
  for (ABPerson *abPerson in [abook people])
    {
      if (xmlPersonIsCompany != [abPerson isCompany])
        continue;
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

/**
 * Finds the XML file person record which best matches the given
 * Address Book person record.
 *
 * \param abPerson the person record to match
 * \param xmlPeople an array of XmlPersonRecord objects representing
 * the person records in an XML file
 * \return A matching XmlPersonRecord object, or nil if no matching
 * record is found.
 */
XmlPersonRecord*
xmlabsyncFindMatchingXmlPerson ( ABPerson *abPerson,
                                 NSArray  *xmlPeople )
{
  NSDictionary        *propertyWeighting  = xmlabsyncPersonPropertyWeighting();
  NSMutableDictionary *props              = [NSMutableDictionary dictionaryWithCapacity:0];
  BOOL                 abPersonIsCompany  = [abPerson isCompany];
  for (NSString *propName in [propertyWeighting allKeys])
    {
      if ([propName isEqualToString:kABOrganizationProperty] != abPersonIsCompany)
        continue;
      NSString *propValue = [NSString string];
      if ([abPerson valueForProperty:propName])
        {
          propValue = [abPerson valueForProperty:propName];
        }
      [props setObject:[PersonPropertyMatch propertyMatchWithProperty:propName
                                            value:propValue
                                            weighting:[[propertyWeighting objectForKey:propName] integerValue]]
             forKey:propName];
    }

  NSInteger        bestScore     = PERSON_MATCHING_SCORE_THRESHOLD;
  XmlPersonRecord *bestCandidate = nil;
  for (XmlPersonRecord *xmlPerson in xmlPeople)
    {
      if (abPersonIsCompany != [xmlPerson isCompany])
        continue;
      NSInteger score = 0;
      for (PersonPropertyMatch *properties in [props allValues])
        {
          score += [properties scoreXmlPerson:xmlPerson];
        }
      if (bestScore < score)
        {
          bestScore     = score;
          bestCandidate = xmlPerson;
        }
    }

  return bestCandidate;
}

/**
 * Finds an Address Book group object with the given name.
 *
 * \param groupName the name of the group to find
 * \param abook the user's address book
 * \return An ABGroup object, or nil if no matching group is found.
 */
ABGroup*
xmlabsyncFindMatchingAbGroup ( NSString      *groupName,
                               ABAddressBook *abook )
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

/**
 * Loads an XML document from the given file.
 *
 * \param filename the name of the file to read, or "-" if the
 * function should read from standard input
 * \return An NSXMLDocument object, or nil if nothing could be loaded.
 */
NSXMLDocument*
xmlabsyncLoadXml ( NSString *filename )
{
  NSXMLDocument *xmlDoc   = nil;
  NSData        *xmlData  = nil;
  NSError       *err      = nil;
  // handle "-" for stdin
  if ([filename isEqualToString:@"-"])
    {
      NSFileHandle *stdin = [NSFileHandle fileHandleWithStandardInput];
      xmlData = [stdin readDataToEndOfFile];
    }
  else
    {
      NSURL *fileUrl = [NSURL fileURLWithPath:filename];
      if (!fileUrl)
        {
          printf("%s\n", [[NSString stringWithFormat:@"ERROR: Can't create an URL from file %@", filename] UTF8String]);
          return nil;
        }
      xmlData = [NSData dataWithContentsOfURL:fileUrl];
    }
  if (!xmlData)
    {
      printf("%s\n", [[NSString stringWithFormat:@"ERROR: Could not load any data from %@", filename] UTF8String]);
      return nil;
    }
  xmlDoc = [[NSXMLDocument alloc] initWithData:xmlData
                                  options:0
                                  error:&err];
  if (xmlDoc == nil)
    {
      xmlDoc = [[NSXMLDocument alloc] initWithData:xmlData
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

/**
 * Gets the set of all groups named in the given XML document.
 *
 * \param xmldoc an XML document representing an address book
 * \return An NSSet object containing the names of the groups found in
 * the given XML document.
 */
NSSet*
xmlabsyncGetXmlGroupSet ( NSXMLDocument *xmldoc )
{
  // returns an arrays of NSXMLElement objects
  NSError *err     = nil;
  NSArray *groups  = [xmldoc nodesForXPath:@"//Group" error:&err];

  // put groups into a MutableSet object
  NSMutableSet *groupSet = [NSMutableSet setWithCapacity:0];
  for (NSXMLElement *group in groups)
    {
      [groupSet addObject:[group stringValue]];
    }
  return groupSet;
}

/**
 * Creates a new Address Book group.
 *
 * \param groupName the name of the group to create
 * \param abook the user's address book
 */
void
xmlabsyncCreateNewAbGroup ( NSString      *groupName,
                            ABAddressBook *abook )
{
  ABGroup *group = [[ABGroup alloc] initWithAddressBook:abook];
  [group setValue:groupName forProperty:kABGroupNameProperty];
  [abook save];
}

/**
 * Modifies the user's Address Book groups to match the structure
 * given in the XML document.
 *
 * \param xmldoc an XML document representing an address book
 * \param abook the user's address book
 * \param update_flag a flag which is YES if existing records in the
 * address book should be modified.  Not used here.
 * \param delete_flag a flag which is YES if existing records in the
 * address book may be deleted if they are not present in the XML
 * document.  If this flag is YES, all groups are deleted which are
 * not found in the XML.
 */
void
xmlabsyncInjectXmlGroups ( NSXMLDocument *xmldoc,
                           ABAddressBook *abook,
                           BOOL           update_flag,
                           BOOL           delete_flag )
{
  NSSet *groupSet = xmlabsyncGetXmlGroupSet(xmldoc);
  for (NSString *groupName in groupSet)
    {
      if (!xmlabsyncFindMatchingAbGroup(groupName, abook))
        {
          // create new group
          printf("%s\n", [[NSString stringWithFormat:@"Creating group %@", groupName] UTF8String]);
          xmlabsyncCreateNewAbGroup(groupName, abook);
        }
    }
  if (delete_flag)
    {
      // find all groups in address book
      for (ABGroup *group in [abook groups])
        {
          // if group is not in xml document
          if (![groupSet member:[group valueForProperty:kABGroupNameProperty]])
            {
              // delete it from the address book
              printf("%s\n", [[NSString stringWithFormat:@"Deleting group %@", [group valueForProperty:kABGroupNameProperty]] UTF8String]);
              // NOTE: we do not have to remove people from a group
              // before deleting it
              [abook removeRecord:group];
              [abook save];
            }
        }
    }
}

/**
 * Finds all person records in the given XML document.
 *
 * \param xmldoc an XML document representing an address book
 * \return An NSArray object containing all the person records found
 * in the given XML document.
 */
NSArray*
xmlabsyncGetXmlPeople ( NSXMLDocument *xmldoc )
{
  NSMutableArray *xmlPeople = [NSMutableArray arrayWithCapacity:0];
  NSError *err = nil;
  for (NSXMLElement *element in [xmldoc nodesForXPath:@"/AddressBook/Person" error:&err])
    {
      XmlPersonRecord *xmlPerson = [[XmlPersonRecord alloc] initWithXMLElement:element];
      [xmlPeople addObject:xmlPerson];
      [xmlPerson release];
    }
  return xmlPeople;
}

/**
 * Tests whether there is an entry in the multiValue2 object which
 * matches the entry in multiValue1 at idx.
 *
 * \param multiValue1 the MultiValue object with the value we are
 * trying to match
 * \param idx the index of the value we are trying to match
 * \param multiValue2 the MultiValue object to search for a matching
 * value
 * \return YES if a matching value is found; NO otherwise.
 */
BOOL
xmlabsyncMultiValueMatch ( ABMultiValue *multiValue1,
                           NSInteger     idx,
                           ABMultiValue *multiValue2 )
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

/**
 * Makes a mutable copy of an Address Book MultiValue structure.
 *
 * \param multivalue the MultiValue structure to copy
 * \return A ABMutableMultiValue object.
 */
ABMutableMultiValue*
xmlabsyncMakeMutableCopyOfMultiValue ( ABMultiValue *multivalue )
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

/**
 * Updates the properties of a person record in the user's Address
 * Book to match the information stored in the given XML file person
 * record.
 *
 * \param xmlPerson the XML file person record whose properties will
 * be stored into the user's Address Book
 * \param abPerson the person record in the user's Address Book which
 * will be updated
 * \param abook the user's Address Book
 * \param update_flag a flag which is YES if existing records in the
 * address book should be modified. Not used here.
 * \param delete_flag a flag which is YES if existing records in the
 * address book may be deleted if they are not present in the XML
 * document.  If this value is YES, properties on the given Address
 * Book person record which are not found in the XML document will be
 * deleted.
 * \return YES if the given Address Book person record was altered by
 * this operation; NO otherwise.
 */
BOOL
xmlabsyncInjectXmlPerson ( XmlPersonRecord *xmlPerson,
                           ABPerson        *abPerson,
                           ABAddressBook   *abook,
                           BOOL             update_flag,
                           BOOL             delete_flag )
{
  // inject properties
  BOOL     changedRecord       = NO;
  NSArray *relevantProperties  = xmlabsyncAbPersonRelevantProperties();
  NSArray *properties          = [xmlPerson getProperties:relevantProperties];
  // set relevant properties
  for (NSXMLElement *prop in properties)
    {
      NSString            *propName    = [prop name];
      NSString            *propType    = [[prop attributeForName:@"type"] stringValue];
      ABMutableMultiValue *multiValue  = nil;
      NSString            *multiType   = nil;
      if ([propType isEqualToString:@"string"])
        {
          NSString *propValue = [prop stringValue];
          if (![[abPerson valueForProperty:propName] isEqual:propValue])
            {
              [abPerson setValue:propValue forProperty:propName];
              changedRecord = YES;
            }
        }
      else if ([propType isEqualToString:@"date"])
        {
          NSDate *propValue = [xmlabsyncIsoDateFormatter() dateFromString:[prop stringValue]];
          // compare dates: two dates are equal if they represent the
          // same day (NSDate also has time information, which we
          // don't need for things like birthdays, etc.)
          if (![[xmlabsyncIsoDateFormatter() stringFromDate:[abPerson valueForProperty:propName]] isEqual:[prop stringValue]])
            {
              [abPerson setValue:propValue forProperty:propName];
              changedRecord = YES;
            }
        }
      else if ([propType isEqualToString:@"number"])
        {
          NSNumber *propValue = [NSNumber numberWithInteger:[[prop stringValue] integerValue]];
          if (![[abPerson valueForProperty:propName] isEqual:propValue])
            {
              [abPerson setValue:propValue forProperty:propName];
              changedRecord = YES;
            }
        }
      else if ([propType isEqualToString:@"multistring"] ||
               [propType isEqualToString:@"multidict"] ||
               [propType isEqualToString:@"multidate"])
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
              NSError      *err    = nil;
              NSXMLElement *value  = [[NSXMLElement alloc] initWithXMLString:[multiValue valueAtIndex:idx] error:&err];
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
              NSError      *err    = nil;
              NSXMLElement *value  = [[NSXMLElement alloc] initWithXMLString:[multiValue valueAtIndex:idx] error:&err];
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
              NSError      *err    = nil;
              NSXMLElement *value  = [[NSXMLElement alloc] initWithXMLString:[multiValue valueAtIndex:idx] error:&err];
              [multiValue replaceValueAtIndex:idx withValue:[xmlabsyncIsoDateFormatter() dateFromString:[value stringValue]]];
              [value release];
            }
        }
      // now do something with the multivalue
      ABMutableMultiValue *abPersonMV = xmlabsyncMakeMutableCopyOfMultiValue([abPerson valueForProperty:propName]);
      int idx = 0;
      for (; idx < [multiValue count]; idx++)
        {
          if (!xmlabsyncMultiValueMatch(multiValue, idx, abPersonMV))
            {
              // add the multivalue
              [abPersonMV addValue:[multiValue valueAtIndex:idx]
                          withLabel:[multiValue labelAtIndex:idx]];
              changedRecord = YES;
            }
        }
      // iterate backwards
      for (idx = [abPersonMV count] - 1; 0 <= idx; idx--)
        {
          if (!xmlabsyncMultiValueMatch(abPersonMV, idx, multiValue))
            {
              // remove the multivalue
              [abPersonMV removeValueAndLabelAtIndex:idx];
              changedRecord = YES;
            }
        }
      // NYI: store identifiers (UUIDs), primaryIdentifier?
      if (changedRecord)
        {
          [abPerson setValue:abPersonMV forProperty:propName];
        }
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
  // image data
  if ([xmlPerson getLastStringValueForProperty:@"ImageData"])
    {
      NSData *imageData = [[GTMStringEncoding rfc4648Base64StringEncoding] decode:[xmlPerson getLastStringValueForProperty:@"ImageData"]];
      if (![abPerson imageData] || ![[abPerson imageData] isEqualToData:imageData])
        {
          [abPerson setImageData:imageData];
          changedRecord = YES;
        }
    }
  // NYI BUG: if the user sets the image data for a person record
  // using the Address Book.app application, the following code will
  // not delete the image data for that person record.  On my system,
  // the image data is stored in
  // ~/Library/Application Support/AddressBook/Images
  // Presumably, the file needs to be removed to delete the image.
  else if (delete_flag && [abPerson imageData])
    {
      [abPerson setImageData:nil];
      changedRecord = YES;
    }
  return changedRecord;
}

/**
 * Updates the group membership information of a person record in the
 * user's Address Book to match the information stored in the given
 * XML file person record.
 *
 * \param xmlPerson the XML file person record whose group membership
 * information will be stored into the user's Address Book
 * \param abPerson the person record in the user's Address Book which
 * will be updated
 * \param abook the user's address book
 * \param update_flag a flag which is YES if existing records in the
 * address book should be modified. Not used here.
 * \param delete_flag a flag which is YES if existing records in the
 * address book may be deleted if they are not present in the XML
 * document. If this flag is YES, the person may be removed from
 * groups if the XML document does not indicate that the person is a
 * member of those groups.
 * \return YES if the given Address Book person record was altered by
 * this operation; NO otherwise.
 */
BOOL
xmlabsyncInjectXmlPersonGroups ( XmlPersonRecord *xmlPerson,
                                 ABPerson        *abPerson,
                                 ABAddressBook   *abook,
                                 BOOL             update_flag,
                                 BOOL             delete_flag )
{
  // inject groups
  BOOL   changedRecord = NO;
  NSSet *xmlGroups     = [xmlPerson getGroups];
  for (NSString *groupName in xmlGroups)
    {
      ABGroup *group = xmlabsyncFindMatchingAbGroup(groupName, abook);
      if (group && ![[abPerson parentGroups] containsObject:group])
        {
          [group addMember:abPerson];
          changedRecord = YES;
        }
    }
  if (delete_flag)
    {
      for (ABGroup *group in [abPerson parentGroups])
        {
          if (![xmlGroups member:[group valueForProperty:kABGroupNameProperty]])
            {
              [group removeMember:abPerson];
              changedRecord = YES;
            }
        }
    }
  return changedRecord;
}

/**
 * Updates the user's Address Book so that its contained person
 * records match the information stored in the given XML document.
 *
 * \param xmldoc an XML document representing an address book
 * \param abook the user's Address Book
 * \param update_flag a flag which is YES if existing records in the
 * address book should be modified. If this flag is YES, person
 * records which are found in the user's Address Book will be altered
 * to match the informatoin found in the given XML document
 * \param delete_flag a flag which is YES if existing records in the
 * address book may be deleted if they are not present in the XML
 * document. If this flag is YES, person records not found in the XML
 * document will be deleted from the user's Address Book.
 */
void
xmlabsyncInjectXmlPeople ( NSXMLDocument *xmldoc,
                           ABAddressBook *abook,
                           BOOL           update_flag,
                           BOOL           delete_flag )
{
  NSArray *xmlPeople = xmlabsyncGetXmlPeople(xmldoc);
  // for each person in the XML document
  for (XmlPersonRecord *xmlPerson in xmlPeople)
    {
      ABPerson *abPerson      = xmlabsyncFindMatchingAbPerson(xmlPerson, abook);
      BOOL      createdPerson = NO;
      // if the person is found
      if (abPerson)
        {
          if (!update_flag)
            {
              // don't update the person
              abPerson = nil;
            }
        }
      else
        {
          // create a new person entry
          printf("%s\n", [[NSString stringWithFormat:@"Creating person %@", [xmlPerson fullName]] UTF8String]);
          abPerson = [[ABPerson alloc] initWithAddressBook:abook];
          createdPerson = YES;
        }
      if (abPerson)
        {
          // inject person properties into the person entry
          BOOL updatedPerson = xmlabsyncInjectXmlPerson(xmlPerson, abPerson, abook, update_flag, delete_flag);
          if (updatedPerson)
            {
              [abook save];
            }
          // inject person groups into the person entry
          updatedPerson |= xmlabsyncInjectXmlPersonGroups(xmlPerson, abPerson, abook, update_flag, delete_flag);
          if (updatedPerson)
            {
              if (!createdPerson)
                {
                  // update the person
                  printf("%s\n", [[NSString stringWithFormat:@"Updated person %@ with %@", [abPerson fullName],
                                            [xmlPerson fullName]] UTF8String]);
                }
              [abook save];
            }
        }
    }
  if (delete_flag)
    {
      // for person in address book
      for (ABPerson *abPerson in [abook people])
        {
          // if the person is not found in the XML doc
          if (!xmlabsyncFindMatchingXmlPerson(abPerson, xmlPeople))
            {
              // delete the person
              printf("%s\n", [[NSString stringWithFormat:@"Deleting person %@", [abPerson fullName]] UTF8String]);
              [abook removeRecord:abPerson];
              [abook save];
            }
        }
    }
  // update the IsMe property
  XmlPersonRecord *xmlMe = nil;
  for (XmlPersonRecord *xmlPerson in xmlPeople)
    {
      if ([[xmlPerson getLastStringValueForProperty:@"IsMe"] isEqualToString:@"1"])
        {
          xmlMe = xmlPerson;
        }
    }
  if (xmlMe)
    {
      ABPerson *abMe = xmlabsyncFindMatchingAbPerson(xmlMe, abook);
      if (!abMe)
        {
          printf("%s\n", [[NSString stringWithFormat:@"WARNING: could not find matching record for person %@",
                                    [xmlMe fullName]] UTF8String]);
          return;
        }
      if ([abook me] != abMe && (update_flag || ![abook me]))
        {
          printf("%s\n", [[NSString stringWithFormat:@"Setting person %@ to Me", [abMe fullName]] UTF8String]);
          [abook setMe:abMe];
          [abook save];
        }
    }
  else
    {
      if ([abook me] && delete_flag)
        {
          printf("%s\n", [@"Setting Me to None" UTF8String]);
          [abook setMe:nil];
          [abook save];
        }
    }
}

/**
 * Reads an XML-formatted description of an address book and stores
 * the information into the current user's Address Book.
 *
 * \param filename the name of the XML file to read
 * \param update_flag a flag which is YES if existing records in the
 * user's Address Book should be modified
 * \param delete_flag a flag which is YES if existing records in the
 * user's Address Book may be deleted if they are not present in the
 * XML document
 */
void
xmlabsyncReadAddressBook ( NSString *filename,
                           BOOL      update_flag,
                           BOOL      delete_flag )
{
  ABAddressBook *abook   = xmlabsyncGetAddressBook();
  NSXMLDocument *xmlDoc  = xmlabsyncLoadXml(filename);
  if (!xmlDoc)
    {
      printf("ERROR: Could not load address book XML data\n");
      [abook release];
      return;
    }
  // synchronize group information
  xmlabsyncInjectXmlGroups(xmlDoc, abook, update_flag, delete_flag);
  // synchronize person information
  xmlabsyncInjectXmlPeople(xmlDoc, abook, update_flag, delete_flag);

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

/**
 * Main function.
 *
 * \param argc the number of command-line arguments passed to this process
 * \param argv an array of the command-line arguments passed to this process
 * \return Exit status (0 on success, 1 on failure).
 */
int
main ( int          argc,
       const char * argv[] )
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  int c;
  int mode        = RUN_MODE_INVALID;
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
          {"version",   no_argument, 0, 'v'},
          {0, 0, 0, 0}
        };
      /* getopt_long stores the option index here. */
      int option_index = 0;

      c = getopt_long (argc, (char * const *)argv,
                       "rwhv", long_options, &option_index);

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
        case 'v':
          printVersion();
          [pool release];
          exit(0);
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
      xmlabsyncReadAddressBook(filename, update_flag, delete_flag);
      break;
    case RUN_MODE_WRITE:
      xmlabsyncWriteAddressBook(filename);
      break;
    case RUN_MODE_REPLACE:
      xmlabsyncDeleteAddressBook();
      xmlabsyncReadAddressBook(filename, update_flag, delete_flag);
      break;
    case RUN_MODE_DELETE:
      xmlabsyncDeleteAddressBook();
      break;
    default:
      printf("ERROR: Invalid run mode\n");
      [pool release];
      exit(1);
    }

  [pool release];

  return 0;
}
