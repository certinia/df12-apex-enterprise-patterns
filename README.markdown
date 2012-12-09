DF12 Session : Applying Enterprise Application Design Patterns on Force.com
===========================================================================

Design patterns are an invaluable tool for developers and architects looking to build enterprise solutions. In this session we will present some tried and tested enterprise application engineering patterns that have been used in other platforms and languages. We will discuss and illustrate how patterns such as Data Mapper, Service Layer, Unit of Work and of course Model View Controller can be applied to Force.com. Applying these patterns can help manage governed resources (such as DML) better, encourage better separation-of-concerns in your logic and enforce Force.com coding best practices.

You can view the slides for this session [here](http://www.slideshare.net/afawcett/df12-applying-enterprise-application-design-patterns-on-forcecom?ref=http://andrewfawcett.wordpress.com/) and a re-recording of the session [here](https://docs.google.com/file/d/0B6brfGow3cD8UHhzWDF1WENEaXc/edit?pli=1). I have also started a series of blog entires on this topic, [Apex Enterprise Patterns – Separation of Concerns](http://andrewfawcett.wordpress.com/2012/11/16/apex-enterprise-patterns-separation-of-concerns/).

Introduction and Acknowledgement
--------------------------------

Thanks to [Martin Fowler](http://martinfowler.com/) for his clear and well define descriptions of the patterns used in this session. While not all are directly applicable to Force.com. We hope to illustrate Force.com tailored implementions of some that are. Many of which are designed to ensure good Separation of Concerns ([SOC](http://en.wikipedia.org/wiki/Separation_of_concerns)) and management of resources. Something as we know is quite important on the Force.com platform. You can find a full overview of all of Martin's EAA patterns [here](http://martinfowler.com/eaaCatalog/).

Sample Code Class Diagram
-------------------------

This class diagram gives an approximate view of the classes used in this sample. Colour coding helps illustrate how separation of concerns has been implemented.

![Class Diagram](http://yuml.me/572cfb8c)
![Key](http://yuml.me/290071ed)

Model View Controller
---------------------

_"Splits user interface interaction into three distinct roles."_
<http://martinfowler.com/eaaCatalog/modelViewController.html>

**Force.com Note:** Visualforce is the Force.com implementation of this pattern. However it does not help you maintain a clear separation of concerns by default. It is up to the developer to consider the purpose and thus positioning of the logic they are writing in respect to the rest of the application. Otherwise action methods in UI controllers will endup containing much of applications true business logic. The patterns below help provide a framework to help avoid. Most important for controllers (a client) is the Service Layer.

**See**  [OpportunityApplyDiscountController](https://github.com/financialforcedev/df12-apex-enterprise-patterns/blob/master/df12/src/classes/OpportunityApplyDiscountController.cls) and  [OpportunityCreateInvoiceController](https://github.com/financialforcedev/df12-apex-enterprise-patterns/blob/master/df12/src/classes/OpportunityCreateInvoiceController.cls)

Service Layer
-------------

_"A Service Layer defines an application's boundary [Cockburn PloP] and its set of available operations from the perspective of interfacing client layers. It encapsulates the application's business logic, controlling transactions and coor-dinating responses in the implementation of its operations."_
<http://martinfowler.com/eaaCatalog/serviceLayer.html>

**See** [OpportunitiesService.cls](https://github.com/financialforcedev/df12-apex-enterprise-patterns/blob/master/df12/src/classes/OpportunitiesService.cls)

**Force.com Note:** On Force.com, application behaviour is exposed in terms of the data model (your Custom Objects). As clients interact with our Custom Objects via the standard UI, Salesforce API's and tools like Data Loader. Consider in addition to this, that your applicaiton will likely have business logic that is more task or process orientated (creating invoices, applying discounts, batch processes, scheduled jobs etc). This logic is ideally suited to the Service layer pattern. Eitherway, as per the Domain Model pattern bellow and adhering to good SOC, avoid positioning business logic above your Custom Object or Service layer.

Domain Model
------------

_"An object model of the domain that incorporates both behavior and data. At its worst business logic can be very complex. Rules and logic describe many different cases and slants of behavior, and it's this complexity that objects were designed to work with. A Domain Model creates a web of interconnected objects, where each object represents some meaningful individual, whether as large as a corporation or as small as a single line on an order form."_
<http://martinfowler.com/eaaCatalog/domainModel.html>

**Force.com Note:** In order to encourage bulkficaiton throughout your business logic the implementation of this pattern here proposes that your domain classes deal with a collection of SObject's, much like an Apex Trigger does. Also consider that you may have Custom Objects that share common behavior, in these cases you can utilise OO programming to develop base classes and interfaces to reuse this code between these objects by having their domain classes extend a common domain base class.

**See** [Opportunities.cls](https://github.com/financialforcedev/df12-apex-enterprise-patterns/blob/master/df12/src/classes/Opportunities.cls), [OpportunityLineItems.cls](https://github.com/financialforcedev/df12-apex-enterprise-patterns/blob/master/df12/src/classes/OpportunityLineItems.cls) and [SObjectDomain.cls](https://github.com/financialforcedev/df12-apex-enterprise-patterns/blob/master/df12/src/classes/SObjectDomain.cls)

(also see [OpportunitiesTrigger.trigger](https://github.com/financialforcedev/df12-apex-enterprise-patterns/blob/master/df12/src/triggers/OpportunitiesTrigger.trigger) and [OpportunityLineItems.trigger](https://github.com/financialforcedev/df12-apex-enterprise-patterns/blob/master/df12/src/triggers/OpportunityLineItemsTrigger.trigger))

Data Mapper (Selector)
----------------------

_"Objects and relational databases have different mechanisms for structuring data. Many parts of an object, such as collections and inheritance, aren't present in relational databases. When you build an object model with a lot of business logic it's valuable to use these mechanisms to better organize the data and the behavior that goes with it. Doing so leads to variant schemas; that is, the object schema and the relational schema don't match up."_ <http://martinfowler.com/eaaCatalog/dataMapper.html>

**Force.com Note:** This pattern is an ideal place to place CRUD security checks for permission to read. It also helps avoid runtime exceptions relating to fields referenced that have not been queried. Since it can help form and encapsulate a consistant place for placing code relating to querying data as apposed to spreading adhoc SOQL queries throughout your logic.

**See** [OpportunitiesSelector.cls](https://github.com/financialforcedev/df12-apex-enterprise-patterns/blob/master/df12/src/classes/OpportunitiesSelector.cls), [OpportunityLineItemsSelector.cls](https://github.com/financialforcedev/df12-apex-enterprise-patterns/blob/master/df12/src/classes/OpportunityLineItemsSelector.cls) and [SObjectSelector](https://github.com/financialforcedev/df12-apex-enterprise-patterns/blob/master/df12/src/classes/SObjectSelector.cls)

Unit Of Work
------------

_"Maintains a list of objects affected by a business transaction and coordinates the writing out of changes and the resolution of concurrency problems."_ <http://martinfowler.com/eaaCatalog/unitOfWork.html>

**Force.com Note:** This pattern provides the following specific benifits

* Applies bulkfication to DML operations, insert, update and delete
* Manages a business transaction around the work and ensures a rollback occurs (even when exceptions are later handled by the caller)
* Honours dependency rules between records and updates dependent relationships automatically during the commit cycle
* Implements CRUD security

**See** [SObjectUnitOfWork.cls](https://github.com/financialforcedev/df12-apex-enterprise-patterns/blob/master/df12/src/classes/SObjectUnitOfWork.cls)
