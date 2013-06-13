/**
 * Copyright (c) 2012, FinancialForce.com, inc
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, 
 *   are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice, 
 *      this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright notice, 
 *      this list of conditions and the following disclaimer in the documentation 
 *      and/or other materials provided with the distribution.
 * - Neither the name of the FinancialForce.com, inc nor the names of its contributors 
 *      may be used to endorse or promote products derived from this software without 
 *      specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
 *  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
 *  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL 
 *  THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
 *  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 *  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 *  OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**/

/**
 * Provides an implementation of the Enterprise Application Architecture Unit Of Work, as defined by Martin Fowler
 *   http://martinfowler.com/eaaCatalog/unitOfWork.html
 *
 * "When you're pulling data in and out of a database, it's important to keep track of what you've changed; otherwise, 
 *  that data won't be written back into the database. Similarly you have to insert new objects you create and 
 *  remove any objects you delete."
 *
 * "You can change the database with each change to your object model, but this can lead to lots of very small database calls, 
 *  which ends up being very slow. Furthermore it requires you to have a transaction open for the whole interaction, which is 
 *  impractical if you have a business transaction that spans multiple requests. The situation is even worse if you need to
 *  keep track of the objects you've read so you can avoid inconsistent reads."
 *
 * "A Unit of Work keeps track of everything you do during a business transaction that can affect the database. When you're done, 
 *  it figures out everything that needs to be done to alter the database as a result of your work."
 *
 * In an Apex context this pattern provides the following specific benifits
 *  - Applies bulkfication to DML operations, insert, update and delete
 *  - Manages a business transaction around the work and ensures a rollback occurs (even when exceptions are later handled by the caller)
 *  - Honours dependency rules between records and updates dependent relationships automatically during the commit 
 *
 * Please refer to the testMethod's in this class for example usage 
 *
 * TODO: Need to complete the 100% coverage by covering parameter exceptions in tests
 * TODO: Need to add some more test methods for more complex use cases and some unexpected (e.g. registerDirty and then registerDeleted)
 *
 **/
public class SObjectUnitOfWork
{
	private List<Schema.SObjectType> m_sObjectTypes = new List<Schema.SObjectType>();
	
	private Map<String, List<SObject>> m_newListByType = new Map<String, List<SObject>>();
	
	private Map<String, List<SObject>> m_dirtyListByType = new Map<String, List<SObject>>();
	
	private Map<String, List<SObject>> m_deletedListByType = new Map<String, List<SObject>>();
	
	private Map<String, Relationships> m_relationships = new Map<String, Relationships>();
	
	/**
	 * Constructs a new UnitOfWork to support work against the given object list
	 *
	 * @param sObjectList A list of objects given in dependency order (least dependent first)
	 */
	public SObjectUnitOfWork(List<Schema.SObjectType> sObjectTypes)
	{
		m_sObjectTypes = sObjectTypes.clone();
			
		for(Schema.SObjectType sObjectType : m_sObjectTypes)
		{
			m_newListByType.put(sObjectType.getDescribe().getName(), new List<SObject>());
			m_dirtyListByType.put(sObjectType.getDescribe().getName(), new List<SObject>());
			m_deletedListByType.put(sObjectType.getDescribe().getName(), new List<SObject>());
			m_relationships.put(sObjectType.getDescribe().getName(), new Relationships());	
		}
	}
	
	/**
	 * Register a newly created SObject instance to be inserted when commitWork is called
	 *
	 * @param record A newly created SObject instance to be inserted during commitWork
	 **/
	public void registerNew(SObject record)
	{
		registerNew(record, null, null);
	}

	/**
	 * Register a newly created SObject instance to be inserted when commitWork is called, 
	 *   you may also provide a reference to the parent record instance (should also be registered as new separatly)
	 *
	 * @param record A newly created SObject instance to be inserted during commitWork
	 * @param relatedToParentField A SObjectField reference to the child field that associates the child record with its parent
	 * @param relatedToParentRecord A SObject instance of the parent record (should also be registered as new separatly)
	 **/
	public void registerNew(SObject record, Schema.sObjectField relatedToParentField, SObject relatedToParentRecord)
	{
		if(record.Id != null)
			throw new UnitOfWorkException('Only new records can be registered as new');
		String sObjectType = record.getSObjectType().getDescribe().getName();			
		if(!m_newListByType.containsKey(sObjectType))
			throw new UnitOfWorkException(String.format('SObject type {0} is not supported by this unit of work', new String[] { sObjectType }));
		m_newListByType.get(sObjectType).add(record);				
		if(relatedToParentRecord!=null && relatedToParentField!=null)
			registerRelationship(record, relatedToParentField, relatedToParentRecord);
	}
	
	/**
	 * Register a relationship between two records that have yet to be inserted to the database. This information will be 
	 *  used during the commitWork phase to make the references only when related records have been inserted to the database.
	 *
	 * @param record An existing or newly created record
	 * @param relatedToField A SObjectField referene to the lookup field that relates the two records together
	 * @param relatedTo A SOBject instance (yet to be commited to the database)
	 */
	public void registerRelationship(SObject record, Schema.sObjectField relatedToField, SObject relatedTo)
	{
		String sObjectType = record.getSObjectType().getDescribe().getName();		
		if(!m_newListByType.containsKey(sObjectType))
			throw new UnitOfWorkException(String.format('SObject type {0} is not supported by this unit of work', new String[] { sObjectType }));
		m_relationships.get(sObjectType).add(record, relatedToField, relatedTo);
	}
	
	/**
	 * Register an existing record to be updated during the commitWork method
	 *
	 * @param record An existing record
	 **/
	public void registerDirty(SObject record)
	{
		if(record.Id == null)
			throw new UnitOfWorkException('New records cannot be registered as dirty');
		String sObjectType = record.getSObjectType().getDescribe().getName();			
		if(!m_dirtyListByType.containsKey(sObjectType))
			throw new UnitOfWorkException(String.format('SObject type {0} is not supported by this unit of work', new String[] { sObjectType }));
		m_dirtyListByType.get(sObjectType).add(record);		
	}
	
	/**
	 * Register an existing record to be deleted during the commitWork method
	 *
	 * @param record An existing record
	 **/
	public void registerDeleted(SObject record)
	{
		if(record.Id == null)
			throw new UnitOfWorkException('New records cannot be registered for deletion');
		String sObjectType = record.getSObjectType().getDescribe().getName();			
		if(!m_deletedListByType.containsKey(sObjectType))
			throw new UnitOfWorkException(String.format('SObject type {0} is not supported by this unit of work', new String[] { sObjectType }));
		m_deletedListByType.get(sObjectType).add(record);							
	}
	
	/**
	 * Takes all the work that has been registered with the UnitOfWork and commits it to the database
	 **/
	public void commitWork()
	{
		// Wrap the work in its own transaction 
		Savepoint sp = Database.setSavePoint();		
		try
		{		
			// Insert by type
			for(Schema.SObjectType sObjectType : m_sObjectTypes)
			{
				m_relationships.get(sObjectType.getDescribe().getName()).resolve();
				insert m_newListByType.get(sObjectType.getDescribe().getName());
			}					
			// Update by type
			for(Schema.SObjectType sObjectType : m_sObjectTypes)
				update m_dirtyListByType.get(sObjectType.getDescribe().getName());		
			// Delete by type (in reverse dependency order)
			Integer objectIdx = m_sObjectTypes.size() - 1;
			while(objectIdx>=0)
				delete m_deletedListByType.get(m_sObjectTypes[objectIdx--].getDescribe().getName());
		}
		catch (Exception e)
		{
			// Rollback
			Database.rollback(sp);
			// Throw exception on to caller
			throw e;
		}
	}
	
	private class Relationships
	{
		private List<Relationship> m_relationships = new List<Relationship>();

		public void resolve()
		{
			// Resolve relationships
			for(Relationship relationship : m_relationships)
				relationship.Record.put(relationship.RelatedToField, relationship.RelatedTo.Id);
		}
		
		public void add(SObject record, Schema.sObjectField relatedToField, SObject relatedTo)
		{
			// Relationship to resolve
			Relationship relationship = new Relationship();
			relationship.Record = record;
			relationship.RelatedToField = relatedToField;
			relationship.RelatedTo = relatedTo;
			m_relationships.add(relationship);
		}
	}
	
	private class Relationship
	{
		public SObject Record;
		public Schema.sObjectField RelatedToField;
		public SObject RelatedTo;
	}
	
	/**
	 * UnitOfWork Exception
	 **/
	public class UnitOfWorkException extends Exception {}

	// SObjects (in order of dependency) used by UnitOfWork in tests bellow	
	private static List<Schema.SObjectType> MY_SOBJECTS = 
		new Schema.SObjectType[] { 
			Product2.SObjectType, 
			PricebookEntry.SObjectType, 
			Opportunity.SObjectType, 
			OpportunityLineItem.SObjectType };

	@IsTest(seeAllData=true)
	public static void testUnitOfWorkNewDirtyDelete()
	{
		// Grab the Standard Pricebook (cannot create these via Apex!?!)
		Pricebook2 pb = [select Id from Pricebook2 where IsStandard = true];		
		
		// Insert Opporunities with UnitOfWork
		{
			SObjectUnitOfWork uow = new SObjectUnitOfWork(MY_SOBJECTS);				
			for(Integer o=0; o<10; o++)
			{
				Opportunity opp = new Opportunity();
				opp.Name = 'UoW Test Name ' + o;
				opp.StageName = 'Open';
				opp.CloseDate = System.today();
				uow.registerNew(opp);		
				for(Integer i=0; i<o+1; i++)
				{						
					Product2 product = new Product2();
					product.Name = opp.Name + ' : Product : ' + i;
					uow.registerNew(product);		
					PricebookEntry pbe = new PricebookEntry();
					pbe.UnitPrice = 10;
					pbe.IsActive = true;
					pbe.UseStandardPrice = false;
					pbe.Pricebook2Id = pb.Id;
					uow.registerNew(pbe, PricebookEntry.Product2Id, product);		
					OpportunityLineItem oppLineItem = new OpportunityLineItem();
					oppLineItem.Quantity = 1;
					oppLineItem.TotalPrice = 10;
					uow.registerRelationship(oppLineItem, OpportunityLineItem.PricebookEntryId, pbe);
					uow.registerNew(oppLineItem, OpportunityLineItem.OpportunityId, opp);
				}
			}					
			uow.commitWork();
		}
		
		// Assert Results 
		assertResults('UoW');
		System.assertEquals(6 /* Oddly a setSavePoint consumes a DML */, Limits.getDmlStatements());				

		// Records to update
		List<Opportunity> opps = [select Id, Name, (Select Id from OpportunityLineItems) from Opportunity where Name like 'UoW Test Name %' order by Name];
		
		// Update some records with UnitOfWork
		{
			SObjectUnitOfWork uow = new SObjectUnitOfWork(MY_SOBJECTS);	
			Opportunity opp = opps[0];
			opp.Name = opp.Name + ' Changed';	
			uow.registerDirty(opp);			
			Product2 product = new Product2();
			product.Name = opp.Name + ' : New Product';
			uow.registerNew(product);		
			PricebookEntry pbe = new PricebookEntry();
			pbe.UnitPrice = 10;
			pbe.IsActive = true;
			pbe.UseStandardPrice = false;
			pbe.Pricebook2Id = pb.Id;
			uow.registerNew(pbe, PricebookEntry.Product2Id, product);
			OpportunityLineItem newOppLineItem = new OpportunityLineItem();
			newOppLineItem.Quantity = 1;
			newOppLineItem.TotalPrice = 10;
			uow.registerRelationship(newOppLineItem, OpportunityLineItem.PricebookEntryId, pbe);
			uow.registerNew(newOppLineItem, OpportunityLineItem.OpportunityId, opp);			
			OpportunityLineItem existingOppLine = opp.OpportunityLineItems[0];
			existingOppLine.Quantity = 2;
			uow.registerDirty(existingOppLine);
			uow.commitWork();
		}
		
		// Assert Results
		System.assertEquals(12, Limits.getDmlStatements());				
		opps = [select Id, Name, (Select Id, PricebookEntry.Product2.Name, Quantity from OpportunityLineItems Order By PricebookEntry.Product2.Name) from Opportunity where Name like 'UoW Test Name %' order by Name];
		System.assertEquals(10, opps.size());
		System.assertEquals('UoW Test Name 0 Changed', opps[0].Name);
		System.assertEquals(2, opps[0].OpportunityLineItems.size());
		System.assertEquals(2, opps[0].OpportunityLineItems[0].Quantity);		
		System.assertEquals('UoW Test Name 0 Changed : New Product', opps[0].OpportunityLineItems[1].PricebookEntry.Product2.Name);
		
		// Delete some records with the UnitOfWork
		{
			SObjectUnitOfWork uow = new SObjectUnitOfWork(MY_SOBJECTS);	
			uow.registerDeleted(opps[0].OpportunityLineItems[1].PricebookEntry.Product2); // Delete PricebookEntry Product 
			uow.registerDeleted(opps[0].OpportunityLineItems[1].PricebookEntry); // Delete PricebookEntry
			uow.registerDeleted(opps[0].OpportunityLineItems[1]); // Delete OpportunityLine Item
			uow.commitWork();
		}		
		
		// Assert Results
		System.assertEquals(16, Limits.getDmlStatements());		
		opps = [select Id, Name, (Select Id, PricebookEntry.Product2.Name, Quantity from OpportunityLineItems Order By PricebookEntry.Product2.Name) from Opportunity where Name like 'UoW Test Name %' order by Name];
		List<Product2> prods = [Select Id from Product2 where Name = 'UoW Test Name 0 Changed : New Product'];
		System.assertEquals(10, opps.size());
		System.assertEquals('UoW Test Name 0 Changed', opps[0].Name);
		System.assertEquals(1, opps[0].OpportunityLineItems.size()); // Should have deleted OpportunityLineItem added above
		System.assertEquals(0, prods.size()); // Should have deleted Product added above				
	}
		
	@IsTest(seeAllData=true)
	public static void testUnitOfWorkUseCae1()
	{
		// Grab the Standard Pricebook (cannot create these via Apex!?!)
		Pricebook2 standardPricebook = [select Id from Pricebook2 where IsStandard = true];		
		
		// Insert Opporunities with UnitOfWork
		{
			SObjectUnitOfWork uow = new SObjectUnitOfWork(MY_SOBJECTS);				
			for(Integer o=0; o<10; o++)
			{
				Opportunity opp = new Opportunity();
				opp.Name = 'UoW Test Name ' + o;
				opp.StageName = 'Open';
				opp.CloseDate = System.today();
				uow.registerNew(opp);		
				Product2 product = new Product2();
				product.Name = opp.Name + ' : Product : ' + o;
				uow.registerNew(product);		
				PricebookEntry pbe = new PricebookEntry();
				pbe.UnitPrice = 10;
				pbe.IsActive = true;
				pbe.UseStandardPrice = false;
				pbe.Pricebook2Id = standardPricebook.Id;
				uow.registerNew(pbe, PricebookEntry.Product2Id, product);		
				for(Integer i=0; i<o+1; i++)
				{						
					OpportunityLineItem oppLineItem = new OpportunityLineItem();
					oppLineItem.Quantity = 1;
					oppLineItem.TotalPrice = 10;
					uow.registerRelationship(oppLineItem, OpportunityLineItem.PricebookEntryId, pbe);
					uow.registerNew(oppLineItem, OpportunityLineItem.OpportunityId, opp);
				}
			}		
			uow.commitWork();
		}

		// Query Opportunity		
		List<Opportunity> opportunities = 
			[select Id, Name, Amount, 
				(Select Id, PricebookEntry.Id, PricebookEntry.Product2.Id, PricebookEntry.Product2.Name, UnitPrice, Quantity from OpportunityLineItems order by PricebookEntry.Product2.Id) 
			 from Opportunity 
			 where Name 
			 like 'UoW Test Name %' 
			 order by Name];
		System.assertEquals(10, opportunities.size());
		System.assertEquals(100, opportunities[9].Amount);		
		System.assertEquals(10, opportunities[9].OpportunityLineItems.size()); // Should have deleted OpportunityLineItem added above			 
			 
		{
			// Consolidate Products on the Opportunities
			SObjectUnitOfWork uow = new SObjectUnitOfWork(MY_SOBJECTS);
			for(Opportunity opportunity : opportunities)
			{			
				// Group the lines by Product
				Map<Id, List<OpportunityLineItem>> linesByGroup = new Map<Id, List<OpportunityLineItem>>();				
				for(OpportunityLineItem opportunityLineItem : opportunity.OpportunityLineItems)
				{
					Id productId = opportunityLineItem.PricebookEntry.Product2.Id;
					List<OpportunityLineItem> linesForThisProduct = linesByGroup.get(productId);
					if(linesForThisProduct==null) 
						linesByGroup.put(productId, (linesForThisProduct = new List<OpportunityLineItem>()));
					linesForThisProduct.add(opportunityLineItem);
				}
				// For groups with more than one 1 line, delete those lines and create a new consolidated one
				for(List<OpportunityLineItem> linesForGroup : linesByGroup.values() )
				{
					// More than one line with this product?
					if(linesForGroup.size()>1)
					{
						// Delete the duplicate product lines and caculate new quantity total
						Decimal consolidatedQuantity = 0;
						for(OpportunityLineItem lineForProduct : linesForGroup)
						{
							consolidatedQuantity += lineForProduct.Quantity;
							uow.registerDeleted(lineForProduct);
						}
						// Create new consolidated line
						OpportunityLineItem consolidatedLine = new OpportunityLineItem();
						consolidatedLine.Quantity = consolidatedQuantity;
						consolidatedLine.UnitPrice = linesForGroup[0].UnitPrice;
						consolidatedLine.PricebookEntryId = linesForGroup[0].PricebookEntry.Id;
						uow.registerNew(consolidatedLine, OpportunityLineItem.OpportunityId, opportunity);						
						// Note the last consolidation date
						opportunity.Description = 'Consolidated on ' + System.today();
						uow.registerDirty(opportunity);
					}					
				}				
			}
			uow.commitWork();
		}
		
		// Query Opportunity		
		opportunities = 
			[select Id, Name, Amount,
				(Select Id, PricebookEntry.Id, PricebookEntry.Product2.Id, PricebookEntry.Product2.Name, UnitPrice, Quantity from OpportunityLineItems order by PricebookEntry.Product2.Id) 
			 from Opportunity 
			 where Name 
			 like 'UoW Test Name %' 
			 order by Name];
		System.assertEquals(10, opportunities.size());
		System.assertEquals(100, opportunities[9].Amount);
		System.assertEquals(1, opportunities[9].OpportunityLineItems.size()); // Should have deleted OpportunityLineItem added above			 		
	}
		
	@IsTest(seeAllData=true)
	public static void testUnitOfWorkOverhead()
	{
		// Grab the Standard Pricebook (cannot create these via Apex!?!)
		Pricebook2 pb = [select Id from Pricebook2 where IsStandard = true];		
		
		// Insert Opporunities with UnitOfWork
		{
			SObjectUnitOfWork uow = new SObjectUnitOfWork(MY_SOBJECTS);				
			for(Integer o=0; o<10; o++)
			{
				Opportunity opp = new Opportunity();
				opp.Name = 'UoW Test Name ' + o;
				opp.StageName = 'Open';
				opp.CloseDate = System.today();
				uow.registerNew(opp);		
				for(Integer i=0; i<o+1; i++)
				{						
					Product2 product = new Product2();
					product.Name = opp.Name + ' : Product : ' + i;
					uow.registerNew(product);		
					PricebookEntry pbe = new PricebookEntry();
					pbe.UnitPrice = 10;
					pbe.IsActive = true;
					pbe.UseStandardPrice = false;
					pbe.Pricebook2Id = pb.Id;
					uow.registerNew(pbe, PricebookEntry.Product2Id, product);		
					OpportunityLineItem oppLineItem = new OpportunityLineItem();
					oppLineItem.Quantity = 1;
					oppLineItem.TotalPrice = 10;
					uow.registerRelationship(oppLineItem, OpportunityLineItem.PricebookEntryId, pbe);
					uow.registerNew(oppLineItem, OpportunityLineItem.OpportunityId, opp);
				}
			}		
			uow.commitWork();
		}
		
		// Assert Results from using UnitOfWork
		Integer costToCommitUoW = Limits.getScriptStatements();
		System.assertEquals(6, Limits.getDmlStatements());		
		assertResults('UoW');
				
		// Insert Opportunities "without" UnitOfWork
		{
			List<Opportunity> opps = new List<Opportunity>();
			List<List<Product2>> productsByOpp = new List<List<Product2>>(); 		
			List<List<PricebookEntry>> pricebookEntriesByOpp = new List<List<PricebookEntry>>(); 		
			List<List<OpportunityLineItem>> oppLinesByOpp = new List<List<OpportunityLineItem>>(); 		
			for(Integer o=0; o<10; o++)
			{
				Opportunity opp = new Opportunity();
				opp.Name = 'NoUoW Test Name ' + o;
				opp.StageName = 'Open';
				opp.CloseDate = System.today();
				opps.add(opp);
				List<Product2> products = new List<Product2>();
				List<PricebookEntry> pricebookEntries = new List<PricebookEntry>();
				List<OpportunityLineItem> oppLineItems = new List<OpportunityLineItem>();
				for(Integer i=0; i<o+1; i++)
				{						
					Product2 product = new Product2();
					product.Name = opp.Name + ' : Product : ' + i;
					products.add(product);
					PricebookEntry pbe = new PricebookEntry();
					pbe.UnitPrice = 10;
					pbe.IsActive = true;
					pbe.UseStandardPrice = false;
					pbe.Pricebook2Id = pb.Id;
					pricebookEntries.add(pbe);
					OpportunityLineItem oppLineItem = new OpportunityLineItem();
					oppLineItem.Quantity = 1;
					oppLineItem.TotalPrice = 10;
					oppLineItems.add(oppLineItem);
				}
				productsByOpp.add(products);
				pricebookEntriesByOpp.add(pricebookEntries);
				oppLinesByOpp.add(oppLineItems);				
			}
			// Insert Opportunities
			insert opps;
			// Insert Products
			List<Product2> allProducts = new List<Product2>(); 
			for(List<Product2> products : productsByOpp)
			{
				allProducts.addAll(products);			
			}
			insert allProducts;
			// Insert Pricebooks
			Integer oppIdx = 0;			
			List<PricebookEntry> allPricebookEntries = new List<PricebookEntry>();				
			for(List<PricebookEntry> pricebookEntries : pricebookEntriesByOpp)
			{
				List<Product2> products = productsByOpp[oppIdx++];
				Integer lineIdx = 0;
				for(PricebookEntry pricebookEntry : pricebookEntries)
				{
					pricebookEntry.Product2Id = products[lineIdx++].Id;
				}
				allPricebookEntries.addAll(pricebookEntries);
			}			
			insert allPricebookEntries;
			// Insert Opportunity Lines
			oppIdx = 0;						
			List<OpportunityLineItem> allOppLineItems = new List<OpportunityLineItem>(); 			
			for(List<OpportunityLineItem> oppLines : oppLinesByOpp)
			{
				List<PricebookEntry> pricebookEntries = pricebookEntriesByOpp[oppIdx];
				Integer lineIdx = 0;
				for(OpportunityLineItem oppLine : oppLines)
				{
					oppLine.OpportunityId = opps[oppIdx].Id;
					oppLine.PricebookEntryId = pricebookEntries[lineIdx++].Id;
				}
				allOppLineItems.addAll(oppLines);
				oppIdx++;
			}			
			insert allOppLineItems;
		}
		
		// Assert Results from not using UnitOfWork
		Integer costToCommitNoUoW = Limits.getScriptStatements() - costToCommitUoW;
		System.debug('costToCommitUoW ' + costToCommitUoW);
		System.debug('costToCommitNoUoW ' + costToCommitNoUoW);
		assertResults('NoUoW');
		
		// Assert an acceptable statement % cost for using the UnitOfWork approach
		System.assert((costToCommitUoW - costToCommitNoUoW) <= 3000, 'Overhead of using UnitOfWork has grown above 3000 statements.');						
	}
	
	private static void assertResults(String prefix)
	{
		// Standard Assertions on tests data inserted by tests
		String filter = prefix + ' Test Name %';
		List<Opportunity> opps = [select Id, Name, (Select Id from OpportunityLineItems) from Opportunity where Name like :filter order by Name];
		System.assertEquals(10, opps.size());
		System.assertEquals(1, opps[0].OpportunityLineItems.size());		
		System.assertEquals(2, opps[1].OpportunityLineItems.size());		
		System.assertEquals(3, opps[2].OpportunityLineItems.size());		
		System.assertEquals(4, opps[3].OpportunityLineItems.size());		
		System.assertEquals(5, opps[4].OpportunityLineItems.size());		
		System.assertEquals(6, opps[5].OpportunityLineItems.size());		
		System.assertEquals(7, opps[6].OpportunityLineItems.size());		
		System.assertEquals(8, opps[7].OpportunityLineItems.size());		
		System.assertEquals(9, opps[8].OpportunityLineItems.size());		
		System.assertEquals(10, opps[9].OpportunityLineItems.size());		
	}
}